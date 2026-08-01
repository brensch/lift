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
        let invite_token = Uuid::new_v4().to_string();
        sqlx::query(
            "INSERT INTO users_current (user_id, user_blob, username_ci, invite_token) VALUES (?, ?, ?, ?)",
        )
        .bind(&user.id)
        .bind(user.encode_to_vec())
        .bind(&normalized)
        .bind(&invite_token)
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
                let invite_token = Uuid::new_v4().to_string();
                sqlx::query(
                    "INSERT INTO users_current (user_id, user_blob, username_ci, invite_token) VALUES (?, ?, ?, ?)",
                )
                .bind(&user.id)
                .bind(user.encode_to_vec())
                .bind(&normalized)
                .bind(&invite_token)
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
        // v2 training-model tables (t_*). Dormant today but user-keyed, so wipe
        // them here too — a new user-keyed table that skips this orphans rows.
        for table in [
            "t_workouts",
            "t_blocks",
            "t_sets",
            "t_entries",
            "t_progression",
        ] {
            sqlx::query(&format!("DELETE FROM {table} WHERE user_id = ?"))
                .bind(user_id)
                .execute(&mut *tx)
                .await?;
        }
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
        sqlx::query("DELETE FROM user_current_session WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM session_members WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM join_requests WHERE from_user_id = ? OR to_user_id = ?")
            .bind(user_id)
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
        sqlx::query("DELETE FROM program_progression_applied WHERE user_id = ?")
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
        sqlx::query("DELETE FROM workout_events WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM profile_exercise_groups WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM user_message_events WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        // Training model v2 tables.
        for table in [
            "t_entries",
            "t_sets",
            "t_blocks",
            "t_workouts",
            "t_progression",
        ] {
            sqlx::query(&format!("DELETE FROM {table} WHERE user_id = ?"))
                .bind(user_id)
                .execute(&mut *tx)
                .await?;
        }
        sqlx::query("DELETE FROM users_current WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
        Ok(())
    }
}

#[cfg(test)]
mod account_deletion_tests {
    use crate::db::ServerDb;
    use sqlx::Row;
    use uuid::Uuid;

    async fn temp_db() -> ServerDb {
        let dir = std::env::temp_dir().join(format!("lift-delete-test-{}", Uuid::new_v4()));
        ServerDb::new_in_dir(&dir).await.unwrap()
    }

    /// Every table in the schema carrying a `user_id` column, discovered from
    /// SQLite itself rather than hardcoded, so a newly added table shows up here
    /// automatically.
    async fn tables_with_user_id(db: &ServerDb) -> Vec<String> {
        let table_names: Vec<String> = sqlx::query(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
        )
        .fetch_all(&db.read_pool)
        .await
        .unwrap()
        .into_iter()
        .map(|r| r.get::<String, _>("name"))
        .collect();

        let mut out = Vec::new();
        for table in table_names {
            let has_user_id = sqlx::query(&format!("PRAGMA table_info({table})"))
                .fetch_all(&db.read_pool)
                .await
                .unwrap()
                .into_iter()
                .any(|c| c.get::<String, _>("name") == "user_id");
            if has_user_id {
                out.push(table);
            }
        }
        out.sort();
        out
    }

    /// Write one row for `user_id` into every user-keyed table, using raw SQL so
    /// the test does not depend on which write helpers happen to exist.
    ///
    /// Every id is derived from `user_id` so two users can be seeded into the
    /// same database without colliding on primary keys.
    async fn seed_all_tables(db: &ServerDb, user_id: &str) {
        let u = user_id;
        let stmts: Vec<(&str, String)> = vec![
            ("users_current", format!("(user_id, user_blob, username_ci, invite_token) VALUES (?, x'00', '{u}-name', '{u}-invite')")),
            ("auth_sessions", format!("(token, user_id, expires_at) VALUES ('{u}-tok', ?, 9999999999)")),
            ("passkey_credentials", format!("(credential_id, user_id, credential_json, created_at) VALUES ('{u}-cred', ?, '{{}}', 1)")),
            ("workouts", format!("(id, user_id, name, start_time) VALUES ('{u}-w1', ?, 'W', 1)")),
            ("exercise_groups", format!("(id, user_id, workout_id, name, workout_order) VALUES ('{u}-g1', ?, '{u}-w1', 'G', 0)")),
            ("proposed_sets", format!("(id, user_id, workout_id, exercise_group_id, workout_order, exercise, target_reps, target_weight) VALUES ('{u}-p1', ?, '{u}-w1', '{u}-g1', 0, 1, 5, 100.0)")),
            ("completed_sets", format!("(id, user_id, workout_id, proposed_set_id, actual_reps, actual_weight, started_at) VALUES ('{u}-c1', ?, '{u}-w1', '{u}-p1', 5, 100.0, 1)")),
            ("active_workout_current", format!("(user_id, workout_id) VALUES (?, '{u}-w1')")),
            ("user_current_session", format!("(user_id, session_id, joined_at) VALUES (?, '{u}-s1', 1)")),
            ("session_participants_current", format!("(session_id, user_id, participant_blob, updated_at) VALUES ('{u}-s1', ?, x'00', 1)")),
            ("session_members", format!("(session_id, user_id, first_joined_at, last_seen_at, left_at) VALUES ('{u}-s1', ?, 1, 1, 0)")),
            ("workout_events", format!("(event_id, user_id, workout_id, recorded_at, event_type, payload) VALUES ('{u}-e1', ?, '{u}-w1', 1, 2, x'00')")),
            ("workout_heart_rate_samples", format!("(id, user_id, workout_id, sampled_at, bpm) VALUES ('{u}-h1', ?, '{u}-w1', 1, 120.0)")),
            ("proposed_schedule_cache", "(user_id, response_blob, updated_at) VALUES (?, x'00', 1)".to_string()),
            ("training_program_state_latest", "(user_id, response_blob, updated_at) VALUES (?, x'00', 1)".to_string()),
            ("program_progression_applied", format!("(workout_id, user_id, applied_at) VALUES ('{u}-w1', ?, 1)")),
            ("user_settings_current", "(user_id, setting_type, setting_blob, updated_at) VALUES (?, 'units', x'00', 1)".to_string()),
            ("workout_drafts_current", "(user_id, draft_blob, updated_at) VALUES (?, x'00', 1)".to_string()),
            ("profile_exercise_groups", format!("(id, user_id, name, created_at, updated_at) VALUES ('{u}-pg1', ?, 'G', 1, 1)")),
            ("user_message_events", "(user_id, message_key, created_at, updated_at, message_blob) VALUES (?, 'k', 1, 1, x'00')".to_string()),
            // Training model v2. Ids derived from user_id so two users don't collide.
            ("t_workouts", format!("(id, user_id, name, start_time) VALUES ('{u}-tw', ?, 'W', 1)")),
            ("t_blocks", format!("(id, workout_id, user_id, ord) VALUES ('{u}-tb', '{u}-tw', ?, 0)")),
            ("t_sets", format!("(id, workout_id, block_id, user_id, ord, exercise, role) VALUES ('{u}-ts', '{u}-tw', '{u}-tb', ?, 0, 1, 1)")),
            ("t_entries", format!("(entry_id, set_id, workout_id, user_id, performed_at, recorded_at) VALUES ('{u}-te', '{u}-ts', '{u}-tw', ?, 1, 1)")),
            ("t_progression", format!("(id, user_id, workout_id, at) VALUES ('{u}-tp', ?, '{u}-tw', 1)")),
        ];

        for (table, cols) in &stmts {
            sqlx::query(&format!("INSERT INTO {table} {cols}"))
                .bind(user_id)
                .execute(&db.write_pool)
                .await
                .unwrap_or_else(|e| panic!("failed seeding {table}: {e}"));
        }
    }

    async fn row_count(db: &ServerDb, table: &str, user_id: &str) -> i64 {
        sqlx::query_scalar(&format!("SELECT COUNT(*) FROM {table} WHERE user_id = ?"))
            .bind(user_id)
            .fetch_one(&db.read_pool)
            .await
            .unwrap()
    }

    /// `delete_user_account_and_data` lists its tables by hand, and has already
    /// missed some (workout_events, profile_exercise_groups, user_message_events
    /// were all left behind). This seeds every user-keyed table, deletes the
    /// account, and fails naming any table that still holds rows — so adding a
    /// table without updating the delete path fails here rather than silently
    /// retaining personal data after an account deletion.
    #[tokio::test]
    async fn deleting_an_account_clears_every_user_keyed_table() {
        let db = temp_db().await;
        let user_id = "user-under-test";

        seed_all_tables(&db, user_id).await;

        let tables = tables_with_user_id(&db).await;
        assert!(!tables.is_empty(), "expected to discover user-keyed tables");

        // Sanity check: the seed actually wrote something everywhere.
        for table in &tables {
            assert!(
                row_count(&db, table, user_id).await > 0,
                "test seed missed {table} — extend seed_all_tables"
            );
        }

        db.delete_user_account_and_data(user_id).await.unwrap();

        let mut leftovers = Vec::new();
        for table in &tables {
            let remaining = row_count(&db, table, user_id).await;
            if remaining > 0 {
                leftovers.push(format!("{table} ({remaining} rows)"));
            }
        }

        assert!(
            leftovers.is_empty(),
            "account deletion left personal data behind. Add these tables to \
             delete_user_account_and_data in src/db/auth.rs:\n  {}",
            leftovers.join("\n  ")
        );
    }

    /// Deleting one account must not touch anyone else's rows.
    #[tokio::test]
    async fn deleting_an_account_leaves_other_users_untouched() {
        let db = temp_db().await;
        seed_all_tables(&db, "victim").await;
        seed_all_tables(&db, "bystander").await;

        db.delete_user_account_and_data("victim").await.unwrap();

        for table in tables_with_user_id(&db).await {
            assert_eq!(
                row_count(&db, &table, "victim").await,
                0,
                "{table} still holds the deleted user's rows"
            );
            assert!(
                row_count(&db, &table, "bystander").await > 0,
                "{table} lost an unrelated user's rows"
            );
        }
    }
}
