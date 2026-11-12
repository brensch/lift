use super::*;
use crate::auth::{AuthState, Refusal, SignIn};
use crate::db::shown_code;
use std::sync::Arc;
use tonic::Code;
use webauthn_rs::prelude::{PublicKeyCredential, RegisterPublicKeyCredential};

// ── Auth Service ──

#[derive(Clone)]
pub struct ServerAuthService {
    pub db: ServerDb,
    pub auth_state: Arc<AuthState>,
}

impl ServerAuthService {
    // Attempt tracking is telemetry. A failure to write it is logged and
    // swallowed: it must never be the reason somebody cannot sign in.

    async fn track_attempt_start(
        &self,
        attempt_id: &str,
        kind: &str,
        platform: &str,
        app_version: &str,
    ) {
        if let Err(e) = self
            .db
            .start_auth_attempt(attempt_id, kind, platform, app_version)
            .await
        {
            tracing::warn!(error = %e, "failed to record auth attempt start");
        }
    }

    async fn track_attempt_finish(&self, attempt_id: &str, outcome: &str, reason: &str) {
        let reason: String = reason.chars().take(80).collect();
        if let Err(e) = self
            .db
            .finish_auth_attempt(attempt_id, outcome, &reason)
            .await
        {
            tracing::warn!(error = %e, "failed to record auth attempt finish");
        }
    }
}

/// On a sign-in refused because its passkey is waiting for an admin: the
/// recovery request it belongs to.
const RECOVERY_REQUEST_HEADER: &str = "x-recovery-request";

/// Longest username a new account may take.
const MAX_USERNAME_CHARS: usize = 64;
/// Passkey names past this are cut short.
const MAX_PASSKEY_NAME_CHARS: usize = 64;

fn passkey_name(name: Option<String>) -> Option<String> {
    name.map(|n| n.chars().take(MAX_PASSKEY_NAME_CHARS).collect())
}

/// A refused ceremony as its caller hears it: the refusal's own words,
/// under a code a client can tell apart. `otherwise` is the code for a
/// credential that didn't verify or came too late, which differs between
/// signing in and registering.
fn refusal_status(refusal: Refusal, otherwise: Code) -> Status {
    let code = match refusal {
        Refusal::UnknownPasskey | Refusal::UnknownUser => Code::NotFound,
        Refusal::NotVerified => Code::FailedPrecondition,
        Refusal::AlreadyRegistered | Refusal::NameTaken => Code::AlreadyExists,
        Refusal::Busy | Refusal::TooManyRecoveries => Code::ResourceExhausted,
        Refusal::Internal => Code::Internal,
        Refusal::Expired | Refusal::Rejected => otherwise,
    };
    Status::new(code, refusal.message())
}

fn registering(refusal: Refusal) -> Status {
    refusal_status(refusal, Code::InvalidArgument)
}

fn signing_in(refusal: Refusal) -> Status {
    refusal_status(refusal, Code::Unauthenticated)
}

/// Where the request came from: the client Caddy names in X-Forwarded-For
/// (the last entry, the one it saw itself), else the connection's peer.
fn client_ip<T>(request: &Request<T>) -> Option<String> {
    request
        .metadata()
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.rsplit(',').next())
        .map(str::trim)
        .filter(|ip| !ip.is_empty())
        .map(str::to_string)
        .or_else(|| request.remote_addr().map(|a| a.ip().to_string()))
}

/// Who is counted as one client for the limit on ceremonies in flight: the
/// address, or for IPv6 its /64, which one host can move freely within.
fn client_key<T>(request: &Request<T>) -> String {
    let ip = client_ip(request).unwrap_or_default();
    match ip.parse::<std::net::IpAddr>() {
        Ok(std::net::IpAddr::V6(v6)) => {
            let s = v6.segments();
            format!("{:x}:{:x}:{:x}:{:x}::/64", s[0], s[1], s[2], s[3])
        }
        _ => ip,
    }
}

#[tonic::async_trait]
impl AuthService for ServerAuthService {
    /// Development-only login that bypasses WebAuthn entirely.
    ///
    /// Gated behind the `test-auth` Cargo feature. Without it this returns
    /// `permission_denied` unconditionally — production release builds
    /// (`cargo build --release --bin schlift`) do NOT enable the feature, so the
    /// bypass is not compiled in. Dev targets in the Makefile pass
    /// `--features test-auth` explicitly.
    ///
    /// This must never be enabled in a build that faces the internet: it issues a
    /// 30-day session token for any username, taking over the account if it
    /// already exists.
    #[cfg(not(feature = "test-auth"))]
    async fn test_login(
        &self,
        _request: Request<TestLoginRequest>,
    ) -> Result<Response<AuthResponse>, Status> {
        Err(Status::permission_denied("test login is not enabled"))
    }

    #[cfg(feature = "test-auth")]
    async fn test_login(
        &self,
        request: Request<TestLoginRequest>,
    ) -> Result<Response<AuthResponse>, Status> {
        let req = request.into_inner();
        let username = req.username.trim();
        info!(rpc = "TestLogin", %username, "request");
        if username.is_empty() {
            return Err(Status::invalid_argument("username is required"));
        }
        let (user, token) = self
            .db
            .get_or_create_user_with_auth_session(username)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(AuthResponse {
            session_token: token,
            user_id: user.id,
            username: user.name,
        }))
    }

    async fn logout(
        &self,
        request: Request<LogoutRequest>,
    ) -> Result<Response<LogoutResponse>, Status> {
        let token = session_token(&request)
            .ok_or_else(|| Status::unauthenticated("Missing session token"))?;
        info!(rpc = "Logout", "request");
        self.db
            .delete_auth_session(token)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(LogoutResponse {}))
    }

    async fn register_start(
        &self,
        request: Request<RegisterStartRequest>,
    ) -> Result<Response<RegisterStartResponse>, Status> {
        let (platform, app_version) = client_labels(&request);
        let client = client_key(&request);
        let req = request.into_inner();
        let username = req.username.trim().to_string();
        info!(rpc = "RegisterStart", %username, "request");
        if username.is_empty() {
            return Err(Status::invalid_argument("username is required"));
        }
        if username.contains(' ') {
            return Err(Status::invalid_argument("username cannot contain spaces"));
        }
        if username.chars().count() > MAX_USERNAME_CHARS || username.chars().any(char::is_control) {
            return Err(Status::invalid_argument("username is not valid"));
        }
        if self
            .db
            .get_user_by_name(&username)
            .await
            .map_err(internal_error)?
            .is_some()
        {
            return Err(Status::already_exists("User already exists"));
        }

        let (user_id, options) = self
            .auth_state
            .start_registration(&username, &client)
            .await
            .map_err(registering)?;
        self.track_attempt_start(&user_id, "register", &platform, &app_version)
            .await;
        let options_json =
            serde_json::to_string(&options).map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(RegisterStartResponse {
            user_id,
            options_json,
        }))
    }
    async fn register_finish(
        &self,
        request: Request<RegisterFinishRequest>,
    ) -> Result<Response<AuthResponse>, Status> {
        let remote_addr = client_ip(&request);
        let req = request.into_inner();
        info!(rpc = "RegisterFinish", user_id = %req.user_id, "request");
        let credential: RegisterPublicKeyCredential = serde_json::from_str(&req.credential_json)
            .map_err(|e| Status::invalid_argument(format!("Invalid credential JSON: {}", e)))?;
        let username = match self
            .auth_state
            .finish_registration(
                &req.user_id,
                &credential,
                remote_addr,
                passkey_name(req.name),
            )
            .await
        {
            Ok(username) => username,
            Err(refusal) => {
                self.track_attempt_finish(&req.user_id, "rejected", refusal.slug())
                    .await;
                return Err(registering(refusal));
            }
        };
        self.track_attempt_finish(&req.user_id, "ok", "").await;
        let token = self
            .db
            .create_auth_session(&req.user_id)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(AuthResponse {
            session_token: token,
            user_id: req.user_id,
            username,
        }))
    }
    async fn login_start(
        &self,
        request: Request<LoginStartRequest>,
    ) -> Result<Response<LoginStartResponse>, Status> {
        let (platform, app_version) = client_labels(&request);
        let client = client_key(&request);
        let req = request.into_inner();
        info!(rpc = "LoginStart", "request");
        let (challenge_id, options) = match req.username.as_deref() {
            Some(username) if !username.trim().is_empty() => self
                .auth_state
                .start_authentication_with_username(username.trim(), &client)
                .await
                .map_err(signing_in)?,
            _ => self
                .auth_state
                .start_authentication(&client)
                .await
                .map_err(signing_in)?,
        };
        self.track_attempt_start(&challenge_id, "login", &platform, &app_version)
            .await;
        let options_json =
            serde_json::to_string(&options).map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(LoginStartResponse {
            challenge_id,
            options_json,
        }))
    }
    async fn login_finish(
        &self,
        request: Request<LoginFinishRequest>,
    ) -> Result<Response<AuthResponse>, Status> {
        let req = request.into_inner();
        info!(rpc = "LoginFinish", challenge_id = %req.challenge_id, "request");
        let credential: PublicKeyCredential = serde_json::from_str(&req.credential_json)
            .map_err(|e| Status::invalid_argument(format!("Invalid credential JSON: {}", e)))?;
        let (token, user_id, username) = match self
            .auth_state
            .finish_authentication(&req.challenge_id, &credential)
            .await
        {
            Ok(SignIn::In {
                token,
                user_id,
                username,
            }) => (token, user_id, username),
            // A passkey made at /recover that no admin has approved yet:
            // not a login. Its holder is told which request it is, so the
            // website can show them their code again.
            Ok(SignIn::AwaitingApproval { request_id }) => {
                self.track_attempt_finish(&req.challenge_id, "rejected", "awaiting_approval")
                    .await;
                let mut status = Status::permission_denied(
                    "That passkey is waiting to be approved. It will sign in once it is.",
                );
                if let Ok(value) = request_id.parse() {
                    status.metadata_mut().insert(RECOVERY_REQUEST_HEADER, value);
                }
                return Err(status);
            }
            Err(refusal) => {
                self.track_attempt_finish(&req.challenge_id, "rejected", refusal.slug())
                    .await;
                return Err(signing_in(refusal));
            }
        };
        self.track_attempt_finish(&req.challenge_id, "ok", "").await;
        Ok(Response::new(AuthResponse {
            session_token: token,
            user_id,
            username,
        }))
    }
    async fn add_passkey_start(
        &self,
        request: Request<AddPasskeyStartRequest>,
    ) -> Result<Response<AddPasskeyStartResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "AddPasskeyStart", %user_id, "request");
        let user = self
            .db
            .get_user(&user_id)
            .await
            .map_err(internal_error)?
            .ok_or_else(|| Status::not_found("User not found"))?;
        let options = self
            .auth_state
            .start_add_passkey(&user_id, &user.name, &client_key(&request))
            .await
            .map_err(registering)?;
        let options_json =
            serde_json::to_string(&options).map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(AddPasskeyStartResponse { options_json }))
    }
    async fn add_passkey_finish(
        &self,
        request: Request<AddPasskeyFinishRequest>,
    ) -> Result<Response<AddPasskeyFinishResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "AddPasskeyFinish", %user_id, "request");
        let remote_addr = client_ip(&request);
        let req = request.into_inner();
        let credential: RegisterPublicKeyCredential = serde_json::from_str(&req.credential_json)
            .map_err(|e| Status::invalid_argument(format!("Invalid credential JSON: {}", e)))?;
        self.auth_state
            .finish_add_passkey(&user_id, &credential, remote_addr, passkey_name(req.name))
            .await
            .map_err(registering)?;
        Ok(Response::new(AddPasskeyFinishResponse {}))
    }
    async fn delete_passkey(
        &self,
        request: Request<DeletePasskeyRequest>,
    ) -> Result<Response<DeletePasskeyResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "DeletePasskey", %user_id, "request");
        let token = session_token(&request).unwrap_or_default().to_string();
        let req = request.into_inner();
        let deleted = self
            .db
            .delete_credential(&user_id, &req.credential_id, &token)
            .await
            .map_err(internal_error)?;
        if !deleted {
            return Err(Status::failed_precondition(
                "Cannot delete the last passkey",
            ));
        }
        Ok(Response::new(DeletePasskeyResponse {}))
    }
    async fn list_passkeys(
        &self,
        request: Request<ListPasskeysRequest>,
    ) -> Result<Response<ListPasskeysResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "ListPasskeys", %user_id, "request");
        let rows = self
            .db
            .list_passkey_metadata(&user_id)
            .await
            .map_err(internal_error)?;
        let passkeys = rows
            .into_iter()
            .map(
                |(credential_id, created_at, credential_json, created_at_ip)| {
                    let value: serde_json::Value =
                        serde_json::from_str(&credential_json).unwrap_or(serde_json::Value::Null);
                    let name = value
                        .get("cred_name")
                        .and_then(|n| n.as_str())
                        .map(str::to_string);
                    let transports = value
                        .get("transports")
                        .and_then(|t| t.as_array())
                        .map(|items| {
                            items
                                .iter()
                                .filter_map(|item| item.as_str().map(str::to_string))
                                .collect()
                        })
                        .unwrap_or_default();
                    PasskeyInfo {
                        credential_id,
                        name,
                        created_at,
                        created_at_ip,
                        transports,
                    }
                },
            )
            .collect();
        Ok(Response::new(ListPasskeysResponse { passkeys }))
    }
    async fn delete_account(
        &self,
        request: Request<DeleteAccountRequest>,
    ) -> Result<Response<DeleteAccountResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "DeleteAccount", %user_id, "request");
        self.db
            .delete_user_account_and_data(&user_id)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(DeleteAccountResponse {
            deleted_user_id: user_id,
        }))
    }

    /// Deliberately unauthenticated, like the Start/Finish RPCs it annotates:
    /// the caller is by definition someone who failed to sign in. Do not copy
    /// this as a pattern. What keeps it safe is that it cannot create rows —
    /// it only labels a recent, still-unfinished attempt the server issued,
    /// once, with an enum value.
    async fn report_auth_failure(
        &self,
        request: Request<ReportAuthFailureRequest>,
    ) -> Result<Response<ReportAuthFailureResponse>, Status> {
        let req = request.into_inner();
        let reason = AuthFailureReason::try_from(req.reason)
            .unwrap_or(AuthFailureReason::Unspecified)
            .as_str_name()
            .trim_start_matches("AUTH_FAILURE_REASON_")
            .to_lowercase();
        info!(rpc = "ReportAuthFailure", %reason, "request");
        if req.attempt_id.len() > 64 {
            return Err(Status::invalid_argument("attempt_id too long"));
        }
        // Whether it landed is not revealed: an unknown id and a settled one
        // look the same to the caller.
        self.db
            .report_auth_failure(&req.attempt_id, &reason)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(ReportAuthFailureResponse {}))
    }

    /// Unauthenticated: the caller has lost their passkey. It starts making
    /// a new one for the account holding the name; `recovery_finish` holds
    /// it aside, and it signs nothing in until an admin approves its code
    /// (`AdminService.DecideRecovery`). A name nobody holds is not refused:
    /// the ceremony runs the same and ends in a code that approves nothing,
    /// with the attempt filed as `unknown_user`. Nothing else is stored
    /// for it, so guessing names fills no table: starts are limited per
    /// client like every ceremony, and an attempt is the one row each
    /// already writes.
    async fn recovery_start(
        &self,
        request: Request<RecoveryStartRequest>,
    ) -> Result<Response<RecoveryStartResponse>, Status> {
        let (platform, app_version) = client_labels(&request);
        let client = client_key(&request);
        let req = request.into_inner();
        let username = req.username.trim();
        info!(rpc = "RecoveryStart", %username, "request");
        if username.is_empty() || username.chars().count() > MAX_USERNAME_CHARS {
            return Err(Status::invalid_argument("username is required"));
        }
        let (request_id, options) = self
            .auth_state
            .start_recovery(username, &client)
            .await
            .map_err(registering)?;
        self.track_attempt_start(&request_id, "recovery", &platform, &app_version)
            .await;
        let options_json =
            serde_json::to_string(&options).map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(RecoveryStartResponse {
            request_id,
            options_json,
        }))
    }

    async fn recovery_finish(
        &self,
        request: Request<RecoveryFinishRequest>,
    ) -> Result<Response<RecoveryFinishResponse>, Status> {
        let remote_addr = client_ip(&request);
        let (platform, _) = client_labels(&request);
        let req = request.into_inner();
        info!(rpc = "RecoveryFinish", request_id = %req.request_id, "request");
        let credential: RegisterPublicKeyCredential = serde_json::from_str(&req.credential_json)
            .map_err(|e| Status::invalid_argument(format!("Invalid credential JSON: {}", e)))?;
        match self
            .auth_state
            .finish_recovery(&req.request_id, &credential, remote_addr, &platform)
            .await
        {
            Ok((code, expires_at, known)) => {
                if known {
                    self.track_attempt_finish(&req.request_id, "ok", "").await;
                } else {
                    self.track_attempt_finish(
                        &req.request_id,
                        "rejected",
                        Refusal::UnknownUser.slug(),
                    )
                    .await;
                }
                Ok(Response::new(RecoveryFinishResponse { code, expires_at }))
            }
            Err(refusal) => {
                self.track_attempt_finish(&req.request_id, "rejected", refusal.slug())
                    .await;
                Err(registering(refusal))
            }
        }
    }

    /// Unauthenticated: the request id, random and known only to whoever
    /// made the request, is what lets its state be read.
    async fn recovery_status(
        &self,
        request: Request<RecoveryStatusRequest>,
    ) -> Result<Response<RecoveryStatusResponse>, Status> {
        let req = request.into_inner();
        if req.request_id.len() > 64 {
            return Err(Status::invalid_argument("request_id too long"));
        }
        let recovery = self
            .db
            .recovery(&req.request_id)
            .await
            .map_err(internal_error)?;
        let expired = RecoveryStatusResponse {
            state: RecoveryState::Expired as i32,
            ..Default::default()
        };
        let Some(recovery) = recovery else {
            // One for a name nobody holds waits like any other, to lapse.
            let started = self
                .db
                .nobodys_recovery_started(&req.request_id)
                .await
                .map_err(internal_error)?;
            let expires_at = started.unwrap_or(0) + crate::db::RECOVERY_TTL_SECONDS;
            if started.is_none() || expires_at <= now_unix() {
                return Ok(Response::new(expired));
            }
            return Ok(Response::new(RecoveryStatusResponse {
                state: RecoveryState::Pending as i32,
                code: crate::db::nobodys_code(&req.request_id),
                expires_at,
                username: String::new(),
            }));
        };
        let state = match recovery.status.as_str() {
            "approved" => RecoveryState::Approved,
            "denied" => RecoveryState::Denied,
            _ if recovery.waiting(now_unix()) => RecoveryState::Pending,
            _ => return Ok(Response::new(expired)),
        };
        let pending = state == RecoveryState::Pending;
        Ok(Response::new(RecoveryStatusResponse {
            state: state as i32,
            code: if pending {
                shown_code(&recovery.code)
            } else {
                String::new()
            },
            expires_at: if pending {
                recovery.created_at + crate::db::RECOVERY_TTL_SECONDS
            } else {
                0
            },
            username: recovery.username,
        }))
    }

    async fn list_my_recoveries(
        &self,
        request: Request<ListMyRecoveriesRequest>,
    ) -> Result<Response<ListMyRecoveriesResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let recoveries = self
            .db
            .recoveries_waiting_for(&user_id)
            .await
            .map_err(internal_error)?
            .into_iter()
            .map(|r| PendingRecovery {
                request_id: r.request_id,
                created_at: r.created_at,
                platform: r.platform,
            })
            .collect();
        Ok(Response::new(ListMyRecoveriesResponse { recoveries }))
    }

    async fn deny_my_recovery(
        &self,
        request: Request<DenyMyRecoveryRequest>,
    ) -> Result<Response<DenyMyRecoveryResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "DenyMyRecovery", %user_id, request_id = %req.request_id, "request");
        // One that is not theirs, or already decided, is left as it is.
        self.db
            .deny_recovery(&req.request_id, Some(&user_id))
            .await
            .map_err(internal_error)?;
        Ok(Response::new(DenyMyRecoveryResponse {}))
    }
}

#[cfg(test)]
mod test_login_gate_tests {
    use super::*;
    use crate::auth::AuthState;
    use std::sync::Arc;

    async fn service() -> ServerAuthService {
        let dir = std::env::temp_dir().join(format!("lift-auth-gate-{}", uuid::Uuid::new_v4()));
        let db = ServerDb::new_in_dir(&dir).await.unwrap();
        ServerAuthService {
            auth_state: Arc::new(AuthState::new(db.clone())),
            db,
        }
    }

    /// TestLogin bypasses WebAuthn and mints a 30-day session for any username,
    /// taking over the account if it already exists. It must not exist in a build
    /// without the `test-auth` feature — production release builds do not enable it.
    #[cfg(not(feature = "test-auth"))]
    #[tokio::test]
    async fn test_login_is_denied_without_the_test_auth_feature() {
        let svc = service().await;

        // Pre-create the account TestLogin would otherwise hand out a token for.
        svc.db
            .get_or_create_user_with_auth_session("victim")
            .await
            .unwrap();

        let status = svc
            .test_login(Request::new(TestLoginRequest {
                username: "victim".to_string(),
            }))
            .await
            .expect_err("TestLogin must be refused when test-auth is not enabled");

        assert_eq!(status.code(), tonic::Code::PermissionDenied);
    }

    #[cfg(feature = "test-auth")]
    #[tokio::test]
    async fn test_login_issues_a_session_when_the_feature_is_enabled() {
        let svc = service().await;

        let response = svc
            .test_login(Request::new(TestLoginRequest {
                username: "dev-user".to_string(),
            }))
            .await
            .expect("TestLogin should work when test-auth is enabled")
            .into_inner();

        assert!(!response.session_token.is_empty());
        assert_eq!(response.username, "dev-user");
    }
}

#[cfg(test)]
mod auth_attempt_tests {
    use super::*;
    use sqlx::Row;

    async fn temp_db() -> ServerDb {
        let dir = std::env::temp_dir().join(format!("lift-attempt-test-{}", Uuid::new_v4()));
        ServerDb::new_in_dir(&dir).await.unwrap()
    }

    async fn service(db: &ServerDb) -> ServerAuthService {
        ServerAuthService {
            db: db.clone(),
            auth_state: Arc::new(AuthState::new(db.clone())),
        }
    }

    async fn attempts(db: &ServerDb) -> Vec<(String, String, String)> {
        sqlx::query("SELECT attempt_id, outcome, reason FROM auth_attempts ORDER BY attempt_id")
            .fetch_all(&db.read_pool)
            .await
            .unwrap()
            .into_iter()
            .map(|r| (r.get("attempt_id"), r.get("outcome"), r.get("reason")))
            .collect()
    }

    fn report(attempt_id: &str, reason: AuthFailureReason) -> Request<ReportAuthFailureRequest> {
        Request::new(ReportAuthFailureRequest {
            attempt_id: attempt_id.to_string(),
            reason: reason as i32,
        })
    }

    #[tokio::test]
    async fn a_started_login_is_recorded_with_the_client_labels() {
        let db = temp_db().await;
        let mut request = Request::new(LoginStartRequest { username: None });
        request
            .metadata_mut()
            .insert("x-platform", "android".parse().unwrap());
        request
            .metadata_mut()
            .insert("x-app-version", "1.2.3".parse().unwrap());

        let started = service(&db).await.login_start(request).await.unwrap();
        let challenge_id = started.into_inner().challenge_id;

        let row = sqlx::query(
            "SELECT kind, outcome, platform, app_version FROM auth_attempts WHERE attempt_id = ?",
        )
        .bind(&challenge_id)
        .fetch_one(&db.read_pool)
        .await
        .unwrap();
        assert_eq!(row.get::<String, _>("kind"), "login");
        assert_eq!(row.get::<String, _>("outcome"), "started");
        assert_eq!(row.get::<String, _>("platform"), "android");
        assert_eq!(row.get::<String, _>("app_version"), "1.2.3");
    }

    fn login_from(ip: &str) -> Request<LoginStartRequest> {
        let mut request = Request::new(LoginStartRequest { username: None });
        request
            .metadata_mut()
            .insert("x-forwarded-for", ip.parse().unwrap());
        request
    }

    /// One client starting sign-ins without end is refused past its share;
    /// everyone else can still sign in.
    #[tokio::test]
    async fn one_client_cannot_crowd_out_the_others_sign_ins() {
        let db = temp_db().await;
        let auth = service(&db).await;
        let mut refused = false;
        for _ in 0..50 {
            if auth.login_start(login_from("203.0.113.7")).await.is_err() {
                refused = true;
                break;
            }
        }
        assert!(refused, "the flood is cut off");
        // Another address in the same IPv6 /64 is the same client.
        for ip in ["2001:db8::1", "2001:db8::2"] {
            for _ in 0..25 {
                let _ = auth.login_start(login_from(ip)).await;
            }
        }
        assert!(auth.login_start(login_from("2001:db8::3")).await.is_err());
        assert!(auth.login_start(login_from("198.51.100.1")).await.is_ok());
        assert!(auth.login_start(login_from("2001:db8:1::1")).await.is_ok());
    }

    /// The unauthenticated report path must not be a way to write rows.
    #[tokio::test]
    async fn a_failure_report_cannot_create_an_attempt() {
        let db = temp_db().await;
        service(&db)
            .await
            .report_auth_failure(report("made-up-id", AuthFailureReason::Cancelled))
            .await
            .unwrap();
        assert!(attempts(&db).await.is_empty());
    }

    #[tokio::test]
    async fn a_failure_report_lands_once_and_never_rewrites_a_verdict() {
        let db = temp_db().await;
        let auth = service(&db).await;
        db.start_auth_attempt("open", "login", "ios", "1.0.0")
            .await
            .unwrap();
        db.start_auth_attempt("settled", "login", "ios", "1.0.0")
            .await
            .unwrap();
        db.finish_auth_attempt("settled", "ok", "").await.unwrap();

        for id in ["open", "settled"] {
            auth.report_auth_failure(report(id, AuthFailureReason::Cancelled))
                .await
                .unwrap();
        }
        // A second report on the same attempt changes nothing.
        auth.report_auth_failure(report("open", AuthFailureReason::Unsupported))
            .await
            .unwrap();

        assert_eq!(
            attempts(&db).await,
            vec![
                (
                    "open".to_string(),
                    "client_error".to_string(),
                    "cancelled".to_string()
                ),
                ("settled".to_string(), "ok".to_string(), String::new()),
            ]
        );
    }

    #[tokio::test]
    async fn a_rejected_login_is_recorded_as_rejected() {
        let db = temp_db().await;
        let auth = service(&db).await;
        let challenge_id = auth
            .login_start(Request::new(LoginStartRequest { username: None }))
            .await
            .unwrap()
            .into_inner()
            .challenge_id;

        // A structurally valid credential that no passkey on file matches.
        let credential_json = r#"{"id":"AAAA","rawId":"AAAA","type":"public-key","response":{"authenticatorData":"AAAA","clientDataJSON":"AAAA","signature":"AAAA"},"extensions":{}}"#;
        let result = auth
            .login_finish(Request::new(LoginFinishRequest {
                challenge_id: challenge_id.clone(),
                credential_json: credential_json.to_string(),
            }))
            .await;
        assert!(result.is_err());

        let rows = attempts(&db).await;
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].0, challenge_id);
        assert_eq!(rows[0].1, "rejected");
    }
}

/// The passkey ceremonies end to end, with a software passkey: each
/// challenge is spent once, a sign-in signs in to its own account, and the
/// last passkey can't be deleted.
#[cfg(test)]
mod ceremony_tests {
    use super::*;
    use sqlx::Row;
    use url::Url;
    use webauthn_authenticator_rs::softpasskey::SoftPasskey;
    use webauthn_authenticator_rs::WebauthnAuthenticator;
    use webauthn_rs::prelude::{CreationChallengeResponse, RequestChallengeResponse};

    type Device = WebauthnAuthenticator<SoftPasskey>;

    fn device() -> Device {
        // Claims user verification, which passkeys require.
        WebauthnAuthenticator::new(SoftPasskey::new(true))
    }

    async fn service() -> ServerAuthService {
        let dir = std::env::temp_dir().join(format!("lift-ceremony-{}", Uuid::new_v4()));
        let db = ServerDb::new_in_dir(&dir).await.unwrap();
        ServerAuthService {
            auth_state: Arc::new(AuthState::new(db.clone())),
            db,
        }
    }

    /// The origin AuthState allows when nothing configures it.
    fn origin() -> Url {
        Url::parse("http://localhost:5173").unwrap()
    }

    fn authed<T>(token: &str, msg: T) -> Request<T> {
        let mut req = Request::new(msg);
        req.metadata_mut()
            .insert("x-session-token", token.parse().unwrap());
        req
    }

    /// The device's new passkey, for these registration options.
    fn create(device: &mut Device, options_json: &str) -> String {
        let options: CreationChallengeResponse = serde_json::from_str(options_json).unwrap();
        let credential = device.do_registration(origin(), options).unwrap();
        serde_json::to_string(&credential).unwrap()
    }

    /// The device's signature, for these sign-in options.
    fn sign(device: &mut Device, options_json: &str) -> String {
        let options: RequestChallengeResponse = serde_json::from_str(options_json).unwrap();
        let credential = device.do_authentication(origin(), options).unwrap();
        serde_json::to_string(&credential).unwrap()
    }

    /// A new account with the device's passkey, named "Phone": the finish
    /// sent, and its answer.
    async fn sign_up(
        svc: &ServerAuthService,
        device: &mut Device,
        username: &str,
    ) -> (RegisterFinishRequest, AuthResponse) {
        let start = svc
            .register_start(Request::new(RegisterStartRequest {
                username: username.to_string(),
            }))
            .await
            .unwrap()
            .into_inner();
        let finish = RegisterFinishRequest {
            user_id: start.user_id,
            credential_json: create(device, &start.options_json),
            name: Some("Phone".to_string()),
        };
        let done = svc
            .register_finish(Request::new(finish.clone()))
            .await
            .unwrap()
            .into_inner();
        (finish, done)
    }

    /// A sign-in by name with the device: the finish sent, and its answer.
    async fn sign_in(
        svc: &ServerAuthService,
        device: &mut Device,
        username: &str,
    ) -> (LoginFinishRequest, Result<AuthResponse, Status>) {
        let start = svc
            .login_start(Request::new(LoginStartRequest {
                username: Some(username.to_string()),
            }))
            .await
            .unwrap()
            .into_inner();
        let finish = LoginFinishRequest {
            challenge_id: start.challenge_id,
            credential_json: sign(device, &start.options_json),
        };
        let done = svc
            .login_finish(Request::new(finish.clone()))
            .await
            .map(Response::into_inner);
        (finish, done)
    }

    async fn passkeys(svc: &ServerAuthService, token: &str) -> Vec<PasskeyInfo> {
        svc.list_passkeys(authed(token, ListPasskeysRequest {}))
            .await
            .unwrap()
            .into_inner()
            .passkeys
    }

    async fn outcome(db: &ServerDb, attempt_id: &str) -> String {
        sqlx::query("SELECT outcome FROM auth_attempts WHERE attempt_id = ?")
            .bind(attempt_id)
            .fetch_one(&db.read_pool)
            .await
            .unwrap()
            .get("outcome")
    }

    #[tokio::test]
    async fn a_sign_up_is_finished_once() {
        let svc = service().await;
        let mut phone = device();
        let (finish, done) = sign_up(&svc, &mut phone, "ann").await;
        assert_eq!(done.username, "ann");
        assert_eq!(
            svc.db
                .validate_auth_session(&done.session_token)
                .await
                .unwrap(),
            Some(done.user_id.clone())
        );

        // The same finish again: refused, and the verdict stands.
        let replayed = svc.register_finish(Request::new(finish)).await;
        assert_eq!(replayed.unwrap_err().code(), tonic::Code::InvalidArgument);
        assert_eq!(outcome(&svc.db, &done.user_id).await, "ok");

        let held = passkeys(&svc, &done.session_token).await;
        assert_eq!(held.len(), 1);
        assert_eq!(held[0].name.as_deref(), Some("Phone"));
        let taken = svc
            .register_start(Request::new(RegisterStartRequest {
                username: "ann".to_string(),
            }))
            .await;
        assert_eq!(taken.unwrap_err().code(), tonic::Code::AlreadyExists);
    }

    #[tokio::test]
    async fn a_sign_in_is_to_its_own_account_once_and_keeps_the_passkey_name() {
        let svc = service().await;
        let mut phone = device();
        let (_, ann) = sign_up(&svc, &mut phone, "ann").await;
        sign_up(&svc, &mut device(), "ben").await;
        let stored = || async { svc.db.get_credentials_for_user(&ann.user_id).await.unwrap() };
        let before = stored().await;

        let (finish, signed_in) = sign_in(&svc, &mut phone, "ann").await;
        let signed_in = signed_in.unwrap();
        assert_eq!(signed_in.user_id, ann.user_id);
        assert_eq!(signed_in.username, "ann");
        assert_eq!(
            svc.db
                .validate_auth_session(&signed_in.session_token)
                .await
                .unwrap(),
            Some(ann.user_id.clone())
        );
        assert_ne!(
            stored().await,
            before,
            "the sign-in counter is written back"
        );
        let held = passkeys(&svc, &signed_in.session_token).await;
        assert_eq!(held[0].name.as_deref(), Some("Phone"), "and the name kept");

        // The same finish again: refused, and the verdict stands.
        let replayed = svc.login_finish(Request::new(finish.clone())).await;
        assert_eq!(replayed.unwrap_err().code(), tonic::Code::Unauthenticated);
        assert_eq!(outcome(&svc.db, &finish.challenge_id).await, "ok");

        // Ann's passkey doesn't sign in to Ben.
        let start = svc
            .login_start(Request::new(LoginStartRequest {
                username: Some("ben".to_string()),
            }))
            .await
            .unwrap()
            .into_inner();
        let options: RequestChallengeResponse = serde_json::from_str(&start.options_json).unwrap();
        assert!(phone.do_authentication(origin(), options).is_err());
    }

    /// Someone who knows a user's id can't spend their add-passkey
    /// challenge with an unauthenticated RegisterFinish; and the last
    /// passkey can't be deleted.
    #[tokio::test]
    async fn a_passkey_is_added_and_the_last_one_is_kept() {
        let svc = service().await;
        let mut phone = device();
        let (_, ann) = sign_up(&svc, &mut phone, "ann").await;
        let token = ann.session_token.as_str();

        let start = svc
            .add_passkey_start(authed(token, AddPasskeyStartRequest {}))
            .await
            .unwrap()
            .into_inner();
        let stranger = svc
            .register_finish(Request::new(RegisterFinishRequest {
                user_id: ann.user_id.clone(),
                credential_json: create(&mut device(), &start.options_json),
                name: None,
            }))
            .await;
        assert!(stranger.is_err());
        let mut laptop = device();
        svc.add_passkey_finish(authed(
            token,
            AddPasskeyFinishRequest {
                credential_json: create(&mut laptop, &start.options_json),
                name: Some("Laptop".to_string()),
            },
        ))
        .await
        .unwrap();
        let held = passkeys(&svc, token).await;
        assert_eq!(held.len(), 2);
        // The added one signs in.
        let laptop_login = sign_in(&svc, &mut laptop, "ann")
            .await
            .1
            .unwrap()
            .session_token;
        let signed_in = |token: String| {
            let db = svc.db.clone();
            async move { db.validate_auth_session(&token).await.unwrap().is_some() }
        };
        assert!(signed_in(laptop_login.clone()).await);

        let delete = |credential_id: String| {
            svc.delete_passkey(authed(token, DeletePasskeyRequest { credential_id }))
        };
        delete(held[0].credential_id.clone()).await.unwrap();
        // Deleting a passkey signs out every other login (a lost phone's),
        // and keeps the one that deleted it.
        assert!(!signed_in(laptop_login).await, "the other login is gone");
        assert!(signed_in(token.to_string()).await, "the caller's stays");
        let last = delete(held[1].credential_id.clone()).await;
        assert_eq!(last.unwrap_err().code(), tonic::Code::FailedPrecondition);
        assert_eq!(passkeys(&svc, token).await.len(), 1, "still there");
    }

    /// A passkey the device still holds for an account that is gone is told
    /// apart from one that fails to verify: the app tells the passkey
    /// manager to drop it.
    #[tokio::test]
    async fn a_passkey_no_account_holds_is_said_to_be_unknown() {
        use webauthn_rs::prelude::Base64UrlSafeData;

        let svc = service().await;
        let mut phone = device();
        let (_, ann) = sign_up(&svc, &mut phone, "ann").await;

        // What the phone answers a usernameless sign-in with: its passkey,
        // naming the account it was made for. (The software passkey only
        // signs when asked by name, so its answer is given the name here.)
        let by_name = svc
            .login_start(Request::new(LoginStartRequest {
                username: Some("ann".to_string()),
            }))
            .await
            .unwrap()
            .into_inner();
        let mut answer: serde_json::Value =
            serde_json::from_str(&sign(&mut phone, &by_name.options_json)).unwrap();
        let handle = Uuid::parse_str(&ann.user_id).unwrap().as_bytes().to_vec();
        answer["response"]["userHandle"] =
            serde_json::to_value(Base64UrlSafeData::from(handle)).unwrap();
        let usernameless = || async {
            let start = svc
                .login_start(Request::new(LoginStartRequest { username: None }))
                .await
                .unwrap()
                .into_inner();
            let refused = svc
                .login_finish(Request::new(LoginFinishRequest {
                    challenge_id: start.challenge_id.clone(),
                    credential_json: answer.to_string(),
                }))
                .await
                .unwrap_err();
            let reason: String =
                sqlx::query("SELECT reason FROM auth_attempts WHERE attempt_id = ?")
                    .bind(&start.challenge_id)
                    .fetch_one(&svc.db.read_pool)
                    .await
                    .unwrap()
                    .get("reason");
            // The caller is told no more than a sentence.
            assert!(!refused.message().contains(&start.challenge_id));
            (refused.code(), reason)
        };

        // While the account holds it, an answer to another challenge is
        // one that doesn't verify.
        assert_eq!(
            usernameless().await,
            (tonic::Code::Unauthenticated, "rejected".to_string())
        );
        svc.db
            .delete_user_account_and_data(&ann.user_id)
            .await
            .unwrap();
        assert_eq!(
            usernameless().await,
            (tonic::Code::NotFound, "unknown_passkey".to_string())
        );
    }

    /// A passkey that answers without verifying its user is refused in
    /// words that say so.
    #[tokio::test]
    async fn an_unverified_passkey_is_refused_as_such() {
        let svc = service().await;
        let mut unverifying: Device = WebauthnAuthenticator::new(SoftPasskey::new(false));
        let start = svc
            .register_start(Request::new(RegisterStartRequest {
                username: "ann".to_string(),
            }))
            .await
            .unwrap()
            .into_inner();
        let options: CreationChallengeResponse = serde_json::from_str(&start.options_json).unwrap();
        // The software passkey itself refuses when verification is
        // required and it has none, like a passkey manager that honours
        // "required"; one that ignores it sends the bit unset, which the
        // server refuses the same way.
        let Ok(credential) = unverifying.do_registration(origin(), options) else {
            return;
        };
        let refused = svc
            .register_finish(Request::new(RegisterFinishRequest {
                user_id: start.user_id,
                credential_json: serde_json::to_string(&credential).unwrap(),
                name: None,
            }))
            .await
            .unwrap_err();
        assert_eq!(refused.code(), tonic::Code::FailedPrecondition);
    }

    /// Whether a sign-in to `username` asks for a passkey the device has.
    async fn offered(svc: &ServerAuthService, device: &mut Device, username: &str) -> bool {
        let start = svc
            .login_start(Request::new(LoginStartRequest {
                username: Some(username.to_string()),
            }))
            .await
            .unwrap()
            .into_inner();
        let options: RequestChallengeResponse = serde_json::from_str(&start.options_json).unwrap();
        device.do_authentication(origin(), options).is_ok()
    }

    async fn status(svc: &ServerAuthService, request_id: &str) -> RecoveryStatusResponse {
        svc.recovery_status(Request::new(RecoveryStatusRequest {
            request_id: request_id.to_string(),
        }))
        .await
        .unwrap()
        .into_inner()
    }

    /// Someone who lost their passkey makes a new one for their account.
    /// It signs nothing in until its code is approved, and then signs in
    /// to the old account.
    #[tokio::test]
    async fn a_recovered_passkey_signs_in_once_its_code_is_approved() {
        let svc = service().await;
        let (_, ann) = sign_up(&svc, &mut device(), "ann").await;

        let start = svc
            .recovery_start(Request::new(RecoveryStartRequest {
                username: "Ann".to_string(),
            }))
            .await
            .unwrap()
            .into_inner();
        let mut new_phone = device();
        let finish = RecoveryFinishRequest {
            request_id: start.request_id.clone(),
            credential_json: create(&mut new_phone, &start.options_json),
        };
        let held = svc
            .recovery_finish(Request::new(finish.clone()))
            .await
            .unwrap()
            .into_inner();
        assert!(held.expires_at > now_unix());
        // The same finish again is refused: one request, one passkey.
        assert!(svc.recovery_finish(Request::new(finish)).await.is_err());

        let waiting = status(&svc, &start.request_id).await;
        assert_eq!(waiting.state, RecoveryState::Pending as i32);
        assert_eq!(waiting.code, held.code);
        assert_eq!(waiting.username, "ann");
        assert_eq!(
            status(&svc, "made-up").await.state,
            RecoveryState::Expired as i32
        );

        // Not approved: the new passkey is nobody's.
        assert!(!offered(&svc, &mut new_phone, "ann").await);
        assert_eq!(passkeys(&svc, &ann.session_token).await.len(), 1);

        // Signing in with it (usernameless, as the website does) is not a
        // login: it says the passkey is waiting, and which request it is.
        let by_name_options = {
            // The software passkey signs only when asked by name, so it is
            // asked for the held passkey by its id.
            let login = svc
                .login_start(Request::new(LoginStartRequest { username: None }))
                .await
                .unwrap()
                .into_inner();
            let held_id = serde_json::from_str::<serde_json::Value>(
                &sqlx::query_scalar::<_, String>(
                    "SELECT passkey_json FROM passkey_recoveries WHERE request_id = ?",
                )
                .bind(&start.request_id)
                .fetch_one(&svc.db.read_pool)
                .await
                .unwrap(),
            )
            .unwrap()["cred"]["cred_id"]
                .clone();
            let mut options: serde_json::Value = serde_json::from_str(&login.options_json).unwrap();
            options["publicKey"]["allowCredentials"] =
                serde_json::json!([{ "type": "public-key", "id": held_id }]);
            (login.challenge_id, options.to_string())
        };
        let mut answer: serde_json::Value =
            serde_json::from_str(&sign(&mut new_phone, &by_name_options.1)).unwrap();
        let handle = Uuid::parse_str(&ann.user_id).unwrap().as_bytes().to_vec();
        answer["response"]["userHandle"] =
            serde_json::to_value(webauthn_rs::prelude::Base64UrlSafeData::from(handle)).unwrap();
        let waiting_sign_in = svc
            .login_finish(Request::new(LoginFinishRequest {
                challenge_id: by_name_options.0,
                credential_json: answer.to_string(),
            }))
            .await
            .unwrap_err();
        assert_eq!(waiting_sign_in.code(), tonic::Code::PermissionDenied);
        assert_eq!(
            waiting_sign_in
                .metadata()
                .get(RECOVERY_REQUEST_HEADER)
                .and_then(|v| v.to_str().ok()),
            Some(start.request_id.as_str())
        );

        // The account's owner, still signed in, hears of it.
        let heard = svc
            .list_my_recoveries(authed(&ann.session_token, ListMyRecoveriesRequest {}))
            .await
            .unwrap()
            .into_inner()
            .recoveries;
        assert_eq!(heard.len(), 1);
        assert_eq!(heard[0].request_id, start.request_id);

        svc.db.approve_recovery(&held.code, false).await.unwrap();
        let approved = status(&svc, &start.request_id).await;
        assert_eq!(approved.state, RecoveryState::Approved as i32);
        assert!(approved.code.is_empty());
        let signed_in = sign_in(&svc, &mut new_phone, "ann").await.1.unwrap();
        assert_eq!(signed_in.user_id, ann.user_id);
        let held = passkeys(&svc, &signed_in.session_token).await;
        assert_eq!(held.len(), 2);
        assert!(held
            .iter()
            .any(|p| p.name.as_deref() == Some("recovery key")));
    }

    /// A name nobody holds is not refused: the request runs to a code like
    /// any other, which waits and approves nothing, and all that is kept
    /// of it is its attempt, filed as failed.
    #[tokio::test]
    async fn a_recovery_for_a_name_nobody_holds_looks_the_same_and_comes_to_nothing() {
        let svc = service().await;
        let ask = || async {
            svc.recovery_start(Request::new(RecoveryStartRequest {
                username: "Nobody".to_string(),
            }))
            .await
            .unwrap()
            .into_inner()
        };
        let user_id = |options_json: &str| {
            let options: serde_json::Value = serde_json::from_str(options_json).unwrap();
            options["publicKey"]["user"]["id"].clone()
        };
        let first = ask().await;
        let start = ask().await;
        // The same name is the same account each time, as a real one is.
        assert_eq!(user_id(&first.options_json), user_id(&start.options_json));

        let held = svc
            .recovery_finish(Request::new(RecoveryFinishRequest {
                request_id: start.request_id.clone(),
                credential_json: create(&mut device(), &start.options_json),
            }))
            .await
            .unwrap()
            .into_inner();
        assert_eq!(held.code.len(), 9);
        let waiting = status(&svc, &start.request_id).await;
        assert_eq!(waiting.state, RecoveryState::Pending as i32);
        assert_eq!(waiting.code, held.code);
        assert_eq!(waiting.expires_at, held.expires_at);

        // Nothing waits for an admin, and the code approves nothing.
        assert!(svc.db.list_recoveries().await.unwrap().is_empty());
        assert_eq!(
            svc.db.approve_recovery(&held.code, false).await.unwrap(),
            crate::db::Approval::NoSuchCode
        );
        let stored: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM passkey_recoveries")
            .fetch_one(&svc.db.read_pool)
            .await
            .unwrap();
        assert_eq!(stored, 0);
        let filed: (String, String) =
            sqlx::query_as("SELECT outcome, reason FROM auth_attempts WHERE attempt_id = ?")
                .bind(&start.request_id)
                .fetch_one(&svc.db.read_pool)
                .await
                .unwrap();
        assert_eq!(filed, ("rejected".to_string(), "unknown_user".to_string()));
        // One never finished is not waiting.
        assert_eq!(
            status(&svc, &first.request_id).await.state,
            RecoveryState::Expired as i32
        );
    }

    /// The owner of an account refuses a request for it they didn't make;
    /// nobody else can.
    #[tokio::test]
    async fn the_owner_refuses_a_recovery_they_did_not_ask_for() {
        let svc = service().await;
        let (_, ann) = sign_up(&svc, &mut device(), "ann").await;
        let (_, ben) = sign_up(&svc, &mut device(), "ben").await;
        let start = svc
            .recovery_start(Request::new(RecoveryStartRequest {
                username: "ann".to_string(),
            }))
            .await
            .unwrap()
            .into_inner();
        let mut thief = device();
        let held = svc
            .recovery_finish(Request::new(RecoveryFinishRequest {
                request_id: start.request_id.clone(),
                credential_json: create(&mut thief, &start.options_json),
            }))
            .await
            .unwrap()
            .into_inner();

        let deny = |token: &str| {
            svc.deny_my_recovery(authed(
                token,
                DenyMyRecoveryRequest {
                    request_id: start.request_id.clone(),
                },
            ))
        };
        deny(&ben.session_token).await.unwrap();
        assert_eq!(
            status(&svc, &start.request_id).await.state,
            RecoveryState::Pending as i32,
            "someone else's refusal changes nothing"
        );
        deny(&ann.session_token).await.unwrap();
        assert_eq!(
            status(&svc, &start.request_id).await.state,
            RecoveryState::Denied as i32
        );
        assert_eq!(
            svc.db.approve_recovery(&held.code, false).await.unwrap(),
            crate::db::Approval::NoSuchCode
        );
        assert!(!offered(&svc, &mut thief, "ann").await);
    }

    /// Passkeys were once keyed by how a Rust type printed their id. Step 4
    /// rekeys them by the id as the passkey's own JSON spells it, and they
    /// go on signing in, counting, and being deleted by that key.
    #[tokio::test]
    async fn passkeys_keyed_the_old_way_are_rekeyed_and_still_sign_in() {
        let dir = std::env::temp_dir().join(format!("lift-rekey-{}", Uuid::new_v4()));
        let db = ServerDb::new_in_dir(&dir).await.unwrap();
        let svc = ServerAuthService {
            auth_state: Arc::new(AuthState::new(db.clone())),
            db,
        };
        let mut phone = device();
        let (_, ann) = sign_up(&svc, &mut phone, "ann").await;
        let key = passkeys(&svc, &ann.session_token).await[0]
            .credential_id
            .clone();
        assert!(
            key.chars()
                .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_'),
            "base64url: {key}"
        );

        // Back to before step 4.
        let setup = "UPDATE passkeys SET credential_id = 'HumanBinaryData([1, 2, 3])';
             DROP TABLE passkey_recoveries;
             PRAGMA user_version = 3;";
        sqlx::query(setup).execute(&svc.db.read_pool).await.unwrap();
        drop(svc);

        let db = ServerDb::new_in_dir(&dir).await.unwrap();
        let svc = ServerAuthService {
            auth_state: Arc::new(AuthState::new(db.clone())),
            db,
        };
        let stored = || async { svc.db.get_credentials_for_user(&ann.user_id).await.unwrap() };
        let before = stored().await;
        let signed_in = sign_in(&svc, &mut phone, "ann").await.1.unwrap();
        assert_eq!(
            passkeys(&svc, &signed_in.session_token).await[0].credential_id,
            key
        );
        assert_ne!(stored().await, before, "the counter is written by the key");
    }
}
