//! What the admin page reads about every account besides its training:
//! the rows the server owns. The training itself is folded from each
//! account's events by the caller, for that answer only.

use super::*;
use std::collections::HashSet;

/// The most accounts one answer covers, most recently created first.
const MAX_ACCOUNTS: i64 = 2_000;

/// An account as the server's own tables describe it.
pub struct AccountRow {
    pub user_id: String,
    pub username: String,
    pub created_at: i64,
    pub is_admin: bool,
    pub passkeys: i32,
    /// Logins not yet expired.
    pub logins: i32,
    /// The latest page view, and the app it came from; 0 and empty if none.
    pub last_seen_ms: i64,
    pub platform: String,
    pub app_version: String,
    /// Events in the account's log.
    pub events: i64,
}

impl ServerDb {
    pub async fn account_rows(&self) -> DbResult<Vec<AccountRow>> {
        const LATEST_VIEW: &str =
            "FROM page_views v WHERE v.user_id = u.id ORDER BY v.entered_at_ms DESC LIMIT 1";
        let rows = sqlx::query(&format!(
            "SELECT u.id, u.username, u.created_at, u.admin_since IS NOT NULL AS is_admin,
                    (SELECT COUNT(*) FROM passkeys p WHERE p.user_id = u.id) AS passkeys,
                    (SELECT COUNT(*) FROM logins l WHERE l.user_id = u.id AND l.expires_at > ?)
                        AS logins,
                    COALESCE((SELECT v.entered_at_ms {LATEST_VIEW}), 0) AS last_seen_ms,
                    COALESCE((SELECT v.platform {LATEST_VIEW}), '') AS platform,
                    COALESCE((SELECT v.app_version {LATEST_VIEW}), '') AS app_version,
                    (SELECT COUNT(*) FROM account_events e WHERE e.user_id = u.id) AS events
             FROM users u ORDER BY u.created_at DESC LIMIT ?"
        ))
        .bind(now_unix())
        .bind(MAX_ACCOUNTS)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| AccountRow {
                user_id: r.get("id"),
                username: r.get("username"),
                created_at: r.get("created_at"),
                is_admin: r.get("is_admin"),
                passkeys: r.get("passkeys"),
                logins: r.get("logins"),
                last_seen_ms: r.get("last_seen_ms"),
                platform: r.get("platform"),
                app_version: r.get("app_version"),
                events: r.get("events"),
            })
            .collect())
    }

    /// The workouts done in a session someone else was also in.
    pub async fn workouts_done_together(&self) -> DbResult<HashSet<String>> {
        let ids: Vec<String> = sqlx::query_scalar(
            "SELECT m.workout_id FROM session_members m
             WHERE m.workout_id != ''
               AND (SELECT COUNT(*) FROM session_members o WHERE o.session_id = m.session_id) > 1",
        )
        .fetch_all(&self.read_pool)
        .await?;
        Ok(ids.into_iter().collect())
    }
}
