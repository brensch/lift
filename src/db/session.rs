use super::*;

impl ServerDb {
    // ── Session ──

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

    pub async fn remove_session_participant(
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

    pub async fn get_current_session_id_for_user(&self, user_id: &str) -> DbResult<Option<String>> {
        let session_id: Option<String> = sqlx::query_scalar(
            "SELECT session_id FROM session_memberships WHERE user_id = ? AND left_at = 0 ORDER BY joined_at DESC LIMIT 1",
        )
        .bind(user_id)
        .fetch_optional(&self.read_pool)
        .await?;
        Ok(session_id)
    }

    pub async fn join_session(&self, user_id: &str, session_id: &str) -> DbResult<()> {
        let now = now_unix();
        let mut tx = self.write_pool.begin().await?;
        sqlx::query(
            "UPDATE session_memberships SET left_at = ? WHERE user_id = ? AND left_at = 0 AND session_id != ?",
        )
        .bind(now)
        .bind(user_id)
        .bind(session_id)
        .execute(&mut *tx)
        .await?;
        sqlx::query(
            "INSERT INTO session_memberships (membership_id, session_id, user_id, joined_at, left_at)
             SELECT ?, ?, ?, ?, 0
             WHERE NOT EXISTS (
                SELECT 1 FROM session_memberships WHERE user_id = ? AND session_id = ? AND left_at = 0
             )",
        )
        .bind(Uuid::new_v4().to_string())
        .bind(session_id)
        .bind(user_id)
        .bind(now)
        .bind(user_id)
        .bind(session_id)
        .execute(&mut *tx)
        .await?;
        tx.commit().await?;
        Ok(())
    }

    pub async fn leave_session(&self, user_id: &str, session_id: &str) -> DbResult<()> {
        sqlx::query(
            "UPDATE session_memberships SET left_at = ? WHERE user_id = ? AND session_id = ? AND left_at = 0",
        )
        .bind(now_unix())
        .bind(user_id)
        .bind(session_id)
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

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
