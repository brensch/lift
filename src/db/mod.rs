use prost::Message;
use schlift::workout::v1::ParticipantStatus;
use sqlx::{
    sqlite::{SqliteConnectOptions, SqliteJournalMode, SqlitePoolOptions, SqliteSynchronous},
    Pool, Row, Sqlite,
};
use std::path::Path;
use std::str::FromStr;
use uuid::Uuid;

use crate::time::now_unix;

mod accounts;
mod analytics;
mod auth;
pub use accounts::{Diverged, Pushed};
mod session;
#[cfg(test)]
pub use session::SESSION_IDLE_SECONDS;

pub use analytics::MAX_STATS_WINDOW_DAYS;

const SERVER_SCHEMA: &str = r#"
CREATE TABLE IF NOT EXISTS users_current (
    user_id TEXT PRIMARY KEY,
    user_blob BLOB NOT NULL,
    username_ci TEXT NOT NULL UNIQUE,
    invite_token TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS auth_sessions (
    token TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    expires_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_auth_sessions_user_id ON auth_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_auth_sessions_expires_at ON auth_sessions(expires_at);

CREATE TABLE IF NOT EXISTS passkey_credentials (
    credential_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    credential_json TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    created_at_ip TEXT
);
CREATE INDEX IF NOT EXISTS idx_passkey_credentials_user_id
    ON passkey_credentials(user_id, created_at DESC);

-- Each account is a log of events (account.proto), made on the phone and
-- synced. Everything about a person's training is the fold of their log;
-- the workout tables (schlift_core::projection::WORKOUT_SCHEMA) are
-- projections of it, rewritten whenever a workout's events arrive, for SQL
-- analytics and multiplayer history.
CREATE TABLE IF NOT EXISTS account_events (
    user_id TEXT NOT NULL,
    seq INTEGER NOT NULL,
    event_blob BLOB NOT NULL,
    PRIMARY KEY(user_id, seq)
);

CREATE TABLE IF NOT EXISTS user_current_session (
    user_id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_user_current_session_session
    ON user_current_session(session_id);

CREATE TABLE IF NOT EXISTS session_participants_current (
    session_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    participant_blob BLOB NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY(session_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_session_participants_current_session
    ON session_participants_current(session_id, updated_at DESC);

-- Durable roster: every (session, user) that ever joined, with join/leave times.
-- Unlike user_current_session (live, one row per user) and
-- session_participants_current (live blob cache, pruned on leave), these rows are
-- never deleted — they are the authoritative record of who trained together.
CREATE TABLE IF NOT EXISTS session_members (
    session_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    first_joined_at INTEGER NOT NULL,
    left_at INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY(session_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_session_members_user
    ON session_members(user_id, first_joined_at DESC);

-- Pending "train together" requests: from_user asks to_user; to_user approves or
-- declines. Rows are deleted once answered (or when they expire on read).
CREATE TABLE IF NOT EXISTS join_requests (
    request_id TEXT PRIMARY KEY,
    from_user_id TEXT NOT NULL,
    to_user_id TEXT NOT NULL,
    created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_join_requests_to
    ON join_requests(to_user_id, created_at DESC);

-- First-party usage analytics: one row per screen visit. (user, session, seq)
-- is the identity so a retried upload is ignored, not double counted.
CREATE TABLE IF NOT EXISTS page_views (
    user_id TEXT NOT NULL,
    app_session_id TEXT NOT NULL,
    seq INTEGER NOT NULL,
    page TEXT NOT NULL,
    entered_at_ms INTEGER NOT NULL,
    duration_ms INTEGER NOT NULL DEFAULT 0,
    platform TEXT NOT NULL DEFAULT '',
    app_version TEXT NOT NULL DEFAULT '',
    PRIMARY KEY(user_id, app_session_id, seq)
);
CREATE INDEX IF NOT EXISTS idx_page_views_user_entered
    ON page_views(user_id, entered_at_ms DESC);
CREATE INDEX IF NOT EXISTS idx_page_views_entered
    ON page_views(entered_at_ms);

-- One row per passkey ceremony the server started. attempt_id is the
-- pre-allocated user id for a registration and the challenge id for a login.
-- A row still 'started' long after started_at is a ceremony that died on the
-- device. Deliberately no username: most of these people never got an account.
CREATE TABLE IF NOT EXISTS auth_attempts (
    attempt_id TEXT PRIMARY KEY,
    kind TEXT NOT NULL,
    started_at INTEGER NOT NULL,
    finished_at INTEGER NOT NULL DEFAULT 0,
    outcome TEXT NOT NULL DEFAULT 'started',
    reason TEXT NOT NULL DEFAULT '',
    platform TEXT NOT NULL DEFAULT '',
    app_version TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_auth_attempts_started
    ON auth_attempts(started_at);

-- Keyed by user_id, never by name: a name is freed by account deletion and
-- could be re-registered by someone else. Granted with `schlift admin add`.
CREATE TABLE IF NOT EXISTS admins (
    user_id TEXT PRIMARY KEY,
    granted_at INTEGER NOT NULL
);
"#;

pub type DbResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

/// Something a live view may need to redraw for. The Sync stream of every
/// connected device listens and re-sends what concerns it.
#[derive(Clone, Debug, PartialEq)]
pub enum Change {
    /// A session's members or their progress.
    Session(String),
    /// A user's own session membership.
    Membership(String),
    /// Requests to join this user.
    JoinRequests(String),
}

#[derive(Clone)]
pub struct ServerDb {
    pub read_pool: Pool<Sqlite>,
    write_pool: Pool<Sqlite>,
    accounts: std::sync::Arc<accounts::AccountCache>,
    changes: tokio::sync::broadcast::Sender<Change>,
}

/// Columns of the projected tables added after the table already existed
/// in production: `CREATE TABLE IF NOT EXISTS` leaves an old table as it
/// was, so each is added at startup when it is missing. Columns the
/// projections no longer write stay, with their defaults.
const ADDED_COLUMNS: &[(&str, &str, &str)] = &[(
    "proposed_sets",
    "rest_seconds",
    "INTEGER NOT NULL DEFAULT 0",
)];

/// Columns no longer in the schema, dropped at startup from a table that
/// still has them: each is `NOT NULL` without a default, so an insert that
/// leaves it out would fail.
const DROPPED_COLUMNS: &[(&str, &str)] = &[
    ("user_current_session", "joined_at"),
    ("session_members", "last_seen_at"),
];

/// Indexes no longer in either schema, dropped at startup so writes stop
/// maintaining them.
const DROPPED_INDEXES: &[&str] = &[
    "idx_session_members_session",
    "idx_workouts_session",
    "idx_completed_sets_proposed",
];

impl ServerDb {
    pub async fn new_in_dir(data_dir: impl AsRef<Path>) -> DbResult<Self> {
        let data_dir = data_dir.as_ref();
        std::fs::create_dir_all(data_dir)?;
        let db_path = format!("{}/server.sqlite", data_dir.display());
        let options = SqliteConnectOptions::from_str(&format!("sqlite://{}", db_path))?
            .create_if_missing(true)
            .synchronous(SqliteSynchronous::Normal)
            .journal_mode(SqliteJournalMode::Wal)
            .busy_timeout(std::time::Duration::from_secs(30));
        let write_pool = SqlitePoolOptions::new()
            .max_connections(1)
            .acquire_slow_threshold(std::time::Duration::from_secs(60))
            .connect_with(options.clone())
            .await?;
        let read_pool = SqlitePoolOptions::new()
            .max_connections(16)
            .connect_with(options)
            .await?;
        sqlx::query(SERVER_SCHEMA).execute(&write_pool).await?;
        sqlx::query(schlift_core::projection::WORKOUT_SCHEMA)
            .execute(&write_pool)
            .await?;
        for (table, column, declaration) in ADDED_COLUMNS {
            let has: bool =
                sqlx::query_scalar("SELECT COUNT(*) > 0 FROM pragma_table_info(?) WHERE name = ?")
                    .bind(table)
                    .bind(column)
                    .fetch_one(&write_pool)
                    .await?;
            if !has {
                sqlx::query(&format!(
                    "ALTER TABLE {table} ADD COLUMN {column} {declaration}"
                ))
                .execute(&write_pool)
                .await?;
            }
        }
        for (table, column) in DROPPED_COLUMNS {
            let has: bool =
                sqlx::query_scalar("SELECT COUNT(*) > 0 FROM pragma_table_info(?) WHERE name = ?")
                    .bind(table)
                    .bind(column)
                    .fetch_one(&write_pool)
                    .await?;
            if has {
                sqlx::query(&format!("ALTER TABLE {table} DROP COLUMN {column}"))
                    .execute(&write_pool)
                    .await?;
            }
        }
        for index in DROPPED_INDEXES {
            sqlx::query(&format!("DROP INDEX IF EXISTS {index}"))
                .execute(&write_pool)
                .await?;
        }
        Ok(Self {
            read_pool,
            write_pool,
            accounts: Default::default(),
            changes: tokio::sync::broadcast::channel(1024).0,
        })
    }

    /// Hear about changes from now on.
    pub fn subscribe(&self) -> tokio::sync::broadcast::Receiver<Change> {
        self.changes.subscribe()
    }

    fn notify(&self, change: Change) {
        // No receivers is fine: nobody is watching.
        let _ = self.changes.send(change);
    }
}

#[cfg(test)]
mod schema_tests {
    use super::*;

    #[tokio::test]
    async fn dropped_columns_are_dropped_from_an_existing_table() {
        let dir = std::env::temp_dir().join(format!("lift-schema-test-{}", Uuid::new_v4()));
        let db = ServerDb::new_in_dir(&dir).await.unwrap();
        for (table, column) in DROPPED_COLUMNS {
            sqlx::query(&format!(
                "ALTER TABLE {table} ADD COLUMN {column} INTEGER NOT NULL DEFAULT 0"
            ))
            .execute(&db.write_pool)
            .await
            .unwrap();
        }
        drop(db);
        let db = ServerDb::new_in_dir(&dir).await.unwrap();
        for (table, column) in DROPPED_COLUMNS {
            let has: bool =
                sqlx::query_scalar("SELECT COUNT(*) > 0 FROM pragma_table_info(?) WHERE name = ?")
                    .bind(table)
                    .bind(column)
                    .fetch_one(&db.read_pool)
                    .await
                    .unwrap();
            assert!(!has, "{table}.{column} is still there");
        }
        db.set_user_current_session("u", "s").await.unwrap();
        db.upsert_session_member("s", "u").await.unwrap();
    }
}
