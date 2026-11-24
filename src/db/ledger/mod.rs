//! The ledger: every account's events, and each account folded, held so a
//! push costs a few memory writes and a read costs no disk.
//!
//! - **Pushes** go into a buffer in memory. Their events go to session
//!   partners at once (`Change::Live`), unplaced.
//! - **A flush** (every `FLUSH_EVERY`, or at once for a write no phone
//!   holds, `push_now`) gives the buffered events their places, writes them
//!   as one Parquet file (`files`), synced, indexes it (`event_files`), and
//!   only then tells each account's devices (`Change::Account`): that is
//!   their ack. A phone keeps an event pending until it hears it back, and
//!   sends it again on its next stream, so a crash before a flush loses
//!   nothing: the event comes again, and is placed then.
//! - **Each account** is held in memory while in use (`UserLog`): its head,
//!   the ids it holds (a resent event is placed once), the events since its
//!   snapshot, and the account folded, caught up as events are placed. A
//!   read answers from that. An account not in use is dropped from memory
//!   and loaded again from its snapshot (`account_snapshots`) and the
//!   events after it.
//! - **Snapshots** are written once an account has `SNAPSHOT_AFTER` events
//!   past its last, so loading it folds little; a snapshot folded by other
//!   rules (`schlift_core::FOLD`) is folded again from the files.
//!
//! The files are only ever added to. Deleting an account removes its rows
//! from the index and its snapshot; its events stay in the files, under an
//! id nothing points to any more.

pub mod files;
#[cfg(test)]
mod tests;

use std::collections::{HashMap, HashSet, VecDeque};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use schlift_core::account::Account;
use schlift_core::events::{Event, Fact};
use schlift_core::session::shared_with_partners;
use sqlx::{Pool, Sqlite};
use tokio::sync::{oneshot, watch, Notify};

use super::changes::Changes;
use super::{Change, DbResult, Topic};
use crate::time::now_unix;
use files::Row;

/// How long pushes wait in memory before they are stored and acked. Set by
/// `FLUSH_MS`; short in tests.
pub fn flush_every() -> Duration {
    let default = if cfg!(test) { 10 } else { 60_000 };
    Duration::from_millis(
        std::env::var("FLUSH_MS")
            .ok()
            .and_then(|ms| ms.parse().ok())
            .unwrap_or(default),
    )
}

/// Buffered past this, a flush starts at once.
const FLUSH_AT_BYTES: usize = 64 << 20;

/// Events an account takes past its snapshot before it is written again.
pub const SNAPSHOT_AFTER: usize = 64;

/// The ids kept with a snapshot, newest: an event resent (its ack lost)
/// after more than this many others is placed again.
const RECENT_IDS: usize = 2_000;

/// How far back a partner's workout is looked for in the files after a
/// restart: more events than any one workout records.
const WORKOUT_REACH: usize = 2_000;

/// Workouts of an account's whose shared events are held, newest.
const LIVE_WORKOUTS: usize = 3;

/// An account not used for this long is dropped from memory.
const IDLE: Duration = Duration::from_secs(600);

/// Events a flush may write in one file.
const ROWS_PER_FILE: usize = 500_000;

/// One account, in memory.
#[derive(Default)]
struct UserLog {
    /// The last seq placed.
    head: i64,
    /// The seq the stored snapshot is folded to.
    snapshot_seq: i64,
    /// Placed events after the snapshot, heart rate and all.
    tail: VecDeque<Arc<Event>>,
    /// The account folded (without heart rate), and the seq it is folded
    /// to; None until something needs it.
    account: Option<(Account, i64)>,
    /// A stored snapshot (by these rules, at `snapshot_seq`) not yet read
    /// (`account` is None), and the ids kept with it not yet read: loading
    /// an account reads neither, so an idle phone holds a few hundred bytes
    /// here and a million coming back after a restart cost a query each.
    snapshot_unread: bool,
    ids_unread: bool,
    /// Ids placed, newest last (the snapshot's and the tail's).
    recent: VecDeque<String>,
    ids: HashSet<String>,
    /// Pushed, not yet placed: in order, and their ids.
    buffered: Vec<Arc<Event>>,
    buffered_ids: HashSet<String>,
    /// The shared events of the account's latest workouts, by workout:
    /// what a session partner sees of them, placed or not.
    workouts: VecDeque<(String, Vec<Arc<Event>>)>,
    /// The workouts above were looked for in the files once loaded.
    workouts_loaded: bool,
    /// The account exists (a push to one deleted, or never made, fails).
    exists: bool,
    last_used: Option<Instant>,
}

impl UserLog {
    fn holds(&self, id: &str) -> bool {
        self.ids.contains(id) || self.buffered_ids.contains(id)
    }

    fn remember(&mut self, id: &str) {
        self.recent.push_back(id.to_string());
        self.ids.insert(id.to_string());
        while self.recent.len() > RECENT_IDS + self.tail.len() {
            if let Some(old) = self.recent.pop_front() {
                self.ids.remove(&old);
            }
        }
    }

    /// Follow an event in the latest workouts' shared events.
    fn follow_workout(&mut self, event: &Arc<Event>) {
        if !shared_with_partners(&event.fact) {
            return;
        }
        let Some(workout) = event.workout_id() else {
            return;
        };
        let held = self.workouts.iter().any(|(w, _)| w == workout);
        if !held && matches!(event.fact, Fact::WorkoutStarted(_)) && event.id == workout {
            self.workouts
                .push_back((workout.to_string(), vec![event.clone()]));
            while self.workouts.len() > LIVE_WORKOUTS {
                self.workouts.pop_front();
            }
            return;
        }
        if let Some((_, events)) = self.workouts.iter_mut().find(|(w, _)| w == workout) {
            // Placed now, it replaces its unplaced copy.
            match events.iter_mut().find(|e| e.id == event.id) {
                Some(held) => *held = event.clone(),
                None => events.push(event.clone()),
            }
        }
    }
}

/// A push waiting in the buffer.
struct Buffered {
    user_id: String,
    events: Vec<Arc<Event>>,
    /// Told the events once placed (a write that waits for its flush).
    done: Option<oneshot::Sender<Vec<Event>>>,
}

#[derive(Default)]
struct Buffer {
    pushes: Vec<Buffered>,
    bytes: usize,
}

pub struct Ledger {
    dir: PathBuf,
    read_pool: Pool<Sqlite>,
    write_pool: Pool<Sqlite>,
    changes: Arc<Changes>,
    users: Mutex<HashMap<String, Arc<tokio::sync::Mutex<UserLog>>>>,
    buffer: Mutex<Buffer>,
    wake: Arc<Notify>,
    /// Bumped after every flush.
    flushed: watch::Sender<u64>,
    files_written: AtomicU64,
    /// Held through a flush: one at a time, so each reads the heads the
    /// last one left.
    flushing: tokio::sync::Mutex<()>,
    /// A flush wrote files it couldn't index: the next indexes them first.
    unindexed: std::sync::atomic::AtomicBool,
    /// Set in tests to stand for a process that died: nothing more flushes.
    stopped: std::sync::atomic::AtomicBool,
}

fn json(event: &Event) -> String {
    // Plain data to a string: can't fail.
    serde_json::to_string(event).expect("an event serialises")
}

fn is_heart_rate(event: &Event) -> bool {
    matches!(event.fact, Fact::HeartRateRecorded(_))
}

impl Ledger {
    /// The ledger over `data_dir/events`, its index reconciled with the
    /// files there, and the events of a database from before it moved in.
    pub async fn open(
        data_dir: &Path,
        read_pool: Pool<Sqlite>,
        write_pool: Pool<Sqlite>,
        changes: Arc<Changes>,
    ) -> DbResult<Arc<Self>> {
        let dir = data_dir.join("events");
        std::fs::create_dir_all(&dir)?;
        let ledger = Arc::new(Self {
            dir,
            read_pool,
            write_pool,
            changes,
            users: Mutex::new(HashMap::new()),
            buffer: Mutex::new(Buffer::default()),
            wake: Arc::new(Notify::new()),
            flushed: watch::channel(0).0,
            files_written: AtomicU64::new(0),
            stopped: Default::default(),
            flushing: tokio::sync::Mutex::new(()),
            unindexed: Default::default(),
        });
        ledger.move_in_from_sqlite().await?;
        ledger.reconcile().await?;
        Ok(ledger)
    }

    /// Flush every `every`, or when asked, for as long as the ledger lives;
    /// and drop accounts not in use from memory.
    pub fn run(self: &Arc<Self>, every: Duration) {
        let ledger = Arc::downgrade(self);
        tokio::spawn(async move {
            let mut swept = Instant::now();
            loop {
                let Some(this) = ledger.upgrade() else { return };
                let wake = this.wake.clone();
                drop(this);
                tokio::select! {
                    _ = tokio::time::sleep(every) => {}
                    _ = wake.notified() => {}
                }
                let Some(this) = ledger.upgrade() else { return };
                if this.stopped.load(Ordering::Relaxed) {
                    return;
                }
                if let Err(error) = this.flush().await {
                    tracing::error!(%error, "flushing the ledger; kept for the next");
                    tokio::time::sleep(Duration::from_millis(200)).await;
                }
                if swept.elapsed() > Duration::from_secs(60) {
                    this.sweep(IDLE).await;
                    swept = Instant::now();
                }
            }
        });
    }

    // ── Accounts in memory ──

    async fn user(&self, user_id: &str) -> DbResult<Arc<tokio::sync::Mutex<UserLog>>> {
        let log = {
            let mut users = self.users.lock().unwrap_or_else(|e| e.into_inner());
            users.entry(user_id.to_string()).or_default().clone()
        };
        {
            let mut held = log.lock().await;
            if held.last_used.is_none() {
                self.load(user_id, &mut held).await?;
            }
            held.last_used = Some(Instant::now());
        }
        Ok(log)
    }

    /// An account into memory: its head, its snapshot (unread) and the
    /// events placed after it (none, for an account written down when it
    /// went idle).
    async fn load(&self, user_id: &str, log: &mut UserLog) -> DbResult<()> {
        log.exists = sqlx::query_scalar("SELECT EXISTS (SELECT 1 FROM users WHERE id = ?)")
            .bind(user_id)
            .fetch_one(&self.read_pool)
            .await?;
        let head: Option<i64> =
            sqlx::query_scalar("SELECT MAX(max_seq) FROM event_files WHERE user_id = ?")
                .bind(user_id)
                .fetch_one(&self.read_pool)
                .await?;
        log.head = head.unwrap_or(0);
        let saved: Option<i64> = sqlx::query_scalar(
            "SELECT seq FROM account_snapshots WHERE user_id = ? AND fold = ?",
        )
        .bind(user_id)
        .bind(schlift_core::FOLD)
        .fetch_optional(&self.read_pool)
        .await?;
        match saved {
            Some(seq) if seq <= log.head => {
                log.snapshot_seq = seq;
                log.snapshot_unread = true;
                log.ids_unread = true;
                if log.head > seq {
                    for (_, _, json) in self.read_user(user_id, seq, true).await? {
                        let event = Arc::new(serde_json::from_str::<Event>(&json)?);
                        log.ids.insert(event.id.clone());
                        log.tail.push_back(event);
                    }
                }
            }
            // None by these rules: folded whole when first needed.
            _ => log.snapshot_seq = -1,
        }
        Ok(())
    }

    /// The ids kept with the snapshot, into the set that turns resends away,
    /// read the first time a push needs them.
    async fn ids_ready(&self, user_id: &str, log: &mut UserLog) -> DbResult<()> {
        if !log.ids_unread {
            return Ok(());
        }
        let json: Option<String> =
            sqlx::query_scalar("SELECT recent_ids FROM account_snapshots WHERE user_id = ?")
                .bind(user_id)
                .fetch_optional(&self.read_pool)
                .await?;
        let tail: Vec<String> = log.tail.iter().map(|e| e.id.clone()).collect();
        log.recent.clear();
        for id in serde_json::from_str::<Vec<String>>(&json.unwrap_or_default()).unwrap_or_default() {
            log.recent.push_back(id.clone());
            log.ids.insert(id);
        }
        log.recent.extend(tail);
        log.ids_unread = false;
        Ok(())
    }

    /// The account folded, as of the last event placed: its snapshot read
    /// and caught up, or (with none by these rules) its whole history
    /// folded once, and written down so the next load folds little.
    async fn folded(&self, user_id: &str, log: &mut UserLog) -> DbResult<()> {
        self.ids_ready(user_id, log).await?;
        if log.account.is_some() {
            return Ok(());
        }
        let state: Option<Vec<u8>> = if log.snapshot_unread {
            sqlx::query_scalar("SELECT state FROM account_snapshots WHERE user_id = ? AND fold = ?")
                .bind(user_id)
                .bind(schlift_core::FOLD)
                .fetch_optional(&self.read_pool)
                .await?
        } else {
            None
        };
        log.snapshot_unread = false;
        if let Some(state) = state {
            match tokio::task::spawn_blocking(move || schlift_core::snapshot::restore(&state))
                .await?
            {
                Ok((account, seq)) => {
                    log.account = Some((account, seq));
                    self.catch_up(log);
                    return Ok(());
                }
                Err(error) => {
                    tracing::warn!(%user_id, %error, "snapshot didn't read; folding whole");
                }
            }
        }
        let rows = self.read_user(user_id, 0, true).await?;
        let (account, ids, tail) = tokio::task::spawn_blocking(move || -> DbResult<_> {
            let mut account = Account::fold_without_heart_rate([]);
            let mut ids = Vec::with_capacity(rows.len());
            for (_, id, json) in &rows {
                if !json.contains("\"HeartRateRecorded\":") {
                    account.replay(&serde_json::from_str::<Event>(json)?);
                }
                ids.push(id.clone());
            }
            Ok((account, ids, rows.last().map_or(0, |(seq, _, _)| *seq)))
        })
        .await??;
        log.tail.clear();
        log.recent.clear();
        log.ids.clear();
        for id in ids.iter().rev().take(RECENT_IDS).rev() {
            log.recent.push_back(id.clone());
            log.ids.insert(id.clone());
        }
        let seq = tail.max(log.head);
        log.account = Some((account, seq));
        log.snapshot_seq = seq;
        if seq > 0 {
            self.save_snapshots(vec![(user_id.to_string(), log_snapshot(log))])
                .await?;
        }
        Ok(())
    }

    /// Fold the tail into the account it is behind.
    fn catch_up(&self, log: &mut UserLog) {
        let Some((account, folded_to)) = log.account.as_mut() else {
            return;
        };
        let from = *folded_to;
        for event in log.tail.iter().filter(|e| e.seq > from) {
            if !is_heart_rate(event) {
                account.replay(event);
            }
            *folded_to = event.seq;
        }
    }

    /// Drop accounts not in use from memory (their snapshots and files hold
    /// them), but none with pushes waiting; one with events past its
    /// snapshot is written down first, so loading it again reads no files.
    async fn sweep(&self, idle_for: Duration) {
        let idle: Vec<(String, Arc<tokio::sync::Mutex<UserLog>>)> = {
            let users = self.users.lock().unwrap_or_else(|e| e.into_inner());
            users
                .iter()
                .filter(|(_, log)| match log.try_lock() {
                    Ok(held) => {
                        held.buffered.is_empty()
                            && held.last_used.is_none_or(|used| used.elapsed() >= idle_for)
                    }
                    Err(_) => false,
                })
                .map(|(user, log)| (user.clone(), log.clone()))
                .collect()
        };
        let mut snapshots = Vec::new();
        for (user, log) in &idle {
            let mut held = log.lock().await;
            if !held.tail.is_empty() {
                if let Err(error) = self.folded(user, &mut held).await {
                    tracing::warn!(%user, %error, "folding an idle account; kept in memory");
                    continue;
                }
                snapshots.push((user.clone(), log_snapshot(&mut held)));
            }
        }
        if let Err(error) = self.save_snapshots(snapshots).await {
            tracing::warn!(%error, "writing idle accounts' snapshots; kept in memory");
            return;
        }
        let mut users = self.users.lock().unwrap_or_else(|e| e.into_inner());
        for (user, log) in idle {
            let still_idle = log
                .try_lock()
                .is_ok_and(|held| held.buffered.is_empty() && held.tail.is_empty());
            if still_idle {
                users.remove(&user);
            }
        }
    }

    /// Every account not mid-push out of memory, written down first.
    #[cfg(test)]
    pub async fn sweep_all(&self) {
        self.sweep(Duration::ZERO).await;
    }

    /// Nothing more flushes, as if the process died.
    #[cfg(test)]
    pub fn stop_flushing(&self) {
        self.stopped.store(true, Ordering::Relaxed);
    }

    /// Forget a deleted account: nothing of it stays in memory, and pushes
    /// of it still waiting are stored under an id nothing points to.
    pub fn forget(&self, user_id: &str) {
        let mut users = self.users.lock().unwrap_or_else(|e| e.into_inner());
        users.remove(user_id);
    }

    // ── Reading the files ──

    /// The account's events in the files after `after`, in order: (seq, id,
    /// event JSON); heart rate only with `heart_rate`.
    async fn read_user(
        &self,
        user_id: &str,
        after: i64,
        heart_rate: bool,
    ) -> DbResult<Vec<(i64, String, String)>> {
        let in_files: Vec<String> = sqlx::query_scalar(
            "SELECT file FROM event_files WHERE user_id = ? AND max_seq > ? ORDER BY min_seq",
        )
        .bind(user_id)
        .bind(after)
        .fetch_all(&self.read_pool)
        .await?;
        let dir = self.dir.clone();
        let user = user_id.to_string();
        let rows = tokio::task::spawn_blocking(move || -> DbResult<_> {
            let mut rows = Vec::new();
            for file in in_files {
                rows.extend(files::read_user(
                    &dir.join(&file),
                    &user,
                    after,
                    heart_rate,
                )?);
            }
            rows.sort_by_key(|(seq, _, _)| *seq);
            rows.dedup_by_key(|(seq, _, _)| *seq);
            Ok(rows)
        })
        .await??;
        Ok(rows)
    }

    // ── Pushing ──

    /// Take a device's events into the buffer: those the account doesn't
    /// hold yet (by id: a device resends until it hears back), in order.
    /// Returns them, unplaced; they go to the account's session partners
    /// now, and are placed and stored with the next flush.
    pub async fn buffer(&self, user_id: &str, events: Vec<Event>) -> DbResult<Vec<Arc<Event>>> {
        self.take(user_id, events, None).await
    }

    /// The same, for a write no phone holds (an assistant's, a friend's
    /// suggestion, a migration's): stored with a flush now, and the events
    /// returned once placed.
    pub async fn push_now(&self, user_id: &str, events: Vec<Event>) -> DbResult<Vec<Event>> {
        let (done, placed) = oneshot::channel();
        let taken = self.take(user_id, events, Some(done)).await?;
        if taken.is_empty() {
            return Ok(Vec::new());
        }
        self.wake.notify_one();
        Ok(placed
            .await
            .map_err(|_| "the ledger stopped before storing it")?)
    }

    async fn take(
        &self,
        user_id: &str,
        events: Vec<Event>,
        done: Option<oneshot::Sender<Vec<Event>>>,
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
        self.ids_ready(user_id, &mut log).await?;
        // A push larger than the ids held in memory (an outbox after a long
        // time away, an import resent whole) is checked against every id
        // the account holds, from the files.
        let all_ids: Option<HashSet<String>> = if events.len() > RECENT_IDS / 2 {
            Some(
                self.read_user(user_id, 0, true)
                    .await?
                    .into_iter()
                    .map(|(_, id, _)| id)
                    .collect(),
            )
        } else {
            None
        };
        let mut taken = Vec::new();
        for mut event in events {
            if log.holds(&event.id) || all_ids.as_ref().is_some_and(|ids| ids.contains(&event.id)) {
                continue;
            }
            event.seq = 0;
            let event = Arc::new(event);
            log.buffered_ids.insert(event.id.clone());
            log.buffered.push(event.clone());
            log.follow_workout(&event);
            taken.push(event);
        }
        if taken.is_empty() {
            return Ok(taken);
        }
        let bytes: usize = taken
            .iter()
            .map(|e| match &e.fact {
                Fact::HeartRateRecorded(h) => 64 + h.bpm.len() * 8,
                _ => 512,
            })
            .sum();
        let full = {
            let mut buffer = self.buffer.lock().unwrap_or_else(|e| e.into_inner());
            buffer.pushes.push(Buffered {
                user_id: user_id.to_string(),
                events: taken.clone(),
                done,
            });
            buffer.bytes += bytes;
            buffer.bytes > FLUSH_AT_BYTES
        };
        drop(log);
        if full {
            self.wake.notify_one();
        }
        Ok(taken)
    }

    /// Store what is buffered: place each event after its account's head,
    /// write them all as one file, synced, and index it; then the accounts'
    /// devices are told, which is their ack.
    pub async fn flush(&self) -> DbResult<()> {
        let _one_at_a_time = self.flushing.lock().await;
        if self.unindexed.swap(false, Ordering::Relaxed) {
            if let Err(error) = self.reconcile().await {
                self.unindexed.store(true, Ordering::Relaxed);
                tracing::error!(%error, "indexing event files again");
            }
        }
        let pushes = {
            let mut buffer = self.buffer.lock().unwrap_or_else(|e| e.into_inner());
            buffer.bytes = 0;
            std::mem::take(&mut buffer.pushes)
        };
        if pushes.is_empty() {
            self.flushed.send_modify(|n| *n += 1);
            return Ok(());
        }
        // Places, from each account's head: only a flush moves a head, and
        // one runs at a time, so they're read now and moved once stored.
        let mut heads: HashMap<String, i64> = HashMap::new();
        let mut placed: Vec<Vec<Event>> = Vec::with_capacity(pushes.len());
        for push in &pushes {
            let head = match heads.get(&push.user_id) {
                Some(head) => *head,
                None => {
                    let log = self.user(&push.user_id).await?;
                    let head = log.lock().await.head;
                    head
                }
            };
            let mut seq = head;
            let events: Vec<Event> = push
                .events
                .iter()
                .map(|e| {
                    seq += 1;
                    let mut event = (**e).clone();
                    event.seq = seq;
                    event
                })
                .collect();
            heads.insert(push.user_id.clone(), seq);
            placed.push(events);
        }
        let mut rows: Vec<Row> = placed
            .iter()
            .zip(&pushes)
            .flat_map(|(events, push)| {
                events.iter().map(|e| Row {
                    user_id: push.user_id.clone(),
                    seq: e.seq,
                    id: e.id.clone(),
                    at: e.at,
                    heart_rate: is_heart_rate(e),
                    event: json(e),
                })
            })
            .collect();
        rows.sort_by(|a, b| (&a.user_id, a.seq).cmp(&(&b.user_id, b.seq)));
        let written = match self.write_files(rows).await {
            Ok(written) => written,
            Err(error) => {
                // Nothing is placed: the pushes go back in front, as they were.
                let mut buffer = self.buffer.lock().unwrap_or_else(|e| e.into_inner());
                let later = std::mem::take(&mut buffer.pushes);
                buffer.pushes = pushes;
                buffer.pushes.extend(later);
                return Err(error);
            }
        };
        // Stored: the files are the truth from here, so the events are
        // placed whatever comes next. An index that fails is built from the
        // files by the next flush (or start).
        if let Err(error) = self.index(&written).await {
            tracing::error!(%error, "indexing event files; indexed again next flush");
            self.unindexed.store(true, Ordering::Relaxed);
        }
        // Into memory: heads, tails, folded accounts; then snapshots due.
        let mut by_user: HashMap<String, Vec<Arc<Event>>> = HashMap::new();
        for (events, push) in placed.iter().zip(&pushes) {
            by_user
                .entry(push.user_id.clone())
                .or_default()
                .extend(events.iter().cloned().map(Arc::new));
        }
        let mut snapshots = Vec::new();
        for (user_id, events) in &by_user {
            let log = self.user(user_id).await?;
            let mut log = log.lock().await;
            self.ids_ready(user_id, &mut log).await?;
            for event in events {
                log.head = log.head.max(event.seq);
                log.buffered_ids.remove(&event.id);
                log.remember(&event.id);
                log.follow_workout(event);
                log.tail.push_back(event.clone());
            }
            let placed_ids: HashSet<&str> = events.iter().map(|e| e.id.as_str()).collect();
            log.buffered.retain(|e| !placed_ids.contains(e.id.as_str()));
            self.catch_up(&mut log);
            let since = log.tail.iter().filter(|e| !is_heart_rate(e)).count();
            if since >= SNAPSHOT_AFTER {
                self.folded(user_id, &mut log).await?;
                snapshots.push((user_id.clone(), log_snapshot(&mut log)));
            }
        }
        if !snapshots.is_empty() {
            // Only a shortcut: one not written is folded again later.
            if let Err(error) = self.save_snapshots(snapshots).await {
                tracing::warn!(%error, "writing snapshots; folded again when next needed");
            }
        }
        // Told: the devices (their ack) and anyone waiting on a write.
        for (events, push) in placed.into_iter().zip(pushes) {
            self.changes.notify(
                Topic::User(push.user_id.clone()),
                Change::Account(events.as_slice().into()),
            );
            if let Some(done) = push.done {
                let _ = done.send(events);
            }
        }
        self.flushed.send_modify(|n| *n += 1);
        Ok(())
    }

    /// The rows as files (one per `ROWS_PER_FILE`), each synced in place.
    async fn write_files(&self, rows: Vec<Row>) -> DbResult<Vec<(String, Vec<files::Span>)>> {
        let mut written = Vec::new();
        let mut chunks: Vec<Vec<Row>> = Vec::new();
        let mut rows = rows;
        while rows.len() > ROWS_PER_FILE {
            let rest = rows.split_off(ROWS_PER_FILE);
            chunks.push(rows);
            rows = rest;
        }
        chunks.push(rows);
        for chunk in chunks {
            let n = self.files_written.fetch_add(1, Ordering::Relaxed);
            let name = format!(
                "{:013}-{:06}.parquet",
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .map_or(0, |d| d.as_millis()),
                n % 1_000_000
            );
            let path = self.dir.join(&name);
            let spans = tokio::task::spawn_blocking(move || -> std::io::Result<_> {
                files::write(&path, &chunk)?;
                Ok(files::spans(&chunk))
            })
            .await??;
            written.push((name, spans));
        }
        Ok(written)
    }

    /// The files in the index, for accounts that still exist.
    async fn index(&self, written: &[(String, Vec<files::Span>)]) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;
        for (file, spans) in written {
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
                 FROM json_each(?)
                 WHERE EXISTS (SELECT 1 FROM users WHERE id = value ->> 1)",
            )
            .bind(serde_json::to_string(&rows)?)
            .execute(&mut *tx)
            .await?;
        }
        tx.commit().await?;
        Ok(())
    }

    /// Files the index lacks (written, then a crash before they were
    /// indexed) are indexed from their contents.
    async fn reconcile(&self) -> DbResult<()> {
        let indexed: HashSet<String> = sqlx::query_scalar("SELECT DISTINCT file FROM event_files")
            .fetch_all(&self.read_pool)
            .await?
            .into_iter()
            .collect();
        let dir = self.dir.clone();
        let missing = tokio::task::spawn_blocking(move || -> DbResult<_> {
            let mut missing = Vec::new();
            for path in files::list(&dir)? {
                let name = path
                    .file_name()
                    .and_then(|n| n.to_str())
                    .unwrap_or_default()
                    .to_string();
                if !indexed.contains(&name) {
                    missing.push((name, files::read_spans(&path)?));
                }
            }
            Ok(missing)
        })
        .await??;
        if !missing.is_empty() {
            tracing::warn!(
                files = missing.len(),
                "indexing event files the index lacked"
            );
            self.index(&missing).await?;
        }
        Ok(())
    }

    // ── Snapshots ──

    async fn save_snapshots(&self, snapshots: Vec<(String, Snapshot)>) -> DbResult<()> {
        let encoded = tokio::task::spawn_blocking(move || {
            snapshots
                .into_iter()
                .map(|(user, s)| {
                    let state = schlift_core::snapshot::snapshot(&s.account, s.seq);
                    (
                        user,
                        s.seq,
                        state,
                        serde_json::to_string(&s.recent).unwrap_or_default(),
                    )
                })
                .collect::<Vec<_>>()
        })
        .await?;
        let mut tx = self.write_pool.begin().await?;
        let now = now_unix();
        for (user, seq, state, recent) in &encoded {
            sqlx::query(
                "INSERT INTO account_snapshots (user_id, seq, fold, state, recent_ids, updated_at)
                 SELECT ?1, ?2, ?3, ?4, ?5, ?6 WHERE EXISTS (SELECT 1 FROM users WHERE id = ?1)
                 ON CONFLICT (user_id) DO UPDATE SET
                     seq = excluded.seq, fold = excluded.fold, state = excluded.state,
                     recent_ids = excluded.recent_ids, updated_at = excluded.updated_at
                 WHERE excluded.seq >= account_snapshots.seq
                    OR excluded.fold != account_snapshots.fold",
            )
            .bind(user)
            .bind(seq)
            .bind(schlift_core::FOLD)
            .bind(state)
            .bind(recent)
            .bind(now)
            .execute(&mut *tx)
            .await?;
        }
        tx.commit().await?;
        Ok(())
    }

    // ── Reading ──

    /// The last seq placed for the account.
    pub async fn head(&self, user_id: &str) -> DbResult<i64> {
        Ok(self.user(user_id).await?.lock().await.head)
    }

    /// Up to `limit` of the account's placed events after `after_seq`, in
    /// order: from memory when it holds them, else from the files.
    pub async fn events_after(
        &self,
        user_id: &str,
        after_seq: i64,
        limit: usize,
    ) -> DbResult<Vec<Event>> {
        let log = self.user(user_id).await?;
        {
            let log = log.lock().await;
            if log.snapshot_seq >= 0 && after_seq >= log.snapshot_seq {
                return Ok(log
                    .tail
                    .iter()
                    .filter(|e| e.seq > after_seq)
                    .take(limit)
                    .map(|e| (**e).clone())
                    .collect());
            }
        }
        let mut rows = self.read_user(user_id, after_seq, true).await?;
        rows.truncate(limit);
        rows.into_iter()
            .map(|(_, _, json)| Ok(serde_json::from_str(&json)?))
            .collect()
    }

    /// The ids of the account's placed events after `after_seq`: from
    /// memory when it holds them, else the files.
    pub async fn ids_after(&self, user_id: &str, after_seq: i64) -> DbResult<HashSet<String>> {
        let log = self.user(user_id).await?;
        {
            let log = log.lock().await;
            if log.snapshot_seq >= 0 && after_seq >= log.snapshot_seq {
                return Ok(log
                    .tail
                    .iter()
                    .filter(|e| e.seq > after_seq)
                    .map(|e| e.id.clone())
                    .collect());
            }
        }
        Ok(self
            .read_user(user_id, after_seq, true)
            .await?
            .into_iter()
            .map(|(_, id, _)| id)
            .collect())
    }

    /// Look at the account as it is now: folded from its snapshot and every
    /// event placed since, with those pushed and not yet placed on top.
    pub async fn read_account<R: Send + 'static>(
        &self,
        user_id: &str,
        read: impl FnOnce(&Account) -> R + Send + 'static,
    ) -> DbResult<R> {
        let log = self.user(user_id).await?;
        let mut log = log.lock_owned().await;
        self.folded(user_id, &mut log).await?;
        Ok(tokio::task::spawn_blocking(move || {
            let buffered: Vec<Arc<Event>> = log
                .buffered
                .iter()
                .filter(|e| !is_heart_rate(e))
                .cloned()
                .collect();
            let (account, _) = log.account.as_ref().expect("folded above");
            if buffered.is_empty() {
                return read(account);
            }
            let mut now = account.clone();
            for event in &buffered {
                now.replay(event);
            }
            read(&now)
        })
        .await?)
    }

    /// The account folded as of its head, written down with the seq: what a
    /// device that needs it whole is sent.
    pub async fn snapshot_now(&self, user_id: &str) -> DbResult<(Vec<u8>, i64)> {
        let log = self.user(user_id).await?;
        let mut log = log.lock_owned().await;
        self.folded(user_id, &mut log).await?;
        Ok(tokio::task::spawn_blocking(move || {
            let (account, seq) = log.account.clone().expect("folded above");
            (schlift_core::snapshot::snapshot(&account, seq), seq)
        })
        .await?)
    }

    /// A workout of the account's as their session partners see it: its
    /// shared events from its start, placed or not, in order. Empty if it
    /// isn't one of the account's latest.
    pub async fn workout_events(&self, user_id: &str, workout_id: &str) -> DbResult<Vec<Event>> {
        let log = self.user(user_id).await?;
        let loaded = log.lock().await.workouts_loaded;
        if !loaded {
            self.load_workouts(user_id, &log).await?;
        }
        let log = log.lock().await;
        Ok(log
            .workouts
            .iter()
            .find(|(w, _)| w == workout_id)
            .map(|(_, events)| events.iter().map(|e| (**e).clone()).collect())
            .unwrap_or_default())
    }

    /// The latest workouts' shared events from the files, once an account
    /// is loaded (after a restart, or back from idle).
    async fn load_workouts(
        &self,
        user_id: &str,
        log: &Arc<tokio::sync::Mutex<UserLog>>,
    ) -> DbResult<()> {
        let head = log.lock().await.head;
        let from = (head - WORKOUT_REACH as i64).max(0);
        let rows = self.read_user(user_id, from, false).await?;
        let mut log = log.lock().await;
        let held = std::mem::take(&mut log.workouts);
        for (_, _, json) in rows {
            let event: Event = serde_json::from_str(&json)?;
            log.follow_workout(&Arc::new(event));
        }
        // What came since (buffered, or placed while reading) on top.
        let mut since: Vec<Arc<Event>> = held.into_iter().flat_map(|(_, e)| e).collect();
        since.extend(log.buffered.clone());
        for event in since {
            log.follow_workout(&event);
        }
        log.workouts_loaded = true;
        Ok(())
    }

    // ── Moving in ──

    /// A database from before the ledger holds its events in
    /// `account_events`: they are written as files (sorted by account),
    /// indexed, and the table dropped, in that order, so a crash between
    /// starts the move again from the table.
    async fn move_in_from_sqlite(&self) -> DbResult<()> {
        let has_table: bool = sqlx::query_scalar(
            "SELECT EXISTS (SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'account_events')",
        )
        .fetch_one(&self.read_pool)
        .await?;
        if !has_table {
            return Ok(());
        }
        // A move a crash cut short: its files go, and it starts again.
        for path in files::list(&self.dir)? {
            if path.to_string_lossy().contains("-moved-") {
                std::fs::remove_file(path)?;
            }
        }
        let total: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM account_events")
            .fetch_one(&self.read_pool)
            .await?;
        let mut written = Vec::new();
        let (mut after_user, mut after_seq) = (String::new(), 0i64);
        let mut part = 0;
        loop {
            let chunk: Vec<(String, i64, String, String)> = sqlx::query_as(
                "SELECT user_id, seq, id, event FROM account_events
                 WHERE (user_id, seq) > (?, ?) ORDER BY user_id, seq LIMIT ?",
            )
            .bind(&after_user)
            .bind(after_seq)
            .bind(ROWS_PER_FILE as i64)
            .fetch_all(&self.read_pool)
            .await?;
            let Some(last) = chunk.last() else { break };
            (after_user, after_seq) = (last.0.clone(), last.1);
            let rows: Vec<Row> = chunk
                .into_iter()
                .map(|(user_id, seq, id, event)| {
                    let at = serde_json::from_str::<serde_json::Value>(&event)
                        .ok()
                        .and_then(|v| v["at"].as_i64())
                        .unwrap_or(0);
                    Row {
                        heart_rate: event.contains("\"HeartRateRecorded\":"),
                        user_id,
                        seq,
                        id,
                        at,
                        event,
                    }
                })
                .collect();
            let name = format!("0000000000000-moved-{part:06}.parquet");
            part += 1;
            let path = self.dir.join(&name);
            let spans = tokio::task::spawn_blocking(move || -> std::io::Result<_> {
                files::write(&path, &rows)?;
                Ok(files::spans(&rows))
            })
            .await??;
            written.push((name, spans));
        }
        self.index(&written).await?;
        sqlx::query("DROP TABLE account_events")
            .execute(&self.write_pool)
            .await?;
        tracing::info!(
            events = total,
            files = written.len(),
            "moved account events into the ledger"
        );
        Ok(())
    }
}

/// What a snapshot is written from.
struct Snapshot {
    account: Account,
    seq: i64,
    recent: Vec<String>,
}

/// The account's snapshot as folded now; its tail, folded in, is let go.
fn log_snapshot(log: &mut UserLog) -> Snapshot {
    let (account, seq) = log.account.clone().expect("folded before a snapshot");
    log.snapshot_seq = seq;
    log.tail.retain(|e| e.seq > seq);
    Snapshot {
        account,
        seq,
        recent: log
            .recent
            .iter()
            .rev()
            .take(RECENT_IDS)
            .rev()
            .cloned()
            .collect(),
    }
}
