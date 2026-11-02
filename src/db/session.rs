use super::*;
use std::collections::HashMap;

/// How long a group member can go without doing anything (no synced
/// write other than heart rate) before they're out of it. A workout writes
/// every set, so only an abandoned session or a join that never started gets
/// this old.
pub const SESSION_IDLE_SECONDS: i64 = 3 * 3600;

impl ServerDb {
    // ── Invite tokens ──

    /// Fetch the caller's invite token. Tokens are allocated on user creation, so this is
    /// effectively infallible for known users.
    pub async fn get_invite_token(&self, user_id: &str) -> DbResult<Option<String>> {
        let token: Option<String> =
            sqlx::query_scalar("SELECT invite_token FROM users_current WHERE user_id = ?")
                .bind(user_id)
                .fetch_optional(&self.read_pool)
                .await?;
        Ok(token)
    }

    /// Resolve an invite token back to a user id.
    pub async fn lookup_user_by_invite_token(
        &self,
        invite_token: &str,
    ) -> DbResult<Option<String>> {
        let user_id: Option<String> =
            sqlx::query_scalar("SELECT user_id FROM users_current WHERE invite_token = ?")
                .bind(invite_token)
                .fetch_optional(&self.read_pool)
                .await?;
        Ok(user_id)
    }

    // ── user_current_session: single source of truth for "am I in a group right now?" ──

    /// Upsert the caller's current session. Overwrites any prior membership (a user can
    /// only be in one session at a time).
    pub async fn set_user_current_session(&self, user_id: &str, session_id: &str) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO user_current_session (user_id, session_id) VALUES (?, ?)
             ON CONFLICT(user_id) DO UPDATE SET session_id = excluded.session_id",
        )
        .bind(user_id)
        .bind(session_id)
        .execute(&self.write_pool)
        .await?;
        self.notify(Change::Membership(user_id.to_string()));
        Ok(())
    }

    /// The session the user is in: their pointer, while they've been active
    /// in it (their live status refreshed — on joining and on every synced
    /// write other than heart rate) within [`SESSION_IDLE_SECONDS`]. Someone
    /// who joined and never started, or walked off without ending, drops out
    /// on their own.
    pub async fn get_user_current_session(&self, user_id: &str) -> DbResult<Option<String>> {
        let row: Option<String> = sqlx::query_scalar(
            "SELECT u.session_id FROM user_current_session u
             JOIN session_participants_current p
               ON p.session_id = u.session_id AND p.user_id = u.user_id
             WHERE u.user_id = ? AND p.updated_at > ?",
        )
        .bind(user_id)
        .bind(now_unix() - SESSION_IDLE_SECONDS)
        .fetch_optional(&self.read_pool)
        .await?;
        Ok(row)
    }

    /// The user's session pointer, idle or not: what leaving has to clean up
    /// (an idle member still has a roster row to stamp left).
    pub async fn get_user_session_pointer(&self, user_id: &str) -> DbResult<Option<String>> {
        let row: Option<String> =
            sqlx::query_scalar("SELECT session_id FROM user_current_session WHERE user_id = ?")
                .bind(user_id)
                .fetch_optional(&self.read_pool)
                .await?;
        Ok(row)
    }

    pub async fn clear_user_current_session(&self, user_id: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM user_current_session WHERE user_id = ?")
            .bind(user_id)
            .execute(&self.write_pool)
            .await?;
        self.notify(Change::Membership(user_id.to_string()));
        Ok(())
    }

    // ── Participant cache ──

    pub async fn upsert_session_participant(
        &self,
        session_id: &str,
        user_id: &str,
        status: &ParticipantStatus,
    ) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO session_participants_current (session_id, user_id, participant_blob, updated_at)
             VALUES (?, ?, ?, ?)
             ON CONFLICT(session_id, user_id) DO UPDATE SET
               participant_blob = excluded.participant_blob,
               updated_at = excluded.updated_at",
        )
        .bind(session_id)
        .bind(user_id)
        .bind(status.encode_to_vec())
        .bind(now_unix())
        .execute(&self.write_pool)
        .await?;
        self.notify(Change::Session(session_id.to_string()));
        Ok(())
    }

    /// Return the live participant snapshots for this session, most-recently-updated
    /// first. This is the LIVE cache — rows are pruned when a member leaves (see
    /// [`prune_session_participant`]) and ignored once idle past
    /// [`SESSION_IDLE_SECONDS`], so it reflects who is currently in the session.
    /// Durable "who was ever here" lives in `session_members`.
    pub async fn get_session_participants(
        &self,
        session_id: &str,
    ) -> DbResult<Vec<ParticipantStatus>> {
        let rows = sqlx::query(
            "SELECT participant_blob FROM session_participants_current
             WHERE session_id = ? AND updated_at > ? ORDER BY updated_at DESC",
        )
        .bind(session_id)
        .bind(now_unix() - SESSION_IDLE_SECONDS)
        .fetch_all(&self.read_pool)
        .await?;
        let mut out = Vec::with_capacity(rows.len());
        for row in rows {
            let blob: Vec<u8> = row.get("participant_blob");
            out.push(ParticipantStatus::decode(blob.as_slice())?);
        }
        Ok(out)
    }

    /// When the member left the session; 0 while they're in it.
    #[cfg(test)]
    pub async fn session_member_left_at(&self, session_id: &str, user_id: &str) -> DbResult<i64> {
        let left: i64 = sqlx::query_scalar(
            "SELECT left_at FROM session_members WHERE session_id = ? AND user_id = ?",
        )
        .bind(session_id)
        .bind(user_id)
        .fetch_one(&self.read_pool)
        .await?;
        Ok(left)
    }

    /// Push a member's last activity [seconds] into the past: idle tests.
    #[cfg(test)]
    pub async fn age_session_participant(&self, user_id: &str, seconds: i64) -> DbResult<()> {
        sqlx::query(
            "UPDATE session_participants_current SET updated_at = updated_at - ?
             WHERE user_id = ?",
        )
        .bind(seconds)
        .bind(user_id)
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    /// Remove a member's live participant snapshot (on leave). Their durable
    /// `session_members` row is untouched, so history is preserved.
    pub async fn prune_session_participant(&self, session_id: &str, user_id: &str) -> DbResult<()> {
        sqlx::query(
            "DELETE FROM session_participants_current WHERE session_id = ? AND user_id = ?",
        )
        .bind(session_id)
        .bind(user_id)
        .execute(&self.write_pool)
        .await?;
        self.notify(Change::Session(session_id.to_string()));
        Ok(())
    }

    // ── Durable roster (session_members) ──

    /// Record (or refresh) a user's membership in a session. Sets first_joined_at
    /// on first join; a rejoin clears left_at.
    pub async fn upsert_session_member(&self, session_id: &str, user_id: &str) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO session_members (session_id, user_id, first_joined_at, left_at)
             VALUES (?, ?, ?, 0)
             ON CONFLICT(session_id, user_id) DO UPDATE SET left_at = 0",
        )
        .bind(session_id)
        .bind(user_id)
        .bind(now_unix())
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    /// Mark a member as having left a session (durable row stays for history).
    pub async fn mark_session_member_left(&self, session_id: &str, user_id: &str) -> DbResult<()> {
        sqlx::query(
            "UPDATE session_members SET left_at = ?
             WHERE session_id = ? AND user_id = ? AND left_at = 0",
        )
        .bind(now_unix())
        .bind(session_id)
        .bind(user_id)
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    /// Every session the user has been in, mapped to the others who were in
    /// it, first to join first.
    pub async fn list_session_partner_ids(
        &self,
        user_id: &str,
    ) -> DbResult<HashMap<String, Vec<String>>> {
        let rows = sqlx::query(
            "SELECT m1.session_id, m2.user_id AS partner_id
             FROM session_members m1
             LEFT JOIN session_members m2
               ON m2.session_id = m1.session_id AND m2.user_id != m1.user_id
             WHERE m1.user_id = ?
             ORDER BY m2.first_joined_at ASC",
        )
        .bind(user_id)
        .fetch_all(&self.read_pool)
        .await?;
        let mut sessions: HashMap<String, Vec<String>> = HashMap::new();
        for row in rows {
            let partners = sessions.entry(row.get("session_id")).or_default();
            if let Some(partner_id) = row.get::<Option<String>, _>("partner_id") {
                partners.push(partner_id);
            }
        }
        Ok(sessions)
    }

    /// Everyone the user has shared a session with, aggregated: (partner_id,
    /// distinct sessions together, most-recent shared-session time). Most recent first.
    pub async fn list_training_partners(&self, user_id: &str) -> DbResult<Vec<(String, i64, i64)>> {
        let rows = sqlx::query(
            "SELECT m2.user_id AS partner_id,
                    COUNT(DISTINCT m1.session_id) AS sessions_together,
                    MAX(m1.first_joined_at) AS last_trained_at
             FROM session_members m1
             JOIN session_members m2
               ON m2.session_id = m1.session_id AND m2.user_id != m1.user_id
             WHERE m1.user_id = ?
             GROUP BY m2.user_id
             ORDER BY last_trained_at DESC",
        )
        .bind(user_id)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| {
                (
                    r.get::<String, _>("partner_id"),
                    r.get::<i64, _>("sessions_together"),
                    r.get::<i64, _>("last_trained_at"),
                )
            })
            .collect())
    }

    // ── Join requests (request / approve to train together) ──

    /// Create a pending join request from `from` to `to`, replacing any existing
    /// pending request in that direction (one live ask per direction).
    pub async fn create_join_request(
        &self,
        request_id: &str,
        from_user: &str,
        to_user: &str,
    ) -> DbResult<()> {
        sqlx::query("DELETE FROM join_requests WHERE from_user_id = ? AND to_user_id = ?")
            .bind(from_user)
            .bind(to_user)
            .execute(&self.write_pool)
            .await?;
        sqlx::query(
            "INSERT INTO join_requests (request_id, from_user_id, to_user_id, created_at)
             VALUES (?, ?, ?, ?)",
        )
        .bind(request_id)
        .bind(from_user)
        .bind(to_user)
        .bind(now_unix())
        .execute(&self.write_pool)
        .await?;
        self.notify(Change::JoinRequests(to_user.to_string()));
        Ok(())
    }

    /// Incoming pending requests for `to_user` newer than `since` (unix seconds):
    /// (request_id, from_user_id, created_at), most recent first.
    pub async fn list_incoming_join_requests(
        &self,
        to_user: &str,
        since: i64,
    ) -> DbResult<Vec<(String, String, i64)>> {
        let rows = sqlx::query(
            "SELECT request_id, from_user_id, created_at FROM join_requests
             WHERE to_user_id = ? AND created_at >= ?
             ORDER BY created_at DESC",
        )
        .bind(to_user)
        .bind(since)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| {
                (
                    r.get::<String, _>("request_id"),
                    r.get::<String, _>("from_user_id"),
                    r.get::<i64, _>("created_at"),
                )
            })
            .collect())
    }

    /// A request's (from_user_id, to_user_id), if it was made at or after
    /// `since` (unix seconds).
    pub async fn get_join_request(
        &self,
        request_id: &str,
        since: i64,
    ) -> DbResult<Option<(String, String)>> {
        let row = sqlx::query(
            "SELECT from_user_id, to_user_id FROM join_requests
             WHERE request_id = ? AND created_at >= ?",
        )
        .bind(request_id)
        .bind(since)
        .fetch_optional(&self.read_pool)
        .await?;
        Ok(row.map(|r| {
            (
                r.get::<String, _>("from_user_id"),
                r.get::<String, _>("to_user_id"),
            )
        }))
    }

    /// Push a join request's creation [seconds] into the past: expiry tests.
    #[cfg(test)]
    pub async fn age_join_request(&self, request_id: &str, seconds: i64) -> DbResult<()> {
        sqlx::query("UPDATE join_requests SET created_at = created_at - ? WHERE request_id = ?")
            .bind(seconds)
            .bind(request_id)
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }

    pub async fn delete_join_request(&self, request_id: &str) -> DbResult<()> {
        let to_user: Option<String> = sqlx::query_scalar(
            "DELETE FROM join_requests WHERE request_id = ? RETURNING to_user_id",
        )
        .bind(request_id)
        .fetch_optional(&self.write_pool)
        .await?;
        if let Some(to_user) = to_user {
            self.notify(Change::JoinRequests(to_user));
        }
        Ok(())
    }

    /// Whether two users have ever shared a session (used to gate partner re-pair).
    pub async fn have_trained_together(&self, a: &str, b: &str) -> DbResult<bool> {
        let n: i64 = sqlx::query_scalar(
            "SELECT COUNT(*) FROM session_members m1
             JOIN session_members m2 ON m2.session_id = m1.session_id
             WHERE m1.user_id = ? AND m2.user_id = ?",
        )
        .bind(a)
        .bind(b)
        .fetch_one(&self.read_pool)
        .await?;
        Ok(n > 0)
    }
}
