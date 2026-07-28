use super::*;
use crate::weight_units::{
    bar_weight, kg_to_pounds, loadable_step, plates, pounds_to_kg, simplest_loadable_near,
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

/// Four warmups (5/5/3/2) climbing to the working weight, each expressed as the
/// simplest plate step-up in `unit` — empty bar first, then loads that prefer
/// one big plate over several small ones. Computed in the display unit and
/// returned in pounds (storage). Mirrored by app/lib/logic/warmup.dart; parity
/// is pinned by the shared golden fixture.
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

pub(crate) fn apply_replace_exercise_group_plan(
    workout_ref: &mut ActiveWorkout,
    req: &ReplaceExerciseGroupPlanRequest,
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

    fn golden_path() -> std::path::PathBuf {
        std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("testdata/warmup_golden.json")
    }

    fn current_table() -> serde_json::Value {
        // Every working weight is generated in BOTH units, so drift in either the
        // lb or kg warmup path fails the build on both sides.
        let mut cases = Vec::new();
        for (unit, label) in [(AppWeightUnit::Lb, "lb"), (AppWeightUnit::Kg, "kg")] {
            for &w in golden_working_weights().iter() {
                let warmups = generate_warmup_defs(w, unit)
                    .into_iter()
                    .map(|(weight, reps)| serde_json::json!({ "weight": weight, "reps": reps }))
                    .collect::<Vec<_>>();
                cases.push(
                    serde_json::json!({ "working_weight": w, "unit": label, "warmups": warmups }),
                );
            }
        }
        serde_json::json!({
            "comment": "Shared golden fixture. src/workout/planning.rs and \
                        app/lib/logic/warmup.dart are independent ports of the same \
                        warmup + plate-snapping maths and must agree exactly. \
                        Regenerate with LIFT_SNAPSHOT_WARMUP=1 cargo test warmup_golden, \
                        then run `cd app && flutter test` to confirm Dart still matches.",
            "cases": cases,
        })
    }

    /// Pins the Rust warmup output. The same file is asserted against by
    /// `app/test/logic/warmup_golden_test.dart`, so a change to either
    /// implementation that is not mirrored in the other fails the build.
    #[test]
    fn warmup_golden_matches_fixture() {
        let current = current_table();

        if std::env::var("LIFT_SNAPSHOT_WARMUP").ok().as_deref() == Some("1") {
            std::fs::create_dir_all(golden_path().parent().unwrap()).unwrap();
            std::fs::write(
                golden_path(),
                format!("{}\n", serde_json::to_string_pretty(&current).unwrap()),
            )
            .unwrap();
            return;
        }

        let raw = std::fs::read_to_string(golden_path()).expect(
            "testdata/warmup_golden.json missing — regenerate with \
             LIFT_SNAPSHOT_WARMUP=1 cargo test warmup_golden",
        );
        let expected: serde_json::Value = serde_json::from_str(&raw).unwrap();

        // Compare numerically rather than by `Value` equality: the fixture is
        // written from f32 and read back as f64, so `Number` equality is not a
        // reliable comparison. Reporting per-case also keeps failures readable —
        // asserting on the whole array dumps hundreds of cases.
        let expected_cases = expected["cases"].as_array().expect("cases array");
        let current_cases = current["cases"].as_array().expect("cases array");

        let mut mismatches: Vec<String> = Vec::new();

        if expected_cases.len() != current_cases.len() {
            mismatches.push(format!(
                "case count: fixture has {}, code produced {}",
                expected_cases.len(),
                current_cases.len()
            ));
        }

        for (exp, cur) in expected_cases.iter().zip(current_cases.iter()) {
            let working = cur["working_weight"].as_f64().unwrap();
            let exp_working = exp["working_weight"].as_f64().unwrap();
            if (working - exp_working).abs() > 1e-6 {
                mismatches.push(format!(
                    "working weight ordering changed: fixture {exp_working}, code {working}"
                ));
                continue;
            }

            let exp_w = exp["warmups"].as_array().unwrap();
            let cur_w = cur["warmups"].as_array().unwrap();
            if exp_w.len() != cur_w.len() {
                mismatches.push(format!(
                    "working={working}: fixture has {} warmups, code produced {}",
                    exp_w.len(),
                    cur_w.len()
                ));
                continue;
            }

            for (idx, (e, c)) in exp_w.iter().zip(cur_w.iter()).enumerate() {
                let (ew, cw) = (e["weight"].as_f64().unwrap(), c["weight"].as_f64().unwrap());
                let (er, cr) = (e["reps"].as_i64().unwrap(), c["reps"].as_i64().unwrap());
                if (ew - cw).abs() > 1e-6 {
                    mismatches.push(format!(
                        "working={working} warmup[{idx}]: fixture weight {ew}, code {cw}"
                    ));
                }
                if er != cr {
                    mismatches.push(format!(
                        "working={working} warmup[{idx}]: fixture {er} reps, code {cr}"
                    ));
                }
            }
        }

        assert!(
            mismatches.is_empty(),
            "Rust warmup output drifted from the golden fixture. If this change is \
             intended, mirror it in app/lib/logic/warmup.dart, regenerate with \
             LIFT_SNAPSHOT_WARMUP=1 cargo test warmup_golden, and run flutter test.\n\n{}",
            mismatches.join("\n")
        );
    }

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
