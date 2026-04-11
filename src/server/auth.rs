use super::*;

// ── Auth Service ──

#[derive(Clone)]
pub struct ServerAuthService {
    pub db: ServerDb,
}

#[tonic::async_trait]
impl AuthService for ServerAuthService {
    async fn test_login(
        &self,
        request: Request<TestLoginRequest>,
    ) -> Result<Response<AuthResponse>, Status> {
        let req = request.into_inner();
        let username = req.username.trim();
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
        self.db
            .delete_auth_session(token)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(LogoutResponse {}))
    }

    async fn register_start(
        &self,
        _r: Request<RegisterStartRequest>,
    ) -> Result<Response<RegisterStartResponse>, Status> {
        Err(Status::unimplemented(
            "server auth only supports TestLogin/Logout",
        ))
    }
    async fn register_finish(
        &self,
        _r: Request<RegisterFinishRequest>,
    ) -> Result<Response<AuthResponse>, Status> {
        Err(Status::unimplemented(
            "server auth only supports TestLogin/Logout",
        ))
    }
    async fn login_start(
        &self,
        _r: Request<LoginStartRequest>,
    ) -> Result<Response<LoginStartResponse>, Status> {
        Err(Status::unimplemented(
            "server auth only supports TestLogin/Logout",
        ))
    }
    async fn login_finish(
        &self,
        _r: Request<LoginFinishRequest>,
    ) -> Result<Response<AuthResponse>, Status> {
        Err(Status::unimplemented(
            "server auth only supports TestLogin/Logout",
        ))
    }
    async fn add_passkey_start(
        &self,
        _r: Request<AddPasskeyStartRequest>,
    ) -> Result<Response<AddPasskeyStartResponse>, Status> {
        Err(Status::unimplemented(
            "server auth only supports TestLogin/Logout",
        ))
    }
    async fn add_passkey_finish(
        &self,
        _r: Request<AddPasskeyFinishRequest>,
    ) -> Result<Response<AddPasskeyFinishResponse>, Status> {
        Err(Status::unimplemented(
            "server auth only supports TestLogin/Logout",
        ))
    }
    async fn delete_passkey(
        &self,
        _r: Request<DeletePasskeyRequest>,
    ) -> Result<Response<DeletePasskeyResponse>, Status> {
        Err(Status::unimplemented(
            "server auth only supports TestLogin/Logout",
        ))
    }
    async fn list_passkeys(
        &self,
        _r: Request<ListPasskeysRequest>,
    ) -> Result<Response<ListPasskeysResponse>, Status> {
        Err(Status::unimplemented(
            "server auth only supports TestLogin/Logout",
        ))
    }
    async fn delete_account(
        &self,
        _r: Request<DeleteAccountRequest>,
    ) -> Result<Response<DeleteAccountResponse>, Status> {
        Err(Status::unimplemented(
            "server auth only supports TestLogin/Logout",
        ))
    }
}
