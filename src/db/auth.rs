use super::migrate::token_hash;
use super::*;
use schlift::workout::v1::User;

/// How long a login lasts.
const LOGIN_SECONDS: i64 = 30 * 24 * 60 * 60;

const USER_COLUMNS: &str = "id, username, created_at, emoji, color_hex, body_weight_kg";

fn user_from(row: &sqlx::sqlite::SqliteRow) -> User {
    User {
        id: row.get("id"),
        name: row.get("username"),
        created_at: row.get("created_at"),
        profile_emoji: row.get("emoji"),
        profile_color_hex: row.get("color_hex"),
        body_weight_kg: row.get::<f64, _>("body_weight_kg") as f32,
    }
}

fn default_profile_emoji() -> &'static str {
    "💪"
}

fn default_profile_color_hex() -> &'static str {
    "#6B7280"
}

fn normalize_profile_emoji(value: &str) -> String {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        default_profile_emoji().to_string()
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
        default_profile_color_hex().to_string()
    }
}

/// A new user, with the default profile.
async fn insert_user(
    conn: &mut sqlx::SqliteConnection,
    user_id: &str,
    username: &str,
) -> DbResult<User> {
    let user = User {
        id: user_id.to_string(),
        name: username.trim().to_string(),
        created_at: now_unix(),
        profile_emoji: default_profile_emoji().to_string(),
        profile_color_hex: default_profile_color_hex().to_string(),
        body_weight_kg: 0.0,
    };
    sqlx::query(
        "INSERT INTO users (id, username, invite_token, created_at, emoji, color_hex)
         VALUES (?, ?, ?, ?, ?, ?)",
    )
    .bind(&user.id)
    .bind(&user.name)
    .bind(Uuid::new_v4().to_string())
    .bind(user.created_at)
    .bind(&user.profile_emoji)
    .bind(&user.profile_color_hex)
    .execute(conn)
    .await?;
    Ok(user)
}

/// A new passkey. A credential id already held, by anyone, is an error:
/// credential ids are public, and must never move between accounts.
async fn insert_passkey(
    conn: &mut sqlx::SqliteConnection,
    credential_id: &str,
    user_id: &str,
    credential_json: &str,
    created_at_ip: Option<&str>,
) -> DbResult<()> {
    sqlx::query(
        "INSERT INTO passkeys (credential_id, user_id, passkey_json, created_at, created_ip)
         VALUES (?, ?, ?, ?, ?)",
    )
    .bind(credential_id)
    .bind(user_id)
    .bind(credential_json)
    .bind(now_unix())
    .bind(created_at_ip)
    .execute(conn)
    .await?;
    Ok(())
}

impl ServerDb {
    // ── Users ──

    /// A user with no passkey: tests and the test-auth dev login only.
    #[cfg(any(test, feature = "test-auth"))]
    pub async fn create_user_with_id(&self, user_id: &str, username: &str) -> DbResult<User> {
        let mut conn = self.write_pool.acquire().await?;
        insert_user(&mut conn, user_id, username).await
    }

    /// A new account and its first passkey, together or not at all: an
    /// account left without one could never be signed in to, and would
    /// hold its name for good.
    pub async fn create_user_with_passkey(
        &self,
        user_id: &str,
        username: &str,
        credential_id: &str,
        credential_json: &str,
        created_at_ip: Option<&str>,
    ) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;
        insert_user(&mut tx, user_id, username).await?;
        insert_passkey(
            &mut tx,
            credential_id,
            user_id,
            credential_json,
            created_at_ip,
        )
        .await?;
        tx.commit().await?;
        Ok(())
    }

    #[cfg(any(test, feature = "test-auth"))]
    pub async fn get_or_create_user_with_auth_session(
        &self,
        username: &str,
    ) -> DbResult<(User, String)> {
        let user = match self.get_user_by_name(username).await? {
            Some(user) => user,
            None => {
                self.create_user_with_id(&Uuid::new_v4().to_string(), username)
                    .await?
            }
        };
        let token = self.create_auth_session(&user.id).await?;
        Ok((user, token))
    }

    pub async fn get_user(&self, user_id: &str) -> DbResult<Option<User>> {
        let row = sqlx::query(&format!("SELECT {USER_COLUMNS} FROM users WHERE id = ?"))
            .bind(user_id)
            .fetch_optional(&self.read_pool)
            .await?;
        Ok(row.as_ref().map(user_from))
    }

    /// The user holding `username`, whatever its case.
    pub async fn get_user_by_name(&self, username: &str) -> DbResult<Option<User>> {
        let row = sqlx::query(&format!(
            "SELECT {USER_COLUMNS} FROM users WHERE username = ?"
        ))
        .bind(username.trim())
        .fetch_optional(&self.read_pool)
        .await?;
        Ok(row.as_ref().map(user_from))
    }

    /// Change what was given: an empty emoji or colour, or no weight, keeps
    /// what the user had.
    pub async fn update_user_profile(
        &self,
        user_id: &str,
        profile_emoji: &str,
        profile_color_hex: &str,
        body_weight_kg: f32,
    ) -> DbResult<Option<User>> {
        let given = |value: &str| !value.trim().is_empty();
        sqlx::query(
            "UPDATE users SET
               emoji = CASE WHEN ? THEN ? ELSE emoji END,
               color_hex = CASE WHEN ? THEN ? ELSE color_hex END,
               body_weight_kg = CASE WHEN ? > 0 THEN ? ELSE body_weight_kg END
             WHERE id = ?",
        )
        .bind(given(profile_emoji))
        .bind(normalize_profile_emoji(profile_emoji))
        .bind(given(profile_color_hex))
        .bind(normalize_profile_color_hex(profile_color_hex))
        .bind(body_weight_kg)
        .bind(body_weight_kg)
        .bind(user_id)
        .execute(&self.write_pool)
        .await?;
        self.get_user(user_id).await
    }

    /// The account and everything it owns: the cascade takes its events,
    /// logins, passkeys, sessions and page views. Its partners' streams
    /// hear the session without it, and its requests to join go.
    pub async fn delete_user_account_and_data(&self, user_id: &str) -> DbResult<()> {
        let session = self.get_user_session_pointer(user_id).await?;
        // On the one write connection: a push already under way lands
        // before it (and goes with it), one after finds no account.
        let mut tx = self.write_pool.begin().await?;
        sqlx::query("DELETE FROM users WHERE id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        // A registration attempt is keyed by the user id it went on to create.
        sqlx::query("DELETE FROM auth_attempts WHERE attempt_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
        self.forget_join_requests(user_id);
        if let Some(session) = session {
            self.session_changed(&session);
        }
        Ok(())
    }

    // ── Logins ──

    /// A new login for the user. Logins already expired, anyone's, are
    /// deleted on the way.
    pub async fn create_auth_session(&self, user_id: &str) -> DbResult<String> {
        let now = now_unix();
        let token = Uuid::new_v4().to_string();
        let mut tx = self.write_pool.begin().await?;
        sqlx::query("DELETE FROM logins WHERE expires_at <= ?")
            .bind(now)
            .execute(&mut *tx)
            .await?;
        sqlx::query("INSERT INTO logins (token_hash, user_id, expires_at) VALUES (?, ?, ?)")
            .bind(token_hash(&token))
            .bind(user_id)
            .bind(now + LOGIN_SECONDS)
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
        Ok(token)
    }

    pub async fn validate_auth_session(&self, token: &str) -> DbResult<Option<String>> {
        let user_id: Option<String> = sqlx::query_scalar(
            "SELECT user_id FROM logins WHERE token_hash = ? AND expires_at > ?",
        )
        .bind(token_hash(token))
        .bind(now_unix())
        .fetch_optional(&self.read_pool)
        .await?;
        Ok(user_id)
    }

    pub async fn delete_auth_session(&self, token: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM logins WHERE token_hash = ?")
            .bind(token_hash(token))
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }

    // ── Passkeys ──

    /// Whether any account holds this passkey.
    pub async fn credential_registered(&self, credential_id: &str) -> DbResult<bool> {
        let held: bool =
            sqlx::query_scalar("SELECT COUNT(*) > 0 FROM passkeys WHERE credential_id = ?")
                .bind(credential_id)
                .fetch_one(&self.read_pool)
                .await?;
        Ok(held)
    }

    /// Store another passkey for an existing user (see `insert_passkey`).
    pub async fn store_credential(
        &self,
        credential_id: &str,
        user_id: &str,
        credential_json: &str,
        created_at_ip: Option<&str>,
    ) -> DbResult<()> {
        let mut conn = self.write_pool.acquire().await?;
        insert_passkey(
            &mut conn,
            credential_id,
            user_id,
            credential_json,
            created_at_ip,
        )
        .await
    }

    /// Delete one of the user's passkeys, unless it is their last: false,
    /// and nothing deleted, so nobody locks themselves out.
    pub async fn delete_credential(&self, user_id: &str, credential_id: &str) -> DbResult<bool> {
        let mut tx = self.write_pool.begin().await?;
        let count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM passkeys WHERE user_id = ?")
            .bind(user_id)
            .fetch_one(&mut *tx)
            .await?;
        if count <= 1 {
            return Ok(false);
        }
        sqlx::query("DELETE FROM passkeys WHERE user_id = ? AND credential_id = ?")
            .bind(user_id)
            .bind(credential_id)
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
        Ok(true)
    }

    pub async fn update_credential_json(
        &self,
        credential_id: &str,
        new_json: &str,
    ) -> DbResult<()> {
        sqlx::query("UPDATE passkeys SET passkey_json = ? WHERE credential_id = ?")
            .bind(new_json)
            .bind(credential_id)
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }

    pub async fn get_credentials_for_user(&self, user_id: &str) -> DbResult<Vec<String>> {
        let rows = sqlx::query_scalar("SELECT passkey_json FROM passkeys WHERE user_id = ?")
            .bind(user_id)
            .fetch_all(&self.read_pool)
            .await?;
        Ok(rows)
    }

    /// (credential id, created at, passkey json, created from)
    pub async fn list_passkey_metadata(
        &self,
        user_id: &str,
    ) -> DbResult<Vec<(String, i64, String, Option<String>)>> {
        let rows = sqlx::query_as(
            "SELECT credential_id, created_at, passkey_json, created_ip FROM passkeys
             WHERE user_id = ? ORDER BY created_at DESC",
        )
        .bind(user_id)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows)
    }
}

#[cfg(test)]
mod tests {
    use super::token_hash;
    use crate::db::ServerDb;
    use sqlx::Row;
    use uuid::Uuid;

    async fn temp_db() -> ServerDb {
        let dir = std::env::temp_dir().join(format!("lift-auth-test-{}", Uuid::new_v4()));
        ServerDb::new_in_dir(&dir).await.unwrap()
    }

    #[tokio::test]
    async fn a_held_credential_id_cannot_be_registered_again() {
        let db = temp_db().await;
        db.create_user_with_id("victim", "victim").await.unwrap();
        db.create_user_with_id("attacker", "attacker")
            .await
            .unwrap();
        db.store_credential("cred", "victim", r#"{"k":"victim"}"#, None)
            .await
            .unwrap();
        assert!(db.credential_registered("cred").await.unwrap());
        assert!(db
            .store_credential("cred", "attacker", r#"{"k":"attacker"}"#, None)
            .await
            .is_err());
        assert_eq!(
            db.get_credentials_for_user("victim").await.unwrap(),
            vec![r#"{"k":"victim"}"#.to_string()]
        );
        assert!(db
            .get_credentials_for_user("attacker")
            .await
            .unwrap()
            .is_empty());
    }

    /// A sign-up whose passkey can't be stored leaves no account behind to
    /// hold the name.
    #[tokio::test]
    async fn a_sign_up_is_the_account_and_its_passkey_or_nothing() {
        let db = temp_db().await;
        db.create_user_with_passkey("victim", "victim", "cred", "{}", None)
            .await
            .unwrap();
        assert!(db
            .create_user_with_passkey("new", "new", "cred", "{}", None)
            .await
            .is_err());
        assert!(db.get_user("new").await.unwrap().is_none());
        assert!(db.get_user_by_name("new").await.unwrap().is_none());
        assert_eq!(
            db.get_credentials_for_user("victim").await.unwrap().len(),
            1
        );
    }

    #[tokio::test]
    async fn logins_are_stored_hashed_and_expired_ones_cleared() {
        let db = temp_db().await;
        db.create_user_with_id("u", "u").await.unwrap();
        sqlx::query("INSERT INTO logins (token_hash, user_id, expires_at) VALUES ('old', 'u', 1)")
            .execute(&db.write_pool)
            .await
            .unwrap();
        let token = db.create_auth_session("u").await.unwrap();
        let stored: Vec<String> = sqlx::query_scalar("SELECT token_hash FROM logins")
            .fetch_all(&db.read_pool)
            .await
            .unwrap();
        assert_eq!(
            stored,
            vec![token_hash(&token)],
            "only the hash, and only the live one"
        );
        assert_eq!(
            db.validate_auth_session(&token).await.unwrap().as_deref(),
            Some("u")
        );
        assert_eq!(
            db.validate_auth_session(&token_hash(&token)).await.unwrap(),
            None
        );
        db.delete_auth_session(&token).await.unwrap();
        assert_eq!(db.validate_auth_session(&token).await.unwrap(), None);
    }

    /// Every table with a `user_id` column, from SQLite itself, so a new
    /// table is covered without anyone remembering to add it.
    async fn tables_with_user_id(db: &ServerDb) -> Vec<String> {
        let tables: Vec<String> = sqlx::query_scalar(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
        )
        .fetch_all(&db.read_pool)
        .await
        .unwrap();
        let mut out = Vec::new();
        for table in tables {
            let has: bool = sqlx::query_scalar(
                "SELECT COUNT(*) > 0 FROM pragma_table_info(?) WHERE name = 'user_id'",
            )
            .bind(&table)
            .fetch_one(&db.read_pool)
            .await
            .unwrap();
            if has {
                out.push(table);
            }
        }
        out
    }

    #[tokio::test]
    async fn every_user_keyed_table_goes_with_its_user() {
        let db = temp_db().await;
        let tables = tables_with_user_id(&db).await;
        assert!(tables.len() >= 5, "{tables:?}");
        for table in tables {
            let cascades = sqlx::query("SELECT * FROM pragma_foreign_key_list(?)")
                .bind(&table)
                .fetch_all(&db.read_pool)
                .await
                .unwrap()
                .iter()
                .any(|fk| {
                    fk.get::<String, _>("table") == "users"
                        && fk.get::<String, _>("from") == "user_id"
                        && fk.get::<String, _>("on_delete") == "CASCADE"
                });
            assert!(
                cascades,
                "{table}.user_id must reference users(id) ON DELETE CASCADE"
            );
        }
    }

    async fn seed(db: &ServerDb, u: &str) {
        db.create_user_with_id(u, u).await.unwrap();
        db.store_credential(&format!("{u}-cred"), u, "{}", None)
            .await
            .unwrap();
        db.create_auth_session(u).await.unwrap();
        db.join_session(&format!("{u}-session"), u).await.unwrap();
        for sql in [
            r#"INSERT INTO account_events (user_id, seq, id, event)
               VALUES (?, 1, 'e', '{"seq":1,"id":"e","at":1,"TemplateDeleted":{"template_id":"t"}}')"#,
            "INSERT INTO page_views (user_id, app_session_id, seq, page, entered_at_ms)
             VALUES (?, 's', 1, 'home', 1)",
        ] {
            sqlx::query(sql)
                .bind(u)
                .execute(&db.write_pool)
                .await
                .unwrap();
        }
    }

    async fn rows(db: &ServerDb, table: &str, u: &str) -> i64 {
        sqlx::query_scalar(&format!("SELECT COUNT(*) FROM {table} WHERE user_id = ?"))
            .bind(u)
            .fetch_one(&db.read_pool)
            .await
            .unwrap()
    }

    #[tokio::test]
    async fn deleting_an_account_leaves_nothing_of_it_and_no_one_else_touched() {
        let db = temp_db().await;
        seed(&db, "gone").await;
        seed(&db, "stays").await;
        db.delete_user_account_and_data("gone").await.unwrap();
        assert!(db.get_user("gone").await.unwrap().is_none());
        assert!(db.get_user("stays").await.unwrap().is_some());
        for table in tables_with_user_id(&db).await {
            assert_eq!(
                rows(&db, &table, "gone").await,
                0,
                "{table} kept the deleted user's rows"
            );
            assert!(
                rows(&db, &table, "stays").await > 0,
                "{table} lost the other user's rows"
            );
        }
    }
}
