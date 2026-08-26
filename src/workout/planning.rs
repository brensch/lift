//! Plan shaping for a flat-set workout. A workout is an ordered list of
//! ProposedSets; "the sets for one exercise" is derived, never stored.
//! Four operations cover everything the app can do to a plan mid-session:
//! add exercises, adjust a weight, remove an exercise, reorder blocks.

use super::*;
use crate::weight_units::{
    bar_weight, kg_to_pounds, plates, pounds_to_kg, simplest_loadable_near, AppWeightUnit,
};

const DEFAULT_SUCCESS_REST_SECONDS: i32 = 180;
const DEFAULT_FAILURE_REST_SECONDS: i32 = 300;
const WARMUP_REST_SECONDS: i32 = 30;

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
/// returned in pounds (storage). The single source of warmup generation — the
/// app renders these, it never computes them.
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

/// Everything needed to prescribe one exercise's block of sets: the tracker
/// weight and the prescription, resolved by the caller (which owns DB access).
pub(crate) struct ExercisePlan {
    pub exercise: i32,
    pub working_weight: f32, // lb
    pub sets: i32,
    pub reps: i32,
    pub rest_success: i32,
    pub rest_failure: i32,
    pub include_warmup: bool,
}

impl ExercisePlan {
    fn rest(&self) -> (i32, i32) {
        (
            if self.rest_success > 0 {
                self.rest_success
            } else {
                DEFAULT_SUCCESS_REST_SECONDS
            },
            if self.rest_failure > 0 {
                self.rest_failure
            } else {
                DEFAULT_FAILURE_REST_SECONDS
            },
        )
    }
}

fn make_set(
    workout_id: &str,
    exercise: i32,
    reps: i32,
    weight: f32,
    warmup: bool,
    rest_s: i32,
    rest_f: i32,
) -> ProposedSet {
    ProposedSet {
        id: Uuid::new_v4().to_string(),
        workout_id: workout_id.to_string(),
        workout_order: 0, // assigned by renumbering
        exercise,
        target_reps: reps,
        target_weight: weight,
        warmup,
        rest_after_success: rest_s,
        rest_after_failure: rest_f,
        cancelled: false,
    }
}

/// One exercise's block: the warmup ladder (where prescribed) followed by the
/// working sets. Orders are assigned by the caller's renumbering pass.
fn generate_sets_for_exercise(
    workout_id: &str,
    plan: &ExercisePlan,
    unit: AppWeightUnit,
) -> Vec<ProposedSet> {
    let (rest_s, rest_f) = plan.rest();
    let mut sets = Vec::new();
    if plan.include_warmup {
        let defs = generate_warmup_defs(plan.working_weight, unit);
        let count = defs.len();
        for (idx, (weight, reps)) in defs.into_iter().enumerate() {
            // The last warmup rolls straight into the first working set, so it
            // rests like a working set rather than the short between-warmups one.
            let rest = if idx + 1 == count {
                rest_s
            } else {
                WARMUP_REST_SECONDS
            };
            sets.push(make_set(
                workout_id, plan.exercise, reps, weight, true, rest, rest,
            ));
        }
    }
    for _ in 0..plan.sets.max(1) {
        sets.push(make_set(
            workout_id,
            plan.exercise,
            plan.reps,
            plan.working_weight,
            false,
            rest_s,
            rest_f,
        ));
    }
    sets
}

/// Plan ops only make sense on a live workout that the request names.
fn require_open_workout(
    workout_ref: &ActiveWorkout,
    workout_id: &str,
) -> Result<(), WorkoutError> {
    if workout_ref.workout.id != workout_id {
        return Err(WorkoutError::failed_precondition("Workout ID mismatch"));
    }
    if workout_ref.workout.end_time > 0 {
        return Err(WorkoutError::failed_precondition("Workout already ended"));
    }
    Ok(())
}

fn completed_proposed_ids(workout_ref: &ActiveWorkout) -> std::collections::HashSet<String> {
    workout_ref
        .completed_sets
        .iter()
        .filter(|c| !c.proposed_set_id.is_empty())
        .map(|c| c.proposed_set_id.clone())
        .collect()
}

/// Append one prescribed block per plan at the end of the workout.
/// `client_working_set_ids` are consumed in block order for the working
/// sets, so an offline client's optimistic sets keep their ids and the
/// completions queued against them reconcile when the mutation lands.
pub(crate) fn apply_add_exercises(
    workout_ref: &mut ActiveWorkout,
    workout_id: &str,
    plans: &[ExercisePlan],
    client_working_set_ids: &[String],
    unit: AppWeightUnit,
) -> Result<(), WorkoutError> {
    require_open_workout(workout_ref, workout_id)?;
    // Ids must be fresh AND unique: a duplicate — within the request or
    // against any existing row — would violate the proposed_sets primary
    // key at persist time and fail the whole write.
    let mut seen: std::collections::HashSet<String> = workout_ref
        .proposed_sets
        .iter()
        .map(|s| s.id.clone())
        .collect();
    let mut ids = client_working_set_ids
        .iter()
        .filter(|id| !id.is_empty() && seen.insert((*id).clone()))
        .cloned()
        .collect::<std::collections::VecDeque<String>>();
    for plan in plans {
        let mut generated = generate_sets_for_exercise(workout_id, plan, unit);
        for set in generated.iter_mut().filter(|s| !s.warmup) {
            if let Some(id) = ids.pop_front() {
                set.id = id;
            }
        }
        workout_ref.proposed_sets.extend(generated);
    }
    workout_ref.renumber_sets();
    Ok(())
}

/// Move an exercise's remaining working sets to a new weight, in place, and
/// regenerate its pending warmups for it. Completed sets are untouched: N
/// completed warmups consume the first (lightest) N rungs of the fresh ladder,
/// and no recalculated rung sits at or below a warmup already done (the
/// downward-edit guard) — both carried over from the old group-edit logic.
pub(crate) fn apply_adjust_exercise_weight(
    workout_ref: &mut ActiveWorkout,
    req: &AdjustExerciseWeightRequest,
    unit: AppWeightUnit,
) -> Result<(), WorkoutError> {
    require_open_workout(workout_ref, &req.workout_id)?;
    if !(0.0..=2000.0).contains(&req.working_weight) {
        return Err(WorkoutError::failed_precondition(
            "Weight out of range",
        ));
    }
    let exercise = req.exercise;
    let done = completed_proposed_ids(workout_ref);

    // Working sets move in place — same count, same reps, same rest.
    let mut rest_s = DEFAULT_SUCCESS_REST_SECONDS;
    for set in workout_ref.proposed_sets.iter_mut().filter(|s| {
        s.exercise == exercise && !s.warmup && !s.cancelled
    }) {
        rest_s = set.rest_after_success;
        if !done.contains(&set.id) {
            set.target_weight = req.working_weight;
        }
    }

    // Warmups regenerate only while some are still pending; once you're past
    // warming up there is nothing to recalculate.
    let pending_warmups = workout_ref
        .proposed_sets
        .iter()
        .filter(|s| s.exercise == exercise && s.warmup && !s.cancelled && !done.contains(&s.id))
        .count();
    if pending_warmups == 0 {
        workout_ref.renumber_sets();
        return Ok(());
    }

    // Two guards carried over from the old edit logic, both driven by what
    // was actually lifted: the pending ladder keeps only as many rungs as
    // are still pending (completed warmups consumed the lightest ones), and
    // no recalculated rung sits at or below a warmup already done. The skip
    // is derived from the pending count rather than the completed count so
    // a re-added exercise (whose earlier block completed its whole ladder)
    // still gets its fresh rungs recalculated instead of deleted.
    let max_done_weight = workout_ref
        .proposed_sets
        .iter()
        .filter(|s| s.exercise == exercise && s.warmup && done.contains(&s.id))
        .map(|s| s.target_weight)
        .fold(f32::MIN, f32::max);
    let has_done_warmup = max_done_weight > f32::MIN;

    let ladder = generate_warmup_defs(req.working_weight, unit);
    let rung_count = ladder.len();
    let fresh_rungs: Vec<ProposedSet> = ladder
        .into_iter()
        .enumerate()
        .skip(rung_count.saturating_sub(pending_warmups))
        .filter(|(_, (weight, _))| {
            !has_done_warmup || *weight > max_done_weight + 1e-3
        })
        .map(|(idx, (weight, reps))| {
            let rest = if idx + 1 == rung_count {
                rest_s
            } else {
                WARMUP_REST_SECONDS
            };
            make_set(&req.workout_id, exercise, reps, weight, true, rest, rest)
        })
        .collect();

    // Splice: the fresh rungs take the position of the first pending warmup;
    // every old pending warmup goes away (never lifted, safe to hard-remove).
    let mut out = Vec::with_capacity(workout_ref.proposed_sets.len());
    let mut inserted = false;
    for set in workout_ref.proposed_sets.drain(..) {
        let pending_warmup =
            set.exercise == exercise && set.warmup && !set.cancelled && !done.contains(&set.id);
        if pending_warmup {
            if !inserted {
                out.extend(fresh_rungs.iter().cloned());
                inserted = true;
            }
            continue;
        }
        out.push(set);
    }
    workout_ref.proposed_sets = out;
    workout_ref.renumber_sets();
    Ok(())
}

/// Cancel an exercise's pending sets. Completed sets stay — the work happened.
pub(crate) fn apply_remove_exercise(
    workout_ref: &mut ActiveWorkout,
    req: &RemoveExerciseRequest,
) -> Result<(), WorkoutError> {
    require_open_workout(workout_ref, &req.workout_id)?;
    let done = completed_proposed_ids(workout_ref);
    for set in workout_ref
        .proposed_sets
        .iter_mut()
        .filter(|s| s.exercise == req.exercise && !done.contains(&s.id))
    {
        set.cancelled = true;
    }
    Ok(())
}

/// Reorder the exercise blocks: listed exercises take the given order; anything
/// unlisted keeps its relative order after them. Stable within a block.
pub(crate) fn apply_reorder_exercises(
    workout_ref: &mut ActiveWorkout,
    req: &ReorderExercisesRequest,
) -> Result<(), WorkoutError> {
    require_open_workout(workout_ref, &req.workout_id)?;
    let rank: std::collections::HashMap<i32, usize> = req
        .exercises
        .iter()
        .enumerate()
        .map(|(idx, exercise)| (*exercise, idx))
        .collect();
    workout_ref.proposed_sets.sort_by_key(|s| {
        (
            rank.get(&s.exercise).copied().unwrap_or(usize::MAX),
            s.workout_order,
        )
    });
    workout_ref.renumber_sets();
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
mod plan_op_tests {
    use super::*;
    use schlift::workout::v1::Workout;

    const SQUAT: i32 = 1;
    const BENCH: i32 = 2;

    fn plan(exercise: i32, weight: f32, warmup: bool) -> ExercisePlan {
        ExercisePlan {
            exercise,
            working_weight: weight,
            sets: 3,
            reps: 6,
            rest_success: 180,
            rest_failure: 300,
            include_warmup: warmup,
        }
    }

    fn empty_workout() -> ActiveWorkout {
        ActiveWorkout::new(
            Workout {
                id: "w1".to_string(),
                name: "T".to_string(),
                start_time: 1,
                ..Default::default()
            },
            vec![],
            vec![],
        )
    }

    fn workout_with(plans: &[ExercisePlan]) -> ActiveWorkout {
        let mut active = empty_workout();
        apply_add_exercises(&mut active, "w1", plans, &[], AppWeightUnit::Lb).unwrap();
        active
    }

    fn complete(active: &mut ActiveWorkout, proposed_id: &str) {
        active.completed_sets.push(CompletedSet {
            id: format!("c_{proposed_id}"),
            workout_id: "w1".to_string(),
            proposed_set_id: proposed_id.to_string(),
            actual_reps: 5,
            actual_weight: 0.0,
            started_at: 100,
            ended_at: 200,
            rest_until: 0,
        });
    }

    fn visible(active: &ActiveWorkout) -> Vec<&ProposedSet> {
        active
            .proposed_sets
            .iter()
            .filter(|s| !s.cancelled)
            .collect()
    }

    fn pending_warmup_weights(active: &ActiveWorkout, exercise: i32) -> Vec<f32> {
        let done: std::collections::HashSet<String> = active
            .completed_sets
            .iter()
            .map(|c| c.proposed_set_id.clone())
            .collect();
        active
            .proposed_sets
            .iter()
            .filter(|s| s.exercise == exercise && s.warmup && !s.cancelled && !done.contains(&s.id))
            .map(|s| s.target_weight)
            .collect()
    }

    fn adjust(active: &mut ActiveWorkout, exercise: i32, weight: f32) {
        apply_adjust_exercise_weight(
            active,
            &AdjustExerciseWeightRequest {
                workout_id: "w1".to_string(),
                exercise,
                working_weight: weight,
            },
            AppWeightUnit::Lb,
        )
        .unwrap();
    }

    // ── AddExercises ────────────────────────────────────────────────────────

    #[test]
    fn add_builds_a_prescribed_block_with_warmups_first() {
        let active = workout_with(&[plan(SQUAT, 200.0, true)]);
        let sets = visible(&active);
        assert_eq!(sets.len(), 7, "4 warmups + 3 working");
        assert!(sets.iter().take(4).all(|s| s.warmup));
        assert!(sets.iter().skip(4).all(|s| !s.warmup));
        assert!(sets.iter().filter(|s| !s.warmup).all(|s| {
            (s.target_weight - 200.0).abs() < 1e-3 && s.target_reps == 6
        }));
        // Warmups climb and stay under the working weight.
        let warmups: Vec<f32> = sets
            .iter()
            .filter(|s| s.warmup)
            .map(|s| s.target_weight)
            .collect();
        assert!(warmups.windows(2).all(|w| w[0] <= w[1]));
        assert!(warmups.iter().all(|&w| w < 200.0));
        // The last warmup rolls into the working set: working rest.
        let last_warmup = sets.iter().rfind(|s| s.warmup).unwrap();
        assert_eq!(last_warmup.rest_after_success, 180);
        assert_eq!(sets[0].rest_after_success, WARMUP_REST_SECONDS);
        // Orders are sequential.
        assert!(sets.iter().enumerate().all(|(i, s)| s.workout_order == i as i32));
    }

    #[test]
    fn add_without_warmup_prescription_gets_none() {
        let active = workout_with(&[plan(SQUAT, 200.0, false)]);
        assert!(active.proposed_sets.iter().all(|s| !s.warmup));
        assert_eq!(active.proposed_sets.len(), 3);
    }

    #[test]
    fn add_appends_after_the_existing_plan() {
        let mut active = workout_with(&[plan(SQUAT, 200.0, false)]);
        apply_add_exercises(&mut active, "w1", &[plan(BENCH, 135.0, false)], &[], AppWeightUnit::Lb)
            .unwrap();
        let exercises: Vec<i32> = active.proposed_sets.iter().map(|s| s.exercise).collect();
        assert_eq!(exercises, vec![SQUAT, SQUAT, SQUAT, BENCH, BENCH, BENCH]);
    }

    #[test]
    fn add_dedupes_client_ids_that_would_break_the_primary_key() {
        // proposed_sets.id is a primary key: a duplicate id — repeated in
        // the request or already present in the workout — must never make
        // it into the plan, or the persist fails and (worse) wedges the
        // offline queue behind a permanently failing mutation.
        let mut active = workout_with(&[plan(SQUAT, 200.0, false)]);
        let existing_id = active.proposed_sets[0].id.clone();
        let ids = vec![
            "dup".to_string(),
            "dup".to_string(),
            existing_id.clone(),
            "fresh".to_string(),
        ];
        apply_add_exercises(&mut active, "w1", &[plan(BENCH, 135.0, false)], &ids, AppWeightUnit::Lb)
            .unwrap();
        let mut seen = std::collections::HashSet::new();
        assert!(
            active.proposed_sets.iter().all(|s| seen.insert(s.id.clone())),
            "every proposed set id must be unique"
        );
        let bench_ids: Vec<&str> = active
            .proposed_sets
            .iter()
            .filter(|s| s.exercise == BENCH)
            .map(|s| s.id.as_str())
            .collect();
        assert_eq!(bench_ids[0], "dup", "first use of a fresh id is kept");
        assert_eq!(bench_ids[1], "fresh");
    }

    #[test]
    fn every_op_rejects_a_finished_workout() {
        let mut active = workout_with(&[plan(SQUAT, 200.0, true)]);
        active.workout.end_time = 9_999;
        assert!(
            apply_add_exercises(&mut active, "w1", &[plan(BENCH, 135.0, false)], &[], AppWeightUnit::Lb)
                .is_err()
        );
        assert!(apply_adjust_exercise_weight(
            &mut active,
            &AdjustExerciseWeightRequest {
                workout_id: "w1".to_string(),
                exercise: SQUAT,
                working_weight: 100.0,
            },
            AppWeightUnit::Lb,
        )
        .is_err());
        assert!(apply_remove_exercise(
            &mut active,
            &RemoveExerciseRequest {
                workout_id: "w1".to_string(),
                exercise: SQUAT,
            },
        )
        .is_err());
        assert!(apply_reorder_exercises(
            &mut active,
            &ReorderExercisesRequest {
                workout_id: "w1".to_string(),
                exercises: vec![SQUAT],
            },
        )
        .is_err());
    }

    #[test]
    fn add_adopts_client_working_set_ids_in_order() {
        let mut active = empty_workout();
        let ids = vec!["c1".to_string(), "c2".to_string(), "c3".to_string()];
        apply_add_exercises(&mut active, "w1", &[plan(SQUAT, 200.0, true)], &ids, AppWeightUnit::Lb)
            .unwrap();
        let working: Vec<&str> = active
            .proposed_sets
            .iter()
            .filter(|s| !s.warmup)
            .map(|s| s.id.as_str())
            .collect();
        assert_eq!(working, vec!["c1", "c2", "c3"]);
        // Warmups never take client ids.
        assert!(active
            .proposed_sets
            .iter()
            .filter(|s| s.warmup)
            .all(|s| !s.id.starts_with('c')));
    }

    // ── AdjustExerciseWeight ────────────────────────────────────────────────

    #[test]
    fn adjust_moves_pending_working_sets_and_recalculates_warmups() {
        let mut active = workout_with(&[plan(SQUAT, 200.0, true)]);
        let before = pending_warmup_weights(&active, SQUAT);
        adjust(&mut active, SQUAT, 300.0);

        assert!(active
            .proposed_sets
            .iter()
            .filter(|s| !s.warmup)
            .all(|s| (s.target_weight - 300.0).abs() < 1e-3));
        let warmups = pending_warmup_weights(&active, SQUAT);
        assert_eq!(warmups.len(), 4, "a fresh ladder is 4 warmups");
        assert_ne!(warmups, before, "warmups follow the new weight");
        assert!(warmups.iter().all(|&w| w < 300.0));
        // Warmups still precede working sets, orders sequential.
        let sets = visible(&active);
        assert!(sets.iter().take(4).all(|s| s.warmup));
        assert!(sets.iter().enumerate().all(|(i, s)| s.workout_order == i as i32));
    }

    #[test]
    fn adjust_keeps_completed_sets_and_recalculates_the_remaining_warmups() {
        let mut active = workout_with(&[plan(SQUAT, 200.0, true)]);
        let (wu1, wu2) = {
            let warmups: Vec<&ProposedSet> =
                active.proposed_sets.iter().filter(|s| s.warmup).collect();
            (warmups[0].id.clone(), warmups[1].id.clone())
        };
        complete(&mut active, &wu1);
        complete(&mut active, &wu2);
        adjust(&mut active, SQUAT, 300.0);

        // 2 done + 2 recalculated = 4, never doubled.
        let all_warmups: Vec<&ProposedSet> = active
            .proposed_sets
            .iter()
            .filter(|s| s.warmup && !s.cancelled)
            .collect();
        assert_eq!(all_warmups.len(), 4);
        let pending = pending_warmup_weights(&active, SQUAT);
        assert_eq!(pending.len(), 2, "the top two rungs were recalculated");
        assert!(pending.iter().all(|&w| w < 300.0));
        // The done rows are untouched.
        assert!(all_warmups.iter().any(|s| s.id == wu1));
        assert!(all_warmups.iter().any(|s| s.id == wu2));
    }

    #[test]
    fn a_large_downward_adjust_drops_warmups_youve_passed() {
        let mut active = workout_with(&[plan(SQUAT, 200.0, true)]);
        let done_ids: Vec<String> = active
            .proposed_sets
            .iter()
            .filter(|s| s.warmup)
            .take(3)
            .map(|s| s.id.clone())
            .collect();
        let heaviest_done = active
            .proposed_sets
            .iter()
            .filter(|s| s.warmup)
            .take(3)
            .map(|s| s.target_weight)
            .fold(f32::MIN, f32::max);
        for id in &done_ids {
            complete(&mut active, id);
        }
        adjust(&mut active, SQUAT, 100.0);

        let pending = pending_warmup_weights(&active, SQUAT);
        assert!(
            pending.iter().all(|&w| w > heaviest_done),
            "no recalculated rung at/below one already done: {pending:?}"
        );
    }

    /// Complete a whole ladder, remove the exercise, add it again, then
    /// adjust the weight. The earlier block's completed warmups must not
    /// consume the fresh block's rungs — that would delete the new ladder
    /// outright (the skip is derived from the pending count, not the
    /// completed count).
    #[test]
    fn adjust_after_remove_and_re_add_keeps_the_fresh_ladder() {
        let mut active = workout_with(&[plan(SQUAT, 200.0, true)]);
        let (first_warmups, max_done): (Vec<String>, f32) = {
            let warmups: Vec<&ProposedSet> =
                active.proposed_sets.iter().filter(|s| s.warmup).collect();
            (
                warmups.iter().map(|s| s.id.clone()).collect(),
                warmups
                    .iter()
                    .map(|s| s.target_weight)
                    .fold(f32::MIN, f32::max),
            )
        };
        for id in &first_warmups {
            complete(&mut active, id);
        }
        apply_remove_exercise(
            &mut active,
            &RemoveExerciseRequest {
                workout_id: "w1".to_string(),
                exercise: SQUAT,
            },
        )
        .unwrap();
        apply_add_exercises(&mut active, "w1", &[plan(SQUAT, 200.0, true)], &[], AppWeightUnit::Lb)
            .unwrap();
        adjust(&mut active, SQUAT, 400.0);

        let pending = pending_warmup_weights(&active, SQUAT);
        assert!(
            !pending.is_empty(),
            "the re-added block keeps a recalculated ladder"
        );
        assert!(
            pending.iter().all(|&w| w > max_done),
            "the surpassed-weight guard still applies: {pending:?}"
        );
    }

    #[test]
    fn adjust_past_the_warmups_leaves_them_alone() {
        let mut active = workout_with(&[plan(SQUAT, 200.0, true)]);
        let warmup_ids: Vec<String> = active
            .proposed_sets
            .iter()
            .filter(|s| s.warmup)
            .map(|s| s.id.clone())
            .collect();
        for id in &warmup_ids {
            complete(&mut active, id);
        }
        let count_before = active.proposed_sets.len();
        adjust(&mut active, SQUAT, 250.0);

        assert_eq!(active.proposed_sets.len(), count_before, "no new rungs mid-lift");
        assert!(active
            .proposed_sets
            .iter()
            .filter(|s| !s.warmup)
            .all(|s| (s.target_weight - 250.0).abs() < 1e-3));
    }

    #[test]
    fn adjust_leaves_completed_working_sets_at_their_lifted_weight() {
        let mut active = workout_with(&[plan(SQUAT, 200.0, false)]);
        let first_working = active.proposed_sets[0].id.clone();
        complete(&mut active, &first_working);
        adjust(&mut active, SQUAT, 250.0);

        let done_set = active
            .proposed_sets
            .iter()
            .find(|s| s.id == first_working)
            .unwrap();
        assert!((done_set.target_weight - 200.0).abs() < 1e-3, "history is history");
        assert!(active
            .proposed_sets
            .iter()
            .filter(|s| s.id != first_working)
            .all(|s| (s.target_weight - 250.0).abs() < 1e-3));
    }

    #[test]
    fn adjust_only_touches_its_own_exercise() {
        let mut active = workout_with(&[plan(SQUAT, 200.0, false), plan(BENCH, 135.0, false)]);
        adjust(&mut active, SQUAT, 250.0);
        assert!(active
            .proposed_sets
            .iter()
            .filter(|s| s.exercise == BENCH)
            .all(|s| (s.target_weight - 135.0).abs() < 1e-3));
    }

    // ── RemoveExercise ──────────────────────────────────────────────────────

    #[test]
    fn remove_cancels_pending_sets_and_keeps_completed_ones() {
        let mut active = workout_with(&[plan(SQUAT, 200.0, false), plan(BENCH, 135.0, false)]);
        let first_squat = active.proposed_sets[0].id.clone();
        complete(&mut active, &first_squat);
        apply_remove_exercise(
            &mut active,
            &RemoveExerciseRequest {
                workout_id: "w1".to_string(),
                exercise: SQUAT,
            },
        )
        .unwrap();

        let squat_sets: Vec<&ProposedSet> = active
            .proposed_sets
            .iter()
            .filter(|s| s.exercise == SQUAT)
            .collect();
        assert!(squat_sets.iter().filter(|s| s.id != first_squat).all(|s| s.cancelled));
        assert!(!squat_sets.iter().find(|s| s.id == first_squat).unwrap().cancelled);
        assert!(active
            .proposed_sets
            .iter()
            .filter(|s| s.exercise == BENCH)
            .all(|s| !s.cancelled));
    }

    // ── ReorderExercises ────────────────────────────────────────────────────

    #[test]
    fn reorder_moves_whole_blocks_and_renumbers() {
        let mut active = workout_with(&[plan(SQUAT, 200.0, false), plan(BENCH, 135.0, false)]);
        apply_reorder_exercises(
            &mut active,
            &ReorderExercisesRequest {
                workout_id: "w1".to_string(),
                exercises: vec![BENCH, SQUAT],
            },
        )
        .unwrap();
        let exercises: Vec<i32> = active.proposed_sets.iter().map(|s| s.exercise).collect();
        assert_eq!(exercises, vec![BENCH, BENCH, BENCH, SQUAT, SQUAT, SQUAT]);
        assert!(active
            .proposed_sets
            .iter()
            .enumerate()
            .all(|(i, s)| s.workout_order == i as i32));
    }

    #[test]
    fn reorder_leaves_unlisted_exercises_after_the_listed_ones() {
        let mut active = workout_with(&[
            plan(SQUAT, 200.0, false),
            plan(BENCH, 135.0, false),
            plan(3, 100.0, false),
        ]);
        apply_reorder_exercises(
            &mut active,
            &ReorderExercisesRequest {
                workout_id: "w1".to_string(),
                exercises: vec![3],
            },
        )
        .unwrap();
        let exercises: Vec<i32> = active
            .proposed_sets
            .iter()
            .map(|s| s.exercise)
            .collect();
        assert_eq!(exercises, vec![3, 3, 3, SQUAT, SQUAT, SQUAT, BENCH, BENCH, BENCH]);
    }

    #[test]
    fn every_op_rejects_the_wrong_workout() {
        let mut active = workout_with(&[plan(SQUAT, 200.0, false)]);
        assert!(apply_add_exercises(&mut active, "other", &[], &[], AppWeightUnit::Lb).is_err());
        assert!(apply_adjust_exercise_weight(
            &mut active,
            &AdjustExerciseWeightRequest {
                workout_id: "other".to_string(),
                exercise: SQUAT,
                working_weight: 100.0,
            },
            AppWeightUnit::Lb,
        )
        .is_err());
        assert!(apply_remove_exercise(
            &mut active,
            &RemoveExerciseRequest {
                workout_id: "other".to_string(),
                exercise: SQUAT,
            },
        )
        .is_err());
        assert!(apply_reorder_exercises(
            &mut active,
            &ReorderExercisesRequest {
                workout_id: "other".to_string(),
                exercises: vec![SQUAT],
            },
        )
        .is_err());
    }
}
