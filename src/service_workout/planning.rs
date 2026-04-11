use super::*;

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
                        progression_hint: None,
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
                    progression_hint: None,
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
                progression_hint: ws.progression_hint.clone(),
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
            progression_hint: None,
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
    let mut seen_ids = std::collections::HashSet::new();
    for s in planned_sets {
        let id = if s.client_set_id.is_empty() || !seen_ids.insert(s.client_set_id.clone()) {
            Uuid::new_v4().to_string()
        } else {
            s.client_set_id.clone()
        };
        out.push(ProposedSet {
            id,
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
            progression_hint: s.progression_hint.clone(),
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

pub(super) fn apply_replace_exercise_group_plan(
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
    let existing_idx = match workout_ref
        .exercise_groups
        .iter()
        .position(|g| g.id == req.exercise_group_id)
    {
        Some(idx) => idx,
        None if req.create_if_missing => {
            let group = ExerciseGroup {
                id: req.exercise_group_id.clone(),
                workout_id: req.workout_id.clone(),
                name: req.name.clone(),
                sets: compute_group_working_rounds_from_sets(&normalized_sets),
                interleave_warmups: req.interleave_warmups,
                workout_order: workout_ref.exercise_groups.len() as i32,
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
                &req.exercise_group_id,
                &normalized_sets,
                set_order,
            );
            workout_ref.exercise_groups.push(group.clone());
            workout_ref.proposed_sets.extend(generated_sets.clone());
            workout_ref.reindex_sets();
            return Ok((
                Some(group),
                active_group_sets(workout_ref, &req.exercise_group_id),
            ));
        }
        None => return Err(Status::not_found("Exercise group not found")),
    };

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

pub(super) fn apply_reorder_exercise_groups(
    workout_ref: &mut ActiveWorkout,
    req: &ReorderExerciseGroupsRequest,
) -> Result<(), Status> {
    if workout_ref.workout.id != req.workout_id {
        return Err(Status::failed_precondition("Workout ID mismatch"));
    }
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
    Ok(())
}

#[cfg(test)]
pub(super) fn apply_update_exercise_group(
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
