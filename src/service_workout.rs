use crate::db::CentralDb;
use crate::program_state::{
    parse_state_payload, serialize_state_payload, ProgramStateEventRecord, WorkingSetResult,
    WorkoutCompletionResult,
};
use crate::progress::compute_next_up_set;
use crate::regimes::get_regime;
use crate::scheduler::Scheduler;
use crate::state::{ActiveWorkout, AppState};
#[cfg(test)]
use lift::workout::v1::UpdateExerciseGroupRequest;
use lift::workout::v1::{
    workout_service_server::WorkoutService, AppendWorkoutHeartRateRequest,
    AppendWorkoutHeartRateResponse, CancelProposedSetRequest, CancelProposedSetResponse,
    CompleteSetRequest, CompleteSetResponse, CompletedSet, DeleteCompletedSetRequest,
    DeleteCompletedSetResponse, EndWorkoutRequest, EndWorkoutResponse, ExerciseGroup,
    ExerciseTypeConfig, GetActiveWorkoutRequest, GetActiveWorkoutResponse,
    GetProposedWorkoutScheduleRequest, GetProposedWorkoutScheduleResponse,
    GetWorkoutHeartRateRequest, GetWorkoutHeartRateResponse, GetWorkoutRequest, GetWorkoutResponse,
    ListWorkoutsRequest, ListWorkoutsResponse, PlannedGroupSet, ProposedSet,
    ReorderExerciseGroupsRequest, ReorderExerciseGroupsResponse, ReplaceExerciseGroupPlanRequest,
    ReplaceExerciseGroupPlanResponse, RestConfig, StartSetRequest, StartSetResponse,
    StartWorkoutRequest, StartWorkoutResponse, WorkingSetSpec, Workout, WorkoutPlanChangeStats,
    WorkoutStateSnapshot,
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

const END_OF_EXERCISE_GROUP_REST_SECONDS: i64 = 10;

fn round_to_2_5(weight: f32) -> f32 {
    (weight / 2.5).round() * 2.5
}

fn round_to_5(weight: f32) -> f32 {
    (weight / 5.0).round() * 5.0
}

fn is_25_45_plate_combo(total_weight: f32) -> bool {
    if total_weight < 45.0 {
        return false;
    }
    let rem = (total_weight - 45.0).round() as i32;
    if rem < 0 || rem % 10 != 0 {
        return false;
    }
    // total = 45 + 50*a + 90*b
    for b in 0..=(rem / 90) {
        let rest = rem - (90 * b);
        if rest >= 0 && rest % 50 == 0 {
            return true;
        }
    }
    false
}

fn snap_warmup_weight(weight: f32, max_warmup_weight: f32) -> f32 {
    if max_warmup_weight < 45.0 {
        return round_to_2_5(weight).clamp(2.5, max_warmup_weight);
    }

    let candidate = round_to_5(weight).clamp(45.0, max_warmup_weight);
    if is_25_45_plate_combo(candidate) {
        return candidate;
    }

    // Prefer a nearby 45/25-plate-only load if it's within 5 lb.
    let mut best = candidate;
    let mut best_diff = f32::INFINITY;
    let mut probe = 45.0;
    while probe <= max_warmup_weight {
        if is_25_45_plate_combo(probe) {
            let diff = (probe - candidate).abs();
            if diff <= 5.0 && (diff < best_diff || (diff == best_diff && probe < best)) {
                best = probe;
                best_diff = diff;
            }
        }
        probe += 5.0;
    }
    best
}

fn generate_warmup_defs(working_weight: f32) -> Vec<(f32, i32)> {
    // Always produce 4 warmup sets (5/5/3/2) and allow sub-45 weights.
    // Use percentages of the working weight, rounded to 2.5-lb increments.
    let reps = [5, 5, 3, 2];
    let pcts = [0.40_f32, 0.55_f32, 0.70_f32, 0.85_f32];
    let max_warmup_weight = (working_weight - 2.5).max(2.5);

    let mut out = Vec::with_capacity(4);
    let mut prev = 0.0_f32;
    for (idx, pct) in pcts.iter().enumerate() {
        let desired = snap_warmup_weight(working_weight * pct, max_warmup_weight);
        let mut chosen = if idx == 0 && max_warmup_weight >= 45.0 {
            45.0
        } else {
            desired.clamp(2.5, max_warmup_weight)
        };
        if chosen < prev {
            chosen = prev;
        }
        prev = chosen;
        out.push((chosen, reps[idx]));
    }

    out
}

/// Unified set generation from ExerciseGroup with ExerciseTypeConfigs.
/// Generates warmup sets and working sets based on group configuration.
pub(crate) fn generate_sets_for_group(
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
    let working_set_defs: Vec<Vec<WorkingSetSpec>> = configs
        .iter()
        .map(|c| materialized_working_sets_for_config(group, c))
        .collect();

    let warmup_defs: Vec<Vec<(f32, i32)>> = configs
        .iter()
        .enumerate()
        .map(|(idx, c)| {
            let warmup_weight = working_set_defs
                .get(idx)
                .and_then(|ws| ws.first())
                .map(|ws| ws.target_weight)
                .unwrap_or(c.start_weight);
            if c.include_warmup {
                generate_warmup_defs(warmup_weight)
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

    // Working sets interleave by round: A1, B1, A2, B2, ... . Configs may have different counts.
    let num_sets = working_set_defs
        .iter()
        .map(|defs| defs.len())
        .max()
        .unwrap_or_else(|| group.sets.max(1) as usize);
    for set_idx in 0..num_sets {
        for (cfg_idx, config) in configs.iter().enumerate() {
            let Some(ws) = working_set_defs[cfg_idx].get(set_idx) else {
                continue;
            };
            let (rest_s, rest_f) = get_rest_for_config(group, config, false, false);
            sets.push(ProposedSet {
                id: Uuid::new_v4().to_string(),
                workout_id: workout_id.to_string(),
                workout_order: order,
                exercise: config.exercise,
                target_reps: ws.target_reps,
                target_weight: ws.target_weight,
                warmup: false,
                exercise_group_id: group.id.clone(),
                rest_after_success: rest_s,
                rest_after_failure: rest_f,
                cancelled: false,
                is_amrap: ws.is_amrap,
                instruction: ws.instruction.clone(),
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

#[cfg(test)]
fn is_default_rest_config(rc: &RestConfig) -> bool {
    rc.rest_after_success == 180
        && rc.rest_after_failure == 300
        && (rc.rest_after_warmup == 10 || rc.rest_after_warmup == 0)
}

#[cfg(test)]
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

fn materialized_working_sets_for_config(
    group: &ExerciseGroup,
    config: &ExerciseTypeConfig,
) -> Vec<WorkingSetSpec> {
    if !config.working_sets.is_empty() {
        return config.working_sets.clone();
    }

    let num_sets = group.sets.max(1) as usize;
    let mut sets = Vec::with_capacity(num_sets);
    for set_idx in 0..num_sets {
        let is_last_working_set = set_idx + 1 == num_sets;
        let weight = if num_sets <= 1 {
            config.start_weight
        } else {
            config.start_weight
                + (set_idx as f32 / (num_sets - 1) as f32)
                    * (config.end_weight - config.start_weight)
        };
        let weight = (weight / 5.0).round() * 5.0;
        let is_amrap = config.last_set_amrap && is_last_working_set;
        let instruction = if is_amrap {
            "AMRAP — push for max reps".to_string()
        } else {
            String::new()
        };
        sets.push(WorkingSetSpec {
            target_weight: weight,
            target_reps: config.reps,
            is_amrap,
            instruction,
        });
    }
    sets
}

pub(crate) fn materialize_group_working_sets(group: &mut ExerciseGroup) {
    let current = group.clone();
    let mut max_sets = 0usize;
    for config in &mut group.exercise_configs {
        if config.working_sets.is_empty() {
            config.working_sets = materialized_working_sets_for_config(&current, config);
        }
        max_sets = max_sets.max(config.working_sets.len());
    }
    if max_sets > 0 {
        group.sets = max_sets as i32;
    }
}

fn compute_group_working_rounds_from_sets(sets: &[PlannedGroupSet]) -> i32 {
    let mut counts: std::collections::HashMap<i32, i32> = std::collections::HashMap::new();
    for set in sets.iter().filter(|s| !s.warmup) {
        *counts.entry(set.exercise).or_insert(0) += 1;
    }
    counts.values().copied().max().unwrap_or(0).max(1)
}

fn normalize_group_plan_sets(req_sets: &[PlannedGroupSet]) -> Vec<PlannedGroupSet> {
    req_sets
        .iter()
        .map(|s| {
            let mut set = s.clone();
            if set.rest_after_success <= 0 {
                set.rest_after_success = if set.warmup { 10 } else { 180 };
            }
            if set.rest_after_failure <= 0 {
                set.rest_after_failure = if set.warmup {
                    set.rest_after_success
                } else {
                    300
                };
            }
            set
        })
        .collect()
}

fn proposed_sets_from_planned_group_sets(
    workout_id: &str,
    group_id: &str,
    planned_sets: &[PlannedGroupSet],
    start_order: i32,
) -> Vec<ProposedSet> {
    let mut order = start_order;
    let mut out = Vec::with_capacity(planned_sets.len());
    for s in planned_sets {
        out.push(ProposedSet {
            id: Uuid::new_v4().to_string(),
            workout_id: workout_id.to_string(),
            workout_order: order,
            exercise: s.exercise,
            target_reps: s.target_reps,
            target_weight: s.target_weight,
            warmup: s.warmup,
            exercise_group_id: group_id.to_string(),
            rest_after_success: if s.rest_after_success > 0 {
                s.rest_after_success
            } else if s.warmup {
                10
            } else {
                180
            },
            rest_after_failure: if s.rest_after_failure > 0 {
                s.rest_after_failure
            } else if s.warmup {
                if s.rest_after_success > 0 {
                    s.rest_after_success
                } else {
                    10
                }
            } else {
                300
            },
            cancelled: false,
            is_amrap: s.is_amrap,
            instruction: s.instruction.clone(),
        });
        order += 1;
    }
    out
}

fn active_group_sets(workout_ref: &ActiveWorkout, group_id: &str) -> Vec<ProposedSet> {
    let mut sets: Vec<ProposedSet> = workout_ref
        .proposed_sets
        .iter()
        .filter(|p| p.exercise_group_id == group_id && !p.cancelled)
        .cloned()
        .collect();
    sets.sort_by_key(|s| s.workout_order);
    sets
}

fn apply_replace_exercise_group_plan(
    workout_ref: &mut ActiveWorkout,
    req: &ReplaceExerciseGroupPlanRequest,
) -> Result<(Option<ExerciseGroup>, Vec<ProposedSet>), Status> {
    if workout_ref.workout.id != req.workout_id {
        return Err(Status::failed_precondition("Workout ID mismatch"));
    }

    let normalized_sets = normalize_group_plan_sets(&req.sets);
    let completed_ids: std::collections::HashSet<String> = workout_ref
        .completed_sets
        .iter()
        .filter(|c| !c.proposed_set_id.is_empty())
        .map(|c| c.proposed_set_id.clone())
        .collect();

    // Create
    if req.exercise_group_id.is_empty() {
        if req.delete_group_if_empty && normalized_sets.is_empty() {
            return Ok((None, vec![]));
        }

        let group_id = Uuid::new_v4().to_string();
        let workout_order = workout_ref.exercise_groups.len() as i32;
        let group = ExerciseGroup {
            id: group_id.clone(),
            workout_id: req.workout_id.clone(),
            name: req.name.clone(),
            sets: compute_group_working_rounds_from_sets(&normalized_sets),
            interleave_warmups: req.interleave_warmups,
            workout_order,
            exercise_configs: vec![],
            rest_config: normalize_rest_config(req.rest_config.clone()),
            instruction: req.instruction.clone(),
            prescribed_by_regime: false,
        };
        let set_order = workout_ref
            .proposed_sets
            .last()
            .map(|s| s.workout_order + 1)
            .unwrap_or(0);
        let generated_sets = proposed_sets_from_planned_group_sets(
            &req.workout_id,
            &group_id,
            &normalized_sets,
            set_order,
        );
        workout_ref.exercise_groups.push(group.clone());
        workout_ref.proposed_sets.extend(generated_sets.clone());
        workout_ref.reindex_sets();
        return Ok((Some(group), active_group_sets(workout_ref, &group_id)));
    }

    // Update/Delete existing
    let existing_idx = workout_ref
        .exercise_groups
        .iter()
        .position(|g| g.id == req.exercise_group_id)
        .ok_or_else(|| Status::not_found("Exercise group not found"))?;

    if workout_ref.exercise_groups[existing_idx].prescribed_by_regime {
        return Err(Status::failed_precondition(
            "Regime-prescribed exercise groups cannot be modified",
        ));
    }

    if req.delete_group_if_empty && normalized_sets.is_empty() {
        let group_id = req.exercise_group_id.clone();
        workout_ref
            .proposed_sets
            .retain(|p| p.exercise_group_id != group_id || completed_ids.contains(&p.id));
        workout_ref.exercise_groups.retain(|g| g.id != group_id);
        workout_ref.reindex_sets();
        return Ok((None, vec![]));
    }

    {
        let group = &mut workout_ref.exercise_groups[existing_idx];
        if !req.name.is_empty() {
            group.name = req.name.clone();
        }
        group.interleave_warmups = req.interleave_warmups;
        group.sets = compute_group_working_rounds_from_sets(&normalized_sets);
        group.exercise_configs.clear();
        group.rest_config = normalize_rest_config(req.rest_config.clone());
        group.instruction = req.instruction.clone();
    }

    // Preserve completed-associated proposed sets, cancel remaining pending
    let mut completed_group_sets: Vec<ProposedSet> = workout_ref
        .proposed_sets
        .iter()
        .filter(|p| p.exercise_group_id == req.exercise_group_id && completed_ids.contains(&p.id))
        .cloned()
        .collect();
    completed_group_sets.sort_by_key(|s| s.workout_order);

    for set in workout_ref
        .proposed_sets
        .iter_mut()
        .filter(|p| p.exercise_group_id == req.exercise_group_id)
    {
        if !completed_ids.contains(&set.id) {
            set.cancelled = true;
        }
    }

    // Consume completed slots by (exercise, warmup) count, then append remaining pending in request order.
    let mut completed_slots_by_key: std::collections::HashMap<(i32, bool), usize> =
        std::collections::HashMap::new();
    for set in &completed_group_sets {
        *completed_slots_by_key
            .entry((set.exercise, set.warmup))
            .or_insert(0) += 1;
    }

    let pending_planned: Vec<PlannedGroupSet> = normalized_sets
        .into_iter()
        .filter(|set| {
            if let Some(remaining) = completed_slots_by_key.get_mut(&(set.exercise, set.warmup)) {
                if *remaining > 0 {
                    *remaining -= 1;
                    return false;
                }
            }
            true
        })
        .collect();

    let appended = proposed_sets_from_planned_group_sets(
        &req.workout_id,
        &req.exercise_group_id,
        &pending_planned,
        0,
    );
    workout_ref.proposed_sets.extend(appended);
    workout_ref.reindex_sets();

    let group = workout_ref.exercise_groups[existing_idx].clone();
    let visible_sets = active_group_sets(workout_ref, &group.id);
    Ok((Some(group), visible_sets))
}

#[cfg(test)]
fn apply_update_exercise_group(
    workout_ref: &mut ActiveWorkout,
    req: &UpdateExerciseGroupRequest,
) -> Result<(ExerciseGroup, Vec<ProposedSet>), Status> {
    let group = workout_ref
        .exercise_groups
        .iter_mut()
        .find(|g| g.id == req.exercise_group_id)
        .ok_or_else(|| Status::not_found("Exercise group not found"))?;

    if group.prescribed_by_regime {
        return Err(Status::failed_precondition(
            "Regime-prescribed exercise groups cannot be modified",
        ));
    }

    if !req.name.is_empty() {
        group.name = req.name.clone();
    }
    group.sets = req.sets;
    group.interleave_warmups = req.interleave_warmups;
    group.exercise_configs = normalize_exercise_configs(&req.exercise_configs);
    group.rest_config = normalize_rest_config(req.rest_config.clone());
    materialize_group_working_sets(group);
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
        let start_time = if req.started_at > 0 {
            req.started_at
        } else {
            now_unix()
        };

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
            materialize_group_working_sets(g);
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

    async fn replace_exercise_group_plan(
        &self,
        request: Request<ReplaceExerciseGroupPlanRequest>,
    ) -> Result<Response<ReplaceExerciseGroupPlanResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        let (group, group_sets, full_workout_state, next_up_set, state_snapshot) = {
            let mut workout_ref = self
                .state
                .workouts
                .get_mut(&user_id)
                .ok_or_else(|| Status::failed_precondition("No active workout"))?;

            let (group, group_sets) = apply_replace_exercise_group_plan(&mut workout_ref, &req)?;

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

            (group, group_sets, full_state, next_up_set, state_snapshot)
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

        Ok(Response::new(ReplaceExerciseGroupPlanResponse {
            group,
            generated_sets: group_sets,
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
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

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
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

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
            let started_at = if req.started_at > 0 {
                req.started_at
            } else {
                now_unix()
            };

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
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

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
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

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
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

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
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

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

    async fn get_workout_heart_rate(
        &self,
        request: Request<GetWorkoutHeartRateRequest>,
    ) -> Result<Response<GetWorkoutHeartRateResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        if req.workout_id.is_empty() {
            return Err(Status::invalid_argument("workout_id is required"));
        }

        let is_active_owned = self
            .state
            .workouts
            .get(&user_id)
            .map(|w| w.workout.id == req.workout_id)
            .unwrap_or(false);

        if !is_active_owned {
            let exists = self
                .central_db
                .get_workout(&user_id, &req.workout_id)
                .await
                .map_err(|e| Status::internal(format!("Failed to get workout: {}", e)))?
                .is_some();
            if !exists {
                return Err(Status::not_found("Workout not found"));
            }
        }

        let samples = self
            .central_db
            .get_workout_heart_rate_samples(&user_id, &req.workout_id)
            .await
            .map_err(|e| Status::internal(format!("Failed to get heart rate samples: {}", e)))?;

        Ok(Response::new(GetWorkoutHeartRateResponse { samples }))
    }

    async fn end_workout(
        &self,
        request: Request<EndWorkoutRequest>,
    ) -> Result<Response<EndWorkoutResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

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

            let end_time = if req.ended_at > 0 {
                req.ended_at
            } else {
                now_unix()
            };
            active.workout.end_time = end_time;
            active
        }; // Guard dropped here

        // Incremental write: update end time
        self.central_db
            .update_workout_end_time(&user_id, &active.workout.id, active.workout.end_time)
            .await
            .map_err(|e| Status::internal(format!("Failed to end workout: {}", e)))?;

        // ── State transition: compute + persist new program state ─────────────
        if let Ok(Some(state_record)) = self.central_db.get_latest_program_state(&user_id).await {
            let regime_type = lift::workout::v1::RegimeType::try_from(state_record.regime_type)
                .unwrap_or(lift::workout::v1::RegimeType::Linear5x5);
            let regime = get_regime(regime_type);
            let current_state = parse_state_payload(&state_record.state_payload_json);

            // Load proposed + completed sets to build WorkoutCompletionResult
            let proposed_sets = self
                .central_db
                .get_proposed_sets(&user_id, &active.workout.id)
                .await
                .unwrap_or_default();
            let completed_sets = self
                .central_db
                .get_completed_sets(&user_id, &active.workout.id)
                .await
                .unwrap_or_default();

            let mut set_results = Vec::new();
            for cs in &completed_sets {
                if let Some(ps) = proposed_sets.iter().find(|p| p.id == cs.proposed_set_id) {
                    if !ps.warmup && !ps.cancelled {
                        if let Ok(ex) = lift::workout::v1::Exercise::try_from(ps.exercise) {
                            set_results.push(WorkingSetResult {
                                exercise: ex,
                                target_reps: ps.target_reps,
                                actual_reps: cs.actual_reps,
                            });
                        }
                    }
                }
            }

            let completion_result = WorkoutCompletionResult { set_results };

            let new_state = regime.transition_state_on_workout_complete(
                &current_state,
                &completion_result,
                active.workout.end_time,
            );

            let event = ProgramStateEventRecord {
                event_id: uuid::Uuid::new_v4().to_string(),
                user_id: user_id.clone(),
                regime_type: regime_type as i32,
                effective_at: active.workout.end_time,
                recorded_at: active.workout.end_time,
                source: "workout_completed".to_string(),
                state_payload_json: serialize_state_payload(&new_state),
                source_workout_id: Some(active.workout.id.clone()),
            };

            // Best-effort: don't fail end_workout if state append fails
            let _ = self.central_db.append_program_state_event(event).await;
        }

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
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        // 1. Get active workout ID while holding lock
        let active_workout_id = self
            .state
            .workouts
            .get(&user_id)
            .map(|w| w.workout.id.clone());

        // 2. Perform DB IO outside the lock
        let scheduler = Scheduler::new(self.central_db.clone());
        let at_time = request.into_inner().at_time;
        let mut response = scheduler
            .get_proposed_schedule(&user_id, at_time)
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
#[path = "service_workout_tests.rs"]
mod tests;
