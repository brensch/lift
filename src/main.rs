use schlift::workout::v1::{
    auth_service_server::AuthServiceServer, multiplayer_service_server::MultiplayerServiceServer,
    settings_service_server::SettingsServiceServer, user_service_server::UserServiceServer,
    workout_service_server::WorkoutServiceServer,
};
use std::net::SocketAddr;

mod db;
mod program_state;
mod progress;
mod regimes;
mod server;
mod state;
mod time;
mod weight_units;
mod workout;

use db::ServerDb;
use server::{
    ServerAuthService, ServerMultiplayerService, ServerSettingsService, ServerUserService,
    ServerWorkoutService,
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

    let addr: SocketAddr = "0.0.0.0:50051".parse()?;

    println!("Server listening on {} (gRPC h2c)", addr);

    tonic::transport::Server::builder()
        .accept_http1(true)
        .add_service(tonic_web::enable(WorkoutServiceServer::new(
            ServerWorkoutService {
                db: server_db.clone(),
            },
        )))
        .add_service(tonic_web::enable(UserServiceServer::new(ServerUserService {
            db: server_db.clone(),
        })))
        .add_service(tonic_web::enable(MultiplayerServiceServer::new(
            ServerMultiplayerService {
                db: server_db.clone(),
            },
        )))
        .add_service(tonic_web::enable(AuthServiceServer::new(ServerAuthService {
            db: server_db.clone(),
        })))
        .add_service(tonic_web::enable(SettingsServiceServer::new(
            ServerSettingsService {
                db: server_db.clone(),
            },
        )))
        .serve(addr)
        .await?;

    Ok(())
}
