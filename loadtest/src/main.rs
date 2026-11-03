//! Load test. Lightweight clients each run the phone's own core
//! (schlift_native) against a real server: sign up with a software passkey,
//! sign in, onboard, then train and sync until the run ends. Afterwards every
//! client's event log is checked against what the server stored, and the
//! numbers are compared with a baseline. See docs/testing/load.md.

mod client;
mod metrics;
mod server;

use clap::Parser;
use client::{Client, Outcome, Role};
use metrics::{Metrics, OpSummary};
use schlift::workout::v1::sync_service_client::SyncServiceClient;
use schlift::workout::v1::PullEventsRequest;
use serde::{Deserialize, Serialize};
use server::{Server, Usage};
use std::collections::BTreeMap;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use tokio::sync::watch;
use tonic::transport::Channel;

#[derive(Parser)]
struct Args {
    /// smoke (a quick check, also run in CI) or scale (many clients).
    #[arg(long, default_value = "smoke")]
    profile: String,
    /// Clients, overriding the profile.
    #[arg(long)]
    clients: Option<usize>,
    /// Seconds each client trains, overriding the profile.
    #[arg(long)]
    seconds: Option<u64>,
    /// Connections to the server, overriding the profile.
    #[arg(long)]
    connections: Option<usize>,
    /// Test a server that is already running instead of starting one.
    #[arg(long)]
    server: Option<String>,
    #[arg(long, default_value = "target/release/schlift")]
    server_bin: PathBuf,
    #[arg(long, default_value = ".tmp/loadtest")]
    out: PathBuf,
    /// A report to compare with; the run fails if it is clearly slower.
    #[arg(long)]
    baseline: Option<PathBuf>,
}

/// How hard and how long to push.
#[derive(Clone, Copy, Serialize, Deserialize, Debug)]
pub struct Profile {
    pub clients: usize,
    /// Clients start spread over this.
    #[serde(with = "secs")]
    pub ramp: Duration,
    /// How long each client trains, from its own start: the run winds down
    /// over the ramp as it wound up.
    #[serde(with = "secs")]
    pub hold: Duration,
    /// Between workouts.
    #[serde(with = "secs")]
    pub idle: Duration,
    /// Between sets (compressed: a real rest is minutes).
    #[serde(with = "secs")]
    pub set_every: Duration,
    /// The app's heartbeat, and the watch's heart-rate batches.
    #[serde(with = "secs")]
    pub heartbeat: Duration,
    pub max_sets: usize,
    /// Clients that train in groups of three; the rest train alone.
    pub grouped: f64,
    /// Connections to the server, shared by the clients (as Caddy does).
    pub connections: usize,
}

impl Profile {
    fn named(name: &str) -> Option<Self> {
        let smoke = Profile {
            clients: 40,
            ramp: Duration::from_secs(5),
            hold: Duration::from_secs(40),
            idle: Duration::from_secs(3),
            set_every: Duration::from_secs(2),
            heartbeat: Duration::from_secs(5),
            max_sets: 12,
            grouped: 0.3,
            connections: 8,
        };
        match name {
            "smoke" => Some(smoke),
            "scale" => Some(Profile {
                clients: 1000,
                ramp: Duration::from_secs(60),
                hold: Duration::from_secs(120),
                idle: Duration::from_secs(10),
                set_every: Duration::from_secs(5),
                connections: 32,
                ..smoke
            }),
            _ => None,
        }
    }
}

mod secs {
    use serde::{Deserialize, Deserializer, Serializer};
    use std::time::Duration;
    pub fn serialize<S: Serializer>(d: &Duration, s: S) -> Result<S::Ok, S::Error> {
        s.serialize_f64(d.as_secs_f64())
    }
    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<Duration, D::Error> {
        Ok(Duration::from_secs_f64(f64::deserialize(d)?))
    }
}

#[derive(Serialize, Deserialize, Debug)]
struct Report {
    profile: String,
    settings: Profile,
    elapsed_seconds: f64,
    clients_finished: usize,
    client_errors: BTreeMap<String, usize>,
    events: usize,
    events_per_second: f64,
    /// Accounts whose log on the server is exactly the client's.
    accounts_matching: usize,
    accounts_differing: Vec<String>,
    server: Option<Usage>,
    /// Server CPU per event pushed, in milliseconds.
    server_cpu_ms_per_event: Option<f64>,
    ops: BTreeMap<String, OpSummary>,
}

#[tokio::main]
async fn main() {
    let args = Args::parse();
    let mut profile = Profile::named(&args.profile).unwrap_or_else(|| {
        eprintln!("unknown profile {}", args.profile);
        std::process::exit(2);
    });
    if let Some(clients) = args.clients {
        profile.clients = clients;
    }
    if let Some(seconds) = args.seconds {
        profile.hold = Duration::from_secs(seconds);
    }
    if let Some(connections) = args.connections {
        profile.connections = connections;
    }
    match run(&args, profile).await {
        Ok(passed) => std::process::exit(if passed { 0 } else { 1 }),
        Err(error) => {
            eprintln!("load test failed to run: {error}");
            std::process::exit(2);
        }
    }
}

async fn run(args: &Args, profile: Profile) -> Result<bool, String> {
    let run_id = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
        .to_string();
    std::fs::create_dir_all(&args.out).map_err(|e| e.to_string())?;
    let server = match &args.server {
        Some(_) => None,
        None => {
            Some(Server::spawn(&args.server_bin, &args.out.join(format!("data-{run_id}"))).await?)
        }
    };
    let url = match (&args.server, &server) {
        (Some(url), _) => url.clone(),
        (None, Some(server)) => server.url.clone(),
        (None, None) => unreachable!(),
    };
    let mut channels = Vec::new();
    for _ in 0..profile.connections.max(1) {
        channels.push(
            Channel::from_shared(url.clone())
                .map_err(|e| e.to_string())?
                .connect()
                .await
                .map_err(|e| format!("connecting to {url}: {e}"))?,
        );
    }
    println!(
        "{} clients, {:?} ramp, {:?} hold, against {url}",
        profile.clients, profile.ramp, profile.hold
    );

    let metrics = Arc::new(Metrics::default());
    let started = Instant::now();
    let mut clients = tokio::task::JoinSet::new();
    let mut leader: Option<watch::Sender<Option<String>>> = None;
    let grouped = (profile.clients as f64 * profile.grouped) as usize;
    for n in 0..profile.clients {
        let role = if n < grouped {
            if n % 3 == 0 {
                let (share, _) = watch::channel(None);
                leader = Some(share.clone());
                Role::Leads(share)
            } else {
                Role::Joins(leader.as_ref().expect("a leader first").subscribe())
            }
        } else {
            Role::Solo
        };
        let client = Client::new(
            n,
            &run_id,
            channels[n % channels.len()].clone(),
            metrics.clone(),
            profile,
        );
        // Each client trains for the hold from its own start, so the run
        // winds down as it wound up, not all at one instant.
        let (stop_tx, stop) = watch::channel(false);
        let hold = profile.hold;
        clients.spawn(async move {
            let timer = tokio::spawn(async move {
                tokio::time::sleep(hold).await;
                stop_tx.send_replace(true);
            });
            let outcome = client.run(role, stop).await;
            timer.abort();
            outcome
        });
        tokio::time::sleep(profile.ramp / profile.clients.max(1) as u32).await;
    }

    let mut outcomes: Vec<Outcome> = Vec::new();
    let mut client_errors: BTreeMap<String, usize> = BTreeMap::new();
    while let Some(joined) = clients.join_next().await {
        match joined {
            Ok(Ok(outcome)) => outcomes.push(outcome),
            Ok(Err(error)) => *client_errors.entry(error).or_default() += 1,
            Err(error) => *client_errors.entry(error.to_string()).or_default() += 1,
        }
    }
    let elapsed = started.elapsed().as_secs_f64();
    let usage = server.as_ref().map(Server::usage);

    let (matching, differing) = verify(&channels[0], &outcomes).await;
    let events: usize = outcomes.iter().map(|o| o.events.len()).sum();
    let report = Report {
        profile: args.profile.clone(),
        settings: profile,
        elapsed_seconds: elapsed,
        clients_finished: outcomes.len(),
        client_errors,
        events,
        events_per_second: events as f64 / elapsed,
        accounts_matching: matching,
        accounts_differing: differing,
        server_cpu_ms_per_event: usage
            .as_ref()
            .filter(|_| events > 0)
            .map(|u| u.cpu_seconds * 1000.0 / events as f64),
        server: usage,
        ops: metrics.summary(),
    };
    if let Some(server) = server {
        server.stop().await;
    }

    let path = args.out.join(format!("report-{}.json", args.profile));
    let json = serde_json::to_string_pretty(&report).map_err(|e| e.to_string())?;
    std::fs::write(&path, json).map_err(|e| e.to_string())?;
    print_report(&report);
    println!("report: {}", path.display());

    let mut failures = problems(&report);
    if let Some(baseline) = &args.baseline {
        let baseline: Report = serde_json::from_str(
            &std::fs::read_to_string(baseline)
                .map_err(|e| format!("{}: {e}", baseline.display()))?,
        )
        .map_err(|e| e.to_string())?;
        failures.extend(regressions(&baseline, &report));
    }
    for failure in &failures {
        println!("FAIL {failure}");
    }
    if failures.is_empty() {
        println!("PASS");
    }
    Ok(failures.is_empty())
}

/// Each client's log against the server's copy: the same events, in order.
async fn verify(channel: &Channel, outcomes: &[Outcome]) -> (usize, Vec<String>) {
    let mut matching = 0;
    let mut differing = Vec::new();
    for outcome in outcomes {
        let mut sync = SyncServiceClient::new(channel.clone());
        let mut request = tonic::Request::new(PullEventsRequest { after_seq: 0 });
        request.metadata_mut().insert(
            "x-session-token",
            outcome.token.parse().expect("ascii token"),
        );
        let pulled = match sync.pull_events(request).await {
            Ok(response) => schlift_core::sync::unpack(&response.into_inner().events),
            Err(status) => {
                differing.push(format!(
                    "{}: pull failed: {}",
                    outcome.username,
                    status.code()
                ));
                continue;
            }
        };
        match pulled {
            Ok(events) if events == outcome.events => matching += 1,
            Ok(events) => differing.push(format!(
                "{}: server holds {} events, client {}",
                outcome.username,
                events.len(),
                outcome.events.len()
            )),
            Err(error) => differing.push(format!("{}: {error}", outcome.username)),
        }
    }
    (matching, differing)
}

/// What fails a run on its own: errors and lost or diverging data.
fn problems(report: &Report) -> Vec<String> {
    let mut out = Vec::new();
    for (error, count) in &report.client_errors {
        out.push(format!("{count} clients stopped: {error}"));
    }
    for (op, summary) in &report.ops {
        for (error, count) in &summary.errors {
            out.push(format!("{op}: {count}x {error}"));
        }
    }
    for differing in &report.accounts_differing {
        out.push(format!("account differs: {differing}"));
    }
    if report.clients_finished == 0 {
        out.push("no client finished".into());
    }
    out
}

/// Clearly slower than the baseline: p95 latency up by half and 5 ms, or
/// server CPU per event or memory up by half.
fn regressions(baseline: &Report, report: &Report) -> Vec<String> {
    let mut out = Vec::new();
    for (op, before) in &baseline.ops {
        let Some(now) = report.ops.get(op) else {
            continue;
        };
        if before.count < 20 || before.p95_ms == 0.0 {
            continue;
        }
        let limit = before.p95_ms * 1.5 + 5.0;
        if now.p95_ms > limit {
            out.push(format!(
                "{op} p95 {:.1} ms, baseline {:.1} ms",
                now.p95_ms, before.p95_ms
            ));
        }
    }
    if let (Some(before), Some(now)) = (
        baseline.server_cpu_ms_per_event,
        report.server_cpu_ms_per_event,
    ) {
        if now > before * 1.5 + 0.05 {
            out.push(format!(
                "server CPU {now:.3} ms/event, baseline {before:.3}"
            ));
        }
    }
    if let (Some(before), Some(now)) = (&baseline.server, &report.server) {
        if now.rss_max_mb > before.rss_max_mb * 1.5 + 32.0 {
            out.push(format!(
                "server memory {:.0} MB, baseline {:.0} MB",
                now.rss_max_mb, before.rss_max_mb
            ));
        }
    }
    out
}

fn print_report(report: &Report) {
    println!(
        "\n{} clients finished in {:.0} s: {} events ({:.0}/s), {} accounts match the server",
        report.clients_finished,
        report.elapsed_seconds,
        report.events,
        report.events_per_second,
        report.accounts_matching
    );
    if let Some(usage) = &report.server {
        println!(
            "server: {:.1} CPU s ({:.3} ms/event), {:.0} MB max RSS, {:.1} MB on disk",
            usage.cpu_seconds,
            report.server_cpu_ms_per_event.unwrap_or(0.0),
            usage.rss_max_mb,
            usage.db_mb
        );
    }
    println!(
        "\n{:<30} {:>8} {:>7} {:>9} {:>9} {:>9} {:>9}",
        "operation", "count", "errors", "p50 ms", "p95 ms", "p99 ms", "max ms"
    );
    for (op, s) in &report.ops {
        let errors: u64 = s.errors.values().sum();
        println!(
            "{op:<30} {:>8} {errors:>7} {:>9.2} {:>9.2} {:>9.2} {:>9.2}",
            s.count, s.p50_ms, s.p95_ms, s.p99_ms, s.max_ms
        );
    }
}
