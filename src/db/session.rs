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

    /// Return all participant snapshots recorded in this session, ordered by most recently updated.
    /// Blobs are permanent — rows are never deleted, so finished participants remain visible
    /// to peers still in the session and surface in historical views.
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
}
