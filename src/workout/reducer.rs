use super::*;
use crate::progress::compute_next_up_set;
use uuid::Uuid;

pub(crate) fn active_proposed_sets(proposed_sets: &[ProposedSet]) -> Vec<ProposedSet> {
    proposed_sets
        .iter()
        .filter(|set| !set.cancelled)
        .cloned()
        .collect()
}

pub(crate) fn workout_plan_change_stats_from_sets(
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

pub(crate) fn is_final_set_in_exercise_group_after_completion(
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

pub(crate) fn workout_state_snapshot_from_state(
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

    // Nothing left to do: the workout is finished. Resting only matters when
    // there is a next set to rest *before* — after the final set there is no set
    // to start, so we must not linger in RESTING/READY (which would offer a Start
    // button pointing at the just-finished set and re-open it in a loop).
    let Some(next) = next_up_set else {
        return WorkoutStateSnapshot {
            state: STATE_ALL_DONE,
            display_set: None,
            active_started_at: 0,
            rest_until: 0,
            last_rest_end: 0,
        };
    };

    // A set is up next. If the previous set's rest is still running we're resting
    // before it; otherwise it's ready now. Either way `display_set` is that next
    // set — every consumer (phone bar, watch, workout screen) uses display_set as
    // the set its Start button targets, so it must be the upcoming one.
    let last_set = completed_sets
        .iter()
        .filter(|set| set.ended_at != 0)
        .max_by_key(|set| set.ended_at);

    if let Some(last) = last_set {
        if last.rest_until > now {
            return WorkoutStateSnapshot {
                state: STATE_RESTING,
                display_set: Some(next),
                active_started_at: 0,
                rest_until: last.rest_until,
                last_rest_end: last.ended_at,
            };
        }
    }

    // Ready for the next set. Carry the moment the previous set's rest ended
    // (its rest_until) as last_rest_end so the client keeps showing the "yapping"
    // count-up after the rest expires — without it, reloading state (e.g. on app
    // focus-regain) drops from "Yapping 0:12" back to a bare "Next up".
    WorkoutStateSnapshot {
        state: STATE_READY,
        display_set: Some(next),
        active_started_at: 0,
        rest_until: 0,
        last_rest_end: last_set.map(|l| l.rest_until).unwrap_or(0),
    }
}

pub(crate) fn get_workout_response_from_active(active: &ActiveWorkout) -> GetWorkoutResponse {
    let now = now_unix();
    let state_snapshot = Some(workout_state_snapshot_from_state(
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
        exercise_groups: active.exercise_groups.clone(),
        proposed_sets: active.proposed_sets.clone(),
        completed_sets: active.completed_sets.clone(),
        next_up_set,
        plan_change_stats: Some(workout_plan_change_stats_from_sets(&active.proposed_sets)),
        state_snapshot,
        user_messages: Vec::new(),
        summary,
    }
}

pub(crate) fn start_workout_response_from_active(active: &ActiveWorkout) -> StartWorkoutResponse {
    let resp = get_workout_response_from_active(active);
    StartWorkoutResponse {
        id: active.workout.id.clone(),
        workout: resp.workout,
        exercise_groups: resp.exercise_groups,
        proposed_sets: resp.proposed_sets,
        completed_sets: resp.completed_sets,
        next_up_set: resp.next_up_set,
        state_snapshot: resp.state_snapshot,
        user_messages: Vec::new(),
    }
}

pub(crate) fn active_from_get_workout_response(
    resp: GetWorkoutResponse,
) -> Result<ActiveWorkout, WorkoutError> {
    let workout = resp
        .workout
        .ok_or_else(|| WorkoutError::internal("Checkpoint missing workout"))?;
    Ok(ActiveWorkout::new(
        workout,
        resp.exercise_groups,
        resp.proposed_sets,
        resp.completed_sets,
    ))
}

pub(crate) fn apply_start_set_to_active(
    workout_ref: &mut ActiveWorkout,
    req: &StartSetRequest,
) -> Result<(), WorkoutError> {
    if workout_ref.workout.id != req.workout_id {
        return Err(WorkoutError::failed_precondition("Workout ID mismatch"));
    }
    let proposed = workout_ref
        .proposed_sets
        .iter()
        .find(|p| p.id == req.proposed_set_id && !p.cancelled);
    if proposed.is_none() {
        // The set is gone — cancelled by a skip, or a stale/duplicate intent (the watch
        // delivers at-least-once and may reference a set the user has since skipped). Treat
        // it as a no-op instead of erroring: a hard error here permanently desynced the
        // watch. The next pushed snapshot reconciles it to the real state.
        return Ok(());
    }
    if workout_ref
        .completed_sets
        .iter()
        .any(|c| c.proposed_set_id == req.proposed_set_id && c.ended_at == 0)
    {
        return Ok(());
    }
    let (actual_reps, actual_weight) = proposed
        .map(|p| (p.target_reps, p.target_weight))
        .unwrap_or((0, 0.0));
    workout_ref.completed_sets.push(CompletedSet {
        id: Uuid::new_v4().to_string(),
        workout_id: req.workout_id.clone(),
        proposed_set_id: req.proposed_set_id.clone(),
        actual_reps,
        actual_weight,
        started_at: if req.started_at > 0 {
            req.started_at
        } else {
            now_unix()
        },
        ended_at: 0,
        rest_until: 0,
    });
    Ok(())
}

pub(crate) fn apply_complete_set_to_active(
    workout_ref: &mut ActiveWorkout,
    req: &CompleteSetRequest,
) -> Result<(), WorkoutError> {
    if workout_ref.workout.id != req.workout_id {
        return Err(WorkoutError::failed_precondition("Workout ID mismatch"));
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
    let ended_at = if req.completed_at > 0 {
        req.completed_at
    } else {
        now_unix()
    };
    let is_final_set_in_group = is_final_set_in_exercise_group_after_completion(
        &req.proposed_set_id,
        &workout_ref.proposed_sets,
        &workout_ref.completed_sets,
    );
    let mut rest_seconds = if req.actual_reps >= proposed.target_reps {
        proposed.rest_after_success as i64
    } else {
        proposed.rest_after_failure as i64
    };
    if is_final_set_in_group {
        rest_seconds = END_OF_EXERCISE_GROUP_REST_SECONDS;
    }
    let rest_until = ended_at + rest_seconds;
    if let Some(existing_idx) = workout_ref.completed_sets.iter().position(|c| {
        c.workout_id == req.workout_id
            && c.proposed_set_id == req.proposed_set_id
            && c.ended_at == 0
    }) {
        let cs = &mut workout_ref.completed_sets[existing_idx];
        cs.actual_reps = req.actual_reps;
        cs.actual_weight = req.actual_weight;
        cs.ended_at = ended_at;
        cs.rest_until = rest_until;
    } else {
        workout_ref.completed_sets.push(CompletedSet {
            id: Uuid::new_v4().to_string(),
            workout_id: req.workout_id.clone(),
            proposed_set_id: req.proposed_set_id.clone(),
            actual_reps: req.actual_reps,
            actual_weight: req.actual_weight,
            started_at: ended_at,
            ended_at,
            rest_until,
        });
    }
    Ok(())
}

pub(crate) fn apply_delete_completed_set_to_active(
    workout_ref: &mut ActiveWorkout,
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

pub(crate) fn apply_cancel_proposed_set_to_active(
    workout_ref: &mut ActiveWorkout,
    req: &CancelProposedSetRequest,
) -> Result<(), WorkoutError> {
    if workout_ref.workout.id != req.workout_id {
        return Err(WorkoutError::failed_precondition("Workout ID mismatch"));
    }
    let proposed_idx = workout_ref
        .proposed_sets
        .iter()
        .position(|set| {
            set.workout_id == req.workout_id && set.id == req.proposed_set_id && !set.cancelled
        })
        .ok_or_else(|| WorkoutError::not_found("Proposed set not found"))?;
    if !workout_ref.proposed_sets[proposed_idx].warmup {
        return Err(WorkoutError::failed_precondition(
            "Only warmup sets can be cancelled with this endpoint",
        ));
    }
    let has_completed = workout_ref
        .completed_sets
        .iter()
        .any(|set| set.proposed_set_id == req.proposed_set_id);
    if has_completed {
        return Err(WorkoutError::failed_precondition(
            "Cannot cancel a proposed set that has completed-set records",
        ));
    }
    workout_ref.proposed_sets[proposed_idx].cancelled = true;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use schlift::workout::v1::Workout;

    // Snapshot states, mirrored from workout_state_snapshot_from_state.
    const STATE_ALL_DONE: i32 = 1;
    const STATE_LIFTING: i32 = 2;
    const STATE_RESTING: i32 = 3;
    const STATE_READY: i32 = 5;

    fn proposed(id: &str, order: i32, warmup: bool) -> ProposedSet {
        ProposedSet {
            id: id.to_string(),
            workout_id: "w1".to_string(),
            workout_order: order,
            exercise: 1,
            target_reps: 5,
            target_weight: 135.0,
            warmup,
            exercise_group_id: "g1".to_string(),
            rest_after_success: 180,
            rest_after_failure: 300,
            cancelled: false,
            is_amrap: false,
            instruction: String::new(),
        }
    }

    fn active_with(sets: Vec<ProposedSet>) -> ActiveWorkout {
        ActiveWorkout::new(
            Workout {
                id: "w1".to_string(),
                name: "Test".to_string(),
                start_time: 1_000,
                end_time: 0,
                session_id: String::new(),
                ..Default::default()
            },
            vec![ExerciseGroup {
                id: "g1".to_string(),
                workout_id: "w1".to_string(),
                name: "Squat".to_string(),
                sets: sets.iter().filter(|s| !s.warmup).count() as i32,
                interleave_warmups: false,
                workout_order: 0,
                exercise_configs: vec![],
                rest_config: None,
                instruction: String::new(),
            }],
            sets,
            vec![],
        )
    }

    fn start(active: &mut ActiveWorkout, set_id: &str, at: i64) {
        apply_start_set_to_active(
            active,
            &StartSetRequest {
                workout_id: "w1".to_string(),
                proposed_set_id: set_id.to_string(),
                started_at: at,
            },
        )
        .unwrap();
    }

    fn complete(active: &mut ActiveWorkout, set_id: &str, reps: i32, at: i64) {
        apply_complete_set_to_active(
            active,
            &CompleteSetRequest {
                workout_id: "w1".to_string(),
                proposed_set_id: set_id.to_string(),
                actual_reps: reps,
                actual_weight: 135.0,
                completed_at: at,
            },
        )
        .unwrap();
    }

    // ── StartSet ────────────────────────────────────────────────────────────

    #[test]
    fn start_set_opens_an_in_progress_completed_set() {
        let mut active = active_with(vec![proposed("s1", 0, false)]);
        start(&mut active, "s1", 2_000);

        assert_eq!(active.completed_sets.len(), 1);
        let c = &active.completed_sets[0];
        assert_eq!(c.proposed_set_id, "s1");
        assert_eq!(c.started_at, 2_000);
        assert_eq!(c.ended_at, 0, "starting a set must not complete it");
    }

    #[test]
    fn start_set_is_idempotent_while_the_set_is_in_progress() {
        // The watch delivers intents at-least-once; a duplicate StartSet must
        // not open a second in-progress row.
        let mut active = active_with(vec![proposed("s1", 0, false)]);
        start(&mut active, "s1", 2_000);
        start(&mut active, "s1", 2_050);
        assert_eq!(active.completed_sets.len(), 1);
        assert_eq!(active.completed_sets[0].started_at, 2_000);
    }

    #[test]
    fn start_set_for_a_cancelled_or_unknown_set_is_a_no_op() {
        // A stale watch intent for a skipped set must not error — an error here
        // permanently desynced the watch.
        let mut sets = vec![proposed("s1", 0, true)];
        sets[0].cancelled = true;
        let mut active = active_with(sets);

        start(&mut active, "s1", 2_000);
        start(&mut active, "nope", 2_000);
        assert!(active.completed_sets.is_empty());
    }

    #[test]
    fn start_set_rejects_the_wrong_workout() {
        let mut active = active_with(vec![proposed("s1", 0, false)]);
        let err = apply_start_set_to_active(
            &mut active,
            &StartSetRequest {
                workout_id: "other".to_string(),
                proposed_set_id: "s1".to_string(),
                started_at: 2_000,
            },
        );
        assert!(err.is_err());
    }

    // ── CompleteSet ─────────────────────────────────────────────────────────

    #[test]
    fn complete_set_finishes_the_in_progress_row_rather_than_adding_one() {
        let mut active = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
        start(&mut active, "s1", 2_000);
        complete(&mut active, "s1", 5, 2_040);

        assert_eq!(active.completed_sets.len(), 1);
        let c = &active.completed_sets[0];
        assert_eq!(c.started_at, 2_000, "the StartSet timestamp is preserved");
        assert_eq!(c.ended_at, 2_040);
        assert_eq!(c.actual_reps, 5);
    }

    #[test]
    fn complete_set_without_a_prior_start_creates_the_row_directly() {
        // One-tap completion from the watch: no StartSet ever arrives.
        let mut active = active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
        complete(&mut active, "s1", 5, 2_040);
        assert_eq!(active.completed_sets.len(), 1);
        assert_eq!(active.completed_sets[0].ended_at, 2_040);
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
    fn the_last_set_of_a_group_gets_the_short_between_group_rest() {
        // No point resting three minutes when the next thing is a different
        // exercise — the final set of a group rests END_OF_EXERCISE_GROUP_REST_SECONDS.
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
            2_300 + END_OF_EXERCISE_GROUP_REST_SECONDS,
            "final set in the group should use the short rest"
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

    // ── DeleteCompletedSet / CancelProposedSet ──────────────────────────────

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
        let snap = workout_state_snapshot_from_state(&active.proposed_sets, &active.completed_sets, 3_000);
        assert_eq!(snap.state, STATE_READY, "the set should be up again");
        assert_eq!(snap.display_set.unwrap().id, "s1");
    }

    #[test]
    fn only_warmups_can_be_cancelled() {
        let mut active = active_with(vec![proposed("s1", 0, false)]);
        let err = apply_cancel_proposed_set_to_active(
            &mut active,
            &CancelProposedSetRequest {
                workout_id: "w1".to_string(),
                proposed_set_id: "s1".to_string(),
            },
        );
        assert!(err.is_err(), "working sets must not be skippable");
        assert!(!active.proposed_sets[0].cancelled);
    }

    #[test]
    fn a_warmup_with_completed_work_cannot_be_cancelled() {
        let mut active = active_with(vec![proposed("s1", 0, true)]);
        complete(&mut active, "s1", 5, 2_000);
        let err = apply_cancel_proposed_set_to_active(
            &mut active,
            &CancelProposedSetRequest {
                workout_id: "w1".to_string(),
                proposed_set_id: "s1".to_string(),
            },
        );
        assert!(err.is_err());
    }

    #[test]
    fn cancelling_a_warmup_soft_deletes_it() {
        let mut active = active_with(vec![proposed("s1", 0, true), proposed("s2", 1, false)]);
        apply_cancel_proposed_set_to_active(
            &mut active,
            &CancelProposedSetRequest {
                workout_id: "w1".to_string(),
                proposed_set_id: "s1".to_string(),
            },
        )
        .unwrap();
        assert!(active.proposed_sets[0].cancelled, "soft delete, not removal");
        assert_eq!(active.proposed_sets.len(), 2, "the row is retained");
    }

    // ── Snapshot state machine ──────────────────────────────────────────────

    #[test]
    fn resting_snapshot_focuses_the_next_set_not_the_finished_one() {
        // Two sets in one group. Finish the first; while resting, the snapshot
        // must point display_set at the SECOND set — that's the set every UI's
        // Start button acts on. Pointing it back at the finished set restarts it
        // in an infinite loop (dev regression: a warmup completed 6× in 40s and
        // the workout never advanced past set 0).
        let mut active =
            active_with(vec![proposed("s1", 0, true), proposed("s2", 1, false)]);
        complete(&mut active, "s1", 5, 2_000);
        let snap = workout_state_snapshot_from_state(
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
    fn ready_after_rest_carries_the_rest_end_for_the_yapping_timer() {
        // Finish set 1; once its rest expires the snapshot is READY for set 2, and
        // must report last_rest_end = set 1's rest_until so the UI keeps the
        // "yapping" count-up. Dropping it to 0 (as it did) made the state revert
        // from "Yapping 0:12" to a bare "Next up" whenever state was reloaded
        // (e.g. on app focus-regain).
        let mut active =
            active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);
        complete(&mut active, "s1", 5, 2_000);
        let rest_until = active.completed_sets[0].rest_until;
        assert!(rest_until > 2_000, "the completed set should carry a rest");
        // Well past the rest.
        let snap = workout_state_snapshot_from_state(
            &active.proposed_sets,
            &active.completed_sets,
            rest_until + 500,
        );
        assert_eq!(snap.state, STATE_READY);
        assert_eq!(snap.display_set.unwrap().id, "s2");
        assert_eq!(snap.last_rest_end, rest_until,
            "READY must carry the rest-end so yapping persists across reloads");
    }

    #[test]
    fn snapshot_walks_ready_lifting_resting_done() {
        // Two sets so RESTING is genuinely reachable (rest happens *before* the
        // next set). A single-set workout would jump straight to ALL_DONE after
        // the last set — there is nothing to rest for.
        let mut active =
            active_with(vec![proposed("s1", 0, false), proposed("s2", 1, false)]);

        let snap = workout_state_snapshot_from_state(&active.proposed_sets, &active.completed_sets, 1_000);
        assert_eq!(snap.state, STATE_READY);
        assert_eq!(snap.display_set.unwrap().id, "s1");

        start(&mut active, "s1", 2_000);
        let snap = workout_state_snapshot_from_state(&active.proposed_sets, &active.completed_sets, 2_010);
        assert_eq!(snap.state, STATE_LIFTING);
        assert_eq!(snap.active_started_at, 2_000);

        // Finish set 1: resting before set 2, focused on set 2.
        complete(&mut active, "s1", 5, 2_040);
        let snap = workout_state_snapshot_from_state(&active.proposed_sets, &active.completed_sets, 2_050);
        assert_eq!(snap.state, STATE_RESTING);
        assert_eq!(snap.display_set.unwrap().id, "s2");

        // Rest expires: set 2 is ready.
        let snap = workout_state_snapshot_from_state(&active.proposed_sets, &active.completed_sets, 9_000);
        assert_eq!(snap.state, STATE_READY);
        assert_eq!(snap.display_set.unwrap().id, "s2");

        // Finish the final set: done immediately, no lingering rest state that
        // could re-offer the just-finished set (dev regression: the last set was
        // logged 10× because rest fell back to it).
        start(&mut active, "s2", 9_100);
        complete(&mut active, "s2", 5, 9_140);
        let snap = workout_state_snapshot_from_state(&active.proposed_sets, &active.completed_sets, 9_150);
        assert_eq!(snap.state, STATE_ALL_DONE, "after the final set there is nothing to rest for");
        assert!(snap.display_set.is_none());
    }

    #[test]
    fn cancelled_sets_do_not_hold_the_workout_open() {
        let mut sets = vec![proposed("s1", 0, true), proposed("s2", 1, false)];
        sets[0].cancelled = true;
        let mut active = active_with(sets);
        complete(&mut active, "s2", 5, 2_000);

        let snap = workout_state_snapshot_from_state(&active.proposed_sets, &active.completed_sets, 9_000);
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
}
