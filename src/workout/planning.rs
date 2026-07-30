use super::*;
use schlift::workout::v1::ProposedExerciseGroup;
use crate::weight_units::{
    bar_weight, kg_to_pounds, plates, pounds_to_kg, simplest_loadable_near,
    AppWeightUnit,
};

const DEFAULT_SUCCESS_REST_SECONDS: i32 = 180;
const DEFAULT_FAILURE_REST_SECONDS: i32 = 300;
const DEFAULT_WARMUP_REST_SECONDS: i32 = 30;

/// Stored weights are pounds; warmup snapping happens in the caller's display
/// unit so the numbers are actually loadable there. These convert at the edges.
fn to_display(weight_lb: f32, unit: AppWeightUnit) -> f32 {
    match unit {
        AppWeightUnit::Lb => weight_lb,
        AppWeightUnit::Kg => pounds_to_kg(weight_lb),
    }
}
fn to_pounds(display: f32, unit: AppWeightUnit) -> f32 {
    match unit {
        AppWeightUnit::Lb => display,
        AppWeightUnit::Kg => kg_to_pounds(display),
    }
}

/// Rough time estimate for one proposed group, so the home screen can show a
/// predicted workout length without doing the maths itself. A heuristic, but the
/// single source of it. Mirrors what the app used to compute in
/// `_estimatedWorkoutMinutes`.
pub(crate) fn estimate_group_duration_seconds(group: &ProposedExerciseGroup) -> i64 {
    const TRANSITION: i64 = 90;
    const SETUP: i64 = 75;
    const WORKING_SET: i64 = 45;
    const WARMUP_SET: i64 = 30;
    const DEFAULT_WORKING_REST: i64 = 180;
    const DEFAULT_WARMUP_REST: i64 = 30;

    let mut total = TRANSITION;
    for cfg in &group.exercise_configs {
        total += SETUP;
        let working_sets = if !cfg.working_sets.is_empty() {
            cfg.working_sets.len() as i64
        } else if group.sets <= 0 {
            1
        } else {
            group.sets as i64
        };
        let warmup_sets: i64 = if cfg.include_warmup { 2 } else { 0 };
        let rest = cfg.rest_config.as_ref().or(group.rest_config.as_ref());
        let working_rest = rest
            .map(|r| r.rest_after_success as i64)
            .unwrap_or(DEFAULT_WORKING_REST);
        let warmup_rest = rest
            .map(|r| r.rest_after_warmup as i64)
            .unwrap_or(DEFAULT_WARMUP_REST);
        total += working_sets * WORKING_SET;
        total += warmup_sets * WARMUP_SET;
        total += (working_sets - 1).max(0) * working_rest;
        total += warmup_sets * warmup_rest;
    }
    total
}

/// Four warmups (5/5/3/2) climbing to the working weight, each expressed as the
/// simplest plate step-up in `unit` — empty bar first, then loads that prefer
/// one big plate over several small ones. Computed in the display unit and
/// returned in pounds (storage). The single source of warmup generation — the
/// app renders these, it no longer computes them.
fn generate_warmup_defs(working_weight_lb: f32, unit: AppWeightUnit) -> Vec<(f32, i32)> {
    let reps = [5, 5, 3, 2];
    let pcts = [0.40_f32, 0.55_f32, 0.70_f32, 0.85_f32];
    let bar = bar_weight(unit);
    let pl = plates(unit);
    let smallest = pl.last().copied().unwrap_or(2.5);

    let working = to_display(working_weight_lb, unit);
    // Warmups must sit below the working weight by at least one small plate.
    let max = (working - smallest).max(smallest);

    let mut out = Vec::with_capacity(4);
    let mut prev = 0.0_f32; // in display units
    for (idx, pct) in pcts.iter().enumerate() {
        let target = working * pct;
        let mut chosen = if idx == 0 && max >= bar {
            bar // start with the empty bar
        } else {
            simplest_loadable_near(target, bar, pl, smallest, max)
        };
        if chosen < prev {
            chosen = prev;
        }
        prev = chosen;
        out.push((to_pounds(chosen, unit), reps[idx]));
    }

    out
}

/// Unified set generation from ExerciseGroup with ExerciseTypeConfigs.
/// Generates warmup sets and working sets based on group configuration.
pub(crate) fn generate_sets_for_group(
    workout_id: &str,
    group: &ExerciseGroup,
    start_order: i32,
    unit: AppWeightUnit,
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
                generate_warmup_defs(warmup_weight, unit)
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
        .unwrap_or(DEFAULT_SUCCESS_REST_SECONDS);

    let failure_rest = rc
        .and_then(|c| {
            if c.rest_after_failure > 0 {
                Some(c.rest_after_failure)
            } else {
                None
            }
        })
        .unwrap_or(DEFAULT_FAILURE_REST_SECONDS);

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
                .unwrap_or(DEFAULT_WARMUP_REST_SECONDS);
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

fn compute_group_working_rounds_from_sets(sets: &[PlannedGroupSet]) -> i32 {
    let mut counts: std::collections::HashMap<i32, i32> = std::collections::HashMap::new();
    for set in sets.iter().filter(|s| !s.warmup) {
        *counts.entry(set.exercise).or_insert(0) += 1;
    }
    counts.values().copied().max().unwrap_or(0).max(1)
}

fn validated_group_plan_sets(
    req_sets: &[PlannedGroupSet],
) -> Result<Vec<PlannedGroupSet>, WorkoutError> {
    for set in req_sets {
        if set.rest_after_success <= 0 || set.rest_after_failure <= 0 {
            return Err(WorkoutError::failed_precondition(
                "Workout plan sets must include explicit rest values",
            ));
        }
    }
    Ok(req_sets.to_vec())
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
            rest_after_success: s.rest_after_success,
            rest_after_failure: s.rest_after_failure,
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

/// Rebuild a group's full planned set list — warmups regenerated for the new
/// working weights — from the working sets the client sent. The app is a thin
/// client and no longer generates warmups, so an edit round-trip arrives as
/// working sets only. Exercises in `warmup_exercises` (those that had warmups
/// before the edit) get a fresh warmup ladder off their top working weight, via
/// the same `generate_sets_for_group` the initial plan uses — so there's no
/// second warmup implementation to keep in sync. The caller reconciles this
/// against completed sets: N completed warmups consume the first N of the new
/// ladder, leaving the top (4−N) as the recalculated pending warmups.
fn rematerialize_group_plan_with_warmups(
    workout_id: &str,
    group_id: &str,
    working_sets: &[PlannedGroupSet],
    warmup_exercises: &std::collections::HashSet<i32>,
    interleave_warmups: bool,
    rest_config: Option<RestConfig>,
    unit: AppWeightUnit,
) -> Vec<PlannedGroupSet> {
    // Group the working sets by exercise, preserving first-appearance order.
    let mut exercise_order: Vec<i32> = Vec::new();
    let mut by_exercise: std::collections::HashMap<i32, Vec<&PlannedGroupSet>> =
        std::collections::HashMap::new();
    for set in working_sets.iter().filter(|s| !s.warmup) {
        by_exercise
            .entry(set.exercise)
            .or_insert_with(|| {
                exercise_order.push(set.exercise);
                Vec::new()
            })
            .push(set);
    }
    if exercise_order.is_empty() {
        // No working sets (e.g. a warmup-only or empty plan) — nothing to rebuild.
        return working_sets.to_vec();
    }

    let configs: Vec<ExerciseTypeConfig> = exercise_order
        .iter()
        .map(|exercise| {
            let working = &by_exercise[exercise];
            let working_specs: Vec<WorkingSetSpec> = working
                .iter()
                .map(|s| WorkingSetSpec {
                    target_weight: s.target_weight,
                    target_reps: s.target_reps,
                    is_amrap: s.is_amrap,
                    instruction: s.instruction.clone(),
                    progression_hint: s.progression_hint.clone(),
                })
                .collect();
            ExerciseTypeConfig {
                exercise: *exercise,
                start_weight: working_specs.first().map(|w| w.target_weight).unwrap_or(0.0),
                end_weight: working_specs.last().map(|w| w.target_weight).unwrap_or(0.0),
                reps: working_specs.first().map(|w| w.target_reps).unwrap_or(0),
                include_warmup: warmup_exercises.contains(exercise),
                rest_config: None,
                last_set_amrap: working_specs.last().map(|w| w.is_amrap).unwrap_or(false),
                working_sets: working_specs,
            }
        })
        .collect();

    let group = ExerciseGroup {
        id: group_id.to_string(),
        workout_id: workout_id.to_string(),
        name: String::new(),
        sets: compute_group_working_rounds_from_sets(working_sets),
        interleave_warmups,
        workout_order: 0,
        exercise_configs: configs,
        rest_config,
        instruction: String::new(),
        prescribed_by_regime: false,
        materialized_sets: Vec::new(),
    };

    generate_sets_for_group(workout_id, &group, 0, unit)
        .into_iter()
        .map(|p| PlannedGroupSet {
            exercise: p.exercise,
            target_reps: p.target_reps,
            target_weight: p.target_weight,
            warmup: p.warmup,
            rest_after_success: p.rest_after_success,
            rest_after_failure: p.rest_after_failure,
            is_amrap: p.is_amrap,
            instruction: p.instruction,
            progression_hint: p.progression_hint,
            client_set_id: p.id,
        })
        .collect()
}

pub(crate) fn apply_replace_exercise_group_plan(
    workout_ref: &mut ActiveWorkout,
    req: &ReplaceExerciseGroupPlanRequest,
    unit: AppWeightUnit,
) -> Result<(Option<ExerciseGroup>, Vec<ProposedSet>), WorkoutError> {
    if workout_ref.workout.id != req.workout_id {
        return Err(WorkoutError::failed_precondition("Workout ID mismatch"));
    }

    let normalized_sets = validated_group_plan_sets(&req.sets)?;
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
            rest_config: normalize_rest_config(req.rest_config),
            instruction: req.instruction.clone(),
            prescribed_by_regime: false,
            materialized_sets: Vec::new(),
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
                rest_config: normalize_rest_config(req.rest_config),
                instruction: req.instruction.clone(),
                prescribed_by_regime: false,
            materialized_sets: Vec::new(),
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
        None => return Err(WorkoutError::not_found("Exercise group not found")),
    };

    if workout_ref.exercise_groups[existing_idx].prescribed_by_regime {
        return Err(WorkoutError::failed_precondition(
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
        group.rest_config = normalize_rest_config(req.rest_config);
        group.instruction = req.instruction.clone();
    }

    // Preserve completed-associated proposed sets.
    let mut completed_group_sets: Vec<ProposedSet> = workout_ref
        .proposed_sets
        .iter()
        .filter(|p| p.exercise_group_id == req.exercise_group_id && completed_ids.contains(&p.id))
        .cloned()
        .collect();
    completed_group_sets.sort_by_key(|s| s.workout_order);

    // Regenerate warmups server-side for the new working weights — the thin client
    // sends working sets only. Only for exercises that already had warmups, so we
    // don't invent them where the group never wanted them.
    let warmup_exercises: std::collections::HashSet<i32> = workout_ref
        .proposed_sets
        .iter()
        .filter(|p| p.exercise_group_id == req.exercise_group_id && p.warmup)
        .map(|p| p.exercise)
        .collect();
    // Heaviest warmup already completed per exercise. A recalculated warmup at or
    // below this is one you've effectively already done (a big *downward* edit), so
    // it's dropped rather than handed back to you.
    let mut max_done_warmup: std::collections::HashMap<i32, f32> =
        std::collections::HashMap::new();
    for set in completed_group_sets.iter().filter(|s| s.warmup) {
        let entry = max_done_warmup.entry(set.exercise).or_insert(f32::MIN);
        if set.target_weight > *entry {
            *entry = set.target_weight;
        }
    }
    let normalized_sets = rematerialize_group_plan_with_warmups(
        &req.workout_id,
        &req.exercise_group_id,
        &normalized_sets,
        &warmup_exercises,
        req.interleave_warmups,
        normalize_rest_config(req.rest_config),
        unit,
    );

    // The edit replaces the pending plan: cancel every pending set (warmups and
    // working); completed sets are kept and consume matching slots below.
    for set in workout_ref
        .proposed_sets
        .iter_mut()
        .filter(|p| p.exercise_group_id == req.exercise_group_id)
    {
        if !completed_ids.contains(&set.id) {
            set.cancelled = true;
        }
    }

    // Reconcile by (exercise, warmup) count: N completed warmups consume the first
    // (lightest) N of the regenerated ladder, leaving the top (4−N) as the
    // recalculated pending warmups. Same for working sets.
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
            // Downward-edit guard: never hand back a warmup you've already surpassed.
            if set.warmup {
                if let Some(done) = max_done_warmup.get(&set.exercise) {
                    if set.target_weight <= *done + 1e-3 {
                        return false;
                    }
                }
            }
            true
        })
        .collect();

    // Place the regenerated pending sets *after* every existing set's order. Otherwise they
    // collide with the kept completed sets' workout_order and reindex_sets() interleaves them
    // (completed/new/completed/new...), which scrambles the visible order and progression.
    // A higher start order keeps completed sets first, then the new pending sets, within the
    // group — matching what the client does locally.
    let start_order = workout_ref
        .proposed_sets
        .iter()
        .map(|s| s.workout_order)
        .max()
        .map(|m| m + 1)
        .unwrap_or(0);
    let appended = proposed_sets_from_planned_group_sets(
        &req.workout_id,
        &req.exercise_group_id,
        &pending_planned,
        start_order,
    );
    workout_ref.proposed_sets.extend(appended);
    workout_ref.reindex_sets();

    let group = workout_ref.exercise_groups[existing_idx].clone();
    let visible_sets = active_group_sets(workout_ref, &group.id);
    Ok((Some(group), visible_sets))
}

pub(crate) fn apply_reorder_exercise_groups(
    workout_ref: &mut ActiveWorkout,
    req: &ReorderExerciseGroupsRequest,
) -> Result<(), WorkoutError> {
    if workout_ref.workout.id != req.workout_id {
        return Err(WorkoutError::failed_precondition("Workout ID mismatch"));
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
mod warmup_tests {
    use super::*;

    /// A dense sweep of every 2.5 lb increment from 5 to 600, plus sub-increment
    /// values. Density matters: the Rust/Dart divergence this fixture exists to
    /// catch came from `175.0 * 0.70` landing on opposite sides of a `.5`
    /// rounding boundary in f32 vs f64, and a sparse table would have missed it.
    /// The sweep also covers the branches in `snap_warmup_weight` — sub-bar
    /// loads, the 45 lb bar boundary, exact 25/45-plate combos (45, 95, 135,
    /// 185, 225) and the gaps between them where the ±5 lb probe runs.
    fn golden_working_weights() -> Vec<f32> {
        let mut weights: Vec<f32> = Vec::new();
        let mut w = 5.0_f32;
        while w <= 600.0 {
            weights.push(w);
            w += 2.5;
        }
        // Values off the 2.5 grid, which users can reach via manual entry.
        weights.extend_from_slice(&[7.5, 13.0, 33.3, 46.0, 47.5, 101.0, 123.4, 178.9, 249.9]);
        weights.sort_by(|a, b| a.partial_cmp(b).unwrap());
        weights.dedup();
        weights
    }

    // The Dart warmup mirror + its golden fixture are gone — the server owns
    // warmup generation, so only these properties matter now.

    /// Properties the app relies on regardless of the exact numbers — in BOTH units.
    #[test]
    fn warmup_defs_are_non_decreasing_and_below_the_working_weight() {
        for unit in [AppWeightUnit::Lb, AppWeightUnit::Kg] {
            for w in golden_working_weights() {
                let defs = generate_warmup_defs(w, unit);
                assert_eq!(defs.len(), 4, "expected 4 warmups for {w} ({unit:?})");

                let mut prev = 0.0_f32;
                for (weight_lb, reps) in defs {
                    assert!(weight_lb >= prev, "warmups must not decrease at {w} ({unit:?})");
                    assert!(weight_lb < w + 1e-3, "warmup {weight_lb} must be under {w} ({unit:?})");
                    assert!(reps > 0, "warmup reps must be positive at {w} ({unit:?})");
                    prev = weight_lb;
                }
            }
        }
    }

    /// The whole point: every warmup is a weight you can actually load in the
    /// caller's unit (no junk decimals after the kg conversion).
    #[test]
    fn warmups_are_exactly_loadable_in_their_unit() {
        use crate::weight_units::{bar_weight, plate_count_per_side, plates, pounds_to_kg};
        for unit in [AppWeightUnit::Lb, AppWeightUnit::Kg] {
            let (bar, pl) = (bar_weight(unit), plates(unit));
            for w in golden_working_weights() {
                for (weight_lb, _) in generate_warmup_defs(w, unit) {
                    let display = match unit {
                        AppWeightUnit::Lb => weight_lb,
                        AppWeightUnit::Kg => pounds_to_kg(weight_lb),
                    };
                    // Sub-bar warmups (very light working weights) fall on the
                    // smallest-plate grid rather than a barbell load; skip those.
                    if display < bar {
                        continue;
                    }
                    assert!(
                        plate_count_per_side(display, bar, pl).is_finite(),
                        "warmup {display} ({unit:?}) from working {w} isn't loadable"
                    );
                }
            }
        }
    }
}

#[cfg(test)]
mod replace_plan_tests {
    use super::*;
    use schlift::workout::v1::Workout;

    fn pset(id: &str, order: i32, warmup: bool, weight: f32) -> ProposedSet {
        ProposedSet {
            id: id.to_string(),
            workout_id: "w1".to_string(),
            workout_order: order,
            exercise: 1,
            target_reps: 5,
            target_weight: weight,
            warmup,
            exercise_group_id: "g1".to_string(),
            rest_after_success: 180,
            rest_after_failure: 300,
            cancelled: false,
            is_amrap: false,
            instruction: String::new(),
            progression_hint: None,
        }
    }

    fn planned_working(weight: f32) -> PlannedGroupSet {
        PlannedGroupSet {
            exercise: 1,
            target_reps: 5,
            target_weight: weight,
            warmup: false,
            rest_after_success: 180,
            rest_after_failure: 300,
            is_amrap: false,
            instruction: String::new(),
            progression_hint: None,
            client_set_id: String::new(),
        }
    }

    fn completed(proposed_id: &str) -> CompletedSet {
        CompletedSet {
            id: format!("c_{proposed_id}"),
            workout_id: "w1".to_string(),
            proposed_set_id: proposed_id.to_string(),
            actual_reps: 5,
            actual_weight: 0.0,
            started_at: 100,
            ended_at: 200,
            rest_until: 0,
        }
    }

    // A Squat group: 4 warmups climbing to a 200 working weight, 2 working sets.
    fn squat_workout(completed_sets: Vec<CompletedSet>) -> ActiveWorkout {
        let group = ExerciseGroup {
            id: "g1".to_string(),
            workout_id: "w1".to_string(),
            name: "Squat".to_string(),
            sets: 2,
            interleave_warmups: false,
            workout_order: 0,
            exercise_configs: vec![],
            rest_config: None,
            instruction: String::new(),
            prescribed_by_regime: false,
            materialized_sets: vec![],
        };
        let proposed = vec![
            pset("wu1", 0, true, 45.0),
            pset("wu2", 1, true, 95.0),
            pset("wu3", 2, true, 135.0),
            pset("wu4", 3, true, 165.0),
            pset("wk1", 4, false, 200.0),
            pset("wk2", 5, false, 200.0),
        ];
        ActiveWorkout::new(
            Workout {
                id: "w1".to_string(),
                name: "T".to_string(),
                start_time: 1,
                end_time: 0,
                session_id: String::new(),
            },
            vec![group],
            proposed,
            completed_sets,
        )
    }

    fn edit_to(active: &mut ActiveWorkout, weight: f32) {
        let req = ReplaceExerciseGroupPlanRequest {
            workout_id: "w1".to_string(),
            exercise_group_id: "g1".to_string(),
            name: "Squat".to_string(),
            interleave_warmups: false,
            sets: vec![planned_working(weight), planned_working(weight)],
            rest_config: None,
            delete_group_if_empty: false,
            instruction: String::new(),
            create_if_missing: false,
        };
        apply_replace_exercise_group_plan(active, &req, AppWeightUnit::Lb).unwrap();
    }

    fn active_warmups(active: &ActiveWorkout) -> Vec<f32> {
        let mut w: Vec<f32> = active
            .proposed_sets
            .iter()
            .filter(|p| p.warmup && !p.cancelled)
            .map(|p| p.target_weight)
            .collect();
        w.sort_by(|a, b| a.partial_cmp(b).unwrap());
        w
    }

    /// Nothing warmed up yet: editing the weight recalculates the whole ladder.
    #[test]
    fn editing_a_weight_recalculates_warmups() {
        let mut active = squat_workout(vec![]);
        let before = active_warmups(&active);
        edit_to(&mut active, 300.0);

        let warmups = active_warmups(&active);
        assert_eq!(warmups.len(), 4, "a fresh ladder is 4 warmups");
        assert_ne!(warmups, before, "warmups should follow the new weight");
        assert!(
            warmups.iter().all(|&w| w < 300.0),
            "every warmup stays below the working weight"
        );
        let working: Vec<_> = active
            .proposed_sets
            .iter()
            .filter(|p| !p.warmup && !p.cancelled)
            .collect();
        assert!(
            working.iter().all(|p| (p.target_weight - 300.0).abs() < 1e-3),
            "working sets carry the edited weight"
        );
    }

    /// Two warmups already done: keep them, recalculate the remaining two at the
    /// new weight (count reconciliation — 4 warmups total, not 6).
    #[test]
    fn completed_warmups_are_kept_and_the_rest_recalculated() {
        let mut active = squat_workout(vec![completed("wu1"), completed("wu2")]);
        edit_to(&mut active, 300.0);

        let warmups = active_warmups(&active);
        assert_eq!(warmups.len(), 4, "2 done + 2 recalculated = 4, never doubled");
        // The two you did are untouched.
        assert!(warmups.contains(&45.0) && warmups.contains(&95.0));
        // The two pending ones climbed for the new weight (heavier than what you did).
        let pending: Vec<f32> = warmups.iter().copied().filter(|&w| w > 95.0).collect();
        assert_eq!(pending.len(), 2, "the top two warmups were recalculated");
        assert!(pending.iter().all(|&w| w < 300.0));
    }

    /// Warm up heavy, then drop the weight a lot: don't hand back warmups you've
    /// already surpassed.
    #[test]
    fn a_large_downward_edit_drops_warmups_youve_passed() {
        let mut active =
            squat_workout(vec![completed("wu1"), completed("wu2"), completed("wu3")]);
        edit_to(&mut active, 100.0);

        // The 135 warmup is already done; no recalculated warmup should sit at or
        // below it.
        let pending: Vec<f32> = active
            .proposed_sets
            .iter()
            .filter(|p| p.warmup && !p.cancelled && !p.id.starts_with("wu"))
            .map(|p| p.target_weight)
            .collect();
        assert!(
            pending.iter().all(|&w| w > 135.0),
            "no warmup at/below one already completed: {pending:?}"
        );
    }
}
