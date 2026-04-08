use super::*;

pub(super) fn active_proposed_sets(proposed_sets: &[ProposedSet]) -> Vec<ProposedSet> {
    proposed_sets
        .iter()
        .filter(|set| !set.cancelled)
        .cloned()
        .collect()
}

pub(super) fn workout_plan_change_stats_from_sets(
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

pub(super) fn next_up_from_workout_state(
    proposed_sets: &[ProposedSet],
    completed_sets: &[CompletedSet],
) -> Option<ProposedSet> {
    compute_next_up_set(proposed_sets, completed_sets)
}

pub(super) fn is_final_set_in_exercise_group_after_completion(
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

pub(super) fn now_unix() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

pub(super) fn workout_state_snapshot_from_state(
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

pub(super) fn start_workout_response_from_active(active: &ActiveWorkout) -> StartWorkoutResponse {
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

pub(super) fn get_workout_response_from_active(active: &ActiveWorkout) -> GetWorkoutResponse {
    let proposed_sets = active_proposed_sets(&active.proposed_sets);
    let completed_sets = active.completed_sets.clone();
    let next_up_set = compute_next_up_set(&proposed_sets, &completed_sets);
    let state_snapshot = Some(workout_state_snapshot_from_state(
        &active.proposed_sets,
        &completed_sets,
        now_unix(),
    ));

    GetWorkoutResponse {
        workout: Some(active.workout.clone()),
        exercise_groups: active.exercise_groups.clone(),
        proposed_sets,
        completed_sets,
        next_up_set,
        plan_change_stats: Some(workout_plan_change_stats_from_sets(&active.proposed_sets)),
        state_snapshot,
    }
}

pub(super) fn checkpoint_event_from_active(
    user_id: &str,
    active: &ActiveWorkout,
) -> WorkoutEventRecord {
    let payload = get_workout_response_from_active(active).encode_to_vec();
    WorkoutEventRecord {
        event_id: Uuid::new_v4().to_string(),
        user_id: user_id.to_string(),
        workout_id: active.workout.id.clone(),
        recorded_at: now_unix(),
        event_type: WorkoutEventType::Checkpoint,
        payload,
    }
}

fn active_from_get_workout_response(resp: GetWorkoutResponse) -> Result<ActiveWorkout, Status> {
    let workout = resp
        .workout
        .ok_or_else(|| Status::internal("Checkpoint missing workout"))?;
    Ok(ActiveWorkout::new(
        workout,
        resp.exercise_groups,
        resp.proposed_sets,
        resp.completed_sets,
    ))
}

pub(super) fn apply_start_set_to_active(
    workout_ref: &mut ActiveWorkout,
    req: &StartSetRequest,
) -> Result<(), Status> {
    if workout_ref.workout.id != req.workout_id {
        return Err(Status::failed_precondition("Workout ID mismatch"));
    }
    let proposed = workout_ref
        .proposed_sets
        .iter()
        .find(|p| p.id == req.proposed_set_id && !p.cancelled);
    if proposed.is_none() {
        return Err(Status::failed_precondition("Proposed set not available"));
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

pub(super) fn apply_complete_set_to_active(
    workout_ref: &mut ActiveWorkout,
    req: &CompleteSetRequest,
) -> Result<(), Status> {
    if workout_ref.workout.id != req.workout_id {
        return Err(Status::failed_precondition("Workout ID mismatch"));
    }
    let proposed = workout_ref
        .proposed_sets
        .iter()
        .find(|p| p.id == req.proposed_set_id && !p.cancelled)
        .cloned()
        .ok_or_else(|| Status::failed_precondition("Proposed set not available"))?;
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

pub(super) fn apply_delete_completed_set_to_active(
    workout_ref: &mut ActiveWorkout,
    req: &DeleteCompletedSetRequest,
) -> Result<(), Status> {
    if workout_ref.workout.id != req.workout_id {
        return Err(Status::failed_precondition("Workout ID mismatch"));
    }
    workout_ref
        .completed_sets
        .retain(|c| !(c.workout_id == req.workout_id && c.id == req.completed_set_id));
    Ok(())
}

pub(super) fn apply_cancel_proposed_set_to_active(
    workout_ref: &mut ActiveWorkout,
    req: &CancelProposedSetRequest,
) -> Result<(), Status> {
    if workout_ref.workout.id != req.workout_id {
        return Err(Status::failed_precondition("Workout ID mismatch"));
    }
    let proposed_idx = workout_ref
        .proposed_sets
        .iter()
        .position(|set| {
            set.workout_id == req.workout_id && set.id == req.proposed_set_id && !set.cancelled
        })
        .ok_or_else(|| Status::not_found("Proposed set not found"))?;
    if !workout_ref.proposed_sets[proposed_idx].warmup {
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
    Ok(())
}

fn apply_end_workout_to_active(
    workout_ref: &mut ActiveWorkout,
    req: &EndWorkoutRequest,
) -> Result<(), Status> {
    if workout_ref.workout.id != req.workout_id {
        return Err(Status::failed_precondition("Workout ID mismatch"));
    }
    workout_ref.workout.end_time = if req.ended_at > 0 {
        req.ended_at
    } else {
        now_unix()
    };
    Ok(())
}

pub(super) fn replay_workout_events(
    events: &[WorkoutEventRecord],
) -> Result<ActiveWorkout, Status> {
    let checkpoint_idx = events
        .iter()
        .enumerate()
        .rev()
        .find(|(_, ev)| ev.event_type == WorkoutEventType::Checkpoint)
        .map(|(idx, _)| idx)
        .ok_or_else(|| Status::not_found("No workout checkpoint event found"))?;

    let checkpoint = GetWorkoutResponse::decode(events[checkpoint_idx].payload.as_slice())
        .map_err(|e| Status::internal(format!("Invalid checkpoint payload: {}", e)))?;
    let mut active = active_from_get_workout_response(checkpoint)?;

    for event in events.iter().skip(checkpoint_idx + 1) {
        match event.event_type {
            WorkoutEventType::Checkpoint => {
                let checkpoint = GetWorkoutResponse::decode(event.payload.as_slice())
                    .map_err(|e| Status::internal(format!("Invalid checkpoint payload: {}", e)))?;
                active = active_from_get_workout_response(checkpoint)?;
            }
            WorkoutEventType::StartSet => {
                let req = StartSetRequest::decode(event.payload.as_slice())
                    .map_err(|e| Status::internal(format!("Invalid start-set payload: {}", e)))?;
                apply_start_set_to_active(&mut active, &req)?;
            }
            WorkoutEventType::CompleteSet => {
                let req = CompleteSetRequest::decode(event.payload.as_slice()).map_err(|e| {
                    Status::internal(format!("Invalid complete-set payload: {}", e))
                })?;
                apply_complete_set_to_active(&mut active, &req)?;
            }
            WorkoutEventType::DeleteCompletedSet => {
                let req = DeleteCompletedSetRequest::decode(event.payload.as_slice())
                    .map_err(|e| Status::internal(format!("Invalid delete-set payload: {}", e)))?;
                apply_delete_completed_set_to_active(&mut active, &req)?;
            }
            WorkoutEventType::CancelProposedSet => {
                let req = CancelProposedSetRequest::decode(event.payload.as_slice())
                    .map_err(|e| Status::internal(format!("Invalid cancel-set payload: {}", e)))?;
                apply_cancel_proposed_set_to_active(&mut active, &req)?;
            }
            WorkoutEventType::EndWorkout => {
                let req = EndWorkoutRequest::decode(event.payload.as_slice())
                    .map_err(|e| Status::internal(format!("Invalid end-workout payload: {}", e)))?;
                apply_end_workout_to_active(&mut active, &req)?;
            }
            WorkoutEventType::ReplaceExerciseGroupPlan => {
                let req = ReplaceExerciseGroupPlanRequest::decode(event.payload.as_slice())
                    .map_err(|e| {
                        Status::internal(format!("Invalid replace-group payload: {}", e))
                    })?;
                let _ = apply_replace_exercise_group_plan(&mut active, &req)?;
            }
            WorkoutEventType::ReorderExerciseGroups => {
                let req = ReorderExerciseGroupsRequest::decode(event.payload.as_slice()).map_err(
                    |e| Status::internal(format!("Invalid reorder-groups payload: {}", e)),
                )?;
                apply_reorder_exercise_groups(&mut active, &req)?;
            }
        }
    }

    Ok(active)
}

pub(super) fn build_workout_completion_result(
    proposed_sets: &[ProposedSet],
    completed_sets: &[CompletedSet],
) -> WorkoutCompletionResult {
    let mut set_results = Vec::new();
    for cs in completed_sets {
        let Some(ps) = proposed_sets.iter().find(|p| p.id == cs.proposed_set_id) else {
            continue;
        };
        if ps.warmup || ps.cancelled {
            continue;
        }
        let hint = ps.progression_hint.clone().unwrap_or_default();
        set_results.push(WorkingSetResult {
            exercise: schlift::workout::v1::Exercise::try_from(ps.exercise)
                .unwrap_or(schlift::workout::v1::Exercise::Unspecified),
            target_reps: ps.target_reps,
            actual_reps: cs.actual_reps,
            target_weight: ps.target_weight,
            actual_weight: cs.actual_weight,
            is_amrap: ps.is_amrap,
            progression_slot_key: hint.slot_key,
            progression_tier: hint.tier,
            progression_rule: schlift::workout::v1::ProgressionRule::try_from(hint.rule)
                .unwrap_or(schlift::workout::v1::ProgressionRule::Unspecified),
            amrap_success_threshold: hint.amrap_success_threshold,
            counts_toward_program: hint.counts_toward_program,
        });
    }
    WorkoutCompletionResult { set_results }
}
