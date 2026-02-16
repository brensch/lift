use std::sync::Arc;
use std::net::SocketAddr;
use axum::{
    routing::get,
    response::Html,
    Json,
};
use http::{header::HeaderName, Method};
use tower_http::cors::{Any, CorsLayer};
use lift::workout::v1::{
    workout_service_server::WorkoutServiceServer,
    user_service_server::UserServiceServer,
    multiplayer_service_server::MultiplayerServiceServer,
    auth_service_server::AuthServiceServer,
};
use log::{info, error};

mod auth;
mod db;
mod scheduler;
mod service_workout;
mod service_user;
mod service_group;
mod service_auth;
mod state;

use auth::AuthState;
use db::CentralDb;
use service_workout::MyWorkoutService;
use service_user::MyUserService;
use service_group::GroupService;
use service_auth::MyAuthService;
use state::AppState;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    env_logger::init();
    info!("Starting server...");

    // Catch panics and log them
    std::panic::set_hook(Box::new(|panic_info| {
        let location = panic_info.location().map(|l| format!("{}:{}", l.file(), l.line())).unwrap_or_else(|| "unknown".to_string());
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
    state::spawn_checkpoint_task(app_state.clone());

    let addr: SocketAddr = "0.0.0.0:50051".parse()?;
    let workout_service = MyWorkoutService::new(central_db.clone(), app_state.clone());
    let user_service = MyUserService::new(central_db.clone());
    let group_service = GroupService::new(central_db.clone(), app_state.clone());

    let auth_state = Arc::new(AuthState::new(central_db.clone()));
    let auth_service = MyAuthService { auth_state: auth_state.clone() };

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

    // Build gRPC router
    #[allow(deprecated)]
    let grpc_router = tonic::transport::Server::builder()
        .accept_http1(true)
        .add_service(workout_service_web)
        .add_service(user_service_web)
        .add_service(multiplayer_service_web)
        .add_service(auth_service_web)
        .into_router();

    // Assetlinks handler for Android passkey verification
    let app = grpc_router
        .route("/", get(root_handler))
        .route("/.well-known/assetlinks.json", get(assetlinks_handler))
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

async fn assetlinks_handler() -> Json<serde_json::Value> {
    let sha256 = std::env::var("ANDROID_CERT_SHA256").unwrap_or_default();
    Json(serde_json::json!([{
        "relation": ["delegate_permission/common.handle_all_urls", "delegate_permission/common.get_login_creds"],
        "target": {
            "namespace": "android_app",
            "package_name": "com.lift.lift",
            "sha256_cert_fingerprints": [sha256]
        }
    }]))
}
