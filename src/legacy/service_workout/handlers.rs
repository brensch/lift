use super::*;
use crate::db::{WorkoutMutationDbOp, WorkoutMutationPersist};
use crate::multiplayer_current::{
    participant_status_from_active, publish_current_session_snapshot,
    publish_current_session_snapshot_from_state,
};
use schlift::workout::v1::{ParticipantStatus, User, WorkoutMutation};
use tracing::info;

#[derive(Clone)]
struct PendingMutation {
    event_id: String,
    workout_id: String,
    event_type: WorkoutEventType,
    payload: Vec<u8>,
    db_op: Option<WorkoutMutationDbOp>,
}

fn mutation_kind_name(mutation: &WorkoutMutation) -> &'static str {
    match mutation.mutation.as_ref() {
        Some(workout_mutation::Mutation::StartSet(_)) => "start_set",
        Some(workout_mutation::Mutation::CompleteSet(_)) => "complete_set",
        Some(workout_mutation::Mutation::CancelProposedSet(_)) => "cancel_proposed_set",
        Some(workout_mutation::Mutation::DeleteCompletedSet(_)) => "delete_completed_set",
        Some(workout_mutation::Mutation::EndWorkout(_)) => "end_workout",
        Some(workout_mutation::Mutation::ReplaceExerciseGroupPlan(_)) => {
            "replace_exercise_group_plan"
        }
        Some(workout_mutation::Mutation::ReorderExerciseGroups(_)) => "reorder_exercise_groups",
        None => "missing",
    }
}

fn is_stale_local_mutation_error(status: &Status) -> bool {
    matches!(
        status.code(),
        tonic::Code::FailedPrecondition | tonic::Code::NotFound
    )
}

fn apply_event_to_active(
    trial: &mut ActiveWorkout,
    event_type: WorkoutEventType,
    payload: &[u8],
) -> Result<(), Status> {
    match event_type {
        WorkoutEventType::StartSet => {
            let decoded = StartSetRequest::decode(payload).map_err(|e| {
                Status::internal(format!("Could not decode start-set payload: {}", e))
            })?;
            apply_start_set_to_active(trial, &decoded)
        }
        WorkoutEventType::CompleteSet => {
            let decoded = CompleteSetRequest::decode(payload).map_err(|e| {
                Status::internal(format!("Could not decode complete-set payload: {}", e))
            })?;
            apply_complete_set_to_active(trial, &decoded)
        }
        WorkoutEventType::DeleteCompletedSet => {
            let decoded = DeleteCompletedSetRequest::decode(payload).map_err(|e| {
                Status::internal(format!("Could not decode delete-set payload: {}", e))
            })?;
            apply_delete_completed_set_to_active(trial, &decoded)
        }
        WorkoutEventType::CancelProposedSet => {
            let decoded = CancelProposedSetRequest::decode(payload).map_err(|e| {
                Status::internal(format!("Could not decode cancel-set payload: {}", e))
            })?;
            apply_cancel_proposed_set_to_active(trial, &decoded)
        }
        WorkoutEventType::ReplaceExerciseGroupPlan => {
            let decoded = ReplaceExerciseGroupPlanRequest::decode(payload).map_err(|e| {
                Status::internal(format!("Could not decode replace-group payload: {}", e))
            })?;
            apply_replace_exercise_group_plan(trial, &decoded).map(|_| ())
        }
        WorkoutEventType::ReorderExerciseGroups => {
            let decoded = ReorderExerciseGroupsRequest::decode(payload).map_err(|e| {
                Status::internal(format!("Could not decode reorder-groups payload: {}", e))
            })?;
            apply_reorder_exercise_groups(trial, &decoded)
        }
        _ => Err(Status::invalid_argument("unsupported mutation type")),
    }
}

fn db_op_from_trial(
    trial: &ActiveWorkout,
    event_type: WorkoutEventType,
    payload: &[u8],
) -> Result<Option<WorkoutMutationDbOp>, Status> {
    match event_type {
        WorkoutEventType::StartSet | WorkoutEventType::CompleteSet => {
            let proposed_set_id = if event_type == WorkoutEventType::StartSet {
                StartSetRequest::decode(payload)
                    .map_err(|e| {
                        Status::internal(format!("Could not decode start-set payload: {}", e))
                    })?
                    .proposed_set_id
            } else {
                CompleteSetRequest::decode(payload)
                    .map_err(|e| {
                        Status::internal(format!("Could not decode complete-set payload: {}", e))
                    })?
                    .proposed_set_id
            };
            let set = trial
                .completed_sets
                .iter()
                .filter(|set| set.proposed_set_id == proposed_set_id)
                .max_by_key(|set| (set.started_at, set.ended_at))
                .cloned()
                .ok_or_else(|| {
                    Status::failed_precondition("Completed set missing after mutation")
                })?;
            Ok(Some(WorkoutMutationDbOp::UpsertCompletedSet(set)))
        }
        WorkoutEventType::DeleteCompletedSet => {
            let decoded = DeleteCompletedSetRequest::decode(payload).map_err(|e| {
                Status::internal(format!("Could not decode delete-set payload: {}", e))
            })?;
            Ok(Some(WorkoutMutationDbOp::DeleteCompletedSet {
                workout_id: decoded.workout_id,
                completed_set_id: decoded.completed_set_id,
            }))
        }
        WorkoutEventType::CancelProposedSet => {
            let decoded = CancelProposedSetRequest::decode(payload).map_err(|e| {
                Status::internal(format!("Could not decode cancel-set payload: {}", e))
            })?;
            Ok(Some(WorkoutMutationDbOp::CancelProposedSet {
                workout_id: decoded.workout_id,
                proposed_set_id: decoded.proposed_set_id,
            }))
        }
        WorkoutEventType::ReplaceExerciseGroupPlan | WorkoutEventType::ReorderExerciseGroups => {
            Ok(None)
        }
        _ => Err(Status::invalid_argument("unsupported mutation type")),
    }
}

fn active_session_id_for_user(state: &AppState, user_id: &str) -> Option<String> {
    state
        .user_sessions
        .get(user_id)
        .map(|s| s.clone())
        .or_else(|| {
            state.workouts.get(user_id).and_then(|w| {
                (!w.workout.session_id.is_empty()).then(|| w.workout.session_id.clone())
            })
        })
}

#[tonic::async_trait]
impl WorkoutService for MyWorkoutService {
    async fn start_workout(
        &self,
        request: Request<StartWorkoutRequest>,
    ) -> Result<Response<StartWorkoutResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        // Lazy crash recovery: check CentralDb once per user for un-ended workouts
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        // Check for existing active workout
        if let Some(active) = self.state.workouts.get(&user_id) {
            if active.workout.end_time == 0 {
                // Workout is still running, return it
                return Ok(Response::new(start_workout_response_from_active(&active)));
            } else {
                // Workout is finished, remove it from memory so we can start a new one
                drop(active); // Release lock
                self.state.workouts.remove(&user_id);
            }
        }

        let workout_id = Uuid::new_v4().to_string();
        let start_time = if req.started_at > 0 {
            req.started_at
        } else {
            now_unix()
        };

        let session_id = {
            let mut session_id = self
                .state
                .user_sessions
                .get(&user_id)
                .map(|s| s.clone())
                .unwrap_or_default();

            if session_id.is_empty() {
                // Every workout must belong to a session. Generate one if needed.
                session_id = Uuid::new_v4().to_string();
                self.state
                    .user_sessions
                    .insert(user_id.clone(), session_id.clone());
                let mut members = std::collections::HashSet::new();
                members.insert(user_id.clone());
                self.state.sessions.insert(session_id.clone(), members);
            }
            session_id
        };

        let workout = Workout {
            id: workout_id.clone(),
            name: req.name.clone(),
            start_time,
            end_time: 0,
            session_id,
        };

        // Assign workout_id to exercise_groups and generate sets server-side
        let mut exercise_groups = req.exercise_groups;
        let mut all_proposed_sets = Vec::new();
        let mut set_order = 0i32;

        for g in &mut exercise_groups {
            g.workout_id = workout_id.clone();
            if g.id.is_empty() {
                g.id = Uuid::new_v4().to_string();
            }
            materialize_group_working_sets(g);
            let generated = generate_sets_for_group(&workout_id, g, set_order);
            set_order += generated.len() as i32;
            all_proposed_sets.extend(generated);
        }

        // Store in memory
        let mut active = ActiveWorkout::new(workout, exercise_groups, all_proposed_sets, vec![]);
        active.reindex_sets();
        let response = start_workout_response_from_active(&active);
        let workout_response = get_workout_response_from_active(&active);
        let participant_user = self
            .state
            .users
            .get(&user_id)
            .map(|u| u.clone())
            .unwrap_or(User {
                id: user_id.clone(),
                name: String::new(),
                created_at: 0,
            });
        let participant_status = participant_status_from_active(&participant_user, &active);

        let checkpoint_event = checkpoint_event_from_active(&user_id, &active);
        self.central_db
            .persist_new_workout_with_checkpoint(
                &user_id,
                &active.workout,
                &active.exercise_groups,
                &active.proposed_sets,
                &checkpoint_event,
                &workout_response,
                Some((active.workout.session_id.as_str(), &participant_status)),
            )
            .await
            .map_err(|e| {
                Status::internal(format!(
                    "Failed to persist new workout transactionally: {}",
                    e
                ))
            })?;

        self.state.workouts.insert(user_id.clone(), active);
        if let Some(session_id) = active_session_id_for_user(&self.state, &user_id) {
            publish_current_session_snapshot_from_state(&self.state, &session_id)?;
        }

        Ok(Response::new(response))
    }

    async fn get_workout(
        &self,
        request: Request<GetWorkoutRequest>,
    ) -> Result<Response<GetWorkoutResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        if req.workout_id.is_empty() {
            return Err(Status::invalid_argument("workout_id is required"));
        }

        // Check in-memory first - clone data to release lock
        let cached = self.state.workouts.get(&user_id).and_then(|w| {
            if w.workout.id == req.workout_id {
                Some((
                    w.workout.clone(),
                    w.exercise_groups.clone(),
                    w.proposed_sets.clone(),
                    w.completed_sets.clone(),
                ))
            } else {
                None
            }
        });

        if let Some((workout, groups, proposed, _)) = cached {
            // Use the in-memory copy of the caller's workout state for read-after-write
            // consistency. DB writes are queued asynchronously, so re-reading only from
            // SQLite here can briefly resurrect deleted/unfinished sets.
            let mut completed_sets = self
                .state
                .workouts
                .get(&user_id)
                .map(|w| w.completed_sets.clone())
                .unwrap_or_default();

            // If this workout is part of a shared session, merge in other participants'
            // completed sets from the DB so the caller still sees the session ledger.
            if !workout.session_id.is_empty() {
                let session_completed = self
                    .central_db
                    .get_completed_sets_by_session(&workout.session_id)
                    .await
                    .map_err(|e| Status::internal(format!("Failed to get session sets: {}", e)))?;
                completed_sets.extend(
                    session_completed
                        .into_iter()
                        .filter(|c| c.workout_id != workout.id),
                );
            }

            let own_completed = completed_sets
                .iter()
                .filter(|c| c.workout_id == workout.id)
                .cloned()
                .collect::<Vec<_>>();

            let proposed_active = active_proposed_sets(&proposed);
            let next_up_set = compute_next_up_set(&proposed_active, &own_completed);
            let plan_change_stats = Some(workout_plan_change_stats_from_sets(&proposed));
            let state_snapshot = Some(workout_state_snapshot_from_state(
                &proposed,
                &own_completed,
                now_unix(),
            ));

            return Ok(Response::new(GetWorkoutResponse {
                workout: Some(workout),
                exercise_groups: groups,
                proposed_sets: proposed,
                completed_sets,
                next_up_set,
                plan_change_stats,
                state_snapshot,
            }));
        }

        // Fall back to CentralDb for historical workouts
        let workout = self
            .central_db
            .get_workout(&user_id, &req.workout_id)
            .await
            .map_err(|e| Status::internal(format!("Failed to get workout: {}", e)))?
            .ok_or_else(|| Status::not_found("Workout not found"))?;

        let exercise_groups = self
            .central_db
            .get_exercise_groups(&user_id, &req.workout_id)
            .await
            .map_err(|e| Status::internal(format!("Failed to get exercise groups: {}", e)))?;

        let proposed_sets = self
            .central_db
            .get_proposed_sets(&user_id, &req.workout_id)
            .await
            .map_err(|e| Status::internal(format!("Failed to get proposed sets: {}", e)))?;

        let completed_sets = if !workout.session_id.is_empty() {
            self.central_db
                .get_completed_sets_by_session(&workout.session_id)
                .await
                .map_err(|e| Status::internal(format!("Failed to get session sets: {}", e)))?
        } else {
            self.central_db
                .get_completed_sets(&user_id, &req.workout_id)
                .await
                .map_err(|e| Status::internal(format!("Failed to get completed sets: {}", e)))?
        };

        // For state snapshot and next-up, only use the current user's own completed sets.
        let own_completed: Vec<CompletedSet> = completed_sets
            .iter()
            .filter(|c| c.workout_id == req.workout_id)
            .cloned()
            .collect();

        let proposed_active = active_proposed_sets(&proposed_sets);
        let next_up_set = compute_next_up_set(&proposed_active, &own_completed);
        let plan_change_stats = Some(workout_plan_change_stats_from_sets(&proposed_sets));
        let state_snapshot = Some(workout_state_snapshot_from_state(
            &proposed_sets,
            &own_completed,
            now_unix(),
        ));

        Ok(Response::new(GetWorkoutResponse {
            workout: Some(workout),
            exercise_groups,
            proposed_sets,
            completed_sets,
            next_up_set,
            plan_change_stats,
            state_snapshot,
        }))
    }

    async fn replace_exercise_group_plan(
        &self,
        request: Request<ReplaceExerciseGroupPlanRequest>,
    ) -> Result<Response<ReplaceExerciseGroupPlanResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        let (group, group_sets, full_workout_state, next_up_set, state_snapshot) = {
            let mut workout_ref = self
                .state
                .workouts
                .get_mut(&user_id)
                .ok_or_else(|| Status::failed_precondition("No active workout"))?;

            let (group, group_sets) = apply_replace_exercise_group_plan(&mut workout_ref, &req)?;

            let full_state = (
                workout_ref.workout.clone(),
                workout_ref.exercise_groups.clone(),
                workout_ref.proposed_sets.clone(),
                workout_ref.completed_sets.clone(),
            );
            let next_up_set =
                next_up_from_workout_state(&workout_ref.proposed_sets, &workout_ref.completed_sets);
            let state_snapshot = workout_state_snapshot_from_state(
                &workout_ref.proposed_sets,
                &workout_ref.completed_sets,
                now_unix(),
            );

            (group, group_sets, full_state, next_up_set, state_snapshot)
        }; // Guard dropped here

        // Re-sync this workout to DB
        self.central_db
            .flush_workout(
                &user_id,
                &full_workout_state.0,
                &full_workout_state.1,
                &full_workout_state.2,
                &full_workout_state.3,
            )
            .await
            .map_err(|e| Status::internal(e.to_string()))?;

        self.log_delta_event(
            &user_id,
            &req.workout_id,
            WorkoutEventType::ReplaceExerciseGroupPlan,
            &req,
        )
        .await?;
        if let Some(session_id) = active_session_id_for_user(&self.state, &user_id) {
            publish_current_session_snapshot_from_state(&self.state, &session_id)?;
        }

        Ok(Response::new(ReplaceExerciseGroupPlanResponse {
            group,
            generated_sets: group_sets,
            next_up_set,
            state_snapshot: Some(state_snapshot),
        }))
    }

    async fn reorder_exercise_groups(
        &self,
        request: Request<ReorderExerciseGroupsRequest>,
    ) -> Result<Response<ReorderExerciseGroupsResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        let (full_workout_state, next_up_set, state_snapshot) = {
            let mut workout_ref = self
                .state
                .workouts
                .get_mut(&user_id)
                .ok_or_else(|| Status::failed_precondition("No active workout"))?;

            apply_reorder_exercise_groups(&mut workout_ref, &req)?;

            let full_state = (
                workout_ref.workout.clone(),
                workout_ref.exercise_groups.clone(),
                workout_ref.proposed_sets.clone(),
                workout_ref.completed_sets.clone(),
            );
            let next_up_set =
                next_up_from_workout_state(&workout_ref.proposed_sets, &workout_ref.completed_sets);
            let state_snapshot = workout_state_snapshot_from_state(
                &workout_ref.proposed_sets,
                &workout_ref.completed_sets,
                now_unix(),
            );
            (full_state, next_up_set, state_snapshot)
        }; // Guard dropped here

        // Re-sync to DB
        self.central_db
            .flush_workout(
                &user_id,
                &full_workout_state.0,
                &full_workout_state.1,
                &full_workout_state.2,
                &full_workout_state.3,
            )
            .await
            .map_err(|e| Status::internal(e.to_string()))?;

        self.log_delta_event(
            &user_id,
            &req.workout_id,
            WorkoutEventType::ReorderExerciseGroups,
            &req,
        )
        .await?;
        if let Some(session_id) = active_session_id_for_user(&self.state, &user_id) {
            publish_current_session_snapshot_from_state(&self.state, &session_id)?;
        }

        Ok(Response::new(ReorderExerciseGroupsResponse {
            next_up_set,
            state_snapshot: Some(state_snapshot),
        }))
    }

    async fn list_workouts(
        &self,
        request: Request<ListWorkoutsRequest>,
    ) -> Result<Response<ListWorkoutsResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;

        // 1. Get active workout while holding the lock
        let active_workout = self.state.workouts.get(&user_id).map(|w| w.workout.clone());

        // 2. Perform DB IO outside the lock
        let mut workouts = self
            .central_db
            .list_workouts(&user_id)
            .await
            .map_err(|e| Status::internal(format!("Failed to list workouts: {}", e)))?;

        // If there's an active workout in memory, make sure it's in the list
        if let Some(active) = active_workout {
            if !workouts.iter().any(|existing| existing.id == active.id) {
                workouts.insert(0, active);
            }
        }

        Ok(Response::new(ListWorkoutsResponse { workouts }))
    }

    async fn start_set(
        &self,
        request: Request<StartSetRequest>,
    ) -> Result<Response<StartSetResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        if req.workout_id.is_empty() {
            return Err(Status::invalid_argument("workout_id is required"));
        }
        if req.proposed_set_id.is_empty() {
            return Err(Status::invalid_argument("proposed_set_id is required"));
        }

        let (completed_set, next_up_set, state_snapshot) = {
            let mut workout_ref = self
                .state
                .workouts
                .get_mut(&user_id)
                .ok_or_else(|| Status::failed_precondition("No active workout"))?;

            let proposed = workout_ref
                .proposed_sets
                .iter()
                .find(|p| p.id == req.proposed_set_id && !p.cancelled);
            if proposed.is_none() {
                return Err(Status::failed_precondition("Proposed set not available"));
            }

            let (actual_reps, actual_weight) = proposed
                .map(|p| (p.target_reps, p.target_weight))
                .unwrap_or((0, 0.0));

            let id = Uuid::new_v4().to_string();
            let started_at = if req.started_at > 0 {
                req.started_at
            } else {
                now_unix()
            };

            let completed_set = CompletedSet {
                id,
                workout_id: req.workout_id.clone(),
                proposed_set_id: req.proposed_set_id.clone(),
                actual_reps,
                actual_weight,
                started_at,
                ended_at: 0,
                rest_until: 0,
            };

            workout_ref.completed_sets.push(completed_set.clone());
            let next_up_set =
                next_up_from_workout_state(&workout_ref.proposed_sets, &workout_ref.completed_sets);
            let state_snapshot = workout_state_snapshot_from_state(
                &workout_ref.proposed_sets,
                &workout_ref.completed_sets,
                now_unix(),
            );
            (completed_set, next_up_set, state_snapshot)
        }; // Guard dropped here

        // Incremental write: save to DB
        self.central_db
            .upsert_completed_set(&user_id, &completed_set)
            .await
            .map_err(|e| Status::internal(format!("Failed to save set to DB: {}", e)))?;

        let logged_req = StartSetRequest {
            workout_id: req.workout_id.clone(),
            proposed_set_id: req.proposed_set_id.clone(),
            started_at: completed_set.started_at,
        };
        self.log_delta_event(
            &user_id,
            &req.workout_id,
            WorkoutEventType::StartSet,
            &logged_req,
        )
        .await?;
        if let Some(session_id) = active_session_id_for_user(&self.state, &user_id) {
            publish_current_session_snapshot_from_state(&self.state, &session_id)?;
        }

        Ok(Response::new(StartSetResponse {
            completed_set: Some(completed_set),
            next_up_set,
            state_snapshot: Some(state_snapshot),
        }))
    }

    async fn complete_set(
        &self,
        request: Request<CompleteSetRequest>,
    ) -> Result<Response<CompleteSetResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        if req.workout_id.is_empty() {
            return Err(Status::invalid_argument("workout_id is required"));
        }
        if req.proposed_set_id.is_empty() {
            return Err(Status::invalid_argument("proposed_set_id is required"));
        }

        let now = now_unix();
        let ended_at = if req.completed_at > 0 {
            if (now - req.completed_at).abs() > 30 {
                return Err(Status::invalid_argument(
                    "completed_at must be within 30 seconds of server time",
                ));
            }
            req.completed_at
        } else {
            now
        };

        let (completed_set, next_up_set, state_snapshot) = {
            let mut workout_ref = self
                .state
                .workouts
                .get_mut(&user_id)
                .ok_or_else(|| Status::failed_precondition("No active workout"))?;

            // Look up proposed set info for rest computation
            let proposed = workout_ref
                .proposed_sets
                .iter()
                .find(|p| p.id == req.proposed_set_id && !p.cancelled)
                .cloned()
                .ok_or_else(|| Status::failed_precondition("Proposed set not available"))?;

            let is_final_set_in_group = is_final_set_in_exercise_group_after_completion(
                &req.proposed_set_id,
                &workout_ref.proposed_sets,
                &workout_ref.completed_sets,
            );

            let (target_reps, rest_s, rest_f) = (
                proposed.target_reps,
                proposed.rest_after_success,
                proposed.rest_after_failure,
            );

            let mut rest_seconds = if req.actual_reps >= target_reps {
                rest_s as i64
            } else {
                rest_f as i64
            };
            if is_final_set_in_group {
                rest_seconds = END_OF_EXERCISE_GROUP_REST_SECONDS;
            }
            // Keep recorded completion time from client event, but start rest from
            // server "now" so debounce/network delay doesn't consume rest duration.
            let rest_base = ended_at.max(now_unix());
            let rest_until = rest_base + rest_seconds;

            // Find existing started set or create new
            let existing_idx = workout_ref.completed_sets.iter().position(|c| {
                c.workout_id == req.workout_id
                    && c.proposed_set_id == req.proposed_set_id
                    && c.ended_at == 0
            });

            let completed_set = if let Some(idx) = existing_idx {
                let cs = &mut workout_ref.completed_sets[idx];
                cs.actual_reps = req.actual_reps;
                cs.actual_weight = req.actual_weight;
                cs.ended_at = ended_at;
                cs.rest_until = rest_until;
                cs.clone()
            } else {
                let cs = CompletedSet {
                    id: Uuid::new_v4().to_string(),
                    workout_id: req.workout_id.clone(),
                    proposed_set_id: req.proposed_set_id.clone(),
                    actual_reps: req.actual_reps,
                    actual_weight: req.actual_weight,
                    started_at: ended_at,
                    ended_at,
                    rest_until,
                };
                workout_ref.completed_sets.push(cs.clone());
                cs
            };
            let next_up_set =
                next_up_from_workout_state(&workout_ref.proposed_sets, &workout_ref.completed_sets);
            let state_snapshot = workout_state_snapshot_from_state(
                &workout_ref.proposed_sets,
                &workout_ref.completed_sets,
                now_unix(),
            );
            (completed_set, next_up_set, state_snapshot)
        }; // Guard dropped here

        // Incremental write: save to DB
        self.central_db
            .upsert_completed_set(&user_id, &completed_set)
            .await
            .map_err(|e| Status::internal(format!("Failed to save completed set to DB: {}", e)))?;

        let logged_req = CompleteSetRequest {
            workout_id: req.workout_id.clone(),
            proposed_set_id: req.proposed_set_id.clone(),
            actual_reps: req.actual_reps,
            actual_weight: req.actual_weight,
            completed_at: completed_set.ended_at,
        };
        self.log_delta_event(
            &user_id,
            &req.workout_id,
            WorkoutEventType::CompleteSet,
            &logged_req,
        )
        .await?;
        if let Some(session_id) = active_session_id_for_user(&self.state, &user_id) {
            publish_current_session_snapshot_from_state(&self.state, &session_id)?;
        }

        Ok(Response::new(CompleteSetResponse {
            completed_set: Some(completed_set),
            next_up_set,
            state_snapshot: Some(state_snapshot),
        }))
    }

    async fn delete_completed_set(
        &self,
        request: Request<DeleteCompletedSetRequest>,
    ) -> Result<Response<DeleteCompletedSetResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        if req.workout_id.is_empty() {
            return Err(Status::invalid_argument("workout_id is required"));
        }
        if req.completed_set_id.is_empty() {
            return Err(Status::invalid_argument("completed_set_id is required"));
        }

        let (next_up_set, state_snapshot) = {
            let mut workout_ref = self
                .state
                .workouts
                .get_mut(&user_id)
                .ok_or_else(|| Status::failed_precondition("No active workout"))?;

            workout_ref
                .completed_sets
                .retain(|c| !(c.workout_id == req.workout_id && c.id == req.completed_set_id));
            let next_up_set =
                next_up_from_workout_state(&workout_ref.proposed_sets, &workout_ref.completed_sets);
            let state_snapshot = workout_state_snapshot_from_state(
                &workout_ref.proposed_sets,
                &workout_ref.completed_sets,
                now_unix(),
            );
            (next_up_set, state_snapshot)
        }; // Guard dropped here

        // Incremental write: delete from DB
        self.central_db
            .delete_completed_set_record(&user_id, &req.workout_id, &req.completed_set_id)
            .await
            .map_err(|e| Status::internal(format!("Failed to delete set from DB: {}", e)))?;

        self.log_delta_event(
            &user_id,
            &req.workout_id,
            WorkoutEventType::DeleteCompletedSet,
            &req,
        )
        .await?;
        if let Some(session_id) = active_session_id_for_user(&self.state, &user_id) {
            publish_current_session_snapshot_from_state(&self.state, &session_id)?;
        }

        Ok(Response::new(DeleteCompletedSetResponse {
            next_up_set,
            state_snapshot: Some(state_snapshot),
        }))
    }

    async fn cancel_proposed_set(
        &self,
        request: Request<CancelProposedSetRequest>,
    ) -> Result<Response<CancelProposedSetResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        if req.workout_id.is_empty() {
            return Err(Status::invalid_argument("workout_id is required"));
        }
        if req.proposed_set_id.is_empty() {
            return Err(Status::invalid_argument("proposed_set_id is required"));
        }

        let (full_workout_state, next_up_set, state_snapshot) = {
            let mut workout_ref = self
                .state
                .workouts
                .get_mut(&user_id)
                .ok_or_else(|| Status::failed_precondition("No active workout"))?;

            let proposed_idx = workout_ref
                .proposed_sets
                .iter()
                .position(|set| {
                    set.workout_id == req.workout_id
                        && set.id == req.proposed_set_id
                        && !set.cancelled
                })
                .ok_or_else(|| Status::not_found("Proposed set not found"))?;

            let proposed = &workout_ref.proposed_sets[proposed_idx];
            if !proposed.warmup {
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

            let full_state = (
                workout_ref.workout.clone(),
                workout_ref.exercise_groups.clone(),
                workout_ref.proposed_sets.clone(),
                workout_ref.completed_sets.clone(),
            );
            let next_up_set =
                next_up_from_workout_state(&workout_ref.proposed_sets, &workout_ref.completed_sets);
            let state_snapshot = workout_state_snapshot_from_state(
                &workout_ref.proposed_sets,
                &workout_ref.completed_sets,
                now_unix(),
            );
            (full_state, next_up_set, state_snapshot)
        }; // Guard dropped here

        self.central_db
            .flush_workout(
                &user_id,
                &full_workout_state.0,
                &full_workout_state.1,
                &full_workout_state.2,
                &full_workout_state.3,
            )
            .await
            .map_err(|e| Status::internal(e.to_string()))?;

        self.log_delta_event(
            &user_id,
            &req.workout_id,
            WorkoutEventType::CancelProposedSet,
            &req,
        )
        .await?;
        if let Some(session_id) = active_session_id_for_user(&self.state, &user_id) {
            publish_current_session_snapshot_from_state(&self.state, &session_id)?;
        }

        Ok(Response::new(CancelProposedSetResponse {
            next_up_set,
            state_snapshot: Some(state_snapshot),
        }))
    }

    async fn append_workout_heart_rate(
        &self,
        request: Request<AppendWorkoutHeartRateRequest>,
    ) -> Result<Response<AppendWorkoutHeartRateResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        if req.workout_id.is_empty() {
            return Err(Status::invalid_argument("workout_id is required"));
        }
        if req.samples.is_empty() {
            return Ok(Response::new(AppendWorkoutHeartRateResponse { stored: 0 }));
        }

        {
            let active = self
                .state
                .workouts
                .get(&user_id)
                .ok_or_else(|| Status::failed_precondition("No active workout"))?;
            if active.workout.id != req.workout_id {
                return Err(Status::failed_precondition("Workout ID mismatch"));
            }
        }

        self.central_db
            .insert_workout_heart_rate_samples(&user_id, &req.workout_id, &req.samples)
            .await
            .map_err(|e| {
                Status::internal(format!("Failed to persist heart rate samples: {}", e))
            })?;

        Ok(Response::new(AppendWorkoutHeartRateResponse {
            stored: req.samples.len() as i32,
        }))
    }

    async fn append_workout_mutations(
        &self,
        request: Request<AppendWorkoutMutationsRequest>,
    ) -> Result<Response<AppendWorkoutMutationsResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        if req.mutations.is_empty() {
            return Err(Status::invalid_argument(
                "at least one mutation is required",
            ));
        }

        let batch_len = req.mutations.len();
        let first_workout_id = req
            .mutations
            .first()
            .and_then(|m| match m.mutation.as_ref() {
                Some(workout_mutation::Mutation::StartSet(r)) => Some(r.workout_id.as_str()),
                Some(workout_mutation::Mutation::CompleteSet(r)) => Some(r.workout_id.as_str()),
                Some(workout_mutation::Mutation::CancelProposedSet(r)) => {
                    Some(r.workout_id.as_str())
                }
                Some(workout_mutation::Mutation::DeleteCompletedSet(r)) => {
                    Some(r.workout_id.as_str())
                }
                Some(workout_mutation::Mutation::EndWorkout(r)) => Some(r.workout_id.as_str()),
                Some(workout_mutation::Mutation::ReplaceExerciseGroupPlan(r)) => {
                    Some(r.workout_id.as_str())
                }
                Some(workout_mutation::Mutation::ReorderExerciseGroups(r)) => {
                    Some(r.workout_id.as_str())
                }
                None => None,
            })
            .unwrap_or("");
        let mutation_kinds = req
            .mutations
            .iter()
            .map(mutation_kind_name)
            .collect::<Vec<_>>()
            .join(",");

        info!(
            sync_event = "append_workout_mutations",
            phase = "received",
            user_id = %user_id,
            workout_id = %first_workout_id,
            mutation_count = batch_len,
            mutation_kinds = %mutation_kinds
        );

        let base_workout = self
            .state
            .workouts
            .get(&user_id)
            .ok_or_else(|| Status::failed_precondition("No active workout"))?;
        if base_workout.workout.id != first_workout_id {
            return Err(Status::failed_precondition("Workout ID mismatch"));
        }
        let mut trial = base_workout.clone();
        drop(base_workout);

        let mut applied_event_ids = Vec::new();
        let mut pending = Vec::with_capacity(batch_len);
        let mut requires_full_flush = false;

        for mutation in req.mutations {
            if mutation.event_id.is_empty() {
                return Err(Status::invalid_argument("mutation event_id is required"));
            }

            let (workout_id, event_type, payload) = if let Some(
                workout_mutation::Mutation::StartSet(req),
            ) = mutation.mutation.clone()
            {
                let normalized = StartSetRequest {
                    workout_id: req.workout_id,
                    proposed_set_id: req.proposed_set_id,
                    started_at: if req.started_at > 0 {
                        req.started_at
                    } else if mutation.client_created_at > 0 {
                        mutation.client_created_at
                    } else {
                        now_unix()
                    },
                };
                (
                    normalized.workout_id.clone(),
                    WorkoutEventType::StartSet,
                    normalized.encode_to_vec(),
                )
            } else if let Some(workout_mutation::Mutation::CompleteSet(req)) =
                mutation.mutation.clone()
            {
                let normalized = CompleteSetRequest {
                    workout_id: req.workout_id,
                    proposed_set_id: req.proposed_set_id,
                    actual_reps: req.actual_reps,
                    actual_weight: req.actual_weight,
                    completed_at: if req.completed_at > 0 {
                        req.completed_at
                    } else if mutation.client_created_at > 0 {
                        mutation.client_created_at
                    } else {
                        now_unix()
                    },
                };
                (
                    normalized.workout_id.clone(),
                    WorkoutEventType::CompleteSet,
                    normalized.encode_to_vec(),
                )
            } else if let Some(workout_mutation::Mutation::CancelProposedSet(req)) =
                mutation.mutation.clone()
            {
                (
                    req.workout_id.clone(),
                    WorkoutEventType::CancelProposedSet,
                    req.encode_to_vec(),
                )
            } else if let Some(workout_mutation::Mutation::DeleteCompletedSet(req)) =
                mutation.mutation.clone()
            {
                (
                    req.workout_id.clone(),
                    WorkoutEventType::DeleteCompletedSet,
                    req.encode_to_vec(),
                )
            } else if matches!(
                mutation.mutation,
                Some(workout_mutation::Mutation::EndWorkout(_))
            ) {
                return Err(Status::invalid_argument(
                    "batched end_workout is not supported yet",
                ));
            } else if let Some(workout_mutation::Mutation::ReplaceExerciseGroupPlan(req)) =
                mutation.mutation.clone()
            {
                (
                    req.workout_id.clone(),
                    WorkoutEventType::ReplaceExerciseGroupPlan,
                    req.encode_to_vec(),
                )
            } else if let Some(workout_mutation::Mutation::ReorderExerciseGroups(req)) =
                mutation.mutation.clone()
            {
                (
                    req.workout_id.clone(),
                    WorkoutEventType::ReorderExerciseGroups,
                    req.encode_to_vec(),
                )
            } else {
                return Err(Status::invalid_argument("mutation payload is required"));
            };

            if workout_id != trial.workout.id {
                return Err(Status::failed_precondition("Workout ID mismatch"));
            }

            if let Err(status) = apply_event_to_active(&mut trial, event_type, payload.as_slice()) {
                if is_stale_local_mutation_error(&status) {
                    info!(
                        sync_event = "append_workout_mutations",
                        phase = "dropped_stale_mutation",
                        user_id = %user_id,
                        workout_id = %workout_id,
                        event_id = %mutation.event_id,
                        event_type = ?event_type,
                        code = ?status.code(),
                        reason = %status.message()
                    );
                    applied_event_ids.push(mutation.event_id);
                    continue;
                }
                return Err(status);
            }

            if matches!(
                event_type,
                WorkoutEventType::ReplaceExerciseGroupPlan
                    | WorkoutEventType::ReorderExerciseGroups
            ) {
                requires_full_flush = true;
            }

            pending.push(PendingMutation {
                event_id: mutation.event_id,
                workout_id: workout_id.clone(),
                event_type,
                payload: payload.clone(),
                db_op: db_op_from_trial(&trial, event_type, payload.as_slice())?,
            });
        }

        let batch: Vec<WorkoutMutationPersist> = pending
            .iter()
            .map(|mutation| WorkoutMutationPersist {
                event: WorkoutEventRecord {
                    event_id: mutation.event_id.clone(),
                    user_id: user_id.clone(),
                    workout_id: mutation.workout_id.clone(),
                    recorded_at: now_unix(),
                    event_type: mutation.event_type,
                    payload: mutation.payload.clone(),
                },
                op: mutation.db_op.clone(),
            })
            .collect();

        let (updated_workout, updated_response, participant_status) = {
            let user = self
                .state
                .users
                .get(&user_id)
                .map(|u| u.clone())
                .unwrap_or(User {
                    id: user_id.clone(),
                    name: String::new(),
                    created_at: 0,
                });
            let mut projected = trial.clone();
            if requires_full_flush {
                projected = trial.clone();
            }
            let participant_status = if projected.workout.session_id.is_empty() {
                None
            } else {
                Some(participant_status_from_active(&user, &projected))
            };
            (
                projected.workout.clone(),
                get_workout_response_from_active(&projected),
                participant_status,
            )
        };

        let (acked_event_ids, inserted_event_ids) = self
            .central_db
            .apply_workout_mutation_batch(
                &user_id,
                &batch,
                Some((&updated_workout, &updated_response)),
                participant_status
                    .as_ref()
                    .map(|status| (updated_workout.session_id.as_str(), status)),
            )
            .await
            .map_err(|e| Status::internal(format!("Failed to append mutation batch: {}", e)))?;
        applied_event_ids.extend(acked_event_ids);

        if !inserted_event_ids.is_empty() {
            let inserted: std::collections::HashSet<&str> =
                inserted_event_ids.iter().map(String::as_str).collect();
            let mut workout_ref = self
                .state
                .workouts
                .get_mut(&user_id)
                .ok_or_else(|| Status::failed_precondition("No active workout"))?;
            for mutation in pending
                .iter()
                .filter(|m| inserted.contains(m.event_id.as_str()))
            {
                apply_event_to_active(
                    &mut workout_ref,
                    mutation.event_type,
                    mutation.payload.as_slice(),
                )?;
            }
        }

        let (
            log_workout_id,
            log_end_time,
            flush_workout,
            flush_groups,
            flush_proposed,
            flush_completed,
            session_id,
        ) = {
            let active = self
                .state
                .workouts
                .get(&user_id)
                .ok_or_else(|| Status::failed_precondition("No active workout"))?;
            (
                active.workout.id.clone(),
                active.workout.end_time,
                active.workout.clone(),
                active.exercise_groups.clone(),
                active.proposed_sets.clone(),
                active.completed_sets.clone(),
                active.workout.session_id.clone(),
            )
        };

        if requires_full_flush && !inserted_event_ids.is_empty() {
            self.central_db
                .flush_workout(
                    &user_id,
                    &flush_workout,
                    &flush_groups,
                    &flush_proposed,
                    &flush_completed,
                )
                .await
                .map_err(|e| Status::internal(format!("Failed to persist workout state: {}", e)))?;
        }
        if !session_id.is_empty() && !inserted_event_ids.is_empty() {
            publish_current_session_snapshot_from_state(&self.state, &session_id)?;
        }

        info!(
            sync_event = "append_workout_mutations",
            phase = "applied",
            user_id = %user_id,
            workout_id = %log_workout_id,
            mutation_count = batch_len,
            applied_count = applied_event_ids.len(),
            remaining_pending = batch_len.saturating_sub(applied_event_ids.len()),
            end_time = log_end_time
        );

        Ok(Response::new(AppendWorkoutMutationsResponse {
            applied_event_ids,
            workout_state: None,
        }))
    }

    async fn rehydrate_workout_from_events(
        &self,
        request: Request<RehydrateWorkoutFromEventsRequest>,
    ) -> Result<Response<RehydrateWorkoutFromEventsResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();
        if req.workout_id.is_empty() {
            return Err(Status::invalid_argument("workout_id is required"));
        }

        let events = self
            .central_db
            .get_workout_events(&user_id, &req.workout_id)
            .await
            .map_err(|e| Status::internal(format!("Failed to load workout events: {}", e)))?;
        let active = replay_workout_events(&events)?;
        let response = get_workout_response_from_active(&active);

        if req.persist {
            self.central_db
                .flush_workout(
                    &user_id,
                    &active.workout,
                    &active.exercise_groups,
                    &active.proposed_sets,
                    &active.completed_sets,
                )
                .await
                .map_err(|e| {
                    Status::internal(format!("Failed to persist rebuilt workout: {}", e))
                })?;
            if active.workout.end_time == 0 {
                self.state.workouts.insert(user_id.clone(), active);
            }
        }

        Ok(Response::new(RehydrateWorkoutFromEventsResponse {
            workout_state: Some(response),
            applied_event_count: events.len() as i32,
        }))
    }

    async fn get_workout_heart_rate(
        &self,
        request: Request<GetWorkoutHeartRateRequest>,
    ) -> Result<Response<GetWorkoutHeartRateResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        if req.workout_id.is_empty() {
            return Err(Status::invalid_argument("workout_id is required"));
        }

        let is_active_owned = self
            .state
            .workouts
            .get(&user_id)
            .map(|w| w.workout.id == req.workout_id)
            .unwrap_or(false);

        if !is_active_owned {
            let exists = self
                .central_db
                .get_workout(&user_id, &req.workout_id)
                .await
                .map_err(|e| Status::internal(format!("Failed to get workout: {}", e)))?
                .is_some();
            if !exists {
                return Err(Status::not_found("Workout not found"));
            }
        }

        let samples = self
            .central_db
            .get_workout_heart_rate_samples(&user_id, &req.workout_id)
            .await
            .map_err(|e| Status::internal(format!("Failed to get heart rate samples: {}", e)))?;

        Ok(Response::new(GetWorkoutHeartRateResponse { samples }))
    }

    async fn end_workout(
        &self,
        request: Request<EndWorkoutRequest>,
    ) -> Result<Response<EndWorkoutResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        if req.workout_id.is_empty() {
            return Err(Status::invalid_argument("workout_id is required"));
        }

        // Remove from memory
        let active = {
            let (_, mut active) = self
                .state
                .workouts
                .remove(&user_id)
                .ok_or_else(|| Status::not_found("No active workout found"))?;

            let end_time = if req.ended_at > 0 {
                req.ended_at
            } else {
                now_unix()
            };
            active.workout.end_time = end_time;
            active
        }; // Guard dropped here

        let logged_req = EndWorkoutRequest {
            workout_id: active.workout.id.clone(),
            ended_at: active.workout.end_time,
        };
        let end_event = WorkoutEventRecord {
            event_id: Uuid::new_v4().to_string(),
            user_id: user_id.clone(),
            workout_id: active.workout.id.clone(),
            recorded_at: now_unix(),
            event_type: WorkoutEventType::EndWorkout,
            payload: logged_req.encode_to_vec(),
        };
        self.central_db
            .flush_writes()
            .await
            .map_err(|e| Status::internal(format!("Failed to flush workout state: {}", e)))?;
        self.central_db
            .finalize_workout_end(
                &user_id,
                &active.workout.id,
                active.workout.end_time,
                &end_event,
            )
            .await
            .map_err(|e| Status::internal(format!("Failed to finalize workout end: {}", e)))?;
        let _ = self
            .central_db
            .delete_active_workout_current(&user_id)
            .await;

        // ── State transition: compute + persist new program state ─────────────
        if let Ok(Some(state_record)) = self.central_db.get_latest_program_state(&user_id).await {
            let regime_type = schlift::workout::v1::RegimeType::try_from(state_record.regime_type)
                .unwrap_or(schlift::workout::v1::RegimeType::Linear5x5);
            let regime = get_regime(regime_type);
            let current_state = parse_state_payload(&state_record.state_payload_json);
            let weight_unit = get_user_weight_unit(&self.central_db, &user_id)
                .await
                .unwrap_or(AppWeightUnit::Lb);
            let annotated_state = annotate_state_with_weight_unit(&current_state, weight_unit);

            // Load proposed + completed sets to build WorkoutCompletionResult
            let proposed_sets = self
                .central_db
                .get_proposed_sets(&user_id, &active.workout.id)
                .await
                .unwrap_or_default();
            let completed_sets = self
                .central_db
                .get_completed_sets(&user_id, &active.workout.id)
                .await
                .unwrap_or_default();

            let completion_result =
                build_workout_completion_result(&proposed_sets, &completed_sets);

            let new_state = regime.transition_state_on_workout_complete(
                &annotated_state,
                &completion_result,
                active.workout.end_time,
            );
            let mut new_state = new_state;
            strip_weight_unit_context(&mut new_state);

            let event = ProgramStateEventRecord {
                event_id: uuid::Uuid::new_v4().to_string(),
                user_id: user_id.clone(),
                regime_type: regime_type as i32,
                effective_at: active.workout.end_time,
                recorded_at: active.workout.end_time,
                source: "workout_completed".to_string(),
                state_payload_json: serialize_state_payload(&new_state),
                source_workout_id: Some(active.workout.id.clone()),
            };

            // Best-effort: don't fail end_workout if state append fails
            let _ = self.central_db.append_program_state_event(event).await;
        }

        // Leave session
        if let Some((_, session_id)) = self.state.user_sessions.remove(&user_id) {
            let participant_user =
                self.state
                    .users
                    .get(&user_id)
                    .map(|u| u.clone())
                    .unwrap_or(User {
                        id: user_id.clone(),
                        name: String::new(),
                        created_at: 0,
                    });
            let proposed_sets: Vec<ProposedSet> = active
                .proposed_sets
                .iter()
                .filter(|set| !set.cancelled)
                .cloned()
                .collect();
            let progress = crate::progress::compute_participant_progress(
                &proposed_sets,
                &active.completed_sets,
            );
            let finished_status = ParticipantStatus {
                user: Some(participant_user),
                active_workout_id: active.workout.id.clone(),
                active_workout: Some(active.workout.clone()),
                exercise_groups: active.exercise_groups.clone(),
                proposed_sets,
                completed_sets: active.completed_sets.clone(),
                next_up_set: progress.next_up_set,
                rest_until: progress.rest_until,
                has_active_set: false,
            };
            let _ = self
                .central_db
                .upsert_session_participant_current(
                    &session_id,
                    &user_id,
                    &finished_status,
                    "end_workout",
                )
                .await;
            if let Some(mut members) = self.state.sessions.get_mut(&session_id) {
                members.remove(&user_id);
                if members.is_empty() {
                    drop(members);
                    self.state.sessions.remove(&session_id);
                }
            }
            // Record session in user's DB
            let _ = self.central_db.leave_session(&user_id, &session_id).await;
            let _ =
                publish_current_session_snapshot(&self.central_db, &self.state, &session_id).await;
        }

        Ok(Response::new(EndWorkoutResponse {
            workout: Some(active.workout),
        }))
    }

    async fn get_active_workout(
        &self,
        request: Request<GetActiveWorkoutRequest>,
    ) -> Result<Response<GetActiveWorkoutResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let workout = self
            .central_db
            .get_active_workout_current(&user_id)
            .await
            .map_err(|e| Status::internal(format!("Failed to load active workout: {}", e)))?
            .and_then(|resp| resp.workout);

        Ok(Response::new(GetActiveWorkoutResponse { workout }))
    }

    async fn get_proposed_workout_schedule(
        &self,
        request: Request<GetProposedWorkoutScheduleRequest>,
    ) -> Result<Response<GetProposedWorkoutScheduleResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        // 1. Get active workout ID while holding lock
        let active_workout_id = self
            .state
            .workouts
            .get(&user_id)
            .map(|w| w.workout.id.clone());

        // 2. Perform DB IO outside the lock
        let scheduler = Scheduler::new(self.central_db.clone());
        let at_time = request.into_inner().at_time;
        let mut response = scheduler
            .get_proposed_schedule(&user_id, at_time)
            .await
            .map_err(|e| Status::internal(format!("Failed to generate schedule: {}", e)))?;

        if let Some(blob) = self
            .central_db
            .get_latest_setting_by_type(&user_id, WORKOUT_DRAFT_SETTING_TYPE)
            .await
            .map_err(|e| Status::internal(format!("Failed to load workout draft: {}", e)))?
        {
            if let Ok(draft) = WorkoutDraft::decode(blob.as_slice()) {
                if !draft.name.is_empty() || !draft.exercise_groups.is_empty() {
                    response.draft = Some(draft);
                }
            }
        }

        // 3. Override active_workout_id from in-memory state if present
        if let Some(id) = active_workout_id {
            response.active_workout_id = id;
        }

        Ok(Response::new(response))
    }

    async fn save_workout_draft(
        &self,
        request: Request<SaveWorkoutDraftRequest>,
    ) -> Result<Response<SaveWorkoutDraftResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();
        let draft = req
            .draft
            .ok_or_else(|| Status::invalid_argument("draft is required"))?;
        info!(
            sync_event = "save_workout_draft",
            phase = "received",
            user_id = %user_id,
            group_count = draft.exercise_groups.len(),
            updated_at = draft.updated_at
        );
        let blob = draft.encode_to_vec();
        self.central_db
            .insert_user_setting(&user_id, WORKOUT_DRAFT_SETTING_TYPE, &blob)
            .await
            .map_err(|e| Status::internal(format!("Failed to save workout draft: {}", e)))?;
        info!(
            sync_event = "save_workout_draft",
            phase = "applied",
            user_id = %user_id,
            group_count = draft.exercise_groups.len(),
            updated_at = draft.updated_at
        );
        Ok(Response::new(SaveWorkoutDraftResponse {
            draft: Some(draft),
        }))
    }

    async fn clear_workout_draft(
        &self,
        request: Request<ClearWorkoutDraftRequest>,
    ) -> Result<Response<ClearWorkoutDraftResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        info!(
            sync_event = "clear_workout_draft",
            phase = "received",
            user_id = %user_id
        );
        let draft = WorkoutDraft {
            name: String::new(),
            exercise_groups: vec![],
            updated_at: now_unix(),
        };
        self.central_db
            .insert_user_setting(&user_id, WORKOUT_DRAFT_SETTING_TYPE, &draft.encode_to_vec())
            .await
            .map_err(|e| Status::internal(format!("Failed to clear workout draft: {}", e)))?;
        info!(
            sync_event = "clear_workout_draft",
            phase = "applied",
            user_id = %user_id
        );
        Ok(Response::new(ClearWorkoutDraftResponse {}))
    }
}
