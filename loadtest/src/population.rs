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
}

/// One app: open, heartbeat until told to stop or reopen.
async fn app(shared: Arc<Shared>, n: usize, mut reopen: mpsc::Receiver<bool>) {
    let channel = shared.channels[n % shared.channels.len()].clone();
    let mut rng = rand::rngs::StdRng::seed_from_u64(n as u64);
    let mut stop = shared.stop.clone();
    let mut from_nothing = false;
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
                after_seq: shared.args.head,
                fold: schlift_core::FOLD.to_string(),
                pending_ids: Vec::new(),
                last_id: shared.args.last_id.clone(),
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
            tokio::select! {
                message = down.message() => match message {
                    Ok(Some(message)) => {
                        match message.kind {
                            Some(sync_response::Kind::Events(_) | sync_response::Kind::Account(_)) if first => {
                                shared.metrics.record(op, opened.elapsed());
                                first = false;
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
    let shared = Arc::new(Shared {
        args: args.clone(),
        metrics: Metrics::default(),
        channels,
        connected: AtomicUsize::new(0),
        beats: AtomicUsize::new(0),
        stop,
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

fn apps_spawn(shared: Arc<Shared>, n: usize, reopen: mpsc::Receiver<bool>) {
    tokio::spawn(app(shared, n, reopen));
}
