use super::*;
use schlift::workout::v1::UserMessageSurface;

impl ServerDb {
    // ── Schedule/Program/Settings/Drafts (blob caches, unchanged) ──

    pub async fn put_schedule_cache(
        &self,
        user_id: &str,
        response: &GetProposedWorkoutScheduleResponse,
    ) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO proposed_schedule_cache (user_id, response_blob, updated_at)
             VALUES (?, ?, ?)
             ON CONFLICT(user_id) DO UPDATE SET response_blob = excluded.response_blob, updated_at = excluded.updated_at",
        )
        .bind(user_id)
        .bind(response.encode_to_vec())
        .bind(now_unix())
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    pub async fn put_setting(
        &self,
        user_id: &str,
        setting_type: &str,
        setting: &UserSetting,
    ) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO user_settings_current (user_id, setting_type, setting_blob, updated_at)
             VALUES (?, ?, ?, ?)
             ON CONFLICT(user_id, setting_type) DO UPDATE SET setting_blob = excluded.setting_blob, updated_at = excluded.updated_at",
        )
        .bind(user_id)
        .bind(setting_type)
        .bind(setting.encode_to_vec())
        .bind(now_unix())
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    pub async fn get_settings(&self, user_id: &str) -> DbResult<Vec<UserSetting>> {
        let rows = sqlx::query(
            "SELECT setting_blob FROM user_settings_current WHERE user_id = ? ORDER BY setting_type ASC",
        )
        .bind(user_id)
        .fetch_all(&self.read_pool)
        .await?;
        let mut out = Vec::with_capacity(rows.len());
        for row in rows {
            let blob: Vec<u8> = row.get("setting_blob");
            out.push(UserSetting::decode(blob.as_slice())?);
        }
        Ok(out)
    }

    pub async fn put_program_state(
        &self,
        user_id: &str,
        response: &GetActiveTrainingProgramStateResponse,
    ) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO training_program_state_latest (user_id, response_blob, updated_at)
             VALUES (?, ?, ?)
             ON CONFLICT(user_id) DO UPDATE SET response_blob = excluded.response_blob, updated_at = excluded.updated_at",
        )
        .bind(user_id)
        .bind(response.encode_to_vec())
        .bind(now_unix())
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    pub async fn get_program_state(
        &self,
        user_id: &str,
    ) -> DbResult<Option<GetActiveTrainingProgramStateResponse>> {
        let blob: Option<Vec<u8>> = sqlx::query_scalar(
            "SELECT response_blob FROM training_program_state_latest WHERE user_id = ?",
        )
        .bind(user_id)
        .fetch_optional(&self.read_pool)
        .await?;
        match blob {
            Some(blob) => Ok(Some(GetActiveTrainingProgramStateResponse::decode(
                blob.as_slice(),
            )?)),
            None => Ok(None),
        }
    }

    pub async fn put_workout_draft(&self, user_id: &str, draft: &WorkoutDraft) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO workout_drafts_current (user_id, draft_blob, updated_at)
             VALUES (?, ?, ?)
             ON CONFLICT(user_id) DO UPDATE SET draft_blob = excluded.draft_blob, updated_at = excluded.updated_at",
        )
        .bind(user_id)
        .bind(draft.encode_to_vec())
        .bind(now_unix())
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    pub async fn get_workout_draft(&self, user_id: &str) -> DbResult<Option<WorkoutDraft>> {
        let blob: Option<Vec<u8>> =
            sqlx::query_scalar("SELECT draft_blob FROM workout_drafts_current WHERE user_id = ?")
                .bind(user_id)
                .fetch_optional(&self.read_pool)
                .await?;
        match blob {
            Some(blob) => Ok(Some(WorkoutDraft::decode(blob.as_slice())?)),
            None => Ok(None),
        }
    }

    pub async fn clear_workout_draft(&self, user_id: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM workout_drafts_current WHERE user_id = ?")
            .bind(user_id)
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }

    pub async fn upsert_user_message_events(
        &self,
        user_id: &str,
        messages: &[UserMessage],
    ) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;
        for message in messages {
            sqlx::query(
                "INSERT INTO user_message_events
                 (user_id, message_key, surface, workout_id, exercise_group_id, exercise, slot_key, dismissed_at, created_at, updated_at, message_blob)
                 VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?)
                 ON CONFLICT(user_id, message_key) DO UPDATE SET
                   surface = excluded.surface,
                   workout_id = excluded.workout_id,
                   exercise_group_id = excluded.exercise_group_id,
                   exercise = excluded.exercise,
                   slot_key = excluded.slot_key,
                   dismissed_at = 0,
                   created_at = excluded.created_at,
                   updated_at = excluded.updated_at,
                   message_blob = excluded.message_blob",
            )
            .bind(user_id)
            .bind(&message.message_key)
            .bind(message.surface)
            .bind(&message.workout_id)
            .bind(&message.exercise_group_id)
            .bind(message.exercise)
            .bind(&message.slot_key)
            .bind(message.created_at)
            .bind(message.updated_at)
            .bind(message.encode_to_vec())
            .execute(&mut *tx)
            .await?;
        }
        tx.commit().await?;
        Ok(())
    }

    pub async fn get_workout_user_messages(
        &self,
        user_id: &str,
        workout_id: &str,
        include_dismissed: bool,
    ) -> DbResult<Vec<UserMessage>> {
        let rows = if include_dismissed {
            sqlx::query(
                "SELECT message_blob FROM user_message_events
                 WHERE user_id = ? AND workout_id = ?
                 ORDER BY updated_at DESC",
            )
            .bind(user_id)
            .bind(workout_id)
            .fetch_all(&self.read_pool)
            .await?
        } else {
            sqlx::query(
                "SELECT message_blob FROM user_message_events
                 WHERE user_id = ? AND workout_id = ? AND dismissed_at = 0
                 ORDER BY updated_at DESC",
            )
            .bind(user_id)
            .bind(workout_id)
            .fetch_all(&self.read_pool)
            .await?
        };
        let mut out = Vec::new();
        for row in rows {
            let blob: Vec<u8> = row.get("message_blob");
            out.push(UserMessage::decode(blob.as_slice())?);
        }
        Ok(out)
    }

    pub async fn get_pending_workout_briefing_messages(
        &self,
        user_id: &str,
    ) -> DbResult<Vec<UserMessage>> {
        let rows = sqlx::query(
            "SELECT message_blob FROM user_message_events
             WHERE user_id = ? AND workout_id = '' AND dismissed_at = 0 AND surface = ?
             ORDER BY updated_at DESC",
        )
        .bind(user_id)
        .bind(UserMessageSurface::WorkoutBriefing as i32)
        .fetch_all(&self.read_pool)
        .await?;
        let mut out = Vec::new();
        for row in rows {
            let blob: Vec<u8> = row.get("message_blob");
            out.push(UserMessage::decode(blob.as_slice())?);
        }
        Ok(out)
    }

    pub async fn dismiss_user_messages(
        &self,
        user_id: &str,
        message_keys: &[String],
    ) -> DbResult<Vec<String>> {
        let mut dismissed = Vec::new();
        let mut tx = self.write_pool.begin().await?;
        for key in message_keys {
            let result = sqlx::query(
                "UPDATE user_message_events
                 SET dismissed_at = ?, updated_at = ?
                 WHERE user_id = ? AND message_key = ? AND dismissed_at = 0",
            )
            .bind(now_unix())
            .bind(now_unix())
            .bind(user_id)
            .bind(key)
            .execute(&mut *tx)
            .await?;
            if result.rows_affected() > 0 {
                dismissed.push(key.clone());
            }
        }
        tx.commit().await?;
        Ok(dismissed)
    }

    // ── Events & Heart Rate ──

    pub async fn append_workout_events(
        &self,
        user_id: &str,
        workout_id: &str,
        events: &[(String, i64, i32, Vec<u8>)],
    ) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;
        for (event_id, recorded_at, event_type, payload) in events {
            sqlx::query(
                "INSERT INTO workout_events (event_id, user_id, workout_id, recorded_at, event_type, payload) VALUES (?, ?, ?, ?, ?, ?)",
            )
            .bind(event_id)
            .bind(user_id)
            .bind(workout_id)
            .bind(recorded_at)
            .bind(event_type)
            .bind(payload)
            .execute(&mut *tx)
            .await?;
        }
        tx.commit().await?;
        Ok(())
    }

    pub async fn insert_heart_rate_samples(
        &self,
        user_id: &str,
        workout_id: &str,
        samples: &[WorkoutHeartRatePoint],
    ) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;
        for sample in samples {
            sqlx::query(
                "INSERT INTO workout_heart_rate_samples (id, user_id, workout_id, sampled_at, bpm, availability) VALUES (?, ?, ?, ?, ?, ?)",
            )
            .bind(Uuid::new_v4().to_string())
            .bind(user_id)
            .bind(workout_id)
            .bind(sample.sampled_at)
            .bind(sample.bpm as f64)
            .bind(sample.availability)
            .execute(&mut *tx)
            .await?;
        }
        tx.commit().await?;
        Ok(())
    }

    pub async fn get_workout_heart_rate(
        &self,
        user_id: &str,
        workout_id: &str,
    ) -> DbResult<Vec<WorkoutHeartRatePoint>> {
        let rows = sqlx::query(
            "SELECT sampled_at, bpm, availability FROM workout_heart_rate_samples
             WHERE user_id = ? AND workout_id = ? ORDER BY sampled_at ASC",
        )
        .bind(user_id)
        .bind(workout_id)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| WorkoutHeartRatePoint {
                sampled_at: r.get("sampled_at"),
                bpm: r.get::<f64, _>("bpm") as f32,
                availability: r.get("availability"),
            })
            .collect())
    }
}
