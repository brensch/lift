//! Assistants connected over MCP, the OAuth way (see `src/mcp`): the
//! clients that registered, the codes a person's consent issued, the grants
//! they made and the tokens a grant holds. Server-owned, so plain columns;
//! every row hangs off a user and goes with them.
//!
//! Codes and tokens are stored as their SHA-256 (`token_hash`), never as
//! themselves: the table holds nothing that would let anyone in.

use super::migrate::token_hash;
use super::{DbResult, ServerDb};
use crate::time::now_unix;
use uuid::Uuid;

/// How long a consent's code can be exchanged for.
pub const CODE_SECONDS: i64 = 10 * 60;
/// How long an access token lasts; the refresh token gets another.
pub const ACCESS_SECONDS: i64 = 60 * 60;
/// How long a refresh token lasts unused; each use replaces it.
pub const REFRESH_SECONDS: i64 = 60 * 24 * 3600;
/// The most clients one registration source can leave lying about: past
/// this, the oldest never used are dropped.
pub const MAX_CLIENTS: i64 = 10_000;
/// The most feedback one person's assistants leave in a day; past this it is
/// thanked for and dropped.
pub const MAX_FEEDBACK_PER_DAY: i64 = 20;
/// The longest feedback: one short line.
pub const MAX_FEEDBACK_CHARS: usize = 144;

/// One piece of an assistant's feedback, as the admin page reads it.
#[derive(Clone, Debug, PartialEq)]
pub struct Feedback {
    pub client_name: String,
    pub tool: String,
    pub text: String,
    pub created_at: i64,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Client {
    pub client_id: String,
    pub client_name: String,
    pub redirect_uris: Vec<String>,
}

/// What a code stood for, once taken.
#[derive(Clone, Debug, PartialEq)]
pub struct Consent {
    pub user_id: String,
    pub client_id: String,
    pub redirect_uri: String,
    pub code_challenge: String,
    pub scope: String,
}

/// A grant, as the person's list shows it.
#[derive(Clone, Debug, PartialEq)]
pub struct Grant {
    pub grant_id: String,
    pub client_name: String,
    pub scope: String,
    pub created_at: i64,
    pub last_used_at: i64,
}

/// A fresh access and refresh token for a grant.
#[derive(Clone, Debug, PartialEq)]
pub struct Tokens {
    pub access_token: String,
    pub refresh_token: String,
    pub expires_in: i64,
    pub scope: String,
}

/// An unguessable token: two random UUIDs, 244 random bits.
fn secret() -> String {
    format!("{}{}", Uuid::new_v4().simple(), Uuid::new_v4().simple())
}

impl ServerDb {
    pub async fn register_assistant(
        &self,
        client_name: &str,
        redirect_uris: &[String],
    ) -> DbResult<Client> {
        let client = Client {
            client_id: Uuid::new_v4().to_string(),
            client_name: client_name.to_string(),
            redirect_uris: redirect_uris.to_vec(),
        };
        sqlx::query(
            "INSERT INTO assistant_clients (client_id, client_name, redirect_uris, created_at)
             VALUES (?, ?, ?, ?)",
        )
        .bind(&client.client_id)
        .bind(&client.client_name)
        .bind(serde_json::to_string(&client.redirect_uris)?)
        .bind(now_unix())
        .execute(&self.write_pool)
        .await?;
        // Registration is open to anyone: clients nobody ever connected
        // are dropped, oldest first, past the cap.
        sqlx::query(
            "DELETE FROM assistant_clients WHERE client_id IN (
                 SELECT client_id FROM assistant_clients c
                 WHERE NOT EXISTS (SELECT 1 FROM assistant_grants g WHERE g.client_id = c.client_id)
                 ORDER BY created_at DESC LIMIT -1 OFFSET ?)",
        )
        .bind(MAX_CLIENTS)
        .execute(&self.write_pool)
        .await?;
        Ok(client)
    }

    pub async fn assistant_client(&self, client_id: &str) -> DbResult<Option<Client>> {
        let row: Option<(String, String, String)> = sqlx::query_as(
            "SELECT client_id, client_name, redirect_uris FROM assistant_clients WHERE client_id = ?",
        )
        .bind(client_id)
        .fetch_optional(&self.read_pool)
        .await?;
        Ok(match row {
            Some((client_id, client_name, uris)) => Some(Client {
                client_id,
                client_name,
                redirect_uris: serde_json::from_str(&uris)?,
            }),
            None => None,
        })
    }

    /// A person's consent: a code the client exchanges, once, within
    /// `CODE_SECONDS`.
    pub async fn issue_assistant_code(&self, consent: &Consent) -> DbResult<String> {
        let code = secret();
        sqlx::query(
            "INSERT INTO assistant_codes
                 (code_hash, user_id, client_id, redirect_uri, code_challenge, scope, expires_at)
             VALUES (?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(token_hash(&code))
        .bind(&consent.user_id)
        .bind(&consent.client_id)
        .bind(&consent.redirect_uri)
        .bind(&consent.code_challenge)
        .bind(&consent.scope)
        .bind(now_unix() + CODE_SECONDS)
        .execute(&self.write_pool)
        .await?;
        Ok(code)
    }

    /// The consent a code stood for, taken: a code works once.
    pub async fn take_assistant_code(&self, code: &str) -> DbResult<Option<Consent>> {
        let row: Option<(String, String, String, String, String)> = sqlx::query_as(
            "DELETE FROM assistant_codes WHERE code_hash = ? AND expires_at > ?
             RETURNING user_id, client_id, redirect_uri, code_challenge, scope",
        )
        .bind(token_hash(code))
        .bind(now_unix())
        .fetch_optional(&self.write_pool)
        .await?;
        Ok(row.map(
            |(user_id, client_id, redirect_uri, code_challenge, scope)| Consent {
                user_id,
                client_id,
                redirect_uri,
                code_challenge,
                scope,
            },
        ))
    }

    /// A grant for a taken consent, and its first tokens.
    pub async fn grant_assistant(&self, consent: &Consent) -> DbResult<Tokens> {
        let grant_id = Uuid::new_v4().to_string();
        let now = now_unix();
        sqlx::query(
            "INSERT INTO assistant_grants (grant_id, user_id, client_id, scope, created_at, last_used_at)
             VALUES (?, ?, ?, ?, ?, 0)",
        )
        .bind(&grant_id)
        .bind(&consent.user_id)
        .bind(&consent.client_id)
        .bind(&consent.scope)
        .bind(now)
        .execute(&self.write_pool)
        .await?;
        self.issue_assistant_tokens(&grant_id, &consent.scope).await
    }

    async fn issue_assistant_tokens(&self, grant_id: &str, scope: &str) -> DbResult<Tokens> {
        let tokens = Tokens {
            access_token: secret(),
            refresh_token: secret(),
            expires_in: ACCESS_SECONDS,
            scope: scope.to_string(),
        };
        let now = now_unix();
        let mut tx = self.write_pool.begin().await?;
        for (token, kind, seconds) in [
            (&tokens.access_token, "access", ACCESS_SECONDS),
            (&tokens.refresh_token, "refresh", REFRESH_SECONDS),
        ] {
            sqlx::query(
                "INSERT INTO assistant_tokens (token_hash, grant_id, kind, expires_at)
                 VALUES (?, ?, ?, ?)",
            )
            .bind(token_hash(token))
            .bind(grant_id)
            .bind(kind)
            .bind(now + seconds)
            .execute(&mut *tx)
            .await?;
        }
        // Expired tokens of any grant go as new ones are made.
        sqlx::query("DELETE FROM assistant_tokens WHERE expires_at <= ?")
            .bind(now)
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
        Ok(tokens)
    }

    /// A refresh token exchanged for new tokens: the old one is spent. A
    /// refresh token must be the client's own.
    pub async fn refresh_assistant(
        &self,
        refresh_token: &str,
        client_id: &str,
    ) -> DbResult<Option<Tokens>> {
        let grant_id: Option<String> = sqlx::query_scalar(
            "DELETE FROM assistant_tokens
             WHERE token_hash = ? AND kind = 'refresh' AND expires_at > ?
               AND grant_id IN (SELECT grant_id FROM assistant_grants WHERE client_id = ?)
             RETURNING grant_id",
        )
        .bind(token_hash(refresh_token))
        .bind(now_unix())
        .bind(client_id)
        .fetch_optional(&self.write_pool)
        .await?;
        let Some(grant_id) = grant_id else {
            return Ok(None);
        };
        let scope: Option<String> =
            sqlx::query_scalar("SELECT scope FROM assistant_grants WHERE grant_id = ?")
                .bind(&grant_id)
                .fetch_optional(&self.write_pool)
                .await?;
        match scope {
            Some(scope) => Ok(Some(self.issue_assistant_tokens(&grant_id, &scope).await?)),
            None => Ok(None),
        }
    }

    /// Whose an access token is, and what its grant is called: None when
    /// it is unknown, expired or revoked. Marks the grant used.
    pub async fn assistant_access(&self, access_token: &str) -> DbResult<Option<(String, String)>> {
        let now = now_unix();
        let row: Option<(String, String, String)> = sqlx::query_as(
            "SELECT g.grant_id, g.user_id, c.client_name
             FROM assistant_tokens t
             JOIN assistant_grants g ON g.grant_id = t.grant_id
             JOIN assistant_clients c ON c.client_id = g.client_id
             WHERE t.token_hash = ? AND t.kind = 'access' AND t.expires_at > ?",
        )
        .bind(token_hash(access_token))
        .bind(now)
        .fetch_optional(&self.read_pool)
        .await?;
        let Some((grant_id, user_id, client_name)) = row else {
            return Ok(None);
        };
        sqlx::query("UPDATE assistant_grants SET last_used_at = ? WHERE grant_id = ?")
            .bind(now)
            .bind(&grant_id)
            .execute(&self.write_pool)
            .await?;
        Ok(Some((user_id, client_name)))
    }

    pub async fn assistant_grants(&self, user_id: &str) -> DbResult<Vec<Grant>> {
        let rows: Vec<(String, String, String, i64, i64)> = sqlx::query_as(
            "SELECT g.grant_id, c.client_name, g.scope, g.created_at, g.last_used_at
             FROM assistant_grants g JOIN assistant_clients c ON c.client_id = g.client_id
             WHERE g.user_id = ?
             ORDER BY MAX(g.last_used_at, g.created_at) DESC",
        )
        .bind(user_id)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(
                |(grant_id, client_name, scope, created_at, last_used_at)| Grant {
                    grant_id,
                    client_name,
                    scope,
                    created_at,
                    last_used_at,
                },
            )
            .collect())
    }

    /// The person's own grant revoked, its tokens with it. Whether there
    /// was one.
    pub async fn revoke_assistant(&self, user_id: &str, grant_id: &str) -> DbResult<bool> {
        let done = sqlx::query("DELETE FROM assistant_grants WHERE grant_id = ? AND user_id = ?")
            .bind(grant_id)
            .bind(user_id)
            .execute(&self.write_pool)
            .await?;
        Ok(done.rows_affected() > 0)
    }

    /// Feedback an assistant sent (`send_feedback`), kept unless the person's
    /// assistants already sent [`MAX_FEEDBACK_PER_DAY`] in the last day.
    /// Whether it was kept.
    pub async fn record_assistant_feedback(
        &self,
        user_id: &str,
        client_name: &str,
        tool: &str,
        text: &str,
    ) -> DbResult<bool> {
        let now = now_unix();
        let recent: i64 = sqlx::query_scalar(
            "SELECT COUNT(*) FROM assistant_feedback WHERE user_id = ? AND created_at > ?",
        )
        .bind(user_id)
        .bind(now - 86_400)
        .fetch_one(&self.read_pool)
        .await?;
        if recent >= MAX_FEEDBACK_PER_DAY {
            return Ok(false);
        }
        sqlx::query(
            "INSERT INTO assistant_feedback (user_id, client_name, tool, text, created_at)
             VALUES (?, ?, ?, ?, ?)",
        )
        .bind(user_id)
        .bind(client_name)
        .bind(tool)
        .bind(text)
        .bind(now)
        .execute(&self.write_pool)
        .await?;
        Ok(true)
    }

    /// The newest feedback first, at most `limit`: for the admin page, so no
    /// user, only which assistant and tool.
    pub async fn assistant_feedback(&self, limit: i64) -> DbResult<Vec<Feedback>> {
        let rows: Vec<(String, String, String, i64)> = sqlx::query_as(
            "SELECT client_name, tool, text, created_at FROM assistant_feedback
             ORDER BY created_at DESC, id DESC LIMIT ?",
        )
        .bind(limit)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|(client_name, tool, text, created_at)| Feedback {
                client_name,
                tool,
                text,
                created_at,
            })
            .collect())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    async fn db() -> ServerDb {
        let dir = std::env::temp_dir().join(format!("lift-assistants-{}", Uuid::new_v4()));
        let db = ServerDb::new_in_dir(&dir).await.unwrap();
        db.create_user_with_id("u1", "Lyss").await.unwrap();
        db
    }

    fn consent(client: &Client) -> Consent {
        Consent {
            user_id: "u1".into(),
            client_id: client.client_id.clone(),
            redirect_uri: client.redirect_uris[0].clone(),
            code_challenge: "challenge".into(),
            scope: "program".into(),
        }
    }

    /// Register, consent, exchange once, use, refresh once, revoke.
    #[tokio::test]
    async fn a_grant_from_consent_to_revocation() {
        let db = db().await;
        let client = db
            .register_assistant("Claude", &["https://claude.ai/cb".into()])
            .await
            .unwrap();
        assert_eq!(
            db.assistant_client(&client.client_id).await.unwrap(),
            Some(client.clone())
        );

        let code = db.issue_assistant_code(&consent(&client)).await.unwrap();
        let taken = db.take_assistant_code(&code).await.unwrap().unwrap();
        assert_eq!(taken, consent(&client));
        assert_eq!(db.take_assistant_code(&code).await.unwrap(), None, "once");

        let tokens = db.grant_assistant(&taken).await.unwrap();
        assert_eq!(
            db.assistant_access(&tokens.access_token).await.unwrap(),
            Some(("u1".into(), "Claude".into()))
        );
        assert_eq!(
            db.assistant_access(&tokens.refresh_token).await.unwrap(),
            None
        );

        assert_eq!(
            db.refresh_assistant(&tokens.refresh_token, "someone-else")
                .await
                .unwrap(),
            None,
            "only the client's own"
        );
        let again = db
            .refresh_assistant(&tokens.refresh_token, &client.client_id)
            .await
            .unwrap()
            .unwrap();
        assert_eq!(
            db.refresh_assistant(&tokens.refresh_token, &client.client_id)
                .await
                .unwrap(),
            None,
            "a refresh token is spent"
        );

        let grants = db.assistant_grants("u1").await.unwrap();
        assert_eq!(grants.len(), 1);
        assert_eq!(grants[0].client_name, "Claude");
        assert!(grants[0].last_used_at > 0);
        assert!(!db
            .revoke_assistant("u2", &grants[0].grant_id)
            .await
            .unwrap());
        assert!(db
            .revoke_assistant("u1", &grants[0].grant_id)
            .await
            .unwrap());
        assert_eq!(
            db.assistant_access(&again.access_token).await.unwrap(),
            None
        );
        assert!(db.assistant_grants("u1").await.unwrap().is_empty());
    }
}
