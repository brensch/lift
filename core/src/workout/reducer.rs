use super::*;
use crate::ids::{derived_id, Ids};
use crate::pb::{
    AnswerRungRequest, EditCompletedSetRequest, RepsLeft, SkipWarmupsRequest, StartSetRequest,
    WeightChange, WeightChangeCause, Workout,
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
            lifting_started_at: 0,
        };
    }

    WorkoutStateSnapshot {
        state: STATE_READY,
        display_set: Some(next),
        rest_until: 0,
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
        rung_question_set_id: rung_question(active).unwrap_or_default(),
        rung_outcomes: Vec::new(),
        passed_warmup_ids,
        workout: Some(active.workout.clone()),
        proposed_sets: active.proposed_sets.clone(),
        completed_sets: active.completed_sets.clone(),
        next_up_set,
        plan_change_stats: Some(workout_plan_change_stats_from_sets(&active.proposed_sets)),
        state_snapshot,
        summary,
        exercise_logs: active.exercise_logs.clone(),
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
        exercise_logs: resp.exercise_logs,
    }
}

pub fn active_from_get_workout_response(
    resp: GetWorkoutResponse,
) -> Result<WorkoutRecord, WorkoutError> {
    let workout = resp
        .workout
        .ok_or_else(|| WorkoutError::internal("Checkpoint missing workout"))?;
    Ok(WorkoutRecord {
        exercise_logs: resp.exercise_logs,
        ..WorkoutRecord::new(workout, resp.proposed_sets, resp.completed_sets)
    })
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
/// appends the next rung or the working sets, in [unit].
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
    let rest_until = ended_at + rest_seconds_after(&proposed, is_final_set_of_exercise);
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
        started_at,
        reps_left: RepsLeft::Unspecified as i32,
        jump_lb: 0.0,
    });
    // A calibration rung settles the moment it's done (`would_append`).
    if proposed.calibration {
        settle_rung(workout_ref, &completed_set_id, unit, ended_at);
    }
    Ok(())
}

/// How long to rest after a set: its own rest, or the short
/// between-exercise rest after an exercise's final set. A calibration rung
/// always rests its own 90 s — the ramp continues after it, so it is never
/// final.
fn rest_seconds_after(proposed: &ProposedSet, is_final: bool) -> i64 {
    if is_final && !proposed.calibration {
        return END_OF_EXERCISE_REST_SECONDS;
    }
    proposed.rest_seconds as i64
}

/// Correct a done set after the fact: reps and weight change, the rest is
/// recomputed from `ended_at` by the same rule Done used, and a weight
/// fixed is logged at `at` (a CORRECTION). An unknown set is a no-op.
pub fn apply_edit_completed_set_to_active(
    workout_ref: &mut WorkoutRecord,
    req: &EditCompletedSetRequest,
    unit: AppWeightUnit,
    at: i64,
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
    let rest = rest_seconds_after(&proposed, is_final);
    let set = &mut workout_ref.completed_sets[idx];
    let weight_before = set.actual_weight;
    // A rung corrected to a miss ran to failure: it had nothing left.
    if req.actual_reps < proposed.target_reps {
        set.reps_left = RepsLeft::Unspecified as i32;
        set.jump_lb = 0.0;
    }
    set.actual_reps = req.actual_reps;
    set.actual_weight = req.actual_weight;
    set.rest_until = set.ended_at + rest;
    let ended_at = set.ended_at;
    workout_ref.log_change(
        proposed.exercise,
        WeightChange {
            at,
            from_set_id: proposed.id.clone(),
            before: weight_before,
            after: req.actual_weight,
            cause: WeightChangeCause::Correction as i32,
        },
    );
    // A rung's reps decide what follows it: settle it again on the new count.
    if proposed.calibration {
        resettle_rung(workout_ref, &req.completed_set_id, unit, ended_at);
    }
    Ok(())
}

/// A calibration rung, done: append what its reps call for (see
/// `would_append`) straight after it, and log the weight it moves to.
fn settle_rung(
    workout_ref: &mut WorkoutRecord,
    completed_set_id: &str,
    unit: AppWeightUnit,
    at: i64,
) {
    let Some(rung) = rung_of(workout_ref, completed_set_id) else {
        return;
    };
    let Some(decision) = workout_ref.decision(rung.exercise).cloned() else {
        return;
    };
    let appended = would_append(
        &workout_ref.proposed_sets,
        &workout_ref.completed_sets,
        &rung,
        completed_set_id,
        &decision,
        unit,
    );
    if let Some(first) = appended.first() {
        let cause = if first.calibration {
            WeightChangeCause::CalibrationStep
        } else {
            WeightChangeCause::CalibrationSettled
        };
        let change = WeightChange {
            at,
            from_set_id: first.id.clone(),
            before: rung.target_weight,
            after: first.target_weight,
            cause: cause as i32,
        };
        workout_ref.log_change(rung.exercise, change);
    }
    planning::insert_sets_after(workout_ref, &rung.id, appended);
}

/// A rung's reps were corrected (a rep tapped off after Done): take back
/// what it appended, and its log entry, and settle it again. Only while
/// what is pending for the exercise is exactly that append — once one of
/// those sets is done, or the weight was typed, the plan stands.
fn resettle_rung(
    workout_ref: &mut WorkoutRecord,
    completed_set_id: &str,
    unit: AppWeightUnit,
    at: i64,
) {
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
    if pending.is_empty()
        || !pending.iter().all(|s| ours.contains(&s.id))
        || !take_back_append(workout_ref, completed_set_id)
    {
        return;
    }
    settle_rung(workout_ref, completed_set_id, unit, at);
}

/// The ramp set whose "how many more could you have done?" is open, as a
/// proposed set id: the workout's latest done set, a calibration rung done
/// in full and unanswered, with nothing pending for its lift but the rung
/// it appended, and nothing being lifted. Its answer can still change what
/// comes next; once anything else happens the question is gone.
pub fn rung_question(workout_ref: &WorkoutRecord) -> Option<String> {
    if workout_ref.workout.end_time > 0 {
        return None;
    }
    let done: std::collections::HashSet<&str> = workout_ref
        .completed_sets
        .iter()
        .filter(|c| c.ended_at != 0)
        .map(|c| c.proposed_set_id.as_str())
        .collect();
    let lifting = workout_ref.proposed_sets.iter().any(|s| {
        s.id == workout_ref.workout.lifting_set_id && !s.cancelled && !done.contains(s.id.as_str())
    });
    if lifting {
        return None;
    }
    let last = last_done_set(&workout_ref.completed_sets)?;
    let rung = rung_of(workout_ref, &last.id)?;
    if last.actual_reps < rung.target_reps
        || last.reps_left != RepsLeft::Unspecified as i32
        || last.jump_lb != 0.0
    {
        return None;
    }
    let next = derived_id(&last.id, 0);
    let mut pending = workout_ref
        .proposed_sets
        .iter()
        .filter(|s| s.exercise == rung.exercise && !s.cancelled && !done.contains(s.id.as_str()));
    let only_next = pending
        .next()
        .is_some_and(|s| s.id == next && s.calibration)
        && pending.next().is_none();
    only_next.then_some(rung.id)
}

/// The answer to an open rung question (`rung_question`): recorded on the
/// done set, and the ramp settled again from it (`would_append`). The
/// answer is a range (`reps_left`) or a specific jump (`jump_lb`), exactly
/// one of them; a jump must be over 0 and at most twice the rung's weight
/// (`MAX_JUMP_FRACTION`). Both, neither, a jump out of range, or an answer
/// to any other set is a no-op.
pub fn apply_answer_rung_to_active(
    workout_ref: &mut WorkoutRecord,
    req: &AnswerRungRequest,
    unit: AppWeightUnit,
    at: i64,
) -> Result<(), WorkoutError> {
    if workout_ref.workout.id != req.workout_id {
        return Err(WorkoutError::failed_precondition("Workout ID mismatch"));
    }
    let ranged = req.reps_left != RepsLeft::Unspecified as i32;
    let jumped = req.jump_lb != 0.0;
    if ranged == jumped
        || (ranged && RepsLeft::try_from(req.reps_left).is_err())
        || rung_question(workout_ref).as_deref() != Some(req.proposed_set_id.as_str())
    {
        return Ok(());
    }
    let Some(done) = workout_ref
        .completed_sets
        .iter()
        .filter(|c| c.proposed_set_id == req.proposed_set_id && c.ended_at != 0)
        .max_by_key(|c| c.ended_at)
    else {
        return Ok(());
    };
    if jumped {
        let lifted = if done.actual_weight > 0.0 {
            done.actual_weight
        } else {
            workout_ref
                .proposed_sets
                .iter()
                .find(|s| s.id == req.proposed_set_id)
                .map_or(0.0, |s| s.target_weight)
        };
        if !jump_in_range(req.jump_lb, lifted) {
            return Ok(());
        }
    }
    let Some(done) = workout_ref
        .completed_sets
        .iter_mut()
        .filter(|c| c.proposed_set_id == req.proposed_set_id && c.ended_at != 0)
        .max_by_key(|c| c.ended_at)
    else {
        return Ok(());
    };
    done.reps_left = req.reps_left;
    done.jump_lb = req.jump_lb;
    let completed_set_id = done.id.clone();
    resettle_rung(workout_ref, &completed_set_id, unit, at);
    Ok(())
}

/// The largest specific jump a rung's answer takes, as a fraction of the
/// rung's weight: past twice the rung it is a typo, not a jump.
pub const MAX_JUMP_FRACTION: f32 = 2.0;

/// Whether `jump_lb` is a jump a rung lifted at `lifted` lb can be
/// answered with: over 0, at most `MAX_JUMP_FRACTION` of the rung.
pub fn jump_in_range(jump_lb: f32, lifted: f32) -> bool {
    jump_lb.is_finite() && jump_lb > 0.0 && jump_lb <= lifted * MAX_JUMP_FRACTION + 1e-3
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

/// The ramp rule, pure: what a done `rung` appends. Every rep, with fewer
/// than six rungs → the next rung up: the larger of one step and 10%, or with
/// an answer of 2–4 or 5+ the weight the max it implies leaves one rep in
/// reserve on (`planning::answered_calibration_weight`), never less, or
/// with a specific jump the rung plus it (`planning::jumped_calibration_weight`). A
/// miss — a set to failure —, an answer of 0–1, or the sixth rung → the
/// decision's working sets, planned from the max the rung shows
/// (`plan::shown_max`: no reserve on a miss, the answer's on an answered
/// rung, one on a full rung otherwise). Ids are
/// `uuid5(NAMESPACE_OID, "{completed_set_id}:{n}")`, whatever was appended.
pub fn would_append(
    proposed_sets: &[ProposedSet],
    completed_sets: &[CompletedSet],
    rung: &ProposedSet,
    completed_set_id: &str,
    decision: &crate::pb::ExerciseDecision,
    unit: AppWeightUnit,
) -> Vec<ProposedSet> {
    // The rungs the lift has, this one included: a rung done again after
    // an undo, out of order, still counts the ones past it.
    let rungs = proposed_sets
        .iter()
        .filter(|set| set.exercise == rung.exercise && set.calibration && !set.cancelled)
        .count();
    let Some(done) = completed_sets
        .iter()
        .find(|c| c.id == completed_set_id && c.ended_at != 0)
    else {
        return Vec::new();
    };
    let full = done.actual_reps >= rung.target_reps;
    let answer = full
        .then(|| crate::plan::answered_reserve(done.reps_left))
        .flatten();
    let settled_by_answer = full && done.reps_left == RepsLeft::ZeroToOne as i32;
    let lifted = if done.actual_weight > 0.0 {
        done.actual_weight
    } else {
        rung.target_weight
    };
    let workout_id = &rung.workout_id;
    let mut appended = if full && !settled_by_answer && rungs < planning::MAX_CALIBRATION_RUNGS {
        let weight = match answer {
            Some(reserve) => {
                planning::answered_calibration_weight(rung.exercise, lifted, reserve, unit)
            }
            None if done.jump_lb > 0.0 => {
                planning::jumped_calibration_weight(rung.exercise, lifted, done.jump_lb, unit)
            }
            None => planning::next_calibration_weight(rung.exercise, rung.target_weight, unit),
        };
        vec![planning::calibration_set(workout_id, rung.exercise, weight)]
    } else {
        let reserve = match (full, answer) {
            (false, _) => 0.0,
            (true, Some(reserve)) => reserve,
            (true, None) => 1.0,
        };
        let max = crate::plan::shown_max(lifted, done.actual_reps, reserve, 1, false);
        planning::working_sets_after_calibration(workout_id, decision, max, unit)
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
    let rung = rung_of(workout_ref, &req.completed_set_id);
    workout_ref
        .completed_sets
        .retain(|c| !(c.workout_id == req.workout_id && c.id == req.completed_set_id));
    // An undone rung takes back what it appended while none of it is
    // lifted: done again, it appends afresh, never a second time.
    if rung.is_some() {
        take_back_append(workout_ref, &req.completed_set_id);
    }
    Ok(())
}

/// Remove what the done set `completed_set_id` appended (its derived
/// ids), and their log entries, unless one of them was lifted. Returns
/// whether it did.
fn take_back_append(workout_ref: &mut WorkoutRecord, completed_set_id: &str) -> bool {
    let ours: std::collections::HashSet<String> =
        (0..64).map(|n| derived_id(completed_set_id, n)).collect();
    if workout_ref
        .completed_sets
        .iter()
        .any(|c| ours.contains(&c.proposed_set_id))
    {
        return false;
    }
    workout_ref.proposed_sets.retain(|s| !ours.contains(&s.id));
    for log in &mut workout_ref.exercise_logs {
        log.changes.retain(|c| !ours.contains(&c.from_set_id));
    }
    workout_ref.renumber_sets();
    true
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
            rest_seconds: 180,
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

    /// Done at the set's own weight.
    fn complete(active: &mut WorkoutRecord, set_id: &str, reps: i32, at: i64) {
        let weight = active
            .proposed_sets
            .iter()
            .find(|s| s.id == set_id)
            .map(|s| s.target_weight)
            .unwrap_or(0.0);
        apply_complete_set_to_active(
            active,
            &CompleteSetRequest {
                workout_id: "w1".to_string(),
                proposed_set_id: set_id.to_string(),
                actual_reps: reps,
                actual_weight: weight,
                completed_at: at,
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
            },
            AppWeightUnit::Lb,
            &mut Ids::new(&Uuid::new_v4().to_string()),
        );
        assert!(err.is_err());
        assert!(active.completed_sets.is_empty());
    }

    #[test]
    fn a_set_rests_its_own_rest_hit_or_not() {
        for reps in [5, 3] {
            let mut active = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
            complete(&mut active, "s1", reps, 2_000);
            assert_eq!(active.completed_sets[0].rest_until, 2_000 + 180);
        }
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
            9_000,
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
        assert_eq!(active.completed_sets[0].rest_until, 2_180);

        // Reps and weight change; the rest stays anchored at ended_at.
        edit(&mut active, &id, 3, 125.0);
        let c = &active.completed_sets[0];
        assert_eq!((c.actual_reps, c.actual_weight), (3, 125.0));
        assert_eq!(c.rest_until, 2_180);

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
        rung.rest_seconds = 90;
        let mut other = proposed("b1", 1, false);
        other.exercise = 2;
        let mut active = active_with(vec![rung, other]);
        active.exercise_logs.push(crate::pb::ExerciseLog {
            decision: Some(ramp_decision(weight)),
            changes: Vec::new(),
        });
        active
    }

    /// A squat never done: 3 sets in the heavy class, a ramp from `weight`.
    fn ramp_decision(weight: f32) -> crate::pb::ExerciseDecision {
        crate::pb::ExerciseDecision {
            exercise: 1,
            sets: 3,
            reps: 5,
            weight,
            rest_seconds: 180,
            warmups: true,
            rep_low: 5,
            rep_high: 8,
            calibration: true,
            ..Default::default()
        }
    }

    fn causes(active: &WorkoutRecord) -> Vec<(WeightChangeCause, f32, f32)> {
        active.exercise_logs[0]
            .changes
            .iter()
            .map(|c| {
                (
                    WeightChangeCause::try_from(c.cause).unwrap(),
                    c.before,
                    c.after,
                )
            })
            .collect()
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
            3_000,
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

    /// A miss ends the ramp: the missed rung, a set to failure, gives the
    /// max, and the decision's working sets are planned from it.
    #[test]
    fn a_miss_settles_from_the_max_the_rung_shows() {
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
        assert_eq!(working.len(), 3, "the decision's sets");
        // 110 × 4 to failure shows 124.7; the heaviest it covers at 5 is
        // 101, so 100 × 5.
        for (n, set) in working.iter().enumerate() {
            assert_eq!((set.target_weight, set.target_reps), (100.0, 5));
            assert_eq!(set.id, uuid5(&done2, n));
            assert_eq!(set.rest_seconds, 180);
        }
        assert_eq!(active.proposed_sets.last().unwrap().id, "b1");
        assert_eq!(
            causes(&active),
            vec![
                (WeightChangeCause::CalibrationStep, 100.0, 110.0),
                (WeightChangeCause::CalibrationSettled, 110.0, 100.0),
            ]
        );
    }

    #[test]
    fn a_first_rung_missed_settles_under_it() {
        let mut active = ramp_workout(100.0);
        complete(&mut active, "c1", 3, 2_000);
        // 100 × 3 shows 110: 85 covers 6 at the bottom of the range.
        assert_eq!(squat_plan(&active), vec![(85.0, false); 3]);
        assert_eq!(
            squat_sets(&active).last().unwrap().target_reps,
            6,
            "a rep more before the next plate"
        );
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
        let max = crate::plan::shown_max(top, 5, 1.0, 1, false);
        let (weight, reps) = crate::plan::choose(
            crate::pb::Exercise::Squat,
            max,
            None,
            3,
            5,
            8,
            AppWeightUnit::Lb,
        );
        let working: Vec<(f32, i32)> = squat_sets(&active)
            .iter()
            .filter(|s| !s.calibration)
            .map(|s| (s.target_weight, s.target_reps))
            .collect();
        assert_eq!(working, vec![(weight, reps); 3]);
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
        assert_eq!(squat_plan(&active), vec![(90.0, false); 3]);
        assert_eq!(
            causes(&active),
            vec![(WeightChangeCause::CalibrationSettled, 100.0, 90.0)],
            "the step it took back is gone from the log"
        );
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

    /// Once a working set the rung settled is lifted, correcting the rung
    /// leaves the plan, and that set, where they are.
    #[test]
    fn a_settled_set_lifted_keeps_the_rung_settled() {
        let mut active = ramp_workout(100.0);
        complete(&mut active, "c1", 3, 2_000);
        let first = active.proposed_sets[1].id.clone();
        complete(&mut active, &first, 5, 2_200);
        let plan = squat_plan(&active);
        let done = done_id(&active, "c1");
        edit(&mut active, &done, 5, 100.0);
        assert_eq!(squat_plan(&active), plan);
        assert!(active.completed_sets.iter().all(|c| active
            .proposed_sets
            .iter()
            .any(|s| s.id == c.proposed_set_id)));
    }

    /// A weight typed mid-ramp moves the pending rung there: it is still a
    /// rung, with its id, and the ramp goes on from it.
    #[test]
    fn typing_a_weight_mid_ramp_moves_the_pending_rung() {
        let mut active = ramp_workout(45.0);
        complete(&mut active, "c1", 5, 2_000);
        let pending_rung = active.proposed_sets[1].id.clone();
        assert!(active.proposed_sets[1].calibration);

        adjust(&mut active, 1, 100.0);
        let squat = squat_sets(&active);
        assert_eq!(squat.len(), 2, "the done rung and the pending one");
        assert_eq!(squat[1].id, pending_rung, "the same rung");
        assert!(squat[1].calibration, "still ramping");
        assert_eq!(squat[1].target_weight, 100.0);
        assert_eq!(
            active.proposed_sets.last().unwrap().id,
            "b1",
            "other exercises stay behind"
        );
        assert_eq!(
            causes(&active).last(),
            Some(&(WeightChangeCause::UserAdjust, 50.0, 100.0))
        );
    }

    /// Fixing a done set's weight is a correction on the log; fixing only
    /// its reps is not a weight change.
    #[test]
    fn a_fixed_weight_is_a_correction() {
        let mut active = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
        active.exercise_logs.push(crate::pb::ExerciseLog {
            decision: Some(crate::pb::ExerciseDecision {
                exercise: 1,
                weight: 135.0,
                ..Default::default()
            }),
            changes: Vec::new(),
        });
        complete(&mut active, "s1", 5, 2_000);
        let id = done_id(&active, "s1");
        edit(&mut active, &id, 4, 135.0);
        assert!(causes(&active).is_empty());
        edit(&mut active, &id, 4, 125.0);
        assert_eq!(
            causes(&active),
            vec![(WeightChangeCause::Correction, 135.0, 125.0)]
        );
        let change = &active.exercise_logs[0].changes[0];
        assert_eq!((change.at, change.from_set_id.as_str()), (9_000, "s1"));
        assert_eq!(active.planned_weight(1), 135.0, "the plan's weight stands");
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

    /// Undoing a rung takes back the rung it appended, so doing it again
    /// appends one, not a second.
    #[test]
    fn an_undone_rung_takes_back_its_append() {
        let mut active = ramp_workout(100.0);
        complete(&mut active, "c1", 5, 2_000);
        let done = done_id(&active, "c1");
        apply_delete_completed_set_to_active(
            &mut active,
            &DeleteCompletedSetRequest {
                workout_id: "w1".to_string(),
                completed_set_id: done,
            },
        )
        .unwrap();
        assert_eq!(squat_plan(&active), Vec::<(f32, bool)>::new());
        assert!(causes(&active).is_empty(), "and its log entry");
        complete(&mut active, "c1", 5, 2_100);
        assert_eq!(squat_plan(&active), vec![(110.0, true)]);
    }

    // ── How many more could you have done? ──────────────────────────────────

    fn answer(active: &mut WorkoutRecord, set_id: &str, reps_left: RepsLeft) {
        send_answer(active, set_id, reps_left, 0.0, AppWeightUnit::Lb);
    }

    /// A specific jump of `jump_lb` for the next rung.
    fn jump(active: &mut WorkoutRecord, set_id: &str, jump_lb: f32, unit: AppWeightUnit) {
        send_answer(active, set_id, RepsLeft::Unspecified, jump_lb, unit);
    }

    fn send_answer(
        active: &mut WorkoutRecord,
        set_id: &str,
        reps_left: RepsLeft,
        jump_lb: f32,
        unit: AppWeightUnit,
    ) {
        apply_answer_rung_to_active(
            active,
            &AnswerRungRequest {
                workout_id: "w1".to_string(),
                proposed_set_id: set_id.to_string(),
                reps_left: reps_left as i32,
                jump_lb,
            },
            unit,
            3_000,
        )
        .unwrap();
    }

    /// A specific jump: the next rung is the rung plus it, snapped to
    /// what loads, still a rung, logged as a calibration step.
    #[test]
    fn a_jump_climbs_by_it_and_the_ramp_goes_on() {
        let mut active = ramp_workout(100.0);
        complete(&mut active, "c1", 5, 2_000);
        jump(&mut active, "c1", 37.0, AppWeightUnit::Lb);
        assert_eq!(squat_plan(&active), vec![(135.0, true)], "137 loads as 135");
        assert_eq!(
            causes(&active),
            vec![(WeightChangeCause::CalibrationStep, 100.0, 135.0)]
        );
        assert_eq!(rung_question(&active), None, "answered");
        let done = &active.completed_sets[0];
        assert_eq!((done.jump_lb, done.reps_left), (37.0, 0));
        // The ramp goes on: the jumped rung asks in turn.
        let rung2 = squat_sets(&active)[1].id.clone();
        complete(&mut active, &rung2, 5, 2_200);
        assert_eq!(rung_question(&active).as_deref(), Some(rung2.as_str()));
        assert!(squat_plan(&active)[1].1, "a third rung");

        // Too small to load: still one step up.
        let mut active = ramp_workout(100.0);
        complete(&mut active, "c1", 5, 2_000);
        jump(&mut active, "c1", 1.0, AppWeightUnit::Lb);
        assert_eq!(squat_plan(&active), vec![(105.0, true)]);
    }

    /// In kilograms the jump lands on kilogram plates.
    #[test]
    fn a_jump_in_kilograms_snaps_to_kilogram_plates() {
        use crate::weight_units::kg_to_pounds;
        let rung = kg_to_pounds(60.0);
        let mut active = ramp_workout(rung);
        complete(&mut active, "c1", 5, 2_000);
        jump(&mut active, "c1", kg_to_pounds(7.0), AppWeightUnit::Kg);
        let next = squat_plan(&active);
        assert_eq!(next.len(), 1);
        assert!(next[0].1);
        assert!(
            (next[0].0 - kg_to_pounds(67.5)).abs() < 0.01,
            "67 kg loads as 67.5: {}",
            next[0].0
        );
    }

    /// Exactly one of a range and a jump, and a jump in range: anything
    /// else is ignored, as is a jump to a question no longer open.
    #[test]
    fn a_bad_or_stale_jump_is_a_no_op() {
        let mut active = ramp_workout(100.0);
        complete(&mut active, "c1", 5, 2_000);
        let before = active.clone();
        let lb = AppWeightUnit::Lb;
        send_answer(&mut active, "c1", RepsLeft::FivePlus, 20.0, lb);
        assert_eq!(active, before, "both");
        send_answer(&mut active, "c1", RepsLeft::Unspecified, 0.0, lb);
        assert_eq!(active, before, "neither");
        for bad in [-10.0, 200.5, f32::NAN, f32::INFINITY] {
            jump(&mut active, "c1", bad, lb);
            assert_eq!(active, before, "out of range: {bad}");
        }
        jump(&mut active, "c1", 200.0, lb);
        assert_eq!(
            squat_plan(&active),
            vec![(300.0, true)],
            "twice the rung is fine"
        );

        // Answered already, by a range or a jump: a jump is ignored.
        let mut active = ramp_workout(100.0);
        complete(&mut active, "c1", 5, 2_000);
        answer(&mut active, "c1", RepsLeft::TwoToFour);
        let answered = active.clone();
        jump(&mut active, "c1", 50.0, lb);
        assert_eq!(active, answered, "answered by a range");
        let mut active = ramp_workout(100.0);
        complete(&mut active, "c1", 5, 2_000);
        jump(&mut active, "c1", 50.0, lb);
        let jumped = active.clone();
        jump(&mut active, "c1", 20.0, lb);
        answer(&mut active, "c1", RepsLeft::ZeroToOne);
        assert_eq!(active, jumped, "answered by a jump");

        // The next rung started: too late.
        let mut active = ramp_workout(100.0);
        complete(&mut active, "c1", 5, 2_000);
        let rung2 = squat_sets(&active)[1].id.clone();
        start(&mut active, &rung2, 2_100);
        let before = active.clone();
        jump(&mut active, "c1", 50.0, lb);
        assert_eq!(active, before, "something is being lifted");
    }

    /// A jumped rung corrected to a miss drops the jump, and settles as a
    /// miss.
    #[test]
    fn a_jumped_rung_corrected_to_a_miss_drops_its_jump() {
        let mut active = ramp_workout(100.0);
        complete(&mut active, "c1", 5, 2_000);
        jump(&mut active, "c1", 50.0, AppWeightUnit::Lb);
        let done = done_id(&active, "c1");
        edit(&mut active, &done, 4, 100.0);
        assert_eq!(active.completed_sets[0].jump_lb, 0.0);
        let max = crate::plan::shown_max(100.0, 4, 0.0, 1, false);
        assert_eq!(squat_plan(&active), settled_at(max));
    }

    /// The working sets a squat max gives this ramp's decision.
    fn settled_at(max: f32) -> Vec<(f32, bool)> {
        let (weight, _) = crate::plan::choose(
            crate::pb::Exercise::Squat,
            max,
            None,
            3,
            5,
            8,
            AppWeightUnit::Lb,
        );
        vec![(weight, false); 3]
    }

    #[test]
    fn a_full_rung_asks_and_a_short_one_does_not() {
        let mut active = ramp_workout(100.0);
        assert_eq!(rung_question(&active), None, "nothing done yet");
        complete(&mut active, "c1", 5, 2_000);
        assert_eq!(rung_question(&active).as_deref(), Some("c1"));
        assert_eq!(
            get_workout_response_from_active(&active, 2_010).rung_question_set_id,
            "c1"
        );

        let mut short = ramp_workout(100.0);
        complete(&mut short, "c1", 4, 2_000);
        assert_eq!(rung_question(&short), None, "a miss settles, no question");

        let mut working = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
        complete(&mut working, "s1", 5, 2_000);
        assert_eq!(rung_question(&working), None, "a working set never asks");
    }

    /// 0–1: the ramp ends at that set, its max counting half a rep in
    /// reserve, laid out as a miss's is.
    #[test]
    fn zero_to_one_settles_the_ramp_at_that_set() {
        let mut active = ramp_workout(100.0);
        complete(&mut active, "c1", 5, 2_000);
        answer(&mut active, "c1", RepsLeft::ZeroToOne);
        let max = crate::plan::shown_max(100.0, 5, 0.5, 1, false);
        assert_eq!(squat_plan(&active), settled_at(max));
        assert_eq!(squat_plan(&active), vec![(95.0, false); 3]);
        let done = done_id(&active, "c1");
        assert_eq!(
            squat_sets(&active)[1].id,
            uuid5(&done, 0),
            "ids from the done set, as a miss's"
        );
        assert_eq!(
            causes(&active),
            vec![(WeightChangeCause::CalibrationSettled, 100.0, 95.0)],
            "the step it took back is gone from the log"
        );
        assert_eq!(rung_question(&active), None, "answered");
        assert_eq!(
            active.completed_sets[0].reps_left,
            RepsLeft::ZeroToOne as i32
        );
    }

    /// 2–3 and 4+: the next rung is where the max they imply leaves a rep
    /// in reserve on five, never under the usual +10%.
    #[test]
    fn more_left_climbs_to_one_rep_in_reserve() {
        let unit = AppWeightUnit::Lb;
        for weight in [100.0, 200.0, 450.0] {
            for (reps_left, reserve) in [(RepsLeft::TwoToFour, 3.0), (RepsLeft::FivePlus, 8.0)] {
                let mut active = ramp_workout(weight);
                complete(&mut active, "c1", 5, 2_000);
                answer(&mut active, "c1", reps_left);
                let usual = planning::next_calibration_weight(1, weight, unit);
                let max = crate::plan::shown_max(weight, 5, reserve, 1, false);
                let next = squat_plan(&active);
                assert_eq!(next.len(), 1);
                assert!(next[0].1, "still a rung");
                assert!(
                    next[0].0 >= usual,
                    "never under +10%: {weight} {reps_left:?}"
                );
                assert!(
                    next[0].0 * 1.2 <= max + 1e-3 || next[0].0 == usual,
                    "a rep in reserve on five: {weight} {reps_left:?}"
                );
                assert_eq!(
                    causes(&active),
                    vec![(WeightChangeCause::CalibrationStep, weight, next[0].0)]
                );
            }
        }
        // 2–4 implies 1.27× the rung: a rep left at 1.06×, so +10% stands.
        let mut active = ramp_workout(100.0);
        complete(&mut active, "c1", 5, 2_000);
        answer(&mut active, "c1", RepsLeft::TwoToFour);
        assert_eq!(squat_plan(&active), vec![(110.0, true)]);
        // 5+ implies 1.43×: a rep left at about 1.19×, well past +10%.
        let mut active = ramp_workout(200.0);
        complete(&mut active, "c1", 5, 2_000);
        answer(&mut active, "c1", RepsLeft::FivePlus);
        assert_eq!(planning::next_calibration_weight(1, 200.0, unit), 220.0);
        assert_eq!(squat_plan(&active), vec![(235.0, true)]);
    }

    #[test]
    fn unanswered_climbs_the_usual_rung() {
        let mut active = ramp_workout(450.0);
        complete(&mut active, "c1", 5, 2_000);
        assert_eq!(squat_plan(&active), vec![(495.0, true)]);
    }

    /// An answered rung, then a miss on the rung after it: the miss
    /// settles the ramp as ever.
    #[test]
    fn a_miss_after_an_answer_still_settles_it() {
        let mut active = ramp_workout(450.0);
        complete(&mut active, "c1", 5, 2_000);
        answer(&mut active, "c1", RepsLeft::FivePlus);
        let (rung2, weight) = {
            let set = &squat_sets(&active)[1];
            (set.id.clone(), set.target_weight)
        };
        complete(&mut active, &rung2, 4, 2_200);
        let max = crate::plan::shown_max(weight, 4, 0.0, 1, false);
        assert_eq!(squat_plan(&active)[1..], settled_at(max)[..]);
        assert_eq!(rung_question(&active), None);
    }

    /// An answer only counts on the open question: not twice, not to a set
    /// before the latest, not once something is lifted, not on a miss.
    #[test]
    fn a_stale_answer_is_a_no_op() {
        // Answered already: the second answer changes nothing.
        let mut active = ramp_workout(100.0);
        complete(&mut active, "c1", 5, 2_000);
        answer(&mut active, "c1", RepsLeft::ZeroToOne);
        let settled = active.clone();
        answer(&mut active, "c1", RepsLeft::FivePlus);
        assert_eq!(active, settled, "the ramp settled: ignored");

        // A rung after it done: the first rung's question is gone.
        let mut active = ramp_workout(100.0);
        complete(&mut active, "c1", 5, 2_000);
        let rung2 = squat_sets(&active)[1].id.clone();
        complete(&mut active, &rung2, 5, 2_200);
        let before = active.clone();
        answer(&mut active, "c1", RepsLeft::ZeroToOne);
        assert_eq!(active, before, "not the latest rung");
        answer(&mut active, &rung2, RepsLeft::Unspecified);
        assert_eq!(active, before, "no answer");
        answer(&mut active, "nope", RepsLeft::ZeroToOne);
        assert_eq!(active, before, "an unknown set");

        // The next rung started: the weight is on the bar.
        let mut active = ramp_workout(100.0);
        complete(&mut active, "c1", 5, 2_000);
        let rung2 = squat_sets(&active)[1].id.clone();
        start(&mut active, &rung2, 2_100);
        assert_eq!(rung_question(&active), None);
        let before = active.clone();
        answer(&mut active, "c1", RepsLeft::ZeroToOne);
        assert_eq!(active, before, "something is being lifted");

        // Another lift's set done after it.
        let mut active = ramp_workout(100.0);
        complete(&mut active, "c1", 5, 2_000);
        complete(&mut active, "b1", 5, 2_100);
        let before = active.clone();
        answer(&mut active, "c1", RepsLeft::ZeroToOne);
        assert_eq!(active, before, "not the latest set");

        // A miss: it ran to failure, nothing to ask.
        let mut active = ramp_workout(100.0);
        complete(&mut active, "c1", 4, 2_000);
        let before = active.clone();
        answer(&mut active, "c1", RepsLeft::FivePlus);
        assert_eq!(active, before, "a miss");
    }

    /// The sixth rung settles the ramp on its own: no question.
    #[test]
    fn the_sixth_rung_does_not_ask() {
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
                .id
                .clone();
            complete(&mut active, &rung, 5, at);
            at += 200;
        }
        assert_eq!(rung_question(&active), None);
    }

    /// A rung answered, then corrected to a miss: the answer goes with it.
    #[test]
    fn a_rung_corrected_to_a_miss_drops_its_answer() {
        let mut active = ramp_workout(450.0);
        complete(&mut active, "c1", 5, 2_000);
        answer(&mut active, "c1", RepsLeft::FivePlus);
        let done = done_id(&active, "c1");
        edit(&mut active, &done, 4, 450.0);
        assert_eq!(
            active.completed_sets[0].reps_left,
            RepsLeft::Unspecified as i32
        );
        edit(&mut active, &done, 5, 450.0);
        assert_eq!(squat_plan(&active), vec![(495.0, true)], "unanswered again");
        assert_eq!(rung_question(&active).as_deref(), Some("c1"), "asks again");
    }
}
