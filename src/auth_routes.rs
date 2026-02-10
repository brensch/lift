use std::sync::Arc;
use axum::{extract::State, http::StatusCode, routing::post, Json, Router};
use serde::{Deserialize, Serialize};
use webauthn_rs::prelude::*;

use crate::auth::AuthState;

#[derive(Deserialize)]
pub struct RegisterStartRequest {
    pub username: String,
}

#[derive(Serialize)]
pub struct RegisterStartResponse {
    pub user_id: String,
    pub options: CreationChallengeResponse,
}

#[derive(Deserialize)]
pub struct RegisterFinishRequest {
    pub user_id: String,
    pub credential: RegisterPublicKeyCredential,
}

#[derive(Serialize)]
pub struct AuthResponse {
    pub session_token: String,
    pub user_id: String,
    pub username: String,
}

#[derive(Deserialize)]
pub struct LoginStartRequest {
    #[serde(default)]
    pub username: Option<String>,
}

#[derive(Serialize)]
pub struct LoginStartResponse {
    pub challenge_id: String,
    pub options: RequestChallengeResponse,
}

#[derive(Deserialize)]
pub struct LoginFinishRequest {
    pub challenge_id: String,
    pub credential: PublicKeyCredential,
}

async fn register_start(
    State(state): State<Arc<AuthState>>,
    Json(req): Json<RegisterStartRequest>,
) -> Result<Json<RegisterStartResponse>, (StatusCode, String)> {
    if req.username.trim().is_empty() {
        return Err((StatusCode::BAD_REQUEST, "username is required".to_string()));
    }

    // Create or get user
    let user = state
        .central_db
        .create_user(&req.username)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let options = state
        .start_registration(&user.id, &user.name)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;

    Ok(Json(RegisterStartResponse {
        user_id: user.id,
        options,
    }))
}

async fn register_finish(
    State(state): State<Arc<AuthState>>,
    Json(req): Json<RegisterFinishRequest>,
) -> Result<Json<AuthResponse>, (StatusCode, String)> {
    state
        .finish_registration(&req.user_id, &req.credential)
        .await
        .map_err(|e| (StatusCode::BAD_REQUEST, e))?;

    // Create session token
    let token = state
        .central_db
        .create_auth_session(&req.user_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let user = state
        .central_db
        .get_user(&req.user_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or_else(|| (StatusCode::NOT_FOUND, "User not found".to_string()))?;

    Ok(Json(AuthResponse {
        session_token: token,
        user_id: req.user_id,
        username: user.name,
    }))
}

async fn login_start(
    State(state): State<Arc<AuthState>>,
    Json(req): Json<LoginStartRequest>,
) -> Result<Json<LoginStartResponse>, (StatusCode, String)> {
    let (challenge_id, options) = match req.username.as_deref() {
        Some(username) if !username.trim().is_empty() => {
            state
                .start_authentication_with_username(username.trim())
                .await
                .map_err(|e| (StatusCode::BAD_REQUEST, e))?
        }
        _ => {
            state
                .start_authentication()
                .await
                .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?
        }
    };

    Ok(Json(LoginStartResponse {
        challenge_id,
        options,
    }))
}

async fn login_finish(
    State(state): State<Arc<AuthState>>,
    Json(req): Json<LoginFinishRequest>,
) -> Result<Json<AuthResponse>, (StatusCode, String)> {
    let (token, user_id, username) = state
        .finish_authentication(&req.challenge_id, &req.credential)
        .await
        .map_err(|e| (StatusCode::UNAUTHORIZED, e))?;

    Ok(Json(AuthResponse {
        session_token: token,
        user_id,
        username,
    }))
}

pub fn auth_router(auth_state: Arc<AuthState>) -> Router {
    Router::new()
        .route("/auth/register/start", post(register_start))
        .route("/auth/register/finish", post(register_finish))
        .route("/auth/login/start", post(login_start))
        .route("/auth/login/finish", post(login_finish))
        .with_state(auth_state)
}
