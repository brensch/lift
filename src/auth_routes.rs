use std::sync::Arc;
use std::net::SocketAddr;
use axum::{
    extract::{State, ConnectInfo},
    http::{HeaderMap, StatusCode},
    routing::{get, post},
    Json, Router,
};
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
    pub name: Option<String>,
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

fn get_client_ip(headers: &HeaderMap, connect_info: Option<ConnectInfo<SocketAddr>>) -> Option<String> {
    headers
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.split(',').next())
        .map(|v| v.trim().to_string())
        .or_else(|| {
            headers
                .get("x-real-ip")
                .and_then(|v| v.to_str().ok())
                .map(|v| v.to_string())
        })
        .or_else(|| connect_info.map(|ci| ci.0.ip().to_string()))
}

async fn register_start(
    State(state): State<Arc<AuthState>>,
    Json(req): Json<RegisterStartRequest>,
) -> Result<Json<RegisterStartResponse>, (StatusCode, String)> {
    let username = req.username.trim().to_string();
    if username.is_empty() {
        return Err((StatusCode::BAD_REQUEST, "username is required".to_string()));
    }

    // Check if username is already taken (but don't create the user yet)
    let existing = state
        .central_db
        .get_user_by_name(&username)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;
    if existing.is_some() {
        return Err((StatusCode::CONFLICT, "User already exists".to_string()));
    }

    let (user_id, options) = state
        .start_registration(&username)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;

    Ok(Json(RegisterStartResponse { user_id, options }))
}

async fn register_finish(
    State(state): State<Arc<AuthState>>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    headers: HeaderMap,
    Json(req): Json<RegisterFinishRequest>,
) -> Result<Json<AuthResponse>, (StatusCode, String)> {
    let ip = get_client_ip(&headers, Some(ConnectInfo(addr)));
    // Verify passkey, then create user + store credential
    let username = state
        .finish_registration(&req.user_id, &req.credential, ip, req.name)
        .await
        .map_err(|e| (StatusCode::BAD_REQUEST, e))?;

    // Create session token
    let token = state
        .central_db
        .create_auth_session(&req.user_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(AuthResponse {
        session_token: token,
        user_id: req.user_id,
        username,
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

async fn validate_session(
    headers: &HeaderMap,
    state: &AuthState,
) -> Result<String, (StatusCode, String)> {
    let token = headers
        .get("x-session-token")
        .and_then(|v| v.to_str().ok())
        .ok_or_else(|| (StatusCode::UNAUTHORIZED, "Missing session token".to_string()))?;

    state
        .central_db
        .validate_auth_session(token)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or_else(|| (StatusCode::UNAUTHORIZED, "Invalid or expired session".to_string()))
}

async fn add_passkey_start(
    State(state): State<Arc<AuthState>>,
    headers: HeaderMap,
) -> Result<Json<serde_json::Value>, (StatusCode, String)> {
    let user_id = validate_session(&headers, &state).await?;

    let user = state
        .central_db
        .get_user(&user_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?
        .ok_or_else(|| (StatusCode::NOT_FOUND, "User not found".to_string()))?;

    let options = state
        .start_add_passkey(&user_id, &user.name)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;

    let options_json =
        serde_json::to_value(&options).map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(serde_json::json!({ "options": options_json })))
}

#[derive(Deserialize)]
pub struct AddPasskeyFinishRequest {
    pub credential: RegisterPublicKeyCredential,
    pub name: Option<String>,
}

async fn add_passkey_finish(
    State(state): State<Arc<AuthState>>,
    ConnectInfo(addr): ConnectInfo<SocketAddr>,
    headers: HeaderMap,
    Json(req): Json<AddPasskeyFinishRequest>,
) -> Result<StatusCode, (StatusCode, String)> {
    let user_id = validate_session(&headers, &state).await?;
    let ip = get_client_ip(&headers, Some(ConnectInfo(addr)));

    state
        .finish_add_passkey(&user_id, &req.credential, ip, req.name)
        .await
        .map_err(|e| (StatusCode::BAD_REQUEST, e))?;

    Ok(StatusCode::OK)
}

#[derive(Deserialize)]
pub struct DeletePasskeyRequest {
    pub credential_id: String,
}

async fn delete_passkey(
    State(state): State<Arc<AuthState>>,
    headers: HeaderMap,
    Json(req): Json<DeletePasskeyRequest>,
) -> Result<StatusCode, (StatusCode, String)> {
    let user_id = validate_session(&headers, &state).await?;

    state
        .central_db
        .delete_credential(&user_id, &req.credential_id)
        .await
        .map_err(|e| (StatusCode::BAD_REQUEST, e.to_string()))?;

    Ok(StatusCode::OK)
}

#[derive(Serialize)]
pub struct PasskeyInfoResponse {
    pub credential_id: String,
    pub name: Option<String>,
    pub created_at: i64,
    pub created_at_ip: Option<String>,
    pub transports: Vec<String>,
}

async fn list_passkeys(
    State(state): State<Arc<AuthState>>,
    headers: HeaderMap,
) -> Result<Json<Vec<PasskeyInfoResponse>>, (StatusCode, String)> {
    let user_id = validate_session(&headers, &state).await?;

    let rows = state
        .central_db
        .list_passkey_metadata(&user_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    let passkeys: Vec<PasskeyInfoResponse> = rows
        .into_iter()
        .map(|(credential_id, created_at, credential_json, created_at_ip)| {
            let v: serde_json::Value = serde_json::from_str(&credential_json).unwrap_or(serde_json::Value::Null);
            
            // Extract name if present
            let name = v.get("cred_name").and_then(|n| n.as_str()).map(|s| s.to_string());

            // Best-effort extract transports from credential JSON
            let transports: Vec<String> = v.get("transports")
                .and_then(|t| t.as_array())
                .map(|arr| {
                    arr.iter()
                        .filter_map(|v| v.as_str().map(String::from))
                        .collect()
                })
                .unwrap_or_default();

            PasskeyInfoResponse {
                credential_id,
                name,
                created_at,
                created_at_ip,
                transports,
            }
        })
        .collect();

    Ok(Json(passkeys))
}

async fn logout(
    State(state): State<Arc<AuthState>>,
    headers: HeaderMap,
) -> Result<StatusCode, (StatusCode, String)> {
    let token = headers
        .get("x-session-token")
        .and_then(|v| v.to_str().ok())
        .ok_or_else(|| (StatusCode::UNAUTHORIZED, "Missing session token".to_string()))?;

    state
        .central_db
        .invalidate_auth_session(token)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(StatusCode::OK)
}

pub fn auth_router(auth_state: Arc<AuthState>) -> Router {
    Router::new()
        .route("/auth/register/start", post(register_start))
        .route("/auth/register/finish", post(register_finish))
        .route("/auth/login/start", post(login_start))
        .route("/auth/login/finish", post(login_finish))
        .route("/auth/logout", post(logout))
        .route("/auth/passkey/add/start", post(add_passkey_start))
        .route("/auth/passkey/add/finish", post(add_passkey_finish))
        .route("/auth/passkey/delete", post(delete_passkey))
        .route("/auth/passkeys", get(list_passkeys))
        .with_state(auth_state)
}
