use super::*;
use schlift::workout::v1::{
    AuthAttemptStat, DailyStat, PageStat, PageView, TrailEntry, UserActivity,
};
use std::collections::HashSet;

/// The widest window GetStats will aggregate. Page views are kept until the
/// account is deleted; auth attempts older than this are dropped.
pub const MAX_STATS_WINDOW_DAYS: i64 = 365;

/// A 'started' attempt younger than this may still be mid-ceremony, so it is
/// neither reportable-as-abandoned in stats nor too old to annotate.
const AUTH_ATTEMPT_IN_FLIGHT_SECS: i64 = 600;
const AUTH_ATTEMPT_REPORT_WINDOW_SECS: i64 = 3600;

impl ServerDb {
    // ── Page views ──

    /// Inserts already-validated views. A (user, session, seq) seen before is
    /// ignored, so the app can retry a batch without double counting.
    pub async fn record_page_views(
        &self,
        user_id: &str,
        platform: &str,
        app_version: &str,
        views: &[PageView],
    ) -> DbResult<usize> {
        let mut tx = self.write_pool.begin().await?;
        let mut accepted = 0;
        for view in views {
            let result = sqlx::query(
                "INSERT OR IGNORE INTO page_views
                 (user_id, app_session_id, seq, page, entered_at_ms, duration_ms, platform, app_version)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            )
            .bind(user_id)
            .bind(&view.app_session_id)
            .bind(view.seq)
            .bind(&view.page)
            .bind(view.entered_at_ms)
            .bind(view.duration_ms)
            .bind(platform)
            .bind(app_version)
            .execute(&mut *tx)
            .await?;
            accepted += result.rows_affected() as usize;
        }
        tx.commit().await?;
        Ok(accepted)
    }

    // ── Auth attempts ──

    /// Record a ceremony starting, and drop attempts older than any stats
    /// window reads.
    pub async fn start_auth_attempt(
        &self,
        attempt_id: &str,
        kind: &str,
        platform: &str,
        app_version: &str,
    ) -> DbResult<()> {
        let now = now_unix();
        let mut tx = self.write_pool.begin().await?;
        sqlx::query("DELETE FROM auth_attempts WHERE started_at < ?")
            .bind(now - MAX_STATS_WINDOW_DAYS * 86_400)
            .execute(&mut *tx)
            .await?;
        sqlx::query(
            "INSERT OR IGNORE INTO auth_attempts (attempt_id, kind, started_at, platform, app_version)
             VALUES (?, ?, ?, ?, ?)",
        )
        .bind(attempt_id)
        .bind(kind)
        .bind(now)
        .bind(platform)
        .bind(app_version)
        .execute(&mut *tx)
        .await?;
        tx.commit().await?;
        Ok(())
    }

    /// The server's own verdict. Overrides anything the client reported,
    /// but never an earlier verdict: a finish replayed for a settled attempt
    /// (anyone can send one, naming a user id) changes nothing.
    pub async fn finish_auth_attempt(
        &self,
        attempt_id: &str,
        outcome: &str,
        reason: &str,
    ) -> DbResult<()> {
        sqlx::query(
            "UPDATE auth_attempts SET outcome = ?, reason = ?, finished_at = ?
             WHERE attempt_id = ? AND outcome IN ('started', 'client_error')",
        )
        .bind(outcome)
        .bind(reason)
        .bind(now_unix())
        .bind(attempt_id)
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    /// The client's account of why a ceremony died. Only lands on an attempt
    /// the server issued, that is recent, and that nobody has finished or
    /// annotated yet — so this unauthenticated path can never create a row or
    /// rewrite a settled one. Returns whether it landed.
    pub async fn report_auth_failure(&self, attempt_id: &str, reason: &str) -> DbResult<bool> {
        let now = now_unix();
        let result = sqlx::query(
            "UPDATE auth_attempts SET outcome = 'client_error', reason = ?, finished_at = ?
             WHERE attempt_id = ? AND outcome = 'started' AND started_at >= ?",
        )
        .bind(reason)
        .bind(now)
        .bind(attempt_id)
        .bind(now - AUTH_ATTEMPT_REPORT_WINDOW_SECS)
        .execute(&self.write_pool)
        .await?;
        Ok(result.rows_affected() > 0)
    }

    // ── Admins ──

    pub async fn is_admin(&self, user_id: &str) -> DbResult<bool> {
        let found: Option<i64> =
            sqlx::query_scalar("SELECT 1 FROM users WHERE id = ? AND admin_since IS NOT NULL")
                .bind(user_id)
                .fetch_optional(&self.read_pool)
                .await?;
        Ok(found.is_some())
    }

    /// Resolves the name to a user id *now* and stores the id. Returns None
    /// when nobody holds that name — an admin grant must never sit waiting for
    /// whoever registers the name first.
    pub async fn grant_admin(&self, username: &str) -> DbResult<Option<String>> {
        let Some(user) = self.get_user_by_name(username).await? else {
            return Ok(None);
        };
        sqlx::query("UPDATE users SET admin_since = COALESCE(admin_since, ?) WHERE id = ?")
            .bind(now_unix())
            .bind(&user.id)
            .execute(&self.write_pool)
            .await?;
        Ok(Some(user.id))
    }

    /// Returns whether an admin row was removed.
    pub async fn revoke_admin(&self, username: &str) -> DbResult<bool> {
        let Some(user) = self.get_user_by_name(username).await? else {
            return Ok(false);
        };
        let result = sqlx::query(
            "UPDATE users SET admin_since = NULL WHERE id = ? AND admin_since IS NOT NULL",
        )
        .bind(&user.id)
        .execute(&self.write_pool)
        .await?;
        Ok(result.rows_affected() > 0)
    }

    /// (username, user_id, granted_at)
    pub async fn list_admins(&self) -> DbResult<Vec<(String, String, i64)>> {
        let rows = sqlx::query(
            "SELECT username, id, admin_since FROM users
             WHERE admin_since IS NOT NULL ORDER BY admin_since",
        )
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| (r.get("username"), r.get("id"), r.get("admin_since")))
            .collect())
    }

    // ── Stats (admin read side) ──

    pub async fn page_stats(&self, since_ms: i64) -> DbResult<Vec<PageStat>> {
        // SQLite has no median; the rows arrive grouped by page and sorted by
        // duration, so each page's median is its middle row.
        let rows = sqlx::query(
            "SELECT page, duration_ms, user_id FROM page_views
             WHERE entered_at_ms >= ? ORDER BY page, duration_ms",
        )
        .bind(since_ms)
        .fetch_all(&self.read_pool)
        .await?;

        let mut stats = Vec::new();
        let mut i = 0;
        while i < rows.len() {
            let page: String = rows[i].get("page");
            let mut durations: Vec<i64> = Vec::new();
            let mut users: HashSet<String> = HashSet::new();
            while i < rows.len() && rows[i].get::<String, _>("page") == page {
                durations.push(rows[i].get("duration_ms"));
                users.insert(rows[i].get("user_id"));
                i += 1;
            }
            stats.push(PageStat {
                page,
                views: durations.len() as i64,
                unique_users: users.len() as i64,
                median_duration_ms: durations[durations.len() / 2],
                total_duration_ms: durations.iter().sum(),
            });
        }
        stats.sort_by(|a, b| b.views.cmp(&a.views).then_with(|| a.page.cmp(&b.page)));
        Ok(stats)
    }

    pub async fn daily_stats(&self, since_ms: i64) -> DbResult<Vec<DailyStat>> {
        let rows = sqlx::query(
            "SELECT strftime('%Y-%m-%d', entered_at_ms / 1000, 'unixepoch') AS day,
                    COUNT(*) AS views, COUNT(DISTINCT user_id) AS unique_users
             FROM page_views WHERE entered_at_ms >= ? GROUP BY day ORDER BY day",
        )
        .bind(since_ms)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| DailyStat {
                day: r.get("day"),
                views: r.get("views"),
                unique_users: r.get("unique_users"),
            })
            .collect())
    }

    pub async fn auth_attempt_stats(&self, since: i64) -> DbResult<Vec<AuthAttemptStat>> {
        let rows = sqlx::query(
            "SELECT kind, platform, app_version, outcome, reason, COUNT(*) AS count
             FROM auth_attempts
             WHERE started_at >= ? AND NOT (outcome = 'started' AND started_at > ?)
             GROUP BY kind, platform, app_version, outcome, reason
             ORDER BY kind, platform, app_version, outcome, reason",
        )
        .bind(since)
        .bind(now_unix() - AUTH_ATTEMPT_IN_FLIGHT_SECS)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| AuthAttemptStat {
                kind: r.get("kind"),
                platform: r.get("platform"),
                app_version: r.get("app_version"),
                outcome: r.get("outcome"),
                reason: r.get("reason"),
                count: r.get("count"),
            })
            .collect())
    }

    pub async fn user_activity(&self, since_ms: i64) -> DbResult<Vec<UserActivity>> {
        let rows = sqlx::query(
            "SELECT u.username, COUNT(*) AS views, MAX(p.entered_at_ms) AS last_seen_ms
             FROM page_views p JOIN users u ON u.id = p.user_id
             WHERE p.entered_at_ms >= ?
             GROUP BY p.user_id ORDER BY last_seen_ms DESC LIMIT 200",
        )
        .bind(since_ms)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| UserActivity {
                username: r.get("username"),
                views: r.get("views"),
                last_seen_ms: r.get("last_seen_ms"),
            })
            .collect())
    }

    /// Distinct users with a page view since `since_ms`: the whole count,
    /// where `user_activity` lists only the most recent.
    pub async fn active_users(&self, since_ms: i64) -> DbResult<i64> {
        Ok(sqlx::query_scalar(
            "SELECT COUNT(DISTINCT user_id) FROM page_views WHERE entered_at_ms >= ?",
        )
        .bind(since_ms)
        .fetch_one(&self.read_pool)
        .await?)
    }

    /// The user's most recent views, newest first.
    pub async fn user_trail(&self, user_id: &str, limit: i64) -> DbResult<Vec<TrailEntry>> {
        let rows = sqlx::query(
            "SELECT page, entered_at_ms, duration_ms, app_session_id, platform, app_version
             FROM page_views WHERE user_id = ? ORDER BY entered_at_ms DESC, seq DESC LIMIT ?",
        )
        .bind(user_id)
        .bind(limit)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| TrailEntry {
                page: r.get("page"),
                entered_at_ms: r.get("entered_at_ms"),
                duration_ms: r.get("duration_ms"),
                app_session_id: r.get("app_session_id"),
                platform: r.get("platform"),
                app_version: r.get("app_version"),
            })
            .collect())
    }

    pub async fn total_users(&self) -> DbResult<i64> {
        Ok(sqlx::query_scalar("SELECT COUNT(*) FROM users")
            .fetch_one(&self.read_pool)
            .await?)
    }
}
