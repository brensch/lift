use http::Method;
use tonic::transport::Server;
use tower_http::cors::{Any, CorsLayer};
use lift::workout::v1::{
    workout_service_server::WorkoutServiceServer,
    user_service_server::UserServiceServer,
};

mod db;
mod scheduler;
mod service_workout;
mod service_user;

use service_workout::MyWorkoutService;
use service_user::MyUserService;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let addr = "127.0.0.1:50051".parse()?;
    let workout_service = MyWorkoutService::default();
    let user_service = MyUserService::default();

    // CORS layer for browser access
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_headers(Any)
        .allow_methods([Method::POST, Method::OPTIONS])
        .expose_headers(Any);

    println!("Services listening on {} (gRPC-Web enabled)", addr);

    Server::builder()
        .accept_http1(true) // Required for gRPC-Web
        .layer(cors)
        .layer(tonic_web::GrpcWebLayer::new())
        .add_service(WorkoutServiceServer::new(workout_service))
        .add_service(UserServiceServer::new(user_service))
        .serve(addr)
        .await?;

    Ok(())
}
