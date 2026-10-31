//! Plan shaping for a flat-set workout. A workout is an ordered list of
//! ProposedSets; "the sets for one exercise" is derived, never stored.
//! Four operations cover everything the app can do to a plan mid-session:
//! add exercises, adjust a weight, remove an exercise, reorder blocks —
//! plus the calibration ramp's appends, which the reducer drives.

use super::*;
use crate::exercise_catalog::{prescription, progression_increment_lb, snap_weight_lb};
use crate::ids::{derived_id, Ids};
use crate::pb::Exercise;
use crate::weight_units::{
    bar_weight, kg_to_pounds, plates, pounds_to_kg, simplest_loadable_near, AppWeightUnit,
};

const DEFAULT_SUCCESS_REST_SECONDS: i32 = 180;
const DEFAULT_FAILURE_REST_SECONDS: i32 = 300;
const WARMUP_REST_SECONDS: i32 = 30;
/// A calibration rung is always five reps, rested 90 s whatever happened.
pub const CALIBRATION_REPS: i32 = 5;
pub const CALIBRATION_REST_SECONDS: i32 = 90;
/// The ramp stops here; the sixth rung is treated as right.
pub const MAX_CALIBRATION_RUNGS: usize = 6;
/// Where a ramp settles: 90% of the heaviest rung done in full. A set of 5
/// taken to a miss is about 85% of a one-rep max, and five sets of five
/// sit around 75–80% of it (standard %1RM tables), so a tenth under the
/// top rung is a weight every set can be finished at.
pub const CALIBRATION_SETTLE_FRACTION: f32 = 0.9;
/// Each rung climbs by at least this fraction of the current weight.
const CALIBRATION_RUNG_FRACTION: f32 = 1.10;

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
        // A rung at the same weight as the one before it is the same lift
        // again: a light working weight would otherwise warm up on the empty
        // bar four times. Keep the first rung at each weight.
        if idx > 0 && chosen == prev {
            continue;
        }
        prev = chosen;
        out.push((to_pounds(chosen, unit), reps[idx]));
    }

    out
}

/// Everything needed to prescribe one exercise's block of sets: the tracker
/// weight and the prescription, resolved by the caller (which owns DB access).
pub struct ExercisePlan {
    pub exercise: i32,
    pub working_weight: f32, // lb
    pub sets: i32,
    pub reps: i32,
    pub rest_success: i32,
    pub rest_failure: i32,
    pub include_warmup: bool,
    /// First session of a loaded exercise: the block is one calibration
    /// rung at `working_weight` (the ramp start) and nothing else.
    pub calibration: bool,
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
        id: String::new(), // the caller gives it one
        workout_id: workout_id.to_string(),
        workout_order: 0, // assigned by renumbering
        exercise,
        target_reps: reps,
        target_weight: weight,
        warmup,
        rest_after_success: rest_s,
        rest_after_failure: rest_f,
        cancelled: false,
        calibration: false,
        skipped: false,
    }
}

/// One rung of the calibration ramp: five reps at `weight`, 90 s rest.
pub fn calibration_set(workout_id: &str, exercise: i32, weight: f32) -> ProposedSet {
    let mut set = make_set(
        workout_id,
        exercise,
        CALIBRATION_REPS,
        weight,
        false,
        CALIBRATION_REST_SECONDS,
        CALIBRATION_REST_SECONDS,
    );
    set.calibration = true;
    set
}

/// The next rung up from `weight`: the larger of one equipment step and
/// 10%, snapped to what the exercise can load.
pub fn next_calibration_weight(exercise: i32, weight: f32, unit: AppWeightUnit) -> f32 {
    let Ok(ex) = Exercise::try_from(exercise) else {
        return weight;
    };
    let step = progression_increment_lb(ex, unit);
    snap_weight_lb(
        ex,
        (weight + step).max(weight * CALIBRATION_RUNG_FRACTION),
        unit,
    )
}

/// The working sets a ramp settles on: the catalog prescription's sets at
/// its range bottom and rest, all at `weight`.
pub fn working_sets_after_calibration(
    workout_id: &str,
    exercise: i32,
    weight: f32,
) -> Vec<ProposedSet> {
    let Ok(ex) = Exercise::try_from(exercise) else {
        return Vec::new();
    };
    prescribed_working_sets(workout_id, exercise, weight, prescription(ex).sets.max(1))
}

/// `count` working sets of the catalog prescription (range bottom, its
/// rest) at `weight`. Ids are fresh; callers that need stable ids set them.
fn prescribed_working_sets(
    workout_id: &str,
    exercise: i32,
    weight: f32,
    count: i32,
) -> Vec<ProposedSet> {
    let Ok(ex) = Exercise::try_from(exercise) else {
        return Vec::new();
    };
    let p = prescription(ex);
    (0..count)
        .map(|_| {
            make_set(
                workout_id,
                exercise,
                p.rep_low,
                weight,
                false,
                p.rest_seconds,
                p.rest_seconds_failure,
            )
        })
        .collect()
}

/// "I know my weight" during calibration: the user typed a weight while
/// the exercise still has a rung to lift. The pending rungs go (never
/// lifted, safe to hard-remove) and the prescription's full working sets
/// take their place at the snapped weight. Ids are
/// `uuid5(NAMESPACE_OID, "{first pending rung id}:{n}")`. No warmup
/// ladder: the done rungs were the warmup. Returns false when there is no
/// pending rung, leaving the ordinary adjust to run.
fn replace_pending_calibration(
    workout_ref: &mut WorkoutRecord,
    req: &AdjustExerciseWeightRequest,
    unit: AppWeightUnit,
) -> bool {
    let exercise = req.exercise;
    let Ok(ex) = Exercise::try_from(exercise) else {
        return false;
    };
    let done = completed_proposed_ids(workout_ref);
    let is_pending_rung = |s: &ProposedSet| {
        s.exercise == exercise && s.calibration && !s.cancelled && !done.contains(&s.id)
    };
    let Some(at) = workout_ref.proposed_sets.iter().position(is_pending_rung) else {
        return false;
    };
    let base = workout_ref.proposed_sets[at].id.clone();
    let weight = snap_weight_lb(ex, req.working_weight, unit);
    let mut sets = prescribed_working_sets(
        &req.workout_id,
        exercise,
        weight,
        prescription(ex).sets.max(1),
    );
    for (n, set) in sets.iter_mut().enumerate() {
        set.id = derived_id(&base, n);
    }
    // Pending rungs only ever sit after the done ones, so `at` is unmoved.
    workout_ref.proposed_sets.retain(|s| !is_pending_rung(s));
    let at = at.min(workout_ref.proposed_sets.len());
    workout_ref.proposed_sets.splice(at..at, sets);
    workout_ref.renumber_sets();
    true
}

/// Splice `sets` in straight after the set `after_id`, ahead of whatever
/// follows it (another exercise's block included), and renumber. Falls
/// back to the end when the anchor is missing.
pub fn insert_sets_after(workout_ref: &mut WorkoutRecord, after_id: &str, sets: Vec<ProposedSet>) {
    let at = workout_ref
        .proposed_sets
        .iter()
        .position(|s| s.id == after_id)
        .map(|idx| idx + 1)
        .unwrap_or(workout_ref.proposed_sets.len());
    workout_ref.proposed_sets.splice(at..at, sets);
    workout_ref.renumber_sets();
}

/// One exercise's block: the warmup ladder (where prescribed) followed by the
/// working sets — or, on a calibration session, the single opening rung.
/// Orders are assigned by the caller's renumbering pass.
fn generate_sets_for_exercise(
    workout_id: &str,
    plan: &ExercisePlan,
    unit: AppWeightUnit,
    ids: &mut Ids,
) -> Vec<ProposedSet> {
    let mut sets = block_sets(workout_id, plan, unit);
    for set in &mut sets {
        set.id = ids.new_id();
    }
    sets
}

fn block_sets(workout_id: &str, plan: &ExercisePlan, unit: AppWeightUnit) -> Vec<ProposedSet> {
    if plan.calibration {
        return vec![calibration_set(
            workout_id,
            plan.exercise,
            plan.working_weight,
        )];
    }
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
                workout_id,
                plan.exercise,
                reps,
                weight,
                true,
                rest,
                rest,
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
fn require_open_workout(workout_ref: &WorkoutRecord, workout_id: &str) -> Result<(), WorkoutError> {
    if workout_ref.workout.id != workout_id {
        return Err(WorkoutError::failed_precondition("Workout ID mismatch"));
    }
    if workout_ref.workout.end_time > 0 {
        return Err(WorkoutError::failed_precondition("Workout already ended"));
    }
    Ok(())
}

fn completed_proposed_ids(workout_ref: &WorkoutRecord) -> std::collections::HashSet<String> {
    workout_ref
        .completed_sets
        .iter()
        .filter(|c| !c.proposed_set_id.is_empty())
        .map(|c| c.proposed_set_id.clone())
        .collect()
}

/// Append one prescribed block per plan at the end of the workout.
pub fn apply_add_exercises(
    workout_ref: &mut WorkoutRecord,
    workout_id: &str,
    plans: &[ExercisePlan],
    unit: AppWeightUnit,
    ids: &mut Ids,
) -> Result<(), WorkoutError> {
    require_open_workout(workout_ref, workout_id)?;
    for plan in plans {
        let generated = generate_sets_for_exercise(workout_id, plan, unit, ids);
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
pub fn apply_adjust_exercise_weight(
    workout_ref: &mut WorkoutRecord,
    req: &AdjustExerciseWeightRequest,
    unit: AppWeightUnit,
    ids: &mut Ids,
) -> Result<(), WorkoutError> {
    require_open_workout(workout_ref, &req.workout_id)?;
    if !(0.0..=2000.0).contains(&req.working_weight) {
        return Err(WorkoutError::failed_precondition("Weight out of range"));
    }
    if !(0..=100).contains(&req.target_reps) {
        return Err(WorkoutError::failed_precondition("Reps out of range"));
    }
    if replace_pending_calibration(workout_ref, req, unit) {
        apply_target_reps(workout_ref, req);
        return Ok(());
    }
    apply_target_reps(workout_ref, req);
    let exercise = req.exercise;
    let done = completed_proposed_ids(workout_ref);

    // Working sets move in place — same count, same reps, same rest.
    let mut rest_s = DEFAULT_SUCCESS_REST_SECONDS;
    for set in workout_ref
        .proposed_sets
        .iter_mut()
        .filter(|s| s.exercise == exercise && !s.warmup && !s.cancelled)
    {
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
        .filter(|(_, (weight, _))| !has_done_warmup || *weight > max_done_weight + 1e-3)
        .map(|(idx, (weight, reps))| {
            let rest = if idx + 1 == rung_count {
                rest_s
            } else {
                WARMUP_REST_SECONDS
            };
            let mut set = make_set(&req.workout_id, exercise, reps, weight, true, rest, rest);
            set.id = ids.new_id();
            set
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

/// A rep target given with the adjust: every working set of the exercise
/// still to do takes it. Rungs and warmups keep theirs.
fn apply_target_reps(workout_ref: &mut WorkoutRecord, req: &AdjustExerciseWeightRequest) {
    if req.target_reps <= 0 {
        return;
    }
    let done = completed_proposed_ids(workout_ref);
    for set in workout_ref.proposed_sets.iter_mut().filter(|s| {
        s.exercise == req.exercise
            && !s.warmup
            && !s.calibration
            && !s.cancelled
            && !done.contains(&s.id)
    }) {
        set.target_reps = req.target_reps;
    }
}

/// Cancel an exercise's pending sets. Completed sets stay — the work happened.
pub fn apply_remove_exercise(
    workout_ref: &mut WorkoutRecord,
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
pub fn apply_reorder_exercises(
    workout_ref: &mut WorkoutRecord,
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

    /// A light working weight warms up on the empty bar once, not four times.
    #[test]
    fn a_light_working_weight_warms_up_on_the_bar_once() {
        let defs = generate_warmup_defs(60.0, AppWeightUnit::Lb);
        assert_eq!(defs, vec![(45.0, 5)]);
        // A heavy one still gets the full ladder.
        assert_eq!(generate_warmup_defs(225.0, AppWeightUnit::Lb).len(), 4);
    }

    /// Properties the app relies on regardless of the exact numbers — in BOTH units.
    #[test]
    fn warmup_defs_are_non_decreasing_and_below_the_working_weight() {
        for unit in [AppWeightUnit::Lb, AppWeightUnit::Kg] {
            for w in golden_working_weights() {
                let defs = generate_warmup_defs(w, unit);
                assert!(
                    (1..=4).contains(&defs.len()),
                    "expected 1 to 4 warmups for {w} ({unit:?}), got {}",
                    defs.len()
                );

                let mut prev = 0.0_f32;
                for (weight_lb, reps) in defs {
                    assert!(
                        weight_lb > prev,
                        "warmups must strictly increase at {w} ({unit:?})"
                    );
                    assert!(
                        weight_lb < w + 1e-3,
                        "warmup {weight_lb} must be under {w} ({unit:?})"
                    );
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
    use crate::pb::Workout;

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
            calibration: false,
        }
    }

    fn empty_workout() -> WorkoutRecord {
        WorkoutRecord::new(
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

    fn test_ids() -> Ids {
        Ids::new(&uuid::Uuid::new_v4().to_string())
    }

    fn workout_with(plans: &[ExercisePlan]) -> WorkoutRecord {
        let mut active = empty_workout();
        apply_add_exercises(&mut active, "w1", plans, AppWeightUnit::Lb, &mut test_ids()).unwrap();
        active
    }

    fn complete(active: &mut WorkoutRecord, proposed_id: &str) {
        active.completed_sets.push(CompletedSet {
            id: format!("c_{proposed_id}"),
            workout_id: "w1".to_string(),
            proposed_set_id: proposed_id.to_string(),
            actual_reps: 5,
            actual_weight: 0.0,
            ended_at: 200,
            rest_until: 0,
            ..Default::default()
        });
    }

    fn visible(active: &WorkoutRecord) -> Vec<&ProposedSet> {
        active
            .proposed_sets
            .iter()
            .filter(|s| !s.cancelled)
            .collect()
    }

    fn pending_warmup_weights(active: &WorkoutRecord, exercise: i32) -> Vec<f32> {
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

    fn adjust(active: &mut WorkoutRecord, exercise: i32, weight: f32) {
        apply_adjust_exercise_weight(
            active,
            &AdjustExerciseWeightRequest {
                workout_id: "w1".to_string(),
                exercise,
                working_weight: weight,
                target_reps: 0,
            },
            AppWeightUnit::Lb,
            &mut test_ids(),
        )
        .unwrap();
    }

    #[test]
    fn adjust_with_reps_sets_the_remaining_working_sets() {
        let mut active = workout_with(&[plan(SQUAT, 200.0, true)]);
        let first_working = visible(&active)
            .iter()
            .find(|s| !s.warmup)
            .unwrap()
            .id
            .clone();
        active.completed_sets.push(CompletedSet {
            id: "c1".to_string(),
            workout_id: "w1".to_string(),
            proposed_set_id: first_working.clone(),
            actual_reps: 6,
            actual_weight: 200.0,
            ended_at: 2_000,
            ..Default::default()
        });
        apply_adjust_exercise_weight(
            &mut active,
            &AdjustExerciseWeightRequest {
                workout_id: "w1".to_string(),
                exercise: SQUAT,
                working_weight: 210.0,
                target_reps: 4,
            },
            AppWeightUnit::Lb,
            &mut test_ids(),
        )
        .unwrap();
        let sets = visible(&active);
        for s in sets.iter().filter(|s| !s.warmup) {
            if s.id == first_working {
                assert_eq!(s.target_reps, 6, "a done set keeps its reps");
            } else {
                assert_eq!(s.target_reps, 4);
                assert!((s.target_weight - 210.0).abs() < 1e-3);
            }
        }
        assert!(
            sets.iter().filter(|s| s.warmup).all(|s| s.target_reps != 4),
            "warmups keep their ladder reps"
        );
    }

    // ── AddExercises ────────────────────────────────────────────────────────

    #[test]
    fn add_builds_a_prescribed_block_with_warmups_first() {
        let active = workout_with(&[plan(SQUAT, 200.0, true)]);
        let sets = visible(&active);
        assert_eq!(sets.len(), 7, "4 warmups + 3 working");
        assert!(sets.iter().take(4).all(|s| s.warmup));
        assert!(sets.iter().skip(4).all(|s| !s.warmup));
        assert!(sets
            .iter()
            .filter(|s| !s.warmup)
            .all(|s| { (s.target_weight - 200.0).abs() < 1e-3 && s.target_reps == 6 }));
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
        assert!(sets
            .iter()
            .enumerate()
            .all(|(i, s)| s.workout_order == i as i32));
    }

    #[test]
    fn a_calibration_plan_is_one_rung() {
        let mut calibration = plan(SQUAT, 110.0, true);
        calibration.calibration = true;
        let active = workout_with(&[calibration, plan(BENCH, 100.0, false)]);
        let squat: Vec<&ProposedSet> = active
            .proposed_sets
            .iter()
            .filter(|s| s.exercise == SQUAT)
            .collect();
        assert_eq!(
            squat.len(),
            1,
            "no ladder, no working sets: the ramp is the warmup"
        );
        let rung = squat[0];
        assert!(rung.calibration);
        assert!(!rung.warmup);
        assert_eq!(rung.target_reps, CALIBRATION_REPS);
        assert_eq!(rung.target_weight, 110.0);
        assert_eq!(rung.rest_after_success, CALIBRATION_REST_SECONDS);
        assert_eq!(rung.rest_after_failure, CALIBRATION_REST_SECONDS);
        assert_eq!(
            active.proposed_sets.len(),
            4,
            "the bench block is untouched"
        );
    }

    #[test]
    fn the_next_rung_is_a_step_or_ten_percent_whichever_is_more() {
        let unit = AppWeightUnit::Lb;
        assert_eq!(
            next_calibration_weight(SQUAT, 45.0, unit),
            50.0,
            "a bar step"
        );
        assert_eq!(next_calibration_weight(SQUAT, 200.0, unit), 220.0, "10%");
        let raise = Exercise::LateralRaise as i32;
        assert_eq!(
            next_calibration_weight(raise, 20.0, unit),
            25.0,
            "a dumbbell step"
        );
    }

    #[test]
    fn working_sets_after_calibration_follow_the_prescription() {
        let sets = working_sets_after_calibration("w1", SQUAT, 95.0);
        assert_eq!(sets.len(), 5, "the full 5×5");
        for set in &sets {
            assert_eq!(set.target_weight, 95.0);
            assert_eq!(set.target_reps, 5);
            assert_eq!((set.rest_after_success, set.rest_after_failure), (180, 240));
            assert!(!set.warmup && !set.calibration);
        }
    }

    #[test]
    fn insert_sets_after_splices_ahead_of_the_following_block() {
        let mut active = workout_with(&[plan(SQUAT, 200.0, false), plan(BENCH, 100.0, false)]);
        let anchor = active.proposed_sets[0].id.clone();
        insert_sets_after(
            &mut active,
            &anchor,
            vec![calibration_set("w1", SQUAT, 50.0)],
        );
        assert_eq!(active.proposed_sets.len(), 7);
        assert!(active.proposed_sets[1].calibration);
        assert_eq!(active.proposed_sets[1].workout_order, 1);
        assert!(active.proposed_sets[4..]
            .iter()
            .all(|s| s.exercise == BENCH));
        assert!(active
            .proposed_sets
            .iter()
            .enumerate()
            .all(|(i, s)| s.workout_order == i as i32));

        // A missing anchor appends at the end rather than losing the sets.
        insert_sets_after(
            &mut active,
            "missing",
            vec![calibration_set("w1", SQUAT, 55.0)],
        );
        assert_eq!(active.proposed_sets.len(), 8);
        assert_eq!(active.proposed_sets[7].target_weight, 55.0);
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
        apply_add_exercises(
            &mut active,
            "w1",
            &[plan(BENCH, 135.0, false)],
            AppWeightUnit::Lb,
            &mut test_ids(),
        )
        .unwrap();
        let exercises: Vec<i32> = active.proposed_sets.iter().map(|s| s.exercise).collect();
        assert_eq!(exercises, vec![SQUAT, SQUAT, SQUAT, BENCH, BENCH, BENCH]);
    }

    #[test]
    fn every_op_rejects_a_finished_workout() {
        let mut active = workout_with(&[plan(SQUAT, 200.0, true)]);
        active.workout.end_time = 9_999;
        assert!(apply_add_exercises(
            &mut active,
            "w1",
            &[plan(BENCH, 135.0, false)],
            AppWeightUnit::Lb,
            &mut test_ids(),
        )
        .is_err());
        assert!(apply_adjust_exercise_weight(
            &mut active,
            &AdjustExerciseWeightRequest {
                workout_id: "w1".to_string(),
                exercise: SQUAT,
                working_weight: 100.0,
                target_reps: 0,
            },
            AppWeightUnit::Lb,
            &mut test_ids(),
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
        assert!(sets
            .iter()
            .enumerate()
            .all(|(i, s)| s.workout_order == i as i32));
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
        apply_add_exercises(
            &mut active,
            "w1",
            &[plan(SQUAT, 200.0, true)],
            AppWeightUnit::Lb,
            &mut test_ids(),
        )
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

        assert_eq!(
            active.proposed_sets.len(),
            count_before,
            "no new rungs mid-lift"
        );
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
        assert!(
            (done_set.target_weight - 200.0).abs() < 1e-3,
            "history is history"
        );
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
        assert!(squat_sets
            .iter()
            .filter(|s| s.id != first_squat)
            .all(|s| s.cancelled));
        assert!(
            !squat_sets
                .iter()
                .find(|s| s.id == first_squat)
                .unwrap()
                .cancelled
        );
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
        let exercises: Vec<i32> = active.proposed_sets.iter().map(|s| s.exercise).collect();
        assert_eq!(
            exercises,
            vec![3, 3, 3, SQUAT, SQUAT, SQUAT, BENCH, BENCH, BENCH]
        );
    }

    #[test]
    fn every_op_rejects_the_wrong_workout() {
        let mut active = workout_with(&[plan(SQUAT, 200.0, false)]);
        assert!(apply_add_exercises(
            &mut active,
            "other",
            &[],
            AppWeightUnit::Lb,
            &mut test_ids()
        )
        .is_err());
        assert!(apply_adjust_exercise_weight(
            &mut active,
            &AdjustExerciseWeightRequest {
                workout_id: "other".to_string(),
                exercise: SQUAT,
                working_weight: 100.0,
                target_reps: 0,
            },
            AppWeightUnit::Lb,
            &mut test_ids(),
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
