//! The account file: one SQLite file per account. It holds the account as
//! the server last placed it, written down (`base`, a snapshot as of a seq),
//! the events the server placed since (`placed`, folded into the base now
//! and then and let go), and the ones recorded here that the server hasn't
//! placed yet (`pending`). The account itself lives in memory: the base with
//! the placed events folded on, then the pending applied on top. The server
//! keeps every event; this file keeps the account. The readable tables
//! (`schlift_core::projection`) are written only into an export.

use std::collections::{HashMap, HashSet};
use std::path::Path;

use prost::Message;
use rusqlite::{params, Connection, OptionalExtension};
use schlift_core::account::Account;
use schlift_core::api::{self, Call};
use schlift_core::events::Event;
use schlift_core::pb::{
    AppendWorkoutHeartRateRequest, AppendWorkoutHeartRateResponse, GetWorkoutHeartRateRequest,
    GetWorkoutHeartRateResponse, WorkoutHeartRatePoint,
};
use schlift_core::projection::{
    account_export_statements, Statement, Value, ACCOUNT_SCHEMA, READABLE_TABLES, WORKOUT_SCHEMA,
};

const SCHEMA: &str = r#"
CREATE TABLE IF NOT EXISTS meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- The account as placed up to `seq`, written down (schlift_core::snapshot,
-- by the rules `fold`): from the server whole, or this file's own fold of
-- what it placed.
CREATE TABLE IF NOT EXISTS base (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    seq INTEGER NOT NULL,
    fold TEXT NOT NULL,
    state BLOB NOT NULL
);

-- Events the server placed after the base, in its order, each an event as
-- JSON (schlift_core::events): folded into the base once there are
-- `FOLD_PLACED_AT`, and deleted.
CREATE TABLE IF NOT EXISTS placed (
    seq INTEGER PRIMARY KEY,
    id TEXT NOT NULL UNIQUE,
    event TEXT NOT NULL
);

-- Events recorded on this device that the server hasn't given a place yet,
-- oldest first: sent on every connect until they come back with one.
CREATE TABLE IF NOT EXISTS pending (
    n INTEGER PRIMARY KEY AUTOINCREMENT,
    id TEXT NOT NULL UNIQUE,
    event TEXT NOT NULL
);

-- Heart rate heard during a workout under way, this device's alone and
-- never synced: once the workout ends it is recorded whole, as one event,
-- and cleared from here.
CREATE TABLE IF NOT EXISTS heart_rate (
    workout_id TEXT NOT NULL,
    sampled_at INTEGER NOT NULL,
    bpm REAL NOT NULL,
    PRIMARY KEY (workout_id, sampled_at)
) WITHOUT ROWID;
"#;

/// What `PRAGMA user_version` says a file is. A file from before programs
/// (2) has its events dropped, placed and pending alike: the server sends
/// its moved copy. One from before the base (3) has its placed events moved
/// into `placed`, and folded into a base from there.
const FORMAT: i64 = 3;

/// Placed events held before they're folded into the base and let go.
const FOLD_PLACED_AT: i64 = 256;

/// The most events in one push.
pub const PUSH_EVENTS: i64 = 500;

/// A store error, as the app shows it: `code: message`, where code is
/// invalid_argument, not_found, failed_precondition or storage.
pub type StoreResult<T> = Result<T, String>;

fn storage(error: impl std::fmt::Display) -> String {
    format!("storage: {error}")
}

pub struct Store {
    conn: Connection,
    user_id: String,
    /// The account as the server placed it: the base, the placed folded on.
    confirmed: Account,
    /// The last seq the server placed that `confirmed` holds, and the id
    /// of the event there (`meta` 'last_id').
    confirmed_seq: i64,
    confirmed_id: String,
    /// The base was folded by other rules (an app update since): it is
    /// shown until the server sends the account again, and the stream
    /// opens from nothing so it does.
    stale: bool,
    /// What the app shows: `confirmed`, with the pending applied on top.
    account: Account,
    /// Session partners' workouts, as the events the server forwarded:
    /// folded for what they're up to, held only while the app runs.
    partners: HashMap<String, Vec<Event>>,
}

impl Store {
    /// Open (or create) the file for `user_id`, known as `name` (kept in
    /// the file so it opens with no server). A file belonging to someone
    /// else is refused.
    pub fn open(path: &Path, user_id: &str, name: &str) -> StoreResult<Self> {
        let conn = Connection::open(path).map_err(storage)?;
        let format: i64 = conn
            .query_row("PRAGMA user_version", [], |r| r.get(0))
            .map_err(storage)?;
        if format < 2 {
            // Everything but who the file is for is the server's to send.
            conn.execute_batch(
                "DROP TABLE IF EXISTS events; DROP TABLE IF EXISTS pending;
                 DROP TABLE IF EXISTS library;",
            )
            .map_err(storage)?;
        }
        conn.execute_batch(SCHEMA).map_err(storage)?;
        if format == 2 {
            // Its history becomes placed events, folded into a base below.
            conn.execute_batch(
                "INSERT OR IGNORE INTO placed (seq, id, event) SELECT seq, id, event FROM events;
                 INSERT OR REPLACE INTO meta (key, value)
                     SELECT 'last_id', id FROM events ORDER BY seq DESC LIMIT 1;
                 DROP TABLE events;",
            )
            .map_err(storage)?;
        }
        if format < FORMAT {
            conn.execute_batch(&format!(
                "DELETE FROM meta WHERE key = 'acked'; PRAGMA user_version = {FORMAT};"
            ))
            .map_err(storage)?;
        }
        let owner: Option<String> = conn
            .query_row("SELECT value FROM meta WHERE key = 'user_id'", [], |r| {
                r.get(0)
            })
            .optional()
            .map_err(storage)?;
        match owner {
            Some(owner) if owner != user_id => {
                return Err(format!(
                    "failed_precondition: this file belongs to another account ({owner})"
                ))
            }
            Some(_) => {}
            None => {
                conn.execute(
                    "INSERT INTO meta (key, value) VALUES ('user_id', ?)",
                    [user_id],
                )
                .map_err(storage)?;
            }
        }
        if !name.is_empty() {
            conn.execute(
                "INSERT INTO meta (key, value) VALUES ('name', ?)
                 ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                [name],
            )
            .map_err(storage)?;
        }
        let mut store = Self {
            conn,
            user_id: user_id.to_string(),
            confirmed: Account::default(),
            confirmed_seq: 0,
            confirmed_id: String::new(),
            stale: false,
            account: Account::default(),
            partners: HashMap::new(),
        };
        store.load_confirmed()?;
        store.fold_placed_if_due()?;
        store.refold()?;
        Ok(store)
    }

    /// The account as placed, from the file: the base, then the placed
    /// events folded on.
    fn load_confirmed(&mut self) -> StoreResult<()> {
        let base: Option<(i64, String, Vec<u8>)> = self
            .conn
            .query_row("SELECT seq, fold, state FROM base WHERE id = 1", [], |r| {
                Ok((r.get(0)?, r.get(1)?, r.get(2)?))
            })
            .optional()
            .map_err(storage)?;
        let (mut account, mut seq, stale) = match base {
            None => (Account::default(), 0, false),
            Some((seq, _, state)) => match schlift_core::snapshot::restore(&state) {
                Ok((account, _)) => (account, seq, false),
                // Folded by other rules (an app update): shown as best it
                // reads, until the server sends the account again.
                Err(_) => {
                    let shown = schlift_core::snapshot::restore_by_any_rules(&state)
                        .map(|(account, _)| account)
                        .unwrap_or_default();
                    (shown, seq, true)
                }
            },
        };
        // A base from the server leaves heart rate out; what this phone
        // records from here is folded in.
        account.without_heart_rate = false;
        for event in self.placed()? {
            account.replay(&event);
            seq = event.seq;
        }
        self.confirmed = account;
        self.confirmed_seq = seq;
        self.confirmed_id = self
            .conn
            .query_row("SELECT value FROM meta WHERE key = 'last_id'", [], |r| {
                r.get(0)
            })
            .optional()
            .map_err(storage)?
            .unwrap_or_default();
        self.stale = stale;
        Ok(())
    }

    /// Once enough placed events are held, they're folded into the base,
    /// written down, and let go.
    fn fold_placed_if_due(&mut self) -> StoreResult<()> {
        let held: i64 = self
            .conn
            .query_row("SELECT COUNT(*) FROM placed", [], |r| r.get(0))
            .map_err(storage)?;
        if held < FOLD_PLACED_AT || self.stale {
            return Ok(());
        }
        let state = schlift_core::snapshot::snapshot(&self.confirmed, self.confirmed_seq);
        let tx = self.conn.transaction().map_err(storage)?;
        write_base(&tx, self.confirmed_seq, &state)?;
        tx.execute("DELETE FROM placed", []).map_err(storage)?;
        tx.commit().map_err(storage)
    }

    /// What the app shows again: the placed account, then what's pending.
    fn refold(&mut self) -> StoreResult<()> {
        let mut account = self.confirmed.clone();
        for event in self.pending()? {
            account.replay(&event);
        }
        self.account = account;
        Ok(())
    }

    /// The account as the server placed it (pending aside).
    pub fn confirmed_account(&self) -> &Account {
        &self.confirmed
    }

    /// Answer one RPC; a write's events are stored before the answer is
    /// given, so nothing the app was told happened can be lost.
    pub fn call(&mut self, method: &str, request: &[u8], now: i64) -> StoreResult<Vec<u8>> {
        match method {
            // Gathered here until the workout ends, not recorded as it comes.
            "AppendWorkoutHeartRate" => {
                let req = AppendWorkoutHeartRateRequest::decode(request).map_err(|e| {
                    format!("invalid_argument: bad AppendWorkoutHeartRate request: {e}")
                })?;
                self.gather_heart_rate(&req.workout_id, &req.samples)?;
                return Ok(AppendWorkoutHeartRateResponse {}.encode_to_vec());
            }
            "GetWorkoutHeartRate" => {
                let mut response = GetWorkoutHeartRateResponse::decode(
                    self.answer(method, request, now)?.as_slice(),
                )
                .map_err(storage)?;
                let req = GetWorkoutHeartRateRequest::decode(request).map_err(storage)?;
                response.samples.extend(self.gathered(&req.workout_id)?);
                response.samples.sort_by_key(|s| s.sampled_at);
                response.samples.dedup_by_key(|s| s.sampled_at);
                return Ok(response.encode_to_vec());
            }
            _ => {}
        }
        let response = self.answer(method, request, now)?;
        self.record_ended_heart_rate(now)?;
        Ok(response)
    }

    /// The core's answer, its events stored first.
    fn answer(&mut self, method: &str, request: &[u8], now: i64) -> StoreResult<Vec<u8>> {
        let event_id = uuid::Uuid::new_v4().to_string();
        let mut call = Call::new(&mut self.account, now, event_id);
        let answered = api::call(&mut call, method, request);
        let events = std::mem::take(&mut call.events);
        let response = match answered {
            Ok(response) => response,
            Err(e) => {
                // A call can fail after recording some of its events: they
                // are in memory but not written, so go back to the file.
                if !events.is_empty() {
                    self.refold()?;
                }
                let code = match e {
                    schlift_core::account::CoreError::InvalidArgument(_) => "invalid_argument",
                    schlift_core::account::CoreError::NotFound(_) => "not_found",
                    schlift_core::account::CoreError::FailedPrecondition(_) => {
                        "failed_precondition"
                    }
                };
                return Err(format!("{code}: {e}"));
            }
        };
        if !events.is_empty() {
            if let Err(error) = self.add_pending(&events) {
                // Memory ran ahead of the file: go back to what was written.
                self.refold()?;
                return Err(error);
            }
        }
        Ok(response)
    }

    fn add_pending(&mut self, events: &[Event]) -> StoreResult<()> {
        let tx = self.conn.transaction().map_err(storage)?;
        add_pending(&tx, events)?;
        tx.commit().map_err(storage)
    }

    fn gather_heart_rate(
        &mut self,
        workout_id: &str,
        samples: &[WorkoutHeartRatePoint],
    ) -> StoreResult<()> {
        let tx = self.conn.transaction().map_err(storage)?;
        for sample in samples {
            tx.prepare_cached(
                "INSERT OR IGNORE INTO heart_rate (workout_id, sampled_at, bpm) VALUES (?, ?, ?)",
            )
            .and_then(|mut insert| {
                insert.execute(params![workout_id, sample.sampled_at, sample.bpm])
            })
            .map_err(storage)?;
        }
        tx.commit().map_err(storage)
    }

    /// The heart rate gathered for a workout and not yet recorded.
    fn gathered(&self, workout_id: &str) -> StoreResult<Vec<WorkoutHeartRatePoint>> {
        let mut query = self
            .conn
            .prepare_cached(
                "SELECT sampled_at, bpm FROM heart_rate WHERE workout_id = ? ORDER BY sampled_at",
            )
            .map_err(storage)?;
        let rows = query
            .query_map([workout_id], |r| {
                Ok(WorkoutHeartRatePoint {
                    sampled_at: r.get(0)?,
                    bpm: r.get::<_, f64>(1)? as f32,
                })
            })
            .map_err(storage)?;
        rows.collect::<Result<_, _>>().map_err(storage)
    }

    /// Each workout that has ended with heart rate gathered gets it
    /// recorded, whole (with any recorded before), as one event; what was
    /// gathered goes in the same transaction.
    fn record_ended_heart_rate(&mut self, now: i64) -> StoreResult<()> {
        let workouts: Vec<String> = {
            let mut query = self
                .conn
                .prepare_cached("SELECT DISTINCT workout_id FROM heart_rate")
                .map_err(storage)?;
            let rows = query.query_map([], |r| r.get(0)).map_err(storage)?;
            rows.collect::<Result<_, _>>().map_err(storage)?
        };
        for workout_id in workouts {
            let Some(record) = self.account.workout(&workout_id) else {
                // Thrown away: its heart rate goes with it.
                self.conn
                    .execute("DELETE FROM heart_rate WHERE workout_id = ?", [&workout_id])
                    .map_err(storage)?;
                continue;
            };
            if record.workout.end_time == 0 {
                continue;
            }
            let mut samples = record.heart_rate.clone();
            samples.extend(self.gathered(&workout_id)?);
            let event_id = uuid::Uuid::new_v4().to_string();
            let mut call = Call::new(&mut self.account, now, event_id);
            // The workout is there, so this can't be refused.
            call.record_heart_rate(&workout_id, &samples)
                .map_err(|e| format!("failed_precondition: {e}"))?;
            let events = std::mem::take(&mut call.events);
            let stored = (|| {
                let tx = self.conn.transaction().map_err(storage)?;
                add_pending(&tx, &events)?;
                tx.execute("DELETE FROM heart_rate WHERE workout_id = ?", [&workout_id])
                    .map_err(storage)?;
                tx.commit().map_err(storage)
            })();
            if let Err(error) = stored {
                self.refold()?;
                return Err(error);
            }
        }
        Ok(())
    }

    /// A session partner's workout events from the server: their workout so
    /// far (`whole`, replacing what was held) or more of it. One already
    /// held is skipped.
    pub fn receive_partner(&mut self, partner: &str, events: Vec<Event>, whole: bool) {
        let held = self.partners.entry(partner.to_string()).or_default();
        if whole {
            held.clear();
        }
        for event in events {
            if !held.iter().any(|e| e.id == event.id) {
                held.push(event);
            }
        }
    }

    /// Where a partner is up to, folded from their events (see
    /// `schlift_core::session::partner_status`), as proto bytes; None once
    /// they're off show.
    pub fn partner_status(
        &self,
        partner: &str,
        joined_at: i64,
        ended_at: i64,
        now: i64,
    ) -> Option<Vec<u8>> {
        let held = self.partners.get(partner).map_or(&[][..], Vec::as_slice);
        schlift_core::session::partner_status(held, joined_at, ended_at, now)
            .map(|status| status.encode_to_vec())
    }

    /// Drop the partners no longer in the session.
    pub fn keep_partners(&mut self, partners: &[String]) {
        self.partners
            .retain(|partner, _| partners.contains(partner));
    }

    /// The last seq this file holds placed: where the server picks up.
    pub fn confirmed(&self) -> StoreResult<i64> {
        Ok(self.confirmed_seq)
    }

    /// What a Sync stream opens with: the last seq placed, or nothing while
    /// the base is by other rules, so the server sends the account whole.
    pub fn opens_after(&self) -> StoreResult<i64> {
        Ok(if self.stale { 0 } else { self.confirmed_seq })
    }

    /// The id of the last event the server placed that this file holds:
    /// what a stream opens with, so a server holding another there sends
    /// the account whole.
    pub fn confirmed_id(&self) -> &str {
        &self.confirmed_id
    }

    /// The placed events held since the base, in order.
    pub fn placed(&self) -> StoreResult<Vec<Event>> {
        self.read("SELECT event FROM placed ORDER BY seq")
    }

    /// The ids of what waits for the server, oldest first: sent when a
    /// stream opens, so the server says which it holds by the account it
    /// sends whole.
    pub fn pending_ids(&self) -> StoreResult<Vec<String>> {
        let mut query = self
            .conn
            .prepare_cached("SELECT id FROM pending ORDER BY n")
            .map_err(storage)?;
        let ids = query
            .query_map([], |r| r.get(0))
            .map_err(storage)?
            .collect::<Result<Vec<String>, _>>()
            .map_err(storage)?;
        Ok(ids)
    }

    /// When the oldest event waiting for the server was recorded (Unix
    /// seconds), if one waits: the app says it's unsynced only once that is
    /// a while ago, since the server acks a minute or so after a push.
    pub fn oldest_pending_at(&self) -> StoreResult<Option<i64>> {
        Ok(self.pending()?.iter().map(|e| e.at).min())
    }

    /// What this device recorded that the server hasn't placed, oldest first.
    pub fn pending(&self) -> StoreResult<Vec<Event>> {
        self.read("SELECT event FROM pending ORDER BY n")
    }

    /// Up to `PUSH_EVENTS` pending events after the one numbered `after` (a
    /// stream's last sent), and the number of the last: the next push. A
    /// long time offline goes up in pieces, each well inside what the
    /// server takes in one message.
    pub fn pending_after(&self, after: i64) -> StoreResult<(Vec<Event>, i64)> {
        let mut query = self
            .conn
            .prepare_cached("SELECT n, event FROM pending WHERE n > ? ORDER BY n LIMIT ?")
            .map_err(storage)?;
        let rows = query
            .query_map([after, PUSH_EVENTS], |r| {
                Ok((r.get::<_, i64>(0)?, r.get::<_, String>(1)?))
            })
            .map_err(storage)?
            .collect::<Result<Vec<_>, _>>()
            .map_err(storage)?;
        let last = rows.last().map_or(after, |(n, _)| *n);
        let events = rows
            .iter()
            .map(|(_, json)| serde_json::from_str(json).map_err(storage))
            .collect::<StoreResult<Vec<Event>>>()?;
        Ok((events, last))
    }

    /// How many events wait for the server.
    pub fn pending_count(&self) -> StoreResult<i64> {
        self.conn
            .query_row("SELECT COUNT(*) FROM pending", [], |r| r.get(0))
            .map_err(storage)
    }

    fn read(&self, sql: &str) -> StoreResult<Vec<Event>> {
        read(&self.conn, sql)
    }

    /// Bring in an export of this account: every event in it this file
    /// doesn't hold (by id, placed here or waiting) waits after the rest,
    /// in the export's order, for the server to place; the server skips any
    /// it holds. Heart rate gathered for a workout under way comes along.
    /// So an import only ever adds: nothing here is removed, and the same
    /// file brought in again adds nothing. Returns how many events it
    /// added. A file that won't read whole adds nothing.
    pub fn import(&mut self, path: &Path) -> StoreResult<usize> {
        let (owner, _) = file_owner(path)?;
        if owner != self.user_id {
            return Err("failed_precondition: that file is a different account".to_string());
        }
        let conn = Connection::open_with_flags(path, rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY)
            .map_err(storage)?;
        let format: i64 = conn
            .query_row("PRAGMA user_version", [], |r| r.get(0))
            .map_err(storage)?;
        if format < 2 {
            // Its events are in a form from before, which nothing reads.
            return Ok(0);
        }
        // Placed there: the whole history (2), or what came after its base (3).
        let placed_table = if format == 2 { "events" } else { "placed" };
        let placed = read(
            &conn,
            &format!("SELECT event FROM {placed_table} ORDER BY seq"),
        )?;
        let waiting = read(&conn, "SELECT event FROM pending ORDER BY n")?;
        let heart_rate: Vec<(String, i64, f64)> = {
            let mut query = conn
                .prepare("SELECT workout_id, sampled_at, bpm FROM heart_rate")
                .map_err(storage)?;
            let rows = query
                .query_map([], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))
                .map_err(storage)?;
            rows.collect::<Result<_, _>>().map_err(storage)?
        };
        let mut held: HashSet<String> = self.placed()?.into_iter().map(|e| e.id).collect();
        held.extend(self.pending_ids()?);
        let added: Vec<Event> = placed
            .into_iter()
            .chain(waiting)
            .filter(|e| held.insert(e.id.clone()))
            .map(|e| Event { seq: 0, ..e })
            .collect();
        let tx = self.conn.transaction().map_err(storage)?;
        add_pending(&tx, &added)?;
        for (workout_id, sampled_at, bpm) in &heart_rate {
            tx.execute(
                "INSERT OR IGNORE INTO heart_rate (workout_id, sampled_at, bpm) VALUES (?, ?, ?)",
                params![workout_id, sampled_at, bpm],
            )
            .map_err(storage)?;
        }
        tx.commit().map_err(storage)?;
        if !added.is_empty() {
            self.refold()?;
        }
        Ok(added.len())
    }

    /// Events from the server, in its order, and the last seq it holds.
    /// Ones this device recorded leave `pending`. Returns whether the
    /// account changed under the app: another device's events arrived. A
    /// gap after what this file holds is refused and changes nothing (the
    /// next stream picks up from here).
    pub fn receive(&mut self, events: Vec<Event>, _head: i64) -> StoreResult<bool> {
        let held = self.confirmed_seq;
        let new: Vec<Event> = events.into_iter().filter(|e| e.seq > held).collect();
        let Some(first) = new.first() else {
            return Ok(false);
        };
        if first.seq != held + 1 {
            return Err(format!(
                "failed_precondition: the server's events start at {}, after {held}",
                first.seq
            ));
        }
        let pending = self.pending()?;
        // The usual case: the server placed this device's own events, next
        // in line, and nothing else; the account already has them.
        let ours =
            new.len() <= pending.len() && new.iter().zip(&pending).all(|(n, p)| n.id == p.id);
        let tx = self.conn.transaction().map_err(storage)?;
        for event in &new {
            let json = serde_json::to_string(event).map_err(storage)?;
            tx.execute(
                "INSERT OR REPLACE INTO placed (seq, id, event) VALUES (?, ?, ?)",
                params![event.seq, event.id, json],
            )
            .map_err(storage)?;
            tx.execute("DELETE FROM pending WHERE id = ?", [&event.id])
                .map_err(storage)?;
        }
        let last = new.last().map(|e| e.id.clone()).unwrap_or_default();
        write_last_id(&tx, &last)?;
        tx.commit().map_err(storage)?;
        for event in &new {
            self.confirmed.replay(event);
            self.confirmed_seq = event.seq;
        }
        self.confirmed_id = last;
        self.fold_placed_if_due()?;
        if ours {
            return Ok(false);
        }
        self.refold()?;
        Ok(true)
    }

    /// The account whole from the server (`schlift_core::snapshot`), as of
    /// `seq`, and which of this device's pending events it holds already:
    /// those leave `pending`, and it becomes the base. What was placed here
    /// before goes; what waits is applied on top as ever.
    pub fn receive_account(
        &mut self,
        snapshot: &[u8],
        seq: i64,
        last_id: &str,
        placed_ids: &[String],
    ) -> StoreResult<()> {
        let (mut account, _) = schlift_core::snapshot::restore(snapshot)
            .map_err(|e| format!("failed_precondition: the account doesn't read: {e}"))?;
        account.without_heart_rate = false;
        let tx = self.conn.transaction().map_err(storage)?;
        write_base(&tx, seq, snapshot)?;
        write_last_id(&tx, last_id)?;
        tx.execute("DELETE FROM placed", []).map_err(storage)?;
        for id in placed_ids {
            tx.execute("DELETE FROM pending WHERE id = ?", [id])
                .map_err(storage)?;
        }
        tx.commit().map_err(storage)?;
        self.confirmed = account;
        self.confirmed_seq = seq;
        self.confirmed_id = last_id.to_string();
        self.stale = false;
        self.refold()
    }

    /// A copy of the whole file at `dest`, with the readable tables
    /// written in: the export.
    pub fn export(&self, dest: &Path) -> StoreResult<()> {
        let _ = std::fs::remove_file(dest);
        self.conn
            .execute("VACUUM INTO ?", [dest.to_string_lossy()])
            .map_err(storage)?;
        let mut conn = Connection::open(dest).map_err(storage)?;
        let tx = conn.transaction().map_err(storage)?;
        for table in READABLE_TABLES {
            tx.execute_batch(&format!("DROP TABLE IF EXISTS {table};"))
                .map_err(storage)?;
        }
        tx.execute_batch(&format!("{WORKOUT_SCHEMA}{ACCOUNT_SCHEMA}"))
            .map_err(storage)?;
        for statement in account_export_statements(&self.user_id, &self.account) {
            run(&tx, statement)?;
        }
        tx.commit().map_err(storage)
    }
}

/// Whose account an exported file holds — the user's id and name —
/// without opening it as the store.
pub fn file_owner(path: &Path) -> StoreResult<(String, String)> {
    let conn = Connection::open_with_flags(path, rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY)
        .map_err(storage)?;
    let meta = |key: &str| {
        conn.query_row("SELECT value FROM meta WHERE key = ?", [key], |r| {
            r.get::<_, String>(0)
        })
        .optional()
    };
    let not_ours = || "invalid_argument: not a Schlift account file".to_string();
    let user_id = meta("user_id")
        .map_err(|_| not_ours())?
        .ok_or_else(not_ours)?;
    // The id names the account's file, so it must be an id the server made.
    uuid::Uuid::parse_str(&user_id).map_err(|_| not_ours())?;
    let name = meta("name").map_err(|_| not_ours())?.unwrap_or_default();
    Ok((user_id, name))
}

/// The id of the last placed event this file holds.
fn write_last_id(tx: &rusqlite::Transaction, id: &str) -> StoreResult<()> {
    tx.execute(
        "INSERT INTO meta (key, value) VALUES ('last_id', ?)
         ON CONFLICT (key) DO UPDATE SET value = excluded.value",
        [id],
    )
    .map_err(storage)?;
    Ok(())
}

/// The base, as of `seq`: replaced whole.
fn write_base(tx: &rusqlite::Transaction, seq: i64, state: &[u8]) -> StoreResult<()> {
    tx.execute(
        "INSERT INTO base (id, seq, fold, state) VALUES (1, ?, ?, ?)
         ON CONFLICT (id) DO UPDATE SET seq = excluded.seq, fold = excluded.fold,
             state = excluded.state",
        params![seq, schlift_core::FOLD, state],
    )
    .map_err(storage)?;
    Ok(())
}

/// The events `sql` selects, one JSON event a row.
fn read(conn: &Connection, sql: &str) -> StoreResult<Vec<Event>> {
    let mut query = conn.prepare_cached(sql).map_err(storage)?;
    let rows = query
        .query_map([], |r| r.get::<_, String>(0))
        .map_err(storage)?
        .collect::<Result<Vec<_>, _>>()
        .map_err(storage)?;
    rows.iter()
        .map(|json| serde_json::from_str(json).map_err(storage))
        .collect()
}

fn add_pending(tx: &rusqlite::Transaction, events: &[Event]) -> StoreResult<()> {
    for event in events {
        let json = serde_json::to_string(event).map_err(storage)?;
        tx.prepare_cached("INSERT INTO pending (id, event) VALUES (?, ?)")
            .and_then(|mut insert| insert.execute(params![event.id, json]))
            .map_err(storage)?;
    }
    Ok(())
}

fn run(tx: &rusqlite::Transaction, statement: Statement) -> StoreResult<()> {
    let params: Vec<rusqlite::types::Value> = statement
        .params
        .into_iter()
        .map(|v| match v {
            Value::Int(v) => rusqlite::types::Value::Integer(v),
            Value::Real(v) => rusqlite::types::Value::Real(v),
            Value::Text(v) => rusqlite::types::Value::Text(v),
            Value::Blob(v) => rusqlite::types::Value::Blob(v),
        })
        .collect();
    tx.prepare_cached(statement.sql)
        .and_then(|mut query| query.execute(rusqlite::params_from_iter(params)))
        .map_err(storage)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use schlift_core::pb::{
        CompleteOnboardingRequest, EndWorkoutRequest, GetHomeRequest, GetHomeResponse,
        StartWorkoutRequest, StartWorkoutResponse, WeightUnit,
    };

    fn temp(name: &str) -> std::path::PathBuf {
        std::env::temp_dir().join(format!(
            "schlift-native-{name}-{}.sqlite",
            uuid::Uuid::new_v4()
        ))
    }

    const U1: &str = "6f1c1d6e-6a39-4c55-9a7e-1b8a8f3f2a01";
    const U2: &str = "0b6d2c9a-3f5e-4d1a-8c2b-7e9f1a4d5c02";

    fn start(store: &mut Store, template_id: &str) -> StartWorkoutResponse {
        StartWorkoutResponse::decode(
            store
                .call(
                    "StartWorkout",
                    &StartWorkoutRequest {
                        template_id: template_id.to_string(),
                        ..Default::default()
                    }
                    .encode_to_vec(),
                    2_000,
                )
                .unwrap()
                .as_slice(),
        )
        .unwrap()
    }

    fn onboard(store: &mut Store) -> GetHomeResponse {
        store
            .call(
                "CompleteOnboarding",
                &CompleteOnboardingRequest {
                    unit: WeightUnit::Kg as i32,
                    ..Default::default()
                }
                .encode_to_vec(),
                1_000,
            )
            .unwrap();
        let bytes = store
            .call("GetHome", &GetHomeRequest::default().encode_to_vec(), 1_000)
            .unwrap();
        GetHomeResponse::decode(bytes.as_slice()).unwrap()
    }

    /// The server's part: give `events` the next places after `head`.
    fn place(events: Vec<Event>, head: i64) -> Vec<Event> {
        events
            .into_iter()
            .zip(head + 1..)
            .map(|(e, seq)| Event { seq, ..e })
            .collect()
    }

    #[test]
    fn a_reopened_file_is_the_same_account() {
        let path = temp("reopen");
        let mut store = Store::open(&path, U1, "una").unwrap();
        let home = onboard(&mut store);
        let placed = place(store.pending().unwrap(), 0);
        store.receive(placed, 1).unwrap();
        let started = start(&mut store, &home.templates[0].id);
        let before = store.account.clone();
        drop(store);

        let store = Store::open(&path, U1, "una").unwrap();
        assert_eq!(store.account, before, "history, then what's pending");
        assert_eq!(store.account.active_workout_id, started.id);
    }

    #[test]
    fn someone_elses_file_is_refused() {
        let path = temp("owner");
        Store::open(&path, U1, "una").unwrap();
        assert!(Store::open(&path, U2, "").is_err());
        assert_eq!(file_owner(&path).unwrap(), (U1.into(), "una".into()));
    }

    #[test]
    fn a_file_whose_owner_is_not_an_id_is_refused() {
        let path = temp("not-an-id");
        Store::open(&path, "../../elsewhere", "").unwrap();
        assert!(file_owner(&path).is_err());
    }

    #[test]
    fn own_events_placed_by_the_server_leave_pending() {
        let mut store = Store::open(&temp("own"), U1, "").unwrap();
        onboard(&mut store);
        let pending = store.pending().unwrap();
        assert_eq!(pending.len(), 1);
        assert_eq!(store.confirmed().unwrap(), 0);
        let before = store.account.clone();
        assert!(
            !store.receive(place(pending, 0), 1).unwrap(),
            "nothing new to the app"
        );
        assert!(store.pending().unwrap().is_empty());
        assert_eq!(store.confirmed().unwrap(), 1);
        assert_eq!(store.account, before);
        // The same events again change nothing.
        let again = store.placed().unwrap();
        assert!(!store.receive(again, 1).unwrap());
    }

    #[test]
    fn another_devices_events_go_first_and_ours_replay_after() {
        let mut phone = Store::open(&temp("phone"), U1, "").unwrap();
        let mut tablet = Store::open(&temp("tablet"), U1, "").unwrap();
        let home = onboard(&mut tablet);
        let theirs = place(tablet.pending().unwrap(), 0);
        tablet.receive(theirs.clone(), 1).unwrap();
        // The phone, offline, starts a workout from the same library.
        phone.receive(theirs.clone(), 1).unwrap();
        let started = start(&mut phone, &home.templates[0].id);
        // The tablet saves a setting meanwhile, placed first.
        tablet
            .call(
                "UpdateSetting",
                &schlift_core::pb::UpdateSettingRequest {
                    setting: Some(schlift_core::pb::UserSetting {
                        setting: Some(schlift_core::pb::user_setting::Setting::WeightUnit(
                            schlift_core::pb::WeightUnitConfig {
                                unit: WeightUnit::Lb as i32,
                            },
                        )),
                    }),
                }
                .encode_to_vec(),
                3_000,
            )
            .unwrap();
        let setting = place(tablet.pending().unwrap(), 1);
        let ours = place(phone.pending().unwrap(), 2);
        assert!(
            phone.receive(setting.clone(), 2).unwrap(),
            "the account moved under the app"
        );
        assert_eq!(
            phone.pending().unwrap().len(),
            1,
            "still waiting for a place"
        );
        assert_eq!(
            phone.account.active_workout_id, started.id,
            "replayed on top"
        );
        assert!(!phone.receive(ours.clone(), 3).unwrap());
        let history = [theirs, setting, ours].concat();
        assert_eq!(phone.placed().unwrap(), history);
        assert_eq!(phone.account, Account::fold(&history));
        assert_eq!(phone.confirmed_account(), &Account::fold(&history));
    }

    #[test]
    fn a_file_from_before_drops_its_events_for_the_server_to_resend() {
        let path = temp("old");
        let conn = Connection::open(&path).unwrap();
        conn.execute_batch(&format!(
            "CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
             INSERT INTO meta VALUES ('user_id', '{U1}'), ('acked', '7');
             CREATE TABLE events (seq INTEGER PRIMARY KEY, id TEXT NOT NULL,
                 at INTEGER NOT NULL, event_blob BLOB NOT NULL);
             INSERT INTO events VALUES (1, 'e', 1, x'0801');"
        ))
        .unwrap();
        drop(conn);
        let store = Store::open(&path, U1, "").unwrap();
        assert_eq!(store.confirmed().unwrap(), 0);
        assert_eq!(store.account, Account::default());
        drop(store);
        // Opening again keeps what it has.
        let mut store = Store::open(&path, U1, "").unwrap();
        onboard(&mut store);
        drop(store);
        assert_eq!(
            Store::open(&path, U1, "").unwrap().pending().unwrap().len(),
            1
        );
    }

    /// The workout's start, in ms: test readings are counted from it.
    fn start_ms(store: &Store, workout_id: &str) -> i64 {
        store
            .account
            .workout(workout_id)
            .unwrap()
            .workout
            .start_time
            * 1000
    }

    /// Readings at `at` ms after the workout's start.
    fn heart_rate(store: &mut Store, workout_id: &str, at: &[i64], now: i64) {
        let base = start_ms(store, workout_id);
        store
            .call(
                "AppendWorkoutHeartRate",
                &AppendWorkoutHeartRateRequest {
                    workout_id: workout_id.to_string(),
                    samples: at
                        .iter()
                        .map(|&after| WorkoutHeartRatePoint {
                            sampled_at: base + after,
                            bpm: 120.0,
                        })
                        .collect(),
                }
                .encode_to_vec(),
                now,
            )
            .unwrap();
    }

    fn end(store: &mut Store, workout_id: &str, now: i64) {
        store
            .call(
                "EndWorkout",
                &EndWorkoutRequest {
                    workout_id: workout_id.to_string(),
                    ended_at: now,
                }
                .encode_to_vec(),
                now,
            )
            .unwrap();
    }

    /// The readings shown, in ms after the workout's start.
    fn shown_heart_rate(store: &mut Store, workout_id: &str) -> Vec<i64> {
        let base = start_ms(store, workout_id);
        let answer = store
            .call(
                "GetWorkoutHeartRate",
                &GetWorkoutHeartRateRequest {
                    workout_id: workout_id.to_string(),
                }
                .encode_to_vec(),
                0,
            )
            .unwrap();
        GetWorkoutHeartRateResponse::decode(answer.as_slice())
            .unwrap()
            .samples
            .iter()
            .map(|s| s.sampled_at - base)
            .collect()
    }

    #[test]
    fn heart_rate_is_recorded_once_when_the_workout_ends() {
        let path = temp("hr");
        let mut store = Store::open(&path, U1, "").unwrap();
        let home = onboard(&mut store);
        let started = start(&mut store, &home.templates[0].id);
        let before = store.pending().unwrap().len();
        heart_rate(&mut store, &started.id, &[1_000, 3_000], 2_001);
        heart_rate(&mut store, &started.id, &[3_000, 5_000], 2_002);
        assert_eq!(
            store.pending().unwrap().len(),
            before,
            "gathered, not recorded"
        );
        // Kept through a restart, and shown while the workout runs.
        let mut store = Store::open(&path, U1, "").unwrap();
        assert_eq!(
            shown_heart_rate(&mut store, &started.id),
            vec![1_000, 3_000, 5_000]
        );

        end(&mut store, &started.id, 2_010);
        let recorded: Vec<Event> = store
            .pending()
            .unwrap()
            .into_iter()
            .filter(|e| matches!(e.fact, schlift_core::events::Fact::HeartRateRecorded(_)))
            .collect();
        assert_eq!(recorded.len(), 1, "one event, the whole workout");
        assert_eq!(
            shown_heart_rate(&mut store, &started.id),
            vec![1_000, 3_000, 5_000]
        );
        let gathered: i64 = store
            .conn
            .query_row("SELECT COUNT(*) FROM heart_rate", [], |r| r.get(0))
            .unwrap();
        assert_eq!(gathered, 0, "nothing left gathered");
        // A late reading after the end is recorded too, with the rest.
        heart_rate(&mut store, &started.id, &[7_000], 2_020);
        any_call(&mut store);
        assert_eq!(
            shown_heart_rate(&mut store, &started.id),
            vec![1_000, 3_000, 5_000, 7_000]
        );
        assert_eq!(Store::open(&path, U1, "").unwrap().account, store.account);
    }

    #[test]
    fn heart_rate_goes_with_a_discarded_workout() {
        let mut store = Store::open(&temp("discard"), U1, "").unwrap();
        let home = onboard(&mut store);
        let started = start(&mut store, &home.templates[0].id);
        heart_rate(&mut store, &started.id, &[1_000, 2_000], 2_001);
        store
            .call(
                "DiscardWorkout",
                &schlift_core::pb::DiscardWorkoutRequest {
                    workout_id: started.id.clone(),
                }
                .encode_to_vec(),
                2_002,
            )
            .unwrap();
        let gathered: i64 = store
            .conn
            .query_row("SELECT COUNT(*) FROM heart_rate", [], |r| r.get(0))
            .unwrap();
        assert_eq!(gathered, 0);
        assert!(store.account.workout(&started.id).is_none());
    }

    /// Any write: what's gathered for an ended workout is recorded after it.
    fn any_call(store: &mut Store) {
        store
            .call("GetHome", &GetHomeRequest::default().encode_to_vec(), 2_030)
            .unwrap();
    }

    #[test]
    fn a_long_outbox_goes_up_in_pieces() {
        let mut store = Store::open(&temp("pieces"), U1, "").unwrap();
        let setting = schlift_core::pb::UpdateSettingRequest {
            setting: Some(schlift_core::pb::UserSetting {
                setting: Some(schlift_core::pb::user_setting::Setting::WeightUnit(
                    schlift_core::pb::WeightUnitConfig {
                        unit: WeightUnit::Kg as i32,
                    },
                )),
            }),
        }
        .encode_to_vec();
        let recorded = PUSH_EVENTS as usize + 20;
        for n in 0..recorded {
            store.call("UpdateSetting", &setting, n as i64).unwrap();
        }
        let (first, last) = store.pending_after(0).unwrap();
        assert_eq!(first.len(), PUSH_EVENTS as usize);
        let (rest, end) = store.pending_after(last).unwrap();
        assert_eq!(rest.len(), 20);
        assert!(store.pending_after(end).unwrap().0.is_empty());
    }

    #[test]
    fn an_export_opens_as_the_same_account() {
        let mut store = Store::open(&temp("x"), U1, "una").unwrap();
        let home = onboard(&mut store);
        let started = start(&mut store, &home.templates[0].id);
        heart_rate(&mut store, &started.id, &[1_000, 2_000, 3_000], 2_005);
        end(&mut store, &started.id, 2_006);
        let dest = temp("export");
        store.export(&dest).unwrap();
        assert_eq!(file_owner(&dest).unwrap(), (U1.into(), "una".into()));
        let readable = |path: &Path| {
            let exported = Connection::open(path).unwrap();
            let samples: i64 = exported
                .query_row(
                    "SELECT COUNT(*) FROM workout_heart_rate_samples WHERE workout_id = ?",
                    [&started.id],
                    |r| r.get(0),
                )
                .unwrap();
            assert_eq!(samples, 3, "the export has the readable tables");
            let in_rotation: i64 = exported
                .query_row(
                    "SELECT in_rotation FROM workout_templates WHERE id = ?",
                    [&home.templates[0].id],
                    |r| r.get(0),
                )
                .unwrap();
            assert_eq!(in_rotation, i64::from(home.templates[0].in_rotation));
        };
        readable(&dest);
        let reopened = Store::open(&dest, U1, "").unwrap();
        assert_eq!(reopened.account, store.account);

        // An account opened from an export exports again.
        let again = temp("export-again");
        reopened.export(&again).unwrap();
        readable(&again);
    }

    #[test]
    fn an_export_from_an_older_build_exports_again() {
        let path = temp("older");
        let mut store = Store::open(&path, U1, "una").unwrap();
        let home = onboard(&mut store);
        let started = start(&mut store, &home.templates[0].id);
        end(&mut store, &started.id, 2_006);
        drop(store);
        // An older build's export: the readable tables without the columns
        // added since.
        Connection::open(&path)
            .unwrap()
            .execute_batch(
                "CREATE TABLE completed_sets (user_id TEXT, id TEXT, PRIMARY KEY (user_id, id));
                 CREATE TABLE workout_templates (id TEXT PRIMARY KEY, user_id TEXT);",
            )
            .unwrap();
        let reopened = Store::open(&path, U1, "").unwrap();
        let dest = temp("older-export");
        reopened.export(&dest).unwrap();
        let templates: i64 = Connection::open(&dest)
            .unwrap()
            .query_row("SELECT COUNT(*) FROM workout_templates", [], |r| r.get(0))
            .unwrap();
        assert_eq!(templates, home.templates.len() as i64);
    }

    #[test]
    fn readable_tables_names_every_exported_table() {
        let conn = Connection::open_in_memory().unwrap();
        conn.execute_batch(&format!("{WORKOUT_SCHEMA}{ACCOUNT_SCHEMA}"))
            .unwrap();
        let mut created: Vec<String> = conn
            .prepare("SELECT name FROM sqlite_master WHERE type = 'table'")
            .unwrap()
            .query_map([], |r| r.get(0))
            .unwrap()
            .collect::<Result<_, _>>()
            .unwrap();
        created.sort();
        let mut listed: Vec<String> = READABLE_TABLES.iter().map(|t| t.to_string()).collect();
        listed.sort();
        assert_eq!(created, listed);
    }

    #[test]
    fn server_events_after_a_gap_are_refused_and_change_nothing() {
        let mut store = Store::open(&temp("gap"), U1, "").unwrap();
        onboard(&mut store);
        let pending = store.pending().unwrap();
        let before = store.account.clone();
        // Placed at 2 while this file holds nothing: seq 1 is missing.
        let error = store.receive(place(pending.clone(), 1), 2).unwrap_err();
        assert!(error.starts_with("failed_precondition"), "{error}");
        assert!(store.placed().unwrap().is_empty());
        assert_eq!(store.pending().unwrap(), pending);
        assert_eq!(store.confirmed().unwrap(), 0);
        assert_eq!(store.account, before);
    }

    /// The server's placement, as `push_events` does it: what it doesn't
    /// hold, by id, after the head.
    fn push(server: &mut Vec<Event>, events: Vec<Event>) {
        for event in events {
            if !server.iter().any(|e| e.id == event.id) {
                let seq = server.len() as i64 + 1;
                server.push(Event { seq, ..event });
            }
        }
    }

    /// A stream, as the app opens one: from where the store says, all the
    /// server holds after that, until the store takes it (a stream opened
    /// past the head is ended unread). Then what waits goes up and comes
    /// back placed.
    fn sync(store: &mut Store, server: &mut Vec<Event>) {
        for _ in 0..16 {
            let after = store.opens_after().unwrap() as usize;
            let head = server.len() as i64;
            let sent = server.get(after..).map_or(Vec::new(), <[Event]>::to_vec);
            if store.receive(sent, head).is_ok() && after as i64 <= head {
                push(server, store.pending().unwrap());
                let confirmed = store.confirmed().unwrap() as usize;
                store
                    .receive(server[confirmed..].to_vec(), server.len() as i64)
                    .unwrap();
                return;
            }
        }
        panic!("never caught up");
    }

    /// `count` settings saved, one event each.
    fn settings(store: &mut Store, count: usize) {
        for n in 0..count {
            let unit = if n % 2 == 0 {
                WeightUnit::Lb
            } else {
                WeightUnit::Kg
            };
            let request = schlift_core::pb::UpdateSettingRequest {
                setting: Some(schlift_core::pb::UserSetting {
                    setting: Some(schlift_core::pb::user_setting::Setting::WeightUnit(
                        schlift_core::pb::WeightUnitConfig { unit: unit as i32 },
                    )),
                }),
            };
            store
                .call("UpdateSetting", &request.encode_to_vec(), 3_000 + n as i64)
                .unwrap();
        }
    }

    /// An import only ever adds: an export brought in again adds nothing,
    /// an older one after newer events removes nothing, and the server,
    /// skipping what it holds, ends with each event once.
    #[test]
    fn an_import_only_adds_and_never_twice() {
        let mut server = Vec::new();
        let mut phone = Store::open(&temp("import-phone"), U1, "una").unwrap();
        let home = onboard(&mut phone);
        settings(&mut phone, 2);
        sync(&mut phone, &mut server);
        let older = temp("import-older");
        phone.export(&older).unwrap();
        let started = start(&mut phone, &home.templates[0].id);
        end(&mut phone, &started.id, 2_100);
        sync(&mut phone, &mut server);
        // One more, not yet sent.
        settings(&mut phone, 1);
        let newer = temp("import-newer");
        phone.export(&newer).unwrap();
        let state = |store: &Store| (store.placed().unwrap(), store.pending().unwrap());
        let before = (state(&phone), phone.account.clone());
        let recorded = before.0 .0.len() + before.0 .1.len();

        for file in [&newer, &newer, &older] {
            assert_eq!(phone.import(file).unwrap(), 0, "it has them all");
        }
        assert_eq!((state(&phone), phone.account.clone()), before);

        // A phone that lost its copy: the older export, then the newer, then
        // the newer again.
        let mut fresh = Store::open(&temp("import-fresh"), U1, "").unwrap();
        assert_eq!(fresh.import(&older).unwrap(), 3);
        assert_eq!(fresh.import(&newer).unwrap(), recorded - 3);
        assert_eq!(fresh.import(&newer).unwrap(), 0);
        assert_eq!(fresh.import(&older).unwrap(), 0);
        assert_eq!(fresh.account, phone.account);

        sync(&mut fresh, &mut server);
        sync(&mut phone, &mut server);
        assert_eq!(server.len(), recorded, "each event once");
        for store in [&phone, &fresh] {
            assert_eq!(store.confirmed_account(), &Account::fold(&server));
            assert!(store.pending().unwrap().is_empty());
            assert_eq!(store.account, Account::fold(&server));
        }

        // Another account's export brings in nothing.
        let mut theirs = Store::open(&temp("import-theirs"), U2, "").unwrap();
        assert!(theirs.import(&newer).is_err());
        assert!(theirs.pending().unwrap().is_empty());
    }

    /// Heart rate gathered for a workout under way comes along with an
    /// export, and is recorded when the workout ends on the new phone.
    #[test]
    fn an_import_brings_the_heart_rate_of_a_workout_under_way() {
        let mut phone = Store::open(&temp("hr-phone"), U1, "").unwrap();
        let home = onboard(&mut phone);
        let started = start(&mut phone, &home.templates[0].id);
        heart_rate(&mut phone, &started.id, &[1_000, 3_000], 2_001);
        let export = temp("hr-export");
        phone.export(&export).unwrap();

        let mut fresh = Store::open(&temp("hr-fresh"), U1, "").unwrap();
        fresh.import(&export).unwrap();
        // Brought in again, nothing is gathered twice.
        fresh.import(&export).unwrap();
        heart_rate(&mut fresh, &started.id, &[5_000], 2_002);
        end(&mut fresh, &started.id, 2_010);
        assert_eq!(
            shown_heart_rate(&mut fresh, &started.id),
            vec![1_000, 3_000, 5_000]
        );
    }

    /// The server's placed events are folded into the base once there are
    /// enough of them, and let go: the file holds the account, not the
    /// history, and opens as the same account.
    #[test]
    fn placed_events_fold_into_the_base_and_the_file_opens_the_same() {
        let path = temp("base");
        let mut server = Vec::new();
        let mut store = Store::open(&path, U1, "").unwrap();
        onboard(&mut store);
        for _ in 0..3 {
            settings(&mut store, 200);
            sync(&mut store, &mut server);
        }
        assert_eq!(store.confirmed().unwrap(), server.len() as i64);
        assert!(
            store.placed().unwrap().len() < FOLD_PLACED_AT as usize,
            "folded in and let go"
        );
        assert_eq!(store.confirmed_account(), &Account::fold(&server));
        let account = store.account.clone();
        drop(store);
        let store = Store::open(&path, U1, "").unwrap();
        assert_eq!(store.account, account);
        assert_eq!(store.opens_after().unwrap(), server.len() as i64);
    }

    /// The account whole from the server becomes the base: what it says it
    /// holds of this phone's waiting events goes, the rest is applied on
    /// top, and events from its seq carry on from there.
    #[test]
    fn an_account_from_the_server_becomes_the_base() {
        let mut server = Vec::new();
        let mut tablet = Store::open(&temp("whole-tablet"), U1, "").unwrap();
        onboard(&mut tablet);
        settings(&mut tablet, 40);
        sync(&mut tablet, &mut server);
        // A phone, with three of its own waiting; the server placed two of
        // them already (their acks lost).
        let mut phone = Store::open(&temp("whole-phone"), U1, "").unwrap();
        settings(&mut phone, 3);
        let waiting = phone.pending().unwrap();
        push(&mut server, waiting[..2].to_vec());
        let snapshot = schlift_core::snapshot::snapshot(
            &Account::fold_without_heart_rate(&server),
            server.len() as i64,
        );
        let held: Vec<String> = waiting[..2].iter().map(|e| e.id.clone()).collect();
        phone
            .receive_account(
                &snapshot,
                server.len() as i64,
                &server.last().unwrap().id,
                &held,
            )
            .unwrap();
        assert_eq!(phone.confirmed().unwrap(), server.len() as i64);
        assert_eq!(phone.pending_ids().unwrap(), vec![waiting[2].id.clone()]);
        let mut shown = Account::fold(&server);
        shown.replay(&waiting[2]);
        assert_eq!(phone.account, shown);
        // The last goes up and comes back placed after the snapshot.
        sync(&mut phone, &mut server);
        assert!(phone.pending().unwrap().is_empty());
        assert_eq!(phone.confirmed_account(), &Account::fold(&server));
    }

    /// A file from before the base (format 2): its placed history is moved
    /// in, folded into a base, and the account is the same.
    #[test]
    fn a_file_of_its_whole_history_moves_into_a_base() {
        let path = temp("format-2");
        let mut server = Vec::new();
        let mut writer = Store::open(&temp("format-2-writer"), U1, "").unwrap();
        onboard(&mut writer);
        settings(&mut writer, 300);
        sync(&mut writer, &mut server);
        let conn = Connection::open(&path).unwrap();
        conn.execute_batch(&format!(
            "CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
             INSERT INTO meta VALUES ('user_id', '{U1}');
             CREATE TABLE events (seq INTEGER PRIMARY KEY, id TEXT NOT NULL UNIQUE,
                 event TEXT NOT NULL);
             PRAGMA user_version = 2;"
        ))
        .unwrap();
        for event in &server {
            conn.execute(
                "INSERT INTO events (seq, id, event) VALUES (?, ?, ?)",
                params![event.seq, event.id, serde_json::to_string(event).unwrap()],
            )
            .unwrap();
        }
        drop(conn);
        let store = Store::open(&path, U1, "").unwrap();
        assert_eq!(store.confirmed().unwrap(), server.len() as i64);
        assert_eq!(store.account, Account::fold(&server));
        assert!(store.placed().unwrap().is_empty(), "folded into the base");
    }

    /// After an update that changes the rules, the base by the old ones is
    /// shown, and the stream opens from nothing so the server sends the
    /// account again by the new.
    #[test]
    fn a_base_by_other_rules_is_shown_until_the_server_sends_the_account() {
        let path = temp("other-rules");
        let mut server = Vec::new();
        let mut store = Store::open(&path, U1, "").unwrap();
        onboard(&mut store);
        settings(&mut store, 300);
        sync(&mut store, &mut server);
        let account = store.account.clone();
        drop(store);
        let conn = Connection::open(&path).unwrap();
        let state: Vec<u8> = conn
            .query_row("SELECT state FROM base", [], |r| r.get(0))
            .unwrap();
        let mut message: schlift_core::pb::AccountSnapshot =
            prost::Message::decode(zstd::decode_all(state.as_slice()).unwrap().as_slice()).unwrap();
        message.fold = "an older core".to_string();
        let state = zstd::encode_all(message.encode_to_vec().as_slice(), 1).unwrap();
        conn.execute("UPDATE base SET state = ?, fold = 'an older core'", [state])
            .unwrap();
        drop(conn);
        let store = Store::open(&path, U1, "").unwrap();
        assert_eq!(store.account, account, "shown as it was");
        assert_eq!(store.opens_after().unwrap(), 0, "and sent again whole");
    }
}
