//! The idle part of a population test: many apps open at once, each an
//! account `seed-population` wrote, its Sync stream open as the app opens
//! one (`SyncOpen` from where it is, by these rules) and a heartbeat every
//! `--heartbeat` seconds, as the app sends. Now and then one is closed and
//! opened again (`--reopen-per-sec`), and one opens as a new install would,
//! from nothing, and is sent its account whole (`--restore-per-sec`).
//! Training, signing up and partners are `schlift-load`, run beside it.
//!
//! Prints how many are connected and the latencies every 10 s, and a JSON
//! summary at the end.

use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

use clap::Parser;
use rand::{Rng, SeedableRng};
use schlift::workout::v1::sync_service_client::SyncServiceClient;
use schlift::workout::v1::workout_service_client::WorkoutServiceClient;
use schlift::workout::v1::*;
use schlift_load::metrics::Metrics;
use tokio::sync::{mpsc, watch};
use tokio_stream::wrappers::ReceiverStream;
use tonic::transport::Channel;

/// Past any version gate.
const APP_VERSION: &str = "999.0.0";

#[derive(Parser, Clone)]
struct Args {
    #[arg(long)]
    server: String,
    /// The first population account this process opens, and how many.
    #[arg(long, default_value_t = 0)]
    from: usize,
    #[arg(long, default_value_t = 100_000)]
    count: usize,
    /// What every seeded account ends at (seed-population prints them).
    #[arg(long)]
    head: i64,
    #[arg(long)]
    last_id: String,
    /// Every this many accounts holds the long history (seed-population's
    /// `long every`), ending at `--long-head` and `--long-last-id`.
    #[arg(long, default_value_t = 0)]
    long_every: usize,
    #[arg(long, default_value_t = 0)]
    long_head: i64,
    #[arg(long, default_value = "")]
    long_last_id: String,
    /// Connections the streams share, as Caddy's to the server are.
    #[arg(long, default_value_t = 1_000)]
    connections: usize,
    #[arg(long, default_value_t = 30.0)]
    heartbeat: f64,
    /// Seconds over which the apps open.
    #[arg(long, default_value_t = 300.0)]
    ramp: f64,
    /// Seconds they stay open once all are.
    #[arg(long, default_value_t = 300.0)]
    hold: f64,
    #[arg(long, default_value_t = 20.0)]
    reopen_per_sec: f64,
    #[arg(long, default_value_t = 2.0)]
    restore_per_sec: f64,
    /// Website reads (ListWorkoutSummaries) a second, across the accounts.
    #[arg(long, default_value_t = 20.0)]
    reads_per_sec: f64,
    #[arg(long, default_value = ".tmp/population-report.json")]
    out: String,
    /// Each app trains (`training.rs`): a workout started at a random
    /// moment within `--start-within` seconds, done at a real cadence.
    #[arg(long)]
    train: bool,
    #[arg(long, default_value_t = 600.0)]
    start_within: f64,
    /// Of sets done, the share followed by a question to the person's
    /// assistant (an account read, folded with what the phone just sent).
    #[arg(long, default_value_t = 0.05)]
    ask_per_set: f64,
}

fn token(n: usize) -> String {
    format!("population-login-{n:012}")
}

fn authed<T>(token: &str, message: T) -> tonic::Request<T> {
    let mut request = tonic::Request::new(message);
    let headers = request.metadata_mut();
    headers.insert("x-session-token", token.parse().expect("header"));
    headers.insert("x-app-version", APP_VERSION.parse().expect("header"));
    headers.insert("x-platform", "android".parse().expect("header"));
    request
}

struct Shared {
    args: Args,
    metrics: Metrics,
    channels: Vec<Channel>,
    connected: AtomicUsize,
    beats: AtomicUsize,
    stop: watch::Receiver<bool>,
    /// The account every seeded user holds, as the server sends it whole:
    /// what each training phone starts from.
    template: Option<schlift_core::account::Account>,
    started: AtomicUsize,
    sets: AtomicUsize,
    ended: AtomicUsize,
    pushed: AtomicUsize,
    /// This run, mixed into every phone's seed.
    run: u64,
}

/// One app: open, heartbeat until told to stop or reopen.
async fn app(shared: Arc<Shared>, n: usize, mut reopen: mpsc::Receiver<bool>) {
    let channel = shared.channels[n % shared.channels.len()].clone();
    // Each run's phones make new event ids, as real ones do (random): a
    // run after another would otherwise resend the last one's.
    let mut rng = rand::rngs::StdRng::seed_from_u64(n as u64 ^ shared.run);
    let mut stop = shared.stop.clone();
    let mut from_nothing = false;
    // Training: the phone, where the server's placed events have it, and
    // when the person acts next.
    let mut phone = shared
        .template
        .clone()
        .map(|account| schlift_load::training::Phone::new(account, n as u64));
    let args = &shared.args;
    let (mut held_seq, mut held_id) = if args.long_every > 0 && n.is_multiple_of(args.long_every) {
        (args.long_head, args.long_last_id.clone())
    } else {
        (args.head, args.last_id.clone())
    };
    // The end of its workout, sent: timed until placed.
    let mut ended_ids = std::collections::HashSet::<String>::new();
    let mut next_action = phone.as_ref().map(|_| {
        tokio::time::Instant::now()
            + Duration::from_secs_f64(rng.gen_range(0.0..shared.args.start_within.max(1.0)))
    });
    loop {
        if *stop.borrow() {
            return;
        }
        let (up, rx) = mpsc::channel::<SyncRequest>(4);
        let open = if from_nothing {
            SyncOpen {
                after_seq: 0,
                fold: schlift_core::FOLD.to_string(),
                ..Default::default()
            }
        } else {
            SyncOpen {
                after_seq: held_seq,
                fold: schlift_core::FOLD.to_string(),
                pending_ids: phone
                    .as_ref()
                    .map(|p| p.unacked.keys().cloned().collect())
                    .unwrap_or_default(),
                last_id: held_id.clone(),
            }
        };
        let op = if from_nothing { "open.restore" } else { "open" };
        let opened = Instant::now();
        if up
            .send(SyncRequest {
                kind: Some(sync_request::Kind::Open(open)),
            })
            .await
            .is_err()
        {
            return;
        }
        let mut down = match SyncServiceClient::new(channel.clone())
            .sync(authed(&token(n), ReceiverStream::new(rx)))
            .await
        {
            Ok(response) => response.into_inner(),
            Err(status) => {
                shared.metrics.error(op, status.message());
                tokio::time::sleep(Duration::from_secs(5)).await;
                continue;
            }
        };
        // Open once the server says where it is: the head, or the account.
        let mut first = true;
        shared.connected.fetch_add(1, Ordering::Relaxed);
        let jitter = Duration::from_secs_f64(rng.gen_range(0.0..shared.args.heartbeat));
        let mut beat = tokio::time::interval_at(
            tokio::time::Instant::now() + jitter,
            Duration::from_secs_f64(shared.args.heartbeat),
        );
        let mut beat_sent: Option<Instant> = None;
        let again = loop {
            let wake = next_action
                .unwrap_or_else(|| tokio::time::Instant::now() + Duration::from_secs(86_400));
            tokio::select! {
                message = down.message() => match message {
                    Ok(Some(message)) => {
                        if first && matches!(message.kind, Some(sync_response::Kind::Events(_) | sync_response::Kind::Account(_))) {
                            shared.metrics.record(op, opened.elapsed());
                            first = false;
                        }
                        match message.kind {
                            Some(sync_response::Kind::Events(events)) => {
                                if let Some(phone) = phone.as_mut() {
                                    let placed = if events.packed.is_empty() {
                                        Vec::new()
                                    } else {
                                        schlift_core::sync::unpack(&events.packed).unwrap_or_default()
                                    };
                                    for event in placed {
                                        if let Some(sent) = phone.unacked.remove(&event.id) {
                                            // Timed from the end: the rest
                                            // were held for it, as designed.
                                            if ended_ids.remove(&event.id) {
                                                shared.metrics.record("ack.end", sent.elapsed());
                                            }
                                        }
                                        held_seq = held_seq.max(event.seq);
                                        if event.seq == held_seq {
                                            held_id = event.id;
                                        }
                                    }
                                }
                            }
                            Some(sync_response::Kind::Account(state)) => {
                                // Whole (behind, or told its pending were
                                // written while it was away).
                                if let Some(phone) = phone.as_mut() {
                                    for id in &state.placed_ids {
                                        phone.unacked.remove(id);
                                        ended_ids.remove(id);
                                    }
                                }
                                if state.seq >= held_seq {
                                    held_seq = state.seq;
                                    held_id = state.last_id;
                                }
                            }
                            Some(sync_response::Kind::Head(_)) => {
                                if let Some(sent) = beat_sent.take() {
                                    shared.metrics.record("heartbeat", sent.elapsed());
                                }
                            }
                            _ => {}
                        }
                    }
                    Ok(None) => { shared.metrics.error("stream", "closed by the server"); break true; }
                    Err(status) => { shared.metrics.error("stream", status.message()); break true; }
                },
                _ = beat.tick() => {
                    if beat_sent.is_some() {
                        shared.metrics.error("heartbeat", "no answer before the next");
                    }
                    beat_sent = Some(Instant::now());
                    shared.beats.fetch_add(1, Ordering::Relaxed);
                    if up.send(SyncRequest { kind: Some(sync_request::Kind::Heartbeat(Heartbeat {})) }).await.is_err() {
                        break true;
                    }
                }
                _ = tokio::time::sleep_until(wake), if next_action.is_some() => {
                    let Some(phone) = phone.as_mut() else { break false };
                    let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map_or(0, |d| d.as_secs() as i64);
                    match phone.act(&mut rng, now) {
                        Ok(done) => {
                            match done.what {
                                "start" => { shared.started.fetch_add(1, Ordering::Relaxed); }
                                "set done" => {
                                    shared.sets.fetch_add(1, Ordering::Relaxed);
                                    if rng.gen_bool(shared.args.ask_per_set.clamp(0.0, 1.0)) {
                                        ask(&shared, &channel, n);
                                    }
                                }
                                "end" => {
                                    shared.ended.fetch_add(1, Ordering::Relaxed);
                                    ended_ids.extend(done.events.iter().map(|e| e.id.clone()));
                                }
                                _ => {}
                            }
                            next_action = done.next_in.map(|s| tokio::time::Instant::now() + Duration::from_secs_f64(s));
                            if !done.events.is_empty() {
                                let at = Instant::now();
                                for event in &done.events {
                                    phone.unacked.insert(event.id.clone(), at);
                                }
                                shared.pushed.fetch_add(done.events.len(), Ordering::Relaxed);
                                let packed = schlift_core::sync::pack(&done.events);
                                if up.send(SyncRequest { kind: Some(sync_request::Kind::Events(packed)) }).await.is_err() {
                                    break true;
                                }
                            }
                        }
                        Err(error) => {
                            shared.metrics.error("train", error);
                            next_action = None;
                        }
                    }
                }
                restore = reopen.recv() => {
                    from_nothing = restore.unwrap_or(false);
                    break restore.is_some();
                }
                _ = stop.changed() => break false,
            }
        };
        shared.connected.fetch_sub(1, Ordering::Relaxed);
        drop(up);
        if !again {
            return;
        }
        if !from_nothing {
            // Closed by the app (or the link): a moment before it opens again.
            tokio::time::sleep(Duration::from_millis(rng.gen_range(100..2_000))).await;
        }
    }
}

#[tokio::main]
async fn main() {
    let args = Args::parse();
    let mut channels = Vec::with_capacity(args.connections);
    for _ in 0..args.connections {
        let endpoint = schlift_load::endpoint(&args.server).expect("server url");
        channels.push(endpoint.connect_lazy());
    }
    let (stop_tx, stop) = watch::channel(false);
    // Training: the account every seeded user holds, as a new phone gets
    // it (the server sends it whole), once.
    let template = if args.train {
        Some(fetch_account(&channels[0], args.from + 1).await)
    } else {
        None
    };
    let shared = Arc::new(Shared {
        args: args.clone(),
        metrics: Metrics::default(),
        channels,
        connected: AtomicUsize::new(0),
        beats: AtomicUsize::new(0),
        stop,
        template,
        started: AtomicUsize::new(0),
        sets: AtomicUsize::new(0),
        ended: AtomicUsize::new(0),
        pushed: AtomicUsize::new(0),
        run: std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_or(0, |d| d.as_nanos() as u64),
    });
    let started = Instant::now();
    let mut reopeners = Vec::with_capacity(args.count);
    let per_app = Duration::from_secs_f64(args.ramp / args.count.max(1) as f64);
    let opener = {
        let shared = shared.clone();
        tokio::spawn(async move {
            let mut tx = Vec::with_capacity(shared.args.count);
            let mut next = tokio::time::Instant::now();
            for k in 0..shared.args.count {
                let (reopen_tx, reopen_rx) = mpsc::channel(1);
                tx.push(reopen_tx);
                let shared2 = shared.clone();
                apps_spawn(shared2, shared.args.from + k, reopen_rx);
                next += per_app;
                tokio::time::sleep_until(next).await;
            }
            tx
        })
    };
    // Reporter.
    let reporter = {
        let shared = shared.clone();
        tokio::spawn(async move {
            let mut last_beats = 0;
            let (mut last_sets, mut last_pushed) = (0, 0);
            let mut every = tokio::time::interval(Duration::from_secs(10));
            every.tick().await;
            loop {
                every.tick().await;
                let beats = shared.beats.load(Ordering::Relaxed);
                let summary = shared.metrics.summary();
                let p = |op: &str| {
                    summary
                        .get(op)
                        .map(|s| {
                            format!(
                                "{} p50 {:.1} p99 {:.1} max {:.0}",
                                s.count, s.p50_ms, s.p99_ms, s.max_ms
                            )
                        })
                        .unwrap_or_default()
                };
                let errors: u64 = summary
                    .values()
                    .map(|s| s.errors.values().sum::<u64>())
                    .sum();
                println!(
                    "{:>5.0}s connected {:>8} beats/s {:>6.0} | open {} | heartbeat {} | restore {} | read {} | errors {errors}",
                    started.elapsed().as_secs_f64(),
                    shared.connected.load(Ordering::Relaxed),
                    (beats - last_beats) as f64 / 10.0,
                    p("open"),
                    p("heartbeat"),
                    p("open.restore"),
                    p("web.read"),
                );
                last_beats = beats;
                if shared.args.train {
                    let (sets, pushed) = (
                        shared.sets.load(Ordering::Relaxed),
                        shared.pushed.load(Ordering::Relaxed),
                    );
                    println!(
                        "        training: started {} ended {} | sets/s {:.0} events/s {:.0} | end acked {} | ask {}",
                        shared.started.load(Ordering::Relaxed),
                        shared.ended.load(Ordering::Relaxed),
                        (sets - last_sets) as f64 / 10.0,
                        (pushed - last_pushed) as f64 / 10.0,
                        p("ack.end"),
                        p("ask.mid-set"),
                    );
                    (last_sets, last_pushed) = (sets, pushed);
                }
            }
        })
    };
    reopeners.extend(opener.await.expect("opener"));
    println!(
        "all {} opened in {:.0}s",
        args.count,
        started.elapsed().as_secs_f64()
    );
    // Holding: reopens, restores and website reads, until the hold is over.
    let held = Instant::now();
    let mut rng = rand::rngs::StdRng::seed_from_u64(42);
    let tick = Duration::from_millis(100);
    let mut reads = tokio::task::JoinSet::new();
    while held.elapsed().as_secs_f64() < args.hold {
        tokio::time::sleep(tick).await;
        let per_tick = |rate: f64, rng: &mut rand::rngs::StdRng| {
            let expected = rate * tick.as_secs_f64();
            expected.floor() as usize + usize::from(rng.gen_bool(expected.fract()))
        };
        for _ in 0..per_tick(args.reopen_per_sec, &mut rng) {
            let _ = reopeners[rng.gen_range(0..reopeners.len())].try_send(false);
        }
        for _ in 0..per_tick(args.restore_per_sec, &mut rng) {
            let _ = reopeners[rng.gen_range(0..reopeners.len())].try_send(true);
        }
        for _ in 0..per_tick(args.reads_per_sec, &mut rng) {
            let n = args.from + rng.gen_range(0..args.count);
            let channel = shared.channels[n % shared.channels.len()].clone();
            let shared = shared.clone();
            reads.spawn(async move {
                let _ = shared
                    .metrics
                    .time(
                        "web.read",
                        WorkoutServiceClient::new(channel).list_workout_summaries(authed(
                            &token(n),
                            ListWorkoutSummariesRequest {},
                        )),
                    )
                    .await;
            });
        }
        while reads.try_join_next().is_some() {}
    }
    stop_tx.send_replace(true);
    drop(reopeners);
    // The apps hang up on the stop; a moment for them to.
    tokio::time::sleep(Duration::from_secs(2)).await;
    reporter.abort();
    let summary = shared.metrics.summary();
    let report = serde_json::json!({
        "accounts": args.count,
        "heartbeat_seconds": args.heartbeat,
        "connections": args.connections,
        "seconds": started.elapsed().as_secs_f64(),
        "ops": summary,
    });
    std::fs::write(
        &args.out,
        serde_json::to_string_pretty(&report).expect("json"),
    )
    .expect("report");
    println!("{}", serde_json::to_string_pretty(&report).expect("json"));
}

/// A question to the person's assistant mid-set: the account read as it is
/// now, the set just sent folded in (the same read the MCP's tools make).
fn ask(shared: &Arc<Shared>, channel: &Channel, n: usize) {
    let (shared, channel) = (shared.clone(), channel.clone());
    tokio::spawn(async move {
        let _ = shared
            .metrics
            .time(
                "ask.mid-set",
                WorkoutServiceClient::new(channel)
                    .list_workout_summaries(authed(&token(n), ListWorkoutSummariesRequest {})),
            )
            .await;
    });
}

fn apps_spawn(shared: Arc<Shared>, n: usize, reopen: mpsc::Receiver<bool>) {
    tokio::spawn(app(shared, n, reopen));
}

/// The account seeded user `n` holds, as the server sends a new phone it.
async fn fetch_account(channel: &Channel, n: usize) -> schlift_core::account::Account {
    let (up, rx) = mpsc::channel::<SyncRequest>(1);
    up.send(SyncRequest {
        kind: Some(sync_request::Kind::Open(SyncOpen {
            after_seq: 0,
            fold: schlift_core::FOLD.to_string(),
            ..Default::default()
        })),
    })
    .await
    .expect("open");
    let mut down = SyncServiceClient::new(channel.clone())
        .sync(authed(&token(n), ReceiverStream::new(rx)))
        .await
        .expect("sync")
        .into_inner();
    while let Some(message) = down.message().await.expect("stream") {
        if let Some(sync_response::Kind::Account(state)) = message.kind {
            let (mut account, _) =
                schlift_core::snapshot::restore(&state.snapshot).expect("the account reads");
            account.without_heart_rate = false;
            println!(
                "the seeded account: {} workouts, seq {}",
                account.workouts.len(),
                state.seq
            );
            return account;
        }
    }
    panic!("no account sent")
}
