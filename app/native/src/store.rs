//! The account file: one SQLite file per account holding the event log
//! (the truth), what the server has acknowledged, and the readable tables
//! (`schlift_core::projection`). The account itself lives in memory, folded
//! from the log when the file is opened.

use std::path::Path;

use prost::Message;
use rusqlite::{params, Connection, OptionalExtension};
use schlift_core::account::{event_workout_ids, Account};
use schlift_core::api::{self, Call};
use schlift_core::pb::Event;
use schlift_core::projection::{
    account_statements, workout_statements, Statement, Value, ACCOUNT_SCHEMA, WORKOUT_SCHEMA,
};

const SCHEMA: &str = r#"
CREATE TABLE IF NOT EXISTS meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- Every write, in order: the account is the fold of these. `event_blob` is
-- an Event (proto/workout/v1/account.proto); id and at are copied out to be
-- readable.
CREATE TABLE IF NOT EXISTS events (
    seq INTEGER PRIMARY KEY,
    id TEXT NOT NULL,
    at INTEGER NOT NULL,
    event_blob BLOB NOT NULL
);
"#;

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
}

impl Store {
    /// Open (or create) the file for `user_id`, known as `name` (kept in
    /// the file so it opens with no server). A file belonging to someone
    /// else is refused.
    pub fn open(path: &Path, user_id: &str, name: &str) -> StoreResult<Self> {
        let conn = Connection::open(path).map_err(storage)?;
        conn.execute_batch(&format!("{SCHEMA}{WORKOUT_SCHEMA}{ACCOUNT_SCHEMA}"))
            .map_err(storage)?;
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
        };
        store.account = Account::fold(&store.events_after(0)?);
        Ok(store)
    }

    pub fn seq(&self) -> i64 {
        self.account.seq
    }

    /// Answer one RPC; a write's events are stored before the answer is
    /// given, so nothing the app was told happened can be lost.
    pub fn call(&mut self, method: &str, request: &[u8], now: i64) -> StoreResult<Vec<u8>> {
        let event_id = uuid::Uuid::new_v4().to_string();
        let mut call = Call::new(&mut self.account, now, event_id);
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
            if let Err(error) = self.store(&events) {
                // Memory ran ahead of the file: go back to what was written.
                self.account = Account::fold(&self.events_after(0)?);
                return Err(error);
            }
        }
        Ok(response)
    }

    /// Store events (already folded in) and rewrite what they touched.
    fn store(&mut self, events: &[Event]) -> StoreResult<()> {
        let tx = self.conn.transaction().map_err(storage)?;
        let mut touched = std::collections::BTreeSet::new();
        for event in events {
            tx.execute(
                "INSERT INTO events (seq, id, at, event_blob) VALUES (?, ?, ?, ?)",
                params![event.seq, event.id, event.at, event.encode_to_vec()],
            )
            .map_err(storage)?;
            touched.extend(event_workout_ids(event));
        }
        let mut statements = account_statements(&self.user_id, &self.account);
        for id in &touched {
            if let Some(record) = self.account.workout(id) {
                statements.extend(workout_statements(&self.user_id, record, ""));
            }
        }
        for statement in statements {
            run(&tx, statement)?;
        }
        tx.commit().map_err(storage)
    }

    pub fn events_after(&self, seq: i64) -> StoreResult<Vec<Event>> {
        let mut query = self
            .conn
            .prepare("SELECT event_blob FROM events WHERE seq > ? ORDER BY seq")
            .map_err(storage)?;
        let blobs = query
            .query_map([seq], |r| r.get::<_, Vec<u8>>(0))
            .map_err(storage)?
            .collect::<Result<Vec<_>, _>>()
            .map_err(storage)?;
        blobs
            .iter()
            .map(|b| Event::decode(b.as_slice()).map_err(storage))
            .collect()
    }

    /// The last seq the server has acknowledged.
    pub fn acked(&self) -> StoreResult<i64> {
        let value: Option<String> = self
            .conn
            .query_row("SELECT value FROM meta WHERE key = 'acked'", [], |r| {
                r.get(0)
            })
            .optional()
            .map_err(storage)?;
        Ok(value.and_then(|v| v.parse().ok()).unwrap_or(0))
    }

    pub fn set_acked(&self, head: i64) -> StoreResult<()> {
        let head = head.min(self.account.seq).max(self.acked()?);
        self.conn
            .execute(
                "INSERT INTO meta (key, value) VALUES ('acked', ?)
                 ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                [head.to_string()],
            )
            .map_err(storage)?;
        Ok(())
    }

    /// Events from the server that this file doesn't have yet (a fresh
    /// install, or a file restored from an older export): appended and
    /// folded, and acknowledged since the server holds them.
    pub fn restore(&mut self, events: Vec<Event>) -> StoreResult<i64> {
        let new: Vec<Event> = events
            .into_iter()
            .filter(|e| e.seq > self.account.seq)
            .collect();
        if let Some(first) = new.first() {
            if first.seq != self.account.seq + 1 {
                return Err(format!(
                    "failed_precondition: the server's events start at {}, after {}",
                    first.seq, self.account.seq
                ));
            }
        }
        for event in &new {
            self.account.replay(event);
        }
        if let Err(error) = self.store(&new) {
            self.account = Account::fold(&self.events_after(0)?);
            return Err(error);
        }
        self.set_acked(self.account.seq)?;
        Ok(self.account.seq)
    }

    /// A copy of the whole file at `dest`: the export.
    pub fn export(&self, dest: &Path) -> StoreResult<()> {
        let _ = std::fs::remove_file(dest);
        self.conn
            .execute("VACUUM INTO ?", [dest.to_string_lossy()])
            .map_err(storage)?;
        Ok(())
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
    let name = meta("name").map_err(|_| not_ours())?.unwrap_or_default();
    Ok((user_id, name))
}

fn run(tx: &rusqlite::Transaction, statement: Statement) -> StoreResult<()> {
    let params: Vec<rusqlite::types::Value> = statement
        .params
        .into_iter()
        .map(|v| match v {
            Value::Int(v) => rusqlite::types::Value::Integer(v),
            Value::Real(v) => rusqlite::types::Value::Real(v),
            Value::Text(v) => rusqlite::types::Value::Text(v),
        })
        .collect();
    tx.execute(statement.sql, rusqlite::params_from_iter(params))
        .map_err(storage)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use schlift_core::pb::{
        CompleteOnboardingRequest, GetHomeResponse, StartWorkoutRequest, StartWorkoutResponse,
        WeightUnit,
    };

    fn temp(name: &str) -> std::path::PathBuf {
        std::env::temp_dir().join(format!(
            "schlift-native-{name}-{}.sqlite",
            uuid::Uuid::new_v4()
        ))
    }

    fn onboard(store: &mut Store) -> GetHomeResponse {
        let bytes = store
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
        schlift_core::pb::CompleteOnboardingResponse::decode(bytes.as_slice())
            .unwrap()
            .home
            .unwrap()
    }

    #[test]
    fn a_reopened_file_is_the_same_account() {
        let path = temp("reopen");
        let mut store = Store::open(&path, "u1", "una").unwrap();
        let home = onboard(&mut store);
        let started = StartWorkoutResponse::decode(
            store
                .call(
                    "StartWorkout",
                    &StartWorkoutRequest {
                        template_id: home.templates[0].id.clone(),
                        ..Default::default()
                    }
                    .encode_to_vec(),
                    2_000,
                )
                .unwrap()
                .as_slice(),
        )
        .unwrap();
        let before = store.account.clone();
        drop(store);

        let store = Store::open(&path, "u1", "una").unwrap();
        assert_eq!(store.account, before);
        assert_eq!(store.account.active_workout_id, started.id);
        // The readable tables are there too.
        let sets: i64 = store
            .conn
            .query_row(
                "SELECT COUNT(*) FROM proposed_sets WHERE workout_id = ?",
                [&started.id],
                |r| r.get(0),
            )
            .unwrap();
        assert_eq!(sets as usize, started.proposed_sets.len());
    }

    #[test]
    fn someone_elses_file_is_refused() {
        let path = temp("owner");
        Store::open(&path, "u1", "una").unwrap();
        assert!(Store::open(&path, "u2", "").is_err());
        assert_eq!(file_owner(&path).unwrap(), ("u1".into(), "una".into()));
    }

    #[test]
    fn the_outbox_is_what_the_server_has_not_acked() {
        let path = temp("outbox");
        let mut store = Store::open(&path, "u1", "una").unwrap();
        onboard(&mut store);
        assert_eq!(store.acked().unwrap(), 0);
        assert_eq!(store.events_after(store.acked().unwrap()).unwrap().len(), 1);
        store.set_acked(1).unwrap();
        assert!(store
            .events_after(store.acked().unwrap())
            .unwrap()
            .is_empty());
        store.set_acked(0).unwrap();
        assert_eq!(store.acked().unwrap(), 1, "acks never go backwards");
    }

    #[test]
    fn a_fresh_install_restores_from_the_servers_log() {
        let mut original = Store::open(&temp("a"), "u1", "").unwrap();
        onboard(&mut original);
        let events = original.events_after(0).unwrap();

        let mut fresh = Store::open(&temp("b"), "u1", "").unwrap();
        assert_eq!(fresh.restore(events).unwrap(), 1);
        assert_eq!(fresh.account, original.account);
        assert_eq!(fresh.acked().unwrap(), 1, "the server holds them");
    }

    #[test]
    fn an_export_opens_as_the_same_account() {
        let mut store = Store::open(&temp("x"), "u1", "una").unwrap();
        onboard(&mut store);
        let dest = temp("export");
        store.export(&dest).unwrap();
        assert_eq!(file_owner(&dest).unwrap(), ("u1".into(), "una".into()));
        assert_eq!(Store::open(&dest, "u1", "").unwrap().account, store.account);
    }
}
