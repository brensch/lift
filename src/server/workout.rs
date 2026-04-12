use super::*;

// ── Workout Service ──

#[derive(Clone)]
pub struct ServerWorkoutService {
    pub db: ServerDb,
}

impl ServerWorkoutService {
    async fn generate_schedule(
        &self,
        user_id: &str,
        at_time: i64,
    ) -> Result<GetProposedWorkoutScheduleResponse, Status> {
        let state_resp = if let Some(resp) = self
            .db
            .get_program_state(user_id)
            .await
            .map_err(internal_error)?
        {
            resp
        } else {
            let regime = get_regime(RegimeType::Linear5x5);
            GetActiveTrainingProgramStateResponse {
                state: Some(TrainingProgramState {
                    regime_type: RegimeType::Linear5x5 as i32,
                    fields: payload_to_proto(&regime.default_state()),
                    updated_at: 0,
                    source: "default".to_string(),
                }),
                schema: Some(regime.state_schema()),
            }
        };
        let state = state_resp
            .state
            .ok_or_else(|| Status::internal("missing state"))?;
        let regime_type = RegimeType::try_from(state.regime_type).unwrap_or(RegimeType::Linear5x5);
        let regime = get_regime(regime_type);
        let payload = payload_from_proto(&state.fields);
        let now = if at_time > 0 { at_time } else { now_unix() };
        let proposal = regime.propose_from_state(&payload, 0, now);
        let pending_updates = regime
            .pending_updates_for_state(&payload, 0, now)
            .into_iter()
            .map(pending_update_to_proto)
            .collect::<Vec<_>>();

        let active_workout_id = self
            .db
            .get_active_workout_id(user_id)
            .await
            .map_err(internal_error)?
            .map(|(id, _)| id)
            .unwrap_or_default();

        let response = GetProposedWorkoutScheduleResponse {
            exercise_statuses: Vec::new(),
            active_workout_id,
            proposed_groups: proposal.proposed_groups,
            regime_context: Some(proposal.regime_context),
            session_readiness: Some(SessionReadiness {
                next_session_at: 0,
                last_session_at: 0,
                readiness_label: "Ready".to_string(),
                readiness_detail: String::new(),
                is_ready: true,
                is_overdue: false,
            }),
            suggested_workout_name: proposal.suggested_workout_name,
            pending_state_updates: pending_updates.clone(),
            can_start_workout: pending_updates.is_empty(),
            draft: self
                .db
                .get_workout_draft(user_id)
                .await
                .map_err(internal_error)?,
        };
        self.db
            .put_schedule_cache(user_id, &response)
            .await
            .map_err(internal_error)?;
        Ok(response)
    }

    /// Load proposed_sets + completed_sets for a workout and compute next_up + snapshot.
    async fn load_sets_and_compute(
        &self,
        _user_id: &str,
        workout_id: &str,
    ) -> Result<
        (
            Vec<ProposedSet>,
            Vec<CompletedSet>,
            Option<ProposedSet>,
            Option<WorkoutStateSnapshot>,
        ),
        Status,
    > {
        let proposed_sets = self
            .db
            .get_proposed_sets(workout_id)
            .await
            .map_err(internal_error)?;
        let completed_sets = self
            .db
            .get_completed_sets(workout_id)
            .await
            .map_err(internal_error)?;
        let active_proposed = active_proposed_sets(&proposed_sets);
        let next_up = compute_next_up_set(&active_proposed, &completed_sets);
        let snapshot = Some(workout_state_snapshot_from_state(
            &proposed_sets,
            &completed_sets,
            now_unix(),
        ));
        Ok((proposed_sets, completed_sets, next_up, snapshot))
    }

    /// Get session_id for a user (from active_workout_current or session membership).
    async fn get_session_id_for_user(&self, user_id: &str) -> Result<String, Status> {
        Ok(self
            .db
            .get_active_workout_id(user_id)
            .await
            .map_err(internal_error)?
            .map(|(_, sid)| sid)
            .unwrap_or_default())
    }
}

#[tonic::async_trait]
impl WorkoutService for ServerWorkoutService {
    async fn start_workout(
        &self,
        request: Request<StartWorkoutRequest>,
    ) -> Result<Response<StartWorkoutResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "StartWorkout", %user_id, group_count = req.exercise_groups.len(), "request");
        let session_id = self
            .db
            .get_current_session_id_for_user(&user_id)
            .await
            .map_err(internal_error)?
            .unwrap_or_default();
        let workout_id = Uuid::new_v4().to_string();
        let started_at = if req.started_at > 0 {
            req.started_at
        } else {
            now_unix()
        };
        let workout = Workout {
            id: workout_id.clone(),
            name: if req.name.is_empty() {
                "Workout".to_string()
            } else {
                req.name
            },
            start_time: started_at,
            end_time: 0,
            session_id: session_id.clone(),
        };
        let mut groups = req.exercise_groups;
        for (idx, group) in groups.iter_mut().enumerate() {
            if group.id.is_empty() {
                group.id = Uuid::new_v4().to_string();
            }
            group.workout_id = workout_id.clone();
            group.workout_order = idx as i32;
        }
        let mut proposed_sets = Vec::new();
        let mut order = 0;
        for group in &groups {
            let generated = generate_sets_for_group(&workout_id, group, order);
            order += generated.len() as i32;
            proposed_sets.extend(generated);
        }

        // Insert real rows
        self.db
            .insert_workout(&user_id, &workout, &groups, &proposed_sets)
            .await
            .map_err(internal_error)?;

        let active = ActiveWorkout::new(workout, groups, proposed_sets, Vec::new());
        let response = start_workout_response_from_active(&active);

        if !session_id.is_empty() {
            refresh_participant_for_user(&self.db, &user_id, &session_id).await?;
        }
        Ok(Response::new(response))
    }

    async fn end_workout(
        &self,
        request: Request<EndWorkoutRequest>,
    ) -> Result<Response<EndWorkoutResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "EndWorkout", %user_id, workout_id = %req.workout_id, "request");
        let ended_at = if req.ended_at > 0 {
            req.ended_at
        } else {
            now_unix()
        };

        // Get session_id before ending
        let session_id = self.get_session_id_for_user(&user_id).await?;

        self.db
            .end_workout(&user_id, &req.workout_id, ended_at)
            .await
            .map_err(internal_error)?;

        let workout = self
            .db
            .get_workout(&user_id, &req.workout_id)
            .await
            .map_err(internal_error)?
            .ok_or_else(|| Status::not_found("Workout not found"))?;

        if !session_id.is_empty() {
            refresh_participant_for_user(&self.db, &user_id, &session_id).await?;
        }
        Ok(Response::new(EndWorkoutResponse {
            workout: Some(workout),
        }))
    }

    async fn get_workout(
        &self,
        request: Request<GetWorkoutRequest>,
    ) -> Result<Response<GetWorkoutResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "GetWorkout", %user_id, workout_id = %req.workout_id, "request");
        let workout = self
            .db
            .load_workout_full(&user_id, &req.workout_id)
            .await
            .map_err(internal_error)?
            .ok_or_else(|| Status::not_found("Workout not found"))?;
        Ok(Response::new(workout))
    }

    async fn get_active_workout(
        &self,
        request: Request<GetActiveWorkoutRequest>,
    ) -> Result<Response<GetActiveWorkoutResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "GetActiveWorkout", %user_id, "request");
        let workout = if let Some((workout_id, _)) = self
            .db
            .get_active_workout_id(&user_id)
            .await
            .map_err(internal_error)?
        {
            self.db
                .get_workout(&user_id, &workout_id)
                .await
                .map_err(internal_error)?
        } else {
            None
        };
        Ok(Response::new(GetActiveWorkoutResponse { workout }))
    }

    async fn list_workouts(
        &self,
        request: Request<ListWorkoutsRequest>,
    ) -> Result<Response<ListWorkoutsResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "ListWorkouts", %user_id, "request");
        let workouts = self
            .db
            .list_workouts(&user_id)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(ListWorkoutsResponse { workouts }))
    }

    // ── Individual Set RPCs (targeted single-row SQL operations) ──

    async fn start_set(
        &self,
        request: Request<StartSetRequest>,
    ) -> Result<Response<StartSetResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "StartSet", %user_id, workout_id = %req.workout_id, proposed_set_id = %req.proposed_set_id, "request");
        if req.workout_id.is_empty() || req.proposed_set_id.is_empty() {
            return Err(Status::invalid_argument(
                "workout_id and proposed_set_id are required",
            ));
        }

        // Look up proposed set for target values
        let proposed = self
            .db
            .get_proposed_set(&req.proposed_set_id)
            .await
            .map_err(internal_error)?
            .ok_or_else(|| Status::failed_precondition("Proposed set not found"))?;
        if proposed.cancelled {
            return Err(Status::failed_precondition("Proposed set is cancelled"));
        }

        // Check for existing in-progress set
        if self
            .db
            .find_in_progress_completed_set(&req.workout_id, &req.proposed_set_id)
            .await
            .map_err(internal_error)?
            .is_some()
        {
            // Already started - load and return current state
            let (_, _, next_up, snapshot) = self
                .load_sets_and_compute(&user_id, &req.workout_id)
                .await?;
            let existing = self
                .db
                .find_in_progress_completed_set(&req.workout_id, &req.proposed_set_id)
                .await
                .map_err(internal_error)?;
            return Ok(Response::new(StartSetResponse {
                completed_set: existing,
                next_up_set: next_up,
                state_snapshot: snapshot,
            }));
        }

        let started_at = if req.started_at > 0 {
            req.started_at
        } else {
            now_unix()
        };
        let completed_set = CompletedSet {
            id: Uuid::new_v4().to_string(),
            workout_id: req.workout_id.clone(),
            proposed_set_id: req.proposed_set_id.clone(),
            actual_reps: proposed.target_reps,
            actual_weight: proposed.target_weight,
            started_at,
            ended_at: 0,
            rest_until: 0,
        };

        self.db
            .insert_completed_set(&user_id, &completed_set)
            .await
            .map_err(internal_error)?;

        let (_, _, next_up, snapshot) = self
            .load_sets_and_compute(&user_id, &req.workout_id)
            .await?;

        let session_id = self.get_session_id_for_user(&user_id).await?;
        if !session_id.is_empty() {
            refresh_participant_for_user(&self.db, &user_id, &session_id).await?;
        }

        Ok(Response::new(StartSetResponse {
            completed_set: Some(completed_set),
            next_up_set: next_up,
            state_snapshot: snapshot,
        }))
    }

    async fn complete_set(
        &self,
        request: Request<CompleteSetRequest>,
    ) -> Result<Response<CompleteSetResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "CompleteSet", %user_id, workout_id = %req.workout_id, proposed_set_id = %req.proposed_set_id, actual_reps = req.actual_reps, actual_weight = req.actual_weight, "request");

        let proposed = self
            .db
            .get_proposed_set(&req.proposed_set_id)
            .await
            .map_err(internal_error)?
            .ok_or_else(|| Status::failed_precondition("Proposed set not found"))?;

        let ended_at = if req.completed_at > 0 {
            req.completed_at
        } else {
            now_unix()
        };

        // Compute rest_until
        let proposed_sets = self
            .db
            .get_proposed_sets(&req.workout_id)
            .await
            .map_err(internal_error)?;
        let completed_sets = self
            .db
            .get_completed_sets(&req.workout_id)
            .await
            .map_err(internal_error)?;

        let is_final = is_final_set_in_exercise_group_after_completion(
            &req.proposed_set_id,
            &proposed_sets,
            &completed_sets,
        );
        let mut rest_seconds = if req.actual_reps >= proposed.target_reps {
            proposed.rest_after_success as i64
        } else {
            proposed.rest_after_failure as i64
        };
        if is_final {
            rest_seconds = END_OF_EXERCISE_GROUP_REST_SECONDS;
        }
        let rest_until = ended_at + rest_seconds;

        // Find existing in-progress set and update it, or create new
        if let Some(existing) = self
            .db
            .find_in_progress_completed_set(&req.workout_id, &req.proposed_set_id)
            .await
            .map_err(internal_error)?
        {
            self.db
                .update_completed_set(
                    &existing.id,
                    req.actual_reps,
                    req.actual_weight,
                    ended_at,
                    rest_until,
                )
                .await
                .map_err(internal_error)?;

            let completed_set = CompletedSet {
                id: existing.id,
                workout_id: req.workout_id.clone(),
                proposed_set_id: req.proposed_set_id.clone(),
                actual_reps: req.actual_reps,
                actual_weight: req.actual_weight,
                started_at: existing.started_at,
                ended_at,
                rest_until,
            };

            let (_, _, next_up, snapshot) = self
                .load_sets_and_compute(&user_id, &req.workout_id)
                .await?;

            let session_id = self.get_session_id_for_user(&user_id).await?;
            if !session_id.is_empty() {
                refresh_participant_for_user(&self.db, &user_id, &session_id).await?;
            }

            Ok(Response::new(CompleteSetResponse {
                completed_set: Some(completed_set),
                next_up_set: next_up,
                state_snapshot: snapshot,
            }))
        } else {
            // No in-progress set - create a completed set directly
            let completed_set = CompletedSet {
                id: Uuid::new_v4().to_string(),
                workout_id: req.workout_id.clone(),
                proposed_set_id: req.proposed_set_id.clone(),
                actual_reps: req.actual_reps,
                actual_weight: req.actual_weight,
                started_at: ended_at,
                ended_at,
                rest_until,
            };
            self.db
                .insert_completed_set(&user_id, &completed_set)
                .await
                .map_err(internal_error)?;

            let (_, _, next_up, snapshot) = self
                .load_sets_and_compute(&user_id, &req.workout_id)
                .await?;

            let session_id = self.get_session_id_for_user(&user_id).await?;
            if !session_id.is_empty() {
                refresh_participant_for_user(&self.db, &user_id, &session_id).await?;
            }

            Ok(Response::new(CompleteSetResponse {
                completed_set: Some(completed_set),
                next_up_set: next_up,
                state_snapshot: snapshot,
            }))
        }
    }

    async fn delete_completed_set(
        &self,
        request: Request<DeleteCompletedSetRequest>,
    ) -> Result<Response<DeleteCompletedSetResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "DeleteCompletedSet", %user_id, workout_id = %req.workout_id, "request");

        self.db
            .delete_completed_set(&req.completed_set_id, &req.workout_id)
            .await
            .map_err(internal_error)?;

        let (_, _, next_up, snapshot) = self
            .load_sets_and_compute(&user_id, &req.workout_id)
            .await?;

        let session_id = self.get_session_id_for_user(&user_id).await?;
        if !session_id.is_empty() {
            refresh_participant_for_user(&self.db, &user_id, &session_id).await?;
        }

        Ok(Response::new(DeleteCompletedSetResponse {
            next_up_set: next_up,
            state_snapshot: snapshot,
        }))
    }

    async fn cancel_proposed_set(
        &self,
        request: Request<CancelProposedSetRequest>,
    ) -> Result<Response<CancelProposedSetResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "CancelProposedSet", %user_id, workout_id = %req.workout_id, "request");

        self.db
            .cancel_proposed_set(&req.proposed_set_id, &req.workout_id)
            .await
            .map_err(internal_error)?;

        let (_, _, next_up, snapshot) = self
            .load_sets_and_compute(&user_id, &req.workout_id)
            .await?;

        let session_id = self.get_session_id_for_user(&user_id).await?;
        if !session_id.is_empty() {
            refresh_participant_for_user(&self.db, &user_id, &session_id).await?;
        }

        Ok(Response::new(CancelProposedSetResponse {
            next_up_set: next_up,
            state_snapshot: snapshot,
        }))
    }

    // ── Structural Mutations (load full state, apply, persist) ──

    async fn replace_exercise_group_plan(
        &self,
        request: Request<ReplaceExerciseGroupPlanRequest>,
    ) -> Result<Response<ReplaceExerciseGroupPlanResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "ReplaceExerciseGroupPlan", %user_id, workout_id = %req.workout_id, "request");

        // Load full workout into ActiveWorkout
        let resp = self
            .db
            .load_workout_full(&user_id, &req.workout_id)
            .await
            .map_err(internal_error)?
            .ok_or_else(|| Status::not_found("Workout not found"))?;
        let mut active = active_from_get_workout_response(resp)?;

        // Apply the complex group plan replacement
        let (group, generated_sets) = apply_replace_exercise_group_plan(&mut active, &req)?;

        // Persist the full updated state back to real tables
        self.db
            .persist_workout_state(
                &user_id,
                &active.workout,
                &active.exercise_groups,
                &active.proposed_sets,
                &active.completed_sets,
            )
            .await
            .map_err(internal_error)?;

        let active_proposed = active_proposed_sets(&active.proposed_sets);
        let next_up = compute_next_up_set(&active_proposed, &active.completed_sets);
        let snapshot = Some(workout_state_snapshot_from_state(
            &active.proposed_sets,
            &active.completed_sets,
            now_unix(),
        ));

        let session_id = self.get_session_id_for_user(&user_id).await?;
        if !session_id.is_empty() {
            refresh_participant_for_user(&self.db, &user_id, &session_id).await?;
        }

        Ok(Response::new(ReplaceExerciseGroupPlanResponse {
            group,
            generated_sets,
            next_up_set: next_up,
            state_snapshot: snapshot,
        }))
    }

    async fn reorder_exercise_groups(
        &self,
        request: Request<ReorderExerciseGroupsRequest>,
    ) -> Result<Response<ReorderExerciseGroupsResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "ReorderExerciseGroups", %user_id, workout_id = %req.workout_id, "request");

        let resp = self
            .db
            .load_workout_full(&user_id, &req.workout_id)
            .await
            .map_err(internal_error)?
            .ok_or_else(|| Status::not_found("Workout not found"))?;
        let mut active = active_from_get_workout_response(resp)?;

        apply_reorder_exercise_groups(&mut active, &req)?;

        self.db
            .persist_workout_state(
                &user_id,
                &active.workout,
                &active.exercise_groups,
                &active.proposed_sets,
                &active.completed_sets,
            )
            .await
            .map_err(internal_error)?;

        let active_proposed = active_proposed_sets(&active.proposed_sets);
        let next_up = compute_next_up_set(&active_proposed, &active.completed_sets);
        let snapshot = Some(workout_state_snapshot_from_state(
            &active.proposed_sets,
            &active.completed_sets,
            now_unix(),
        ));

        let session_id = self.get_session_id_for_user(&user_id).await?;
        if !session_id.is_empty() {
            refresh_participant_for_user(&self.db, &user_id, &session_id).await?;
        }

        Ok(Response::new(ReorderExerciseGroupsResponse {
            next_up_set: next_up,
            state_snapshot: snapshot,
        }))
    }

    // ── Batch Mutations ──

    async fn append_workout_mutations(
        &self,
        request: Request<AppendWorkoutMutationsRequest>,
    ) -> Result<Response<AppendWorkoutMutationsResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let first_mutation = req
            .mutations
            .first()
            .ok_or_else(|| Status::invalid_argument("mutations are required"))?;
        let workout_id = match first_mutation.mutation.as_ref() {
            Some(Mutation::StartSet(m)) => m.workout_id.clone(),
            Some(Mutation::CompleteSet(m)) => m.workout_id.clone(),
            Some(Mutation::CancelProposedSet(m)) => m.workout_id.clone(),
            Some(Mutation::DeleteCompletedSet(m)) => m.workout_id.clone(),
            Some(Mutation::EndWorkout(m)) => m.workout_id.clone(),
            Some(Mutation::ReplaceExerciseGroupPlan(m)) => m.workout_id.clone(),
            Some(Mutation::ReorderExerciseGroups(m)) => m.workout_id.clone(),
            None => return Err(Status::invalid_argument("mutation payload missing")),
        };
        info!(rpc = "AppendWorkoutMutations", %user_id, %workout_id, mutation_count = req.mutations.len(), "request");

        // For batch mutations, load full state and use reducers (same as before)
        let resp = self
            .db
            .load_workout_full(&user_id, &workout_id)
            .await
            .map_err(internal_error)?
            .ok_or_else(|| Status::not_found("Workout not found"))?;
        let mut active = active_from_get_workout_response(resp)?;
        let mut events = Vec::with_capacity(req.mutations.len());
        let mut applied = Vec::with_capacity(req.mutations.len());

        for mutation in req.mutations {
            let event_id = if mutation.event_id.is_empty() {
                Uuid::new_v4().to_string()
            } else {
                mutation.event_id.clone()
            };
            let recorded_at = if mutation.client_created_at > 0 {
                mutation.client_created_at
            } else {
                now_unix()
            };
            match mutation
                .mutation
                .ok_or_else(|| Status::invalid_argument("mutation missing"))?
            {
                Mutation::StartSet(req) => {
                    apply_start_set_to_active(&mut active, &req)?;
                    events.push((event_id.clone(), recorded_at, 2, req.encode_to_vec()));
                }
                Mutation::CompleteSet(req) => {
                    apply_complete_set_to_active(&mut active, &req)?;
                    events.push((event_id.clone(), recorded_at, 3, req.encode_to_vec()));
                }
                Mutation::DeleteCompletedSet(req) => {
                    apply_delete_completed_set_to_active(&mut active, &req)?;
                    events.push((event_id.clone(), recorded_at, 4, req.encode_to_vec()));
                }
                Mutation::CancelProposedSet(req) => {
                    apply_cancel_proposed_set_to_active(&mut active, &req)?;
                    events.push((event_id.clone(), recorded_at, 5, req.encode_to_vec()));
                }
                Mutation::EndWorkout(req) => {
                    let ended_at = if req.ended_at > 0 {
                        req.ended_at
                    } else {
                        now_unix()
                    };
                    active.workout.end_time = ended_at;
                    events.push((event_id.clone(), recorded_at, 6, req.encode_to_vec()));
                }
                Mutation::ReplaceExerciseGroupPlan(req) => {
                    apply_replace_exercise_group_plan(&mut active, &req)?;
                    events.push((event_id.clone(), recorded_at, 7, req.encode_to_vec()));
                }
                Mutation::ReorderExerciseGroups(req) => {
                    apply_reorder_exercise_groups(&mut active, &req)?;
                    events.push((event_id.clone(), recorded_at, 8, req.encode_to_vec()));
                }
            }
            applied.push(event_id);
        }

        // Append events
        self.db
            .append_workout_events(&user_id, &workout_id, &events)
            .await
            .map_err(internal_error)?;

        // Persist full state back to tables
        if active.workout.end_time > 0 {
            self.db
                .persist_workout_state(
                    &user_id,
                    &active.workout,
                    &active.exercise_groups,
                    &active.proposed_sets,
                    &active.completed_sets,
                )
                .await
                .map_err(internal_error)?;
            // End workout: remove active pointer
            self.db
                .end_workout(&user_id, &workout_id, active.workout.end_time)
                .await
                .map_err(internal_error)?;
        } else {
            self.db
                .persist_workout_state(
                    &user_id,
                    &active.workout,
                    &active.exercise_groups,
                    &active.proposed_sets,
                    &active.completed_sets,
                )
                .await
                .map_err(internal_error)?;
        }

        let response = get_workout_response_from_active(&active);

        if !active.workout.session_id.is_empty() {
            refresh_participant_for_user(&self.db, &user_id, &active.workout.session_id).await?;
        }

        Ok(Response::new(AppendWorkoutMutationsResponse {
            applied_event_ids: applied,
            workout_state: Some(response),
        }))
    }

    // ── Heart Rate ──

    async fn append_workout_heart_rate(
        &self,
        request: Request<AppendWorkoutHeartRateRequest>,
    ) -> Result<Response<AppendWorkoutHeartRateResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "AppendWorkoutHeartRate", %user_id, workout_id = %req.workout_id, sample_count = req.samples.len(), "request");
        self.db
            .insert_heart_rate_samples(&user_id, &req.workout_id, &req.samples)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(AppendWorkoutHeartRateResponse {
            stored: req.samples.len() as i32,
        }))
    }

    async fn get_workout_heart_rate(
        &self,
        request: Request<GetWorkoutHeartRateRequest>,
    ) -> Result<Response<GetWorkoutHeartRateResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "GetWorkoutHeartRate", %user_id, workout_id = %req.workout_id, "request");
        let samples = self
            .db
            .get_workout_heart_rate(&user_id, &req.workout_id)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(GetWorkoutHeartRateResponse { samples }))
    }

    // ── Schedule / Drafts ──

    async fn get_proposed_workout_schedule(
        &self,
        request: Request<GetProposedWorkoutScheduleRequest>,
    ) -> Result<Response<GetProposedWorkoutScheduleResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "GetProposedWorkoutSchedule", %user_id, "request");
        let response = self.generate_schedule(&user_id, req.at_time).await?;
        Ok(Response::new(response))
    }

    async fn save_workout_draft(
        &self,
        request: Request<SaveWorkoutDraftRequest>,
    ) -> Result<Response<SaveWorkoutDraftResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "SaveWorkoutDraft", %user_id, "request");
        let req = request.into_inner();
        let draft = req
            .draft
            .ok_or_else(|| Status::invalid_argument("draft is required"))?;
        self.db
            .put_workout_draft(&user_id, &draft)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(SaveWorkoutDraftResponse {
            draft: Some(draft),
        }))
    }

    async fn clear_workout_draft(
        &self,
        request: Request<ClearWorkoutDraftRequest>,
    ) -> Result<Response<ClearWorkoutDraftResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "ClearWorkoutDraft", %user_id, "request");
        self.db
            .clear_workout_draft(&user_id)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(ClearWorkoutDraftResponse {}))
    }

    async fn rehydrate_workout_from_events(
        &self,
        _request: Request<RehydrateWorkoutFromEventsRequest>,
    ) -> Result<Response<RehydrateWorkoutFromEventsResponse>, Status> {
        Err(Status::unimplemented(
            "server workout service does not support rehydration yet",
        ))
    }
}
