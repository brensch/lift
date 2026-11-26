//! The ledger: every account's events and its snapshot, kept so that a
//! push costs a few memory writes, a read costs one snapshot read, and
//! nothing in normal running reads the event files.
//!
//! - **The phone is the storage until a workout ends.** It holds every
//!   event it records until it hears it back placed (its ack), and sends
//!   what it holds again on every new stream. The server holds an account's
//!   unacked events in memory, and only those: no folded account.
//! - **Partners see each event at once** (`Change::Live`), unplaced.
//! - **An account is written when its workout ends** (or a write outside a
//!   workout goes quiet, or for a write no phone holds at once, or when
//!   memory runs short): its events get their places, go into the events
//!   file of that batch (one Parquet file for every account written
//!   together, every couple of seconds), its heart rate into the batch's
//!   heart-rate file, and its new snapshot (the old one with the events
//!   folded on) into `account_snapshots`, all synced, in one go; then the
//!   devices hear the events placed (`Change::Account`), which is their
//!   ack, and the events leave memory. So a snapshot always holds every
//!   event written: an account's head is its snapshot's seq.
//! - **A read** (the website, an assistant) folds the snapshot and the
//!   events in memory, answers, and drops it: the set done a moment ago is
//!   in it.
//! - **After a restart** the server holds snapshots only; the phones send
//!   what they hold again. The files are read only to fold an account again
//!   after a release changes the rules (its snapshot is by other ones), and
//!   by compaction (`compact`).
//!
//! The files are only ever added to (compaction writes new ones and drops
//! the old once the index points at the new). Deleting an account removes
//! its index rows and snapshot; its events stay in the files under an id
//! nothing points to.

pub mod compact;
pub mod files;
#[cfg(test)]
mod tests;

use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use schlift_core::account::Account;
use schlift_core::events::{Event, Fact};
use schlift_core::session::{shared_with_partners, SHOWN_FOR_SECONDS};
use sqlx::{Pool, Sqlite};
use tokio::sync::{oneshot, Notify};

use super::changes::Changes;
use super::{Change, DbResult, Topic};
use crate::time::now_unix;
use files::{Beats, Row};

/// The ledger's timings and memory, from the environment.
#[derive(Clone, Copy, Debug)]
pub struct Timing {
    /// How often accounts due a write are written, together.
    pub batch_every: Duration,
    /// A workout with nothing new for this long is written as it is
    /// (walked off from, or the app killed).
    pub abandoned: Duration,
    /// A write outside a workout (a setting, the program) waits this long
    /// for more before it is written.
    pub quiet: Duration,
    /// Past this many bytes of events held, the workouts held longest are
    /// written early (and acked) until under it again.
    pub memory_budget: usize,
}

impl Timing {
    pub fn from_env() -> Self {
        let ms = |name: &str, default: u64| {
            Duration::from_millis(
                std::env::var(name)
                    .ok()
                    .and_then(|v| v.parse().ok())
                    .unwrap_or(default),
            )
        };
        let test = cfg!(test);
        Self {
            batch_every: ms("LEDGER_BATCH_MS", if test { 10 } else { 2_000 }),
            // In tests a workout is written soon after its last event, as
            // the tests of streams expect events placed as they go; the
            // ledger's own tests hold them with `Timing` of their own.
            abandoned: ms("LEDGER_ABANDONED_MS", if test { 100 } else { 30 * 60_000 }),
            quiet: ms("LEDGER_QUIET_MS", if test { 50 } else { 90_000 }),
            memory_budget: std::env::var("LEDGER_MEMORY_MB")
                .ok()
                .and_then(|v| v.parse::<usize>().ok())
                .unwrap_or(8_192)
                << 20,
        }
    }
}

/// The ids of snapshot events kept with it: those a phone that lost its ack
/// is told are placed.
const RECENT_IDS: usize = 2_000;

/// Statements a batch's snapshot reads are split across, at once, on their
/// own connections (`Ledger::snapshot_pool`): a cold snapshot is a few
/// random page reads, and the disk serves many more at once than the
/// read pool's sixteen ask for.
const SNAPSHOT_READERS: usize = 64;

/// Accounts written in one batch at most.
const ACCOUNTS_PER_BATCH: usize = 5_000;

/// An account holding more than this is written at the next batch, under
/// way or not: one account can't fill the server's memory however it
/// pushes (a long workout's events are a few hundred KB).
const MAX_HELD_BYTES_PER_ACCOUNT: usize = 32 << 20;
const MAX_HELD_EVENTS_PER_ACCOUNT: usize = 20_000;

/// Sets planned by the held events of one account past this are refused:
/// folding a workout costs with the sets it holds, on the server and on
/// every partner's phone (a real workout plans a few dozen).
const MAX_PLANNED_SETS_HELD: usize = 2_000;

/// An account whose write failed is tried again this much later, not with
/// every batch.
const FAILED_RETRY: Duration = Duration::from_secs(60);

/// One account, in memory.
#[derive(Default)]
struct Log {
    loaded: bool,
    /// The account exists (a push to one deleted, or never made, fails).
    exists: bool,
    /// The last seq written: the snapshot's.
    head: i64,
    /// The id of the event at `head`.
    last_id: String,
    /// Its snapshot is by these rules (else it is folded again from the
    /// files when next needed).
    snapshot_ours: bool,
    /// Pushed, not yet written: in order.
    unacked: Vec<Arc<Event>>,
    unacked_ids: HashSet<String>,
    /// Bytes `unacked` holds, roughly.
    bytes: usize,
    /// The workout under way (its id, or empty): from the snapshot, then
    /// the events held. While there is one, the account waits for its end.
    active: String,
    /// When the oldest unacked event came.
    since: Option<Instant>,
    /// Writes waiting on this account's next write (a write no phone holds).
    waiters: Vec<oneshot::Sender<Vec<Event>>>,
    /// Workouts written recently whose owner is in a session: what a
    /// partner who appears later is sent of them, until `SHOWN_FOR_SECONDS`.
    shown: Vec<(String, i64, Vec<Arc<Event>>)>,
    last_used: Option<Instant>,
}

impl Log {
    /// The shared events of a workout, from those held unacked and shown.
    fn workout(&self, workout_id: &str) -> Vec<Event> {
        let mut events: Vec<Event> = self
            .shown
            .iter()
            .filter(|(w, _, _)| w == workout_id)
            .flat_map(|(_, _, e)| e.iter().map(|e| (**e).clone()))
            .collect();
        events.extend(
            self.unacked
                .iter()
                .filter(|e| e.workout_id() == Some(workout_id) && shared_with_partners(&e.fact))
                .map(|e| (**e).clone()),
        );
        events
    }
}

pub struct Ledger {
    dir: PathBuf,
    read_pool: Pool<Sqlite>,
    /// Where an account is, read as it loads (`Ledger::load`).
    reader: Arc<super::reader::Reader>,
    /// A batch's snapshot reads, apart from every other read.
    snapshot_pool: Pool<Sqlite>,
    write_pool: Pool<Sqlite>,
    changes: Arc<Changes>,
    timing: Timing,
    users: Mutex<HashMap<String, Arc<tokio::sync::Mutex<Log>>>>,
    /// Accounts holding unacked events, and when each is due a write.
    due: Mutex<HashMap<String, Instant>>,
    /// Bytes of events held across accounts, roughly.
    held: AtomicUsize,
    wake: Arc<Notify>,
    /// One write at a time: each assigns places from the heads the last left.
    writing: tokio::sync::Mutex<()>,
    files_written: AtomicU64,
    /// Set in tests to stand for a process that died: nothing more writes.
    stopped: std::sync::atomic::AtomicBool,
}

fn json(event: &Event) -> String {
    // Plain data to a string: can't fail.
    serde_json::to_string(event).expect("an event serialises")
}

fn is_heart_rate(event: &Event) -> bool {
    matches!(event.fact, Fact::HeartRateRecorded(_))
}

/// The fact's name, as the event's JSON writes it: the key after `at`.
fn kind_of(json: &str) -> String {
    let Some(at) = json.find("\"at\":") else {
        return String::new();
    };
    let rest = &json[at..];
    let Some(comma) = rest.find(",\"") else {
        return String::new();
    };
    let rest = &rest[comma + 2..];
    rest.split('"').next().unwrap_or_default().to_string()
}

fn approx_bytes(event: &Event) -> usize {
    // What the event holds, as its JSON (a phone chose its strings and
    // lists: a guess by kind let a few huge events count as small ones),
    // and at least the guess by kind.
    struct Count(usize);
    impl std::io::Write for Count {
        fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
            self.0 += buf.len();
            Ok(buf.len())
        }
        fn flush(&mut self) -> std::io::Result<()> {
            Ok(())
        }
    }
    let mut count = Count(0);
    let _ = serde_json::to_writer(&mut count, event);
    let floor = match &event.fact {
        Fact::HeartRateRecorded(h) => 128 + h.bpm.len() * 6,
        Fact::WorkoutStarted(_) => 8_192,
        _ => 384,
    };
    count.0.max(floor)
}

/// The sets a held event plans: a workout's start and its added lifts,
/// and the set count an adjust asks for.
fn planned_sets(event: &Event) -> usize {
    let sets = |decisions: &[schlift_core::pb::ExerciseDecision]| {
        decisions
            .iter()
            .map(|d| usize::try_from(d.sets).unwrap_or(0))
            .sum::<usize>()
    };
    match &event.fact {
        Fact::WorkoutStarted(started) => sets(&started.decisions),
        Fact::ExercisesAdded(added) => sets(&added.decisions),
        Fact::ExerciseAdjusted(adjusted) => usize::try_from(adjusted.sets).unwrap_or(0),
        _ => 0,
    }
}

/// A push the ledger refuses: what the caller is told.
#[derive(Debug)]
pub struct Refused(pub &'static str);

impl std::fmt::Display for Refused {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.0)
    }
}

impl std::error::Error for Refused {}

fn now_ms() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_or(0, |d| d.as_millis() as i64)
}

/// An account moved in from SQLite: its id, seq, snapshot, latest ids and
/// workout under way.
type Moved = (String, i64, Vec<u8>, String, String);

/// An account's held events taken for a write: who, its log, the events,
/// its head and the writes waiting on it.
type Taken = (
    String,
    Arc<tokio::sync::Mutex<Log>>,
    Vec<Arc<Event>>,
    i64,
    Vec<oneshot::Sender<Vec<Event>>>,
);

impl Ledger {
    /// The ledger over `data_dir`, its index reconciled with the files
    /// there, and the events of a database from before it moved in.
    pub(super) async fn open(
        data_dir: &Path,
        read_pool: Pool<Sqlite>,
        reader: Arc<super::reader::Reader>,
        write_pool: Pool<Sqlite>,
        changes: Arc<Changes>,
        timing: Timing,
    ) -> DbResult<Arc<Self>> {
        let dir = data_dir.to_path_buf();
        std::fs::create_dir_all(dir.join("events"))?;
        std::fs::create_dir_all(dir.join("heart_rate"))?;
        let snapshot_pool = sqlx::sqlite::SqlitePoolOptions::new()
            .max_connections(SNAPSHOT_READERS as u32)
            .min_connections(0)
            .idle_timeout(Duration::from_secs(60))
            .connect_lazy_with((*read_pool.connect_options()).clone().read_only(true));
        let ledger = Arc::new(Self {
            dir,
            snapshot_pool,
            read_pool,
            reader,
            write_pool,
            changes,
            timing,
            users: Mutex::new(HashMap::new()),
            due: Mutex::new(HashMap::new()),
            held: AtomicUsize::new(0),
            wake: Arc::new(Notify::new()),
            writing: tokio::sync::Mutex::new(()),
            files_written: AtomicU64::new(0),
            stopped: Default::default(),
        });
        ledger.move_in_from_sqlite().await?;
        ledger.reconcile().await?;
        Ok(ledger)
    }

    fn events_dir(&self) -> PathBuf {
        self.dir.join("events")
    }

    fn beats_dir(&self) -> PathBuf {
        self.dir.join("heart_rate")
    }

    /// Write what is due every `batch_every`, or when woken, for as long as
    /// the ledger lives; drop accounts not in use from memory; compact.
    pub fn run(self: &Arc<Self>) {
        let ledger = Arc::downgrade(self);
        let every = self.timing.batch_every;
        tokio::spawn(async move {
            let mut swept = Instant::now();
            // At a fixed rate: a write that took a while is followed by the
            // next at once, not by a whole interval more (an end would wait
            // up to twice the interval for its ack).
            let mut tick = tokio::time::interval(every);
            tick.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
            loop {
                let Some(this) = ledger.upgrade() else { return };
                let wake = this.wake.clone();
                drop(this);
                tokio::select! {
                    _ = tick.tick() => {}
                    _ = wake.notified() => {}
                }
                let Some(this) = ledger.upgrade() else { return };
                if this.stopped.load(Ordering::Relaxed) {
                    return;
                }
                if let Err(error) = this.write_due(false).await {
                    tracing::error!(%error, "writing accounts; kept for the next try");
                    tokio::time::sleep(Duration::from_millis(500)).await;
                }
                if swept.elapsed() > Duration::from_secs(60) {
                    this.sweep();
                    swept = Instant::now();
                }
            }
        });
        compact::run(self);
    }

    // ── Accounts in memory ──

    async fn user(&self, user_id: &str) -> DbResult<Arc<tokio::sync::Mutex<Log>>> {
        let log = {
            let mut users = self.users.lock().unwrap_or_else(|e| e.into_inner());
            users.entry(user_id.to_string()).or_default().clone()
        };
        {
            let mut held = log.lock().await;
            if !held.loaded {
                self.load(user_id, &mut held).await?;
                held.loaded = true;
            }
            held.last_used = Some(Instant::now());
        }
        Ok(log)
    }

    /// An account into memory: whether it exists, and where its snapshot
    /// is (its head), in one query. Nothing else is read.
    async fn load(&self, user_id: &str, log: &mut Log) -> DbResult<()> {
        type Loaded = (
            bool,
            Option<i64>,
            Option<String>,
            Option<bool>,
            Option<String>,
        );
        let (exists, seq, last_id, ours, active): Loaded = self.reader.read(|c| {
            c.prepare_cached(
                "SELECT EXISTS (SELECT 1 FROM users WHERE id = ?1),
                        (SELECT seq FROM account_snapshots WHERE user_id = ?1),
                        (SELECT last_id FROM account_snapshots WHERE user_id = ?1),
                        (SELECT fold = ?2 FROM account_snapshots WHERE user_id = ?1),
                        (SELECT active_workout FROM account_snapshots WHERE user_id = ?1)",
            )?
            .query_row((user_id, schlift_core::FOLD), |r| {
                Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?, r.get(4)?))
            })
        })?;
        log.exists = exists;
        log.head = seq.unwrap_or(0);
        log.last_id = last_id.unwrap_or_default();
        log.snapshot_ours = ours.unwrap_or(true);
        log.active = active.unwrap_or_default();
        if seq.is_none() {
            // No snapshot, but events written (one lost, or never made):
            // the head is the files', and the account is folded from them.
            let head = self.head_in_files(user_id).await?;
            if head > 0 {
                log.head = head;
                log.snapshot_ours = false;
            }
        }
        Ok(())
    }

    /// Drop accounts from memory that hold nothing unacked and haven't been
    /// used for a while: what's left of them is a few bytes and a snapshot.
    fn sweep(&self) {
        let idle = Duration::from_secs(600);
        let mut users = self.users.lock().unwrap_or_else(|e| e.into_inner());
        users.retain(|_, log| match log.try_lock() {
            Ok(held) => {
                !held.unacked.is_empty()
                    || !held.shown.is_empty()
                    || held.last_used.is_some_and(|used| used.elapsed() < idle)
            }
            Err(_) => true,
        });
    }

    /// Nothing more writes, as if the process died.
    #[cfg(test)]
    pub fn stop_writing(&self) {
        self.stopped.store(true, Ordering::Relaxed);
    }

    /// Forget a deleted account: nothing of it stays in memory.
    pub fn forget(&self, user_id: &str) {
        self.users
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .remove(user_id);
        self.due
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .remove(user_id);
    }

    // ── Pushing ──

    /// A device's events: those the account doesn't hold yet (by id: a
    /// device resends until it hears back; with `check_written`, also
    /// against the snapshot's ids, for a stream's first push, which may
    /// resend what was written while it was away). Returns them, unplaced,
    /// for the account's session partners; they are written with the
    /// account, as `due` says.
    pub async fn buffer(
        &self,
        user_id: &str,
        events: Vec<Event>,
        check_written: bool,
    ) -> DbResult<Vec<Arc<Event>>> {
        self.take(user_id, events, None, check_written).await
    }

    /// Events no phone holds (an assistant's write, a friend's suggestion, a
    /// seed): written now, and returned placed.
    pub async fn push_now(&self, user_id: &str, events: Vec<Event>) -> DbResult<Vec<Event>> {
        let (done, placed) = oneshot::channel();
        let taken = self.take(user_id, events, Some(done), true).await?;
        if taken.is_empty() {
            return Ok(Vec::new());
        }
        self.wake.notify_one();
        Ok(placed
            .await
            .map_err(|_| "the ledger stopped before writing it")?)
    }

    async fn take(
        &self,
        user_id: &str,
        events: Vec<Event>,
        done: Option<oneshot::Sender<Vec<Event>>>,
        check_written: bool,
    ) -> DbResult<Vec<Arc<Event>>> {
        let log = self.user(user_id).await?;
        let mut log = log.lock().await;
        if !log.exists {
            // Looked again: it may have been made since it was loaded.
            log.exists = sqlx::query_scalar("SELECT EXISTS (SELECT 1 FROM users WHERE id = ?)")
                .bind(user_id)
                .fetch_one(&self.read_pool)
                .await?;
            if !log.exists {
                return Err(format!("no account {user_id}").into());
            }
        }
        let written: HashSet<String> =
            if check_written && log.head > 0 && events.len() > RECENT_IDS / 2 {
                // Larger than the ids a snapshot keeps (an import resent whole):
                // against every id the account holds, from the files. Rare.
                self.read_user(user_id, 0, true)
                    .await?
                    .into_iter()
                    .map(|r| r.id)
                    .collect()
            } else if check_written && log.head > 0 {
                let ids: Vec<&str> = events.iter().map(|e| e.id.as_str()).collect();
                sqlx::query_scalar(
                    "SELECT j.value FROM account_snapshots s, json_each(s.recent_ids) j
                 WHERE s.user_id = ? AND j.value IN (SELECT value FROM json_each(?))",
                )
                .bind(user_id)
                .bind(serde_json::to_string(&ids)?)
                .fetch_all(&self.read_pool)
                .await?
                .into_iter()
                .collect()
            } else {
                HashSet::new()
            };
        let new = || {
            events
                .iter()
                .filter(|e| !log.unacked_ids.contains(&e.id) && !written.contains(&e.id))
        };
        let planned: usize = log
            .unacked
            .iter()
            .map(|e| planned_sets(e))
            .chain(new().map(planned_sets))
            .sum();
        if planned > MAX_PLANNED_SETS_HELD {
            return Err(Box::new(Refused(
                "more sets planned than any workout holds",
            )));
        }
        let mut taken = Vec::new();
        let mut ended = false;
        for mut event in events {
            if log.unacked_ids.contains(&event.id) || written.contains(&event.id) {
                continue;
            }
            event.seq = 0;
            match &event.fact {
                Fact::WorkoutStarted(_) => log.active = event.id.clone(),
                Fact::WorkoutEnded(_) | Fact::WorkoutDiscarded(_) => {
                    if event.workout_id() == Some(log.active.as_str()) {
                        log.active.clear();
                    }
                    ended = true;
                }
                _ => {}
            }
            let event = Arc::new(event);
            let bytes = approx_bytes(&event);
            log.bytes += bytes;
            self.held.fetch_add(bytes, Ordering::Relaxed);
            log.unacked_ids.insert(event.id.clone());
            log.unacked.push(event.clone());
            taken.push(event);
        }
        if let Some(done) = done {
            log.waiters.push(done);
        }
        if taken.is_empty() && log.waiters.is_empty() {
            return Ok(taken);
        }
        let now = Instant::now();
        log.since.get_or_insert(now);
        // Waited on (no phone holds it): written now. A workout's end: with
        // the next batch, so the ends of a busy minute share their files
        // rather than each making its own.
        let urgent = !log.waiters.is_empty();
        let too_much = log.bytes > MAX_HELD_BYTES_PER_ACCOUNT
            || log.unacked.len() > MAX_HELD_EVENTS_PER_ACCOUNT;
        let write_by = if urgent || ended || too_much {
            now
        } else if !log.active.is_empty() {
            now + self.timing.abandoned
        } else {
            now + self.timing.quiet
        };
        drop(log);
        // A deadline slides with each event (written once quiet, or once a
        // workout is abandoned); one due now stays due now.
        let mut due = self.due.lock().unwrap_or_else(|e| e.into_inner());
        let by = due.entry(user_id.to_string()).or_insert(write_by);
        *by = if write_by <= now || *by <= now {
            (*by).min(write_by)
        } else {
            write_by
        };
        drop(due);
        if urgent {
            self.wake.notify_one();
        }
        Ok(taken)
    }

    // ── Writing ──

    /// Write the accounts due (with `all`, every account holding events:
    /// shutdown, and tests), and those the memory valve picks.
    async fn write_due(&self, all: bool) -> DbResult<()> {
        let _one_at_a_time = self.writing.lock().await;
        let now = Instant::now();
        let mut picked: Vec<String> = {
            let due = self.due.lock().unwrap_or_else(|e| e.into_inner());
            due.iter()
                .filter(|(_, by)| all || **by <= now)
                .map(|(user, _)| user.clone())
                .collect()
        };
        // The release valve: over budget, the accounts holding events
        // longest are written early, until it would be under again.
        let held = self.held.load(Ordering::Relaxed);
        if !all && held > self.timing.memory_budget {
            let mut oldest: Vec<(Instant, String, usize)> = Vec::new();
            let users: Vec<(String, Arc<tokio::sync::Mutex<Log>>)> = {
                let due = self.due.lock().unwrap_or_else(|e| e.into_inner());
                let users = self.users.lock().unwrap_or_else(|e| e.into_inner());
                due.keys()
                    .filter_map(|u| users.get(u).map(|l| (u.clone(), l.clone())))
                    .collect()
            };
            for (user, log) in users {
                if let Ok(log) = log.try_lock() {
                    if let Some(since) = log.since {
                        oldest.push((since, user, log.bytes));
                    }
                }
            }
            oldest.sort();
            let mut freed = 0;
            let target = held - self.timing.memory_budget * 9 / 10;
            for (_, user, bytes) in oldest {
                if freed >= target {
                    break;
                }
                freed += bytes;
                picked.push(user);
            }
            tracing::warn!(
                held_mb = held >> 20,
                "over the memory budget: writing early"
            );
        }
        picked.sort();
        picked.dedup();
        for chunk in picked.chunks(ACCOUNTS_PER_BATCH) {
            self.write_batch(chunk).await?;
        }
        Ok(())
    }

    /// Write `users`' held events, each account's after its head, as one
    /// events file and one heart-rate file, with their new snapshots, then
    /// tell their devices.
    async fn write_batch(&self, users: &[String]) -> DbResult<()> {
        // Taken out of each account, in order; put back in front if the
        // write fails.
        let mut taken: Vec<Taken> = Vec::new();
        for user in users {
            let log = self.user(user).await?;
            let mut held = log.lock().await;
            let events = std::mem::take(&mut held.unacked);
            let waiters = std::mem::take(&mut held.waiters);
            held.unacked_ids.clear();
            let freed = std::mem::take(&mut held.bytes);
            self.held.fetch_sub(freed, Ordering::Relaxed);
            held.since = None;
            let head = held.head;
            drop(held);
            self.due
                .lock()
                .unwrap_or_else(|e| e.into_inner())
                .remove(user);
            taken.push((user.clone(), log, events, head, waiters));
        }
        let result = self.write_taken(&taken).await;
        match result {
            Ok(written) => {
                for ((user, log, events, _, waiters), written) in taken.into_iter().zip(written) {
                    let Some(written) = written else {
                        // Not written (logged): held again, and tried later
                        // than the rest, so it doesn't fail every batch.
                        self.put_back(user, &log, events, waiters, Instant::now() + FAILED_RETRY)
                            .await;
                        continue;
                    };
                    let mut held = log.lock().await;
                    if let Some(last) = written.last() {
                        held.head = last.seq;
                        held.last_id = last.id.clone();
                    }
                    held.snapshot_ours = true;
                    let in_session = self.in_session(&user).await.unwrap_or(false);
                    let now = now_unix();
                    held.shown.retain(|(_, until, _)| *until > now);
                    if in_session {
                        for workout in written
                            .iter()
                            .filter(|e| matches!(e.fact, Fact::WorkoutStarted(_)))
                            .map(|e| e.id.clone())
                            .collect::<HashSet<_>>()
                        {
                            let shared: Vec<Arc<Event>> = written
                                .iter()
                                .filter(|e| {
                                    e.workout_id() == Some(&workout)
                                        && shared_with_partners(&e.fact)
                                })
                                .cloned()
                                .map(Arc::new)
                                .collect();
                            held.shown.push((workout, now + SHOWN_FOR_SECONDS, shared));
                        }
                    }
                    drop(held);
                    if !written.is_empty() {
                        self.changes.notify(
                            Topic::User(user.clone()),
                            Change::Account(written.as_slice().into()),
                        );
                    }
                    for waiter in waiters {
                        let _ = waiter.send(written.clone());
                    }
                }
                Ok(())
            }
            Err(error) => {
                // Nothing written: the events go back in front, as they were.
                for (user, log, events, _, waiters) in taken {
                    self.put_back(user, &log, events, waiters, Instant::now())
                        .await;
                }
                Err(error)
            }
        }
    }

    /// Taken events not written: back in front of the account's held ones,
    /// as they were, due again at `due`.
    async fn put_back(
        &self,
        user: String,
        log: &tokio::sync::Mutex<Log>,
        events: Vec<Arc<Event>>,
        waiters: Vec<oneshot::Sender<Vec<Event>>>,
        due: Instant,
    ) {
        let mut held = log.lock().await;
        let later = std::mem::take(&mut held.unacked);
        let bytes: usize = events.iter().map(|e| approx_bytes(e)).sum();
        held.bytes += bytes;
        self.held.fetch_add(bytes, Ordering::Relaxed);
        held.unacked = events.into_iter().chain(later).collect();
        held.unacked_ids = held.unacked.iter().map(|e| e.id.clone()).collect();
        held.waiters.splice(0..0, waiters);
        held.since.get_or_insert(Instant::now());
        drop(held);
        self.due
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .insert(user, due);
    }

    /// The write itself: what each account's events become, in the files
    /// and its snapshot. The events placed, per account, in `taken`'s order;
    /// None for an account that couldn't be placed (its snapshot didn't
    /// read, its fold failed): left out, so one account never stops the
    /// others being written.
    async fn write_taken(&self, taken: &[Taken]) -> DbResult<Vec<Option<Vec<Event>>>> {
        // The snapshots these fold onto, and the ids kept with them, in one
        // query; accounts whose snapshot is by other rules are folded again
        // from the files (after a release changed them).
        let ids: Vec<&str> = taken.iter().map(|t| t.0.as_str()).collect();
        // Read in pieces at once: a cold snapshot is a few random page reads,
        // which the disk serves many of together but one statement asks for
        // one at a time (20k accounts in one statement: a minute).
        let mut reads = tokio::task::JoinSet::new();
        let started = Instant::now();
        for chunk in ids.chunks(ids.len().div_ceil(SNAPSHOT_READERS).max(1)) {
            let (pool, chunk) = (self.snapshot_pool.clone(), serde_json::to_string(chunk)?);
            reads.spawn(async move {
                sqlx::query_as::<_, (String, Vec<u8>, String, String)>(
                    "SELECT s.user_id, s.state, s.recent_ids, s.fold
                     FROM json_each(?) j CROSS JOIN account_snapshots s ON s.user_id = j.value",
                )
                .bind(chunk)
                .fetch_all(&pool)
                .await
            });
        }
        let mut saved: HashMap<String, (Vec<u8>, String, String)> = HashMap::new();
        while let Some(read) = reads.join_next().await {
            for (u, state, recent, fold) in read?? {
                saved.insert(u, (state, recent, fold));
            }
        }
        let read = started.elapsed();
        // Each account's base: its stored snapshot (read in `place`), an
        // empty account, or (by other rules) folded again from the files.
        let mut bases: Vec<Base> = Vec::with_capacity(taken.len());
        for (user, _, _, head, _) in taken {
            match saved.get(user) {
                Some((_, recent, fold)) if fold == schlift_core::FOLD => {
                    bases.push(Ok((None, serde_json::from_str(recent).unwrap_or_default())));
                }
                _ if *head == 0 => {
                    bases.push(Ok((Some(Account::fold_without_heart_rate([])), Vec::new())))
                }
                _ => bases.push(
                    self.fold_from_files(user)
                        .await
                        .map(|(a, r)| (Some(a), r))
                        .map_err(|e| format!("folding from the files: {e}")),
                ),
            }
        }
        // Places, rows and new snapshots: folding is the work, spread over
        // the cores.
        let now = now_ms();
        let mut jobs = Vec::new();
        let mut placed: Vec<Option<Placed>> = (0..taken.len()).map(|_| None).collect();
        for (i, ((user, _, events, head, _), base)) in taken.iter().zip(bases).enumerate() {
            let (base, recent) = match base {
                Ok(base) => base,
                Err(error) => {
                    tracing::error!(user_id = %user, %error, "an account couldn't be written");
                    continue;
                }
            };
            let state = saved
                .get(user)
                .filter(|(_, _, fold)| fold == schlift_core::FOLD)
                .map(|(state, _, _)| state.clone());
            jobs.push((
                i,
                Job {
                    user_id: user.clone(),
                    events: events.clone(),
                    head: *head,
                    base,
                    state,
                    recent,
                },
            ));
        }
        let parts = std::thread::available_parallelism()
            .map_or(4, |n| n.get())
            .max(1);
        let per = jobs.len().div_ceil(parts).max(1);
        let mut handles = Vec::new();
        let mut jobs = jobs.into_iter();
        loop {
            let chunk: Vec<_> = jobs.by_ref().take(per).collect();
            if chunk.is_empty() {
                break;
            }
            // Each account on its own: a fold that fails or panics (an
            // event no app makes) leaves that account out, not the batch.
            handles.push(tokio::task::spawn_blocking(move || {
                chunk
                    .into_iter()
                    .map(|(i, job)| {
                        let user = job.user_id.clone();
                        let result =
                            std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| place(job)))
                                .map_err(|_| "its fold panicked".to_string())
                                .and_then(|r| r.map_err(|e| e.to_string()));
                        (i, user, result)
                    })
                    .collect::<Vec<_>>()
            }));
        }
        for handle in handles {
            for (i, user, result) in handle.await? {
                match result {
                    Ok(p) => placed[i] = Some(p),
                    Err(error) => {
                        tracing::error!(user_id = %user, %error, "an account couldn't be written");
                    }
                }
            }
        }
        let (fold, files_from) = (started.elapsed() - read, Instant::now());
        // The files: events, and heart rate, of the whole batch.
        let mut rows: Vec<Row> = placed
            .iter()
            .flatten()
            .flat_map(|p| p.rows.iter().cloned())
            .collect();
        rows.sort_by(|a, b| (&a.user_id, a.seq).cmp(&(&b.user_id, b.seq)));
        let mut beats: Vec<Beats> = placed
            .iter()
            .flatten()
            .flat_map(|p| p.beats.iter().cloned())
            .collect();
        beats.sort_by(|a, b| (&a.user_id, &a.workout_id).cmp(&(&b.user_id, &b.workout_id)));
        let n = self.files_written.fetch_add(1, Ordering::Relaxed) % 1_000_000;
        let part = files::partition(now);
        let events_file = part.join(format!("b-{now:013}-{n:06}.parquet"));
        let beats_file = part.join(format!("b-{now:013}-{n:06}.parquet"));
        let spans = files::spans(&rows);
        {
            let (events_path, beats_path) = (
                self.events_dir().join(&events_file),
                self.beats_dir().join(&beats_file),
            );
            let write_beats = !beats.is_empty();
            let write_rows = !rows.is_empty();
            tokio::task::spawn_blocking(move || -> std::io::Result<()> {
                if write_rows {
                    files::write_events(&events_path, &rows, 3)?;
                }
                if write_beats {
                    files::write_beats(&beats_path, &beats, 3)?;
                }
                Ok(())
            })
            .await??;
        }
        let (files, commit_from) = (files_from.elapsed(), Instant::now());
        // The index, the heart-rate index and the snapshots, in one go.
        let events_file = events_file.to_string_lossy().into_owned();
        let beats_file = beats_file.to_string_lossy().into_owned();
        let mut tx = self.write_pool.begin().await?;
        let index: Vec<(&str, &str, i64, i64, i64)> = spans
            .iter()
            .map(|s| {
                (
                    events_file.as_str(),
                    s.user_id.as_str(),
                    s.min_seq,
                    s.max_seq,
                    s.events,
                )
            })
            .collect();
        sqlx::query(
            "INSERT OR IGNORE INTO event_files (file, user_id, min_seq, max_seq, events)
             SELECT value ->> 0, value ->> 1, value ->> 2, value ->> 3, value ->> 4
             FROM json_each(?) WHERE EXISTS (SELECT 1 FROM users WHERE id = value ->> 1)",
        )
        .bind(serde_json::to_string(&index)?)
        .execute(&mut *tx)
        .await?;
        let beat_index: Vec<(&str, &str, &str)> = placed
            .iter()
            .flatten()
            .flat_map(|p| {
                p.beats.iter().map(|b| {
                    (
                        b.user_id.as_str(),
                        b.workout_id.as_str(),
                        beats_file.as_str(),
                    )
                })
            })
            .collect();
        if !beat_index.is_empty() {
            sqlx::query(
                "INSERT OR REPLACE INTO heart_rate_files (user_id, workout_id, file)
                 SELECT value ->> 0, value ->> 1, value ->> 2 FROM json_each(?)
                 WHERE EXISTS (SELECT 1 FROM users WHERE id = value ->> 0)",
            )
            .bind(serde_json::to_string(&beat_index)?)
            .execute(&mut *tx)
            .await?;
        }
        let unix = now_unix();
        for p in placed.iter().flatten() {
            if p.events.is_empty() {
                continue;
            }
            sqlx::query(
                "INSERT INTO account_snapshots
                     (user_id, seq, fold, state, recent_ids, updated_at, active_workout, last_id)
                 SELECT ?1, ?2, ?3, ?4, ?5, ?6, ?7, coalesce(?5 ->> '$[#-1]', '')
                 WHERE EXISTS (SELECT 1 FROM users WHERE id = ?1)
                 ON CONFLICT (user_id) DO UPDATE SET
                     active_workout = excluded.active_workout, last_id = excluded.last_id,
                     seq = excluded.seq, fold = excluded.fold, state = excluded.state,
                     recent_ids = excluded.recent_ids, updated_at = excluded.updated_at",
            )
            .bind(&p.user_id)
            .bind(p.head)
            .bind(schlift_core::FOLD)
            .bind(&p.snapshot)
            .bind(&p.recent)
            .bind(unix)
            .bind(&p.active)
            .execute(&mut *tx)
            .await?;
        }
        tx.commit().await?;
        if started.elapsed() > self.timing.batch_every {
            // Slower than batches come: say where the time went.
            tracing::warn!(
                accounts = taken.len(),
                read_ms = read.as_millis() as u64,
                fold_ms = fold.as_millis() as u64,
                files_ms = files.as_millis() as u64,
                commit_ms = commit_from.elapsed().as_millis() as u64,
                "a write took longer than the batch interval"
            );
        }
        Ok(placed.into_iter().map(|p| p.map(|p| p.events)).collect())
    }

    /// Whether the account is in a session, or ended one still on show:
    /// its written workouts are kept for partners who appear later.
    async fn in_session(&self, user_id: &str) -> DbResult<bool> {
        Ok(sqlx::query_scalar(
            "SELECT EXISTS (SELECT 1 FROM session_members
             WHERE user_id = ? AND (left_at = 0 OR ended_at > ?))",
        )
        .bind(user_id)
        .bind(now_unix() - SHOWN_FOR_SECONDS)
        .fetch_one(&self.read_pool)
        .await?)
    }

    /// Write every account holding events now: tests.
    #[cfg(test)]
    pub async fn flush(&self) -> DbResult<()> {
        self.write_due(true).await
    }

    /// What a stopping server writes: what is due now (workouts ended,
    /// writes waited on, quiet ones), not workouts under way, which their
    /// phones hold and send again.
    pub async fn shut_down(&self) -> DbResult<()> {
        self.write_due(false).await
    }

    // ── Reading ──

    /// The account's snapshot as stored and the seq it holds, when by these
    /// rules; else folded again from the files.
    async fn base(&self, user_id: &str, ours: bool) -> DbResult<(Account, i64)> {
        if ours {
            let saved: Option<(i64, Vec<u8>)> = sqlx::query_as(
                "SELECT seq, state FROM account_snapshots WHERE user_id = ? AND fold = ?",
            )
            .bind(user_id)
            .bind(schlift_core::FOLD)
            .fetch_optional(&self.read_pool)
            .await?;
            match saved {
                None if self.head_in_files(user_id).await? == 0 => {
                    return Ok((Account::fold_without_heart_rate([]), 0))
                }
                None => tracing::warn!(%user_id, "no snapshot; folding from the files"),
                Some((seq, state)) => {
                    if let Ok((account, _)) =
                        tokio::task::spawn_blocking(move || schlift_core::snapshot::restore(&state))
                            .await?
                    {
                        return Ok((account, seq));
                    }
                    tracing::warn!(%user_id, "snapshot didn't read; folding from the files");
                }
            }
        }
        let (account, _) = self.fold_from_files(user_id).await?;
        let seq = self.head_in_files(user_id).await?;
        Ok((account, seq))
    }

    /// The account folded from every event the files hold (heart rate
    /// skipped), and its latest ids: after a release changed the rules.
    async fn fold_from_files(&self, user_id: &str) -> DbResult<(Account, Vec<String>)> {
        let rows = self.read_user(user_id, 0, false).await?;
        tokio::task::spawn_blocking(move || -> DbResult<_> {
            let mut account = Account::fold_without_heart_rate([]);
            let mut ids = Vec::with_capacity(rows.len());
            for row in &rows {
                account.replay(&serde_json::from_str::<Event>(&row.event)?);
                ids.push(row.id.clone());
            }
            let recent = ids.split_off(ids.len().saturating_sub(RECENT_IDS));
            Ok((account, recent))
        })
        .await?
    }

    async fn head_in_files(&self, user_id: &str) -> DbResult<i64> {
        let head: Option<i64> =
            sqlx::query_scalar("SELECT MAX(max_seq) FROM event_files WHERE user_id = ?")
                .bind(user_id)
                .fetch_one(&self.read_pool)
                .await?;
        Ok(head.unwrap_or(0))
    }

    /// The account's events in the files after `after`, in order; heart
    /// rate only with `heart_rate`. Only a refold after a rule change, the
    /// old apps' catch-up, and tests read these.
    async fn read_user(&self, user_id: &str, after: i64, heart_rate: bool) -> DbResult<Vec<Row>> {
        let in_files: Vec<String> = sqlx::query_scalar(
            "SELECT file FROM event_files WHERE user_id = ? AND max_seq > ? ORDER BY min_seq",
        )
        .bind(user_id)
        .bind(after)
        .fetch_all(&self.read_pool)
        .await?;
        let dir = self.events_dir();
        let user = user_id.to_string();
        tokio::task::spawn_blocking(move || -> DbResult<Vec<Row>> {
            let mut rows = Vec::new();
            for file in in_files {
                rows.extend(
                    files::read_rows(&dir.join(&file), Some(&user))?
                        .into_iter()
                        .filter(|r| r.seq > after && (heart_rate || !r.heart_rate)),
                );
            }
            rows.sort_by_key(|r| r.seq);
            rows.dedup_by_key(|r| r.seq);
            Ok(rows)
        })
        .await?
    }

    /// The last seq written for the account.
    pub async fn head(&self, user_id: &str) -> DbResult<i64> {
        Ok(self.user(user_id).await?.lock().await.head)
    }

    /// The id of the event at the account's head, and the head.
    pub async fn last(&self, user_id: &str) -> DbResult<(i64, String)> {
        let log = self.user(user_id).await?;
        let log = log.lock().await;
        Ok((log.head, log.last_id.clone()))
    }

    /// Of `ids`, those the account's snapshot holds (its latest written):
    /// a device's pending events written while it was away.
    pub async fn written_among(&self, user_id: &str, ids: &[String]) -> DbResult<Vec<String>> {
        if ids.is_empty() {
            return Ok(Vec::new());
        }
        Ok(sqlx::query_scalar(
            "SELECT j.value FROM account_snapshots s, json_each(s.recent_ids) j
             WHERE s.user_id = ? AND j.value IN (SELECT value FROM json_each(?))",
        )
        .bind(user_id)
        .bind(serde_json::to_string(ids)?)
        .fetch_all(&self.read_pool)
        .await?)
    }

    /// Up to `limit` of the account's written events after `after_seq`, from
    /// the files: what an app from before the snapshots catches up with.
    pub async fn events_after(
        &self,
        user_id: &str,
        after_seq: i64,
        limit: usize,
    ) -> DbResult<Vec<Event>> {
        let mut rows = self.read_user(user_id, after_seq, true).await?;
        rows.truncate(limit);
        rows.into_iter()
            .map(|r| Ok(serde_json::from_str(&r.event)?))
            .collect()
    }

    /// Look at the account as it is now: its snapshot with the events held
    /// unacked folded on (heart rate aside), folded for this read and
    /// dropped.
    pub async fn read_account<R: Send + 'static>(
        &self,
        user_id: &str,
        read: impl FnOnce(&Account) -> R + Send + 'static,
    ) -> DbResult<R> {
        let log = self.user(user_id).await?;
        let (ours, unacked) = {
            let log = log.lock().await;
            (log.snapshot_ours, log.unacked.clone())
        };
        let (mut account, _) = self.base(user_id, ours).await?;
        Ok(tokio::task::spawn_blocking(move || {
            for event in unacked.iter().filter(|e| !is_heart_rate(e)) {
                account.replay(event);
            }
            read(&account)
        })
        .await?)
    }

    /// The account as written (its snapshot), its seq, and the id there:
    /// what a device that needs it whole is sent. The stored bytes as they
    /// are, unless they are by other rules.
    pub async fn snapshot_now(&self, user_id: &str) -> DbResult<(Vec<u8>, i64, String)> {
        let log = self.user(user_id).await?;
        let (ours, last_id) = {
            let log = log.lock().await;
            (log.snapshot_ours, log.last_id.clone())
        };
        if ours {
            let saved: Option<(i64, Vec<u8>)> = sqlx::query_as(
                "SELECT seq, state FROM account_snapshots WHERE user_id = ? AND fold = ?",
            )
            .bind(user_id)
            .bind(schlift_core::FOLD)
            .fetch_optional(&self.read_pool)
            .await?;
            if let Some((seq, state)) = saved {
                return Ok((state, seq, last_id));
            }
        }
        let (account, seq) = self.base(user_id, false).await?;
        let state =
            tokio::task::spawn_blocking(move || schlift_core::snapshot::snapshot(&account, seq))
                .await?;
        Ok((state, seq, last_id))
    }

    /// A workout of the account's as their session partners see it: its
    /// shared events, written (if on show) and held, in order.
    pub async fn workout_events(&self, user_id: &str, workout_id: &str) -> DbResult<Vec<Event>> {
        let log = self.user(user_id).await?;
        let log = log.lock().await;
        Ok(log.workout(workout_id))
    }

    /// A workout's heart rate, by its id, from the file the index names.
    pub async fn heart_rate(&self, user_id: &str, workout_id: &str) -> DbResult<Option<Beats>> {
        let file: Option<String> = sqlx::query_scalar(
            "SELECT file FROM heart_rate_files WHERE user_id = ? AND workout_id = ?",
        )
        .bind(user_id)
        .bind(workout_id)
        .fetch_optional(&self.read_pool)
        .await?;
        let Some(file) = file else { return Ok(None) };
        let path = self.beats_dir().join(file);
        let (user, workout) = (user_id.to_string(), workout_id.to_string());
        Ok(
            tokio::task::spawn_blocking(move || files::read_beats(&path, &user, &workout))
                .await??,
        )
    }

    // ── The index and the files ──

    /// Files no index names are set aside (`files::ORPHANED`), never read:
    /// a batch's files are indexed in the transaction that writes its
    /// snapshots, so one the index lacks is a write that never committed
    /// (its events were never acked, and the phones send them again), and
    /// compaction's are a merge to redo or inputs already merged. Half
    /// written files go.
    async fn reconcile(&self) -> DbResult<()> {
        for (dir, indexed) in [
            (self.events_dir(), "SELECT DISTINCT file FROM event_files"),
            (
                self.beats_dir(),
                "SELECT DISTINCT file FROM heart_rate_files",
            ),
        ] {
            let named: HashSet<String> = sqlx::query_scalar(indexed)
                .fetch_all(&self.read_pool)
                .await?
                .into_iter()
                .collect();
            let moved = tokio::task::spawn_blocking(move || -> std::io::Result<usize> {
                files::clear_temporary(&dir)?;
                let mut moved = 0;
                for file in files::list(&dir)? {
                    if named.contains(&file) {
                        continue;
                    }
                    let to = dir.join(files::ORPHANED).join(&file);
                    if let Some(parent) = to.parent() {
                        std::fs::create_dir_all(parent)?;
                    }
                    std::fs::rename(dir.join(&file), to)?;
                    moved += 1;
                }
                Ok(moved)
            })
            .await??;
            if moved > 0 {
                tracing::warn!(files = moved, "set aside files no index names");
            }
        }
        Ok(())
    }

    /// A database from before the ledger holds its events in
    /// `account_events`: they are written as files (sorted by account),
    /// indexed, each account's snapshot folded and written, and the table
    /// dropped, in that order, so a crash between starts the move again.
    async fn move_in_from_sqlite(&self) -> DbResult<()> {
        let has_table: bool = sqlx::query_scalar(
            "SELECT EXISTS (SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'account_events')",
        )
        .fetch_one(&self.read_pool)
        .await?;
        if !has_table {
            return Ok(());
        }
        let moved_dir = self.events_dir().join("moved");
        let _ = std::fs::remove_dir_all(&moved_dir);
        let _ = std::fs::remove_dir_all(self.beats_dir().join("moved"));
        // Each workout's heart rate, its last record (a later one replaces
        // an earlier), for the heart-rate files.
        let mut beats: HashMap<(String, String), Beats> = HashMap::new();
        let total: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM account_events")
            .fetch_one(&self.read_pool)
            .await?;
        let mut index = Vec::new();
        let mut snapshots: Vec<Moved> = Vec::new();
        let (mut after_user, mut after_seq) = (String::new(), 0i64);
        let mut part = 0;
        // Per account as it goes: the fold, and its ids.
        let mut account: Option<(String, Account, Vec<String>, i64)> = None;
        let finish = |account: Option<(String, Account, Vec<String>, i64)>,
                      snapshots: &mut Vec<Moved>| {
            if let Some((user, folded, ids, seq)) = account {
                let recent = ids[ids.len().saturating_sub(RECENT_IDS)..].to_vec();
                snapshots.push((
                    user,
                    seq,
                    schlift_core::snapshot::snapshot(&folded, seq),
                    serde_json::to_string(&recent).unwrap_or_else(|_| "[]".into()),
                    folded.active_workout_id.clone(),
                ));
            }
        };
        loop {
            let chunk: Vec<(String, i64, String, String)> = sqlx::query_as(
                "SELECT user_id, seq, id, event FROM account_events
                 WHERE (user_id, seq) > (?, ?) ORDER BY user_id, seq LIMIT 200000",
            )
            .bind(&after_user)
            .bind(after_seq)
            .fetch_all(&self.read_pool)
            .await?;
            let Some(last) = chunk.last() else { break };
            (after_user, after_seq) = (last.0.clone(), last.1);
            let mut rows = Vec::with_capacity(chunk.len());
            for (user_id, seq, id, json) in chunk {
                let event: Event = serde_json::from_str(&json)?;
                if account.as_ref().is_none_or(|(u, _, _, _)| *u != user_id) {
                    finish(account.take(), &mut snapshots);
                    account = Some((
                        user_id.clone(),
                        Account::fold_without_heart_rate([]),
                        Vec::new(),
                        0,
                    ));
                }
                if let Some((_, folded, ids, last)) = account.as_mut() {
                    folded.replay(&event);
                    ids.push(id.clone());
                    *last = seq;
                }
                for b in beats_of(&user_id, &event) {
                    beats.insert((b.user_id.clone(), b.workout_id.clone()), b);
                }
                rows.push(Row {
                    heart_rate: is_heart_rate(&event),
                    kind: kind_of(&json),
                    workout_id: event.workout_id().unwrap_or_default().to_string(),
                    at: event.at,
                    user_id,
                    seq,
                    id,
                    event: json,
                });
            }
            let file = format!("moved/m-{part:06}.parquet");
            part += 1;
            let path = self.events_dir().join(&file);
            let spans = tokio::task::spawn_blocking(move || -> std::io::Result<_> {
                files::write_events(&path, &rows, 3)?;
                Ok(files::spans(&rows))
            })
            .await??;
            index.push((file, spans));
        }
        finish(account.take(), &mut snapshots);
        let mut beats: Vec<Beats> = beats.into_values().collect();
        beats.sort_by(|a, b| (&a.user_id, &a.workout_id).cmp(&(&b.user_id, &b.workout_id)));
        let beats_file = "moved/m-heart-rate.parquet";
        if !beats.is_empty() {
            let path = self.beats_dir().join(beats_file);
            let beats = beats.clone();
            tokio::task::spawn_blocking(move || files::write_beats(&path, &beats, 3)).await??;
        }
        let mut tx = self.write_pool.begin().await?;
        let beat_index: Vec<(&str, &str)> = beats
            .iter()
            .map(|b| (b.user_id.as_str(), b.workout_id.as_str()))
            .collect();
        if !beat_index.is_empty() {
            sqlx::query(
                "INSERT OR REPLACE INTO heart_rate_files (user_id, workout_id, file)
                 SELECT value ->> 0, value ->> 1, ? FROM json_each(?)
                 WHERE EXISTS (SELECT 1 FROM users WHERE id = value ->> 0)",
            )
            .bind(beats_file)
            .bind(serde_json::to_string(&beat_index)?)
            .execute(&mut *tx)
            .await?;
        }
        for (file, spans) in &index {
            let rows: Vec<(&str, &str, i64, i64, i64)> = spans
                .iter()
                .map(|s| {
                    (
                        file.as_str(),
                        s.user_id.as_str(),
                        s.min_seq,
                        s.max_seq,
                        s.events,
                    )
                })
                .collect();
            sqlx::query(
                "INSERT OR IGNORE INTO event_files (file, user_id, min_seq, max_seq, events)
                 SELECT value ->> 0, value ->> 1, value ->> 2, value ->> 3, value ->> 4
                 FROM json_each(?) WHERE EXISTS (SELECT 1 FROM users WHERE id = value ->> 1)",
            )
            .bind(serde_json::to_string(&rows)?)
            .execute(&mut *tx)
            .await?;
        }
        let now = now_unix();
        for (user, seq, state, recent, active) in &snapshots {
            sqlx::query(
                "INSERT OR REPLACE INTO account_snapshots
                     (user_id, seq, fold, state, recent_ids, updated_at, active_workout, last_id)
                 SELECT ?1, ?2, ?3, ?4, ?5, ?6, ?7, coalesce(?5 ->> '$[#-1]', '')
                 WHERE EXISTS (SELECT 1 FROM users WHERE id = ?1)",
            )
            .bind(user)
            .bind(seq)
            .bind(schlift_core::FOLD)
            .bind(state)
            .bind(recent)
            .bind(now)
            .bind(active)
            .execute(&mut *tx)
            .await?;
        }
        sqlx::query("DROP TABLE account_events")
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
        tracing::info!(
            events = total,
            accounts = snapshots.len(),
            "moved account events into the ledger"
        );
        Ok(())
    }
}

/// The heart rate an event brings, as the heart-rate files hold it: a
/// workout's readings once it has ended, or imported workouts' own.
fn beats_of(user_id: &str, event: &Event) -> Vec<Beats> {
    let beats = |workout_id: &str, samples: &[schlift_core::pb::WorkoutHeartRatePoint]| Beats {
        user_id: user_id.to_string(),
        workout_id: workout_id.to_string(),
        start_ms: samples.first().map_or(0, |s| s.sampled_at),
        t_ms: samples.iter().map(|s| s.sampled_at).collect(),
        bpm: samples.iter().map(|s| s.bpm.round() as u16).collect(),
    };
    match &event.fact {
        Fact::HeartRateRecorded(h) => h
            .samples()
            .map(|samples| beats(&h.workout_id, &samples))
            .into_iter()
            .collect(),
        Fact::HistoryImported(imported) => imported
            .workouts
            .iter()
            .filter(|w| !w.heart_rate.is_empty())
            .filter_map(|w| Some(beats(&w.workout.as_ref()?.id, &w.heart_rate)))
            .collect(),
        _ => Vec::new(),
    }
}

/// One account's write, worked out off the async threads.
struct Placed {
    user_id: String,
    head: i64,
    events: Vec<Event>,
    rows: Vec<Row>,
    beats: Vec<Beats>,
    snapshot: Vec<u8>,
    recent: String,
    /// The workout under way once these are folded (or empty).
    active: String,
}

/// An account's base to fold onto (folded already, or None for its stored
/// snapshot) and its latest ids; or why there is none.
type Base = Result<(Option<Account>, Vec<String>), String>;

/// One account's write to work out: its held events, its head, its base
/// (folded already, or its stored snapshot's bytes) and its latest ids.
struct Job {
    user_id: String,
    events: Vec<Arc<Event>>,
    head: i64,
    base: Option<Account>,
    state: Option<Vec<u8>>,
    recent: Vec<String>,
}

/// Give an account's held events their places after `head`, fold them onto
/// its snapshot (stored bytes, or a base folded from the files), and lay
/// out its rows and heart rate.
fn place(
    Job {
        user_id,
        events,
        head,
        base,
        state,
        mut recent,
    }: Job,
) -> DbResult<Placed> {
    let mut account = match (base, state) {
        (Some(account), _) => account,
        (None, Some(state)) => schlift_core::snapshot::restore(&state)
            .map(|(a, _)| a)
            .map_err(|e| format!("{user_id}'s snapshot: {e}"))?,
        (None, None) => Account::fold_without_heart_rate([]),
    };
    let mut seq = head;
    let mut placed = Vec::with_capacity(events.len());
    let mut rows = Vec::with_capacity(events.len());
    let mut beats = Vec::new();
    for event in &events {
        seq += 1;
        let mut event = (**event).clone();
        event.seq = seq;
        beats.extend(beats_of(&user_id, &event));
        if !is_heart_rate(&event) {
            account.replay(&event);
        }
        let json = json(&event);
        rows.push(Row {
            user_id: user_id.clone(),
            seq,
            id: event.id.clone(),
            at: event.at,
            kind: kind_of(&json),
            workout_id: event.workout_id().unwrap_or_default().to_string(),
            heart_rate: is_heart_rate(&event),
            event: json,
        });
        recent.push(event.id.clone());
        placed.push(event);
    }
    let recent = recent.split_off(recent.len().saturating_sub(RECENT_IDS));
    let snapshot = schlift_core::snapshot::snapshot(&account, seq);
    Ok(Placed {
        active: account.active_workout_id.clone(),
        user_id,
        head: seq,
        events: placed,
        rows,
        beats,
        snapshot,
        recent: serde_json::to_string(&recent)?,
    })
}
