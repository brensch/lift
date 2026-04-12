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

#[tonic::async_trait]
impl AuthService for ServerAuthService {
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
        let username = self
            .auth_state
            .finish_registration(&req.user_id, &credential, remote_addr, req.name)
            .await
            .map_err(Status::invalid_argument)?;
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
        let (token, user_id, username) = self
            .auth_state
            .finish_authentication(&req.challenge_id, &req.credential_json, &credential)
            .await
            .map_err(Status::unauthenticated)?;
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
}
