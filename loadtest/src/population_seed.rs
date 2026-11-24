//! A million existing accounts for the population test (`schlift-population`),
//! written straight into a server's data directory before it starts: the
//! users, a login each (its token derived from the user's number, so the
//! load clients need nothing passed to them), each account's history as
//! the ledger stores it (Parquet files under `events/`, indexed in
//! `event_files`), and its snapshot.
//!
//! Every account holds the same history (a lifter trained `--weeks` through
//! the phone's own core, schlift_testkit), under its own user id: the shape
//! and size of a real account, written in minutes rather than played in
//! over days. Only for a throwaway server's data directory: it writes the
//! tables directly.
//!
//!   seed-population --data DIR --users 1000000 --weeks 4
//!
//! The directory must hold a migrated database (start the server on it
//! once). Prints the seq and last event id every account ends at, which the
//! idle clients open with.

use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Instant;

use arrow_array::{ArrayRef, BooleanArray, Int64Array, RecordBatch, StringArray};
use arrow_schema::{DataType, Field, Schema};
use clap::Parser;
use parquet::arrow::ArrowWriter;
use parquet::basic::{Compression, ZstdLevel};
use parquet::file::properties::WriterProperties;
use rusqlite::{params, Connection};
use schlift_core::account::Account;
use schlift_core::events::{Event, Fact};
use schlift_native::store::Store;
use schlift_testkit::{history, onboard, Lifter};
use sha2::{Digest, Sha256};

#[derive(Parser)]
struct Args {
    /// Print the rules this build folds by (schlift_core::FOLD) and stop.
    #[arg(long)]
    print_fold: bool,
    /// Check, instead of seeding, that the data directory's snapshots read
    /// by this build's rules, as the server reads them: the stamp inside
    /// each snapshot, not the `fold` column. A server built from another
    /// commit would refold every account from the files, which a load test
    /// must not mistake for the server's own cost. Never restamp snapshots
    /// by SQL to get round it (the column alone isn't the stamp): seed again.
    #[arg(long)]
    check: bool,
    #[arg(long, default_value = ".")]
    data: PathBuf,
    #[arg(long, default_value_t = 1_000_000)]
    users: usize,
    /// Weeks of history every account holds (three workouts a week).
    #[arg(long, default_value_t = 4)]
    weeks: u32,
    /// Every this many accounts, one holds `--long-weeks` of history
    /// instead (0: none): the long-standing users, with their larger
    /// snapshots.
    #[arg(long, default_value_t = 10)]
    long_every: usize,
    #[arg(long, default_value_t = 52)]
    long_weeks: u32,
    /// Write the snapshots only, not the event files behind them: nothing
    /// in normal running reads those (only a refold after the rules change
    /// does), and a year of history for every account outgrows the disk.
    #[arg(long)]
    snapshots_only: bool,
    /// Accounts written per transaction and per file.
    #[arg(long, default_value_t = 20_000)]
    batch: usize,
}

/// The id of population user `n`: what the load clients derive too.
pub fn user_id(n: usize) -> String {
    format!("00000000-0000-4000-8000-{n:012}")
}

/// The login token of population user `n`.
pub fn token(n: usize) -> String {
    format!("population-login-{n:012}")
}

fn token_hash(token: &str) -> String {
    Sha256::digest(token.as_bytes())
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect()
}

fn now() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_or(0, |d| d.as_secs() as i64)
}

/// The history every account holds, placed: 1, 2, … in order.
fn template(weeks: u32) -> Vec<Event> {
    let dir = std::env::temp_dir().join(format!("population-template-{}", std::process::id()));
    std::fs::create_dir_all(&dir).expect("temp dir");
    let mut store = Store::open(
        &dir.join("t.sqlite"),
        "00000000-0000-4000-8000-ffffffffffff",
        "",
    )
    .expect("store");
    let until = now() - 86_400;
    let begin = until - i64::from(weeks) * 7 * 86_400 - 86_400;
    onboard(&mut store, begin).expect("onboard");
    let mut lifter = Lifter::new(7);
    history(&mut store, &mut lifter, weeks, 3, until).expect("history");
    let mut events = store.pending().expect("pending");
    for (n, event) in events.iter_mut().enumerate() {
        event.seq = n as i64 + 1;
    }
    let _ = std::fs::remove_dir_all(&dir);
    events
}

/// One history accounts are seeded with, as the ledger stores it.
struct Kind {
    weeks: u32,
    events: Vec<Event>,
    json: Vec<String>,
    head: i64,
    last_id: String,
    workouts: usize,
    snapshot: Vec<u8>,
    recent: String,
}

impl Kind {
    fn new(weeks: u32) -> Self {
        let events = template(weeks);
        let json = events
            .iter()
            .map(|e| serde_json::to_string(e).expect("event"))
            .collect();
        let head = events.len() as i64;
        let last_id = events.last().map(|e| e.id.clone()).unwrap_or_default();
        let account = Account::fold_without_heart_rate(&events);
        let recent: Vec<&str> = events
            .iter()
            .rev()
            .take(2_000)
            .rev()
            .map(|e| e.id.as_str())
            .collect();
        Self {
            weeks,
            json,
            head,
            last_id,
            workouts: account.workouts.len(),
            snapshot: schlift_core::snapshot::snapshot(&account, head),
            recent: serde_json::to_string(&recent).expect("ids"),
            events,
        }
    }
}

fn schema() -> Arc<Schema> {
    Arc::new(Schema::new(vec![
        Field::new("user_id", DataType::Utf8, false),
        Field::new("seq", DataType::Int64, false),
        Field::new("id", DataType::Utf8, false),
        Field::new("at", DataType::Int64, false),
        Field::new("heart_rate", DataType::Boolean, false),
        Field::new("event", DataType::Utf8, false),
    ]))
}

/// One file of `users` accounts' events, as the ledger writes them (sorted
/// by account, then seq), synced.
fn write_file(path: &Path, users: &[String], events: &[Event], json: &[String]) {
    let per = events.len();
    let rows = users.len() * per;
    let user_col = StringArray::from_iter_values((0..rows).map(|i| users[i / per].as_str()));
    let seq_col = Int64Array::from_iter_values((0..rows).map(|i| events[i % per].seq));
    let id_col = StringArray::from_iter_values((0..rows).map(|i| events[i % per].id.as_str()));
    let at_col = Int64Array::from_iter_values((0..rows).map(|i| events[i % per].at));
    let hr_col = BooleanArray::from(
        (0..rows)
            .map(|i| matches!(events[i % per].fact, Fact::HeartRateRecorded(_)))
            .collect::<Vec<_>>(),
    );
    let event_col = StringArray::from_iter_values((0..rows).map(|i| json[i % per].as_str()));
    let batch = RecordBatch::try_new(
        schema(),
        vec![
            Arc::new(user_col) as ArrayRef,
            Arc::new(seq_col),
            Arc::new(id_col),
            Arc::new(at_col),
            Arc::new(hr_col),
            Arc::new(event_col),
        ],
    )
    .expect("batch");
    let props = WriterProperties::builder()
        .set_compression(Compression::ZSTD(ZstdLevel::try_new(3).expect("level")))
        .set_max_row_group_size(8_192)
        .build();
    let file = std::fs::File::create(path).expect("create");
    let mut writer = ArrowWriter::try_new(file, schema(), Some(props)).expect("writer");
    writer.write(&batch).expect("write");
    writer
        .into_inner()
        .expect("close")
        .sync_all()
        .expect("sync");
}

fn main() {
    let args = Args::parse();
    if args.print_fold {
        println!("{}", schlift_core::FOLD);
        return;
    }
    if args.check {
        check(&args.data);
        return;
    }
    let started = Instant::now();
    let short = Kind::new(args.weeks);
    let long = (args.long_every > 0).then(|| Kind::new(args.long_weeks));
    for kind in std::iter::once(&short).chain(&long) {
        println!(
            "template: {} weeks, {} events ({} workouts), snapshot {} KB, built in {:.1}s",
            kind.weeks,
            kind.events.len(),
            kind.workouts,
            kind.snapshot.len() / 1000,
            started.elapsed().as_secs_f64()
        );
    }
    let kind_of = |i: usize| match &long {
        Some(long) if i.is_multiple_of(args.long_every) => long,
        _ => &short,
    };

    let events_dir = args.data.join("events");
    std::fs::create_dir_all(&events_dir).expect("events dir");
    let mut db = Connection::open(args.data.join("server.sqlite")).expect("database");
    db.execute_batch("PRAGMA journal_mode=WAL; PRAGMA synchronous=OFF; PRAGMA cache_size=-262144;")
        .expect("pragmas");
    let created = now();
    let expires = created + 400 * 86_400;
    let mut n = 0;
    let mut part = 0;
    while n < args.users {
        let end = (n + args.batch).min(args.users);
        let mut files = Vec::new();
        for (k, kind) in std::iter::once(&short).chain(&long).enumerate() {
            let users: Vec<String> = (n..end)
                .filter(|&i| std::ptr::eq(kind_of(i), kind))
                .map(user_id)
                .collect();
            if users.is_empty() || args.snapshots_only {
                continue;
            }
            let file = format!("0000000001000-population-{part:06}-{k}.parquet");
            write_file(&events_dir.join(&file), &users, &kind.events, &kind.json);
            files.push((file, kind));
        }
        let tx = db.transaction().expect("tx");
        {
            let mut user = tx
                .prepare_cached(
                    "INSERT OR IGNORE INTO users (id, username, invite_token, created_at, emoji, color_hex)
                     VALUES (?, ?, ?, ?, '🏋️', '#4F7CAC')",
                )
                .expect("users");
            let mut login = tx
                .prepare_cached(
                    "INSERT OR IGNORE INTO logins (token_hash, user_id, expires_at) VALUES (?, ?, ?)",
                )
                .expect("logins");
            let mut snap = tx
                .prepare_cached(
                    "INSERT OR REPLACE INTO account_snapshots
                         (user_id, seq, fold, state, recent_ids, updated_at, last_id)
                     VALUES (?1, ?2, ?3, ?4, ?5, ?6, coalesce(?5 ->> '$[#-1]', ''))",
                )
                .expect("snapshots");
            let mut index = tx
                .prepare_cached(
                    "INSERT OR IGNORE INTO event_files (file, user_id, min_seq, max_seq, events)
                     VALUES (?, ?, 1, ?, ?)",
                )
                .expect("index");
            for i in n..end {
                let id = &user_id(i);
                let kind = kind_of(i);
                let file = files.iter().find(|(_, k)| std::ptr::eq(*k, kind));
                user.execute(params![
                    id,
                    format!("p{i}"),
                    format!("invite-{i:012}"),
                    created
                ])
                .expect("user");
                login
                    .execute(params![token_hash(&token(i)), id, expires])
                    .expect("login");
                snap.execute(params![
                    id,
                    kind.head,
                    schlift_core::FOLD,
                    kind.snapshot,
                    kind.recent,
                    created
                ])
                .expect("snapshot");
                if let Some((file, _)) = file {
                    index
                        .execute(params![file, id, kind.head, kind.head])
                        .expect("index");
                }
            }
        }
        tx.commit().expect("commit");
        n = end;
        part += 1;
        if part % 10 == 0 || n == args.users {
            println!("{n} accounts in {:.0}s", started.elapsed().as_secs_f64());
        }
    }
    println!("head {} last_id {}", short.head, short.last_id);
    if let Some(long) = &long {
        println!(
            "long every {} head {} last_id {}",
            args.long_every, long.head, long.last_id
        );
    }
}

/// The seeded snapshots read by this build's rules, or the process fails
/// saying how many don't (see `--check`).
fn check(data: &Path) {
    let db = Connection::open(data.join("server.sqlite")).expect("database");
    let total: i64 = db
        .query_row("SELECT COUNT(*) FROM account_snapshots", [], |r| r.get(0))
        .expect("count");
    let mut sample = db
        .prepare("SELECT user_id, state FROM account_snapshots ORDER BY random() LIMIT 200")
        .expect("sample");
    let rows: Vec<(String, Vec<u8>)> = sample
        .query_map([], |r| Ok((r.get(0)?, r.get(1)?)))
        .expect("rows")
        .collect::<Result<_, _>>()
        .expect("rows");
    let bad: Vec<String> = rows
        .iter()
        .filter_map(|(user, state)| {
            schlift_core::snapshot::restore(state)
                .err()
                .map(|e| format!("{user}: {e}"))
        })
        .collect();
    if !bad.is_empty() {
        eprintln!(
            "{} of {} sampled snapshots (of {total}) don't read by this build's rules ({}); \
             seed again with this build:\n  {}",
            bad.len(),
            rows.len(),
            schlift_core::FOLD,
            bad.iter().take(3).cloned().collect::<Vec<_>>().join("\n  ")
        );
        std::process::exit(1);
    }
    println!(
        "{} sampled snapshots (of {total}) read by this build's rules ({})",
        rows.len(),
        schlift_core::FOLD
    );
}
