use axum::{
    extract::Extension,
    http::StatusCode,
    response::{Html, IntoResponse},
    routing::{get, post},
    Json,
};
use http::{
    header::{HeaderName, CONTENT_TYPE},
    Method,
};
use lift::workout::v1::{
    auth_service_server::AuthServiceServer, multiplayer_service_server::MultiplayerServiceServer,
    settings_service_server::SettingsServiceServer, user_service_server::UserServiceServer,
    workout_service_server::WorkoutServiceServer,
};
use log::{error, info};
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;
use std::sync::Arc;
use tower_http::cors::{Any, CorsLayer};
use webauthn_rs::prelude::PublicKeyCredential;

mod auth;
mod db;
mod program_state;
mod progress;
mod regimes;
mod scheduler;
mod service_auth;
mod service_group;
mod service_settings;
mod service_user;
mod service_workout;
mod state;

use auth::AuthState;
use db::CentralDb;
use service_auth::MyAuthService;
use service_group::GroupService;
use service_settings::MySettingsService;
use service_user::MyUserService;
use service_workout::MyWorkoutService;
use state::AppState;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    env_logger::init();
    info!("Starting server...");

    // Catch panics and log them
    std::panic::set_hook(Box::new(|panic_info| {
        let location = panic_info
            .location()
            .map(|l| format!("{}:{}", l.file(), l.line()))
            .unwrap_or_else(|| "unknown".to_string());
        let payload = panic_info.payload();
        let message = if let Some(s) = payload.downcast_ref::<&str>() {
            *s
        } else if let Some(s) = payload.downcast_ref::<String>() {
            s.as_str()
        } else {
            "no message"
        };
        error!("PANIC at {}: {}", location, message);
    }));

    let central_db = CentralDb::new().await?;
    let app_state = Arc::new(AppState::new());

    // Spawn periodic checkpoint task (flushes dirty workouts every 30s)
    state::spawn_checkpoint_task(app_state.clone(), central_db.clone());

    let addr: SocketAddr = "0.0.0.0:50051".parse()?;
    let workout_service = MyWorkoutService::new(central_db.clone(), app_state.clone());
    let user_service = MyUserService::new(central_db.clone());
    let group_service = GroupService::new(central_db.clone(), app_state.clone());

    let settings_service = MySettingsService::new(central_db.clone());

    let auth_state = Arc::new(AuthState::new(central_db.clone()));
    let auth_service = MyAuthService {
        auth_state: auth_state.clone(),
    };

    // CORS layer for browser access
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_headers(Any)
        .allow_methods([Method::POST, Method::OPTIONS, Method::GET])
        .expose_headers([
            HeaderName::from_static("grpc-status"),
            HeaderName::from_static("grpc-message"),
            HeaderName::from_static("grpc-status-details-bin"),
            HeaderName::from_static("x-grpc-web"),
            HeaderName::from_static("x-user-agent"),
        ]);

    let workout_service_web = tonic_web::enable(WorkoutServiceServer::new(workout_service));
    let user_service_web = tonic_web::enable(UserServiceServer::new(user_service));
    let multiplayer_service_web = tonic_web::enable(MultiplayerServiceServer::new(group_service));
    let auth_service_web = tonic_web::enable(AuthServiceServer::new(auth_service));
    let settings_service_web = tonic_web::enable(SettingsServiceServer::new(settings_service));

    // Build gRPC router
    #[allow(deprecated)]
    let grpc_router = tonic::transport::Server::builder()
        .accept_http1(true)
        .add_service(workout_service_web)
        .add_service(user_service_web)
        .add_service(multiplayer_service_web)
        .add_service(auth_service_web)
        .add_service(settings_service_web)
        .into_router();

    // Assetlinks handler for Android passkey verification
    let app = grpc_router
        .route("/", get(root_handler))
        .route("/privacy", get(privacy_handler))
        .route("/forget", get(forget_handler))
        .route("/assets/lift-theme.css", get(theme_css_handler))
        .route("/assets/lift-wobble.js", get(wobble_js_handler))
        .route("/api/forget/start", post(forget_start_handler))
        .route("/api/forget/confirm", post(forget_confirm_handler))
        .route("/.well-known/assetlinks.json", get(assetlinks_handler))
        .layer(Extension(auth_state))
        .layer(Extension(app_state))
        .layer(cors);

    println!("Server listening on {} (gRPC-Web)", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(
        listener,
        app.into_make_service_with_connect_info::<SocketAddr>(),
    )
    .await?;

    Ok(())
}

async fn root_handler() -> Html<&'static str> {
    Html(include_str!("../index.html"))
}

async fn privacy_handler() -> Html<&'static str> {
    Html(include_str!("../privacy.html"))
}

async fn forget_handler() -> Html<&'static str> {
    Html(include_str!("../forget.html"))
}

async fn theme_css_handler() -> impl IntoResponse {
    (
        [(CONTENT_TYPE, "text/css; charset=utf-8")],
        include_str!("../web/lift-theme.css"),
    )
}

async fn wobble_js_handler() -> impl IntoResponse {
    (
        [(CONTENT_TYPE, "application/javascript; charset=utf-8")],
        include_str!("../web/lift-wobble.js"),
    )
}

#[derive(Serialize)]
struct ForgetStartResponse {
    challenge_id: String,
    options_json: serde_json::Value,
}

#[derive(Deserialize)]
struct ForgetConfirmRequest {
    challenge_id: String,
    credential_json: serde_json::Value,
}

#[derive(Serialize)]
struct ForgetConfirmResponse {
    deleted_user_id: String,
}

async fn forget_start_handler(
    Extension(auth_state): Extension<Arc<AuthState>>,
) -> Result<Json<ForgetStartResponse>, (StatusCode, String)> {
    let (challenge_id, options) = auth_state
        .start_authentication()
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e))?;

    let options_json = serde_json::to_value(options)
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    Ok(Json(ForgetStartResponse {
        challenge_id,
        options_json,
    }))
}

async fn forget_confirm_handler(
    Extension(auth_state): Extension<Arc<AuthState>>,
    Extension(app_state): Extension<Arc<AppState>>,
    Json(req): Json<ForgetConfirmRequest>,
) -> Result<Json<ForgetConfirmResponse>, (StatusCode, String)> {
    let credential: PublicKeyCredential =
        serde_json::from_value(req.credential_json).map_err(|e| {
            (
                StatusCode::BAD_REQUEST,
                format!("Invalid credential JSON: {}", e),
            )
        })?;

    let (session_token, user_id, _) = auth_state
        .finish_authentication(&req.challenge_id, &credential)
        .await
        .map_err(|e| (StatusCode::UNAUTHORIZED, e))?;

    auth_state
        .central_db
        .delete_user_account_and_data(&user_id)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))?;

    app_state.remove_user_data(&user_id);

    let _ = auth_state
        .central_db
        .invalidate_auth_session(&session_token)
        .await;

    Ok(Json(ForgetConfirmResponse {
        deleted_user_id: user_id,
    }))
}

async fn assetlinks_handler() -> Json<serde_json::Value> {
    // Always include the upload signing fingerprint.
    // Google Play app signing fingerprint:
    // FC:0A:96:93:88:92:30:42:E1:E6:DF:08:C2:63:D6:D6:21:8D:74:80:1F:55:5D:C3:EB:04:E1:C9:34:49:1A:09
    // Optionally include ANDROID_CERT_SHA256 (e.g. local debug cert) for dev installs.
    let mut fingerprints = vec![
        "1F:0C:6B:FD:A7:5A:7D:18:7A:AE:53:1B:33:30:CD:11:7F:31:F5:05:8E:05:A9:21:FF:23:B0:E8:74:C2:21:EC".to_string(),
        "FC:0A:96:93:88:92:30:42:E1:E6:DF:08:C2:63:D6:D6:21:8D:74:80:1F:55:5D:C3:EB:04:E1:C9:34:49:1A:09".to_string(),
    ];
    if let Ok(env_fp) = std::env::var("ANDROID_CERT_SHA256") {
        let env_fp = env_fp.trim();
        if !env_fp.is_empty() && !fingerprints.iter().any(|f| f == env_fp) {
            fingerprints.push(env_fp.to_string());
        }
    }
    Json(serde_json::json!([{
        "relation": ["delegate_permission/common.handle_all_urls", "delegate_permission/common.get_login_creds"],
        "target": {
            "namespace": "android_app",
            "package_name": "com.brensch.lift",
            "sha256_cert_fingerprints": fingerprints
        }
    }]))
}
