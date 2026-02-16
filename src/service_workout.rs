use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};
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
    ExerciseGroup, ProposedSet, CompletedSet, ExerciseGroupType, Exercise, Workout,
};
use crate::db::{CentralDb, UserDb};
use crate::scheduler::Scheduler;
use crate::state::{ActiveWorkout, AppState};
use uuid::Uuid;

pub struct MyWorkoutService {
    central_db: CentralDb,
    state: Arc<AppState>,
}

impl MyWorkoutService {
    pub fn new(central_db: CentralDb, state: Arc<AppState>) -> Self {
        Self { central_db, state }
    }
}

// Helper to extract user_id from request metadata.
pub async fn get_user_id_authenticated<T>(request: &Request<T>, central_db: &CentralDb) -> Result<String, Status> {
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

fn compute_rest_seconds(
    target_reps: i32,
    actual_reps: i32,
    warmup: bool,
    last_warmup: bool,
) -> i64 {
    if warmup && last_warmup {
        180
    } else if warmup {
        10
    } else if actual_reps >= target_reps {
        180
    } else {
        300
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

        // Lazy crash recovery: check UserDb once per user for un-ended workouts
        self.state.try_recover_user(&user_id).await;

        if self.state.workouts.contains_key(&user_id) {
            return Err(Status::failed_precondition("A workout is already in progress. End it before starting a new one."));
        }

        let workout_id = Uuid::new_v4().to_string();
        let start_time = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs() as i64;

        let workout = Workout {
            id: workout_id.clone(),
            name: req.name.clone(),
            start_time,
            end_time: 0,
        };

        // Assign workout_id to exercise_groups and proposed_sets
        let mut exercise_groups = req.exercise_groups;
        for g in &mut exercise_groups {
            g.workout_id = workout_id.clone();
        }
        let mut proposed_sets = req.proposed_sets;
        for s in &mut proposed_sets {
            s.workout_id = workout_id.clone();
            if s.id.is_empty() {
                s.id = Uuid::new_v4().to_string();
            }
        }

        // Write initial workout row to UserDb (for crash recovery)
        let user_db = UserDb::new(&user_id).await
            .map_err(|e| Status::internal(format!("Failed to connect to user db: {}", e)))?;
        user_db.flush_workout(&workout, &exercise_groups, &proposed_sets, &[]).await
            .map_err(|e| Status::internal(format!("Failed to create workout: {}", e)))?;

        // Store in memory
        let mut active = ActiveWorkout::new(workout, exercise_groups, proposed_sets, vec![]);
        active.reindex_sets();
        self.state.workouts.insert(user_id.clone(), active);


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

        // Check in-memory first
        if let Some(w) = self.state.workouts.get(&user_id) {
            if w.workout.id == req.workout_id {
                return Ok(Response::new(GetWorkoutResponse {
                    workout: Some(w.workout.clone()),
                    exercise_groups: w.exercise_groups.clone(),
                    proposed_sets: w.proposed_sets.clone(),
                    completed_sets: w.completed_sets.clone(),
                }));
            }
        }

        // Fall back to UserDb for historical workouts
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

        let mut workout_ref = self.state.workouts.get_mut(&user_id)
            .ok_or_else(|| Status::failed_precondition("No active workout"))?;

        if workout_ref.workout.id != req.workout_id {
            return Err(Status::failed_precondition("Workout ID mismatch"));
        }

        let group_id = Uuid::new_v4().to_string();
        let workout_order = workout_ref.exercise_groups.len() as i32;

        let group = ExerciseGroup {
            id: group_id.clone(),
            workout_id: req.workout_id.clone(),
            name: req.name.clone(),
            r#type: req.r#type,
            include_warmup: req.include_warmup,
            workout_order,
        };

        let set_order = workout_ref.proposed_sets.last()
            .map(|s| s.workout_order + 1)
            .unwrap_or(0);

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

        workout_ref.exercise_groups.push(group.clone());
        workout_ref.proposed_sets.extend(generated_sets.clone());
        workout_ref.reindex_sets();
        workout_ref.mark_dirty();

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

        let mut workout_ref = self.state.workouts.get_mut(&user_id)
            .ok_or_else(|| Status::failed_precondition("No active workout"))?;

        // Find the group
        let group = workout_ref.exercise_groups.iter_mut()
            .find(|g| g.id == req.exercise_group_id)
            .ok_or_else(|| Status::not_found("Exercise group not found"))?;

        if !req.name.is_empty() { group.name = req.name.clone(); }
        group.include_warmup = req.include_warmup;
        let group = group.clone();

        // Find completed set IDs
        let completed_ids: std::collections::HashSet<String> = workout_ref.completed_sets
            .iter()
            .map(|c| c.proposed_set_id.clone())
            .collect();

        // Separate group's proposed sets into completed and pending
        let group_proposed: Vec<ProposedSet> = workout_ref.proposed_sets
            .iter()
            .filter(|p| p.exercise_group_id == group.id)
            .cloned()
            .collect();

        let completed_group_sets: Vec<ProposedSet> = group_proposed.iter()
            .filter(|p| completed_ids.contains(&p.id))
            .cloned()
            .collect();

        // Determine exercises from existing sets
        let mut exercises = Vec::new();
        for p in &group_proposed {
            if !exercises.contains(&p.exercise) {
                exercises.push(p.exercise);
            }
        }
        if exercises.is_empty() { exercises.push(Exercise::Unspecified as i32); }

        let mut new_sets = completed_group_sets.clone();

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

        for gen_set in &all_generated {
            let is_already_completed = new_sets.iter().any(|s| {
                s.exercise == gen_set.exercise && s.warmup == gen_set.warmup &&
                new_sets.iter().filter(|existing| existing.exercise == gen_set.exercise && existing.warmup == gen_set.warmup).count() >
                all_generated.iter().filter(|g| g.exercise == gen_set.exercise && g.warmup == gen_set.warmup && g.workout_order < gen_set.workout_order).count()
            });
            if !is_already_completed {
                new_sets.push(gen_set.clone());
            }
        }

        // Remove old group sets and add new ones
        workout_ref.proposed_sets.retain(|p| p.exercise_group_id != group.id);
        workout_ref.proposed_sets.extend(new_sets.clone());
        workout_ref.reindex_sets();
        workout_ref.mark_dirty();

        // Build response from current state
        let updated_group = workout_ref.exercise_groups.iter()
            .find(|g| g.id == req.exercise_group_id)
            .cloned()
            .ok_or_else(|| Status::not_found("Exercise group not found after update"))?;

        let updated_sets: Vec<ProposedSet> = workout_ref.proposed_sets.iter()
            .filter(|p| p.exercise_group_id == updated_group.id)
            .cloned()
            .collect();

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

        let mut workout_ref = self.state.workouts.get_mut(&user_id)
            .ok_or_else(|| Status::failed_precondition("No active workout"))?;

        let completed_ids: std::collections::HashSet<String> = workout_ref.completed_sets
            .iter()
            .map(|c| c.proposed_set_id.clone())
            .collect();

        // Remove pending (non-completed) proposed sets for this group
        workout_ref.proposed_sets.retain(|p| {
            p.exercise_group_id != req.exercise_group_id || completed_ids.contains(&p.id)
        });

        // Remove the group
        workout_ref.exercise_groups.retain(|g| g.id != req.exercise_group_id);
        workout_ref.mark_dirty();

        Ok(Response::new(DeleteExerciseGroupResponse {}))
    }

    async fn reorder_exercise_groups(
        &self,
        request: Request<ReorderExerciseGroupsRequest>,
    ) -> Result<Response<ReorderExerciseGroupsResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        let mut workout_ref = self.state.workouts.get_mut(&user_id)
            .ok_or_else(|| Status::failed_precondition("No active workout"))?;

        for (idx, group_id) in req.exercise_group_ids.iter().enumerate() {
            if let Some(g) = workout_ref.exercise_groups.iter_mut().find(|g| &g.id == group_id) {
                g.workout_order = idx as i32;
            }
        }

        workout_ref.reindex_sets();
        workout_ref.mark_dirty();

        Ok(Response::new(ReorderExerciseGroupsResponse {}))
    }

    async fn list_workouts(
        &self,
        request: Request<ListWorkoutsRequest>,
    ) -> Result<Response<ListWorkoutsResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;

        let user_db = UserDb::new(&user_id).await
            .map_err(|e| Status::internal(format!("Failed to connect to user db: {}", e)))?;

        let mut workouts = user_db.list_workouts().await
            .map_err(|e| Status::internal(format!("Failed to list workouts: {}", e)))?;

        // If there's an active workout in memory, make sure it's in the list
        if let Some(w) = self.state.workouts.get(&user_id) {
            if !workouts.iter().any(|existing| existing.id == w.workout.id) {
                workouts.insert(0, w.workout.clone());
            }
        }

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

        let mut workout_ref = self.state.workouts.get_mut(&user_id)
            .ok_or_else(|| Status::failed_precondition("No active workout"))?;

        let proposed = workout_ref.proposed_sets.iter()
            .find(|p| p.id == req.proposed_set_id);

        let (actual_reps, actual_weight) = proposed
            .map(|p| (p.target_reps, p.target_weight))
            .unwrap_or((0, 0.0));

        let id = Uuid::new_v4().to_string();
        let started_at = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs() as i64;

        let completed_set = CompletedSet {
            id,
            workout_id: req.workout_id,
            proposed_set_id: req.proposed_set_id,
            actual_reps,
            actual_weight,
            started_at,
            ended_at: 0,
            rest_until: 0,
        };

        workout_ref.completed_sets.push(completed_set.clone());
        workout_ref.mark_dirty();

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

        let mut workout_ref = self.state.workouts.get_mut(&user_id)
            .ok_or_else(|| Status::failed_precondition("No active workout"))?;

        let ended_at = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs() as i64;

        // Look up proposed set info for rest computation
        let proposed = workout_ref.proposed_sets.iter()
            .find(|p| p.id == req.proposed_set_id);

        let (target_reps, warmup, exercise, workout_order) = proposed
            .map(|p| (p.target_reps, p.warmup, p.exercise, p.workout_order))
            .unwrap_or((0, false, 0, 0));

        // Check if this is the last warmup
        let last_warmup = if warmup {
            let next = workout_ref.proposed_sets.iter()
                .filter(|p| p.workout_order > workout_order)
                .min_by_key(|p| p.workout_order);
            match next {
                Some(n) if n.warmup && n.exercise == exercise => false,
                _ => true,
            }
        } else {
            false
        };

        let rest_seconds = compute_rest_seconds(target_reps, req.actual_reps, warmup, last_warmup);
        let rest_until = ended_at + rest_seconds;

        // Find existing started set or create new
        let existing_idx = workout_ref.completed_sets.iter().position(|c| {
            c.workout_id == req.workout_id && c.proposed_set_id == req.proposed_set_id && c.ended_at == 0
        });

        let completed_set = if let Some(idx) = existing_idx {
            let cs = &mut workout_ref.completed_sets[idx];
            cs.actual_reps = req.actual_reps;
            cs.actual_weight = req.actual_weight;
            cs.ended_at = ended_at;
            cs.rest_until = rest_until;
            cs.clone()
        } else {
            let cs = CompletedSet {
                id: Uuid::new_v4().to_string(),
                workout_id: req.workout_id,
                proposed_set_id: req.proposed_set_id,
                actual_reps: req.actual_reps,
                actual_weight: req.actual_weight,
                started_at: ended_at,
                ended_at,
                rest_until,
            };
            workout_ref.completed_sets.push(cs.clone());
            cs
        };

        workout_ref.mark_dirty();

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

        let mut workout_ref = self.state.workouts.get_mut(&user_id)
            .ok_or_else(|| Status::failed_precondition("No active workout"))?;

        workout_ref.completed_sets.retain(|c| {
            !(c.workout_id == req.workout_id && c.id == req.completed_set_id)
        });
        workout_ref.mark_dirty();

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

        // Remove from memory, flush to DB
        let (_, mut active) = self.state.workouts.remove(&user_id)
            .ok_or_else(|| Status::not_found("No active workout found"))?;

        let end_time = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs() as i64;
        active.workout.end_time = end_time;

        let user_db = UserDb::new(&user_id).await
            .map_err(|e| Status::internal(format!("Failed to connect to user db: {}", e)))?;

        user_db.flush_workout(
            &active.workout,
            &active.exercise_groups,
            &active.proposed_sets,
            &active.completed_sets,
        ).await
            .map_err(|e| Status::internal(format!("Failed to end workout: {}", e)))?;

        // Leave session
        if let Some((_, session_id)) = self.state.user_sessions.remove(&user_id) {
            if let Some(mut members) = self.state.sessions.get_mut(&session_id) {
                members.remove(&user_id);
                if members.is_empty() {
                    drop(members);
                    self.state.sessions.remove(&session_id);
                }
            }
            // Record session in user's DB
            let _ = user_db.add_session(&session_id, false).await;
        }

        Ok(Response::new(EndWorkoutResponse {
            workout: Some(active.workout),
        }))
    }

    async fn get_active_workout(
        &self,
        request: Request<GetActiveWorkoutRequest>,
    ) -> Result<Response<GetActiveWorkoutResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;

        // Lazy crash recovery: check UserDb once per user for un-ended workouts
        self.state.try_recover_user(&user_id).await;

        let workout = self.state.workouts.get(&user_id)
            .map(|w| w.workout.clone());

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
        let mut response = scheduler.get_proposed_schedule().await
            .map_err(|e| Status::internal(format!("Failed to generate schedule: {}", e)))?;

        // Override active_workout_id from in-memory state if present
        if let Some(w) = self.state.workouts.get(&user_id) {
            response.active_workout_id = w.workout.id.clone();
        }

        Ok(Response::new(response))
    }
}
