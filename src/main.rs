use std::sync::Arc;
use http::{header::HeaderName, Method};
use tonic::transport::Server;
use tower_http::cors::{Any, CorsLayer};
use lift::workout::v1::{
    workout_service_server::WorkoutServiceServer,
    user_service_server::UserServiceServer,
    multiplayer_service_server::MultiplayerServiceServer,
};
use log::info;

mod db;
mod scheduler;
mod service_workout;
mod service_user;
mod service_group;

use db::CentralDb;
use service_workout::MyWorkoutService;
use service_user::MyUserService;
use service_group::{GroupService, SessionManager};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    env_logger::init();
    info!("Starting server...");

    let central_db = CentralDb::new().await?;
    let session_manager = Arc::new(SessionManager::new(central_db.clone()));

    let addr = "127.0.0.1:50051".parse()?;
    let workout_service = MyWorkoutService::new(session_manager.clone());
    let user_service = MyUserService::new(central_db.clone());
    let group_service = GroupService::new(central_db.clone(), session_manager.clone());

    // CORS layer for browser access
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_headers(Any)
        .allow_methods([Method::POST, Method::OPTIONS])
        .expose_headers([
            HeaderName::from_static("grpc-status"),
            HeaderName::from_static("grpc-message"),
            HeaderName::from_static("grpc-status-details-bin"),
            HeaderName::from_static("x-grpc-web"),
            HeaderName::from_static("x-user-agent"),
        ]);

    println!("Services listening on {} (gRPC-Web enabled)", addr);

    let workout_service_web = tonic_web::enable(WorkoutServiceServer::new(workout_service));
    let user_service_web = tonic_web::enable(UserServiceServer::new(user_service));
    let multiplayer_service_web = tonic_web::enable(MultiplayerServiceServer::new(group_service));

    Server::builder()
        .accept_http1(true)
        .tcp_nodelay(true)
        .layer(cors)
        .add_service(workout_service_web)
        .add_service(user_service_web)
        .add_service(multiplayer_service_web)
        .serve(addr)
        .await?;

    Ok(())
}
