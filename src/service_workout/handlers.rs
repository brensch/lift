use super::*;
use schlift::workout::v1::WorkoutMutation;
use tokio::time::{sleep, Duration};
use tracing::info;

fn mutation_kind_name(mutation: &WorkoutMutation) -> &'static str {
    match mutation.mutation.as_ref() {
        Some(workout_mutation::Mutation::StartSet(_)) => "start_set",
        Some(workout_mutation::Mutation::CompleteSet(_)) => "complete_set",
        Some(workout_mutation::Mutation::CancelProposedSet(_)) => "cancel_proposed_set",
        Some(workout_mutation::Mutation::DeleteCompletedSet(_)) => "delete_completed_set",
        Some(workout_mutation::Mutation::EndWorkout(_)) => "end_workout",
        Some(workout_mutation::Mutation::ReplaceExerciseGroupPlan(_)) => "replace_exercise_group_plan",
        Some(workout_mutation::Mutation::ReorderExerciseGroups(_)) => "reorder_exercise_groups",
        None => "missing",
    }
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

                // Persist join to DB
                let _ = self.central_db.join_session(&user_id, &session_id).await;
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

        let checkpoint_event = checkpoint_event_from_active(&user_id, &active);
        self.central_db
            .persist_new_workout_with_checkpoint(
                &user_id,
                &active.workout,
                &active.exercise_groups,
                &active.proposed_sets,
                &checkpoint_event,
            )
            .await
            .map_err(|e| {
                Status::internal(format!(
                    "Failed to persist new workout transactionally: {}",
                    e
                ))
            })?;

        self.state.workouts.insert(user_id.clone(), active);

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
            // Even if cached, we need to re-fetch completed sets if it's a shared session
            // to see other people's updates.
            let completed_sets = if !workout.session_id.is_empty() {
                self.central_db
                    .get_completed_sets_by_session(&workout.session_id)
                    .await
                    .map_err(|e| Status::internal(format!("Failed to get session sets: {}", e)))?
            } else {
                self.central_db
                    .get_completed_sets(&user_id, &workout.id)
                    .await
                    .map_err(|e| Status::internal(format!("Failed to get completed sets: {}", e)))?
            };

            // For state snapshot and next-up computation, only use the current user's
            // own completed sets. Using all session sets would incorrectly detect
            // another participant's active set (ended_at==0) as our own lifting state,
            // causing the bottom bar to vanish when display_set can't be resolved.
            let own_workout_id = workout.id.clone();
            let own_completed: Vec<CompletedSet> = completed_sets
                .iter()
                .filter(|c| c.workout_id == own_workout_id)
                .cloned()
                .collect();

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
        info!(
            sync_event = "append_workout_heart_rate",
            phase = "received",
            user_id = %user_id,
            workout_id = %req.workout_id,
            sample_count = req.samples.len()
        );
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

        info!(
            sync_event = "append_workout_heart_rate",
            phase = "applied",
            user_id = %user_id,
            workout_id = %req.workout_id,
            stored_count = req.samples.len()
        );
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
            mutation_kinds = %mutation_kinds,
            artificial_delay_ms = 1000
        );

        // Temporary latency injection to verify the local-first client flow
        // stays responsive under slow network/server conditions.
        sleep(Duration::from_secs(1)).await;

        let mut applied_event_ids = Vec::new();

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

            let mut workout_ref = self
                .state
                .workouts
                .get_mut(&user_id)
                .ok_or_else(|| Status::failed_precondition("No active workout"))?;
            if workout_ref.workout.id != workout_id {
                return Err(Status::failed_precondition("Workout ID mismatch"));
            }

            let mut trial = workout_ref.clone();
            match event_type {
                WorkoutEventType::StartSet => {
                    let decoded = StartSetRequest::decode(payload.as_slice()).map_err(|e| {
                        Status::internal(format!("Could not decode start-set payload: {}", e))
                    })?;
                    apply_start_set_to_active(&mut trial, &decoded)?;
                }
                WorkoutEventType::CompleteSet => {
                    let decoded = CompleteSetRequest::decode(payload.as_slice()).map_err(|e| {
                        Status::internal(format!("Could not decode complete-set payload: {}", e))
                    })?;
                    apply_complete_set_to_active(&mut trial, &decoded)?;
                }
                WorkoutEventType::DeleteCompletedSet => {
                    let decoded =
                        DeleteCompletedSetRequest::decode(payload.as_slice()).map_err(|e| {
                            Status::internal(format!("Could not decode delete-set payload: {}", e))
                        })?;
                    apply_delete_completed_set_to_active(&mut trial, &decoded)?;
                }
                WorkoutEventType::CancelProposedSet => {
                    let decoded =
                        CancelProposedSetRequest::decode(payload.as_slice()).map_err(|e| {
                            Status::internal(format!("Could not decode cancel-set payload: {}", e))
                        })?;
                    apply_cancel_proposed_set_to_active(&mut trial, &decoded)?;
                }
                WorkoutEventType::ReplaceExerciseGroupPlan => {
                    let decoded = ReplaceExerciseGroupPlanRequest::decode(payload.as_slice())
                        .map_err(|e| {
                            Status::internal(format!(
                                "Could not decode replace-group payload: {}",
                                e
                            ))
                        })?;
                    let _ = apply_replace_exercise_group_plan(&mut trial, &decoded)?;
                }
                WorkoutEventType::ReorderExerciseGroups => {
                    let decoded = ReorderExerciseGroupsRequest::decode(payload.as_slice())
                        .map_err(|e| {
                            Status::internal(format!(
                                "Could not decode reorder-groups payload: {}",
                                e
                            ))
                        })?;
                    apply_reorder_exercise_groups(&mut trial, &decoded)?;
                }
                _ => return Err(Status::invalid_argument("unsupported mutation type")),
            }

            let inserted = self
                .central_db
                .append_workout_event(&WorkoutEventRecord {
                    event_id: mutation.event_id.clone(),
                    user_id: user_id.clone(),
                    workout_id: workout_id.clone(),
                    recorded_at: now_unix(),
                    event_type,
                    payload: payload.clone(),
                })
                .await
                .map_err(|e| Status::internal(format!("Failed to append mutation event: {}", e)))?;
            if !inserted {
                continue;
            }

            *workout_ref = trial;
            applied_event_ids.push(mutation.event_id);
        }

        let active = self
            .state
            .workouts
            .get(&user_id)
            .ok_or_else(|| Status::failed_precondition("No active workout"))?;
        self.central_db
            .flush_workout(
                &user_id,
                &active.workout,
                &active.exercise_groups,
                &active.proposed_sets,
                &active.completed_sets,
            )
            .await
            .map_err(|e| Status::internal(format!("Failed to persist workout state: {}", e)))?;

        info!(
            sync_event = "append_workout_mutations",
            phase = "applied",
            user_id = %user_id,
            workout_id = %active.workout.id,
            mutation_count = batch_len,
            applied_count = applied_event_ids.len(),
            remaining_pending = batch_len.saturating_sub(applied_event_ids.len()),
            end_time = active.workout.end_time
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

        // Incremental write: update end time
        self.central_db
            .update_workout_end_time(&user_id, &active.workout.id, active.workout.end_time)
            .await
            .map_err(|e| Status::internal(format!("Failed to end workout: {}", e)))?;

        let logged_req = EndWorkoutRequest {
            workout_id: active.workout.id.clone(),
            ended_at: active.workout.end_time,
        };
        self.log_delta_event(
            &user_id,
            &active.workout.id,
            WorkoutEventType::EndWorkout,
            &logged_req,
        )
        .await?;

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
            if let Some(mut members) = self.state.sessions.get_mut(&session_id) {
                members.remove(&user_id);
                if members.is_empty() {
                    drop(members);
                    self.state.sessions.remove(&session_id);
                }
            }
            // Record session in user's DB
            let _ = self.central_db.leave_session(&user_id, &session_id).await;
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

        // Lazy crash recovery: check CentralDb once per user for un-ended workouts
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        let workout = self.state.workouts.get(&user_id).map(|w| w.workout.clone());

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
