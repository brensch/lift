//! The account file: one SQLite file per account. It holds the account's
//! events in the server's order, and the ones recorded here that the server
//! hasn't given a place yet. The account itself lives in memory: the fold of
//! the first, with the second applied on top. The readable tables
//! (`schlift_core::projection`) are written only into an export.

use std::collections::HashMap;
use std::path::Path;

use prost::Message;
use rusqlite::{params, Connection, OptionalExtension};
use schlift_core::account::Account;
use schlift_core::api::{self, Call};
use schlift_core::events::Event;
use schlift_core::pb::{
    AppendWorkoutHeartRateRequest, AppendWorkoutHeartRateResponse, GetWorkoutHeartRateRequest,
    GetWorkoutHeartRateResponse, LibraryTemplate, ListTemplateLibraryResponse,
    WorkoutHeartRatePoint,
};
use schlift_core::projection::{
    account_export_statements, Statement, Value, ACCOUNT_SCHEMA, READABLE_TABLES, WORKOUT_SCHEMA,
};

const SCHEMA: &str = r#"
CREATE TABLE IF NOT EXISTS meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- The account's history, in the server's order: each an event as JSON
-- (schlift_core::events).
CREATE TABLE IF NOT EXISTS events (
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

-- The template library as the server last sent it (a
-- ListTemplateLibraryResponse): what coupled templates follow. Absent until
-- the first sync; the library built into the app stands in.
CREATE TABLE IF NOT EXISTS library (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    blob BLOB NOT NULL
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

/// What `PRAGMA user_version` says a file is. A file from before (its events
/// in another form) has them dropped: they come back from the server.
const FORMAT: i64 = 1;

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
    account: Account,
    library: Vec<LibraryTemplate>,
    /// Session partners' workouts, as the events the server forwarded:
    /// folded for what they're up to, held only while the app runs.
    partners: HashMap<String, Vec<Event>>,
    /// While the server's history is found to part from this file's: the
    /// seq the next stream checks from, further back than the last.
    probe: Option<i64>,
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
        if format < FORMAT {
            // Everything but who the file is for is the server's to send.
            conn.execute_batch("DROP TABLE IF EXISTS events;")
                .map_err(storage)?;
        }
        conn.execute_batch(SCHEMA).map_err(storage)?;
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
            account: Account::default(),
            library: schlift_core::template_library::library().to_vec(),
            partners: HashMap::new(),
            probe: None,
        };
        let saved: Option<Vec<u8>> = store
            .conn
            .query_row("SELECT blob FROM library WHERE id = 1", [], |r| r.get(0))
            .optional()
            .map_err(storage)?;
        if let Some(blob) = saved {
            store.library = ListTemplateLibraryResponse::decode(blob.as_slice())
                .map_err(storage)?
                .templates;
        }
        store.refold()?;
        Ok(store)
    }

    /// The account again from the file: its history, then what's pending.
    fn refold(&mut self) -> StoreResult<()> {
        let mut account = Account::fold(&self.events()?);
        for event in self.pending()? {
            account.replay(&event);
        }
        self.account = account;
        Ok(())
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
        let mut call = Call::new(&mut self.account, now, event_id).with_library(&self.library);
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

    /// The last seq this file holds: where the server picks up.
    pub fn confirmed(&self) -> StoreResult<i64> {
        self.conn
            .query_row("SELECT COALESCE(MAX(seq), 0) FROM events", [], |r| r.get(0))
            .map_err(storage)
    }

    /// What a Sync stream opens with: the seq before the last this file
    /// holds (or before the one it checks from), so the server's first
    /// event is one this file has, and its id says whether the two
    /// histories are the same up to there. A server restored from a backup
    /// can hold other events at the same places.
    pub fn opens_after(&self) -> StoreResult<i64> {
        let confirmed = self.confirmed()?;
        let from = self.probe.map_or(confirmed, |p| p.min(confirmed));
        Ok((from - 1).max(0))
    }

    /// The account's history, in the server's order.
    pub fn events(&self) -> StoreResult<Vec<Event>> {
        self.read("SELECT event FROM events ORDER BY seq")
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

    /// Bring in an export of this account: each event in it that this file
    /// holds neither placed nor waiting (by id) waits after the rest, in the
    /// export's order, for the server to place; the server skips any it
    /// holds. So an import only ever adds: nothing here is removed, and the
    /// same file brought in again adds nothing. Returns how many it added.
    /// A file that won't read whole adds nothing.
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
        if format < FORMAT {
            // Its events are in a form from before, which nothing reads.
            return Ok(0);
        }
        let mut theirs = read(&conn, "SELECT event FROM events ORDER BY seq")?;
        theirs.extend(read(&conn, "SELECT event FROM pending ORDER BY n")?);
        let mut held: std::collections::HashSet<String> = self
            .events()?
            .into_iter()
            .chain(self.pending()?)
            .map(|e| e.id)
            .collect();
        let added: Vec<Event> = theirs
            .into_iter()
            .filter(|e| held.insert(e.id.clone()))
            .map(|e| Event { seq: 0, ..e })
            .collect();
        if !added.is_empty() {
            self.add_pending(&added)?;
            self.refold()?;
        }
        Ok(added.len())
    }

    /// Events from the server, in its order, and the last seq it holds.
    /// Ones this device recorded leave `pending`. Returns whether the
    /// account changed under the app: another device's events arrived, or
    /// the histories parted (below), so what the server lacks is offered
    /// again.
    ///
    /// Where the server sends an event this file holds, the ids must agree.
    /// They part after a server is restored from an older backup and
    /// another device's events are placed where this file's were: this
    /// file's events from there go back to the front of the queue, to be
    /// placed again (the server skips any it holds), and the server's are
    /// taken in their place. Where they part at the first event a stream
    /// sent, they may part earlier still: refused, and the next stream
    /// checks from further back. And a server that holds less than this
    /// file has the rest queued again, then the stream is refused, so the
    /// next one checks its last event before anything is pushed.
    pub fn receive(&mut self, events: Vec<Event>, head: i64) -> StoreResult<bool> {
        let confirmed = self.confirmed()?;
        let parted = self.parted(&events, confirmed)?;
        // Parted at the first event a stream sends (the first of its first
        // message, which no event of its was checked before): where they
        // meet is further back.
        let from = self.probe.map_or(confirmed, |p| p.min(confirmed));
        let first = events.first().map_or(0, |e| e.seq);
        if parted.is_some_and(|seq| seq == first && seq <= from && seq > 1) {
            // Twice as far back as this stream checked from.
            self.probe = Some((2 * first - confirmed - 1).max(1));
            return Err(format!(
                "failed_precondition: the server's event {first} is not this file's; \
                 checking from further back"
            ));
        }
        // The server holds less than this file, and nothing it sent parts.
        let behind = parted.is_none() && head < confirmed;
        // The last seq this file and the server agree on, when this file
        // holds more than that.
        let meet = match parted {
            Some(seq) => Some(seq - 1),
            None if behind => Some(head),
            None => None,
        };
        // Checked as far as this file goes.
        let checked = events.last().is_some_and(|e| e.seq >= confirmed);
        let kept = meet.unwrap_or(confirmed);
        let new: Vec<Event> = events.into_iter().filter(|e| e.seq > kept).collect();
        if let Some(first) = new.first() {
            if first.seq != kept + 1 {
                return Err(format!(
                    "failed_precondition: the server's events start at {}, after {kept}",
                    first.seq
                ));
            }
        }
        let pending = self.pending()?;
        // The usual case: the server placed this device's own events, next
        // in line, and nothing else; the account already has them.
        let ours = meet.is_none()
            && new.len() <= pending.len()
            && new.iter().zip(&pending).all(|(n, p)| n.id == p.id);
        let tx = self.conn.transaction().map_err(storage)?;
        if let Some(meet) = meet {
            requeue_after(&tx, meet)?;
        }
        for event in &new {
            let json = serde_json::to_string(event).map_err(storage)?;
            tx.execute(
                "INSERT INTO events (seq, id, event) VALUES (?, ?, ?)",
                params![event.seq, event.id, json],
            )
            .map_err(storage)?;
            tx.execute("DELETE FROM pending WHERE id = ?", [&event.id])
                .map_err(storage)?;
        }
        tx.commit().map_err(storage)?;
        if meet.is_some() || checked {
            self.probe = None;
        }
        if ours {
            return Ok(false);
        }
        self.refold()?;
        if behind {
            return Err(format!(
                "failed_precondition: the server holds {head} events, fewer than this file; \
                 checking its last before sending more"
            ));
        }
        Ok(true)
    }

    /// The first seq at which `events` (the server's) hold another event
    /// than this file, of those this file holds.
    fn parted(&self, events: &[Event], confirmed: i64) -> StoreResult<Option<i64>> {
        let Some(first) = events.first().map(|e| e.seq).filter(|&s| s <= confirmed) else {
            return Ok(None);
        };
        let mut query = self
            .conn
            .prepare_cached("SELECT seq, id FROM events WHERE seq BETWEEN ? AND ?")
            .map_err(storage)?;
        let held: HashMap<i64, String> = query
            .query_map([first, confirmed], |r| Ok((r.get(0)?, r.get(1)?)))
            .map_err(storage)?
            .collect::<Result<_, _>>()
            .map_err(storage)?;
        Ok(events
            .iter()
            .take_while(|e| e.seq <= confirmed)
            .find(|e| held.get(&e.seq) != Some(&e.id))
            .map(|e| e.seq))
    }

    /// Keep the library the server sent (a ListTemplateLibraryResponse).
    /// Returns whether it differs from the one in use.
    pub fn set_library(&mut self, packed: &[u8]) -> StoreResult<bool> {
        let library = ListTemplateLibraryResponse::decode(packed)
            .map_err(|e| format!("invalid_argument: {e}"))?
            .templates;
        if library == self.library {
            return Ok(false);
        }
        self.conn
            .execute(
                "INSERT INTO library (id, blob) VALUES (1, ?)
                 ON CONFLICT(id) DO UPDATE SET blob = excluded.blob",
                [packed],
            )
            .map_err(storage)?;
        self.library = library;
        Ok(true)
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

/// This file's events after `meet` go back to the front of the queue, in
/// order and without their places, ahead of what waited already: the whole
/// queue is offered again, however much of it was sent before.
fn requeue_after(tx: &rusqlite::Transaction, meet: i64) -> StoreResult<()> {
    let rows = |sql: &str, params: &[i64]| -> StoreResult<Vec<(String, String)>> {
        let mut query = tx.prepare(sql).map_err(storage)?;
        let rows = query
            .query_map(rusqlite::params_from_iter(params), |r| {
                Ok((r.get(0)?, r.get(1)?))
            })
            .map_err(storage)?
            .collect::<Result<Vec<_>, _>>()
            .map_err(storage);
        rows
    };
    let lost = rows(
        "SELECT id, event FROM events WHERE seq > ? ORDER BY seq",
        &[meet],
    )?;
    let queued = rows("SELECT id, event FROM pending ORDER BY n", &[])?;
    tx.execute("DELETE FROM events WHERE seq > ?", [meet])
        .map_err(storage)?;
    tx.execute("DELETE FROM pending", []).map_err(storage)?;
    for (id, event) in lost.iter().chain(&queued) {
        let event: Event = serde_json::from_str(event).map_err(storage)?;
        let json = serde_json::to_string(&Event { seq: 0, ..event }).map_err(storage)?;
        tx.execute(
            "INSERT INTO pending (id, event) VALUES (?, ?)",
            params![id, json],
        )
        .map_err(storage)?;
    }
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
    use std::collections::HashSet;

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
        let again = store.events().unwrap();
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
        assert_eq!(phone.events().unwrap(), history);
        assert_eq!(phone.account, Account::fold(&history));
    }

    #[test]
    fn what_the_server_lacks_is_offered_again() {
        let mut store = Store::open(&temp("behind"), U1, "").unwrap();
        onboard(&mut store);
        let placed = place(store.pending().unwrap(), 0);
        store.receive(placed, 1).unwrap();
        let before = store.account.clone();
        // A server that holds nothing of this file: the stream is refused,
        // the next to check where they meet before anything goes up.
        assert!(store.receive(Vec::new(), 0).is_err());
        assert_eq!(store.confirmed().unwrap(), 0);
        assert_eq!(store.pending().unwrap().len(), 1);
        assert_eq!(store.pending().unwrap()[0].seq, 0);
        assert_eq!(store.account, before);
    }

    /// What the server lacks goes ahead of what was waiting already, and the
    /// whole queue is offered again, however much of it was sent before.
    #[test]
    fn what_the_server_lacks_goes_ahead_of_what_waits() {
        let mut store = Store::open(&temp("behind-waiting"), U1, "").unwrap();
        let home = onboard(&mut store);
        let placed = place(store.pending().unwrap(), 0);
        store.receive(placed.clone(), 1).unwrap();
        start(&mut store, &home.templates[0].id);
        let (waiting, sent) = store.pending_after(0).unwrap();
        let before = store.account.clone();
        assert!(store.receive(Vec::new(), 0).is_err());
        let ids = |events: &[Event]| events.iter().map(|e| e.id.clone()).collect::<Vec<_>>();
        let queued = [placed, waiting].concat();
        assert_eq!(ids(&store.pending().unwrap()), ids(&queued));
        assert_eq!(ids(&store.pending_after(sent).unwrap().0), ids(&queued));
        assert_eq!(store.account, before);
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

    fn home(store: &mut Store) -> GetHomeResponse {
        let bytes = store
            .call("GetHome", &GetHomeRequest::default().encode_to_vec(), 1_000)
            .unwrap();
        GetHomeResponse::decode(bytes.as_slice()).unwrap()
    }

    #[test]
    fn the_servers_library_is_kept_and_coupled_templates_follow_it() {
        let path = temp("library");
        let mut store = Store::open(&path, U1, "").unwrap();
        let coupled = onboard(&mut store)
            .templates
            .into_iter()
            .find(|t| t.coupled)
            .expect("a template that follows the library");
        let mut library = schlift_core::template_library::library().to_vec();
        let entry = library
            .iter_mut()
            .find(|e| e.id == coupled.library_id)
            .unwrap();
        entry.name = "Renamed by the server".into();
        let packed = ListTemplateLibraryResponse {
            templates: library.clone(),
            ..Default::default()
        }
        .encode_to_vec();
        assert!(store.set_library(&packed).unwrap(), "a change");
        assert!(!store.set_library(&packed).unwrap(), "the same again");
        drop(store);

        // After a restart: the server's library, not the one built in.
        let mut store = Store::open(&path, U1, "").unwrap();
        assert_eq!(store.library, library);
        let shown = home(&mut store)
            .templates
            .into_iter()
            .find(|t| t.id == coupled.id)
            .unwrap();
        assert_eq!(shown.name, "Renamed by the server");
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
        assert!(store.events().unwrap().is_empty());
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

    /// The server restored from a backup that lacks the end of one phone's
    /// history, and another phone's event placed there first: the phones
    /// tell the histories apart by the events' ids, not their places, and
    /// both end with the server's log, every event in it once.
    #[test]
    fn after_a_server_restore_the_phones_meet_where_their_events_agree() {
        let mut server = Vec::new();
        let mut a = Store::open(&temp("restore-a"), U1, "").unwrap();
        let mut b = Store::open(&temp("restore-b"), U1, "").unwrap();
        onboard(&mut a);
        settings(&mut a, 4);
        sync(&mut a, &mut server);
        sync(&mut b, &mut server);
        settings(&mut a, 5);
        sync(&mut a, &mut server);
        assert_eq!(a.confirmed().unwrap(), 10);
        assert_eq!(b.confirmed().unwrap(), 5);

        // Restored to a backup of 1..=5; B's next event is placed 6th.
        server.truncate(5);
        settings(&mut b, 1);
        sync(&mut b, &mut server);
        sync(&mut a, &mut server);
        sync(&mut b, &mut server);

        assert_eq!(server.len(), 11, "A's five again, after B's one");
        let ids: HashSet<&str> = server.iter().map(|e| e.id.as_str()).collect();
        assert_eq!(ids.len(), server.len(), "each event once");
        for store in [&a, &b] {
            assert_eq!(store.events().unwrap(), server);
            assert!(store.pending().unwrap().is_empty());
            assert_eq!(store.account, Account::fold(&server));
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
        let state = |store: &Store| (store.events().unwrap(), store.pending().unwrap());
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
            assert_eq!(store.events().unwrap(), server);
            assert!(store.pending().unwrap().is_empty());
            assert_eq!(store.account, Account::fold(&server));
        }

        // Another account's export brings in nothing.
        let mut theirs = Store::open(&temp("import-theirs"), U2, "").unwrap();
        assert!(theirs.import(&newer).is_err());
        assert!(theirs.pending().unwrap().is_empty());
    }
}
