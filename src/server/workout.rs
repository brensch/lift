use super::*;
use crate::program_state::{
    payload_from_proto, FieldVal, ProposalMessage, ProposeResult, StatePayload,
};
use crate::weight_units::{weight_unit_from_state, AppWeightUnit};
use std::collections::HashMap;

use super::messages::*;

// ── Workout Service ──

#[derive(Clone)]
pub struct ServerWorkoutService {
    pub db: ServerDb,
}

impl ServerWorkoutService {
    fn maybe_annotate_temporal_adjustment(
        stored_payload: &StatePayload,
        effective_payload: &StatePayload,
        last_session_at: i64,
        now: i64,
        proposal: &mut ProposeResult,
    ) {
        if last_session_at <= 0 || stored_payload == effective_payload {
            return;
        }

        let changed_numeric = effective_payload
            .iter()
            .filter_map(|(key, effective)| {
                let stored = stored_payload.get(key)?;
                let stored_num = match stored {
                    FieldVal::Float(v) => Some(v.to_owned()),
                    FieldVal::Int(v) => Some(v.to_owned() as f64),
                    _ => None,
                }?;
                let effective_num = match effective {
                    FieldVal::Float(v) => Some(v.to_owned()),
                    FieldVal::Int(v) => Some(v.to_owned() as f64),
                    _ => None,
                }?;
                if (stored_num - effective_num).abs() < 0.001 {
                    return None;
                }
                Some((key.as_str(), stored_num, effective_num))
            })
            .collect::<Vec<_>>();

        if changed_numeric.is_empty() {
            return;
        }

        let days_since = ((now - last_session_at) / (24 * 3600)).max(0);
        let ratio_pct = changed_numeric
            .first()
            .and_then(|(_, stored, effective)| {
                if *stored > 0.0 {
                    Some((effective / stored * 100.0).round() as i64)
                } else {
                    None
                }
            })
            .unwrap_or(100);
        let lowered_fields = changed_numeric.len();
        let note = format!(
            "Comeback deload applied: after {} days away, today's programmed weights were reduced to about {}% across {} setting{}.",
            days_since,
            ratio_pct,
            lowered_fields,
            if lowered_fields == 1 { "" } else { "s" }
        );
        let already_present = proposal
            .schedule_messages
            .iter()
            .any(|message| message.kind == UserMessageKind::TemporalDeload && message.body == note);
        if !already_present {
            proposal.schedule_messages.insert(
                0,
                ProposalMessage {
                    key: "temporal_adjustment".to_string(),
                    kind: UserMessageKind::TemporalDeload,
                    surface: UserMessageSurface::WorkoutBriefing,
                    title: proposal.regime_context.regime_display_name.clone(),
                    body: note,
                    exercise: Exercise::Unspecified,
                    slot_key: String::new(),
                },
            );
        }
    }

    /// How many recent workouts the scheduler loads for its proposal. The
    /// proposal only uses history for timing insights and the last-session
    /// timestamp (see `load_recent_schplanner_history`), and the most recent
    /// workout — the one that fixes `last_session_at` even after a long layoff —
    /// is always among the newest, so a fixed cap is safe and keeps the load
    /// from growing with a user's training history.
    const RECENT_HISTORY_LIMIT: i64 = 24;

    /// Recent history for the proposal path. Production never replays full
    /// history (state comes from `training_program_state_latest`); it needs only
    /// `last_session_at` and recent timing insights, both of which a bounded
    /// window of the newest workouts satisfies.
    async fn load_recent_schplanner_history(
        &self,
        user_id: &str,
    ) -> Result<Vec<SchplannerWorkoutRecord>, Status> {
        let workouts = self
            .db
            .list_recent_workouts(user_id, Self::RECENT_HISTORY_LIMIT)
            .await
            .map_err(internal_error)?;
        self.hydrate_workout_records(workouts).await
    }

    async fn hydrate_workout_records(
        &self,
        workouts: Vec<Workout>,
    ) -> Result<Vec<SchplannerWorkoutRecord>, Status> {
        let mut history = Vec::with_capacity(workouts.len());
        for workout in workouts {
            let exercise_groups = self
                .db
                .get_exercise_groups(&workout.id)
                .await
                .map_err(internal_error)?;
            let proposed_sets = self
                .db
                .get_proposed_sets(&workout.id)
                .await
                .map_err(internal_error)?;
            let completed_sets = self
                .db
                .get_completed_sets(&workout.id)
                .await
                .map_err(internal_error)?;
            history.push(SchplannerWorkoutRecord {
                workout,
                exercise_groups,
                proposed_sets,
                completed_sets,
            });
        }
        Ok(history)
    }

    async fn load_workout_messages(
        &self,
        user_id: &str,
        workout_id: &str,
    ) -> Result<Vec<UserMessage>, Status> {
        self.db
            .get_workout_user_messages(user_id, workout_id, false)
            .await
            .map_err(internal_error)
    }

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
        let stored_payload = payload_from_proto(&state.fields);
        let now = if at_time > 0 { at_time } else { now_unix() };
        let history = self.load_recent_schplanner_history(user_id).await?;
        let last_session_at = history
            .iter()
            .map(|workout| {
                if workout.workout.end_time > 0 {
                    workout.workout.end_time
                } else {
                    workout.workout.start_time
                }
            })
            .max()
            .unwrap_or(0);
        let effective_state =
            regime.apply_temporal_adjustments_for_proposal(&stored_payload, last_session_at, now);
        let insights = summarize_recent_insights(&history);
        let mut proposal =
            regime.propose_from_state(&effective_state, last_session_at, now, &insights);
        Self::maybe_annotate_temporal_adjustment(
            &stored_payload,
            &effective_state,
            last_session_at,
            now,
            &mut proposal,
        );
        let mut schedule_messages = schedule_messages_from_proposal(&proposal, user_id);
        let pending_messages = self
            .db
            .get_pending_workout_briefing_messages(user_id)
            .await
            .map_err(internal_error)?;
        schedule_messages.extend(pending_briefing_messages_for_proposal(
            &pending_messages,
            &proposal.proposed_groups,
        ));
        schedule_messages.sort_by(|a, b| b.updated_at.cmp(&a.updated_at));
        schedule_messages.dedup_by(|a, b| a.message_key == b.message_key);
        let training_status =
            regime.derive_training_status(&effective_state, &history, last_session_at, now);

        let active_workout_id = self
            .db
            .get_active_workout_id(user_id)
            .await
            .map_err(internal_error)?
            .unwrap_or_default();

        let mut proposed_groups = proposal.proposed_groups;
        let unit = weight_unit_from_state(&effective_state);
        for (i, g) in proposed_groups.iter_mut().enumerate() {
            g.estimated_duration_seconds =
                crate::workout::estimate_group_duration_seconds(g);
            // Materialize the display sets (warmups + working sets) server-side.
            let eg = ExerciseGroup {
                id: format!("preview-{i}"),
                workout_id: String::new(),
                name: g.name.clone(),
                sets: g.sets,
                interleave_warmups: g.interleave_warmups,
                workout_order: i as i32,
                exercise_configs: g.exercise_configs.clone(),
                rest_config: g.rest_config.clone(),
                instruction: String::new(),
                prescribed_by_regime: g.prescribed_by_regime,
                materialized_sets: Vec::new(),
            };
            g.materialized_sets =
                crate::workout::generate_sets_for_group("", &eg, 0, unit);
        }

        let mut saved_exercise_groups = self
            .db
            .list_profile_exercise_groups(user_id)
            .await
            .map_err(internal_error)?;
        for g in &mut saved_exercise_groups {
            g.materialized_sets =
                crate::workout::generate_sets_for_group(&g.id, g, 0, unit);
        }

        let response = GetProposedWorkoutScheduleResponse {
            exercise_statuses: Vec::new(),
            active_workout_id,
            proposed_groups,
            regime_context: Some(proposal.regime_context),
            training_status: Some(training_status),
            suggested_workout_name: proposal.suggested_workout_name,
            draft: self
                .db
                .get_workout_draft(user_id)
                .await
                .map_err(internal_error)?,
            saved_exercise_groups,
            user_messages: schedule_messages,
        };
        self.db
            .put_schedule_cache(user_id, &response)
            .await
            .map_err(internal_error)?;
        Ok(response)
    }

    async fn persist_program_state_after_workout_end(
        &self,
        user_id: &str,
        workout: &SchplannerWorkoutRecord,
    ) -> Result<Vec<UserMessage>, Status> {
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
        let prev_payload = payload_from_proto(&state.fields);

        // Reconcile against the program's prescription for this session, derived from the
        // pre-transition state — NOT from the (possibly user-edited) workout plan. Completed
        // work is matched to prescribed slots by exercise, so editing a weight or
        // deleting/re-adding a group still progresses the correct lift.
        let now = workout
            .workout
            .end_time
            .max(workout.workout.start_time)
            .max(1);
        let history = self.load_recent_schplanner_history(user_id).await?;
        let last_session_at = history
            .iter()
            .filter(|h| h.workout.id != workout.workout.id)
            .map(|h| {
                if h.workout.end_time > 0 {
                    h.workout.end_time
                } else {
                    h.workout.start_time
                }
            })
            .max()
            .unwrap_or(0);
        let insights = summarize_recent_insights(&history);

        // Reconcile against the SAME state the proposal was built from, including any
        // layoff deload. `get_proposed_workout_schedule` applies
        // `apply_temporal_adjustments_for_proposal` before proposing, so after time away
        // the user is shown (and performs) reduced weights. Reconciling against the
        // un-deloaded state instead would judge them against work they were never asked
        // to do, and — because the failure branches of the regimes hold the state weight
        // rather than the attempted one — would prescribe the pre-layoff weight after a
        // failed comeback session, i.e. heavier than the weight they just missed.
        let adjusted_prev =
            regime.apply_temporal_adjustments_for_proposal(&prev_payload, last_session_at, now);
        let mut payload = adjusted_prev.clone();
        let proposal = regime.propose_from_state(&adjusted_prev, last_session_at, now, &insights);
        let prescribed = prescribed_slots_from_groups(&proposal.proposed_groups);
        let slot_outcomes = summarize_slot_outcomes(workout, &prescribed);
        regime.transition_state_on_workout_completed(&mut payload, workout, &slot_outcomes);
        let next_updated_at = workout.workout.end_time.max(workout.workout.start_time);
        let response = GetActiveTrainingProgramStateResponse {
            state: Some(TrainingProgramState {
                regime_type: regime_type as i32,
                fields: payload_to_proto(&payload),
                updated_at: next_updated_at,
                source: format!("workout_completed:{}", workout.workout.id),
            }),
            schema: Some(regime.state_schema()),
        };

        // Idempotency lives in the DB: the first EndWorkout for this workout claims the
        // progression and writes the new state atomically; a retry / double-fire finds the
        // claim already taken and is a no-op, so we never advance twice.
        let applied = self
            .db
            .apply_program_state_for_workout(user_id, &workout.workout.id, &response)
            .await
            .map_err(internal_error)?;
        if !applied {
            return Ok(Vec::new());
        }
        // Compare against the weights the session was actually performed at, not
        // the raw stored state. After a layoff deload the two differ, and using
        // the stored weight would render "180 → 150" (a phantom decrease) when
        // the user deloaded to 145 and progressed to 150. With no layoff,
        // adjusted_prev == prev_payload and this is unchanged.
        let messages = completion_messages_for_regime(
            regime_type,
            &adjusted_prev,
            &payload,
            &slot_outcomes,
            &workout.workout.id,
        );
        if !messages.is_empty() {
            self.db
                .upsert_user_message_events(user_id, &messages)
                .await
                .map_err(internal_error)?;
        }
        Ok(messages)
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

    /// Read the caller's current session id (the single source of truth for group membership).
    async fn get_session_id_for_user(&self, user_id: &str) -> Result<String, Status> {
        Ok(self
            .db
            .get_user_current_session(user_id)
            .await
            .map_err(internal_error)?
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
        // Session attachment is decided by the invariant: whatever session the user is
        // currently in (via user_current_session) is stamped onto the new workout row.
        let session_id = self.get_session_id_for_user(&user_id).await?;
        info!(rpc = "StartWorkout", %user_id, group_count = req.exercise_groups.len(), %session_id, "request");
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
        // Warmups snap to loadable weights in the user's unit, so we need it here.
        let unit = self
            .db
            .get_program_state(&user_id)
            .await
            .map_err(internal_error)?
            .and_then(|resp| resp.state)
            .map(|state| weight_unit_from_state(&payload_from_proto(&state.fields)))
            .unwrap_or(AppWeightUnit::Lb);

        let mut proposed_sets = Vec::new();
        let mut order = 0;
        for group in &groups {
            let generated = generate_sets_for_group(&workout_id, group, order, unit);
            order += generated.len() as i32;
            proposed_sets.extend(generated);
        }

        // Insert real rows
        self.db
            .insert_workout(&user_id, &workout, &groups, &proposed_sets)
            .await
            .map_err(internal_error)?;

        let pending_messages = self
            .db
            .get_pending_workout_briefing_messages(&user_id)
            .await
            .map_err(internal_error)?;
        let attachment_pairs = attachable_briefing_messages_for_workout(&pending_messages, &groups);
        let pending_by_key = pending_messages
            .into_iter()
            .map(|message| (message.message_key.clone(), message))
            .collect::<HashMap<_, _>>();
        let attached_messages = attachment_pairs
            .iter()
            .filter_map(|(message_key, exercise_group_id)| {
                let base = pending_by_key.get(message_key)?;
                let mut message = retarget_progression_message(base);
                message.workout_id = workout_id.clone();
                // Tie the message to this workout so subsequent reads
                // (get_workout / mutation refreshes) keyed by source_workout_id
                // keep returning it for the whole session.
                message.source_workout_id = workout_id.clone();
                message.exercise_group_id = exercise_group_id.clone();
                message.updated_at = started_at;
                Some(message)
            })
            .collect::<Vec<_>>();
        if !attached_messages.is_empty() {
            self.db
                .upsert_user_message_events(&user_id, &attached_messages)
                .await
                .map_err(internal_error)?;
        }

        let active = ActiveWorkout::new(workout, groups, proposed_sets, Vec::new());
        let mut response = start_workout_response_from_active(&active);
        response.user_messages = attached_messages;

        if !session_id.is_empty() {
            refresh_participant_for_user(&self.db, &user_id, &session_id, Some(&workout_id))
                .await?;
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

        // Capture session before ending: once end_workout deletes active_workout_current,
        // the session link is no longer reachable via get_active_workout_id.
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
        let exercise_groups = self
            .db
            .get_exercise_groups(&req.workout_id)
            .await
            .map_err(internal_error)?;
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
        let workout_record = SchplannerWorkoutRecord {
            workout: workout.clone(),
            exercise_groups,
            proposed_sets,
            completed_sets,
        };
        let completion_messages = self
            .persist_program_state_after_workout_end(&user_id, &workout_record)
            .await?;

        if !session_id.is_empty() {
            // Refresh with the finished workout so peers still in the session see the
            // completed participant snapshot instead of a cleared one…
            refresh_participant_for_user(&self.db, &user_id, &session_id, Some(&req.workout_id))
                .await?;
            // …then drop the caller out of the group. Their last blob remains in
            // session_participants_current so peers still polling the session still see
            // them. A subsequent StartWorkout will be solo unless they rejoin.
            self.db
                .clear_user_current_session(&user_id)
                .await
                .map_err(internal_error)?;
        }
        Ok(Response::new(EndWorkoutResponse {
            workout: Some(workout),
            user_messages: completion_messages,
        }))
    }

    async fn get_workout(
        &self,
        request: Request<GetWorkoutRequest>,
    ) -> Result<Response<GetWorkoutResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "GetWorkout", %user_id, workout_id = %req.workout_id, "request");
        let mut workout = self
            .db
            .load_workout_full(&user_id, &req.workout_id)
            .await
            .map_err(internal_error)?
            .ok_or_else(|| Status::not_found("Workout not found"))?;
        workout.user_messages = self
            .load_workout_messages(&user_id, &req.workout_id)
            .await?;
        Ok(Response::new(workout))
    }

    async fn get_active_workout(
        &self,
        request: Request<GetActiveWorkoutRequest>,
    ) -> Result<Response<GetActiveWorkoutResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "GetActiveWorkout", %user_id, "request");
        let workout = if let Some(workout_id) = self
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

    async fn list_workout_summaries(
        &self,
        request: Request<ListWorkoutSummariesRequest>,
    ) -> Result<Response<ListWorkoutSummariesResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "ListWorkoutSummaries", %user_id, "request");
        let full = self
            .db
            .list_finished_workouts_full(&user_id)
            .await
            .map_err(internal_error)?;
        let workouts = full
            .into_iter()
            .map(|(w, proposed, completed)| WorkoutWithSummary {
                summary: Some(crate::progress::compute_workout_summary(
                    &w, &proposed, &completed,
                )),
                workout: Some(w),
            })
            .collect();
        Ok(Response::new(ListWorkoutSummariesResponse { workouts }))
    }

    async fn get_exercise_progress(
        &self,
        request: Request<GetExerciseProgressRequest>,
    ) -> Result<Response<GetExerciseProgressResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "GetExerciseProgress", %user_id, "request");
        let full = self
            .db
            .list_finished_workouts_full(&user_id)
            .await
            .map_err(internal_error)?;
        let workout_count = full.len() as i32;
        let since = full.iter().map(|(w, _, _)| w.start_time).min().unwrap_or(0);
        let total_volume: f32 = full
            .iter()
            .map(|(w, p, c)| crate::progress::compute_workout_summary(w, p, c).total_volume)
            .sum();
        let exercises = crate::progress::compute_exercise_progress(&full);
        Ok(Response::new(GetExerciseProgressResponse {
            exercises,
            workout_count,
            total_volume,
            since,
        }))
    }

    async fn get_recommended_starting_weights(
        &self,
        request: Request<GetRecommendedStartingWeightsRequest>,
    ) -> Result<Response<GetRecommendedStartingWeightsResponse>, Status> {
        let _user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let experience = ExperienceLevel::try_from(req.experience)
            .unwrap_or(ExperienceLevel::Unspecified);
        let weights = crate::onboarding::recommended_starting_weights(
            req.bodyweight_kg as f32,
            experience,
        );
        Ok(Response::new(GetRecommendedStartingWeightsResponse { weights }))
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
                user_messages: self
                    .load_workout_messages(&user_id, &req.workout_id)
                    .await?,
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
            refresh_participant_for_user(&self.db, &user_id, &session_id, Some(&req.workout_id))
                .await?;
        }

        Ok(Response::new(StartSetResponse {
            completed_set: Some(completed_set),
            next_up_set: next_up,
            state_snapshot: snapshot,
            user_messages: self
                .load_workout_messages(&user_id, &req.workout_id)
                .await?,
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
                refresh_participant_for_user(
                    &self.db,
                    &user_id,
                    &session_id,
                    Some(&req.workout_id),
                )
                .await?;
            }

            let group_name = self
                .db
                .get_exercise_groups(&req.workout_id)
                .await
                .map_err(internal_error)?
                .into_iter()
                .find(|g| g.id == proposed.exercise_group_id)
                .map(|g| g.name)
                .unwrap_or_else(|| "current block".to_string());
            let session_messages = session_messages_for_completed_set(
                &req.workout_id,
                &proposed,
                &group_name,
                req.actual_reps,
                req.actual_weight,
                ended_at,
            );
            if !session_messages.is_empty() {
                self.db
                    .upsert_user_message_events(&user_id, &session_messages)
                    .await
                    .map_err(internal_error)?;
            }
            Ok(Response::new(CompleteSetResponse {
                completed_set: Some(completed_set),
                next_up_set: next_up,
                state_snapshot: snapshot,
                user_messages: self
                    .load_workout_messages(&user_id, &req.workout_id)
                    .await?,
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
                refresh_participant_for_user(
                    &self.db,
                    &user_id,
                    &session_id,
                    Some(&req.workout_id),
                )
                .await?;
            }

            let group_name = self
                .db
                .get_exercise_groups(&req.workout_id)
                .await
                .map_err(internal_error)?
                .into_iter()
                .find(|g| g.id == proposed.exercise_group_id)
                .map(|g| g.name)
                .unwrap_or_else(|| "current block".to_string());
            let session_messages = session_messages_for_completed_set(
                &req.workout_id,
                &proposed,
                &group_name,
                req.actual_reps,
                req.actual_weight,
                ended_at,
            );
            if !session_messages.is_empty() {
                self.db
                    .upsert_user_message_events(&user_id, &session_messages)
                    .await
                    .map_err(internal_error)?;
            }
            Ok(Response::new(CompleteSetResponse {
                completed_set: Some(completed_set),
                next_up_set: next_up,
                state_snapshot: snapshot,
                user_messages: self
                    .load_workout_messages(&user_id, &req.workout_id)
                    .await?,
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
            refresh_participant_for_user(&self.db, &user_id, &session_id, Some(&req.workout_id))
                .await?;
        }

        Ok(Response::new(DeleteCompletedSetResponse {
            next_up_set: next_up,
            state_snapshot: snapshot,
            user_messages: self
                .load_workout_messages(&user_id, &req.workout_id)
                .await?,
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
            refresh_participant_for_user(&self.db, &user_id, &session_id, Some(&req.workout_id))
                .await?;
        }

        Ok(Response::new(CancelProposedSetResponse {
            next_up_set: next_up,
            state_snapshot: snapshot,
            user_messages: self
                .load_workout_messages(&user_id, &req.workout_id)
                .await?,
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

        // Warmups snap to loadable weights in the user's unit when regenerated.
        let unit = self
            .db
            .get_program_state(&user_id)
            .await
            .map_err(internal_error)?
            .and_then(|resp| resp.state)
            .map(|state| weight_unit_from_state(&payload_from_proto(&state.fields)))
            .unwrap_or(AppWeightUnit::Lb);

        // Apply the complex group plan replacement
        let (group, generated_sets) =
            apply_replace_exercise_group_plan(&mut active, &req, unit)?;

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
            refresh_participant_for_user(&self.db, &user_id, &session_id, Some(&req.workout_id))
                .await?;
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
            refresh_participant_for_user(&self.db, &user_id, &session_id, Some(&req.workout_id))
                .await?;
        }

        Ok(Response::new(ReorderExerciseGroupsResponse {
            next_up_set: next_up,
            state_snapshot: snapshot,
            user_messages: self
                .load_workout_messages(&user_id, &req.workout_id)
                .await?,
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
        let mut generated_messages = Vec::<UserMessage>::new();

        // A plan edit regenerates warmups, which snap to the user's unit — but the
        // common batch (start/complete a set) doesn't, so only pay the settings
        // read when a replace is actually present.
        let unit = if req
            .mutations
            .iter()
            .any(|m| matches!(&m.mutation, Some(Mutation::ReplaceExerciseGroupPlan(_))))
        {
            self.db
                .get_program_state(&user_id)
                .await
                .map_err(internal_error)?
                .and_then(|resp| resp.state)
                .map(|state| weight_unit_from_state(&payload_from_proto(&state.fields)))
                .unwrap_or(AppWeightUnit::Lb)
        } else {
            AppWeightUnit::Lb
        };

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
                    if let Some(proposed) = active
                        .proposed_sets
                        .iter()
                        .find(|s| s.id == req.proposed_set_id)
                    {
                        let group_name = active
                            .exercise_groups
                            .iter()
                            .find(|g| g.id == proposed.exercise_group_id)
                            .map(|g| g.name.clone())
                            .unwrap_or_else(|| "current block".to_string());
                        generated_messages.extend(session_messages_for_completed_set(
                            &workout_id,
                            proposed,
                            &group_name,
                            req.actual_reps,
                            req.actual_weight,
                            if req.completed_at > 0 {
                                req.completed_at
                            } else {
                                now_unix()
                            },
                        ));
                    }
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
                    apply_replace_exercise_group_plan(&mut active, &req, unit)?;
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

        if !generated_messages.is_empty() {
            self.db
                .upsert_user_message_events(&user_id, &generated_messages)
                .await
                .map_err(internal_error)?;
        }

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
            let workout_record = SchplannerWorkoutRecord {
                workout: active.workout.clone(),
                exercise_groups: active.exercise_groups.clone(),
                proposed_sets: active.proposed_sets.clone(),
                completed_sets: active.completed_sets.clone(),
            };
            let _ = self
                .persist_program_state_after_workout_end(&user_id, &workout_record)
                .await?;
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

        let mut response = get_workout_response_from_active(&active);
        response.user_messages = self.load_workout_messages(&user_id, &workout_id).await?;

        if !active.workout.session_id.is_empty() {
            refresh_participant_for_user(
                &self.db,
                &user_id,
                &active.workout.session_id,
                Some(&workout_id),
            )
            .await?;
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

    async fn dismiss_user_messages(
        &self,
        request: Request<DismissUserMessagesRequest>,
    ) -> Result<Response<DismissUserMessagesResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let dismissed = self
            .db
            .dismiss_user_messages(&user_id, &req.message_keys)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(DismissUserMessagesResponse {
            dismissed_message_keys: dismissed,
        }))
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

    async fn save_profile_exercise_group(
        &self,
        request: Request<SaveProfileExerciseGroupRequest>,
    ) -> Result<Response<SaveProfileExerciseGroupResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "SaveProfileExerciseGroup", %user_id, "request");
        let req = request.into_inner();
        let group = req
            .group
            .ok_or_else(|| Status::invalid_argument("group is required"))?;
        if group.name.trim().is_empty() {
            return Err(Status::invalid_argument("group name is required"));
        }
        if group.exercise_configs.is_empty() {
            return Err(Status::invalid_argument(
                "profile exercise group must include at least one exercise config",
            ));
        }
        let saved = self
            .db
            .save_profile_exercise_group(&user_id, &group)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(SaveProfileExerciseGroupResponse {
            group: Some(saved),
        }))
    }

    async fn delete_profile_exercise_group(
        &self,
        request: Request<DeleteProfileExerciseGroupRequest>,
    ) -> Result<Response<DeleteProfileExerciseGroupResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "DeleteProfileExerciseGroup", %user_id, group_id = %req.group_id, "request");
        if req.group_id.is_empty() {
            return Err(Status::invalid_argument("group_id is required"));
        }
        self.db
            .delete_profile_exercise_group(&user_id, &req.group_id)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(DeleteProfileExerciseGroupResponse {}))
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
