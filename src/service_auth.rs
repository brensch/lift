use crate::auth::AuthState;
#[cfg(feature = "test-auth")]
use crate::service_auth_test::handle_test_login;
use crate::service_workout::get_user_id_authenticated;
use schlift::workout::v1::{
    auth_service_server::AuthService, AddPasskeyFinishRequest, AddPasskeyFinishResponse,
    AddPasskeyStartRequest, AddPasskeyStartResponse, AuthResponse, DeleteAccountRequest,
    DeleteAccountResponse, DeletePasskeyRequest, DeletePasskeyResponse, ListPasskeysRequest,
    ListPasskeysResponse, LoginFinishRequest, LoginStartRequest, LoginStartResponse, LogoutRequest,
    LogoutResponse, PasskeyInfo, RegisterFinishRequest, RegisterStartRequest,
    RegisterStartResponse, TestLoginRequest,
};
use std::sync::Arc;
use tonic::{Request, Response, Status};
use webauthn_rs::prelude::*;

use crate::state::AppState;

pub struct MyAuthService {
    pub auth_state: Arc<AuthState>,
    pub app_state: Arc<AppState>,
}

#[tonic::async_trait]
impl AuthService for MyAuthService {
    async fn register_start(
        &self,
        request: Request<RegisterStartRequest>,
    ) -> Result<Response<RegisterStartResponse>, Status> {
        let req = request.into_inner();
        let username = req.username.trim().to_string();
        if username.is_empty() {
            return Err(Status::invalid_argument("username is required"));
        }
        if username.contains(' ') {
            return Err(Status::invalid_argument("username cannot contain spaces"));
        }

        let existing = self
            .auth_state
            .central_db
            .get_user_by_name(&username)
            .await
            .map_err(|e| Status::internal(e.to_string()))?;
        if existing.is_some() {
            return Err(Status::already_exists("User already exists"));
        }

        let (user_id, options) = self
            .auth_state
            .start_registration(&username)
            .await
            .map_err(|e| Status::internal(e))?;

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

        let credential: RegisterPublicKeyCredential = serde_json::from_str(&req.credential_json)
            .map_err(|e| Status::invalid_argument(format!("Invalid credential JSON: {}", e)))?;

        let username = self
            .auth_state
            .finish_registration(&req.user_id, &credential, remote_addr, req.name)
            .await
            .map_err(|e| Status::invalid_argument(e))?;

        let token = self
            .auth_state
            .central_db
            .create_auth_session(&req.user_id)
            .await
            .map_err(|e| Status::internal(e.to_string()))?;

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
        let (challenge_id, options) = match req.username.as_deref() {
            Some(username) if !username.trim().is_empty() => self
                .auth_state
                .start_authentication_with_username(username.trim())
                .await
                .map_err(|e| Status::invalid_argument(e))?,
            _ => self
                .auth_state
                .start_authentication()
                .await
                .map_err(|e| Status::internal(e))?,
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
        let credential: PublicKeyCredential = serde_json::from_str(&req.credential_json)
            .map_err(|e| Status::invalid_argument(format!("Invalid credential JSON: {}", e)))?;

        let (token, user_id, username) = self
            .auth_state
            .finish_authentication(&req.challenge_id, &req.credential_json, &credential)
            .await
            .map_err(|e| Status::unauthenticated(e))?;

        Ok(Response::new(AuthResponse {
            session_token: token,
            user_id,
            username,
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

        self.auth_state
            .central_db
            .invalidate_auth_session(token)
            .await
            .map_err(|e| Status::internal(e.to_string()))?;

        Ok(Response::new(LogoutResponse {}))
    }

    async fn add_passkey_start(
        &self,
        request: Request<AddPasskeyStartRequest>,
    ) -> Result<Response<AddPasskeyStartResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.auth_state.central_db).await?;

        let user = self
            .auth_state
            .central_db
            .get_user(&user_id)
            .await
            .map_err(|e| Status::internal(e.to_string()))?
            .ok_or_else(|| Status::not_found("User not found"))?;

        let options = self
            .auth_state
            .start_add_passkey(&user_id, &user.name)
            .await
            .map_err(|e| Status::internal(e))?;

        let options_json =
            serde_json::to_string(&options).map_err(|e| Status::internal(e.to_string()))?;

        Ok(Response::new(AddPasskeyStartResponse { options_json }))
    }

    async fn add_passkey_finish(
        &self,
        request: Request<AddPasskeyFinishRequest>,
    ) -> Result<Response<AddPasskeyFinishResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.auth_state.central_db).await?;
        let remote_addr = request.remote_addr().map(|a| a.ip().to_string());
        let req = request.into_inner();

        let credential: RegisterPublicKeyCredential = serde_json::from_str(&req.credential_json)
            .map_err(|e| Status::invalid_argument(format!("Invalid credential JSON: {}", e)))?;

        self.auth_state
            .finish_add_passkey(&user_id, &credential, remote_addr, req.name)
            .await
            .map_err(|e| Status::invalid_argument(e))?;

        Ok(Response::new(AddPasskeyFinishResponse {}))
    }

    async fn delete_passkey(
        &self,
        request: Request<DeletePasskeyRequest>,
    ) -> Result<Response<DeletePasskeyResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.auth_state.central_db).await?;
        let req = request.into_inner();

        self.auth_state
            .central_db
            .delete_credential(&user_id, &req.credential_id)
            .await
            .map_err(|e| Status::invalid_argument(e.to_string()))?;

        Ok(Response::new(DeletePasskeyResponse {}))
    }

    async fn list_passkeys(
        &self,
        request: Request<ListPasskeysRequest>,
    ) -> Result<Response<ListPasskeysResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.auth_state.central_db).await?;

        let rows = self
            .auth_state
            .central_db
            .list_passkey_metadata(&user_id)
            .await
            .map_err(|e| Status::internal(e.to_string()))?;

        let passkeys: Vec<PasskeyInfo> = rows
            .into_iter()
            .map(
                |(credential_id, created_at, credential_json, created_at_ip)| {
                    let v: serde_json::Value =
                        serde_json::from_str(&credential_json).unwrap_or(serde_json::Value::Null);

                    let name = v
                        .get("cred_name")
                        .and_then(|n| n.as_str())
                        .map(|s| s.to_string());

                    let transports: Vec<String> = v
                        .get("transports")
                        .and_then(|t| t.as_array())
                        .map(|arr| {
                            arr.iter()
                                .filter_map(|v| v.as_str().map(String::from))
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

    async fn test_login(
        &self,
        request: Request<TestLoginRequest>,
    ) -> Result<Response<AuthResponse>, Status> {
        #[cfg(not(feature = "test-auth"))]
        {
            let _ = request;
            return Err(Status::unimplemented(
                "TestLogin is not available in this build",
            ));
        }

        #[cfg(feature = "test-auth")]
        {
            handle_test_login(self.auth_state.clone(), request).await
        }
    }

    async fn delete_account(
        &self,
        request: Request<DeleteAccountRequest>,
    ) -> Result<Response<DeleteAccountResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.auth_state.central_db).await?;

        self.auth_state
            .central_db
            .delete_user_account_and_data(&user_id)
            .await
            .map_err(|e| Status::internal(e.to_string()))?;

        self.app_state.remove_user_data(&user_id);

        // Invalidate the session token used for this request
        if let Some(token) = request
            .metadata()
            .get("x-session-token")
            .and_then(|v| v.to_str().ok())
        {
            let _ = self
                .auth_state
                .central_db
                .invalidate_auth_session(token)
                .await;
        }

        Ok(Response::new(DeleteAccountResponse {
            deleted_user_id: user_id,
        }))
    }
}
