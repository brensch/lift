use axum::{routing::get, Json};
use http::{header::HeaderName, Method};
use schlift::workout::v1::{
    auth_service_server::AuthServiceServer, multiplayer_service_server::MultiplayerServiceServer,
    settings_service_server::SettingsServiceServer,
    training_service_server::TrainingServiceServer, user_service_server::UserServiceServer,
    workout_service_server::WorkoutServiceServer,
};
use std::net::SocketAddr;
use tower_http::cors::{Any, CorsLayer};

mod auth;
mod db;
mod exercise_catalog;
mod exercise_progress;
mod program_state;
mod progress;
mod onboarding;
mod recovery;
mod regimes;
#[cfg(test)]
mod scenario_tests;
mod schplanner;
#[cfg(test)]
mod schplanner_tests;
mod server;
mod state;
mod time;
mod weight_units;
mod workout;

use auth::AuthState;
use db::ServerDb;
use server::{
    ServerAuthService, ServerMultiplayerService, ServerSettingsService, ServerTrainingService,
    ServerUserService, ServerWorkoutService,
};
use tracing::{error, info};
use tracing_subscriber::{fmt, EnvFilter};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let env_filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("warn"));
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

    let data_dir = std::env::var("DATA_DIR").unwrap_or_else(|_| "data".to_string());
    let server_db = ServerDb::new_in_dir(data_dir).await?;
    let auth_state = std::sync::Arc::new(AuthState::new(server_db.clone()));

    // PORT lets a throwaway instance (the API invariant harness, a second dev
    // backend) run alongside the usual one on 50051.
    let port = std::env::var("PORT").unwrap_or_else(|_| "50051".to_string());
    let addr: SocketAddr = format!("0.0.0.0:{port}").parse()?;

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

    #[allow(deprecated)]
    let grpc_router = tonic::transport::Server::builder()
        // Disable Nagle: without this every small RPC response can stall on the
        // ~40ms TCP delayed-ACK timer, adding that latency to essentially every
        // request. Standard for a low-latency gRPC service.
        .tcp_nodelay(true)
        .accept_http1(true)
        .add_service(tonic_web::enable(WorkoutServiceServer::new(
            ServerWorkoutService {
                db: server_db.clone(),
            },
        )))
        .add_service(tonic_web::enable(UserServiceServer::new(
            ServerUserService {
                db: server_db.clone(),
            },
        )))
        .add_service(tonic_web::enable(MultiplayerServiceServer::new(
            ServerMultiplayerService {
                db: server_db.clone(),
            },
        )))
        .add_service(tonic_web::enable(AuthServiceServer::new(
            ServerAuthService {
                db: server_db.clone(),
                auth_state: auth_state.clone(),
            },
        )))
        .add_service(tonic_web::enable(SettingsServiceServer::new(
            ServerSettingsService {
                db: server_db.clone(),
            },
        )))
        .add_service(tonic_web::enable(TrainingServiceServer::new(
            ServerTrainingService {
                db: server_db.clone(),
            },
        )))
        .into_router();

    let app = axum::Router::new()
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
        .fallback_service(grpc_router)
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
    // One statement per package. The dev backend sets ANDROID_PACKAGE_NAMES to
    // include com.brensch.schlift.dev so the side-by-side dev app (a different
    // applicationId, same signing key) can associate passkeys on dev.schlift.com.
    let packages: Vec<String> = std::env::var("ANDROID_PACKAGE_NAMES")
        .ok()
        .map(|s| {
            s.split(',')
                .map(str::trim)
                .filter(|p| !p.is_empty())
                .map(ToOwned::to_owned)
                .collect::<Vec<_>>()
        })
        .filter(|v| !v.is_empty())
        .unwrap_or_else(|| vec!["com.brensch.schlift".to_string()]);

    let statements: Vec<serde_json::Value> = packages
        .iter()
        .map(|pkg| {
            serde_json::json!({
                "relation": ["delegate_permission/common.handle_all_urls", "delegate_permission/common.get_login_creds"],
                "target": {
                    "namespace": "android_app",
                    "package_name": pkg,
                    "sha256_cert_fingerprints": fingerprints
                }
            })
        })
        .collect();
    Json(serde_json::json!(statements))
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
        // Universal Links: open the app for join links (schlift.com/?join=…) and
        // leave every other path to the website.
        "applinks": {
            "apps": [],
            "details": [{
                "appIDs": apps.clone(),
                "components": [{
                    "/": "/",
                    "?": { "join": "?*" },
                    "comment": "Open Schlift and join the multiplayer session"
                }]
            }]
        },
        // Passkeys.
        "webcredentials": {
            "apps": apps
        }
    }))
}
