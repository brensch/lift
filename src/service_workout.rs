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
    ExerciseGroup, ProposedSet, CompletedSet, Workout,
};
use crate::db::CentralDb;
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

/// Unified set generation from ExerciseGroup with ExerciseTypeConfigs.
/// Generates warmup sets and working sets based on group configuration.
fn generate_sets_for_group(
    workout_id: &str,
    group: &ExerciseGroup,
    start_order: i32,
) -> Vec<ProposedSet> {
    let mut sets = Vec::new();
    let mut order = start_order;

    let configs = &group.exercise_configs;
    if configs.is_empty() {
        return sets;
    }

    // Generate warmup defs per config
    let warmup_defs: Vec<Vec<(f32, i32)>> = configs.iter().map(|c| {
        if c.include_warmup {
            generate_warmup_defs(c.start_weight)
        } else {
            Vec::new()
        }
    }).collect();

    // Place warmups
    if group.interleave_warmups && configs.len() > 1 {
        // Round-robin warmups: A_w1, B_w1, A_w2, B_w2, ...
        let max_warmups = warmup_defs.iter().map(|d| d.len()).max().unwrap_or(0);
        for round in 0..max_warmups {
            for (cfg_idx, config) in configs.iter().enumerate() {
                if let Some(&(weight, reps)) = warmup_defs[cfg_idx].get(round) {
                    sets.push(ProposedSet {
                        id: Uuid::new_v4().to_string(),
                        workout_id: workout_id.to_string(),
                        workout_order: order,
                        exercise: config.exercise,
                        target_reps: reps,
                        target_weight: weight,
                        warmup: true,
                        exercise_group_id: group.id.clone(),
                    });
                    order += 1;
                }
            }
        }
    } else {
        // Sequential warmups: all A warmups, then all B warmups
        for (cfg_idx, config) in configs.iter().enumerate() {
            for &(weight, reps) in &warmup_defs[cfg_idx] {
                sets.push(ProposedSet {
                    id: Uuid::new_v4().to_string(),
                    workout_id: workout_id.to_string(),
                    workout_order: order,
                    exercise: config.exercise,
                    target_reps: reps,
                    target_weight: weight,
                    warmup: true,
                    exercise_group_id: group.id.clone(),
                });
                order += 1;
            }
        }
    }

    // Working sets always interleave: A1, B1, A2, B2, ... for group.sets rounds
    let num_sets = group.sets.max(1);
    for set_idx in 0..num_sets {
        for config in configs {
            let weight = if num_sets <= 1 {
                config.start_weight
            } else {
                config.start_weight + (set_idx as f32 / (num_sets - 1) as f32) * (config.end_weight - config.start_weight)
            };
            // Round to nearest 5.0 (standard plate increment)
            let weight = (weight / 5.0).round() * 5.0;

            sets.push(ProposedSet {
                id: Uuid::new_v4().to_string(),
                workout_id: workout_id.to_string(),
                workout_order: order,
                exercise: config.exercise,
                target_reps: config.reps,
                target_weight: weight,
                warmup: false,
                exercise_group_id: group.id.clone(),
            });
            order += 1;
        }
    }

    sets
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

        // Lazy crash recovery: check CentralDb once per user for un-ended workouts
        self.state.try_recover_user(&self.central_db, &user_id).await;

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

        // Assign workout_id to exercise_groups and generate sets server-side
        let mut exercise_groups = req.exercise_groups;
        let mut all_proposed_sets = Vec::new();
        let mut set_order = 0i32;

        for g in &mut exercise_groups {
            g.workout_id = workout_id.clone();
            if g.id.is_empty() {
                g.id = Uuid::new_v4().to_string();
            }
            let generated = generate_sets_for_group(&workout_id, g, set_order);
            set_order += generated.len() as i32;
            all_proposed_sets.extend(generated);
        }

        // Incremental write: Create workout record
        self.central_db.create_workout_record(&user_id, &workout).await
            .map_err(|e| Status::internal(format!("Failed to create workout: {}", e)))?;

        // Incremental write: Create groups and proposed sets
        for g in &exercise_groups {
            let sets: Vec<_> = all_proposed_sets.iter().filter(|s| s.exercise_group_id == g.id).cloned().collect();
            self.central_db.insert_exercise_group_with_sets(&user_id, g, &sets).await
                .map_err(|e| Status::internal(format!("Failed to save workout group: {}", e)))?;
        }

        // Store in memory
        let mut active = ActiveWorkout::new(workout, exercise_groups, all_proposed_sets, vec![]);
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

        // Check in-memory first - clone data to release lock
        let cached = self.state.workouts.get(&user_id).and_then(|w| {
            if w.workout.id == req.workout_id {
                Some((w.workout.clone(), w.exercise_groups.clone(), w.proposed_sets.clone(), w.completed_sets.clone()))
            } else {
                None
            }
        });

        if let Some((workout, groups, proposed, completed)) = cached {
            return Ok(Response::new(GetWorkoutResponse {
                workout: Some(workout),
                exercise_groups: groups,
                proposed_sets: proposed,
                completed_sets: completed,
            }));
        }

        // Fall back to CentralDb for historical workouts
        let workout = self.central_db.get_workout(&user_id, &req.workout_id).await
            .map_err(|e| Status::internal(format!("Failed to get workout: {}", e)))?
            .ok_or_else(|| Status::not_found("Workout not found"))?;

        let exercise_groups = self.central_db.get_exercise_groups(&user_id, &req.workout_id).await
            .map_err(|e| Status::internal(format!("Failed to get exercise groups: {}", e)))?;

        let proposed_sets = self.central_db.get_proposed_sets(&user_id, &req.workout_id).await
            .map_err(|e| Status::internal(format!("Failed to get proposed sets: {}", e)))?;

        let completed_sets = self.central_db.get_completed_sets(&user_id, &req.workout_id).await
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

        let (group, generated_sets) = {
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
                sets: req.sets,
                interleave_warmups: req.interleave_warmups,
                workout_order,
                exercise_configs: req.exercise_configs.clone(),
            };

            let set_order = workout_ref.proposed_sets.last()
                .map(|s| s.workout_order + 1)
                .unwrap_or(0);

            let generated_sets = generate_sets_for_group(
                &req.workout_id,
                &group,
                set_order,
            );

            workout_ref.exercise_groups.push(group.clone());
            workout_ref.proposed_sets.extend(generated_sets.clone());
            workout_ref.reindex_sets();
            (group, generated_sets)
        }; // Guard dropped here

        // Incremental write: save group and sets to DB
        self.central_db.insert_exercise_group_with_sets(&user_id, &group, &generated_sets).await
            .map_err(|e| Status::internal(format!("Failed to save group to DB: {}", e)))?;

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

        let (updated_group, updated_sets, full_workout_state) = {
            let mut workout_ref = self.state.workouts.get_mut(&user_id)
                .ok_or_else(|| Status::failed_precondition("No active workout"))?;

            // Find the group
            let group = workout_ref.exercise_groups.iter_mut()
                .find(|g| g.id == req.exercise_group_id)
                .ok_or_else(|| Status::not_found("Exercise group not found"))?;

            // Update group fields
            if !req.name.is_empty() { group.name = req.name.clone(); }
            group.sets = req.sets;
            group.interleave_warmups = req.interleave_warmups;
            group.exercise_configs = req.exercise_configs.clone();
            let group = group.clone();

            // Find completed set IDs
            let completed_ids: std::collections::HashSet<String> = workout_ref.completed_sets
                .iter()
                .map(|c| c.proposed_set_id.clone())
                .collect();

            // Keep completed proposed sets for this group
            let completed_group_sets: Vec<ProposedSet> = workout_ref.proposed_sets
                .iter()
                .filter(|p| p.exercise_group_id == group.id && completed_ids.contains(&p.id))
                .cloned()
                .collect();

            // Generate new sets from updated configs
            let set_order = completed_group_sets.iter().map(|s| s.workout_order).max().unwrap_or(0)
                + if completed_group_sets.is_empty() { 0 } else { 1 };

            let generated = generate_sets_for_group(
                &req.workout_id,
                &group,
                set_order,
            );

            // Only keep generated sets that aren't already completed
            let pending_generated: Vec<ProposedSet> = generated.into_iter()
                .filter(|g| !completed_ids.contains(&g.id))
                .collect();

            let mut new_sets = completed_group_sets;
            new_sets.extend(pending_generated);

            // Remove old group sets and add new ones
            workout_ref.proposed_sets.retain(|p| p.exercise_group_id != group.id);
            workout_ref.proposed_sets.extend(new_sets.clone());
            workout_ref.reindex_sets();

            let updated_group = workout_ref.exercise_groups.iter()
                .find(|g| g.id == req.exercise_group_id)
                .cloned()
                .ok_or_else(|| Status::not_found("Exercise group not found after update"))?;

            let updated_sets: Vec<ProposedSet> = workout_ref.proposed_sets.iter()
                .filter(|p| p.exercise_group_id == updated_group.id)
                .cloned()
                .collect();

            let full_state = (
                workout_ref.workout.clone(),
                workout_ref.exercise_groups.clone(),
                workout_ref.proposed_sets.clone(),
                workout_ref.completed_sets.clone(),
            );

            (updated_group, updated_sets, full_state)
        }; // Guard dropped here

        // Re-sync this workout to DB
        self.central_db.flush_workout(
            &user_id,
            &full_workout_state.0,
            &full_workout_state.1,
            &full_workout_state.2,
            &full_workout_state.3,
        ).await.map_err(|e| Status::internal(e.to_string()))?;

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

        let full_workout_state = {
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

            (
                workout_ref.workout.clone(),
                workout_ref.exercise_groups.clone(),
                workout_ref.proposed_sets.clone(),
                workout_ref.completed_sets.clone(),
            )
        }; // Guard dropped here

        // Re-sync to DB
        self.central_db.flush_workout(
            &user_id,
            &full_workout_state.0,
            &full_workout_state.1,
            &full_workout_state.2,
            &full_workout_state.3,
        ).await.map_err(|e| Status::internal(e.to_string()))?;

        Ok(Response::new(DeleteExerciseGroupResponse {}))
    }

    async fn reorder_exercise_groups(
        &self,
        request: Request<ReorderExerciseGroupsRequest>,
    ) -> Result<Response<ReorderExerciseGroupsResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        let full_workout_state = {
            let mut workout_ref = self.state.workouts.get_mut(&user_id)
                .ok_or_else(|| Status::failed_precondition("No active workout"))?;

            for (idx, group_id) in req.exercise_group_ids.iter().enumerate() {
                if let Some(g) = workout_ref.exercise_groups.iter_mut().find(|g| &g.id == group_id) {
                    g.workout_order = idx as i32;
                }
            }

            workout_ref.reindex_sets();

            (
                workout_ref.workout.clone(),
                workout_ref.exercise_groups.clone(),
                workout_ref.proposed_sets.clone(),
                workout_ref.completed_sets.clone(),
            )
        }; // Guard dropped here

        // Re-sync to DB
        self.central_db.flush_workout(
            &user_id,
            &full_workout_state.0,
            &full_workout_state.1,
            &full_workout_state.2,
            &full_workout_state.3,
        ).await.map_err(|e| Status::internal(e.to_string()))?;

        Ok(Response::new(ReorderExerciseGroupsResponse {}))
    }

    async fn list_workouts(
        &self,
        request: Request<ListWorkoutsRequest>,
    ) -> Result<Response<ListWorkoutsResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;

        // 1. Get active workout while holding the lock
        let active_workout = self.state.workouts.get(&user_id).map(|w| w.workout.clone());

        // 2. Perform DB IO outside the lock
        let mut workouts = self.central_db.list_workouts(&user_id).await
            .map_err(|e| Status::internal(format!("Failed to list workouts: {}", e)))?;

        // If there's an active workout in memory, make sure it's in the list
        if let Some(active) = active_workout {
            if !workouts.iter().any(|existing| existing.id == active.id) {
                workouts.insert(0, active);
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

        let completed_set = {
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
            completed_set
        }; // Guard dropped here

        // Incremental write: save to DB
        self.central_db.upsert_completed_set(&user_id, &completed_set).await
            .map_err(|e| Status::internal(format!("Failed to save set to DB: {}", e)))?;

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

        let completed_set = {
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

            if let Some(idx) = existing_idx {
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
            }
        }; // Guard dropped here

        // Incremental write: save to DB
        self.central_db.upsert_completed_set(&user_id, &completed_set).await
            .map_err(|e| Status::internal(format!("Failed to save completed set to DB: {}", e)))?;

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

        {
            let mut workout_ref = self.state.workouts.get_mut(&user_id)
                .ok_or_else(|| Status::failed_precondition("No active workout"))?;

            workout_ref.completed_sets.retain(|c| {
                !(c.workout_id == req.workout_id && c.id == req.completed_set_id)
            });
        } // Guard dropped here

        // Incremental write: delete from DB
        self.central_db.delete_completed_set_record(&user_id, &req.workout_id, &req.completed_set_id).await
            .map_err(|e| Status::internal(format!("Failed to delete set from DB: {}", e)))?;

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

        // Remove from memory
        let active = {
            let (_, mut active) = self.state.workouts.remove(&user_id)
                .ok_or_else(|| Status::not_found("No active workout found"))?;

            let end_time = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs() as i64;
            active.workout.end_time = end_time;
            active
        }; // Guard dropped here

        // Incremental write: Just update end time!
        self.central_db.update_workout_end_time(&user_id, &active.workout.id, active.workout.end_time).await
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
            let _ = self.central_db.leave_session(&user_id, &session_id).await;
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

        // Lazy crash recovery: check CentralDb once per user for un-ended workouts
        self.state.try_recover_user(&self.central_db, &user_id).await;

        let workout = self.state.workouts.get(&user_id)
            .map(|w| w.workout.clone());

        Ok(Response::new(GetActiveWorkoutResponse { workout }))
    }

    async fn get_proposed_workout_schedule(
        &self,
        request: Request<GetProposedWorkoutScheduleRequest>,
    ) -> Result<Response<GetProposedWorkoutScheduleResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;

        // 1. Get active workout ID while holding lock
        let active_workout_id = self.state.workouts.get(&user_id)
            .map(|w| w.workout.id.clone());

        // 2. Perform DB IO outside the lock
        let scheduler = Scheduler::new(self.central_db.clone());
        let mut response = scheduler.get_proposed_schedule(&user_id).await
            .map_err(|e| Status::internal(format!("Failed to generate schedule: {}", e)))?;

        // 3. Override active_workout_id from in-memory state if present
        if let Some(id) = active_workout_id {
            response.active_workout_id = id;
        }

        Ok(Response::new(response))
    }
}
