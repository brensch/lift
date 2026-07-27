use super::*;

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

    /// Rotate and return a fresh invite token for the user.
    pub async fn rotate_invite_token(&self, user_id: &str) -> DbResult<String> {
        let token = Uuid::new_v4().to_string();
        sqlx::query("UPDATE users_current SET invite_token = ? WHERE user_id = ?")
            .bind(&token)
            .bind(user_id)
            .execute(&self.write_pool)
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

    // ── Sessions ──

    /// Create a session row if it doesn't already exist. Idempotent.
    pub async fn create_session(&self, session_id: &str, created_by: &str) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO sessions (session_id, created_by, created_at) VALUES (?, ?, ?)
             ON CONFLICT(session_id) DO NOTHING",
        )
        .bind(session_id)
        .bind(created_by)
        .bind(now_unix())
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    // ── user_current_session: single source of truth for "am I in a group right now?" ──

    /// Upsert the caller's current session. Overwrites any prior membership (a user can
    /// only be in one session at a time).
    pub async fn set_user_current_session(&self, user_id: &str, session_id: &str) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO user_current_session (user_id, session_id, joined_at) VALUES (?, ?, ?)
             ON CONFLICT(user_id) DO UPDATE SET
               session_id = excluded.session_id,
               joined_at = excluded.joined_at",
        )
        .bind(user_id)
        .bind(session_id)
        .bind(now_unix())
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    pub async fn get_user_current_session(&self, user_id: &str) -> DbResult<Option<String>> {
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
        Ok(())
    }

    /// Return the live participant snapshots for this session, most-recently-updated
    /// first. This is the LIVE cache — rows are pruned when a member leaves (see
    /// [`prune_session_participant`]), so it reflects who is currently in the session.
    /// Durable "who was ever here" lives in `session_members`.
    pub async fn get_session_participants(
        &self,
        session_id: &str,
    ) -> DbResult<Vec<ParticipantStatus>> {
        let rows = sqlx::query(
            "SELECT participant_blob FROM session_participants_current WHERE session_id = ? ORDER BY updated_at DESC",
        )
        .bind(session_id)
        .fetch_all(&self.read_pool)
        .await?;
        let mut out = Vec::with_capacity(rows.len());
        for row in rows {
            let blob: Vec<u8> = row.get("participant_blob");
            out.push(ParticipantStatus::decode(blob.as_slice())?);
        }
        Ok(out)
    }

    /// Remove a member's live participant snapshot (on leave). Their durable
    /// `session_members` row is untouched, so history is preserved.
    pub async fn prune_session_participant(
        &self,
        session_id: &str,
        user_id: &str,
    ) -> DbResult<()> {
        sqlx::query(
            "DELETE FROM session_participants_current WHERE session_id = ? AND user_id = ?",
        )
        .bind(session_id)
        .bind(user_id)
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    // ── Durable roster (session_members) ──

    /// Record (or refresh) a user's membership in a session. Sets first_joined_at
    /// on first join; a rejoin clears left_at and bumps last_seen_at.
    pub async fn upsert_session_member(&self, session_id: &str, user_id: &str) -> DbResult<()> {
        let now = now_unix();
        sqlx::query(
            "INSERT INTO session_members (session_id, user_id, first_joined_at, last_seen_at, left_at)
             VALUES (?, ?, ?, ?, 0)
             ON CONFLICT(session_id, user_id) DO UPDATE SET
               last_seen_at = excluded.last_seen_at,
               left_at = 0",
        )
        .bind(session_id)
        .bind(user_id)
        .bind(now)
        .bind(now)
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    /// Mark a member as having left a session (durable row stays for history).
    pub async fn mark_session_member_left(&self, session_id: &str, user_id: &str) -> DbResult<()> {
        let now = now_unix();
        sqlx::query(
            "UPDATE session_members SET left_at = ?, last_seen_at = ?
             WHERE session_id = ? AND user_id = ?",
        )
        .bind(now)
        .bind(now)
        .bind(session_id)
        .bind(user_id)
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    /// Everyone the user has shared a session with, aggregated: (partner_id,
    /// distinct sessions together, most-recent shared-session time). Most recent first.
    pub async fn list_training_partners(
        &self,
        user_id: &str,
    ) -> DbResult<Vec<(String, i64, i64)>> {
        let rows = sqlx::query(
            "SELECT m2.user_id AS partner_id,
                    COUNT(DISTINCT m1.session_id) AS sessions_together,
                    MAX(s.created_at) AS last_trained_at
             FROM session_members m1
             JOIN session_members m2
               ON m2.session_id = m1.session_id AND m2.user_id != m1.user_id
             JOIN sessions s ON s.session_id = m1.session_id
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

    /// The sessions a user shared with one partner: (session_id, session time,
    /// caller_worked_out, partner_worked_out). Most recent first.
    pub async fn list_shared_sessions(
        &self,
        user_id: &str,
        partner_id: &str,
    ) -> DbResult<Vec<(String, i64, bool, bool)>> {
        let rows = sqlx::query(
            "SELECT m1.session_id AS session_id,
                    s.created_at AS trained_at,
                    EXISTS(SELECT 1 FROM workouts w
                           WHERE w.session_id = m1.session_id AND w.user_id = ?) AS caller_wo,
                    EXISTS(SELECT 1 FROM workouts w
                           WHERE w.session_id = m1.session_id AND w.user_id = ?) AS partner_wo
             FROM session_members m1
             JOIN session_members m2
               ON m2.session_id = m1.session_id AND m2.user_id = ?
             JOIN sessions s ON s.session_id = m1.session_id
             WHERE m1.user_id = ?
             ORDER BY s.created_at DESC",
        )
        .bind(user_id)
        .bind(partner_id)
        .bind(partner_id)
        .bind(user_id)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| {
                (
                    r.get::<String, _>("session_id"),
                    r.get::<i64, _>("trained_at"),
                    r.get::<i64, _>("caller_wo") != 0,
                    r.get::<i64, _>("partner_wo") != 0,
                )
            })
            .collect())
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
