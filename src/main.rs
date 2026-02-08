use http::{header::HeaderName, Method};
use tonic::transport::Server;
use tower_http::cors::{Any, CorsLayer};
use lift::workout::v1::{
    workout_service_server::WorkoutServiceServer,
    user_service_server::UserServiceServer,
};
use log::info;

mod db;
mod scheduler;
mod service_workout;
mod service_user;

use service_workout::MyWorkoutService;
use service_user::MyUserService;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();
    info!("Starting server...");

    let addr = "127.0.0.1:50051".parse()?;
    let workout_service = MyWorkoutService::default();
    let user_service = MyUserService::default();

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

    let workout_service = WorkoutServiceServer::new(workout_service);
    let user_service = UserServiceServer::new(user_service);

    // Enable gRPC-Web directly on the services
    let workout_service_web = tonic_web::enable(workout_service);
    let user_service_web = tonic_web::enable(user_service);

    Server::builder()
        .accept_http1(true)
        .tcp_nodelay(true)
        .layer(cors)
        .add_service(workout_service_web)
        .add_service(user_service_web)
        .serve(addr)
        .await?;

    Ok(())
}
