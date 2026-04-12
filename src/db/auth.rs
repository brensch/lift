use super::*;

impl ServerDb {
    // ── Auth ──

    fn default_profile_emoji() -> &'static str {
        "💪"
    }

    fn default_profile_color_hex() -> &'static str {
        "#6B7280"
    }

    fn normalize_profile_emoji(value: &str) -> String {
        let trimmed = value.trim();
        if trimmed.is_empty() {
            Self::default_profile_emoji().to_string()
        } else {
            trimmed.chars().take(8).collect()
        }
    }

    fn normalize_profile_color_hex(value: &str) -> String {
        let trimmed = value.trim();
        let hex = trimmed.strip_prefix('#').unwrap_or(trimmed);
        if hex.len() == 6 && hex.chars().all(|c| c.is_ascii_hexdigit()) {
            format!("#{}", hex.to_ascii_uppercase())
        } else {
            Self::default_profile_color_hex().to_string()
        }
    }

    pub async fn create_user_with_id(
        &self,
        user_id: &str,
        username: &str,
    ) -> DbResult<schlift::workout::v1::User> {
        let user = schlift::workout::v1::User {
            id: user_id.to_string(),
            name: username.trim().to_string(),
            created_at: now_unix(),
            profile_emoji: Self::default_profile_emoji().to_string(),
            profile_color_hex: Self::default_profile_color_hex().to_string(),
            body_weight_kg: 0.0,
        };
        let normalized = username.trim().to_lowercase();
        sqlx::query("INSERT INTO users_current (user_id, user_blob, username_ci) VALUES (?, ?, ?)")
            .bind(&user.id)
            .bind(user.encode_to_vec())
            .bind(&normalized)
            .execute(&self.write_pool)
            .await?;
        Ok(user)
    }

    pub async fn get_or_create_user_with_auth_session(
        &self,
        username: &str,
    ) -> DbResult<(schlift::workout::v1::User, String)> {
        let mut tx = self.write_pool.begin().await?;
        let normalized = username.trim().to_lowercase();
        let existing: Option<Vec<u8>> =
            sqlx::query_scalar("SELECT user_blob FROM users_current WHERE username_ci = ?")
                .bind(&normalized)
                .fetch_optional(&mut *tx)
                .await?;
        let user = match existing {
            Some(blob) => schlift::workout::v1::User::decode(blob.as_slice())?,
            None => {
                let user = schlift::workout::v1::User {
                    id: Uuid::new_v4().to_string(),
                    name: username.trim().to_string(),
                    created_at: now_unix(),
                    profile_emoji: Self::default_profile_emoji().to_string(),
                    profile_color_hex: Self::default_profile_color_hex().to_string(),
                    body_weight_kg: 0.0,
                };
                sqlx::query(
                    "INSERT INTO users_current (user_id, user_blob, username_ci) VALUES (?, ?, ?)",
                )
                .bind(&user.id)
                .bind(user.encode_to_vec())
                .bind(&normalized)
                .execute(&mut *tx)
                .await?;
                user
            }
        };
        let token = Uuid::new_v4().to_string();
        sqlx::query("INSERT INTO auth_sessions (token, user_id, expires_at) VALUES (?, ?, ?)")
            .bind(&token)
            .bind(&user.id)
            .bind(now_unix() + 30 * 24 * 60 * 60)
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
        Ok((user, token))
    }

    pub async fn create_auth_session(&self, user_id: &str) -> DbResult<String> {
        let token = Uuid::new_v4().to_string();
        sqlx::query("INSERT INTO auth_sessions (token, user_id, expires_at) VALUES (?, ?, ?)")
            .bind(&token)
            .bind(user_id)
            .bind(now_unix() + 30 * 24 * 60 * 60)
            .execute(&self.write_pool)
            .await?;
        Ok(token)
    }

    pub async fn validate_auth_session(&self, token: &str) -> DbResult<Option<String>> {
        let now = now_unix();
        let user_id: Option<String> = sqlx::query_scalar(
            "SELECT user_id FROM auth_sessions WHERE token = ? AND expires_at > ?",
        )
        .bind(token)
        .bind(now)
        .fetch_optional(&self.read_pool)
        .await?;
        Ok(user_id)
    }

    pub async fn delete_auth_session(&self, token: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM auth_sessions WHERE token = ?")
            .bind(token)
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }

    pub async fn get_user(&self, user_id: &str) -> DbResult<Option<schlift::workout::v1::User>> {
        let blob: Option<Vec<u8>> =
            sqlx::query_scalar("SELECT user_blob FROM users_current WHERE user_id = ?")
                .bind(user_id)
                .fetch_optional(&self.read_pool)
                .await?;
        match blob {
            Some(blob) => Ok(Some(schlift::workout::v1::User::decode(blob.as_slice())?)),
            None => Ok(None),
        }
    }

    pub async fn update_user_profile(
        &self,
        user_id: &str,
        profile_emoji: &str,
        profile_color_hex: &str,
        body_weight_kg: f32,
    ) -> DbResult<Option<schlift::workout::v1::User>> {
        let existing = self.get_user(user_id).await?;
        let Some(mut user) = existing else {
            return Ok(None);
        };

        if !profile_emoji.trim().is_empty() {
            user.profile_emoji = Self::normalize_profile_emoji(profile_emoji);
        }
        if !profile_color_hex.trim().is_empty() {
            user.profile_color_hex = Self::normalize_profile_color_hex(profile_color_hex);
        }
        if body_weight_kg > 0.0 {
            user.body_weight_kg = body_weight_kg;
        }

        sqlx::query("UPDATE users_current SET user_blob = ? WHERE user_id = ?")
            .bind(user.encode_to_vec())
            .bind(user_id)
            .execute(&self.write_pool)
            .await?;

        Ok(Some(user))
    }

    pub async fn get_user_by_name(
        &self,
        username: &str,
    ) -> DbResult<Option<schlift::workout::v1::User>> {
        let normalized = username.trim().to_lowercase();
        let blob: Option<Vec<u8>> =
            sqlx::query_scalar("SELECT user_blob FROM users_current WHERE username_ci = ?")
                .bind(&normalized)
                .fetch_optional(&self.read_pool)
                .await?;
        match blob {
            Some(blob) => Ok(Some(schlift::workout::v1::User::decode(blob.as_slice())?)),
            None => Ok(None),
        }
    }

    pub async fn store_credential(
        &self,
        credential_id: &str,
        user_id: &str,
        credential_json: &str,
        created_at_ip: Option<&str>,
    ) -> DbResult<()> {
        sqlx::query(
            "INSERT OR REPLACE INTO passkey_credentials (credential_id, user_id, credential_json, created_at, created_at_ip) VALUES (?, ?, ?, ?, ?)",
        )
        .bind(credential_id)
        .bind(user_id)
        .bind(credential_json)
        .bind(now_unix())
        .bind(created_at_ip)
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    pub async fn delete_credential(&self, user_id: &str, credential_id: &str) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;
        let count: i64 =
            sqlx::query_scalar("SELECT COUNT(*) FROM passkey_credentials WHERE user_id = ?")
                .bind(user_id)
                .fetch_one(&mut *tx)
                .await?;
        if count <= 1 {
            return Err("Cannot delete the last passkey".into());
        }
        sqlx::query("DELETE FROM passkey_credentials WHERE user_id = ? AND credential_id = ?")
            .bind(user_id)
            .bind(credential_id)
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
        Ok(())
    }

    pub async fn update_credential_json(
        &self,
        credential_id: &str,
        new_json: &str,
    ) -> DbResult<()> {
        sqlx::query("UPDATE passkey_credentials SET credential_json = ? WHERE credential_id = ?")
            .bind(new_json)
            .bind(credential_id)
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }

    pub async fn get_credentials_for_user(&self, user_id: &str) -> DbResult<Vec<String>> {
        let rows =
            sqlx::query_scalar("SELECT credential_json FROM passkey_credentials WHERE user_id = ?")
                .bind(user_id)
                .fetch_all(&self.read_pool)
                .await?;
        Ok(rows)
    }

    pub async fn list_passkey_metadata(
        &self,
        user_id: &str,
    ) -> DbResult<Vec<(String, i64, String, Option<String>)>> {
        let rows = sqlx::query_as(
            "SELECT credential_id, created_at, credential_json, created_at_ip FROM passkey_credentials WHERE user_id = ? ORDER BY created_at DESC",
        )
        .bind(user_id)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows)
    }

    pub async fn delete_user_account_and_data(&self, user_id: &str) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;
        sqlx::query("DELETE FROM auth_sessions WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM passkey_credentials WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM session_participants_current WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM session_memberships WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM workout_heart_rate_samples WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM completed_sets WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM proposed_sets WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM exercise_groups WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM workouts WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM active_workout_current WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM proposed_schedule_cache WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM training_program_state_latest WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM user_settings_current WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM workout_drafts_current WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM users_current WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
        Ok(())
    }
}
