use crate::db::CentralDb;
use crate::progress::compute_next_up_set;
use crate::scheduler::Scheduler;
use crate::state::{ActiveWorkout, AppState};
use lift::workout::v1::{
    workout_service_server::WorkoutService, AppendWorkoutHeartRateRequest,
    AppendWorkoutHeartRateResponse, CancelProposedSetRequest, CancelProposedSetResponse,
    CompleteSetRequest, CompleteSetResponse, CompletedSet, CreateExerciseGroupRequest,
    CreateExerciseGroupResponse, DeleteCompletedSetRequest, DeleteCompletedSetResponse,
    DeleteExerciseGroupRequest, DeleteExerciseGroupResponse, EndWorkoutRequest, EndWorkoutResponse,
    ExerciseGroup, ExerciseTypeConfig, GetActiveWorkoutRequest, GetActiveWorkoutResponse,
    GetProposedWorkoutScheduleRequest, GetProposedWorkoutScheduleResponse, GetWorkoutRequest,
    GetWorkoutResponse, ListWorkoutsRequest, ListWorkoutsResponse, ProposedSet,
    ReorderExerciseGroupsRequest, ReorderExerciseGroupsResponse, RestConfig, StartSetRequest,
    StartSetResponse, StartWorkoutRequest, StartWorkoutResponse, UpdateExerciseGroupRequest,
    UpdateExerciseGroupResponse, Workout, WorkoutPlanChangeStats, WorkoutStateSnapshot,
};
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};
use tonic::{Request, Response, Status};
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
pub async fn get_user_id_authenticated<T>(
    request: &Request<T>,
    central_db: &CentralDb,
) -> Result<String, Status> {
    if let Some(token) = request
        .metadata()
        .get("x-session-token")
        .and_then(|v| v.to_str().ok())
    {
        if let Ok(Some(user_id)) = central_db.validate_auth_session(token).await {
            return Ok(user_id);
        }
    }

    Err(Status::unauthenticated("Authentication required"))
}

const PLATE_STOPS: &[f32] = &[
    45.0, 95.0, 135.0, 185.0, 225.0, 275.0, 315.0, 365.0, 405.0, 455.0, 495.0, 545.0, 585.0, 635.0,
];
const END_OF_EXERCISE_GROUP_REST_SECONDS: i64 = 10;

fn generate_warmup_defs(working_weight: f32) -> Vec<(f32, i32)> {
    if working_weight <= 45.0 {
        return Vec::new();
    }

    let candidates: Vec<f32> = PLATE_STOPS
        .iter()
        .cloned()
        .filter(|&w| w < working_weight)
        .collect();
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
    let warmup_defs: Vec<Vec<(f32, i32)>> = configs
        .iter()
        .map(|c| {
            if c.include_warmup {
                generate_warmup_defs(c.start_weight)
            } else {
                Vec::new()
            }
        })
        .collect();

    // Place warmups
    if group.interleave_warmups && configs.len() > 1 {
        // Round-robin warmups: A_w1, B_w1, A_w2, B_w2, ...
        let max_warmups = warmup_defs.iter().map(|d| d.len()).max().unwrap_or(0);
        for round in 0..max_warmups {
            for (cfg_idx, config) in configs.iter().enumerate() {
                if let Some(&(weight, reps)) = warmup_defs[cfg_idx].get(round) {
                    let is_last_warmup = warmup_defs[cfg_idx].len() == round + 1;
                    let (rest_s, rest_f) = get_rest_for_config(group, config, true, is_last_warmup);
                    sets.push(ProposedSet {
                        id: Uuid::new_v4().to_string(),
                        workout_id: workout_id.to_string(),
                        workout_order: order,
                        exercise: config.exercise,
                        target_reps: reps,
                        target_weight: weight,
                        warmup: true,
                        exercise_group_id: group.id.clone(),
                        rest_after_success: rest_s,
                        rest_after_failure: rest_f,
                        cancelled: false,
                        is_amrap: false,
                        instruction: String::new(),
                    });
                    order += 1;
                }
            }
        }
    } else {
        // Sequential warmups: all A warmups, then all B warmups
        for (cfg_idx, config) in configs.iter().enumerate() {
            let num_warmups = warmup_defs[cfg_idx].len();
            for (w_idx, &(weight, reps)) in warmup_defs[cfg_idx].iter().enumerate() {
                let is_last_warmup = w_idx == num_warmups - 1;
                let (rest_s, rest_f) = get_rest_for_config(group, config, true, is_last_warmup);
                sets.push(ProposedSet {
                    id: Uuid::new_v4().to_string(),
                    workout_id: workout_id.to_string(),
                    workout_order: order,
                    exercise: config.exercise,
                    target_reps: reps,
                    target_weight: weight,
                    warmup: true,
                    exercise_group_id: group.id.clone(),
                    rest_after_success: rest_s,
                    rest_after_failure: rest_f,
                    cancelled: false,
                    is_amrap: false,
                    instruction: String::new(),
                });
                order += 1;
            }
        }
    }

    // Working sets always interleave: A1, B1, A2, B2, ... for group.sets rounds
    let num_sets = group.sets.max(1);
    for set_idx in 0..num_sets {
        let is_last_working_set = set_idx == num_sets - 1;
        for config in configs {
            let weight = if num_sets <= 1 {
                config.start_weight
            } else {
                config.start_weight
                    + (set_idx as f32 / (num_sets - 1) as f32)
                        * (config.end_weight - config.start_weight)
            };
            // Round to nearest 5.0 (standard plate increment)
            let weight = (weight / 5.0).round() * 5.0;

            let is_amrap = config.last_set_amrap && is_last_working_set;
            let instruction = if is_amrap {
                "AMRAP — push for max reps".to_string()
            } else {
                String::new()
            };

            let (rest_s, rest_f) = get_rest_for_config(group, config, false, false);
            sets.push(ProposedSet {
                id: Uuid::new_v4().to_string(),
                workout_id: workout_id.to_string(),
                workout_order: order,
                exercise: config.exercise,
                target_reps: config.reps,
                target_weight: weight,
                warmup: false,
                exercise_group_id: group.id.clone(),
                rest_after_success: rest_s,
                rest_after_failure: rest_f,
                cancelled: false,
                is_amrap,
                instruction,
            });
            order += 1;
        }
    }

    sets
}

fn get_rest_for_config(
    group: &ExerciseGroup,
    config: &ExerciseTypeConfig,
    warmup: bool,
    last_warmup: bool,
) -> (i32, i32) {
    let rc = config
        .rest_config
        .as_ref()
        .filter(|rest_config| rest_config_has_values(rest_config))
        .or(group
            .rest_config
            .as_ref()
            .filter(|rest_config| rest_config_has_values(rest_config)));

    let success_rest = rc
        .and_then(|c| {
            if c.rest_after_success > 0 {
                Some(c.rest_after_success)
            } else {
                None
            }
        })
        .unwrap_or(180);

    let failure_rest = rc
        .and_then(|c| {
            if c.rest_after_failure > 0 {
                Some(c.rest_after_failure)
            } else {
                None
            }
        })
        .unwrap_or(300);

    if warmup {
        if last_warmup {
            // Last warmup should match the working-set success rest for this group/config.
            (success_rest, success_rest)
        } else {
            let r = rc
                .and_then(|c| {
                    if c.rest_after_warmup > 0 {
                        Some(c.rest_after_warmup)
                    } else {
                        None
                    }
                })
                .unwrap_or(10);
            (r, r)
        }
    } else {
        (success_rest, failure_rest)
    }
}

fn rest_config_has_values(rest_config: &RestConfig) -> bool {
    rest_config.rest_after_success > 0
        || rest_config.rest_after_failure > 0
        || rest_config.rest_after_warmup > 0
        || rest_config.rest_after_last_warmup > 0
}

fn normalize_rest_config(rest_config: Option<RestConfig>) -> Option<RestConfig> {
    rest_config.filter(rest_config_has_values)
}

fn is_default_rest_config(rc: &RestConfig) -> bool {
    rc.rest_after_success == 180
        && rc.rest_after_failure == 300
        && (rc.rest_after_warmup == 10 || rc.rest_after_warmup == 0)
}

fn normalize_exercise_configs(configs: &[ExerciseTypeConfig]) -> Vec<ExerciseTypeConfig> {
    configs
        .iter()
        .map(|config| {
            let mut normalized = config.clone();
            normalized.rest_config = normalize_rest_config(normalized.rest_config);
            if let Some(rc) = &normalized.rest_config {
                if is_default_rest_config(rc) {
                    normalized.rest_config = None;
                }
            }
            normalized
        })
        .collect()
}

fn apply_update_exercise_group(
    workout_ref: &mut ActiveWorkout,
    req: &UpdateExerciseGroupRequest,
) -> Result<(ExerciseGroup, Vec<ProposedSet>), Status> {
    let group = workout_ref
        .exercise_groups
        .iter_mut()
        .find(|g| g.id == req.exercise_group_id)
        .ok_or_else(|| Status::not_found("Exercise group not found"))?;

    if !req.name.is_empty() {
        group.name = req.name.clone();
    }
    group.sets = req.sets;
    group.interleave_warmups = req.interleave_warmups;
    group.exercise_configs = normalize_exercise_configs(&req.exercise_configs);
    group.rest_config = normalize_rest_config(req.rest_config.clone());
    let group = group.clone();

    let completed_ids: std::collections::HashSet<String> = workout_ref
        .completed_sets
        .iter()
        .filter(|c| !c.proposed_set_id.is_empty())
        .map(|c| c.proposed_set_id.clone())
        .collect();

    let mut completed_group_sets: Vec<ProposedSet> = workout_ref
        .proposed_sets
        .iter()
        .filter(|p| p.exercise_group_id == group.id && completed_ids.contains(&p.id))
        .cloned()
        .collect();
    completed_group_sets.sort_by_key(|s| s.workout_order);

    let generated = generate_sets_for_group(&req.workout_id, &group, 0);
    let mut completed_slots_by_key: std::collections::HashMap<(i32, bool), usize> =
        std::collections::HashMap::new();
    for set in &completed_group_sets {
        *completed_slots_by_key
            .entry((set.exercise, set.warmup))
            .or_insert(0) += 1;
    }

    // Cancel all pending sets in this group. Completed-associated proposed sets stay unchanged.
    for set in workout_ref
        .proposed_sets
        .iter_mut()
        .filter(|p| p.exercise_group_id == group.id)
    {
        if !completed_ids.contains(&set.id) {
            set.cancelled = true;
        }
    }

    // Generate only the remaining sets not already satisfied by completed-associated set slots.
    let mut pending_generated = Vec::new();
    for set in generated {
        let key = (set.exercise, set.warmup);
        if let Some(remaining) = completed_slots_by_key.get_mut(&key) {
            if *remaining > 0 {
                *remaining -= 1;
                continue;
            }
        }
        pending_generated.push(set);
    }
    workout_ref.proposed_sets.extend(pending_generated);
    workout_ref.reindex_sets();

    let updated_group = workout_ref
        .exercise_groups
        .iter()
        .find(|g| g.id == req.exercise_group_id)
        .cloned()
        .ok_or_else(|| Status::not_found("Exercise group not found after update"))?;

    // Pre-calculate last warmup workout_order for the group to avoid borrow issues
    let last_warmup_order = workout_ref
        .proposed_sets
        .iter()
        .filter(|p| p.exercise_group_id == updated_group.id && p.warmup && !p.cancelled)
        .map(|p| p.workout_order)
        .max();

    // Update rest config for all proposed sets in this group (including already completed ones)
    for set in workout_ref
        .proposed_sets
        .iter_mut()
        .filter(|p| p.exercise_group_id == updated_group.id && !p.cancelled)
    {
        if let Some(config) = updated_group
            .exercise_configs
            .iter()
            .find(|c| c.exercise == set.exercise)
        {
            let is_last_warmup = set.warmup && Some(set.workout_order) == last_warmup_order;

            let (rest_s, rest_f) =
                get_rest_for_config(&updated_group, config, set.warmup, is_last_warmup);
            set.rest_after_success = rest_s;
            set.rest_after_failure = rest_f;
        }
    }

    // Recalculate rest_until for all completed sets in this group.
    // Clone necessary data first to avoid borrow issues while iterating mutably.
    let current_proposed = workout_ref.proposed_sets.clone();
    let current_completed = workout_ref.completed_sets.clone();

    for cs in workout_ref.completed_sets.iter_mut() {
        if let Some(ps) = current_proposed
            .iter()
            .find(|p| p.id == cs.proposed_set_id && p.exercise_group_id == updated_group.id)
        {
            let is_final = is_final_set_in_exercise_group_after_completion(
                &ps.id,
                &current_proposed,
                &current_completed,
            );

            let mut rest_seconds = if cs.actual_reps >= ps.target_reps {
                ps.rest_after_success as i64
            } else {
                ps.rest_after_failure as i64
            };
            if is_final {
                rest_seconds = END_OF_EXERCISE_GROUP_REST_SECONDS;
            }
            cs.rest_until = cs.ended_at + rest_seconds;
        }
    }

    let updated_sets: Vec<ProposedSet> = workout_ref
        .proposed_sets
        .iter()
        .filter(|p| p.exercise_group_id == updated_group.id && !p.cancelled)
        .cloned()
        .collect();

    Ok((updated_group, updated_sets))
}

fn active_proposed_sets(proposed_sets: &[ProposedSet]) -> Vec<ProposedSet> {
    proposed_sets
        .iter()
        .filter(|set| !set.cancelled)
        .cloned()
        .collect()
}

fn workout_plan_change_stats_from_sets(proposed_sets: &[ProposedSet]) -> WorkoutPlanChangeStats {
    let cancelled_total = proposed_sets.iter().filter(|set| set.cancelled).count() as i32;
    let cancelled_warmups = proposed_sets
        .iter()
        .filter(|set| set.cancelled && set.warmup)
        .count() as i32;
    let cancelled_working = proposed_sets
        .iter()
        .filter(|set| set.cancelled && !set.warmup)
        .count() as i32;
    WorkoutPlanChangeStats {
        cancelled_total,
        cancelled_warmups,
        cancelled_working,
    }
}

fn next_up_from_workout_state(
    proposed_sets: &[ProposedSet],
    completed_sets: &[CompletedSet],
) -> Option<ProposedSet> {
    compute_next_up_set(proposed_sets, completed_sets)
}

fn is_final_set_in_exercise_group_after_completion(
    proposed_set_id: &str,
    proposed_sets: &[ProposedSet],
    completed_sets: &[CompletedSet],
) -> bool {
    let Some(current) = proposed_sets
        .iter()
        .find(|set| set.id == proposed_set_id && !set.cancelled)
    else {
        return false;
    };

    let group_id = &current.exercise_group_id;

    !proposed_sets
        .iter()
        .filter(|set| {
            set.exercise_group_id == *group_id && !set.cancelled && set.id != proposed_set_id
        })
        .any(|set| {
            !completed_sets
                .iter()
                .any(|done| done.proposed_set_id == set.id && done.ended_at != 0)
        })
}

fn now_unix() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

fn workout_state_snapshot_from_state(
    proposed_sets: &[ProposedSet],
    completed_sets: &[CompletedSet],
    now: i64,
) -> WorkoutStateSnapshot {
    let proposed_active = active_proposed_sets(proposed_sets);
    let next_up_set = compute_next_up_set(&proposed_active, completed_sets);
    const STATE_ALL_DONE: i32 = 1;
    const STATE_LIFTING: i32 = 2;
    const STATE_RESTING: i32 = 3;
    const STATE_READY: i32 = 5;

    let active_set = completed_sets
        .iter()
        .filter(|set| set.ended_at == 0)
        .max_by_key(|set| set.started_at);

    if let Some(active) = active_set {
        let display_set = proposed_active
            .iter()
            .find(|set| set.id == active.proposed_set_id)
            .cloned();
        return WorkoutStateSnapshot {
            state: STATE_LIFTING,
            display_set,
            active_started_at: active.started_at,
            rest_until: 0,
            last_rest_end: 0,
        };
    }

    let all_done = if proposed_active.is_empty() {
        // If there are no remaining active proposed sets (e.g. all were completed/cancelled),
        // treat workout as complete so UI can offer a clean finish action.
        true
    } else {
        proposed_active.iter().all(|set| {
            completed_sets
                .iter()
                .any(|done| done.proposed_set_id == set.id && done.ended_at != 0)
        })
    };

    let last_rest_end = completed_sets
        .iter()
        .filter(|set| set.ended_at != 0 && set.rest_until != 0)
        .max_by_key(|set| set.ended_at)
        .map(|set| set.rest_until)
        .unwrap_or(0);

    if all_done {
        return WorkoutStateSnapshot {
            state: STATE_ALL_DONE,
            display_set: None,
            active_started_at: 0,
            rest_until: 0,
            last_rest_end,
        };
    }

    let resting = completed_sets
        .iter()
        .filter(|set| set.ended_at != 0 && set.rest_until > now)
        .max_by_key(|set| set.ended_at);

    if let Some(resting) = resting {
        return WorkoutStateSnapshot {
            state: STATE_RESTING,
            display_set: next_up_set,
            active_started_at: 0,
            rest_until: resting.rest_until,
            last_rest_end: 0,
        };
    }

    WorkoutStateSnapshot {
        state: STATE_READY,
        display_set: next_up_set,
        active_started_at: 0,
        rest_until: 0,
        last_rest_end,
    }
}

fn start_workout_response_from_active(active: &ActiveWorkout) -> StartWorkoutResponse {
    let proposed_active = active_proposed_sets(&active.proposed_sets);
    let next_up_set = compute_next_up_set(&proposed_active, &active.completed_sets);
    let state_snapshot = Some(workout_state_snapshot_from_state(
        &active.proposed_sets,
        &active.completed_sets,
        now_unix(),
    ));

    StartWorkoutResponse {
        id: active.workout.id.clone(),
        workout: Some(active.workout.clone()),
        exercise_groups: active.exercise_groups.clone(),
        proposed_sets: proposed_active,
        completed_sets: active.completed_sets.clone(),
        next_up_set,
        state_snapshot,
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
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        // Check for existing active workout
        if let Some(active) = self.state.workouts.get(&user_id) {
            if active.workout.end_time == 0 {
                // Workout is still running, return it
                return Ok(Response::new(start_workout_response_from_active(&active)));
            } else {
                // Workout is finished, remove it from memory so we can start a new one
                drop(active); // Release lock
                self.state.workouts.remove(&user_id);
            }
        }

        let workout_id = Uuid::new_v4().to_string();
        let start_time = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64;

        let session_id = {
            let mut session_id = self
                .state
                .user_sessions
                .get(&user_id)
                .map(|s| s.clone())
                .unwrap_or_default();

            if session_id.is_empty() {
                // Every workout must belong to a session. Generate one if needed.
                session_id = Uuid::new_v4().to_string();
                self.state
                    .user_sessions
                    .insert(user_id.clone(), session_id.clone());
                let mut members = std::collections::HashSet::new();
                members.insert(user_id.clone());
                self.state.sessions.insert(session_id.clone(), members);

                // Persist join to DB
                let _ = self.central_db.join_session(&user_id, &session_id).await;
            }
            session_id
        };

        let workout = Workout {
            id: workout_id.clone(),
            name: req.name.clone(),
            start_time,
            end_time: 0,
            session_id,
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
        self.central_db
            .create_workout_record(&user_id, &workout)
            .await
            .map_err(|e| Status::internal(format!("Failed to create workout: {}", e)))?;

        // Incremental write: Create groups and proposed sets
        for g in &exercise_groups {
            let sets: Vec<_> = all_proposed_sets
                .iter()
                .filter(|s| s.exercise_group_id == g.id)
                .cloned()
                .collect();
            self.central_db
                .insert_exercise_group_with_sets(&user_id, g, &sets)
                .await
                .map_err(|e| Status::internal(format!("Failed to save workout group: {}", e)))?;
        }

        // Store in memory
        let mut active = ActiveWorkout::new(workout, exercise_groups, all_proposed_sets, vec![]);
        active.reindex_sets();
        let response = start_workout_response_from_active(&active);
        self.state.workouts.insert(user_id.clone(), active);

        Ok(Response::new(response))
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
                Some((
                    w.workout.clone(),
                    w.exercise_groups.clone(),
                    w.proposed_sets.clone(),
                    w.completed_sets.clone(),
                ))
            } else {
                None
            }
        });

        if let Some((workout, groups, proposed, _)) = cached {
            // Even if cached, we need to re-fetch completed sets if it's a shared session
            // to see other people's updates.
            let completed_sets = if !workout.session_id.is_empty() {
                self.central_db
                    .get_completed_sets_by_session(&workout.session_id)
                    .await
                    .map_err(|e| Status::internal(format!("Failed to get session sets: {}", e)))?
            } else {
                self.central_db
                    .get_completed_sets(&user_id, &workout.id)
                    .await
                    .map_err(|e| Status::internal(format!("Failed to get completed sets: {}", e)))?
            };

            // For state snapshot and next-up computation, only use the current user's
            // own completed sets. Using all session sets would incorrectly detect
            // another participant's active set (ended_at==0) as our own lifting state,
            // causing the bottom bar to vanish when display_set can't be resolved.
            let own_workout_id = workout.id.clone();
            let own_completed: Vec<CompletedSet> = completed_sets
                .iter()
                .filter(|c| c.workout_id == own_workout_id)
                .cloned()
                .collect();

            let proposed_active = active_proposed_sets(&proposed);
            let next_up_set = compute_next_up_set(&proposed_active, &own_completed);
            let plan_change_stats = Some(workout_plan_change_stats_from_sets(&proposed));
            let state_snapshot = Some(workout_state_snapshot_from_state(
                &proposed,
                &own_completed,
                now_unix(),
            ));

            return Ok(Response::new(GetWorkoutResponse {
                workout: Some(workout),
                exercise_groups: groups,
                proposed_sets: proposed,
                completed_sets,
                next_up_set,
                plan_change_stats,
                state_snapshot,
            }));
        }

        // Fall back to CentralDb for historical workouts
        let workout = self
            .central_db
            .get_workout(&user_id, &req.workout_id)
            .await
            .map_err(|e| Status::internal(format!("Failed to get workout: {}", e)))?
            .ok_or_else(|| Status::not_found("Workout not found"))?;

        let exercise_groups = self
            .central_db
            .get_exercise_groups(&user_id, &req.workout_id)
            .await
            .map_err(|e| Status::internal(format!("Failed to get exercise groups: {}", e)))?;

        let proposed_sets = self
            .central_db
            .get_proposed_sets(&user_id, &req.workout_id)
            .await
            .map_err(|e| Status::internal(format!("Failed to get proposed sets: {}", e)))?;

        let completed_sets = if !workout.session_id.is_empty() {
            self.central_db
                .get_completed_sets_by_session(&workout.session_id)
                .await
                .map_err(|e| Status::internal(format!("Failed to get session sets: {}", e)))?
        } else {
            self.central_db
                .get_completed_sets(&user_id, &req.workout_id)
                .await
                .map_err(|e| Status::internal(format!("Failed to get completed sets: {}", e)))?
        };

        // For state snapshot and next-up, only use the current user's own completed sets.
        let own_completed: Vec<CompletedSet> = completed_sets
            .iter()
            .filter(|c| c.workout_id == req.workout_id)
            .cloned()
            .collect();

        let proposed_active = active_proposed_sets(&proposed_sets);
        let next_up_set = compute_next_up_set(&proposed_active, &own_completed);
        let plan_change_stats = Some(workout_plan_change_stats_from_sets(&proposed_sets));
        let state_snapshot = Some(workout_state_snapshot_from_state(
            &proposed_sets,
            &own_completed,
            now_unix(),
        ));

        Ok(Response::new(GetWorkoutResponse {
            workout: Some(workout),
            exercise_groups,
            proposed_sets,
            completed_sets,
            next_up_set,
            plan_change_stats,
            state_snapshot,
        }))
    }

    async fn create_exercise_group(
        &self,
        request: Request<CreateExerciseGroupRequest>,
    ) -> Result<Response<CreateExerciseGroupResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        let (group, generated_sets, next_up_set, state_snapshot) = {
            let mut workout_ref = self
                .state
                .workouts
                .get_mut(&user_id)
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
                exercise_configs: normalize_exercise_configs(&req.exercise_configs),
                rest_config: normalize_rest_config(req.rest_config.clone()),
                instruction: String::new(),
            };

            let set_order = workout_ref
                .proposed_sets
                .last()
                .map(|s| s.workout_order + 1)
                .unwrap_or(0);

            let generated_sets = generate_sets_for_group(&req.workout_id, &group, set_order);

            workout_ref.exercise_groups.push(group.clone());
            workout_ref.proposed_sets.extend(generated_sets.clone());
            workout_ref.reindex_sets();
            let next_up_set =
                next_up_from_workout_state(&workout_ref.proposed_sets, &workout_ref.completed_sets);
            let state_snapshot = workout_state_snapshot_from_state(
                &workout_ref.proposed_sets,
                &workout_ref.completed_sets,
                now_unix(),
            );
            (group, generated_sets, next_up_set, state_snapshot)
        }; // Guard dropped here

        // Incremental write: save group and sets to DB
        self.central_db
            .insert_exercise_group_with_sets(&user_id, &group, &generated_sets)
            .await
            .map_err(|e| Status::internal(format!("Failed to save group to DB: {}", e)))?;

        Ok(Response::new(CreateExerciseGroupResponse {
            group: Some(group),
            generated_sets,
            next_up_set,
            state_snapshot: Some(state_snapshot),
        }))
    }

    async fn update_exercise_group(
        &self,
        request: Request<UpdateExerciseGroupRequest>,
    ) -> Result<Response<UpdateExerciseGroupResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        let (updated_group, updated_sets, full_workout_state, next_up_set, state_snapshot) = {
            let mut workout_ref = self
                .state
                .workouts
                .get_mut(&user_id)
                .ok_or_else(|| Status::failed_precondition("No active workout"))?;

            let (updated_group, updated_sets) =
                apply_update_exercise_group(&mut workout_ref, &req)?;

            let full_state = (
                workout_ref.workout.clone(),
                workout_ref.exercise_groups.clone(),
                workout_ref.proposed_sets.clone(),
                workout_ref.completed_sets.clone(),
            );
            let next_up_set =
                next_up_from_workout_state(&workout_ref.proposed_sets, &workout_ref.completed_sets);
            let state_snapshot = workout_state_snapshot_from_state(
                &workout_ref.proposed_sets,
                &workout_ref.completed_sets,
                now_unix(),
            );

            (
                updated_group,
                updated_sets,
                full_state,
                next_up_set,
                state_snapshot,
            )
        }; // Guard dropped here

        // Re-sync this workout to DB
        self.central_db
            .flush_workout(
                &user_id,
                &full_workout_state.0,
                &full_workout_state.1,
                &full_workout_state.2,
                &full_workout_state.3,
            )
            .await
            .map_err(|e| Status::internal(e.to_string()))?;

        Ok(Response::new(UpdateExerciseGroupResponse {
            group: Some(updated_group),
            generated_sets: updated_sets,
            next_up_set,
            state_snapshot: Some(state_snapshot),
        }))
    }

    async fn delete_exercise_group(
        &self,
        request: Request<DeleteExerciseGroupRequest>,
    ) -> Result<Response<DeleteExerciseGroupResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        let (full_workout_state, next_up_set, state_snapshot) = {
            let mut workout_ref = self
                .state
                .workouts
                .get_mut(&user_id)
                .ok_or_else(|| Status::failed_precondition("No active workout"))?;

            let completed_ids: std::collections::HashSet<String> = workout_ref
                .completed_sets
                .iter()
                .map(|c| c.proposed_set_id.clone())
                .collect();

            // Remove pending (non-completed) proposed sets for this group
            workout_ref.proposed_sets.retain(|p| {
                p.exercise_group_id != req.exercise_group_id || completed_ids.contains(&p.id)
            });

            // Remove the group
            workout_ref
                .exercise_groups
                .retain(|g| g.id != req.exercise_group_id);

            let full_state = (
                workout_ref.workout.clone(),
                workout_ref.exercise_groups.clone(),
                workout_ref.proposed_sets.clone(),
                workout_ref.completed_sets.clone(),
            );
            let next_up_set =
                next_up_from_workout_state(&workout_ref.proposed_sets, &workout_ref.completed_sets);
            let state_snapshot = workout_state_snapshot_from_state(
                &workout_ref.proposed_sets,
                &workout_ref.completed_sets,
                now_unix(),
            );
            (full_state, next_up_set, state_snapshot)
        }; // Guard dropped here

        // Re-sync to DB
        self.central_db
            .flush_workout(
                &user_id,
                &full_workout_state.0,
                &full_workout_state.1,
                &full_workout_state.2,
                &full_workout_state.3,
            )
            .await
            .map_err(|e| Status::internal(e.to_string()))?;

        Ok(Response::new(DeleteExerciseGroupResponse {
            next_up_set,
            state_snapshot: Some(state_snapshot),
        }))
    }

    async fn reorder_exercise_groups(
        &self,
        request: Request<ReorderExerciseGroupsRequest>,
    ) -> Result<Response<ReorderExerciseGroupsResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        let (full_workout_state, next_up_set, state_snapshot) = {
            let mut workout_ref = self
                .state
                .workouts
                .get_mut(&user_id)
                .ok_or_else(|| Status::failed_precondition("No active workout"))?;

            for (idx, group_id) in req.exercise_group_ids.iter().enumerate() {
                if let Some(g) = workout_ref
                    .exercise_groups
                    .iter_mut()
                    .find(|g| &g.id == group_id)
                {
                    g.workout_order = idx as i32;
                }
            }

            workout_ref.reindex_sets();

            let full_state = (
                workout_ref.workout.clone(),
                workout_ref.exercise_groups.clone(),
                workout_ref.proposed_sets.clone(),
                workout_ref.completed_sets.clone(),
            );
            let next_up_set =
                next_up_from_workout_state(&workout_ref.proposed_sets, &workout_ref.completed_sets);
            let state_snapshot = workout_state_snapshot_from_state(
                &workout_ref.proposed_sets,
                &workout_ref.completed_sets,
                now_unix(),
            );
            (full_state, next_up_set, state_snapshot)
        }; // Guard dropped here

        // Re-sync to DB
        self.central_db
            .flush_workout(
                &user_id,
                &full_workout_state.0,
                &full_workout_state.1,
                &full_workout_state.2,
                &full_workout_state.3,
            )
            .await
            .map_err(|e| Status::internal(e.to_string()))?;

        Ok(Response::new(ReorderExerciseGroupsResponse {
            next_up_set,
            state_snapshot: Some(state_snapshot),
        }))
    }

    async fn list_workouts(
        &self,
        request: Request<ListWorkoutsRequest>,
    ) -> Result<Response<ListWorkoutsResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;

        // 1. Get active workout while holding the lock
        let active_workout = self.state.workouts.get(&user_id).map(|w| w.workout.clone());

        // 2. Perform DB IO outside the lock
        let mut workouts = self
            .central_db
            .list_workouts(&user_id)
            .await
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

        let (completed_set, next_up_set, state_snapshot) = {
            let mut workout_ref = self
                .state
                .workouts
                .get_mut(&user_id)
                .ok_or_else(|| Status::failed_precondition("No active workout"))?;

            let proposed = workout_ref
                .proposed_sets
                .iter()
                .find(|p| p.id == req.proposed_set_id && !p.cancelled);
            if proposed.is_none() {
                return Err(Status::failed_precondition("Proposed set not available"));
            }

            let (actual_reps, actual_weight) = proposed
                .map(|p| (p.target_reps, p.target_weight))
                .unwrap_or((0, 0.0));

            let id = Uuid::new_v4().to_string();
            let started_at = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs() as i64;

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
            let next_up_set =
                next_up_from_workout_state(&workout_ref.proposed_sets, &workout_ref.completed_sets);
            let state_snapshot = workout_state_snapshot_from_state(
                &workout_ref.proposed_sets,
                &workout_ref.completed_sets,
                now_unix(),
            );
            (completed_set, next_up_set, state_snapshot)
        }; // Guard dropped here

        // Incremental write: save to DB
        self.central_db
            .upsert_completed_set(&user_id, &completed_set)
            .await
            .map_err(|e| Status::internal(format!("Failed to save set to DB: {}", e)))?;

        Ok(Response::new(StartSetResponse {
            completed_set: Some(completed_set),
            next_up_set,
            state_snapshot: Some(state_snapshot),
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

        let now = now_unix();
        let ended_at = if req.completed_at > 0 {
            if (now - req.completed_at).abs() > 30 {
                return Err(Status::invalid_argument(
                    "completed_at must be within 30 seconds of server time",
                ));
            }
            req.completed_at
        } else {
            now
        };

        let (completed_set, next_up_set, state_snapshot) = {
            let mut workout_ref = self
                .state
                .workouts
                .get_mut(&user_id)
                .ok_or_else(|| Status::failed_precondition("No active workout"))?;

            // Look up proposed set info for rest computation
            let proposed = workout_ref
                .proposed_sets
                .iter()
                .find(|p| p.id == req.proposed_set_id && !p.cancelled)
                .cloned()
                .ok_or_else(|| Status::failed_precondition("Proposed set not available"))?;

            let is_final_set_in_group = is_final_set_in_exercise_group_after_completion(
                &req.proposed_set_id,
                &workout_ref.proposed_sets,
                &workout_ref.completed_sets,
            );

            let (target_reps, rest_s, rest_f) = (
                proposed.target_reps,
                proposed.rest_after_success,
                proposed.rest_after_failure,
            );

            let mut rest_seconds = if req.actual_reps >= target_reps {
                rest_s as i64
            } else {
                rest_f as i64
            };
            if is_final_set_in_group {
                rest_seconds = END_OF_EXERCISE_GROUP_REST_SECONDS;
            }
            // Keep recorded completion time from client event, but start rest from
            // server "now" so debounce/network delay doesn't consume rest duration.
            let rest_base = ended_at.max(now_unix());
            let rest_until = rest_base + rest_seconds;

            // Find existing started set or create new
            let existing_idx = workout_ref.completed_sets.iter().position(|c| {
                c.workout_id == req.workout_id
                    && c.proposed_set_id == req.proposed_set_id
                    && c.ended_at == 0
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
            let next_up_set =
                next_up_from_workout_state(&workout_ref.proposed_sets, &workout_ref.completed_sets);
            let state_snapshot = workout_state_snapshot_from_state(
                &workout_ref.proposed_sets,
                &workout_ref.completed_sets,
                now_unix(),
            );
            (completed_set, next_up_set, state_snapshot)
        }; // Guard dropped here

        // Incremental write: save to DB
        self.central_db
            .upsert_completed_set(&user_id, &completed_set)
            .await
            .map_err(|e| Status::internal(format!("Failed to save completed set to DB: {}", e)))?;

        Ok(Response::new(CompleteSetResponse {
            completed_set: Some(completed_set),
            next_up_set,
            state_snapshot: Some(state_snapshot),
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

        let (next_up_set, state_snapshot) = {
            let mut workout_ref = self
                .state
                .workouts
                .get_mut(&user_id)
                .ok_or_else(|| Status::failed_precondition("No active workout"))?;

            workout_ref
                .completed_sets
                .retain(|c| !(c.workout_id == req.workout_id && c.id == req.completed_set_id));
            let next_up_set =
                next_up_from_workout_state(&workout_ref.proposed_sets, &workout_ref.completed_sets);
            let state_snapshot = workout_state_snapshot_from_state(
                &workout_ref.proposed_sets,
                &workout_ref.completed_sets,
                now_unix(),
            );
            (next_up_set, state_snapshot)
        }; // Guard dropped here

        // Incremental write: delete from DB
        self.central_db
            .delete_completed_set_record(&user_id, &req.workout_id, &req.completed_set_id)
            .await
            .map_err(|e| Status::internal(format!("Failed to delete set from DB: {}", e)))?;

        Ok(Response::new(DeleteCompletedSetResponse {
            next_up_set,
            state_snapshot: Some(state_snapshot),
        }))
    }

    async fn cancel_proposed_set(
        &self,
        request: Request<CancelProposedSetRequest>,
    ) -> Result<Response<CancelProposedSetResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        if req.workout_id.is_empty() {
            return Err(Status::invalid_argument("workout_id is required"));
        }
        if req.proposed_set_id.is_empty() {
            return Err(Status::invalid_argument("proposed_set_id is required"));
        }

        let (full_workout_state, next_up_set, state_snapshot) = {
            let mut workout_ref = self
                .state
                .workouts
                .get_mut(&user_id)
                .ok_or_else(|| Status::failed_precondition("No active workout"))?;

            let proposed_idx = workout_ref
                .proposed_sets
                .iter()
                .position(|set| {
                    set.workout_id == req.workout_id
                        && set.id == req.proposed_set_id
                        && !set.cancelled
                })
                .ok_or_else(|| Status::not_found("Proposed set not found"))?;

            let proposed = &workout_ref.proposed_sets[proposed_idx];
            if !proposed.warmup {
                return Err(Status::failed_precondition(
                    "Only warmup sets can be cancelled with this endpoint",
                ));
            }

            let has_completed = workout_ref
                .completed_sets
                .iter()
                .any(|set| set.proposed_set_id == req.proposed_set_id);
            if has_completed {
                return Err(Status::failed_precondition(
                    "Cannot cancel a proposed set that has completed-set records",
                ));
            }

            workout_ref.proposed_sets[proposed_idx].cancelled = true;

            let full_state = (
                workout_ref.workout.clone(),
                workout_ref.exercise_groups.clone(),
                workout_ref.proposed_sets.clone(),
                workout_ref.completed_sets.clone(),
            );
            let next_up_set =
                next_up_from_workout_state(&workout_ref.proposed_sets, &workout_ref.completed_sets);
            let state_snapshot = workout_state_snapshot_from_state(
                &workout_ref.proposed_sets,
                &workout_ref.completed_sets,
                now_unix(),
            );
            (full_state, next_up_set, state_snapshot)
        }; // Guard dropped here

        self.central_db
            .flush_workout(
                &user_id,
                &full_workout_state.0,
                &full_workout_state.1,
                &full_workout_state.2,
                &full_workout_state.3,
            )
            .await
            .map_err(|e| Status::internal(e.to_string()))?;

        Ok(Response::new(CancelProposedSetResponse {
            next_up_set,
            state_snapshot: Some(state_snapshot),
        }))
    }

    async fn append_workout_heart_rate(
        &self,
        request: Request<AppendWorkoutHeartRateRequest>,
    ) -> Result<Response<AppendWorkoutHeartRateResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        if req.workout_id.is_empty() {
            return Err(Status::invalid_argument("workout_id is required"));
        }
        if req.samples.is_empty() {
            return Ok(Response::new(AppendWorkoutHeartRateResponse { stored: 0 }));
        }

        {
            let active = self
                .state
                .workouts
                .get(&user_id)
                .ok_or_else(|| Status::failed_precondition("No active workout"))?;
            if active.workout.id != req.workout_id {
                return Err(Status::failed_precondition("Workout ID mismatch"));
            }
        }

        self.central_db
            .insert_workout_heart_rate_samples(&user_id, &req.workout_id, &req.samples)
            .await
            .map_err(|e| {
                Status::internal(format!("Failed to persist heart rate samples: {}", e))
            })?;

        Ok(Response::new(AppendWorkoutHeartRateResponse {
            stored: req.samples.len() as i32,
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

        // Remove from memory
        let active = {
            let (_, mut active) = self
                .state
                .workouts
                .remove(&user_id)
                .ok_or_else(|| Status::not_found("No active workout found"))?;

            let end_time = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_secs() as i64;
            active.workout.end_time = end_time;
            active
        }; // Guard dropped here

        // Incremental write: Just update end time!
        self.central_db
            .update_workout_end_time(&user_id, &active.workout.id, active.workout.end_time)
            .await
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
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        let workout = self.state.workouts.get(&user_id).map(|w| w.workout.clone());

        Ok(Response::new(GetActiveWorkoutResponse { workout }))
    }

    async fn get_proposed_workout_schedule(
        &self,
        request: Request<GetProposedWorkoutScheduleRequest>,
    ) -> Result<Response<GetProposedWorkoutScheduleResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;

        // 1. Get active workout ID while holding lock
        let active_workout_id = self
            .state
            .workouts
            .get(&user_id)
            .map(|w| w.workout.id.clone());

        // 2. Perform DB IO outside the lock
        let scheduler = Scheduler::new(self.central_db.clone());
        let mut response = scheduler
            .get_proposed_schedule(&user_id)
            .await
            .map_err(|e| Status::internal(format!("Failed to generate schedule: {}", e)))?;

        // 3. Override active_workout_id from in-memory state if present
        if let Some(id) = active_workout_id {
            response.active_workout_id = id;
        }

        Ok(Response::new(response))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[derive(Clone)]
    struct Case {
        name: &'static str,
        request: UpdateExerciseGroupRequest,
        initial_sets: i32,
        completed_indexes: Vec<usize>,
        expected_target_group_total_sets: usize,
        expected_target_group_working_set_count: usize,
        expected_target_group_working_weights: Vec<f32>,
        expected_target_group_rest_success: Vec<i32>,
        expected_target_group_rest_failure: Vec<i32>,
    }

    fn config(
        exercise: i32,
        start_weight: f32,
        end_weight: f32,
        reps: i32,
        include_warmup: bool,
        rest_config: Option<RestConfig>,
    ) -> ExerciseTypeConfig {
        ExerciseTypeConfig {
            exercise,
            start_weight,
            end_weight,
            reps,
            include_warmup,
            rest_config,
            last_set_amrap: false,
        }
    }

    fn group(
        id: &str,
        name: &str,
        sets: i32,
        workout_order: i32,
        configs: Vec<ExerciseTypeConfig>,
        rest_config: Option<RestConfig>,
    ) -> ExerciseGroup {
        ExerciseGroup {
            id: id.to_string(),
            workout_id: "w1".to_string(),
            name: name.to_string(),
            sets,
            interleave_warmups: false,
            workout_order,
            exercise_configs: configs,
            rest_config,
            instruction: String::new(),
        }
    }

    fn rest(success: i32, failure: i32, warmup: i32, last_warmup: i32) -> RestConfig {
        RestConfig {
            rest_after_success: success,
            rest_after_failure: failure,
            rest_after_warmup: warmup,
            rest_after_last_warmup: last_warmup,
        }
    }

    fn with_stable_ids(group: &ExerciseGroup, mut sets: Vec<ProposedSet>) -> Vec<ProposedSet> {
        for (idx, set) in sets.iter_mut().enumerate() {
            set.id = format!("{}-{}", group.id, idx);
        }
        sets
    }

    fn proposed(id: &str, group_id: &str, cancelled: bool) -> ProposedSet {
        ProposedSet {
            id: id.to_string(),
            workout_id: "w1".to_string(),
            workout_order: 0,
            exercise: 1,
            target_reps: 5,
            target_weight: 100.0,
            warmup: false,
            exercise_group_id: group_id.to_string(),
            rest_after_success: 90,
            rest_after_failure: 180,
            cancelled,
            is_amrap: false,
            instruction: String::new(),
        }
    }

    fn completed(proposed_set_id: &str) -> CompletedSet {
        CompletedSet {
            id: format!("c-{}", proposed_set_id),
            workout_id: "w1".to_string(),
            proposed_set_id: proposed_set_id.to_string(),
            actual_reps: 5,
            actual_weight: 100.0,
            started_at: 10,
            ended_at: 20,
            rest_until: 100,
        }
    }

    #[test]
    fn update_exercise_group_table_driven() {
        let cases = vec![
            Case {
                name: "no completed sets regenerates full target group",
                request: UpdateExerciseGroupRequest {
                    workout_id: "w1".to_string(),
                    exercise_group_id: "g1".to_string(),
                    name: "Updated Squat".to_string(),
                    sets: 3,
                    interleave_warmups: false,
                    exercise_configs: vec![config(1, 135.0, 155.0, 5, false, None)],
                    rest_config: Some(rest(120, 240, 20, 150)),
                },
                initial_sets: 2,
                completed_indexes: vec![],
                expected_target_group_total_sets: 3,
                expected_target_group_working_set_count: 3,
                expected_target_group_working_weights: vec![135.0, 145.0, 155.0],
                expected_target_group_rest_success: vec![120, 120, 120],
                expected_target_group_rest_failure: vec![240, 240, 240],
            },
            Case {
                name: "one completed set keeps one old proposed and regenerates remaining",
                request: UpdateExerciseGroupRequest {
                    workout_id: "w1".to_string(),
                    exercise_group_id: "g1".to_string(),
                    name: "Updated Squat".to_string(),
                    sets: 4,
                    interleave_warmups: false,
                    exercise_configs: vec![config(1, 135.0, 165.0, 5, false, None)],
                    rest_config: Some(rest(90, 210, 10, 180)),
                },
                initial_sets: 3,
                completed_indexes: vec![0],
                expected_target_group_total_sets: 4,
                expected_target_group_working_set_count: 4,
                expected_target_group_working_weights: vec![100.0, 145.0, 155.0, 165.0],
                expected_target_group_rest_success: vec![90, 90, 90, 90],
                expected_target_group_rest_failure: vec![210, 210, 210, 210],
            },
            Case {
                name: "two completed sets and fewer target sets keeps completed only",
                request: UpdateExerciseGroupRequest {
                    workout_id: "w1".to_string(),
                    exercise_group_id: "g1".to_string(),
                    name: "Updated Squat".to_string(),
                    sets: 1,
                    interleave_warmups: false,
                    exercise_configs: vec![config(1, 150.0, 150.0, 5, false, None)],
                    rest_config: Some(rest(110, 220, 15, 160)),
                },
                initial_sets: 3,
                completed_indexes: vec![0, 1],
                expected_target_group_total_sets: 2,
                expected_target_group_working_set_count: 2,
                expected_target_group_working_weights: vec![100.0, 100.0],
                expected_target_group_rest_success: vec![110, 110],
                expected_target_group_rest_failure: vec![220, 220],
            },
            Case {
                name: "group rest config applies when config rest config absent",
                request: UpdateExerciseGroupRequest {
                    workout_id: "w1".to_string(),
                    exercise_group_id: "g1".to_string(),
                    name: "Updated Squat".to_string(),
                    sets: 2,
                    interleave_warmups: false,
                    exercise_configs: vec![config(1, 135.0, 145.0, 5, false, None)],
                    rest_config: Some(rest(75, 135, 12, 100)),
                },
                initial_sets: 2,
                completed_indexes: vec![],
                expected_target_group_total_sets: 2,
                expected_target_group_working_set_count: 2,
                expected_target_group_working_weights: vec![135.0, 145.0],
                expected_target_group_rest_success: vec![75, 75],
                expected_target_group_rest_failure: vec![135, 135],
            },
            Case {
                name:
                    "empty config rest config is normalized and does not override group rest config",
                request: UpdateExerciseGroupRequest {
                    workout_id: "w1".to_string(),
                    exercise_group_id: "g1".to_string(),
                    name: "Updated Squat".to_string(),
                    sets: 2,
                    interleave_warmups: false,
                    exercise_configs: vec![config(
                        1,
                        135.0,
                        145.0,
                        5,
                        false,
                        Some(rest(0, 0, 0, 0)),
                    )],
                    rest_config: Some(rest(95, 205, 12, 100)),
                },
                initial_sets: 2,
                completed_indexes: vec![],
                expected_target_group_total_sets: 2,
                expected_target_group_working_set_count: 2,
                expected_target_group_working_weights: vec![135.0, 145.0],
                expected_target_group_rest_success: vec![95, 95],
                expected_target_group_rest_failure: vec![205, 205],
            },
        ];

        for case in cases {
            let target_group = group(
                "g1",
                "Squat",
                case.initial_sets,
                0,
                vec![config(1, 100.0, 100.0, 5, false, None)],
                None,
            );
            let other_group = group(
                "g2",
                "Bench",
                1,
                1,
                vec![config(2, 185.0, 185.0, 5, false, None)],
                None,
            );

            let target_sets = with_stable_ids(
                &target_group,
                generate_sets_for_group("w1", &target_group, 0),
            );
            let other_sets = with_stable_ids(
                &other_group,
                generate_sets_for_group("w1", &other_group, 100),
            );

            let completed_sets: Vec<CompletedSet> = case
                .completed_indexes
                .iter()
                .enumerate()
                .map(|(idx, set_idx)| CompletedSet {
                    id: format!("c{}", idx),
                    workout_id: "w1".to_string(),
                    proposed_set_id: target_sets[*set_idx].id.clone(),
                    actual_reps: target_sets[*set_idx].target_reps,
                    actual_weight: target_sets[*set_idx].target_weight,
                    started_at: 0,
                    ended_at: 0,
                    rest_until: 0,
                })
                .collect();

            let mut workout = ActiveWorkout::new(
                Workout {
                    id: "w1".to_string(),
                    name: "Test".to_string(),
                    start_time: 0,
                    end_time: 0,
                    session_id: String::new(),
                },
                vec![target_group, other_group],
                target_sets.into_iter().chain(other_sets).collect(),
                completed_sets,
            );
            workout.reindex_sets();

            let result = apply_update_exercise_group(&mut workout, &case.request).expect(case.name);
            let updated_sets = result.1;

            assert_eq!(
                updated_sets.len(),
                case.expected_target_group_total_sets,
                "{}",
                case.name
            );
            let working_sets: Vec<&ProposedSet> =
                updated_sets.iter().filter(|s| !s.warmup).collect();
            assert_eq!(
                working_sets.len(),
                case.expected_target_group_working_set_count,
                "{}",
                case.name
            );

            let working_weights: Vec<f32> = working_sets.iter().map(|s| s.target_weight).collect();
            assert_eq!(
                working_weights, case.expected_target_group_working_weights,
                "{}",
                case.name
            );

            let rest_successes: Vec<i32> =
                working_sets.iter().map(|s| s.rest_after_success).collect();
            assert_eq!(
                rest_successes, case.expected_target_group_rest_success,
                "{}",
                case.name
            );

            let rest_failures: Vec<i32> =
                working_sets.iter().map(|s| s.rest_after_failure).collect();
            assert_eq!(
                rest_failures, case.expected_target_group_rest_failure,
                "{}",
                case.name
            );

            let other_group_sets: Vec<&ProposedSet> = workout
                .proposed_sets
                .iter()
                .filter(|s| s.exercise_group_id == "g2")
                .collect();
            assert_eq!(other_group_sets.len(), 1, "{}", case.name);
        }
    }

    #[test]
    fn last_warmup_rest_matches_success_rest_for_group() {
        let g = group(
            "g1",
            "Squat",
            2,
            0,
            vec![config(1, 135.0, 155.0, 5, true, None)],
            Some(rest(75, 135, 12, 240)),
        );

        let sets = generate_sets_for_group("w1", &g, 0);
        let warmups: Vec<&ProposedSet> = sets.iter().filter(|s| s.warmup).collect();
        assert!(warmups.len() >= 2);

        // Non-last warmup keeps warmup rest.
        assert_eq!(warmups[0].rest_after_success, 12);
        assert_eq!(warmups[0].rest_after_failure, 12);

        // Last warmup uses working-set success rest.
        let last = warmups[warmups.len() - 1];
        assert_eq!(last.rest_after_success, 75);
        assert_eq!(last.rest_after_failure, 75);
    }

    #[test]
    fn update_group_weight_change_cancels_old_pending_and_preserves_working_count() {
        let initial_group = group(
            "g1",
            "Squat",
            3,
            0,
            vec![config(1, 100.0, 100.0, 5, false, None)],
            None,
        );

        let mut initial_sets = with_stable_ids(
            &initial_group,
            generate_sets_for_group("w1", &initial_group, 0),
        );
        assert_eq!(initial_sets.len(), 3);

        let completed = CompletedSet {
            id: "c1".to_string(),
            workout_id: "w1".to_string(),
            proposed_set_id: initial_sets.remove(0).id,
            actual_reps: 5,
            actual_weight: 100.0,
            started_at: 0,
            ended_at: 1,
            rest_until: 10,
        };

        let mut workout = ActiveWorkout::new(
            Workout {
                id: "w1".to_string(),
                name: "Test".to_string(),
                start_time: 0,
                end_time: 0,
                session_id: String::new(),
            },
            vec![initial_group],
            with_stable_ids(
                &group(
                    "g1",
                    "Squat",
                    3,
                    0,
                    vec![config(1, 100.0, 100.0, 5, false, None)],
                    None,
                ),
                generate_sets_for_group(
                    "w1",
                    &group(
                        "g1",
                        "Squat",
                        3,
                        0,
                        vec![config(1, 100.0, 100.0, 5, false, None)],
                        None,
                    ),
                    0,
                ),
            ),
            vec![completed],
        );

        let req = UpdateExerciseGroupRequest {
            workout_id: "w1".to_string(),
            exercise_group_id: "g1".to_string(),
            name: "Squat".to_string(),
            sets: 3,
            interleave_warmups: false,
            exercise_configs: vec![config(1, 185.0, 185.0, 5, true, None)],
            rest_config: None,
        };

        let _ = apply_update_exercise_group(&mut workout, &req).expect("update");

        let active_group_sets: Vec<&ProposedSet> = workout
            .proposed_sets
            .iter()
            .filter(|set| set.exercise_group_id == "g1" && !set.cancelled)
            .collect();
        let cancelled_group_sets: Vec<&ProposedSet> = workout
            .proposed_sets
            .iter()
            .filter(|set| set.exercise_group_id == "g1" && set.cancelled)
            .collect();
        let working_active: Vec<&ProposedSet> = active_group_sets
            .iter()
            .copied()
            .filter(|set| !set.warmup)
            .collect();

        // 3 warmups + 3 working in target plan, with 1 working already completed => 5 active pending+completed.
        assert_eq!(active_group_sets.len(), 6);
        assert_eq!(working_active.len(), 3);
        assert_eq!(cancelled_group_sets.len(), 2);
    }

    #[test]
    fn final_set_detection_true_when_group_done_after_completion() {
        let proposed_sets = vec![
            proposed("g1-1", "g1", false),
            proposed("g1-2", "g1", false),
            proposed("g2-1", "g2", false),
        ];
        let completed_sets = vec![completed("g1-2")];

        assert!(is_final_set_in_exercise_group_after_completion(
            "g1-1",
            &proposed_sets,
            &completed_sets
        ));
    }

    #[test]
    fn final_set_detection_false_when_same_group_pending_exists() {
        let proposed_sets = vec![
            proposed("g1-1", "g1", false),
            proposed("g1-2", "g1", false),
            proposed("g2-1", "g2", false),
        ];
        let completed_sets = Vec::<CompletedSet>::new();

        assert!(!is_final_set_in_exercise_group_after_completion(
            "g1-1",
            &proposed_sets,
            &completed_sets
        ));
    }

    #[test]
    fn final_set_detection_ignores_cancelled_remaining_sets() {
        let proposed_sets = vec![
            proposed("g1-1", "g1", false),
            proposed("g1-cancelled", "g1", true),
            proposed("g2-1", "g2", false),
        ];
        let completed_sets = Vec::<CompletedSet>::new();

        assert!(is_final_set_in_exercise_group_after_completion(
            "g1-1",
            &proposed_sets,
            &completed_sets
        ));
    }

    #[test]
    fn state_snapshot_is_all_done_when_no_active_proposed_sets_remain() {
        let proposed_sets = Vec::<ProposedSet>::new();
        let completed_sets = Vec::<CompletedSet>::new();

        let snapshot = workout_state_snapshot_from_state(&proposed_sets, &completed_sets, 0);
        assert_eq!(snapshot.state, 1);
        assert!(snapshot.display_set.is_none());
    }

    #[test]
    fn update_group_rest_config_is_ignored_if_exercise_configs_have_rest_config() {
        let exercise_rest = rest(180, 300, 10, 180);
        let initial_group = group(
            "g1",
            "Squat",
            2,
            0,
            vec![config(1, 100.0, 100.0, 5, false, Some(exercise_rest))],
            None,
        );

        let initial_sets = generate_sets_for_group("w1", &initial_group, 0);
        assert_eq!(initial_sets[0].rest_after_success, 180);

        let mut workout = ActiveWorkout::new(
            Workout {
                id: "w1".to_string(),
                name: "Test".to_string(),
                start_time: 0,
                end_time: 0,
                session_id: String::new(),
            },
            vec![initial_group],
            initial_sets,
            vec![],
        );

        // Update group rest config to 150, and keep same exercise config (with its default 180,300,10 rest config)
        let new_group_rest = rest(150, 300, 20, 150);
        let req = UpdateExerciseGroupRequest {
            workout_id: "w1".to_string(),
            exercise_group_id: "g1".to_string(),
            name: "Squat".to_string(),
            sets: 2,
            interleave_warmups: false,
            exercise_configs: vec![config(
                1,
                100.0,
                100.0,
                5,
                false,
                Some(rest(180, 300, 10, 180)),
            )],
            rest_config: Some(new_group_rest),
        };

        let result = apply_update_exercise_group(&mut workout, &req).expect("update");
        let updated_sets = result.1;

        // Now it should be 150 because the default 180,300,10 should be cleared
        assert_eq!(updated_sets[0].rest_after_success, 150, "Group rest config should have taken precedence because the exercise config had defaults");
    }
}
