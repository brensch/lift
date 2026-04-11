use super::*;

impl ServerDb {
    // ── Auth ──

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
}
