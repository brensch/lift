//! Getting back into an account whose passkeys are lost. The person makes a
//! new passkey for the account; it waits in `passkey_recoveries` under a
//! code, signing nothing in, until an admin approves the code they were sent.
//! See docs/architecture/auth.md.

use super::*;
use crate::auth::Refusal;

/// How long a request waits for an admin before it lapses.
pub const RECOVERY_TTL_SECONDS: i64 = 7 * 24 * 60 * 60;
/// How long a decided request is kept, so its maker can read the verdict
/// and an admin can see what was done.
const DECIDED_KEPT_SECONDS: i64 = 30 * 24 * 60 * 60;
/// Requests waiting past these are refused: per account, so the list an
/// admin reads stays short; and in all, so the unauthenticated start can't
/// grow the table without bound.
const MAX_WAITING_PER_USER: i64 = 5;
const MAX_WAITING: i64 = 1_000;

/// Letters and digits that can't be read as each other (no 0/O, 1/I/L).
const CODE_ALPHABET: &[u8] = b"ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const CODE_CHARS: usize = 8;

/// A fresh code, as stored: eight characters.
fn new_code() -> String {
    // Two ids' worth of random bytes; the bytes holding a UUID's version
    // and variant are skipped.
    let (a, b) = (Uuid::new_v4(), Uuid::new_v4());
    a.as_bytes()[..6]
        .iter()
        .chain(&b.as_bytes()[..6])
        .take(CODE_CHARS)
        .map(|byte| CODE_ALPHABET[*byte as usize % CODE_ALPHABET.len()] as char)
        .collect()
}

/// A code as a person types it, to how it is stored: "k7m2-qx9p" is
/// "K7M2QX9P".
fn stored_code(typed: &str) -> String {
    typed
        .chars()
        .filter(char::is_ascii_alphanumeric)
        .map(|c| c.to_ascii_uppercase())
        .collect()
}

/// The code shown for a request to recover a name nobody holds. Nothing is
/// stored for such a request, so its code is worked out from its id each
/// time it is asked for; no waiting request has it, so it approves nothing.
pub fn nobodys_code(request_id: &str) -> String {
    use sha2::{Digest, Sha256};
    let digest = Sha256::digest(request_id.as_bytes());
    let code: String = digest[..CODE_CHARS]
        .iter()
        .map(|byte| CODE_ALPHABET[*byte as usize % CODE_ALPHABET.len()] as char)
        .collect();
    shown_code(&code)
}

/// A stored code as it is shown: "K7M2-QX9P".
pub fn shown_code(stored: &str) -> String {
    let (head, tail) = stored.split_at(stored.len().min(CODE_CHARS / 2));
    format!("{head}-{tail}")
}

/// A request to get into an account, with what an admin judges it by.
#[derive(Debug, Clone, PartialEq)]
pub struct Recovery {
    pub request_id: String,
    pub user_id: String,
    pub username: String,
    /// As stored; see `shown_code`.
    pub code: String,
    pub created_at: i64,
    pub created_ip: String,
    pub platform: String,
    /// "pending", "approved" or "denied".
    pub status: String,
    pub decided_at: i64,
    pub passkeys: i32,
    pub logins: i32,
    pub last_seen_ms: i64,
}

impl Recovery {
    /// Waiting and not yet lapsed.
    pub fn waiting(&self, now: i64) -> bool {
        self.status == "pending" && self.created_at > now - RECOVERY_TTL_SECONDS
    }
}

const RECOVERY_SELECT: &str = "SELECT r.request_id, r.user_id, u.username, r.code, r.created_at,
        COALESCE(r.created_ip, '') AS created_ip, r.platform, r.status, r.decided_at,
        (SELECT COUNT(*) FROM passkeys p WHERE p.user_id = r.user_id) AS passkeys,
        (SELECT COUNT(*) FROM logins l WHERE l.user_id = r.user_id AND l.expires_at > ?) AS logins,
        COALESCE((SELECT MAX(v.entered_at_ms) FROM page_views v WHERE v.user_id = r.user_id), 0)
            AS last_seen_ms
     FROM passkey_recoveries r JOIN users u ON u.id = r.user_id";

fn recovery_from(row: &sqlx::sqlite::SqliteRow) -> Recovery {
    Recovery {
        request_id: row.get("request_id"),
        user_id: row.get("user_id"),
        username: row.get("username"),
        code: row.get("code"),
        created_at: row.get("created_at"),
        created_ip: row.get("created_ip"),
        platform: row.get("platform"),
        status: row.get("status"),
        decided_at: row.get("decided_at"),
        passkeys: row.get("passkeys"),
        logins: row.get("logins"),
        last_seen_ms: row.get("last_seen_ms"),
    }
}

/// What approving a code came to.
#[derive(Debug, PartialEq)]
pub enum Approval {
    Approved(Recovery),
    /// No waiting request has that code.
    NoSuchCode,
    /// The passkey has since been registered some other way.
    AlreadyRegistered,
}

impl ServerDb {
    /// Hold a new passkey aside for `user_id`: the code to send an admin,
    /// and when the request lapses. Lapsed and long-decided requests,
    /// anyone's, are cleared on the way.
    pub async fn store_recovery(
        &self,
        request_id: &str,
        user_id: &str,
        credential_id: &str,
        passkey_json: &str,
        created_ip: Option<&str>,
        platform: &str,
    ) -> DbResult<Result<(String, i64), Refusal>> {
        let now = now_unix();
        let mut tx = self.write_pool.begin().await?;
        sqlx::query(
            "DELETE FROM passkey_recoveries
             WHERE (status = 'pending' AND created_at <= ?)
                OR (status != 'pending' AND decided_at <= ?)",
        )
        .bind(now - RECOVERY_TTL_SECONDS)
        .bind(now - DECIDED_KEPT_SECONDS)
        .execute(&mut *tx)
        .await?;
        let (waiting, theirs): (i64, i64) = sqlx::query_as(
            "SELECT COUNT(*), COALESCE(SUM(user_id = ?), 0) FROM passkey_recoveries
             WHERE status = 'pending'",
        )
        .bind(user_id)
        .fetch_one(&mut *tx)
        .await?;
        if waiting >= MAX_WAITING || theirs >= MAX_WAITING_PER_USER {
            return Ok(Err(Refusal::TooManyRecoveries));
        }
        let held: bool = sqlx::query_scalar(
            "SELECT (SELECT COUNT(*) FROM passkeys WHERE credential_id = ?1)
                  + (SELECT COUNT(*) FROM passkey_recoveries
                     WHERE credential_id = ?1 AND status = 'pending') > 0",
        )
        .bind(credential_id)
        .fetch_one(&mut *tx)
        .await?;
        if held {
            return Ok(Err(Refusal::AlreadyRegistered));
        }
        let code = new_code();
        sqlx::query(
            "INSERT INTO passkey_recoveries
             (request_id, user_id, code, credential_id, passkey_json, created_at, created_ip, platform)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(request_id)
        .bind(user_id)
        .bind(&code)
        .bind(credential_id)
        .bind(passkey_json)
        .bind(now)
        .bind(created_ip)
        .bind(platform)
        .execute(&mut *tx)
        .await?;
        tx.commit().await?;
        Ok(Ok((shown_code(&code), now + RECOVERY_TTL_SECONDS)))
    }

    /// When a recovery for a name nobody holds was asked for, if `request_id`
    /// is one: all that is kept of it is its attempt (`auth_attempts`), the
    /// row every ceremony already writes.
    pub async fn nobodys_recovery_started(&self, request_id: &str) -> DbResult<Option<i64>> {
        Ok(sqlx::query_scalar(
            "SELECT started_at FROM auth_attempts
             WHERE attempt_id = ? AND kind = 'recovery' AND reason = 'unknown_user'",
        )
        .bind(request_id)
        .fetch_optional(&self.read_pool)
        .await?)
    }

    /// The request, whatever its state.
    pub async fn recovery(&self, request_id: &str) -> DbResult<Option<Recovery>> {
        let row = sqlx::query(&format!("{RECOVERY_SELECT} WHERE r.request_id = ?"))
            .bind(now_unix())
            .bind(request_id)
            .fetch_optional(&self.read_pool)
            .await?;
        Ok(row.as_ref().map(recovery_from))
    }

    /// Requests waiting to get into the user's account, newest first.
    pub async fn recoveries_waiting_for(&self, user_id: &str) -> DbResult<Vec<Recovery>> {
        let now = now_unix();
        let rows = sqlx::query(&format!(
            "{RECOVERY_SELECT} WHERE r.user_id = ? AND r.status = 'pending' AND r.created_at > ?
             ORDER BY r.created_at DESC"
        ))
        .bind(now)
        .bind(user_id)
        .bind(now - RECOVERY_TTL_SECONDS)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows.iter().map(recovery_from).collect())
    }

    /// Every request an admin might act on or want to see: the waiting,
    /// oldest first, then the decided, newest first.
    pub async fn list_recoveries(&self) -> DbResult<Vec<Recovery>> {
        let now = now_unix();
        let rows = sqlx::query(&format!(
            "{RECOVERY_SELECT} WHERE r.status != 'pending' OR r.created_at > ?
             ORDER BY r.status != 'pending',
                      CASE WHEN r.status = 'pending' THEN r.created_at ELSE -r.decided_at END
             LIMIT 200"
        ))
        .bind(now)
        .bind(now - RECOVERY_TTL_SECONDS)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows.iter().map(recovery_from).collect())
    }

    /// Refuse a waiting request: an admin any (`owner` None), an account's
    /// owner only their own. The held passkey is dropped. Returns the
    /// request as it now stands, or None if there was nothing to refuse.
    pub async fn deny_recovery(
        &self,
        request_id: &str,
        owner: Option<&str>,
    ) -> DbResult<Option<Recovery>> {
        let denied = sqlx::query(
            "UPDATE passkey_recoveries SET status = 'denied', decided_at = ?, passkey_json = ''
             WHERE request_id = ? AND status = 'pending' AND (? IS NULL OR user_id = ?)",
        )
        .bind(now_unix())
        .bind(request_id)
        .bind(owner)
        .bind(owner)
        .execute(&self.write_pool)
        .await?
        .rows_affected();
        if denied == 0 {
            return Ok(None);
        }
        self.recovery(request_id).await
    }

    /// Approve the waiting request that came with `code`: its passkey
    /// becomes one of the account's. With `remove_others`, the account's
    /// other passkeys go and its devices are signed out.
    pub async fn approve_recovery(&self, code: &str, remove_others: bool) -> DbResult<Approval> {
        let now = now_unix();
        let mut tx = self.write_pool.begin().await?;
        let held: Option<(String, String, String, String, Option<String>)> = sqlx::query_as(
            "SELECT request_id, user_id, credential_id, passkey_json, created_ip
             FROM passkey_recoveries WHERE code = ? AND status = 'pending' AND created_at > ?",
        )
        .bind(stored_code(code))
        .bind(now - RECOVERY_TTL_SECONDS)
        .fetch_optional(&mut *tx)
        .await?;
        let Some((request_id, user_id, credential_id, passkey_json, created_ip)) = held else {
            return Ok(Approval::NoSuchCode);
        };
        let registered: bool =
            sqlx::query_scalar("SELECT COUNT(*) > 0 FROM passkeys WHERE credential_id = ?")
                .bind(&credential_id)
                .fetch_one(&mut *tx)
                .await?;
        if registered {
            return Ok(Approval::AlreadyRegistered);
        }
        if remove_others {
            for table in ["passkeys", "logins"] {
                sqlx::query(&format!("DELETE FROM {table} WHERE user_id = ?"))
                    .bind(&user_id)
                    .execute(&mut *tx)
                    .await?;
            }
        }
        sqlx::query(
            "INSERT INTO passkeys (credential_id, user_id, passkey_json, created_at, created_ip)
             VALUES (?, ?, ?, ?, ?)",
        )
        .bind(&credential_id)
        .bind(&user_id)
        .bind(&passkey_json)
        .bind(now)
        .bind(created_ip)
        .execute(&mut *tx)
        .await?;
        sqlx::query(
            "UPDATE passkey_recoveries SET status = 'approved', decided_at = ?, passkey_json = ''
             WHERE request_id = ?",
        )
        .bind(now)
        .bind(&request_id)
        .execute(&mut *tx)
        .await?;
        tx.commit().await?;
        if remove_others {
            self.notify(Topic::User(user_id), Change::SignedOut);
        }
        match self.recovery(&request_id).await? {
            Some(recovery) => Ok(Approval::Approved(recovery)),
            None => Err("the approved recovery is gone".into()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    async fn temp_db() -> ServerDb {
        let dir = std::env::temp_dir().join(format!("lift-recovery-test-{}", Uuid::new_v4()));
        ServerDb::new_in_dir(&dir).await.unwrap()
    }

    async fn request(db: &ServerDb, id: &str, user: &str, credential: &str) -> String {
        db.store_recovery(id, user, credential, "{}", Some("203.0.113.9"), "web")
            .await
            .unwrap()
            .unwrap()
            .0
    }

    #[test]
    fn a_code_is_read_however_it_is_typed() {
        let code = new_code();
        assert_eq!(code.len(), CODE_CHARS);
        assert!(code.bytes().all(|b| CODE_ALPHABET.contains(&b)));
        let shown = shown_code(&code);
        assert_eq!(shown.len(), CODE_CHARS + 1);
        assert_eq!(stored_code(&shown), code);
        assert_eq!(stored_code(&format!(" {} ", shown.to_lowercase())), code);
    }

    #[tokio::test]
    async fn a_held_passkey_signs_nothing_in_until_its_code_is_approved() {
        let db = temp_db().await;
        db.create_user_with_id("ann", "ann").await.unwrap();
        let code = request(&db, "r1", "ann", "new-cred").await;
        assert!(db.get_credentials_for_user("ann").await.unwrap().is_empty());
        assert!(!db.credential_registered("new-cred").await.unwrap());
        let waiting = db.recoveries_waiting_for("ann").await.unwrap();
        assert_eq!(waiting.len(), 1);
        assert_eq!(waiting[0].platform, "web");

        assert_eq!(
            db.approve_recovery("WRONG-CODE", false).await.unwrap(),
            Approval::NoSuchCode
        );
        let Approval::Approved(done) = db.approve_recovery(&code, false).await.unwrap() else {
            panic!("the code approves its request");
        };
        assert_eq!(done.username, "ann");
        assert_eq!(done.status, "approved");
        assert_eq!(done.passkeys, 1);
        assert!(db.credential_registered("new-cred").await.unwrap());
        // Spent: the code approves nothing twice.
        assert_eq!(
            db.approve_recovery(&code, false).await.unwrap(),
            Approval::NoSuchCode
        );
        assert!(db.recoveries_waiting_for("ann").await.unwrap().is_empty());
    }

    #[tokio::test]
    async fn approving_can_drop_the_other_passkeys_and_sign_the_devices_out() {
        let db = temp_db().await;
        db.create_user_with_id("ann", "ann").await.unwrap();
        db.create_user_with_id("ben", "ben").await.unwrap();
        db.store_credential("old", "ann", "{}", None).await.unwrap();
        db.store_credential("bens", "ben", "{}", None)
            .await
            .unwrap();
        let stolen = db.create_auth_session("ann").await.unwrap();
        let bens = db.create_auth_session("ben").await.unwrap();

        let code = request(&db, "r1", "ann", "new-cred").await;
        db.approve_recovery(&code, true).await.unwrap();
        assert!(!db.credential_registered("old").await.unwrap());
        assert!(db.credential_registered("new-cred").await.unwrap());
        assert_eq!(db.validate_auth_session(&stolen).await.unwrap(), None);
        // Nobody else is touched.
        assert!(db.credential_registered("bens").await.unwrap());
        assert!(db.validate_auth_session(&bens).await.unwrap().is_some());
    }

    #[tokio::test]
    async fn an_owner_refuses_only_requests_for_their_own_account() {
        let db = temp_db().await;
        db.create_user_with_id("ann", "ann").await.unwrap();
        db.create_user_with_id("ben", "ben").await.unwrap();
        let code = request(&db, "r1", "ann", "new-cred").await;

        assert!(db.deny_recovery("r1", Some("ben")).await.unwrap().is_none());
        let denied = db.deny_recovery("r1", Some("ann")).await.unwrap().unwrap();
        assert_eq!(denied.status, "denied");
        assert_eq!(
            db.approve_recovery(&code, false).await.unwrap(),
            Approval::NoSuchCode
        );
        assert!(!db.credential_registered("new-cred").await.unwrap());
        // An admin refuses any.
        request(&db, "r2", "ann", "another").await;
        assert!(db.deny_recovery("r2", None).await.unwrap().is_some());
    }

    #[tokio::test]
    async fn requests_lapse_and_are_bounded_per_account() {
        let db = temp_db().await;
        db.create_user_with_id("ann", "ann").await.unwrap();
        let code = request(&db, "old", "ann", "c-old").await;
        sqlx::query("UPDATE passkey_recoveries SET created_at = ? WHERE request_id = 'old'")
            .bind(now_unix() - RECOVERY_TTL_SECONDS - 1)
            .execute(&db.write_pool)
            .await
            .unwrap();
        assert_eq!(
            db.approve_recovery(&code, false).await.unwrap(),
            Approval::NoSuchCode
        );
        assert!(!db
            .recovery("old")
            .await
            .unwrap()
            .unwrap()
            .waiting(now_unix()));

        for i in 0..MAX_WAITING_PER_USER {
            request(&db, &format!("r{i}"), "ann", &format!("c{i}")).await;
        }
        // The lapsed one was cleared by the next request.
        assert!(db.recovery("old").await.unwrap().is_none());
        let full = db
            .store_recovery("more", "ann", "c-more", "{}", None, "")
            .await
            .unwrap();
        assert_eq!(full, Err(Refusal::TooManyRecoveries));
        // The same passkey isn't held twice, nor one an account holds.
        db.deny_recovery("r0", None).await.unwrap();
        let again = db
            .store_recovery("dup", "ann", "c1", "{}", None, "")
            .await
            .unwrap();
        assert_eq!(again, Err(Refusal::AlreadyRegistered));
    }
}
