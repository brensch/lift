//! The account file: one SQLite file per account. It holds the account's
//! events in the server's order, and the ones recorded here that the server
//! hasn't given a place yet. The account itself lives in memory: the fold of
//! the first, with the second applied on top. The readable tables
//! (`schlift_core::projection`) are written only into an export.

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
    account_export_statements, Statement, Value, ACCOUNT_SCHEMA, WORKOUT_SCHEMA,
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
        let response = api::call(&mut call, method, request).map_err(|e| {
            let code = match e {
                schlift_core::account::CoreError::InvalidArgument(_) => "invalid_argument",
                schlift_core::account::CoreError::NotFound(_) => "not_found",
                schlift_core::account::CoreError::FailedPrecondition(_) => "failed_precondition",
            };
            format!("{code}: {e}")
        })?;
        let events = std::mem::take(&mut call.events);
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

    /// The last seq this file holds: where the server picks up.
    pub fn confirmed(&self) -> StoreResult<i64> {
        self.conn
            .query_row("SELECT COALESCE(MAX(seq), 0) FROM events", [], |r| r.get(0))
            .map_err(storage)
    }

    /// The account's history, in the server's order.
    pub fn events(&self) -> StoreResult<Vec<Event>> {
        self.read("SELECT event FROM events ORDER BY seq")
    }

    /// What this device recorded that the server hasn't placed, oldest first.
    pub fn pending(&self) -> StoreResult<Vec<Event>> {
        self.read("SELECT event FROM pending ORDER BY n")
    }

    /// The pending events after the one numbered `after` (a stream's last
    /// sent), and the number of the last: what a stream hasn't sent yet.
    pub fn pending_after(&self, after: i64) -> StoreResult<(Vec<Event>, i64)> {
        let mut query = self
            .conn
            .prepare_cached("SELECT n, event FROM pending WHERE n > ? ORDER BY n")
            .map_err(storage)?;
        let rows = query
            .query_map([after], |r| {
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
        let mut query = self.conn.prepare_cached(sql).map_err(storage)?;
        let rows = query
            .query_map([], |r| r.get::<_, String>(0))
            .map_err(storage)?
            .collect::<Result<Vec<_>, _>>()
            .map_err(storage)?;
        rows.iter()
            .map(|json| serde_json::from_str(json).map_err(storage))
            .collect()
    }

    /// Events from the server, in its order, and the last seq it holds.
    /// Ones this device recorded leave `pending`. Returns whether the
    /// account changed under the app: another device's events arrived, or
    /// the server holds less than this file (an older export opened), so
    /// what it lacks is offered again.
    pub fn receive(&mut self, events: Vec<Event>, head: i64) -> StoreResult<bool> {
        let confirmed = self.confirmed()?;
        let new: Vec<Event> = events.into_iter().filter(|e| e.seq > confirmed).collect();
        if let Some(first) = new.first() {
            if first.seq != confirmed + 1 {
                return Err(format!(
                    "failed_precondition: the server's events start at {}, after {confirmed}",
                    first.seq
                ));
            }
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
                "INSERT INTO events (seq, id, event) VALUES (?, ?, ?)",
                params![event.seq, event.id, json],
            )
            .map_err(storage)?;
            tx.execute("DELETE FROM pending WHERE id = ?", [&event.id])
                .map_err(storage)?;
        }
        let behind = head < confirmed && new.is_empty();
        if behind {
            // The server lacks the end of this file's history: it goes back
            // to the front of the queue, in order, to be placed again.
            let lost: Vec<(String, String)> = {
                let mut query = tx
                    .prepare("SELECT id, event FROM events WHERE seq > ? ORDER BY seq")
                    .map_err(storage)?;
                let rows = query
                    .query_map([head], |r| Ok((r.get(0)?, r.get(1)?)))
                    .map_err(storage)?
                    .collect::<Result<Vec<_>, _>>()
                    .map_err(storage)?;
                rows
            };
            let queued: Vec<(String, String)> = {
                let mut query = tx
                    .prepare("SELECT id, event FROM pending ORDER BY n")
                    .map_err(storage)?;
                let rows = query
                    .query_map([], |r| Ok((r.get(0)?, r.get(1)?)))
                    .map_err(storage)?
                    .collect::<Result<Vec<_>, _>>()
                    .map_err(storage)?;
                rows
            };
            tx.execute("DELETE FROM events WHERE seq > ?", [head])
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
        }
        tx.commit().map_err(storage)?;
        if ours && !behind {
            return Ok(false);
        }
        self.refold()?;
        Ok(true)
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
        // A server that holds nothing of this file.
        assert!(store.receive(Vec::new(), 0).unwrap());
        assert_eq!(store.confirmed().unwrap(), 0);
        assert_eq!(store.pending().unwrap().len(), 1);
        assert_eq!(store.pending().unwrap()[0].seq, 0);
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

    fn heart_rate(store: &mut Store, workout_id: &str, at: &[i64], now: i64) {
        store
            .call(
                "AppendWorkoutHeartRate",
                &AppendWorkoutHeartRateRequest {
                    workout_id: workout_id.to_string(),
                    samples: at
                        .iter()
                        .map(|&sampled_at| WorkoutHeartRatePoint {
                            sampled_at,
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

    fn shown_heart_rate(store: &mut Store, workout_id: &str) -> Vec<i64> {
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
            .map(|s| s.sampled_at)
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

    /// Any write: what's gathered for an ended workout is recorded after it.
    fn any_call(store: &mut Store) {
        store
            .call("GetHome", &GetHomeRequest::default().encode_to_vec(), 2_030)
            .unwrap();
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
        let exported = Connection::open(&dest).unwrap();
        let samples: i64 = exported
            .query_row(
                "SELECT COUNT(*) FROM workout_heart_rate_samples WHERE workout_id = ?",
                [&started.id],
                |r| r.get(0),
            )
            .unwrap();
        assert_eq!(samples, 3, "the export has the readable tables");
        let reopened = Store::open(&dest, U1, "").unwrap();
        assert_eq!(reopened.account, store.account);
    }
}
