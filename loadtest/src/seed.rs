//! Test workouts for any account on a dev backend: `make seed-workouts
//! ACCOUNT=<name>`. A seeded lifter (schlift_testkit) trains `--weeks` of
//! history through the phone's own core, ending yesterday, at irregular
//! times as people do: a day or a few between sessions, mornings, lunches
//! and evenings, now and then a week or two away, and a break of a month or
//! two after every five months to a year. The workouts it finished go into
//! the account as history imports, pushed up the sync stream as a phone
//! would. A phone signed in as that user gets them live.
//!
//! Signs in with dev login (`TestLogin`), so only a backend built with
//! `test-auth` takes it: `make run-backend`, never production. The same seed
//! makes the same workouts at the same times. Each run adds them again under
//! new ids; `--replace` first discards what earlier imports brought in.

use clap::Parser;
use rand::rngs::StdRng;
use rand::{Rng, SeedableRng};
use schlift::workout::v1::auth_service_client::AuthServiceClient;
use schlift::workout::v1::sync_service_client::SyncServiceClient;
use schlift::workout::v1::*;
use schlift_core::account::Account;
use schlift_core::events::{Event, Fact};
use schlift_native::store::Store;
use schlift_testkit::Lifter;
use std::path::Path;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::sync::mpsc;
use tokio_stream::wrappers::ReceiverStream;
use tonic::Request;

/// Past any version gate a dev backend sets.
const APP_VERSION: &str = "999.0.0";

const DAY: i64 = 86_400;

/// Workouts in one history import: a long history goes in as several, each
/// a modest event to store and send.
const IMPORT_WORKOUTS: usize = 20;

#[derive(Parser)]
struct Args {
    /// The account to add workouts to; dev login makes it if it is new.
    #[arg(long)]
    user: String,
    /// Weeks of history, ending yesterday, time off included.
    #[arg(long, default_value_t = 16)]
    weeks: u32,
    /// Workouts a week, on average, while training.
    #[arg(long, default_value_t = 3)]
    per_week: u32,
    /// The lifter's habits: the same seed, the same workouts.
    #[arg(long, default_value_t = 1)]
    seed: u64,
    /// The phone's offset from UTC, as `date +%z` prints it: the times of
    /// day are local.
    #[arg(long, default_value = "+0000", allow_hyphen_values = true)]
    utc_offset: String,
    /// Discard the workouts earlier history imports brought in first.
    #[arg(long)]
    replace: bool,
    #[arg(long, default_value = "http://127.0.0.1:50051")]
    server: String,
}

fn now_unix() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |d| d.as_secs() as i64)
}

/// "+hhmm" or "-hhmm", in seconds.
fn offset_seconds(offset: &str) -> Result<i64, String> {
    let bad = || format!("--utc-offset {offset}: expected +hhmm or -hhmm");
    let (sign, digits) = match offset.split_at_checked(1) {
        Some(("+", d)) => (1, d),
        Some(("-", d)) => (-1, d),
        _ => return Err(bad()),
    };
    if digits.len() != 4 {
        return Err(bad());
    }
    let hours: i64 = digits[..2].parse().map_err(|_| bad())?;
    let minutes: i64 = digits[2..].parse().map_err(|_| bad())?;
    Ok(sign * (hours * 3_600 + minutes * 60))
}

/// When the lifter trains over the weeks asked for, ending before `until`
/// (unix seconds; the times of day `offset` seconds from UTC). Between
/// sessions, a day or a few around `per_week`'s pace, now and then a week
/// or two; after every five months to a year, three to nine weeks off. Most
/// sessions in the evening, some in the morning, the odd one at lunch.
fn schedule(args: &Args, until: i64, offset: i64) -> Vec<i64> {
    let mut rng = StdRng::seed_from_u64(args.seed);
    let pace = 7.0 / f64::from(args.per_week.max(1));
    let mut day = until - i64::from(args.weeks) * 7 * DAY;
    let mut next_break = day + rng.gen_range(150..365) * DAY;
    let mut starts = Vec::new();
    loop {
        let gap = if rng.gen_bool(0.06) {
            rng.gen_range(6..15)
        } else {
            ((pace * rng.gen_range(0.4..1.7)).round() as i64).max(1)
        };
        day += gap * DAY;
        if day >= next_break {
            day += rng.gen_range(21..64) * DAY;
            next_break = day + rng.gen_range(150..365) * DAY;
        }
        let midnight = day - (day + offset).rem_euclid(DAY);
        let hour = match rng.gen_range(0..20) {
            0..=4 => rng.gen_range(6..9),
            5..=7 => rng.gen_range(11..14),
            _ => rng.gen_range(16..21),
        };
        let start = midnight + hour * 3_600 + rng.gen_range(0..3_600);
        if start >= until {
            return starts;
        }
        starts.push(start);
    }
}

/// The workouts a fresh lifter records on that schedule, heart rate and
/// all, as imports.
fn workouts(args: &Args) -> Result<Vec<ImportHistory>, String> {
    let now = now_unix();
    let starts = schedule(args, now - DAY, offset_seconds(&args.utc_offset)?);
    let mut store = Store::open(Path::new(":memory:"), "seed", "seed")?;
    let mut lifter = Lifter::new(args.seed);
    schlift_testkit::onboard(&mut store, starts.first().map_or(now, |s| s - DAY))?;
    for start in starts {
        schlift_testkit::workout(&mut store, &mut lifter, start)?;
    }
    let account = Account::fold(&store.pending()?);
    let finished: Vec<ImportedWorkout> = account
        .workouts
        .into_iter()
        .filter(|r| r.workout.end_time > 0)
        .map(|r| ImportedWorkout {
            workout: Some(r.workout),
            proposed_sets: r.proposed_sets,
            completed_sets: r.completed_sets,
            heart_rate: r.heart_rate,
            exercise_logs: r.exercise_logs,
        })
        .collect();
    Ok(finished
        .chunks(IMPORT_WORKOUTS)
        .map(|chunk| ImportHistory {
            workouts: chunk.to_vec(),
            starting_weights: Vec::new(),
        })
        .collect())
}

/// The workouts history imports brought into the account that it still
/// holds (none discarded since).
fn imported(events: &[Event]) -> Vec<String> {
    let account = Account::fold(events);
    events
        .iter()
        .filter_map(|e| match &e.fact {
            Fact::HistoryImported(h) => Some(h),
            _ => None,
        })
        .flat_map(|h| &h.workouts)
        .filter_map(|w| w.workout.as_ref().map(|w| w.id.clone()))
        .filter(|id| account.workouts.iter().any(|r| &r.workout.id == id))
        .collect()
}

/// The server's next message on the stream.
async fn next(down: &mut tonic::Streaming<SyncResponse>) -> Result<SyncResponse, String> {
    tokio::time::timeout(Duration::from_secs(60), down.message())
        .await
        .map_err(|_| "the server went quiet".to_string())?
        .map_err(|s| s.to_string())?
        .ok_or_else(|| "the server hung up".to_string())
}

fn request<T>(message: T, token: &str) -> Request<T> {
    let mut request = Request::new(message);
    let metadata = request.metadata_mut();
    if !token.is_empty() {
        metadata.insert("x-session-token", token.parse().expect("ascii token"));
    }
    metadata.insert("x-app-version", APP_VERSION.parse().expect("ascii"));
    metadata.insert("x-platform", "seed".parse().expect("ascii"));
    request
}

async fn run(args: Args) -> Result<(), String> {
    let imports = workouts(&args)?;
    let count: usize = imports.iter().map(|i| i.workouts.len()).sum();

    let channel = tonic::transport::Endpoint::from_shared(args.server.clone())
        .map_err(|e| e.to_string())?
        .connect()
        .await
        .map_err(|e| format!("{}: {e}", args.server))?;
    let signed_in = AuthServiceClient::new(channel.clone())
        .test_login(request(
            TestLoginRequest {
                username: args.user.clone(),
            },
            "",
        ))
        .await
        .map_err(|s| format!("dev login: {}", s.message()))?
        .into_inner();

    // The stream opens from the start: the account as it stands comes down
    // first, up to the server's head.
    let (up, rx) = mpsc::channel(16);
    let send = |kind| {
        let up = up.clone();
        async move {
            up.send(SyncRequest { kind: Some(kind) })
                .await
                .map_err(|_| "sync stream closed".to_string())
        }
    };
    send(sync_request::Kind::AfterSeq(0)).await?;
    let mut down = SyncServiceClient::new(channel)
        .max_decoding_message_size(64 << 20)
        .sync(request(ReceiverStream::new(rx), &signed_in.session_token))
        .await
        .map_err(|s| format!("sync: {}", s.message()))?
        .into_inner();
    let mut held: Vec<Event> = Vec::new();
    let head = loop {
        if let Some(sync_response::Kind::Events(events)) = next(&mut down).await?.kind {
            if !events.packed.is_empty() {
                let batch =
                    schlift_core::sync::unpack(&events.packed).map_err(|e| e.to_string())?;
                held.extend(batch);
            }
            if held.last().map_or(0, |e| e.seq) >= events.head {
                break events.head;
            }
        }
    };

    // What to send, as this account's own events, made by its core.
    let mut store = Store::open(
        Path::new(":memory:"),
        &signed_in.user_id,
        &signed_in.username,
    )?;
    store.receive(held.clone(), head)?;
    let replaced = if args.replace {
        imported(&held)
    } else {
        Vec::new()
    };
    for workout_id in &replaced {
        store.call(
            "DiscardWorkout",
            &prost::Message::encode_to_vec(&DiscardWorkoutRequest {
                workout_id: workout_id.clone(),
            }),
            now_unix(),
        )?;
    }
    for import in &imports {
        store.call(
            "ImportHistory",
            &prost::Message::encode_to_vec(import),
            now_unix(),
        )?;
    }
    let events = store.pending()?;
    let last = events
        .last()
        .map(|e| e.id.clone())
        .ok_or("nothing to push")?;

    // An event a push, each well inside what the server takes at once, then
    // wait for the last to come back placed.
    for event in &events {
        send(sync_request::Kind::Events(schlift_core::sync::pack(
            std::slice::from_ref(event),
        )))
        .await?;
    }
    loop {
        if let Some(sync_response::Kind::Events(events)) = next(&mut down).await?.kind {
            if !events.packed.is_empty()
                && schlift_core::sync::unpack(&events.packed)
                    .map_err(|e| e.to_string())?
                    .iter()
                    .any(|e| e.id == last)
            {
                break;
            }
        }
    }
    if !replaced.is_empty() {
        println!(
            "{} imported workouts discarded from {}",
            replaced.len(),
            signed_in.username
        );
    }
    println!(
        "{count} workouts over {} weeks added to {}",
        args.weeks, signed_in.username
    );
    Ok(())
}

#[tokio::main]
async fn main() {
    if let Err(e) = run(Args::parse()).await {
        eprintln!("seed: {e}");
        std::process::exit(1);
    }
}
