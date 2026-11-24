//! The database's shape, one version at a time. `PRAGMA user_version` is the
//! version a database is at; [migrate] runs every step past it, in order,
//! each in its own transaction, at startup. A new step is a new `if version <
//! N` block at the end: never edit one that has shipped.
//!
//! What lives here is only what the server owns: who people are, how they
//! sign in, who trained together, and telemetry. A person's training is
//! their account's events, stored as they arrive and never interpreted by
//! SQL (see `docs/architecture/data-model.md`); `account_snapshots` only
//! saves folding them again, and can be emptied at any time.

use super::DbResult;
use crate::time::now_unix;
use prost::Message;
use sha2::{Digest, Sha256};
use sqlx::{Pool, Row, Sqlite, Transaction};

pub(super) async fn migrate(pool: &Pool<Sqlite>) -> DbResult<()> {
    let version: i64 = sqlx::query_scalar("PRAGMA user_version")
        .fetch_one(pool)
        .await?;
    if version < 1 {
        let mut tx = pool.begin().await?;
        let converted = v1(&mut tx).await?;
        sqlx::query("PRAGMA user_version = 1")
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
        if converted {
            // The old tables' pages go back to the filesystem. Only space is
            // at stake, so a failure here must not stop the server starting
            // on the schema it has just committed.
            if let Err(error) = sqlx::query("VACUUM").execute(pool).await {
                tracing::warn!(%error, "vacuum after converting failed");
            }
        }
    }
    if version < 2 {
        let mut tx = pool.begin().await?;
        v2(&mut tx).await?;
        sqlx::query("PRAGMA user_version = 2")
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
    }
    if version < 3 {
        let mut tx = pool.begin().await?;
        // The workout a member does in the session: what of theirs the
        // others see, and what ending takes them out. Empty until the first
        // event that puts one in it.
        sqlx::query("ALTER TABLE session_members ADD COLUMN workout_id TEXT NOT NULL DEFAULT ''")
            .execute(&mut *tx)
            .await?;
        sqlx::query("PRAGMA user_version = 3")
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
    }
    if version < 4 {
        let mut tx = pool.begin().await?;
        v4(&mut tx).await?;
        sqlx::query("PRAGMA user_version = 4")
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
    }
    if version < 5 {
        let mut tx = pool.begin().await?;
        v5(&mut tx).await?;
        sqlx::query("PRAGMA user_version = 5")
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
    }
    if version < 6 {
        let mut tx = pool.begin().await?;
        v6(&mut tx).await?;
        sqlx::query("PRAGMA user_version = 6")
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
    }
    if version < 7 {
        let mut tx = pool.begin().await?;
        v7(&mut tx).await?;
        sqlx::query("PRAGMA user_version = 7")
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
    }
    if version < 8 {
        let mut tx = pool.begin().await?;
        v8(&mut tx).await?;
        sqlx::query("PRAGMA user_version = 8")
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
    }
    if version < 9 {
        let mut tx = pool.begin().await?;
        v9(&mut tx).await?;
        sqlx::query("PRAGMA user_version = 9")
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
    }
    if version < 10 {
        let mut tx = pool.begin().await?;
        v10(&mut tx).await?;
        sqlx::query("PRAGMA user_version = 10")
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
    }
    // A step that moves events (as v6 did) leaves snapshots folded from the
    // events as they were: any step run clears them, and they are folded
    // again as accounts are read.
    if version > 0 && version < LATEST {
        sqlx::query("DELETE FROM account_snapshots")
            .execute(pool)
            .await?;
    }
    Ok(())
}

/// The version the steps above bring a database to: a new step moves it.
const LATEST: i64 = 10;

/// A login token as stored: its SHA-256, so the table never holds a token
/// that would let someone in.
pub(super) fn token_hash(token: &str) -> String {
    Sha256::digest(token.as_bytes())
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect()
}

const V1: &str = r#"
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    username TEXT NOT NULL UNIQUE COLLATE NOCASE,
    invite_token TEXT NOT NULL UNIQUE,
    created_at INTEGER NOT NULL,
    emoji TEXT NOT NULL,
    color_hex TEXT NOT NULL,
    body_weight_kg REAL NOT NULL DEFAULT 0,
    -- When the user was made an admin (`schlift admin add`); NULL if not one.
    admin_since INTEGER
);

CREATE TABLE passkeys (
    credential_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- webauthn-rs's Passkey, with the name the user gave it as "cred_name".
    passkey_json TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    created_ip TEXT
);
CREATE INDEX passkeys_user ON passkeys(user_id);

CREATE TABLE logins (
    token_hash TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at INTEGER NOT NULL
);
CREATE INDEX logins_user ON logins(user_id);

-- Each account is a log of events (account.proto), made on the phone and
-- synced. Everything about a person's training is the fold of their log.
CREATE TABLE account_events (
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    seq INTEGER NOT NULL,
    event BLOB NOT NULL,
    PRIMARY KEY (user_id, seq)
);

-- Who trained together. A user is in at most one session at a time: the row
-- with left_at 0. active_at is their last activity in it (joining, or a
-- synced write other than heart rate); a member is on show to the others
-- until it is SESSION_IDLE_SECONDS old. Leaving zeroes it.
CREATE TABLE session_members (
    session_id TEXT NOT NULL,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at INTEGER NOT NULL,
    left_at INTEGER NOT NULL DEFAULT 0,
    active_at INTEGER NOT NULL,
    PRIMARY KEY (session_id, user_id)
) WITHOUT ROWID;
CREATE INDEX session_members_user ON session_members(user_id, joined_at DESC);
CREATE UNIQUE INDEX session_members_current ON session_members(user_id) WHERE left_at = 0;

-- First-party usage analytics: one row per screen visit. (user, session, seq)
-- is the identity so a retried upload is ignored, not double counted.
CREATE TABLE page_views (
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    app_session_id TEXT NOT NULL,
    seq INTEGER NOT NULL,
    page TEXT NOT NULL,
    entered_at_ms INTEGER NOT NULL,
    duration_ms INTEGER NOT NULL DEFAULT 0,
    platform TEXT NOT NULL DEFAULT '',
    app_version TEXT NOT NULL DEFAULT '',
    PRIMARY KEY (user_id, app_session_id, seq)
);
CREATE INDEX page_views_entered ON page_views(entered_at_ms);

-- One row per passkey ceremony the server started. attempt_id is the
-- pre-allocated user id for a registration and the challenge id for a login.
-- A row still 'started' long after started_at is a ceremony that died on the
-- device. Deliberately no username: most of these people never got an account.
CREATE TABLE auth_attempts (
    attempt_id TEXT PRIMARY KEY,
    kind TEXT NOT NULL,
    started_at INTEGER NOT NULL,
    finished_at INTEGER NOT NULL DEFAULT 0,
    outcome TEXT NOT NULL DEFAULT 'started',
    reason TEXT NOT NULL DEFAULT '',
    platform TEXT NOT NULL DEFAULT '',
    app_version TEXT NOT NULL DEFAULT ''
);
CREATE INDEX auth_attempts_started ON auth_attempts(started_at);
"#;

/// The schema above. A database from before versions (it has
/// `users_current`) is converted into it, and true is returned.
async fn v1(tx: &mut Transaction<'_, Sqlite>) -> DbResult<bool> {
    let old = table_exists(tx, "users_current").await?;
    if old {
        // The tables whose names the new schema reuses step aside.
        for table in [
            "account_events",
            "session_members",
            "page_views",
            "auth_attempts",
        ] {
            if table_exists(tx, table).await? {
                sqlx::query(&format!("ALTER TABLE {table} RENAME TO v0_{table}"))
                    .execute(&mut **tx)
                    .await?;
            }
        }
    }
    sqlx::query(V1).execute(&mut **tx).await?;
    if !old {
        return Ok(false);
    }

    // Users: the profile out of its blob into columns; admins onto the row.
    let rows = sqlx::query(
        "SELECT u.user_id, u.user_blob, u.invite_token, a.granted_at
         FROM users_current u LEFT JOIN admins a ON a.user_id = u.user_id",
    )
    .fetch_all(&mut **tx)
    .await?;
    for row in rows {
        let blob: Vec<u8> = row.get("user_blob");
        let user = schlift::workout::v1::User::decode(blob.as_slice())?;
        sqlx::query(
            "INSERT INTO users (id, username, invite_token, created_at, emoji, color_hex,
                                body_weight_kg, admin_since)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(row.get::<String, _>("user_id"))
        .bind(user.name.trim())
        .bind(row.get::<String, _>("invite_token"))
        .bind(user.created_at)
        .bind(&user.profile_emoji)
        .bind(&user.profile_color_hex)
        .bind(user.body_weight_kg)
        .bind(row.get::<Option<i64>, _>("granted_at"))
        .execute(&mut **tx)
        .await?;
    }

    // Logins: only the live ones, hashed.
    let logins = sqlx::query(
        "SELECT token, user_id, expires_at FROM auth_sessions
         WHERE expires_at > ? AND user_id IN (SELECT id FROM users)",
    )
    .bind(now_unix())
    .fetch_all(&mut **tx)
    .await?;
    for row in logins {
        sqlx::query("INSERT INTO logins (token_hash, user_id, expires_at) VALUES (?, ?, ?)")
            .bind(token_hash(row.get("token")))
            .bind(row.get::<String, _>("user_id"))
            .bind(row.get::<i64, _>("expires_at"))
            .execute(&mut **tx)
            .await?;
    }

    for sql in [
        "INSERT INTO passkeys (credential_id, user_id, passkey_json, created_at, created_ip)
         SELECT credential_id, user_id, credential_json, created_at, created_at_ip
         FROM passkey_credentials WHERE user_id IN (SELECT id FROM users)",
        "INSERT INTO account_events (user_id, seq, event)
         SELECT user_id, seq, event_blob FROM v0_account_events
         WHERE user_id IN (SELECT id FROM users)",
        "INSERT INTO page_views SELECT * FROM v0_page_views
         WHERE user_id IN (SELECT id FROM users)",
        "INSERT INTO auth_attempts SELECT * FROM v0_auth_attempts",
    ] {
        sqlx::query(sql).execute(&mut **tx).await?;
    }
    // A member counts as in a session only through the old pointer: any
    // other open membership is closed, so each user has at most one. Their
    // last activity was their live status's last refresh.
    sqlx::query(
        "INSERT INTO session_members (session_id, user_id, joined_at, left_at, active_at)
         SELECT m.session_id, m.user_id, m.first_joined_at,
                CASE WHEN m.left_at = 0 AND m.session_id IS NOT
                          (SELECT c.session_id FROM user_current_session c WHERE c.user_id = m.user_id)
                     THEN ? ELSE m.left_at END,
                COALESCE((SELECT p.updated_at FROM session_participants_current p
                          WHERE p.session_id = m.session_id AND p.user_id = m.user_id),
                         0)
         FROM v0_session_members m WHERE m.user_id IN (SELECT id FROM users)",
    )
    .bind(now_unix())
    .execute(&mut **tx)
    .await?;

    // Everything else was a copy of the events (the workout tables), a cache
    // of them (live participant status), lives in memory now (join requests),
    // or was left behind by designs before the account log (the last eight).
    for table in [
        "users_current",
        "auth_sessions",
        "passkey_credentials",
        "admins",
        "user_current_session",
        "session_participants_current",
        "join_requests",
        "v0_account_events",
        "v0_session_members",
        "v0_page_views",
        "v0_auth_attempts",
        "workouts",
        "proposed_sets",
        "completed_sets",
        "workout_heart_rate_samples",
        "exercise_decisions",
        "workout_templates",
        "active_workout_current",
        "exercise_trackers",
        "progression_applied",
        "schema_migrations",
        "sessions",
        "template_library",
        "user_message_events",
        "user_settings_current",
    ] {
        sqlx::query(&format!("DROP TABLE IF EXISTS {table}"))
            .execute(&mut **tx)
            .await?;
    }
    Ok(true)
}

/// Events as facts, JSON (schlift_core::events), each with its id. Events
/// from before facts are converted out of band, against a backup, and the
/// converted database already reads version 2 (see docs/architecture/
/// local-first.md); this refuses to start on one that wasn't.
async fn v2(tx: &mut Transaction<'_, Sqlite>) -> DbResult<()> {
    let held: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM account_events")
        .fetch_one(&mut **tx)
        .await?;
    if held > 0 {
        return Err("account_events holds events from before facts: convert them first".into());
    }
    sqlx::query(
        "DROP TABLE account_events;
         CREATE TABLE account_events (
             user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
             seq INTEGER NOT NULL,
             id TEXT NOT NULL,
             event TEXT NOT NULL,
             PRIMARY KEY (user_id, seq),
             UNIQUE (user_id, id)
         );
         -- Membership is written on joining, leaving and ending a workout,
         -- never per set: who is active is read from their events.
         ALTER TABLE session_members DROP COLUMN active_at;
         ALTER TABLE session_members ADD COLUMN ended_at INTEGER NOT NULL DEFAULT 0;",
    )
    .execute(&mut **tx)
    .await?;
    Ok(())
}

/// Passkeys held aside for accounts whose owner lost theirs, until an admin
/// approves the code; and passkeys keyed by the credential id as the passkey
/// itself spells it (base64url), where they were keyed by how a Rust type
/// happened to print.
async fn v4(tx: &mut Transaction<'_, Sqlite>) -> DbResult<()> {
    sqlx::query(
        "CREATE TABLE passkey_recoveries (
             request_id TEXT PRIMARY KEY,
             user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
             -- What the person sends an admin. Unique among all requests.
             code TEXT NOT NULL UNIQUE,
             credential_id TEXT NOT NULL,
             -- As in passkeys; emptied once the request is decided.
             passkey_json TEXT NOT NULL,
             created_at INTEGER NOT NULL,
             created_ip TEXT,
             platform TEXT NOT NULL DEFAULT '',
             -- 'pending', 'approved' or 'denied'.
             status TEXT NOT NULL DEFAULT 'pending',
             decided_at INTEGER NOT NULL DEFAULT 0
         );
         CREATE INDEX passkey_recoveries_user ON passkey_recoveries(user_id);
         UPDATE passkeys SET credential_id = passkey_json ->> '$.cred.cred_id'
         WHERE passkey_json ->> '$.cred.cred_id' IS NOT NULL;",
    )
    .execute(&mut **tx)
    .await?;
    Ok(())
}

/// A recovery may be for a username nobody holds (a typo, a guess): it is
/// held like any other, so its maker can come back to its code and an admin
/// who is sent the code can say the name is wrong. Such a row has no user,
/// only the name that was asked for.
async fn v5(tx: &mut Transaction<'_, Sqlite>) -> DbResult<()> {
    sqlx::query(
        "CREATE TABLE passkey_recoveries_v5 (
             request_id TEXT PRIMARY KEY,
             -- NULL when nobody holds asked_username.
             user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
             -- The username as it was typed.
             asked_username TEXT NOT NULL DEFAULT '',
             code TEXT NOT NULL UNIQUE,
             credential_id TEXT NOT NULL,
             passkey_json TEXT NOT NULL,
             created_at INTEGER NOT NULL,
             created_ip TEXT,
             platform TEXT NOT NULL DEFAULT '',
             status TEXT NOT NULL DEFAULT 'pending',
             decided_at INTEGER NOT NULL DEFAULT 0
         );
         INSERT INTO passkey_recoveries_v5
             (request_id, user_id, code, credential_id, passkey_json, created_at, created_ip,
              platform, status, decided_at)
         SELECT request_id, user_id, code, credential_id, passkey_json, created_at, created_ip,
                platform, status, decided_at
         FROM passkey_recoveries;
         DROP TABLE passkey_recoveries;
         ALTER TABLE passkey_recoveries_v5 RENAME TO passkey_recoveries;
         CREATE INDEX passkey_recoveries_user ON passkey_recoveries(user_id);
         CREATE INDEX passkey_recoveries_credential ON passkey_recoveries(credential_id);",
    )
    .execute(&mut **tx)
    .await?;
    Ok(())
}

async fn table_exists(tx: &mut Transaction<'_, Sqlite>, table: &str) -> DbResult<bool> {
    let found: Option<i64> =
        sqlx::query_scalar("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?")
            .bind(table)
            .fetch_optional(&mut **tx)
            .await?;
    Ok(found.is_some())
}

/// Programs: every account's events moved to the shapes they have now
/// (`schlift_core::migrate`): exercises as the built-in program's keys, the
/// template facts as one program, seqs from 1. Phones drop what they hold
/// (the store's format moved on with it) and pull the moved log.
async fn v6(tx: &mut Transaction<'_, Sqlite>) -> DbResult<()> {
    let users: Vec<String> =
        sqlx::query_scalar("SELECT DISTINCT user_id FROM account_events ORDER BY user_id")
            .fetch_all(&mut **tx)
            .await?;
    for user_id in users {
        let stored: Vec<String> =
            sqlx::query_scalar("SELECT event FROM account_events WHERE user_id = ? ORDER BY seq")
                .bind(&user_id)
                .fetch_all(&mut **tx)
                .await?;
        let values: Vec<serde_json::Value> = stored
            .iter()
            .filter_map(|json| serde_json::from_str(json).ok())
            .collect();
        let moved = schlift_core::migrate::migrate(&values);
        sqlx::query("DELETE FROM account_events WHERE user_id = ?")
            .bind(&user_id)
            .execute(&mut **tx)
            .await?;
        for event in &moved {
            let json = serde_json::to_string(event).expect("an event serialises");
            sqlx::query("INSERT INTO account_events (user_id, seq, id, event) VALUES (?, ?, ?, ?)")
                .bind(&user_id)
                .bind(event.seq)
                .bind(&event.id)
                .bind(json)
                .execute(&mut **tx)
                .await?;
        }
        tracing::info!(%user_id, before = stored.len(), after = moved.len(), "account moved to programs");
    }
    Ok(())
}

/// Assistants connected over MCP (`db/assistants.rs`): the clients that
/// registered, the codes a consent issued, the grants made and their
/// tokens, each code and token stored as its hash. (`IF NOT EXISTS`: a
/// database rewound to an earlier version in a test runs it again.)
async fn v7(tx: &mut Transaction<'_, Sqlite>) -> DbResult<()> {
    sqlx::query(
        "CREATE TABLE IF NOT EXISTS assistant_clients (
             client_id TEXT PRIMARY KEY,
             client_name TEXT NOT NULL,
             -- A JSON array of the exact redirect URIs it registered.
             redirect_uris TEXT NOT NULL,
             created_at INTEGER NOT NULL
         );
         CREATE TABLE IF NOT EXISTS assistant_codes (
             code_hash TEXT PRIMARY KEY,
             user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
             client_id TEXT NOT NULL REFERENCES assistant_clients(client_id) ON DELETE CASCADE,
             redirect_uri TEXT NOT NULL,
             code_challenge TEXT NOT NULL,
             scope TEXT NOT NULL,
             expires_at INTEGER NOT NULL
         );
         CREATE TABLE IF NOT EXISTS assistant_grants (
             grant_id TEXT PRIMARY KEY,
             user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
             client_id TEXT NOT NULL REFERENCES assistant_clients(client_id) ON DELETE CASCADE,
             scope TEXT NOT NULL,
             created_at INTEGER NOT NULL,
             last_used_at INTEGER NOT NULL DEFAULT 0
         );
         CREATE INDEX IF NOT EXISTS assistant_grants_user ON assistant_grants(user_id);
         CREATE TABLE IF NOT EXISTS assistant_tokens (
             token_hash TEXT PRIMARY KEY,
             grant_id TEXT NOT NULL REFERENCES assistant_grants(grant_id) ON DELETE CASCADE,
             -- 'access' or 'refresh'.
             kind TEXT NOT NULL,
             expires_at INTEGER NOT NULL
         );
         CREATE INDEX IF NOT EXISTS assistant_tokens_grant ON assistant_tokens(grant_id);",
    )
    .execute(&mut **tx)
    .await?;
    Ok(())
}

/// What assistants say about the MCP tools (`send_feedback`): server-owned
/// telemetry, read on the admin page to make the tools easier.
async fn v8(tx: &mut Transaction<'_, Sqlite>) -> DbResult<()> {
    sqlx::query(
        "CREATE TABLE IF NOT EXISTS assistant_feedback (
             id INTEGER PRIMARY KEY,
             user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
             -- As the client registered it (\"Claude\").
             client_name TEXT NOT NULL,
             -- The tool it is about, or ''.
             tool TEXT NOT NULL DEFAULT '',
             text TEXT NOT NULL,
             created_at INTEGER NOT NULL
         );
         CREATE INDEX IF NOT EXISTS assistant_feedback_user ON assistant_feedback(user_id, created_at);",
    )
    .execute(&mut **tx)
    .await?;
    Ok(())
}

/// Who may suggest changes to whose program (docs/plans/set-types.md):
/// server-owned grants, made to someone the owner has trained with. Either
/// account going takes the grant with it.
async fn v9(tx: &mut Transaction<'_, Sqlite>) -> DbResult<()> {
    sqlx::query(
        "CREATE TABLE IF NOT EXISTS program_editors (
             user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
             editor_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
             created_at INTEGER NOT NULL,
             PRIMARY KEY (user_id, editor_id)
         );
         CREATE INDEX IF NOT EXISTS program_editors_editor ON program_editors(editor_id);",
    )
    .execute(&mut **tx)
    .await?;
    Ok(())
}

/// Each account folded as of some point in its log (`db/snapshots.rs`), so
/// a read folds only the events after it. Nothing in it is the truth: every
/// row can be thrown away and folded again from the events, and is when the
/// rules that folded it (`fold`, the build's) aren't this server's.
async fn v10(tx: &mut Transaction<'_, Sqlite>) -> DbResult<()> {
    sqlx::query(
        "CREATE TABLE IF NOT EXISTS account_snapshots (
             user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
             -- The last event folded into it.
             seq INTEGER NOT NULL,
             -- The rules that folded it: schlift_core's sources, hashed.
             fold TEXT NOT NULL,
             -- schlift_core::snapshot, without heart rate.
             state BLOB NOT NULL,
             updated_at INTEGER NOT NULL
         );",
    )
    .execute(&mut **tx)
    .await?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use crate::db::ServerDb;
    use crate::time::now_unix;
    use prost::Message;
    use schlift::workout::v1::User;
    use uuid::Uuid;

    /// The tables of a database from before versions, as v0.14.1 left them.
    const V0: &str = r#"
        CREATE TABLE users_current (user_id TEXT PRIMARY KEY, user_blob BLOB NOT NULL,
            username_ci TEXT NOT NULL UNIQUE, invite_token TEXT NOT NULL UNIQUE);
        CREATE TABLE auth_sessions (token TEXT PRIMARY KEY, user_id TEXT NOT NULL,
            expires_at INTEGER NOT NULL);
        CREATE TABLE passkey_credentials (credential_id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
            credential_json TEXT NOT NULL, created_at INTEGER NOT NULL, created_at_ip TEXT);
        CREATE TABLE account_events (user_id TEXT NOT NULL, seq INTEGER NOT NULL,
            event_blob BLOB NOT NULL, PRIMARY KEY(user_id, seq));
        CREATE TABLE user_current_session (user_id TEXT PRIMARY KEY, session_id TEXT NOT NULL);
        CREATE TABLE session_participants_current (session_id TEXT NOT NULL, user_id TEXT NOT NULL,
            participant_blob BLOB NOT NULL, updated_at INTEGER NOT NULL,
            PRIMARY KEY(session_id, user_id));
        CREATE TABLE session_members (session_id TEXT NOT NULL, user_id TEXT NOT NULL,
            first_joined_at INTEGER NOT NULL, left_at INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY(session_id, user_id));
        CREATE TABLE join_requests (request_id TEXT PRIMARY KEY, from_user_id TEXT NOT NULL,
            to_user_id TEXT NOT NULL, created_at INTEGER NOT NULL);
        CREATE TABLE page_views (user_id TEXT NOT NULL, app_session_id TEXT NOT NULL,
            seq INTEGER NOT NULL, page TEXT NOT NULL, entered_at_ms INTEGER NOT NULL,
            duration_ms INTEGER NOT NULL DEFAULT 0, platform TEXT NOT NULL DEFAULT '',
            app_version TEXT NOT NULL DEFAULT '', PRIMARY KEY(user_id, app_session_id, seq));
        CREATE TABLE auth_attempts (attempt_id TEXT PRIMARY KEY, kind TEXT NOT NULL,
            started_at INTEGER NOT NULL, finished_at INTEGER NOT NULL DEFAULT 0,
            outcome TEXT NOT NULL DEFAULT 'started', reason TEXT NOT NULL DEFAULT '',
            platform TEXT NOT NULL DEFAULT '', app_version TEXT NOT NULL DEFAULT '');
        CREATE TABLE admins (user_id TEXT PRIMARY KEY, granted_at INTEGER NOT NULL);
        CREATE TABLE workouts (id TEXT PRIMARY KEY, user_id TEXT NOT NULL);
        CREATE TABLE workout_heart_rate_samples (id TEXT PRIMARY KEY, user_id TEXT NOT NULL);
    "#;

    fn temp_dir() -> std::path::PathBuf {
        let dir = std::env::temp_dir().join(format!("lift-migrate-test-{}", Uuid::new_v4()));
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[tokio::test]
    async fn a_fresh_database_starts_at_the_latest_version() {
        let dir = temp_dir();
        let db = ServerDb::new_in_dir(&dir).await.unwrap();
        let version: i64 = sqlx::query_scalar("PRAGMA user_version")
            .fetch_one(&db.read_pool)
            .await
            .unwrap();
        assert_eq!(version, super::LATEST);
        drop(db);
        // Opening again runs nothing.
        ServerDb::new_in_dir(&dir).await.unwrap();
    }

    /// A version 1 database whose events weren't converted to facts is
    /// refused (the deploy rolls back); one with none gets the new table.
    #[tokio::test]
    async fn step_two_needs_the_events_converted() {
        for (events, starts) in [(true, false), (false, true)] {
            let dir = temp_dir();
            let pool = sqlx::SqlitePool::connect(&format!(
                "sqlite://{}/server.sqlite?mode=rwc",
                dir.display()
            ))
            .await
            .unwrap();
            let mut tx = pool.begin().await.unwrap();
            super::v1(&mut tx).await.unwrap();
            sqlx::query("PRAGMA user_version = 1")
                .execute(&mut *tx)
                .await
                .unwrap();
            tx.commit().await.unwrap();
            if events {
                sqlx::query(
                    "INSERT INTO users (id, username, invite_token, created_at, emoji, color_hex)
                     VALUES ('u', 'u', 'i', 0, '', '')",
                )
                .execute(&pool)
                .await
                .unwrap();
                sqlx::query("INSERT INTO account_events VALUES ('u', 1, x'0801')")
                    .execute(&pool)
                    .await
                    .unwrap();
            }
            pool.close().await;
            let opened = ServerDb::new_in_dir(&dir).await;
            assert_eq!(opened.is_ok(), starts, "events held: {events}");
            if let Ok(db) = opened {
                let columns: Vec<String> =
                    sqlx::query_scalar("SELECT name FROM pragma_table_info('account_events')")
                        .fetch_all(&db.read_pool)
                        .await
                        .unwrap();
                assert_eq!(columns, ["user_id", "seq", "id", "event"]);
            }
        }
    }

    #[tokio::test]
    async fn a_database_from_before_versions_is_converted() {
        let dir = temp_dir();
        let old = sqlx::SqlitePool::connect(&format!(
            "sqlite://{}/server.sqlite?mode=rwc",
            dir.display()
        ))
        .await
        .unwrap();
        sqlx::query(V0).execute(&old).await.unwrap();
        let now = now_unix();
        let user = User {
            id: "u1".into(),
            name: "Lyss".into(),
            created_at: 100,
            profile_emoji: "🦦".into(),
            profile_color_hex: "#112233".into(),
            body_weight_kg: 61.5,
        };
        for (sql, binds) in [
            (
                "INSERT INTO users_current VALUES ('u1', ?, 'lyss', 'invite-1')",
                vec![],
            ),
            (
                "INSERT INTO users_current VALUES ('u2', ?, 'bo', 'invite-2')",
                vec![],
            ),
            ("INSERT INTO admins VALUES ('u1', 200)", vec![]),
            (
                "INSERT INTO auth_sessions VALUES ('live-token', 'u1', ?)",
                vec![now + 999],
            ),
            (
                "INSERT INTO auth_sessions VALUES ('dead-token', 'u1', 1)",
                vec![],
            ),
            (
                "INSERT INTO passkey_credentials VALUES ('cred-1', 'u1', '{}', 300, NULL)",
                vec![],
            ),
            // u1 is in s2 now; s1 was never closed.
            (
                "INSERT INTO session_members VALUES ('s1', 'u1', 10, 0)",
                vec![],
            ),
            (
                "INSERT INTO session_members VALUES ('s2', 'u1', 20, 0)",
                vec![],
            ),
            (
                "INSERT INTO user_current_session VALUES ('u1', 's2')",
                vec![],
            ),
            (
                "INSERT INTO session_participants_current VALUES ('s2', 'u1', x'', ?)",
                vec![now],
            ),
            (
                "INSERT INTO page_views (user_id, app_session_id, seq, page, entered_at_ms)
                 VALUES ('u1', 'a', 1, 'home', 5)",
                vec![],
            ),
            (
                "INSERT INTO auth_attempts (attempt_id, kind, started_at) VALUES ('t', 'login', 7)",
                vec![],
            ),
        ] {
            let mut query = sqlx::query(sql);
            if sql.contains("users_current") {
                let mut u = user.clone();
                if sql.contains("'u2'") {
                    u = User {
                        id: "u2".into(),
                        name: "Bo".into(),
                        ..user.clone()
                    };
                }
                query = query.bind(u.encode_to_vec());
            }
            for b in binds {
                query = query.bind(b);
            }
            query.execute(&old).await.unwrap();
        }
        old.close().await;

        let db = ServerDb::new_in_dir(&dir).await.unwrap();
        assert_eq!(db.get_user("u1").await.unwrap(), Some(user));
        assert_eq!(
            db.get_user_by_name("LYSS").await.unwrap().map(|u| u.id),
            Some("u1".to_string())
        );
        assert!(db.is_admin("u1").await.unwrap());
        assert!(!db.is_admin("u2").await.unwrap());
        assert_eq!(
            db.validate_auth_session("live-token")
                .await
                .unwrap()
                .as_deref(),
            Some("u1")
        );
        assert_eq!(db.validate_auth_session("dead-token").await.unwrap(), None);
        assert_eq!(
            db.get_credentials_for_user("u1").await.unwrap(),
            vec!["{}".to_string()]
        );
        assert_eq!(
            db.get_invite_token("u2").await.unwrap().as_deref(),
            Some("invite-2")
        );
        assert_eq!(
            db.get_user_session_pointer("u1").await.unwrap().as_deref(),
            Some("s2")
        );
        assert!(
            db.session_member_left_at("s1", "u1").await.unwrap() > 0,
            "s1 was closed"
        );
        for gone in [
            "users_current",
            "auth_sessions",
            "admins",
            "workouts",
            "join_requests",
        ] {
            let left: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM sqlite_master WHERE name = ?")
                .bind(gone)
                .fetch_one(&db.read_pool)
                .await
                .unwrap();
            assert_eq!(left, 0, "{gone} is still there");
        }
    }

    /// An account stored before programs moves: its events read as they
    /// are now, its templates are its program's workouts, and its plans
    /// come out of the fold.
    #[tokio::test]
    async fn accounts_move_to_programs() {
        let dir = std::env::temp_dir().join(format!("lift-v6-{}", Uuid::new_v4()));
        let db = ServerDb::new_in_dir(&dir).await.unwrap();
        db.create_user_with_id("u1", "Lyss").await.unwrap();
        let old: Vec<serde_json::Value> = serde_json::from_str(include_str!(
            "../../core/tests/testdata/stored_events_before_programs.json"
        ))
        .unwrap();
        for (n, event) in old.iter().enumerate() {
            sqlx::query("INSERT INTO account_events (user_id, seq, id, event) VALUES (?, ?, ?, ?)")
                .bind("u1")
                .bind(n as i64 + 1)
                .bind(event["id"].as_str().unwrap())
                .bind(event.to_string())
                .execute(&db.write_pool)
                .await
                .unwrap();
        }
        sqlx::query("PRAGMA user_version = 5")
            .execute(&db.write_pool)
            .await
            .unwrap();
        drop(db);

        let db = ServerDb::new_in_dir(&dir).await.unwrap();
        let account = db.read_account("u1", Clone::clone).await.unwrap();
        assert!(!account.program.workouts.is_empty(), "the templates moved");
        assert!(!account.workouts.is_empty());
        let rows: Vec<(i64, String)> = sqlx::query_as(
            "SELECT seq, event FROM account_events WHERE user_id = 'u1' ORDER BY seq",
        )
        .fetch_all(&db.read_pool)
        .await
        .unwrap();
        assert!(rows
            .iter()
            .enumerate()
            .all(|(n, (seq, _))| *seq == n as i64 + 1));
        assert!(rows.iter().any(|(_, e)| e.contains("\"ProgramSet\"")));
        assert!(!rows.iter().any(|(_, e)| e.contains("\"TemplateSaved\"")));
    }
}
