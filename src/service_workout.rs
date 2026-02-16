use std::sync::Arc;
use tonic::{Request, Response, Status};
use lift::workout::v1::{
    workout_service_server::WorkoutService,
    StartWorkoutRequest, StartWorkoutResponse,
    GetWorkoutRequest, GetWorkoutResponse,
    ListWorkoutsRequest, ListWorkoutsResponse,
    StartSetRequest, StartSetResponse,
    CompleteSetRequest, CompleteSetResponse,
    DeleteCompletedSetRequest, DeleteCompletedSetResponse,
    EndWorkoutRequest, EndWorkoutResponse,
    GetActiveWorkoutRequest, GetActiveWorkoutResponse,
    GetProposedWorkoutScheduleRequest, GetProposedWorkoutScheduleResponse,
    CreateExerciseGroupRequest, CreateExerciseGroupResponse,
    UpdateExerciseGroupRequest, UpdateExerciseGroupResponse,
    DeleteExerciseGroupRequest, DeleteExerciseGroupResponse,
    ReorderExerciseGroupsRequest, ReorderExerciseGroupsResponse,
    ExerciseGroup, ProposedSet, ExerciseGroupType, Exercise,
};
use crate::db::{CentralDb, UserDb};
use crate::scheduler::Scheduler;
use crate::service_group::SessionManager;
use uuid::Uuid;

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

    Err(Status::unauthenticated("Authentication required"))
}

const PLATE_STOPS: &[f32] = &[45.0, 95.0, 135.0, 185.0, 225.0, 275.0, 315.0, 365.0, 405.0, 455.0, 495.0, 545.0, 585.0, 635.0];

fn generate_warmup_defs(working_weight: f32) -> Vec<(f32, i32)> {
    if working_weight <= 45.0 {
        return Vec::new();
    }

    let candidates: Vec<f32> = PLATE_STOPS.iter().cloned().filter(|&w| w < working_weight).collect();
    if candidates.is_empty() {
        return Vec::new();
    }

    let selected = if candidates.len() <= 4 {
        candidates
    } else {
        let n = candidates.len();
        let step = (n - 1) as f32 / 3.0;
        vec![
            candidates[0],
            candidates[step.round() as usize],
            candidates[(step * 2.0).round() as usize],
            candidates[n - 1],
        ]
    };

    let reps = match selected.len() {
        1 => vec![5],
        2 => vec![5, 5],
        3 => vec![5, 5, 3],
        4 => vec![5, 5, 3, 2],
        _ => vec![5; selected.len()],
    };
    
    selected.into_iter().zip(reps.into_iter()).collect()
}


// --- Exercise Group Generation ---

trait ExerciseGroupGenerator: Send + Sync {
    fn generate(
        &self,
        workout_id: &str,
        group_id: &str,
        exercises: &[i32],
        weights: &[f32],
        sets: i32,
        reps: i32,
        include_warmup: bool,
        start_order: i32,
    ) -> Vec<ProposedSet>;
}

struct StraightSetsGenerator;
impl ExerciseGroupGenerator for StraightSetsGenerator {
    fn generate(
        &self,
        workout_id: &str,
        group_id: &str,
        exercises: &[i32],
        weights: &[f32],
        sets: i32,
        reps: i32,
        include_warmup: bool,
        mut start_order: i32,
    ) -> Vec<ProposedSet> {
        let mut generated = Vec::new();
        let weight = weights.first().copied().unwrap_or(0.0);
        for &exercise in exercises {
            if include_warmup {
                let warmups = generate_warmup_defs(weight);
                for (w, r) in warmups {
                    generated.push(ProposedSet {
                        id: Uuid::new_v4().to_string(),
                        workout_id: workout_id.to_string(),
                        workout_order: start_order,
                        exercise,
                        target_reps: r,
                        target_weight: w,
                        warmup: true,
                        exercise_group_id: group_id.to_string(),
                    });
                    start_order += 1;
                }
            }

            for _ in 0..sets {
                generated.push(ProposedSet {
                    id: Uuid::new_v4().to_string(),
                    workout_id: workout_id.to_string(),
                    workout_order: start_order,
                    exercise,
                    target_reps: reps,
                    target_weight: weight,
                    warmup: false,
                    exercise_group_id: group_id.to_string(),
                });
                start_order += 1;
            }
        }
        generated
    }
}

struct SupersetGenerator;
impl ExerciseGroupGenerator for SupersetGenerator {
    fn generate(
        &self,
        workout_id: &str,
        group_id: &str,
        exercises: &[i32],
        weights: &[f32],
        sets: i32,
        reps: i32,
        include_warmup: bool,
        mut start_order: i32,
    ) -> Vec<ProposedSet> {
        let mut generated = Vec::new();
        // Warmups sequential
        for (i, &exercise) in exercises.iter().enumerate() {
            if include_warmup {
                let weight = weights.get(i).copied().unwrap_or(0.0);
                let warmups = generate_warmup_defs(weight);
                for (w, r) in warmups {
                    generated.push(ProposedSet {
                        id: Uuid::new_v4().to_string(),
                        workout_id: workout_id.to_string(),
                        workout_order: start_order,
                        exercise,
                        target_reps: r,
                        target_weight: w,
                        warmup: true,
                        exercise_group_id: group_id.to_string(),
                    });
                    start_order += 1;
                }
            }
        }
        // Working sets alternating
        for _ in 0..sets {
            for (i, &exercise) in exercises.iter().enumerate() {
                let weight = weights.get(i).copied().unwrap_or(0.0);
                generated.push(ProposedSet {
                    id: Uuid::new_v4().to_string(),
                    workout_id: workout_id.to_string(),
                    workout_order: start_order,
                    exercise,
                    target_reps: reps,
                    target_weight: weight,
                    warmup: false,
                    exercise_group_id: group_id.to_string(),
                });
                start_order += 1;
            }
        }
        generated
    }
}

struct DropsetGenerator;
impl ExerciseGroupGenerator for DropsetGenerator {
    fn generate(
        &self,
        workout_id: &str,
        group_id: &str,
        exercises: &[i32],
        weights: &[f32],
        _sets: i32,
        reps: i32,
        include_warmup: bool,
        mut start_order: i32,
    ) -> Vec<ProposedSet> {
        let mut generated = Vec::new();
        let &exercise = exercises.first().unwrap_or(&(Exercise::Unspecified as i32));
        let first_weight = weights.first().copied().unwrap_or(0.0);

        if include_warmup {
            let warmups = generate_warmup_defs(first_weight);
            for (w, r) in warmups {
                generated.push(ProposedSet {
                    id: Uuid::new_v4().to_string(),
                    workout_id: workout_id.to_string(),
                    workout_order: start_order,
                    exercise,
                    target_reps: r,
                    target_weight: w,
                    warmup: true,
                    exercise_group_id: group_id.to_string(),
                });
                start_order += 1;
            }
        }

        for &weight in weights {
            generated.push(ProposedSet {
                id: Uuid::new_v4().to_string(),
                workout_id: workout_id.to_string(),
                workout_order: start_order,
                exercise,
                target_reps: reps,
                target_weight: weight,
                warmup: false,
                exercise_group_id: group_id.to_string(),
            });
            start_order += 1;
        }
        generated
    }
}

fn get_generator(group_type: i32) -> Box<dyn ExerciseGroupGenerator> {
    if group_type == ExerciseGroupType::Superset as i32 {
        Box::new(SupersetGenerator)
    } else if group_type == ExerciseGroupType::Dropset as i32 {
        Box::new(DropsetGenerator)
    } else {
        Box::new(StraightSetsGenerator)
    }
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

        let workout_id = user_db.create_workout(&req.name, req.exercise_groups, req.proposed_sets).await
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

        let exercise_groups = user_db.get_exercise_groups(&req.workout_id).await
            .map_err(|e| Status::internal(format!("Failed to get exercise groups: {}", e)))?;

        let proposed_sets = user_db.get_proposed_sets(&req.workout_id).await
            .map_err(|e| Status::internal(format!("Failed to get proposed sets: {}", e)))?;

        let completed_sets = user_db.get_completed_sets(&req.workout_id).await
            .map_err(|e| Status::internal(format!("Failed to get completed sets: {}", e)))?;

        Ok(Response::new(GetWorkoutResponse {
            workout: Some(workout),
            exercise_groups,
            proposed_sets,
            completed_sets,
        }))
    }

    async fn create_exercise_group(
        &self,
        request: Request<CreateExerciseGroupRequest>,
    ) -> Result<Response<CreateExerciseGroupResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        let user_db = UserDb::new(&user_id).await
            .map_err(|e| Status::internal(format!("Failed to connect to user db: {}", e)))?;

        let group_id = Uuid::new_v4().to_string();
        
        // Fetch existing groups to determine workout_order
        let existing_groups = user_db.get_exercise_groups(&req.workout_id).await
            .map_err(|e| Status::internal(format!("Failed to fetch existing groups: {}", e)))?;
        let workout_order = existing_groups.len() as i32;

        let group = ExerciseGroup {
            id: group_id.clone(),
            workout_id: req.workout_id.clone(),
            name: req.name.clone(),
            r#type: req.r#type,
            include_warmup: req.include_warmup,
            workout_order,
        };

        let mut set_order = 0;

        // Fetch existing sets to determine starting workout_order for sets
        let existing_sets = user_db.get_proposed_sets(&req.workout_id).await
            .map_err(|e| Status::internal(format!("Failed to fetch existing sets: {}", e)))?;
        if let Some(last_set) = existing_sets.last() {
            set_order = last_set.workout_order + 1;
        }

        let generator = get_generator(req.r#type);
        let generated_sets = generator.generate(
            &req.workout_id,
            &group_id,
            &req.exercises,
            &req.weights,
            req.sets,
            req.reps,
            req.include_warmup,
            set_order,
        );

        user_db.create_exercise_group(group.clone(), generated_sets.clone()).await
            .map_err(|e| Status::internal(format!("Failed to save exercise group: {}", e)))?;

        self.session_manager.notify_user_update(&user_id).await;

        Ok(Response::new(CreateExerciseGroupResponse {
            group: Some(group),
            generated_sets,
        }))
    }

    async fn update_exercise_group(
        &self,
        request: Request<UpdateExerciseGroupRequest>,
    ) -> Result<Response<UpdateExerciseGroupResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        let user_db = UserDb::new(&user_id).await
            .map_err(|e| Status::internal(format!("Failed to connect to user db: {}", e)))?;

        // 1. Fetch existing group
        let groups = user_db.get_exercise_groups(&req.workout_id).await
            .map_err(|e| Status::internal(format!("Failed to fetch groups: {}", e)))?;
        let mut group = groups.into_iter().find(|g| g.id == req.exercise_group_id)
            .ok_or_else(|| Status::not_found("Exercise group not found"))?;

        // 2. Update group fields
        if !req.name.is_empty() { group.name = req.name.clone(); }
        group.include_warmup = req.include_warmup;

        // 3. Fetch existing sets and completed sets
        let all_proposed = user_db.get_proposed_sets(&req.workout_id).await
            .map_err(|e| Status::internal(e.to_string()))?;
        let group_proposed: Vec<_> = all_proposed.into_iter().filter(|p| p.exercise_group_id == group.id).collect();
        
        let completed = user_db.get_completed_sets(&req.workout_id).await
            .map_err(|e| Status::internal(e.to_string()))?;
        let completed_ids: std::collections::HashSet<_> = completed.into_iter().map(|c| c.proposed_set_id).collect();

        // 4. Determine which sets to keep (completed) and which to replace
        let mut new_sets = Vec::new();
        let completed_group_sets: Vec<_> = group_proposed.clone().into_iter().filter(|p| completed_ids.contains(&p.id)).collect();
        
        // Add completed sets back
        new_sets.extend(completed_group_sets.clone());

        // 5. Generate new sets
        // Determine unique exercises involved in this group from existing sets (preserving order)
        let mut exercises = Vec::new();
        for p in &group_proposed {
            if !exercises.contains(&p.exercise) {
                exercises.push(p.exercise);
            }
        }
        if exercises.is_empty() { exercises.push(Exercise::Unspecified as i32); }

        let mut set_order = new_sets.iter().map(|s| s.workout_order).max().unwrap_or(0);
        if !new_sets.is_empty() { set_order += 1; }

        let generator = get_generator(group.r#type);
        let all_generated = generator.generate(
            &req.workout_id,
            &group.id,
            &exercises,
            &req.weights,
            req.sets,
            req.reps,
            group.include_warmup,
            set_order,
        );

        // Filter out sets that were already completed (master of masters)
        for gen_set in &all_generated {
            let is_already_completed = new_sets.iter().any(|s| {
                s.exercise == gen_set.exercise && s.warmup == gen_set.warmup && 
                // This is a heuristic: if we have N completed sets of this type, we skip the first N generated sets of this type
                new_sets.iter().filter(|existing| existing.exercise == gen_set.exercise && existing.warmup == gen_set.warmup).count() > 
                all_generated.iter().filter(|g| g.exercise == gen_set.exercise && g.warmup == gen_set.warmup && g.workout_order < gen_set.workout_order).count()
            });

            if !is_already_completed {
                new_sets.push(gen_set.clone());
            }
        }

        user_db.update_exercise_group(group.clone(), new_sets).await
            .map_err(|e| Status::internal(format!("Failed to update group: {}", e)))?;

        // 6. Fetch the definitive re-indexed state from the DB to return
        let updated_group = user_db.get_exercise_groups(&req.workout_id).await
            .map_err(|e| Status::internal(e.to_string()))?
            .into_iter().find(|g| g.id == req.exercise_group_id)
            .ok_or_else(|| Status::not_found("Exercise group not found after update"))?;

        let updated_sets = user_db.get_proposed_sets(&req.workout_id).await
            .map_err(|e| Status::internal(e.to_string()))?
            .into_iter().filter(|p| p.exercise_group_id == updated_group.id).collect();

        self.session_manager.notify_user_update(&user_id).await;

        Ok(Response::new(UpdateExerciseGroupResponse {
            group: Some(updated_group),
            generated_sets: updated_sets,
        }))
    }

    async fn delete_exercise_group(
        &self,
        request: Request<DeleteExerciseGroupRequest>,
    ) -> Result<Response<DeleteExerciseGroupResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        let user_db = UserDb::new(&user_id).await
            .map_err(|e| Status::internal(format!("Failed to connect to user db: {}", e)))?;

        user_db.delete_exercise_group(&req.workout_id, &req.exercise_group_id).await
            .map_err(|e| Status::internal(format!("Failed to delete exercise group: {}", e)))?;

        self.session_manager.notify_user_update(&user_id).await;

        Ok(Response::new(DeleteExerciseGroupResponse {}))
    }

    async fn reorder_exercise_groups(
        &self,
        request: Request<ReorderExerciseGroupsRequest>,
    ) -> Result<Response<ReorderExerciseGroupsResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        let user_db = UserDb::new(&user_id).await
            .map_err(|e| Status::internal(format!("Failed to connect to user db: {}", e)))?;

        user_db.reorder_exercise_groups(&req.workout_id, req.exercise_group_ids).await
            .map_err(|e| Status::internal(format!("Failed to reorder exercise groups: {}", e)))?;

        self.session_manager.notify_user_update(&user_id).await;

        Ok(Response::new(ReorderExerciseGroupsResponse {}))
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

    async fn delete_completed_set(
        &self,
        request: Request<DeleteCompletedSetRequest>,
    ) -> Result<Response<DeleteCompletedSetResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        if req.workout_id.is_empty() {
            return Err(Status::invalid_argument("workout_id is required"));
        }
        if req.completed_set_id.is_empty() {
            return Err(Status::invalid_argument("completed_set_id is required"));
        }

        let user_db = UserDb::new(&user_id).await
            .map_err(|e| Status::internal(format!("Failed to connect to user db: {}", e)))?;

        user_db.delete_completed_set(&req.workout_id, &req.completed_set_id).await
            .map_err(|e| Status::internal(format!("Failed to delete completed set: {}", e)))?;

        self.session_manager.notify_user_update(&user_id).await;

        Ok(Response::new(DeleteCompletedSetResponse {}))
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

        // Sync final workout state to session DB, then leave the session.
        // The participant row is kept so their finished workout remains visible.
        self.session_manager.notify_user_update(&user_id).await;
        self.session_manager.finish_session(&user_id).await
            .map_err(|e| Status::internal(format!("Failed to finish session: {}", e)))?;

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
        let response = scheduler.get_proposed_schedule().await
            .map_err(|e| Status::internal(format!("Failed to generate schedule: {}", e)))?;

        Ok(Response::new(response))
    }
}