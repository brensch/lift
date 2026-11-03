//! The database's shape, one version at a time. `PRAGMA user_version` is the
//! version a database is at; [migrate] runs every step past it, in order,
//! each in its own transaction, at startup. A new step is a new `if version <
//! N` block at the end: never edit one that has shipped.
//!
//! What lives here is only what the server owns: who people are, how they
//! sign in, who trained together, and telemetry. A person's training is
//! their account's events, stored as they arrive and never interpreted by
//! SQL (see `docs/architecture/data-model.md`).

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
    Ok(())
}

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
         );",
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
        assert_eq!(version, 2);
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
            db.get_user_current_session("u1").await.unwrap().as_deref(),
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
}
