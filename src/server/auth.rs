use super::*;
use crate::auth::AuthState;
use std::sync::Arc;
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
        let token = request
            .metadata()
            .get("x-session-token")
            .and_then(|v| v.to_str().ok())
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
        let req = request.into_inner();
        let username = req.username.trim().to_string();
        info!(rpc = "RegisterStart", %username, "request");
        if username.is_empty() {
            return Err(Status::invalid_argument("username is required"));
        }
        if username.contains(' ') {
            return Err(Status::invalid_argument("username cannot contain spaces"));
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
            .start_registration(&username)
            .await
            .map_err(Status::internal)?;
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
        let remote_addr = request.remote_addr().map(|a| a.ip().to_string());
        let req = request.into_inner();
        info!(rpc = "RegisterFinish", user_id = %req.user_id, "request");
        let credential: RegisterPublicKeyCredential = serde_json::from_str(&req.credential_json)
            .map_err(|e| Status::invalid_argument(format!("Invalid credential JSON: {}", e)))?;
        let username = match self
            .auth_state
            .finish_registration(&req.user_id, &credential, remote_addr, req.name)
            .await
        {
            Ok(username) => username,
            Err(e) => {
                self.track_attempt_finish(&req.user_id, "rejected", &e).await;
                return Err(Status::invalid_argument(e));
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
        let req = request.into_inner();
        info!(rpc = "LoginStart", "request");
        let (challenge_id, options) = match req.username.as_deref() {
            Some(username) if !username.trim().is_empty() => self
                .auth_state
                .start_authentication_with_username(username.trim())
                .await
                .map_err(Status::invalid_argument)?,
            _ => self
                .auth_state
                .start_authentication()
                .await
                .map_err(Status::internal)?,
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
            .finish_authentication(&req.challenge_id, &req.credential_json, &credential)
            .await
        {
            Ok(session) => session,
            Err(e) => {
                self.track_attempt_finish(&req.challenge_id, "rejected", &e)
                    .await;
                return Err(Status::unauthenticated(e));
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
            .start_add_passkey(&user_id, &user.name)
            .await
            .map_err(Status::internal)?;
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
        let remote_addr = request.remote_addr().map(|a| a.ip().to_string());
        let req = request.into_inner();
        let credential: RegisterPublicKeyCredential = serde_json::from_str(&req.credential_json)
            .map_err(|e| Status::invalid_argument(format!("Invalid credential JSON: {}", e)))?;
        self.auth_state
            .finish_add_passkey(&user_id, &credential, remote_addr, req.name)
            .await
            .map_err(Status::invalid_argument)?;
        Ok(Response::new(AddPasskeyFinishResponse {}))
    }
    async fn delete_passkey(
        &self,
        request: Request<DeletePasskeyRequest>,
    ) -> Result<Response<DeletePasskeyResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "DeletePasskey", %user_id, "request");
        let req = request.into_inner();
        self.db
            .delete_credential(&user_id, &req.credential_id)
            .await
            .map_err(|e| Status::invalid_argument(e.to_string()))?;
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
        if let Some(token) = request
            .metadata()
            .get("x-session-token")
            .and_then(|v| v.to_str().ok())
        {
            let _ = self.db.delete_auth_session(token).await;
        }
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

        let row = sqlx::query("SELECT kind, outcome, platform, app_version FROM auth_attempts WHERE attempt_id = ?")
            .bind(&challenge_id)
            .fetch_one(&db.read_pool)
            .await
            .unwrap();
        assert_eq!(row.get::<String, _>("kind"), "login");
        assert_eq!(row.get::<String, _>("outcome"), "started");
        assert_eq!(row.get::<String, _>("platform"), "android");
        assert_eq!(row.get::<String, _>("app_version"), "1.2.3");
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
        db.start_auth_attempt("open", "login", "ios", "1.0.0").await.unwrap();
        db.start_auth_attempt("settled", "login", "ios", "1.0.0").await.unwrap();
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
                ("open".to_string(), "client_error".to_string(), "cancelled".to_string()),
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
