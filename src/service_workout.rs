use std::sync::Arc;
use tonic::{Request, Response, Status};
use lift::workout::v1::{
    workout_service_server::WorkoutService,
    StartWorkoutRequest, StartWorkoutResponse,
    GetWorkoutRequest, GetWorkoutResponse,
    ListWorkoutsRequest, ListWorkoutsResponse,
    ModifyProposedSetsRequest, ModifyProposedSetsResponse,
    StartSetRequest, StartSetResponse,
    CompleteSetRequest, CompleteSetResponse,
    EndWorkoutRequest, EndWorkoutResponse,
    GetActiveWorkoutRequest, GetActiveWorkoutResponse,
    GetProposedWorkoutScheduleRequest, GetProposedWorkoutScheduleResponse,
};
use crate::db::{CentralDb, UserDb};
use crate::scheduler::Scheduler;
use crate::service_group::SessionManager;

pub struct MyWorkoutService {
    central_db: CentralDb,
    session_manager: Arc<SessionManager>,
}

impl MyWorkoutService {
    pub fn new(central_db: CentralDb, session_manager: Arc<SessionManager>) -> Self {
        Self { central_db, session_manager }
    }
}

// Helper to extract user_id from request metadata.
// Prefers x-session-token (validated via DB), falls back to x-user-id.
pub async fn get_user_id_authenticated<T>(request: &Request<T>, central_db: &CentralDb) -> Result<String, Status> {
    // First try session token
    if let Some(token) = request.metadata().get("x-session-token").and_then(|v| v.to_str().ok()) {
        if let Ok(Some(user_id)) = central_db.validate_auth_session(token).await {
            return Ok(user_id);
        }
    }

    // Fall back to raw user-id (migration period)
    request
        .metadata()
        .get("x-user-id")
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string())
        .ok_or_else(|| Status::unauthenticated("Authentication required"))
}


#[tonic::async_trait]
impl WorkoutService for MyWorkoutService {
    async fn start_workout(
        &self,
        request: Request<StartWorkoutRequest>,
    ) -> Result<Response<StartWorkoutResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        let user_db = UserDb::new(&user_id).await
            .map_err(|e| Status::internal(format!("Failed to connect to user db: {}", e)))?;

        if let Some(active) = user_db.get_active_workout().await
            .map_err(|e| Status::internal(format!("Failed to check for active workout: {}", e)))? {
            return Err(Status::failed_precondition(format!("A workout is already in progress (id: {}). End it before starting a new one.", active.id)));
        }

        let workout_id = user_db.create_workout(&req.name, req.proposed_sets).await
            .map_err(|e| Status::internal(format!("Failed to create workout: {}", e)))?;

        let _ = self.session_manager.update_active_workout(&user_id, &workout_id).await;
        self.session_manager.notify_user_update(&user_id).await;

        Ok(Response::new(StartWorkoutResponse { id: workout_id }))
    }

    async fn get_workout(
        &self,
        request: Request<GetWorkoutRequest>,
    ) -> Result<Response<GetWorkoutResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        if req.workout_id.is_empty() {
            return Err(Status::invalid_argument("workout_id is required"));
        }

        let user_db = UserDb::new(&user_id).await
            .map_err(|e| Status::internal(format!("Failed to connect to user db: {}", e)))?;

        let workout = user_db.get_workout(&req.workout_id).await
            .map_err(|e| Status::internal(format!("Failed to get workout: {}", e)))?
            .ok_or_else(|| Status::not_found("Workout not found"))?;

        let proposed_sets = user_db.get_proposed_sets(&req.workout_id).await
            .map_err(|e| Status::internal(format!("Failed to get proposed sets: {}", e)))?;

        let completed_sets = user_db.get_completed_sets(&req.workout_id).await
            .map_err(|e| Status::internal(format!("Failed to get completed sets: {}", e)))?;

        Ok(Response::new(GetWorkoutResponse {
            workout: Some(workout),
            proposed_sets,
            completed_sets,
        }))
    }

    async fn list_workouts(
        &self,
        request: Request<ListWorkoutsRequest>,
    ) -> Result<Response<ListWorkoutsResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;

        let user_db = UserDb::new(&user_id).await
            .map_err(|e| Status::internal(format!("Failed to connect to user db: {}", e)))?;

        let workouts = user_db.list_workouts().await
            .map_err(|e| Status::internal(format!("Failed to list workouts: {}", e)))?;

        Ok(Response::new(ListWorkoutsResponse { workouts }))
    }

    async fn modify_proposed_sets(
        &self,
        request: Request<ModifyProposedSetsRequest>,
    ) -> Result<Response<ModifyProposedSetsResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        if req.workout_id.is_empty() {
            return Err(Status::invalid_argument("workout_id is required"));
        }

        let user_db = UserDb::new(&user_id).await
            .map_err(|e| Status::internal(format!("Failed to connect to user db: {}", e)))?;

        let proposed_sets = user_db.modify_proposed_sets(&req.workout_id, req.proposed_sets).await
            .map_err(|e| Status::internal(format!("Failed to modify proposed sets: {}", e)))?;

        self.session_manager.notify_user_update(&user_id).await;

        Ok(Response::new(ModifyProposedSetsResponse { proposed_sets }))
    }

    async fn start_set(
        &self,
        request: Request<StartSetRequest>,
    ) -> Result<Response<StartSetResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        if req.workout_id.is_empty() {
            return Err(Status::invalid_argument("workout_id is required"));
        }
        if req.proposed_set_id.is_empty() {
            return Err(Status::invalid_argument("proposed_set_id is required"));
        }

        let user_db = UserDb::new(&user_id).await
            .map_err(|e| Status::internal(format!("Failed to connect to user db: {}", e)))?;

        let completed_set = user_db.start_set(&req.workout_id, &req.proposed_set_id).await
            .map_err(|e| Status::internal(format!("Failed to start set: {}", e)))?;

        self.session_manager.notify_user_update(&user_id).await;

        Ok(Response::new(StartSetResponse {
            completed_set: Some(completed_set),
        }))
    }

    async fn complete_set(
        &self,
        request: Request<CompleteSetRequest>,
    ) -> Result<Response<CompleteSetResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        if req.workout_id.is_empty() {
            return Err(Status::invalid_argument("workout_id is required"));
        }
        if req.proposed_set_id.is_empty() {
            return Err(Status::invalid_argument("proposed_set_id is required"));
        }

        let user_db = UserDb::new(&user_id).await
            .map_err(|e| Status::internal(format!("Failed to connect to user db: {}", e)))?;

        let completed_set = user_db.complete_set(
            &req.workout_id,
            &req.proposed_set_id,
            req.actual_reps,
            req.actual_weight,
        ).await
            .map_err(|e| Status::internal(format!("Failed to complete set: {}", e)))?;

        self.session_manager.notify_user_update(&user_id).await;

        Ok(Response::new(CompleteSetResponse {
            completed_set: Some(completed_set),
        }))
    }

    async fn end_workout(
        &self,
        request: Request<EndWorkoutRequest>,
    ) -> Result<Response<EndWorkoutResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        if req.workout_id.is_empty() {
            return Err(Status::invalid_argument("workout_id is required"));
        }

        let user_db = UserDb::new(&user_id).await
            .map_err(|e| Status::internal(format!("Failed to connect to user db: {}", e)))?;

        let workout = user_db.end_workout(&req.workout_id).await
            .map_err(|e| Status::internal(format!("Failed to end workout: {}", e)))?
            .ok_or_else(|| Status::not_found("Workout not found"))?;

        user_db.deactivate_all_sessions().await
            .map_err(|e| Status::internal(format!("Failed to deactivate sessions: {}", e)))?;
        
        self.session_manager.notify_user_update(&user_id).await;

        Ok(Response::new(EndWorkoutResponse {
            workout: Some(workout),
        }))
    }

    async fn get_active_workout(
        &self,
        request: Request<GetActiveWorkoutRequest>,
    ) -> Result<Response<GetActiveWorkoutResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;

        let user_db = UserDb::new(&user_id).await
            .map_err(|e| Status::internal(format!("Failed to connect to user db: {}", e)))?;

        let workout = user_db.get_active_workout().await
            .map_err(|e| Status::internal(format!("Failed to get active workout: {}", e)))?;

        Ok(Response::new(GetActiveWorkoutResponse { workout }))
    }

    async fn get_proposed_workout_schedule(
        &self,
        request: Request<GetProposedWorkoutScheduleRequest>,
    ) -> Result<Response<GetProposedWorkoutScheduleResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;

        let user_db = UserDb::new(&user_id).await
            .map_err(|e| Status::internal(format!("Failed to connect to user db: {}", e)))?;

        let scheduler = Scheduler::new(user_db);
        let proposed_workouts = scheduler.get_proposed_schedule().await
            .map_err(|e| Status::internal(format!("Failed to generate schedule: {}", e)))?;

        Ok(Response::new(GetProposedWorkoutScheduleResponse {
            proposed_workouts,
        }))
    }
}