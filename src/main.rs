use http::Method;
use tonic::{transport::Server, Request, Response, Status};
use tower_http::cors::{Any, CorsLayer};
use lift::workout::v1::{
    workout_service_server::{WorkoutService, WorkoutServiceServer},
    StartWorkoutRequest, StartWorkoutResponse,
    GetWorkoutRequest, GetWorkoutResponse,
    ListWorkoutsRequest, ListWorkoutsResponse,
    ModifyProposedSetsRequest, ModifyProposedSetsResponse,
    StartSetRequest, StartSetResponse,
    CompleteSetRequest, CompleteSetResponse,
    EndWorkoutRequest, EndWorkoutResponse,
};

mod db;

#[derive(Debug, Default)]
pub struct MyWorkoutService;

#[tonic::async_trait]
impl WorkoutService for MyWorkoutService {
    async fn start_workout(
        &self,
        request: Request<StartWorkoutRequest>,
    ) -> Result<Response<StartWorkoutResponse>, Status> {
        let req = request.into_inner();
        let user_id = req.user_id;

        if user_id.is_empty() {
            return Err(Status::invalid_argument("user_id is required"));
        }

        println!("Starting workout for user: {}", user_id);

        // 1. Connect to the specific user's DB
        let user_db = db::UserDb::new(&user_id).await
            .map_err(|e| Status::internal(format!("Failed to connect to user db: {}", e)))?;

        // 2. Create the workout
        let workout = user_db.create_workout().await
            .map_err(|e| Status::internal(format!("Failed to create workout: {}", e)))?;

        // 3. Return response
        Ok(Response::new(StartWorkoutResponse {
            workout: Some(workout),
        }))
    }

    async fn get_workout(
        &self,
        _request: Request<GetWorkoutRequest>,
    ) -> Result<Response<GetWorkoutResponse>, Status> {
        Err(Status::unimplemented("Not implemented yet"))
    }

    async fn list_workouts(
        &self,
        _request: Request<ListWorkoutsRequest>,
    ) -> Result<Response<ListWorkoutsResponse>, Status> {
        Err(Status::unimplemented("Not implemented yet"))
    }

    async fn modify_proposed_sets(
        &self,
        _request: Request<ModifyProposedSetsRequest>,
    ) -> Result<Response<ModifyProposedSetsResponse>, Status> {
        Err(Status::unimplemented("Not implemented yet"))
    }

    async fn start_set(
        &self,
        _request: Request<StartSetRequest>,
    ) -> Result<Response<StartSetResponse>, Status> {
        Err(Status::unimplemented("Not implemented yet"))
    }

    async fn complete_set(
        &self,
        _request: Request<CompleteSetRequest>,
    ) -> Result<Response<CompleteSetResponse>, Status> {
        Err(Status::unimplemented("Not implemented yet"))
    }

    async fn end_workout(
        &self,
        _request: Request<EndWorkoutRequest>,
    ) -> Result<Response<EndWorkoutResponse>, Status> {
        Err(Status::unimplemented("Not implemented yet"))
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let addr = "127.0.0.1:50051".parse()?;
    let service = MyWorkoutService::default();

    // CORS layer for browser access
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_headers(Any)
        .allow_methods([Method::POST, Method::OPTIONS])
        .expose_headers(Any);

    println!("WorkoutService listening on {} (gRPC-Web enabled)", addr);

    Server::builder()
        .accept_http1(true) // Required for gRPC-Web
        .layer(cors)
        .layer(tonic_web::GrpcWebLayer::new())
        .add_service(WorkoutServiceServer::new(service))
        .serve(addr)
        .await?;

    Ok(())
}