use super::*;
use crate::ids::{derived_id, Ids};
use crate::pb::{
    EditCompletedSetRequest, Effort, EffortPrompt, RateExerciseRequest, SkipWarmupsRequest,
    StartSetRequest, Workout,
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

/// Whether "how was that" is asked about this done set: every working
/// set and every calibration rung, never a warmup.
pub fn is_prompt_worthy(done: &CompletedSet, proposed_sets: &[ProposedSet]) -> bool {
    proposed_sets
        .iter()
        .find(|set| set.id == done.proposed_set_id && !set.cancelled)
        .is_some_and(|set| set.calibration || !set.warmup)
}

/// The question on screen: the latest done set, while it is
/// prompt-worthy, whatever the rest state, carrying its current answer
/// (unspecified until one is given). A newer Done replaces it.
pub fn effort_prompt_from_state(
    proposed_sets: &[ProposedSet],
    completed_sets: &[CompletedSet],
) -> Option<EffortPrompt> {
    let last = last_done_set(completed_sets)?;
    if !is_prompt_worthy(last, proposed_sets) {
        return None;
    }
    let proposed = proposed_sets
        .iter()
        .find(|set| set.id == last.proposed_set_id)?;
    Some(EffortPrompt {
        exercise: proposed.exercise,
        completed_set_id: last.id.clone(),
        calibration: proposed.calibration,
        effort: last.effort,
    })
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
    // Includes the would-be `{done_id}:0` of an unanswered rung, so the
    // state below is RESTING/READY by that rung's rest, never ALL_DONE.
    let next_up_set = compute_next_up_set(&proposed_active, completed_sets);
    // The question outlives the state: a calibration rung can be the last
    // set in the plan (ALL_DONE) and its answer is what appends the rest.
    let effort_prompt = effort_prompt_from_state(proposed_sets, completed_sets);

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
    GetWorkoutResponse {
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
    resolve_unanswered(workout_ref, true);
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

/// Log a set as done. A rating given with the Done answers "how was that"
/// for it there and then, exactly as `RateExercise` would (on a calibration
/// rung that appends the next rung or the working sets, in [unit]).
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
    // Every question still open is answered "right" first — on a rung that
    // appends the working sets (or the next rung) now, so a Done tapped on
    // the deterministic `{done_id}:0` the app already shows finds its set.
    resolve_unanswered(workout_ref, true);
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
    // A rung short of its target has answered for itself: too heavy.
    let effort = if missed_rung(&proposed, req.actual_reps) {
        Effort::Hard as i32
    } else {
        req.effort
    };
    if effort != Effort::Unspecified as i32 {
        apply_rate_exercise_to_active(
            workout_ref,
            &RateExerciseRequest {
                workout_id: req.workout_id.clone(),
                completed_set_id,
                effort,
            },
            unit,
        )?;
    }
    Ok(())
}

/// A finding-weight rung done short of its target: the miss is the answer
/// to "how many more could you have done" — none, hard, settle back.
fn missed_rung(proposed: &ProposedSet, actual_reps: i32) -> bool {
    proposed.calibration && actual_reps < proposed.target_reps
}

/// How long to rest after a set: the success rest when the target was
/// hit, the failure rest otherwise, and the short between-exercise rest
/// after an exercise's final set. A calibration rung always rests its
/// own 90 s — the ramp continues after the answer, so it is never final.
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
    // Tapped down below a rung's target: the miss answers it, hard (a no-op
    // once a later set is done — only the latest can be re-rated).
    if missed_rung(&proposed, req.actual_reps) {
        apply_rate_exercise_to_active(
            workout_ref,
            &RateExerciseRequest {
                workout_id: req.workout_id.clone(),
                completed_set_id: req.completed_set_id.clone(),
                effort: Effort::Hard as i32,
            },
            unit,
        )?;
    }
    Ok(())
}

/// Answer "how was that" for the latest done set — or change the answer,
/// until the next Done. Any other set is a no-op (a late watch intent, a
/// warmup). On a calibration rung a changed answer takes back what the old
/// one appended (pending sets with ids derived from this done set) and
/// appends for the new one; when the plan no longer holds exactly that
/// append (the weight was typed, the exercise removed) only the answer
/// changes.
pub fn apply_rate_exercise_to_active(
    workout_ref: &mut WorkoutRecord,
    req: &RateExerciseRequest,
    unit: AppWeightUnit,
) -> Result<(), WorkoutError> {
    if workout_ref.workout.id != req.workout_id {
        return Err(WorkoutError::failed_precondition("Workout ID mismatch"));
    }
    let effort = Effort::try_from(req.effort).unwrap_or(Effort::Unspecified);
    if effort == Effort::Unspecified || workout_ref.workout.end_time > 0 {
        return Ok(());
    }
    let Some(last) = last_done_set(&workout_ref.completed_sets) else {
        return Ok(());
    };
    if last.id != req.completed_set_id || !is_prompt_worthy(last, &workout_ref.proposed_sets) {
        return Ok(());
    }
    let old = last.effort();
    if old == effort {
        return Ok(());
    }
    let completed_set_id = last.id.clone();
    let rung = workout_ref
        .proposed_sets
        .iter()
        .find(|set| set.id == last.proposed_set_id && set.calibration)
        .cloned();
    let Some(rung) = rung else {
        set_effort(workout_ref, &completed_set_id, effort);
        return Ok(());
    };
    if old == Effort::Unspecified {
        answer(workout_ref, &completed_set_id, effort, unit, true);
        return Ok(());
    }
    // Take back the old answer's append only if it is exactly what is
    // pending for this exercise.
    let previous: std::collections::HashSet<String> =
        ramp_append(workout_ref, &rung, &completed_set_id, old, unit)
            .into_iter()
            .map(|set| set.id)
            .collect();
    let pending: std::collections::HashSet<String> = workout_ref
        .proposed_sets
        .iter()
        .filter(|set| {
            set.exercise == rung.exercise
                && !set.cancelled
                && !workout_ref
                    .completed_sets
                    .iter()
                    .any(|c| c.proposed_set_id == set.id && c.ended_at != 0)
        })
        .map(|set| set.id.clone())
        .collect();
    if previous != pending {
        set_effort(workout_ref, &completed_set_id, effort);
        return Ok(());
    }
    workout_ref
        .proposed_sets
        .retain(|set| !previous.contains(&set.id));
    workout_ref.renumber_sets();
    answer(workout_ref, &completed_set_id, effort, unit, true);
    Ok(())
}

/// Close every unanswered done calibration rung of `exercise` as right,
/// without extending the ramp — the user typed their weight instead.
pub(super) fn close_open_rungs(workout_ref: &mut WorkoutRecord, exercise: i32) {
    let open: Vec<String> = workout_ref
        .completed_sets
        .iter()
        .filter(|c| c.ended_at != 0 && c.effort() == Effort::Unspecified)
        .filter(|c| {
            workout_ref
                .proposed_sets
                .iter()
                .any(|p| p.id == c.proposed_set_id && p.exercise == exercise && p.calibration)
        })
        .map(|c| c.id.clone())
        .collect();
    for id in open {
        set_effort(workout_ref, &id, Effort::Right);
    }
}

/// No question survives the end of a workout: everything still open is
/// answered "right" before progression reads the efforts. A rung closed
/// here appends nothing — pending rows on a finished workout are wrong.
pub fn resolve_all_effort(workout_ref: &mut WorkoutRecord) {
    resolve_unanswered(workout_ref, false);
}

/// Answer "right" for every prompt-worthy done set still unanswered,
/// oldest first. With `extend_ramp` a closed rung appends as a "right"
/// answer would (CompleteSet); without it nothing is appended (EndWorkout).
/// Nothing else resolves — not the clock, not other mutations.
fn resolve_unanswered(workout_ref: &mut WorkoutRecord, extend_ramp: bool) {
    loop {
        let open = workout_ref
            .completed_sets
            .iter()
            .filter(|set| {
                set.ended_at != 0
                    && set.effort() == Effort::Unspecified
                    && is_prompt_worthy(set, &workout_ref.proposed_sets)
            })
            .min_by_key(|set| set.ended_at)
            .map(|set| set.id.clone());
        let Some(id) = open else {
            return;
        };
        // "Right" never snaps a weight, so the unit is immaterial here.
        answer(
            workout_ref,
            &id,
            Effort::Right,
            AppWeightUnit::Lb,
            extend_ramp,
        );
    }
}

fn set_effort(workout_ref: &mut WorkoutRecord, completed_set_id: &str, effort: Effort) {
    if let Some(set) = workout_ref
        .completed_sets
        .iter_mut()
        .find(|set| set.id == completed_set_id)
    {
        set.effort = effort as i32;
    }
}

/// Store an answer and, with `extend_ramp`, on a calibration rung append
/// what the answer calls for (see `ramp_append`) straight after the rung.
fn answer(
    workout_ref: &mut WorkoutRecord,
    completed_set_id: &str,
    effort: Effort,
    unit: AppWeightUnit,
    extend_ramp: bool,
) {
    set_effort(workout_ref, completed_set_id, effort);
    if !extend_ramp {
        return;
    }
    let Some(proposed_id) = workout_ref
        .completed_sets
        .iter()
        .find(|set| set.id == completed_set_id)
        .map(|set| set.proposed_set_id.clone())
    else {
        return;
    };
    let Some(rung) = workout_ref
        .proposed_sets
        .iter()
        .find(|set| set.id == proposed_id && set.calibration)
        .cloned()
    else {
        return;
    };
    let appended = ramp_append(workout_ref, &rung, completed_set_id, effort, unit);
    planning::insert_sets_after(workout_ref, &rung.id, appended);
}

/// What an answer on a calibration rung appends, with its ids — the plan
/// in `workout_ref` is not touched (see `would_append`).
fn ramp_append(
    workout_ref: &WorkoutRecord,
    rung: &ProposedSet,
    completed_set_id: &str,
    effort: Effort,
    unit: AppWeightUnit,
) -> Vec<ProposedSet> {
    would_append(
        &workout_ref.proposed_sets,
        rung,
        completed_set_id,
        effort,
        unit,
    )
}

/// The ramp rule, pure: what answering `effort` on `rung` (done as
/// `completed_set_id`) would append. Easy climbs a rung, right settles
/// here, hard settles one rung down (the opener if this was the first);
/// the sixth rung settles whatever the answer. Ids are
/// `uuid5(NAMESPACE_OID, "{completed_set_id}:{n}")`, shared with the app.
pub fn would_append(
    proposed_sets: &[ProposedSet],
    rung: &ProposedSet,
    completed_set_id: &str,
    effort: Effort,
    unit: AppWeightUnit,
) -> Vec<ProposedSet> {
    let rungs: Vec<&ProposedSet> = proposed_sets
        .iter()
        .filter(|set| set.exercise == rung.exercise && set.calibration && !set.cancelled)
        .collect();
    let position = rungs.iter().position(|set| set.id == rung.id).unwrap_or(0);
    let effort = if position + 1 >= planning::MAX_CALIBRATION_RUNGS {
        Effort::Right
    } else {
        effort
    };
    let workout_id = &rung.workout_id;
    let mut appended = match effort {
        Effort::Easy => vec![planning::calibration_set(
            workout_id,
            rung.exercise,
            planning::next_calibration_weight(rung.exercise, rung.target_weight, unit),
        )],
        Effort::Hard => {
            let previous = if position == 0 {
                rung.target_weight
            } else {
                rungs[position - 1].target_weight
            };
            planning::working_sets_after_calibration(workout_id, rung.exercise, previous)
        }
        _ => {
            planning::working_sets_after_calibration(workout_id, rung.exercise, rung.target_weight)
        }
    };
    for (n, set) in appended.iter_mut().enumerate() {
        set.id = derived_id(completed_set_id, n);
    }
    appended
}

/// The set an unanswered calibration rung is waiting on: the first set
/// "right" would append. `compute_next_up_set` puts it ahead of every
/// other pending set, and the workout is not done while it exists.
pub fn awaiting_ramp_set(
    proposed_sets: &[ProposedSet],
    completed_sets: &[CompletedSet],
) -> Option<ProposedSet> {
    let last = last_done_set(completed_sets)?;
    if last.effort() != Effort::Unspecified {
        return None;
    }
    let rung = proposed_sets
        .iter()
        .find(|set| set.id == last.proposed_set_id && set.calibration && !set.cancelled)?;
    // "Right" never snaps a weight, so the unit is immaterial here.
    would_append(
        proposed_sets,
        rung,
        &last.id,
        Effort::Right,
        AppWeightUnit::Lb,
    )
    .into_iter()
    .next()
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

    #[test]
    fn a_rating_given_with_done_answers_for_the_set() {
        let mut active = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
        start(&mut active, "s1", 1_000);
        apply_complete_set_to_active(
            &mut active,
            &CompleteSetRequest {
                workout_id: "w1".to_string(),
                proposed_set_id: "s1".to_string(),
                actual_reps: 5,
                actual_weight: 135.0,
                completed_at: 1_040,
                effort: Effort::Hard as i32,
            },
            AppWeightUnit::Lb,
            &mut Ids::new(&Uuid::new_v4().to_string()),
        )
        .unwrap();
        assert_eq!(active.completed_sets[0].effort, Effort::Hard as i32);
        let prompt = snapshot(&active, 1_050)
            .effort_prompt
            .expect("still the latest set");
        assert_eq!(prompt.effort, Effort::Hard as i32, "already answered");
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

    /// Answer for the done set that completed `proposed_id`.
    fn rate(active: &mut WorkoutRecord, proposed_id: &str, effort: Effort) {
        let id = done_id(active, proposed_id);
        rate_id(active, &id, effort);
    }

    fn rate_id(active: &mut WorkoutRecord, completed_id: &str, effort: Effort) {
        apply_rate_exercise_to_active(
            active,
            &RateExerciseRequest {
                workout_id: "w1".to_string(),
                completed_set_id: completed_id.to_string(),
                effort: effort as i32,
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

    // ── Effort: the prompt, the answer, the resolution ──────────────────────

    #[test]
    fn every_working_set_asks_and_warmups_never_do() {
        let mut active = active_with(vec![
            proposed("w0", 0, true),
            proposed("s1", 1, false),
            proposed("s2", 2, false),
        ]);
        complete(&mut active, "w0", 5, 1_000);
        assert!(
            snapshot(&active, 1_010).effort_prompt.is_none(),
            "warmups never ask"
        );

        complete(&mut active, "s1", 5, 2_000);
        let snap = snapshot(&active, 2_010);
        assert_eq!(snap.state, STATE_RESTING);
        let prompt = snap
            .effort_prompt
            .expect("a non-final working set asks too");
        assert_eq!(prompt.completed_set_id, done_id(&active, "s1"));
        assert_eq!(prompt.effort, Effort::Unspecified as i32);
        assert!(!prompt.calibration);

        // Still asking once rest is over: rest ending resolves nothing.
        let snap = snapshot(&active, 9_000);
        assert_eq!(snap.state, STATE_YAPPING);
        assert!(snap.effort_prompt.is_some());
        assert_eq!(active.completed_sets[1].effort(), Effort::Unspecified);
    }

    #[test]
    fn the_prompt_carries_the_answer_and_a_newer_done_replaces_it() {
        let mut active = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
        complete(&mut active, "s1", 5, 2_000);
        rate(&mut active, "s1", Effort::Hard);
        let prompt = snapshot(&active, 2_010).effort_prompt.unwrap();
        assert_eq!(
            prompt.effort,
            Effort::Hard as i32,
            "the chip shows the answer"
        );

        complete(&mut active, "s2", 5, 3_000);
        let prompt = snapshot(&active, 3_010).effort_prompt.unwrap();
        assert_eq!(prompt.completed_set_id, done_id(&active, "s2"));
        assert_eq!(prompt.effort, Effort::Unspecified as i32);
        assert_eq!(
            active.completed_sets[0].effort(),
            Effort::Hard,
            "answers stay put"
        );
    }

    #[test]
    fn the_latest_set_can_be_re_rated_until_the_next_done() {
        let mut active = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
        complete(&mut active, "s1", 5, 2_000);
        rate(&mut active, "s1", Effort::Hard);
        rate(&mut active, "s1", Effort::Easy);
        assert_eq!(
            active.completed_sets[0].effort(),
            Effort::Easy,
            "changed answer"
        );

        complete(&mut active, "s2", 5, 3_000);
        rate(&mut active, "s1", Effort::Hard);
        assert_eq!(
            active.completed_sets[0].effort(),
            Effort::Easy,
            "no longer the latest"
        );
    }

    #[test]
    fn rating_anything_but_the_latest_prompt_worthy_set_is_a_no_op() {
        let mut active = active_with(vec![
            proposed("w0", 0, true),
            proposed("s1", 1, false),
            proposed("s2", 2, false),
        ]);
        complete(&mut active, "w0", 5, 1_000);
        let before = active.clone();
        rate(&mut active, "w0", Effort::Easy);
        assert_eq!(
            active.completed_sets, before.completed_sets,
            "a warmup never asks"
        );
        rate_id(&mut active, "nope", Effort::Easy);
        assert_eq!(active.completed_sets, before.completed_sets);
        assert_eq!(active.proposed_sets, before.proposed_sets);
    }

    #[test]
    fn done_answers_every_open_question_as_right() {
        let mut active = active_with(vec![
            proposed("w0", 0, true),
            proposed("s1", 1, false),
            proposed("s2", 2, false),
        ]);
        complete(&mut active, "w0", 5, 1_000);
        complete(&mut active, "s1", 5, 2_000);
        complete(&mut active, "s2", 5, 3_000);
        assert_eq!(
            active.completed_sets[0].effort(),
            Effort::Unspecified,
            "warmup"
        );
        assert_eq!(
            active.completed_sets[1].effort(),
            Effort::Right,
            "closed by the next Done"
        );
        assert_eq!(
            active.completed_sets[2].effort(),
            Effort::Unspecified,
            "still open"
        );
    }

    #[test]
    fn end_of_workout_closes_every_open_question() {
        let mut active = active_with(vec![proposed("s1", 0, false)]);
        complete(&mut active, "s1", 5, 2_000);
        resolve_all_effort(&mut active);
        assert_eq!(active.completed_sets[0].effort(), Effort::Right);
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

    #[test]
    fn a_rung_rests_its_own_ninety_seconds_and_asks_even_when_nothing_is_pending() {
        let mut active = active_with(vec![{
            let mut rung = proposed("c1", 0, false);
            rung.calibration = true;
            rung.rest_after_success = 90;
            rung.rest_after_failure = 90;
            rung
        }]);
        complete(&mut active, "c1", 5, 2_000);
        assert_eq!(
            active.completed_sets[0].rest_until, 2_090,
            "not the 60 s end-of-exercise rest: the ramp continues"
        );
        let snap = snapshot(&active, 2_010);
        assert_eq!(
            snap.state, STATE_RESTING,
            "not done: the answer still appends working sets"
        );
        let prompt = snap.effort_prompt.expect("the rung asks");
        assert!(prompt.calibration);
    }

    #[test]
    fn easy_climbs_a_rung_ahead_of_the_next_exercise() {
        let mut active = ramp_workout(45.0);
        complete(&mut active, "c1", 5, 2_000);
        rate(&mut active, "c1", Effort::Easy);

        assert_eq!(active.proposed_sets.len(), 3);
        let next = &active.proposed_sets[1];
        assert_eq!(next.exercise, 1, "spliced in right after the rung");
        assert!(next.calibration);
        assert_eq!(next.target_reps, 5);
        assert_eq!(next.target_weight, 50.0, "max(45 + 5, 45 × 1.1) snapped");
        assert_eq!((next.rest_after_success, next.rest_after_failure), (90, 90));
        assert_eq!(active.proposed_sets[2].id, "b1");
        assert!(active
            .proposed_sets
            .iter()
            .enumerate()
            .all(|(i, s)| s.workout_order == i as i32));
        assert_eq!(active.completed_sets[0].effort(), Effort::Easy);
        assert_eq!(
            snapshot(&active, 2_010).effort_prompt.unwrap().effort,
            Effort::Easy as i32,
            "the prompt stays, showing the answer"
        );
    }

    #[test]
    fn a_big_rung_climbs_ten_percent() {
        let mut active = ramp_workout(200.0);
        complete(&mut active, "c1", 5, 2_000);
        rate(&mut active, "c1", Effort::Easy);
        assert_eq!(active.proposed_sets[1].target_weight, 220.0);
    }

    #[test]
    fn right_settles_here_with_the_working_sets_minus_one() {
        let mut active = ramp_workout(45.0);
        complete(&mut active, "c1", 5, 2_000);
        rate(&mut active, "c1", Effort::Right);

        let squat = squat_sets(&active);
        assert_eq!(squat.len(), 3, "the rung plus two working sets");
        let working: Vec<&&ProposedSet> = squat.iter().filter(|s| !s.calibration).collect();
        assert_eq!(working.len(), 2);
        for set in &working {
            assert_eq!(set.target_weight, 45.0);
            assert_eq!(set.target_reps, 6, "squat range bottom");
            assert_eq!((set.rest_after_success, set.rest_after_failure), (180, 240));
            assert!(!set.warmup);
        }
        assert_eq!(
            active.proposed_sets[3].id, "b1",
            "other exercises stay behind"
        );
        let snap = snapshot(&active, 2_010);
        assert_eq!(snap.state, STATE_RESTING);
        assert_eq!(snap.display_set.unwrap().id, working[0].id);
    }

    #[test]
    fn hard_settles_one_rung_down_or_at_the_opener() {
        // Hard on the very first rung: that rung's weight is the weight.
        let mut active = ramp_workout(45.0);
        complete(&mut active, "c1", 5, 2_000);
        rate(&mut active, "c1", Effort::Hard);
        assert!(squat_sets(&active)
            .iter()
            .filter(|s| !s.calibration)
            .all(|s| s.target_weight == 45.0));

        // Easy then hard: the previous rung wins.
        let mut active = ramp_workout(45.0);
        complete(&mut active, "c1", 5, 2_000);
        rate(&mut active, "c1", Effort::Easy);
        let rung2 = active.proposed_sets[1].id.clone();
        complete(&mut active, &rung2, 5, 2_200);
        rate(&mut active, &rung2, Effort::Hard);
        let working: Vec<&ProposedSet> = squat_sets(&active)
            .into_iter()
            .filter(|s| !s.calibration)
            .collect();
        assert_eq!(working.len(), 2);
        assert!(
            working.iter().all(|s| s.target_weight == 45.0),
            "back to rung one"
        );
        assert_eq!(
            active.completed_sets[1].effort(),
            Effort::Hard,
            "the answer is kept"
        );
    }

    #[test]
    fn a_rung_missed_on_its_done_is_answered_hard() {
        let mut active = ramp_workout(45.0);
        complete(&mut active, "c1", 3, 2_000);
        assert_eq!(
            active.completed_sets[0].effort(),
            Effort::Hard,
            "short of the target: the miss is the answer"
        );
        assert!(
            squat_sets(&active)
                .iter()
                .filter(|s| !s.calibration)
                .all(|s| s.target_weight == 45.0),
            "settled at the opener"
        );
        let prompt = workout_state_snapshot(
            &active.workout,
            &active.proposed_sets,
            &active.completed_sets,
            2_010,
        )
        .effort_prompt
        .unwrap();
        assert_eq!(prompt.effort(), Effort::Hard, "nothing left to ask");
    }

    #[test]
    fn tapping_a_rung_below_its_target_re_answers_it_hard() {
        let mut active = ramp_workout(45.0);
        complete(&mut active, "c1", 5, 2_000);
        rate(&mut active, "c1", Effort::Easy);
        assert!(squat_sets(&active)[1].calibration, "easy climbed a rung");
        let id = done_id(&active, "c1");
        edit(&mut active, &id, 4, 45.0);
        assert_eq!(active.completed_sets[0].effort(), Effort::Hard);
        let squat = squat_sets(&active);
        assert_eq!(
            squat.iter().filter(|s| s.calibration).count(),
            1,
            "the climbed rung is taken back"
        );
        assert!(squat
            .iter()
            .filter(|s| !s.calibration)
            .all(|s| s.target_weight == 45.0));
    }

    #[test]
    fn the_sixth_rung_settles_whatever_the_answer() {
        let mut active = ramp_workout(45.0);
        let mut rung = "c1".to_string();
        let mut at = 2_000;
        for _ in 0..5 {
            complete(&mut active, &rung, 5, at);
            rate(&mut active, &rung, Effort::Easy);
            at += 200;
            rung = squat_sets(&active).last().unwrap().id.clone();
        }
        assert_eq!(squat_sets(&active).len(), 6, "five easies built the cap");

        complete(&mut active, &rung, 5, at);
        rate(&mut active, &rung, Effort::Easy);
        let squat = squat_sets(&active);
        assert_eq!(
            squat.iter().filter(|s| s.calibration).count(),
            6,
            "no seventh rung"
        );
        let sixth_weight = squat[5].target_weight;
        let working: Vec<&&ProposedSet> = squat.iter().filter(|s| !s.calibration).collect();
        assert_eq!(working.len(), 2);
        assert!(working.iter().all(|s| s.target_weight == sixth_weight));
    }

    #[test]
    fn a_rung_is_never_resolved_by_the_clock() {
        let mut active = ramp_workout(45.0);
        complete(&mut active, "c1", 5, 2_000); // rests until 2_090
        let snap = snapshot(&active, 9_000);
        assert!(
            snap.effort_prompt.is_some(),
            "still asking long after the rest"
        );
        assert_eq!(active.completed_sets[0].effort(), Effort::Unspecified);
        assert_eq!(squat_sets(&active).len(), 1, "nothing appended");
    }

    #[test]
    fn done_without_an_answer_on_a_rung_appends_then_completes_the_first_working_set() {
        let mut active = ramp_workout(45.0);
        complete(&mut active, "c1", 5, 2_000);
        active.completed_sets[0].id = "done-c1".to_string();
        // The app shows uuid5("done-c1:0") on the button and sends Done for it.
        let first = uuid5("done-c1", 0);
        complete(&mut active, &first, 6, 2_200);

        assert_eq!(active.completed_sets[0].effort(), Effort::Right);
        let squat = squat_sets(&active);
        assert_eq!(squat.len(), 3, "the rung plus two working sets");
        assert_eq!(squat[1].id, first);
        assert_eq!(squat[2].id, uuid5("done-c1", 1));
        assert!(
            active
                .completed_sets
                .iter()
                .any(|c| c.proposed_set_id == first),
            "the Done landed on the appended set, not a no-op"
        );
    }

    #[test]
    fn re_rating_a_rung_takes_back_its_append_and_applies_the_new_answer() {
        let mut active = ramp_workout(45.0);
        complete(&mut active, "c1", 5, 2_000);
        rate(&mut active, "c1", Effort::Easy);
        assert_eq!(squat_sets(&active).len(), 2, "rung two appended");

        rate(&mut active, "c1", Effort::Right);
        let squat = squat_sets(&active);
        assert_eq!(
            squat.iter().filter(|s| s.calibration).count(),
            1,
            "rung two gone"
        );
        let working: Vec<&&ProposedSet> = squat.iter().filter(|s| !s.calibration).collect();
        assert_eq!(working.len(), 2);
        assert!(working.iter().all(|s| s.target_weight == 45.0));
        let done = done_id(&active, "c1");
        assert_eq!(working[0].id, uuid5(&done, 0));
        assert_eq!(active.proposed_sets.last().unwrap().id, "b1");

        rate(&mut active, "c1", Effort::Easy);
        let squat = squat_sets(&active);
        assert_eq!(squat.len(), 2, "back to one more rung, working sets gone");
        assert!(squat[1].calibration);
        assert_eq!(squat[1].id, uuid5(&done, 0));
        assert_eq!(active.completed_sets[0].effort(), Effort::Easy);
    }

    #[test]
    fn re_rating_a_rung_after_a_typed_weight_only_changes_the_answer() {
        let mut active = ramp_workout(45.0);
        complete(&mut active, "c1", 5, 2_000);
        adjust(&mut active, 1, 100.0);
        let plan = active.proposed_sets.clone();
        rate(&mut active, "c1", Effort::Easy);
        assert_eq!(active.completed_sets[0].effort(), Effort::Easy);
        assert_eq!(active.proposed_sets, plan, "the typed weight's sets stay");
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

    #[test]
    fn typing_a_weight_mid_ramp_replaces_the_rung_with_the_full_working_sets() {
        let mut active = ramp_workout(45.0);
        complete(&mut active, "c1", 5, 2_000);
        rate(&mut active, "c1", Effort::Easy);
        let pending_rung = active.proposed_sets[1].id.clone();
        assert!(active.proposed_sets[1].calibration);

        adjust(&mut active, 1, 102.0);
        let squat = squat_sets(&active);
        assert_eq!(squat.len(), 4, "the done rung plus three working sets");
        assert!(
            squat.iter().all(|s| s.id != pending_rung),
            "the pending rung is gone"
        );
        let working: Vec<&&ProposedSet> = squat.iter().filter(|s| !s.calibration).collect();
        assert_eq!(
            working.len(),
            3,
            "the prescription's full count, not minus one"
        );
        for (n, set) in working.iter().enumerate() {
            assert_eq!(set.id, uuid5(&pending_rung, n), "pinned id for n = {n}");
            assert_eq!(set.target_weight, 100.0, "102 snapped loadable");
            assert_eq!(set.target_reps, 6);
            assert_eq!((set.rest_after_success, set.rest_after_failure), (180, 240));
            assert!(!set.warmup);
        }
        assert_eq!(
            active.proposed_sets[1].id, working[0].id,
            "where the rung was"
        );
        assert_eq!(
            active.proposed_sets[4].id, "b1",
            "other exercises stay behind"
        );
        assert!(active
            .proposed_sets
            .iter()
            .enumerate()
            .all(|(i, s)| s.workout_order == i as i32));
        assert_eq!(
            active.completed_sets[0].effort(),
            Effort::Easy,
            "answered rungs keep theirs"
        );
    }

    #[test]
    fn typing_a_weight_closes_an_open_rung_as_right_without_appending() {
        let mut second = proposed("c2", 1, false);
        second.calibration = true;
        second.target_weight = 50.0;
        let mut active = ramp_workout(45.0);
        active.proposed_sets[0].calibration = true;
        active.proposed_sets.insert(1, second);
        active.renumber_sets();
        complete(&mut active, "c1", 5, 2_000);
        assert!(
            snapshot(&active, 2_010).effort_prompt.is_some(),
            "c1 is asking"
        );

        adjust(&mut active, 1, 95.0);
        assert_eq!(active.completed_sets[0].effort(), Effort::Right);
        let squat = squat_sets(&active);
        assert_eq!(
            squat.iter().filter(|s| s.calibration).count(),
            1,
            "only the done rung"
        );
        let working: Vec<&&ProposedSet> = squat.iter().filter(|s| !s.calibration).collect();
        assert_eq!(
            working.len(),
            3,
            "no RIGHT append on top of the typed weight's sets"
        );
        assert!(working.iter().all(|s| s.target_weight == 95.0));
        assert_eq!(working[0].id, uuid5("c2", 0));
        assert_eq!(
            snapshot(&active, 2_010).effort_prompt.unwrap().effort,
            Effort::Right as i32
        );
    }

    #[test]
    fn typing_a_weight_while_the_rung_is_asking_settles_on_it() {
        let mut active = ramp_workout(45.0);
        complete(&mut active, "c1", 5, 2_000);
        let done_rung = done_id(&active, "c1");
        assert!(
            snapshot(&active, 2_010).effort_prompt.is_some(),
            "c1 is asking"
        );

        adjust(&mut active, 1, 102.0);
        assert_eq!(
            active.completed_sets[0].effort(),
            Effort::Right,
            "closed, not appended"
        );
        assert_eq!(
            snapshot(&active, 2_010).effort_prompt.unwrap().effort,
            Effort::Right as i32
        );
        let squat = squat_sets(&active);
        assert_eq!(
            squat.len(),
            4,
            "the rung plus three working sets, no RIGHT append"
        );
        let working: Vec<&&ProposedSet> = squat.iter().filter(|s| !s.calibration).collect();
        for (n, set) in working.iter().enumerate() {
            assert_eq!(
                set.id,
                uuid5(&done_rung, n),
                "ids from the done rung, n = {n}"
            );
            assert_eq!(set.target_weight, 100.0);
        }
        assert_eq!(working.len(), 3);
        assert_eq!(
            active.proposed_sets[1].id, working[0].id,
            "straight after the rung"
        );
        assert_eq!(active.proposed_sets[4].id, "b1");
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
        assert_eq!(active.completed_sets[0].effort(), Effort::Unspecified);
    }

    #[test]
    fn a_lone_unanswered_rung_is_not_all_done() {
        let mut rung = proposed("c1", 0, false);
        rung.calibration = true;
        rung.target_weight = 45.0;
        rung.rest_after_success = 90;
        rung.rest_after_failure = 90;
        let mut active = active_with(vec![rung]);
        complete(&mut active, "c1", 5, 2_000);
        active.completed_sets[0].id = "done-c1".to_string();

        let snap = snapshot(&active, 2_010);
        assert_eq!(snap.state, STATE_RESTING, "right would append working sets");
        assert_eq!(snap.rest_until, 2_090);
        let display = snap.display_set.expect("what Done will log");
        assert_eq!(display.id, uuid5("done-c1", 0));
        assert_eq!(display.target_weight, 45.0);
        assert!(!display.calibration);
        assert_eq!(
            active.proposed_sets.len(),
            1,
            "the snapshot appends nothing"
        );

        let snap = snapshot(&active, 2_090);
        assert_eq!(snap.state, STATE_YAPPING);
        assert_eq!(snap.display_set.unwrap().id, uuid5("done-c1", 0));

        // Answered, or the plan is genuinely over: ALL_DONE.
        resolve_all_effort(&mut active);
        assert_eq!(snapshot(&active, 2_010).state, STATE_ALL_DONE);

        // Done on the displayed id goes through.
        let mut active = active_with(vec![{
            let mut rung = proposed("c1", 0, false);
            rung.calibration = true;
            rung
        }]);
        complete(&mut active, "c1", 5, 2_000);
        let display = snapshot(&active, 2_010).display_set.unwrap();
        complete(&mut active, &display.id, 6, 2_200);
        assert!(active
            .completed_sets
            .iter()
            .any(|c| c.proposed_set_id == display.id));
    }

    #[test]
    fn an_unanswered_rung_points_done_at_its_own_working_set_before_other_exercises() {
        let mut active = ramp_workout(45.0); // squat rung c1, bench b1 pending
        complete(&mut active, "c1", 5, 2_000);
        active.completed_sets[0].id = "done-c1".to_string();

        let snap = snapshot(&active, 2_010);
        assert_eq!(snap.state, STATE_RESTING);
        let display = snap.display_set.expect("the would-be first working set");
        assert_eq!(display.id, uuid5("done-c1", 0), "not the pending bench set");
        assert_eq!(display.exercise, 1, "squat");
        assert_eq!(
            snapshot(&active, 2_090).state,
            STATE_YAPPING,
            "by the rung's rest"
        );

        let response = get_workout_response_from_active(&active, 2_090);
        assert_eq!(
            response.next_up_set.unwrap().id,
            display.id,
            "next_up_set and display_set are one source of truth"
        );

        complete(&mut active, &display.id, 6, 2_200);
        assert_eq!(active.completed_sets[0].effort(), Effort::Right);
        let logged = active
            .proposed_sets
            .iter()
            .find(|s| active.completed_sets[1].proposed_set_id == s.id)
            .unwrap();
        assert_eq!(logged.exercise, 1, "a squat working set was logged");
        assert!(!logged.calibration);
        assert_eq!(
            active.proposed_sets[1].id, display.id,
            "appended right after the rung"
        );
        assert_eq!(active.proposed_sets.last().unwrap().id, "b1");
    }

    #[test]
    fn done_on_another_exercise_still_settles_the_rung_first() {
        let mut active = ramp_workout(45.0);
        complete(&mut active, "c1", 5, 2_000);
        complete(&mut active, "b1", 5, 2_200);
        assert_eq!(active.completed_sets[0].effort(), Effort::Right);
        assert_eq!(
            squat_sets(&active).len(),
            3,
            "the squat working sets were appended"
        );
        assert!(active
            .completed_sets
            .iter()
            .any(|c| c.proposed_set_id == "b1"));
        let snap = snapshot(&active, 2_210);
        assert_eq!(snap.display_set.unwrap().exercise, 1, "squat is next again");
    }

    #[test]
    fn done_twice_on_the_same_set_is_a_no_op() {
        let mut active = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
        complete(&mut active, "s1", 5, 2_000);
        let before = active.completed_sets.clone();
        complete(&mut active, "s1", 3, 2_050);
        assert_eq!(active.completed_sets, before, "one row, untouched");
        assert_eq!(
            active.completed_sets[0].effort(),
            Effort::Unspecified,
            "the repeat resolves nothing either"
        );
    }

    #[test]
    fn appended_sets_get_deterministic_ids() {
        // Two identical runs: the rung's done set gets a fixed id so the
        // appends can be compared across them.
        let run = |effort: Effort| {
            let mut active = ramp_workout(45.0);
            complete(&mut active, "c1", 5, 2_000);
            active.completed_sets[0].id = "done-c1".to_string();
            rate_id(&mut active, "done-c1", effort);
            active
                .proposed_sets
                .iter()
                .filter(|s| s.exercise == 1 && s.id != "c1")
                .map(|s| s.id.clone())
                .collect::<Vec<String>>()
        };
        let expected = |n: usize| {
            Uuid::new_v5(&Uuid::NAMESPACE_OID, format!("done-c1:{n}").as_bytes()).to_string()
        };

        let easy = run(Effort::Easy);
        assert_eq!(easy, vec![expected(0)], "one rung: n = 0");
        assert_eq!(run(Effort::Easy), easy, "stable across runs");

        let right = run(Effort::Right);
        assert_eq!(
            right,
            vec![expected(0), expected(1)],
            "working sets: n = 0, 1"
        );
        assert_ne!(right[0], right[1], "distinct across n");
        assert_eq!(
            run(Effort::Hard),
            right,
            "the answer does not change the ids"
        );

        // Resolution at the next Done is the same path, so the same ids.
        let mut active = ramp_workout(45.0);
        complete(&mut active, "c1", 5, 2_000);
        active.completed_sets[0].id = "done-c1".to_string();
        complete(&mut active, "b1", 5, 2_200);
        let stale: Vec<String> = active
            .proposed_sets
            .iter()
            .filter(|s| s.exercise == 1 && s.id != "c1")
            .map(|s| s.id.clone())
            .collect();
        assert_eq!(stale, right);
    }

    #[test]
    fn a_rung_left_open_at_end_of_workout_is_right_but_appends_nothing() {
        let mut active = ramp_workout(45.0);
        complete(&mut active, "c1", 5, 2_000);
        resolve_all_effort(&mut active);
        assert_eq!(active.completed_sets[0].effort(), Effort::Right);
        assert_eq!(
            active.proposed_sets.len(),
            2,
            "no pending rows on a finished workout"
        );
        assert_eq!(squat_sets(&active).len(), 1);
        let prompt = snapshot(&active, 2_010).effort_prompt.unwrap();
        assert_eq!(prompt.effort, Effort::Right as i32, "shown as answered");
    }
}
