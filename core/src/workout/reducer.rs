use super::*;
use crate::exercise_catalog::snap_weight_lb;
use crate::ids::{derived_id, Ids};
use crate::pb::{
    EditCompletedSetRequest, Effort, Exercise, SkipWarmupsRequest, StartSetRequest, Workout,
};
use crate::progress::compute_next_up_set;
use crate::weight_units::AppWeightUnit;

const STATE_ALL_DONE: i32 = 1;
const STATE_RESTING: i32 = 3;
const STATE_READY: i32 = 5;
const STATE_YAPPING: i32 = 6;
const STATE_LIFTING: i32 = 7;

pub fn active_proposed_sets(proposed_sets: &[ProposedSet]) -> Vec<ProposedSet> {
    proposed_sets
        .iter()
        .filter(|set| !set.cancelled)
        .cloned()
        .collect()
}

pub fn workout_plan_change_stats_from_sets(
    proposed_sets: &[ProposedSet],
) -> WorkoutPlanChangeStats {
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

pub fn is_final_set_of_exercise_after_completion(
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

    let exercise = current.exercise;

    // Finishing a working set puts the exercise's undone warmups behind
    // you (`is_passed_warmup`): they don't keep it open.
    !proposed_sets
        .iter()
        .filter(|set| {
            set.exercise == exercise
                && !set.cancelled
                && set.id != proposed_set_id
                && (current.warmup || !set.warmup)
        })
        .any(|set| {
            !completed_sets
                .iter()
                .any(|done| done.proposed_set_id == set.id && done.ended_at != 0)
        })
}

/// The most recently finished set, by `ended_at`.
fn last_done_set(completed_sets: &[CompletedSet]) -> Option<&CompletedSet> {
    completed_sets
        .iter()
        .filter(|set| set.ended_at != 0)
        .max_by_key(|set| set.ended_at)
}

/// The workout's state, derived from its sets and lifting marker (see
/// `WorkoutState` in workout.proto): LIFTING while the marker points at a
/// set that is still pending; otherwise, after a done set, RESTING while its
/// rest runs and YAPPING once it has run out; READY before any set; ALL_DONE
/// with nothing left. Mirrored in the app's `WorkoutProvider`.
pub fn workout_state_snapshot(
    workout: &Workout,
    proposed_sets: &[ProposedSet],
    completed_sets: &[CompletedSet],
    now: i64,
) -> WorkoutStateSnapshot {
    let proposed_active = active_proposed_sets(proposed_sets);
    let next_up_set = compute_next_up_set(&proposed_active, completed_sets);
    // Nothing is asked: a set says what it did by its reps.
    let effort_prompt = None;

    // A started set that is still pending is being lifted, whatever the
    // rest: the timer counts up from its start.
    if !workout.lifting_set_id.is_empty() {
        let lifting = proposed_active
            .iter()
            .find(|p| p.id == workout.lifting_set_id)
            .filter(|p| {
                !completed_sets
                    .iter()
                    .any(|c| c.proposed_set_id == p.id && c.ended_at != 0)
            });
        if let Some(set) = lifting {
            return WorkoutStateSnapshot {
                state: STATE_LIFTING,
                display_set: Some(set.clone()),
                rest_until: 0,
                effort_prompt,
                lifting_started_at: workout.lifting_started_at,
            };
        }
    }

    // Nothing left to do: the workout is finished. Resting only matters when
    // there is a next set to rest *before* — after the final set there is no set
    // to do, so we must not linger in RESTING/READY (which would offer a Done
    // button pointing at the just-finished set and log it in a loop).
    let Some(next) = next_up_set else {
        return WorkoutStateSnapshot {
            state: STATE_ALL_DONE,
            display_set: None,
            rest_until: 0,
            effort_prompt,
            lifting_started_at: 0,
        };
    };

    // A set is up next. The state comes from one moment, when the last set was
    // done, and its prescribed rest: resting while that rest runs, yapping once
    // it has run out, and ready only before the first set. Either way
    // `display_set` is that next set — every consumer (phone bar, watch,
    // workout screen) uses display_set as the set its Done button targets, so
    // it must be the upcoming one. `rest_until` is what both timers count
    // from: down to it while resting, up from it while yapping.
    if let Some(last) = last_done_set(completed_sets) {
        let rest_end = last.rest_until.max(last.ended_at);
        return WorkoutStateSnapshot {
            state: if rest_end > now {
                STATE_RESTING
            } else {
                STATE_YAPPING
            },
            display_set: Some(next),
            rest_until: rest_end,
            effort_prompt,
            lifting_started_at: 0,
        };
    }

    WorkoutStateSnapshot {
        state: STATE_READY,
        display_set: Some(next),
        rest_until: 0,
        effort_prompt,
        lifting_started_at: 0,
    }
}

pub fn get_workout_response_from_active(active: &WorkoutRecord, now: i64) -> GetWorkoutResponse {
    let state_snapshot = Some(workout_state_snapshot(
        &active.workout,
        &active.proposed_sets,
        &active.completed_sets,
        now,
    ));
    let proposed_active = active_proposed_sets(&active.proposed_sets);
    let next_up_set = compute_next_up_set(&proposed_active, &active.completed_sets);
    let summary = Some(crate::progress::compute_workout_summary(
        &active.workout,
        &active.proposed_sets,
        &active.completed_sets,
    ));
    let passed_warmup_ids = active
        .proposed_sets
        .iter()
        .filter(|s| {
            crate::progress::is_passed_warmup(s, &active.proposed_sets, &active.completed_sets)
        })
        .map(|s| s.id.clone())
        .collect();
    GetWorkoutResponse {
        passed_warmup_ids,
        workout: Some(active.workout.clone()),
        proposed_sets: active.proposed_sets.clone(),
        completed_sets: active.completed_sets.clone(),
        next_up_set,
        plan_change_stats: Some(workout_plan_change_stats_from_sets(&active.proposed_sets)),
        state_snapshot,
        user_messages: Vec::new(),
        summary,
    }
}

pub fn start_workout_response_from_active(
    active: &WorkoutRecord,
    now: i64,
) -> StartWorkoutResponse {
    let resp = get_workout_response_from_active(active, now);
    StartWorkoutResponse {
        id: active.workout.id.clone(),
        workout: resp.workout,
        proposed_sets: resp.proposed_sets,
        completed_sets: resp.completed_sets,
        next_up_set: resp.next_up_set,
        state_snapshot: resp.state_snapshot,
        user_messages: Vec::new(),
    }
}

pub fn active_from_get_workout_response(
    resp: GetWorkoutResponse,
) -> Result<WorkoutRecord, WorkoutError> {
    let workout = resp
        .workout
        .ok_or_else(|| WorkoutError::internal("Checkpoint missing workout"))?;
    Ok(WorkoutRecord::new(
        workout,
        resp.proposed_sets,
        resp.completed_sets,
    ))
}

/// Begin a set: the workout is LIFTING it until its Done. Open questions
/// resolve first, as for Done, so a rung's would-be next set exists to be
/// started. Starting a set already being lifted keeps its first start;
/// starting another moves the start; a done, cancelled or unknown set is a
/// no-op.
/// "Skip all warmups": the exercise's undone warmups are marked skipped.
/// Nothing is removed; they stay in the plan, nothing waits on them
/// (`is_passed_warmup`), and doing one later still records it.
pub fn apply_skip_warmups_to_active(
    workout_ref: &mut WorkoutRecord,
    req: &SkipWarmupsRequest,
) -> Result<(), WorkoutError> {
    if workout_ref.workout.id != req.workout_id {
        return Err(WorkoutError::failed_precondition("Workout ID mismatch"));
    }
    let done: std::collections::HashSet<String> = workout_ref
        .completed_sets
        .iter()
        .filter(|c| c.ended_at != 0)
        .map(|c| c.proposed_set_id.clone())
        .collect();
    for set in workout_ref
        .proposed_sets
        .iter_mut()
        .filter(|s| s.exercise == req.exercise && s.warmup && !s.cancelled && !done.contains(&s.id))
    {
        set.skipped = true;
    }
    Ok(())
}

pub fn apply_start_set_to_active(
    workout_ref: &mut WorkoutRecord,
    req: &StartSetRequest,
    now: i64,
) -> Result<(), WorkoutError> {
    if workout_ref.workout.id != req.workout_id {
        return Err(WorkoutError::failed_precondition("Workout ID mismatch"));
    }
    let pending = workout_ref
        .proposed_sets
        .iter()
        .any(|p| p.id == req.proposed_set_id && !p.cancelled)
        && !workout_ref
            .completed_sets
            .iter()
            .any(|c| c.proposed_set_id == req.proposed_set_id);
    if !pending || workout_ref.workout.lifting_set_id == req.proposed_set_id {
        return Ok(());
    }
    workout_ref.workout.lifting_set_id = req.proposed_set_id.clone();
    workout_ref.workout.lifting_started_at = if req.started_at > 0 {
        req.started_at
    } else {
        now
    };
    Ok(())
}

/// Log a set as done. A calibration rung settles there and then: it
/// appends the next rung or the working sets, in [unit]. Any effort on the
/// request is ignored (ratings are retired).
pub fn apply_complete_set_to_active(
    workout_ref: &mut WorkoutRecord,
    req: &CompleteSetRequest,
    unit: AppWeightUnit,
    ids: &mut Ids,
) -> Result<(), WorkoutError> {
    if workout_ref.workout.id != req.workout_id {
        return Err(WorkoutError::failed_precondition("Workout ID mismatch"));
    }
    // Done is idempotent: a set already logged is never logged twice (a
    // re-sent watch intent, a double tap that raced the snapshot).
    if workout_ref
        .completed_sets
        .iter()
        .any(|c| c.proposed_set_id == req.proposed_set_id)
    {
        return Ok(());
    }
    let proposed = match workout_ref
        .proposed_sets
        .iter()
        .find(|p| p.id == req.proposed_set_id && !p.cancelled)
        .cloned()
    {
        Some(p) => p,
        // Set gone (skipped/cancelled, or a stale/duplicate at-least-once intent). No-op
        // rather than erroring — erroring permanently desynced the watch. The next snapshot
        // reconciles the watch to the real state.
        None => return Ok(()),
    };
    let ended_at = req.completed_at;
    let is_final_set_of_exercise = is_final_set_of_exercise_after_completion(
        &req.proposed_set_id,
        &workout_ref.proposed_sets,
        &workout_ref.completed_sets,
    );
    let rest_until =
        ended_at + rest_seconds_after(&proposed, req.actual_reps, is_final_set_of_exercise);
    // The set's start, if it was started; any Done ends the lifting.
    let started_at = if workout_ref.workout.lifting_set_id == req.proposed_set_id {
        workout_ref.workout.lifting_started_at
    } else {
        0
    };
    workout_ref.workout.lifting_set_id.clear();
    workout_ref.workout.lifting_started_at = 0;
    let completed_set_id = ids.new_id();
    workout_ref.completed_sets.push(CompletedSet {
        id: completed_set_id.clone(),
        workout_id: req.workout_id.clone(),
        proposed_set_id: req.proposed_set_id.clone(),
        actual_reps: req.actual_reps,
        actual_weight: req.actual_weight,
        ended_at,
        rest_until,
        effort: Effort::Unspecified as i32,
        started_at,
    });
    // A calibration rung settles the moment it's done (`would_append`).
    if proposed.calibration {
        settle_rung(workout_ref, &completed_set_id, unit);
    }
    Ok(())
}

/// How long to rest after a set: the success rest when the target was
/// hit, the failure rest otherwise, and the short between-exercise rest
/// after an exercise's final set. A calibration rung always rests its
/// own 90 s — the ramp continues after it, so it is never final.
fn rest_seconds_after(proposed: &ProposedSet, actual_reps: i32, is_final: bool) -> i64 {
    if proposed.calibration {
        return proposed.rest_after_success as i64;
    }
    if is_final {
        return END_OF_EXERCISE_REST_SECONDS;
    }
    if actual_reps >= proposed.target_reps {
        proposed.rest_after_success as i64
    } else {
        proposed.rest_after_failure as i64
    }
}

/// Correct a done set after the fact: reps and weight change, and the rest
/// is recomputed from `ended_at` by the same rule Done used (fewer reps
/// than planned switches to the failure rest). An unknown set is a no-op.
pub fn apply_edit_completed_set_to_active(
    workout_ref: &mut WorkoutRecord,
    req: &EditCompletedSetRequest,
    unit: AppWeightUnit,
) -> Result<(), WorkoutError> {
    if workout_ref.workout.id != req.workout_id {
        return Err(WorkoutError::failed_precondition("Workout ID mismatch"));
    }
    if req.actual_reps < 0 {
        return Err(WorkoutError::failed_precondition("Reps out of range"));
    }
    if !(0.0..=2000.0).contains(&req.actual_weight) {
        return Err(WorkoutError::failed_precondition("Weight out of range"));
    }
    let Some(idx) = workout_ref
        .completed_sets
        .iter()
        .position(|c| c.id == req.completed_set_id && c.ended_at != 0)
    else {
        return Ok(());
    };
    let proposed_id = workout_ref.completed_sets[idx].proposed_set_id.clone();
    let Some(proposed) = workout_ref
        .proposed_sets
        .iter()
        .find(|p| p.id == proposed_id)
        .cloned()
    else {
        return Ok(());
    };
    let is_final = is_final_set_of_exercise_after_completion(
        &proposed_id,
        &workout_ref.proposed_sets,
        &workout_ref.completed_sets,
    );
    let rest = rest_seconds_after(&proposed, req.actual_reps, is_final);
    let set = &mut workout_ref.completed_sets[idx];
    set.actual_reps = req.actual_reps;
    set.actual_weight = req.actual_weight;
    set.rest_until = set.ended_at + rest;
    // A rung's reps decide what follows it: settle it again on the new count.
    if proposed.calibration {
        resettle_rung(workout_ref, &req.completed_set_id, unit);
    }
    Ok(())
}

/// A calibration rung, done: append what its reps call for (see
/// `would_append`) straight after it.
fn settle_rung(workout_ref: &mut WorkoutRecord, completed_set_id: &str, unit: AppWeightUnit) {
    let Some(rung) = rung_of(workout_ref, completed_set_id) else {
        return;
    };
    let appended = would_append(
        &workout_ref.proposed_sets,
        &workout_ref.completed_sets,
        &rung,
        completed_set_id,
        unit,
    );
    planning::insert_sets_after(workout_ref, &rung.id, appended);
}

/// A rung's reps were corrected (a rep tapped off after Done): take back
/// what it appended and settle it again. Only while what is pending for
/// the exercise is exactly that append — once one of those sets is done,
/// or the weight was typed, the plan stands.
fn resettle_rung(workout_ref: &mut WorkoutRecord, completed_set_id: &str, unit: AppWeightUnit) {
    let Some(rung) = rung_of(workout_ref, completed_set_id) else {
        return;
    };
    let ours: std::collections::HashSet<String> =
        (0..64).map(|n| derived_id(completed_set_id, n)).collect();
    let done: std::collections::HashSet<&str> = workout_ref
        .completed_sets
        .iter()
        .filter(|c| c.ended_at != 0)
        .map(|c| c.proposed_set_id.as_str())
        .collect();
    let pending: Vec<&ProposedSet> = workout_ref
        .proposed_sets
        .iter()
        .filter(|s| s.exercise == rung.exercise && !s.cancelled && !done.contains(s.id.as_str()))
        .collect();
    if pending.is_empty() || !pending.iter().all(|s| ours.contains(&s.id)) {
        return;
    }
    workout_ref.proposed_sets.retain(|s| !ours.contains(&s.id));
    workout_ref.renumber_sets();
    settle_rung(workout_ref, completed_set_id, unit);
}

/// The calibration rung a done set lifted, if it was one.
fn rung_of(workout_ref: &WorkoutRecord, completed_set_id: &str) -> Option<ProposedSet> {
    let done = workout_ref
        .completed_sets
        .iter()
        .find(|c| c.id == completed_set_id && c.ended_at != 0)?;
    workout_ref
        .proposed_sets
        .iter()
        .find(|s| s.id == done.proposed_set_id && s.calibration && !s.cancelled)
        .cloned()
}

/// The ramp rule, pure: what a done `rung` appends. Every rep → the next
/// rung up (the larger of one step and 10%); a miss, or the sixth rung →
/// the prescription's working sets at 90% of the heaviest rung done in full
/// (this rung's weight when none was). Ids are
/// `uuid5(NAMESPACE_OID, "{completed_set_id}:{n}")`.
pub fn would_append(
    proposed_sets: &[ProposedSet],
    completed_sets: &[CompletedSet],
    rung: &ProposedSet,
    completed_set_id: &str,
    unit: AppWeightUnit,
) -> Vec<ProposedSet> {
    let rungs: Vec<&ProposedSet> = proposed_sets
        .iter()
        .filter(|set| set.exercise == rung.exercise && set.calibration && !set.cancelled)
        .collect();
    let position = rungs.iter().position(|set| set.id == rung.id).unwrap_or(0);
    let done_in_full = |set: &ProposedSet| {
        completed_sets.iter().any(|c| {
            c.proposed_set_id == set.id && c.ended_at != 0 && c.actual_reps >= set.target_reps
        })
    };
    let workout_id = &rung.workout_id;
    let mut appended = if done_in_full(rung) && position + 1 < planning::MAX_CALIBRATION_RUNGS {
        vec![planning::calibration_set(
            workout_id,
            rung.exercise,
            planning::next_calibration_weight(rung.exercise, rung.target_weight, unit),
        )]
    } else {
        let heaviest = rungs
            .iter()
            .filter(|set| done_in_full(set))
            .map(|set| set.target_weight)
            .fold(0.0, f32::max);
        let base = if heaviest > 0.0 {
            heaviest
        } else {
            rung.target_weight
        };
        let weight = Exercise::try_from(rung.exercise)
            .map(|ex| snap_weight_lb(ex, base * planning::CALIBRATION_SETTLE_FRACTION, unit))
            .unwrap_or(base);
        planning::working_sets_after_calibration(workout_id, rung.exercise, weight)
    };
    for (n, set) in appended.iter_mut().enumerate() {
        set.id = derived_id(completed_set_id, n);
    }
    appended
}

pub fn apply_delete_completed_set_to_active(
    workout_ref: &mut WorkoutRecord,
    req: &DeleteCompletedSetRequest,
) -> Result<(), WorkoutError> {
    if workout_ref.workout.id != req.workout_id {
        return Err(WorkoutError::failed_precondition("Workout ID mismatch"));
    }
    workout_ref
        .completed_sets
        .retain(|c| !(c.workout_id == req.workout_id && c.id == req.completed_set_id));
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pb::Workout;
    use uuid::Uuid;

    fn proposed(id: &str, order: i32, warmup: bool) -> ProposedSet {
        ProposedSet {
            id: id.to_string(),
            workout_id: "w1".to_string(),
            workout_order: order,
            exercise: 1,
            target_reps: 5,
            target_weight: 135.0,
            warmup,
            rest_after_success: 180,
            rest_after_failure: 300,
            cancelled: false,
            calibration: false,
            skipped: false,
        }
    }

    fn active_with(sets: Vec<ProposedSet>) -> WorkoutRecord {
        WorkoutRecord::new(
            Workout {
                id: "w1".to_string(),
                name: "Test".to_string(),
                start_time: 1_000,
                end_time: 0,
                session_id: String::new(),
                ..Default::default()
            },
            sets,
            vec![],
        )
    }

    fn complete(active: &mut WorkoutRecord, set_id: &str, reps: i32, at: i64) {
        apply_complete_set_to_active(
            active,
            &CompleteSetRequest {
                workout_id: "w1".to_string(),
                proposed_set_id: set_id.to_string(),
                actual_reps: reps,
                actual_weight: 135.0,
                completed_at: at,
                effort: 0,
            },
            AppWeightUnit::Lb,
            &mut Ids::new(&Uuid::new_v4().to_string()),
        )
        .unwrap();
    }

    fn start(active: &mut WorkoutRecord, set_id: &str, at: i64) {
        apply_start_set_to_active(
            active,
            &StartSetRequest {
                workout_id: "w1".to_string(),
                proposed_set_id: set_id.to_string(),
                started_at: at,
            },
            at,
        )
        .unwrap();
    }

    // ── StartSet ────────────────────────────────────────────────────────────

    #[test]
    fn start_lifts_the_set_until_its_done() {
        let mut active = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
        start(&mut active, "s1", 1_000);
        let snap = snapshot(&active, 1_010);
        assert_eq!(snap.state, STATE_LIFTING);
        assert_eq!(snap.display_set.unwrap().id, "s1");
        assert_eq!(
            snap.lifting_started_at, 1_000,
            "the timer counts up from Start"
        );
        assert_eq!(snap.rest_until, 0);

        complete(&mut active, "s1", 5, 1_040);
        assert_eq!(
            active.completed_sets[0].started_at, 1_000,
            "the done set keeps its start"
        );
        assert!(
            active.workout.lifting_set_id.is_empty() && active.workout.lifting_started_at == 0,
            "Done ends the lifting"
        );
        assert_eq!(snapshot(&active, 1_050).state, STATE_RESTING);
    }

    #[test]
    fn starting_while_resting_is_lifting() {
        let mut active = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
        complete(&mut active, "s1", 5, 1_000);
        assert_eq!(snapshot(&active, 1_010).state, STATE_RESTING);
        start(&mut active, "s2", 1_010);
        let snap = snapshot(&active, 1_020);
        assert_eq!(snap.state, STATE_LIFTING, "Start ends the rest early");
        assert_eq!(snap.display_set.unwrap().id, "s2");
    }

    #[test]
    fn restarting_keeps_the_first_start_and_another_set_moves_it() {
        let mut active = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
        start(&mut active, "s1", 1_000);
        start(&mut active, "s1", 1_005);
        assert_eq!(active.workout.lifting_started_at, 1_000, "a re-sent Start");
        start(&mut active, "s2", 1_010);
        assert_eq!(active.workout.lifting_set_id, "s2");
        assert_eq!(active.workout.lifting_started_at, 1_010);
    }

    #[test]
    fn starting_a_done_or_unknown_set_is_a_no_op() {
        let mut active = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
        complete(&mut active, "s1", 5, 1_000);
        start(&mut active, "s1", 1_010);
        start(&mut active, "nope", 1_010);
        assert!(active.workout.lifting_set_id.is_empty());
        assert_eq!(snapshot(&active, 1_020).state, STATE_RESTING);
    }

    #[test]
    fn a_done_set_never_started_has_no_start() {
        let mut active = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
        complete(&mut active, "s1", 5, 1_000);
        assert_eq!(active.completed_sets[0].started_at, 0);
    }

    // ── CompleteSet ─────────────────────────────────────────────────────────

    #[test]
    fn complete_set_creates_the_done_row() {
        let mut active = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
        complete(&mut active, "s1", 5, 2_040);

        assert_eq!(active.completed_sets.len(), 1);
        let c = &active.completed_sets[0];
        assert_eq!(c.proposed_set_id, "s1");
        assert_eq!(c.ended_at, 2_040);
        assert_eq!(c.actual_reps, 5);
    }

    #[test]
    fn complete_set_rejects_the_wrong_workout() {
        let mut active = active_with(vec![proposed("s1", 0, false)]);
        let err = apply_complete_set_to_active(
            &mut active,
            &CompleteSetRequest {
                workout_id: "other".to_string(),
                proposed_set_id: "s1".to_string(),
                actual_reps: 5,
                actual_weight: 135.0,
                completed_at: 2_000,
                effort: 0,
            },
            AppWeightUnit::Lb,
            &mut Ids::new(&Uuid::new_v4().to_string()),
        );
        assert!(err.is_err());
        assert!(active.completed_sets.is_empty());
    }

    #[test]
    fn rest_depends_on_hitting_the_target() {
        let mut active = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
        complete(&mut active, "s1", 5, 2_000); // hit 5/5 -> success rest
        assert_eq!(active.completed_sets[0].rest_until, 2_000 + 180);

        let mut active = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
        complete(&mut active, "s1", 3, 2_000); // missed -> failure rest
        assert_eq!(active.completed_sets[0].rest_until, 2_000 + 300);
    }

    #[test]
    fn the_last_set_of_an_exercise_gets_the_short_between_exercise_rest() {
        // No point resting three minutes when the next thing is a different
        // exercise — the final set of an exercise rests END_OF_EXERCISE_REST_SECONDS.
        let mut active = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
        complete(&mut active, "s1", 5, 2_000);
        complete(&mut active, "s2", 5, 2_300);

        let last = active
            .completed_sets
            .iter()
            .find(|c| c.proposed_set_id == "s2")
            .unwrap();
        assert_eq!(
            last.rest_until,
            2_300 + END_OF_EXERCISE_REST_SECONDS,
            "the exercise's final set should use the short rest"
        );
    }

    #[test]
    fn completing_a_cancelled_set_is_a_no_op() {
        let mut sets = vec![proposed("s1", 0, true), proposed("s2", 1, false)];
        sets[0].cancelled = true;
        let mut active = active_with(sets);
        complete(&mut active, "s1", 5, 2_000);
        assert!(active.completed_sets.is_empty());
    }

    // ── Any set, any order: warmups are never removed ───────────────────────

    fn snap_at(active: &WorkoutRecord, now: i64) -> WorkoutStateSnapshot {
        workout_state_snapshot(
            &active.workout,
            &active.proposed_sets,
            &active.completed_sets,
            now,
        )
    }

    #[test]
    fn a_working_set_moves_past_its_warmups() {
        let mut active = active_with(vec![
            proposed("w1", 0, true),
            proposed("w2", 1, true),
            proposed("s1", 2, false),
            proposed("s2", 3, false),
        ]);
        complete(&mut active, "w1", 5, 2_000);
        complete(&mut active, "s1", 5, 2_100);
        let snap = snap_at(&active, 2_150);
        assert_eq!(
            snap.display_set.unwrap().id,
            "s2",
            "the warmup left behind is not up next"
        );
        complete(&mut active, "s2", 5, 2_300);
        assert_eq!(
            snap_at(&active, 2_400).state,
            STATE_ALL_DONE,
            "an undone warmup doesn't hold the workout open"
        );
        assert!(
            !active.proposed_sets.iter().any(|p| p.cancelled),
            "nothing is removed"
        );
    }

    #[test]
    fn the_last_working_set_rests_short_with_warmups_undone() {
        let mut active = active_with(vec![proposed("w1", 0, true), proposed("s1", 1, false)]);
        complete(&mut active, "s1", 5, 2_000);
        assert_eq!(
            active.completed_sets[0].rest_until,
            2_000 + END_OF_EXERCISE_REST_SECONDS,
            "the exercise is finished: its warmup was moved past"
        );
    }

    #[test]
    fn skipping_warmups_marks_them_and_moves_past() {
        let mut active = active_with(vec![
            proposed("w1", 0, true),
            proposed("w2", 1, true),
            proposed("s1", 2, false),
        ]);
        complete(&mut active, "w1", 5, 2_000);
        apply_skip_warmups_to_active(
            &mut active,
            &SkipWarmupsRequest {
                workout_id: "w1".to_string(),
                exercise: 1,
            },
        )
        .unwrap();
        let by_id = |id: &str| active.proposed_sets.iter().find(|p| p.id == id).unwrap();
        assert!(!by_id("w1").skipped, "a done warmup isn't skipped");
        assert!(by_id("w2").skipped);
        assert!(!by_id("w2").cancelled, "nothing is removed");
        assert_eq!(
            snap_at(&active, 2_050).display_set.unwrap().id,
            "s1",
            "up next is the working set"
        );

        // A skipped warmup can still be done; it records like any set.
        complete(&mut active, "w2", 5, 2_100);
        assert!(active
            .completed_sets
            .iter()
            .any(|c| c.proposed_set_id == "w2"));
    }

    #[test]
    fn up_next_is_the_first_open_set_in_order() {
        let mut sets = vec![
            proposed("a1", 0, false),
            proposed("a2", 1, false),
            proposed("b1", 2, false),
            proposed("b2", 3, false),
        ];
        for s in &mut sets[2..] {
            s.exercise = 2;
        }
        let mut active = active_with(sets);
        complete(&mut active, "b1", 5, 2_000);
        assert_eq!(
            snap_at(&active, 2_050).display_set.unwrap().id,
            "a1",
            "a set done out of order doesn't move up next off the top"
        );
    }

    // ── DeleteCompletedSet ──────────────────────────────

    #[test]
    fn deleting_a_completed_set_returns_it_to_pending() {
        let mut active = active_with(vec![proposed("s1", 0, false)]);
        complete(&mut active, "s1", 5, 2_000);
        let completed_id = active.completed_sets[0].id.clone();

        apply_delete_completed_set_to_active(
            &mut active,
            &DeleteCompletedSetRequest {
                workout_id: "w1".to_string(),
                completed_set_id: completed_id,
            },
        )
        .unwrap();

        assert!(active.completed_sets.is_empty());
        let snap = workout_state_snapshot(
            &active.workout,
            &active.proposed_sets,
            &active.completed_sets,
            3_000,
        );
        assert_eq!(snap.state, STATE_READY, "the set should be up again");
        assert_eq!(snap.display_set.unwrap().id, "s1");
    }

    // ── Snapshot state machine ──────────────────────────────────────────────

    #[test]
    fn resting_snapshot_focuses_the_next_set_not_the_finished_one() {
        // Two sets in one group. Finish the first; while resting, the snapshot
        // must point display_set at the SECOND set — that's the set every UI's
        // Done button acts on. Pointing it back at the finished set logs it
        // in an infinite loop (dev regression: a warmup completed 6× in 40s and
        // the workout never advanced past set 0).
        let mut active = active_with(vec![proposed("s1", 0, true), proposed("s2", 1, false)]);
        complete(&mut active, "s1", 5, 2_000);
        let snap = workout_state_snapshot(
            &active.workout,
            &active.proposed_sets,
            &active.completed_sets,
            2_050,
        );
        assert_eq!(snap.state, STATE_RESTING);
        assert_eq!(
            snap.display_set.unwrap().id,
            "s2",
            "resting must focus the upcoming set, not the one just finished"
        );
    }

    #[test]
    fn snapshot_walks_ready_resting_done() {
        // Two sets so RESTING is genuinely reachable (rest happens *before* the
        // next set). A single-set workout would jump straight to ALL_DONE after
        // the last set — there is nothing to rest for.
        let mut active = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);

        let snap = workout_state_snapshot(
            &active.workout,
            &active.proposed_sets,
            &active.completed_sets,
            1_000,
        );
        assert_eq!(snap.state, STATE_READY);
        assert_eq!(snap.display_set.unwrap().id, "s1");

        // Finish set 1: resting before set 2, focused on set 2.
        complete(&mut active, "s1", 5, 2_040);
        let snap = workout_state_snapshot(
            &active.workout,
            &active.proposed_sets,
            &active.completed_sets,
            2_050,
        );
        assert_eq!(snap.state, STATE_RESTING);
        assert_eq!(snap.display_set.unwrap().id, "s2");
        assert_eq!(snap.rest_until, 2_040 + 180);

        // Rest expires: yapping until set 2 is done, counting up from the rest end.
        let snap = workout_state_snapshot(
            &active.workout,
            &active.proposed_sets,
            &active.completed_sets,
            9_000,
        );
        assert_eq!(snap.state, STATE_YAPPING);
        assert_eq!(snap.display_set.unwrap().id, "s2");
        assert_eq!(
            snap.rest_until,
            2_040 + 180,
            "yapping carries the rest end so its count-up survives a reload"
        );

        // Finish the final set: done immediately, no lingering rest state that
        // could re-offer the just-finished set (dev regression: the last set was
        // logged 10× because rest fell back to it).
        complete(&mut active, "s2", 5, 9_140);
        let snap = workout_state_snapshot(
            &active.workout,
            &active.proposed_sets,
            &active.completed_sets,
            9_150,
        );
        assert_eq!(
            snap.state, STATE_ALL_DONE,
            "after the final set there is nothing to rest for"
        );
        assert!(snap.display_set.is_none());
    }

    #[test]
    fn cancelled_sets_do_not_hold_the_workout_open() {
        let mut sets = vec![proposed("s1", 0, true), proposed("s2", 1, false)];
        sets[0].cancelled = true;
        let mut active = active_with(sets);
        complete(&mut active, "s2", 5, 2_000);

        let snap = workout_state_snapshot(
            &active.workout,
            &active.proposed_sets,
            &active.completed_sets,
            9_000,
        );
        assert_eq!(
            snap.state, STATE_ALL_DONE,
            "a cancelled warmup must not keep the workout in READY"
        );
    }

    // ── Plan change stats ───────────────────────────────────────────────────

    #[test]
    fn plan_change_stats_count_cancellations_by_kind() {
        let mut sets = vec![
            proposed("w-1", 0, true),
            proposed("w-2", 1, true),
            proposed("s-1", 2, false),
        ];
        sets[0].cancelled = true;
        sets[2].cancelled = true;
        let stats = workout_plan_change_stats_from_sets(&sets);
        assert_eq!(stats.cancelled_total, 2);
        assert_eq!(stats.cancelled_warmups, 1);
        assert_eq!(stats.cancelled_working, 1);
    }

    // ── Exceptions: edit a done set ──────────────────────────────────────

    fn done_id(active: &WorkoutRecord, proposed_id: &str) -> String {
        active
            .completed_sets
            .iter()
            .find(|c| c.proposed_set_id == proposed_id)
            .unwrap()
            .id
            .clone()
    }

    fn edit(active: &mut WorkoutRecord, completed_id: &str, reps: i32, weight: f32) {
        apply_edit_completed_set_to_active(
            active,
            &EditCompletedSetRequest {
                workout_id: "w1".to_string(),
                completed_set_id: completed_id.to_string(),
                actual_reps: reps,
                actual_weight: weight,
            },
            AppWeightUnit::Lb,
        )
        .unwrap();
    }

    fn snapshot(active: &WorkoutRecord, now: i64) -> WorkoutStateSnapshot {
        workout_state_snapshot(
            &active.workout,
            &active.proposed_sets,
            &active.completed_sets,
            now,
        )
    }

    #[test]
    fn editing_a_done_set_recomputes_its_rest_from_when_it_ended() {
        let mut active = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
        complete(&mut active, "s1", 5, 2_000);
        let id = done_id(&active, "s1");
        assert_eq!(
            active.completed_sets[0].rest_until, 2_180,
            "hit: success rest"
        );

        // Fewer reps than planned: the rest switches to the failure rest,
        // still anchored at ended_at. Weight changes land too.
        edit(&mut active, &id, 3, 125.0);
        let c = &active.completed_sets[0];
        assert_eq!((c.actual_reps, c.actual_weight), (3, 125.0));
        assert_eq!(c.rest_until, 2_300);

        // Back to target: back to the success rest.
        edit(&mut active, &id, 5, 125.0);
        assert_eq!(active.completed_sets[0].rest_until, 2_180);

        // The exercise's final set keeps the short between-exercise rest.
        complete(&mut active, "s2", 5, 2_400);
        let last = done_id(&active, "s2");
        edit(&mut active, &last, 2, 135.0);
        let c = active.completed_sets.iter().find(|c| c.id == last).unwrap();
        assert_eq!(c.rest_until, 2_400 + END_OF_EXERCISE_REST_SECONDS);
    }

    #[test]
    fn editing_an_unknown_set_is_a_no_op() {
        let mut active = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
        complete(&mut active, "s1", 5, 2_000);
        let before = active.completed_sets.clone();
        edit(&mut active, "nope", 1, 1.0);
        assert_eq!(active.completed_sets, before);
    }

    // ── Calibration ramp ────────────────────────────────────────────────────

    /// A squat rung at `weight` followed by another exercise's set, so the
    /// splice point is observable.
    fn ramp_workout(weight: f32) -> WorkoutRecord {
        let mut rung = proposed("c1", 0, false);
        rung.calibration = true;
        rung.target_reps = 5;
        rung.target_weight = weight;
        rung.rest_after_success = 90;
        rung.rest_after_failure = 90;
        let mut other = proposed("b1", 1, false);
        other.exercise = 2;
        active_with(vec![rung, other])
    }

    fn squat_sets(active: &WorkoutRecord) -> Vec<&ProposedSet> {
        active
            .proposed_sets
            .iter()
            .filter(|s| s.exercise == 1)
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
            &mut Ids::new(&Uuid::new_v4().to_string()),
        )
        .unwrap();
    }

    fn uuid5(base: &str, n: usize) -> String {
        Uuid::new_v5(&Uuid::NAMESPACE_OID, format!("{base}:{n}").as_bytes()).to_string()
    }

    /// The squat sets after the first, as (weight, calibration).
    fn squat_plan(active: &WorkoutRecord) -> Vec<(f32, bool)> {
        squat_sets(active)
            .iter()
            .skip(1)
            .map(|s| (s.target_weight, s.calibration))
            .collect()
    }

    #[test]
    fn a_full_rung_climbs_ahead_of_the_next_exercise() {
        let mut active = ramp_workout(45.0);
        complete(&mut active, "c1", 5, 2_000);
        let done = done_id(&active, "c1");
        let next = &active.proposed_sets[1];
        assert!(next.calibration, "another rung");
        assert_eq!(next.target_weight, 50.0, "one bar step beats 10% at 45");
        assert_eq!(next.id, uuid5(&done, 0), "derived from the done set");
        assert_eq!(
            active.proposed_sets[2].id, "b1",
            "spliced in ahead of bench"
        );
        assert_eq!(
            active.completed_sets[0].rest_until, 2_090,
            "a rung rests its own 90 s"
        );
    }

    #[test]
    fn a_big_rung_climbs_ten_percent() {
        let mut active = ramp_workout(200.0);
        complete(&mut active, "c1", 5, 2_000);
        assert_eq!(active.proposed_sets[1].target_weight, 220.0);
    }

    /// A miss ends the ramp: the working sets at 90% of the heaviest rung
    /// done in full.
    #[test]
    fn a_miss_settles_at_ninety_percent_of_the_heaviest_full_rung() {
        let mut active = ramp_workout(100.0);
        complete(&mut active, "c1", 5, 2_000);
        let rung2 = active.proposed_sets[1].id.clone();
        assert_eq!(active.proposed_sets[1].target_weight, 110.0);
        complete(&mut active, &rung2, 4, 2_200);
        let done2 = done_id(&active, &rung2);
        let working: Vec<&ProposedSet> = squat_sets(&active)
            .into_iter()
            .filter(|s| !s.calibration)
            .collect();
        assert_eq!(working.len(), 5, "the full 5×5");
        for (n, set) in working.iter().enumerate() {
            assert_eq!(set.target_weight, 90.0, "90% of the 100 done in full");
            assert_eq!(set.target_reps, 5);
            assert_eq!(set.id, uuid5(&done2, n));
            assert_eq!((set.rest_after_success, set.rest_after_failure), (180, 240));
        }
        assert_eq!(active.proposed_sets.last().unwrap().id, "b1");
    }

    #[test]
    fn a_first_rung_missed_settles_under_it() {
        let mut active = ramp_workout(100.0);
        complete(&mut active, "c1", 3, 2_000);
        assert_eq!(squat_plan(&active), vec![(90.0, false); 5]);
    }

    #[test]
    fn the_sixth_rung_settles_whatever_it_did() {
        let mut active = ramp_workout(100.0);
        let mut at = 2_000;
        for _ in 0..planning::MAX_CALIBRATION_RUNGS {
            let rung = squat_sets(&active)
                .into_iter()
                .find(|s| {
                    s.calibration
                        && !active
                            .completed_sets
                            .iter()
                            .any(|c| c.proposed_set_id == s.id)
                })
                .unwrap()
                .clone();
            complete(&mut active, &rung.id, 5, at);
            at += 200;
        }
        let rungs: Vec<f32> = squat_sets(&active)
            .iter()
            .filter(|s| s.calibration)
            .map(|s| s.target_weight)
            .collect();
        assert_eq!(rungs.len(), planning::MAX_CALIBRATION_RUNGS);
        let top = *rungs.last().unwrap();
        let working: Vec<f32> = squat_sets(&active)
            .iter()
            .filter(|s| !s.calibration)
            .map(|s| s.target_weight)
            .collect();
        assert_eq!(working.len(), 5);
        assert!(working.iter().all(|w| (*w - top * 0.9).abs() <= 5.0));
    }

    /// Tapping a rep off a rung after Done (the way a miss is recorded)
    /// settles it again — while nothing after it has been lifted.
    #[test]
    fn tapping_a_rep_off_a_rung_resettles_it() {
        let mut active = ramp_workout(100.0);
        complete(&mut active, "c1", 5, 2_000);
        assert_eq!(squat_plan(&active), vec![(110.0, true)]);
        let done = done_id(&active, "c1");
        edit(&mut active, &done, 4, 100.0);
        assert_eq!(squat_plan(&active), vec![(90.0, false); 5]);
        edit(&mut active, &done, 5, 100.0);
        assert_eq!(squat_plan(&active), vec![(110.0, true)], "and back");
    }

    #[test]
    fn a_rung_stands_once_a_set_after_it_is_lifted() {
        let mut active = ramp_workout(100.0);
        complete(&mut active, "c1", 5, 2_000);
        let rung2 = active.proposed_sets[1].id.clone();
        complete(&mut active, &rung2, 5, 2_200);
        let plan = squat_plan(&active);
        let done = done_id(&active, "c1");
        edit(&mut active, &done, 4, 100.0);
        assert_eq!(squat_plan(&active), plan);
    }

    #[test]
    fn typing_a_weight_mid_ramp_replaces_the_rung_with_the_full_working_sets() {
        let mut active = ramp_workout(45.0);
        complete(&mut active, "c1", 5, 2_000);
        let pending_rung = active.proposed_sets[1].id.clone();
        assert!(active.proposed_sets[1].calibration);

        adjust(&mut active, 1, 102.0);
        let squat = squat_sets(&active);
        assert!(
            squat.iter().all(|s| s.id != pending_rung),
            "the pending rung is gone"
        );
        let working: Vec<&&ProposedSet> = squat.iter().filter(|s| !s.calibration).collect();
        assert_eq!(working.len(), 5, "the prescription's 5×5");
        for (n, set) in working.iter().enumerate() {
            assert_eq!(set.id, uuid5(&pending_rung, n), "pinned id for n = {n}");
            assert_eq!(set.target_weight, 100.0, "102 snapped loadable");
            assert_eq!(set.target_reps, 5);
            assert!(!set.warmup);
        }
        assert_eq!(
            active.proposed_sets[1].id, working[0].id,
            "where the rung was"
        );
        assert_eq!(
            active.proposed_sets.last().unwrap().id,
            "b1",
            "other exercises stay behind"
        );
        assert!(active
            .proposed_sets
            .iter()
            .enumerate()
            .all(|(i, s)| s.workout_order == i as i32));
    }

    #[test]
    fn adjusting_without_a_pending_rung_is_unchanged() {
        let mut active = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
        complete(&mut active, "s1", 5, 2_000);
        adjust(&mut active, 1, 102.0);
        let ids: Vec<&str> = active.proposed_sets.iter().map(|s| s.id.as_str()).collect();
        assert_eq!(ids, vec!["s1", "s2"], "no sets added or removed");
        assert_eq!(
            active.proposed_sets[0].target_weight, 135.0,
            "done set untouched"
        );
        assert_eq!(
            active.proposed_sets[1].target_weight, 102.0,
            "moved in place, as before"
        );
    }

    #[test]
    fn done_twice_on_the_same_set_is_a_no_op() {
        let mut active = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
        complete(&mut active, "s1", 5, 2_000);
        let before = active.completed_sets.clone();
        complete(&mut active, "s1", 3, 2_050);
        assert_eq!(active.completed_sets, before, "one row, untouched");
    }
}
