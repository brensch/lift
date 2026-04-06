use crate::auth::AuthState;
use schlift::workout::v1::{AuthResponse, TestLoginRequest};
use std::sync::Arc;
use tonic::{Request, Response, Status};

fn test_auth_enabled() -> bool {
    matches!(
        std::env::var("TEST_AUTH_ENABLED").ok().as_deref(),
        Some("1" | "true" | "TRUE" | "yes" | "YES")
    )
}

pub async fn handle_test_login(
    auth_state: Arc<AuthState>,
    request: Request<TestLoginRequest>,
) -> Result<Response<AuthResponse>, Status> {
    if !test_auth_enabled() {
        return Err(Status::permission_denied(
            "TestLogin is disabled for this process",
        ));
    }

    let req = request.into_inner();
    let username = req.username.trim().to_string();

    if username.is_empty() {
        return Err(Status::invalid_argument("username is required"));
    }
    if username.contains(' ') {
        return Err(Status::invalid_argument("username cannot contain spaces"));
    }

    let user = match auth_state
        .central_db
        .get_user_by_name(&username)
        .await
        .map_err(|e| Status::internal(e.to_string()))?
    {
        Some(existing) => existing,
        None => auth_state
            .central_db
            .create_user(&username)
            .await
            .map_err(|e| {
                if e.to_string().contains("already exists") {
                    Status::already_exists("User already exists")
                } else {
                    Status::internal(e.to_string())
                }
            })?,
    };

    let token = auth_state
        .central_db
        .create_auth_session(&user.id)
        .await
        .map_err(|e| Status::internal(e.to_string()))?;

    Ok(Response::new(AuthResponse {
        session_token: token,
        user_id: user.id,
        username: user.name,
    }))
}
