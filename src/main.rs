use axum::{routing::get, Json};
use http::{header::HeaderName, Method};
use schlift::workout::v1::{
    auth_service_server::AuthServiceServer, multiplayer_service_server::MultiplayerServiceServer,
    settings_service_server::SettingsServiceServer, user_service_server::UserServiceServer,
    workout_service_server::WorkoutServiceServer,
};
use std::net::SocketAddr;
use std::sync::Arc;
use tower_http::cors::{Any, CorsLayer};

mod auth;
mod db;
mod program_state;
mod progress;
mod regimes;
mod scheduler;
mod service_auth;
#[cfg(feature = "test-auth")]
mod service_auth_test;
mod service_group;
mod service_settings;
mod service_user;
mod service_workout;
mod state;
mod weight_units;
mod workout_events;

use auth::AuthState;
use db::CentralDb;
use service_auth::MyAuthService;
use service_group::GroupService;
use service_settings::MySettingsService;
use service_user::MyUserService;
use service_workout::MyWorkoutService;
use state::AppState;
use tracing::{error, info};
use tracing_subscriber::{fmt, EnvFilter};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let env_filter =
        EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    fmt()
        .json()
        .with_env_filter(env_filter)
        .with_current_span(false)
        .with_span_list(false)
        .flatten_event(true)
        .init();
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
        app_state: app_state.clone(),
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

    let app = grpc_router
        .route("/api/health", get(|| async { "ok" }))
        .route("/.well-known/assetlinks.json", get(assetlinks_handler))
        .route(
            "/.well-known/apple-app-site-association",
            get(apple_app_site_association_handler),
        )
        .route(
            "/apple-app-site-association",
            get(apple_app_site_association_handler),
        )
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

async fn assetlinks_handler() -> Json<serde_json::Value> {
    // Always include the upload signing fingerprint.
    // Google Play app signing fingerprint:
    // 90:40:E8:C2:90:6F:32:DF:2B:8D:5B:1B:36:8C:FD:D7:D9:B7:1A:34:45:82:EA:23:F2:FE:16:26:ED:05:63:00
    // Optionally include ANDROID_CERT_SHA256 (e.g. local debug cert) for dev installs.
    let mut fingerprints = vec![
        "1F:0C:6B:FD:A7:5A:7D:18:7A:AE:53:1B:33:30:CD:11:7F:31:F5:05:8E:05:A9:21:FF:23:B0:E8:74:C2:21:EC".to_string(),
        "90:40:E8:C2:90:6F:32:DF:2B:8D:5B:1B:36:8C:FD:D7:D9:B7:1A:34:45:82:EA:23:F2:FE:16:26:ED:05:63:00".to_string(),
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
            "package_name": "com.brensch.schlift",
            "sha256_cert_fingerprints": fingerprints
        }
    }]))
}

async fn apple_app_site_association_handler() -> Json<serde_json::Value> {
    let apps: Vec<String> = if let Ok(app_ids) = std::env::var("APPLE_APP_IDS") {
        app_ids
            .split(',')
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(ToOwned::to_owned)
            .collect()
    } else if let Ok(team_id) = std::env::var("APPLE_TEAM_ID") {
        let team_id = team_id.trim();
        if team_id.is_empty() {
            Vec::new()
        } else {
            vec![format!("{}.com.brensch.schlift", team_id)]
        }
    } else {
        Vec::new()
    };

    Json(serde_json::json!({
        "webcredentials": {
            "apps": apps
        }
    }))
}
