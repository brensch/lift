use super::*;

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
