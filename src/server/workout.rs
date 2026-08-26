use super::*;
use crate::exercise_catalog::{category, load_style, primary_muscle};
use crate::exercise_progress::{
    advance_tracker, resolve_tracker, session_outcomes, weight_history, TrackerState,
};
use crate::history::WorkoutRecord;
use crate::recovery::per_muscle_recovery;
use crate::volume::{muscle_volume_7d, suggest_template};
use crate::weight_units::AppWeightUnit;
use std::collections::HashMap;

use super::messages::*;

// ── Workout Service ──

#[derive(Clone)]
pub struct ServerWorkoutService {
    pub db: ServerDb,
}

impl ServerWorkoutService {
    /// How many recent workouts the home/progression paths load. Volume
    /// needs 7 days and recovery needs the latest session per muscle; a
    /// fixed cap keeps the load flat as history accumulates.
    const RECENT_HISTORY_LIMIT: i64 = 24;

    /// Recent history: enough for volume (7 days), recovery, weight
    /// sparklines and the suggestion tie-break.
    async fn load_recent_history(
        &self,
        user_id: &str,
    ) -> Result<Vec<WorkoutRecord>, Status> {
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
    ) -> Result<Vec<WorkoutRecord>, Status> {
        let mut history = Vec::with_capacity(workouts.len());
        for workout in workouts {
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
            history.push(WorkoutRecord {
                workout,
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

    /// The unit the user picked in settings. Every warmup snap and
    /// progression step rounds in this unit.
    async fn get_weight_unit(&self, user_id: &str) -> Result<AppWeightUnit, Status> {
        let settings = self
            .db
            .get_settings(user_id)
            .await
            .map_err(internal_error)?;
        for setting in settings {
            if let Some(schlift::workout::v1::user_setting::Setting::WeightUnit(config)) =
                setting.setting
            {
                return Ok(crate::weight_units::unit_from_proto(config.unit));
            }
        }
        Ok(AppWeightUnit::Lb)
    }

    /// Advance every tracker touched by a finished workout — the single
    /// seam where performance becomes prescription. Idempotent through the
    /// `progression_applied` claim: a re-fired EndWorkout moves nothing.
    /// Returns the progression messages describing what changed.
    async fn apply_progression_for_workout(
        &self,
        user_id: &str,
        record: &WorkoutRecord,
    ) -> Result<Vec<UserMessage>, Status> {
        if record.workout.end_time <= 0 {
            return Ok(Vec::new());
        }
        let claimed = self
            .db
            .claim_progression(user_id, &record.workout.id)
            .await
            .map_err(internal_error)?;
        if !claimed {
            return Ok(Vec::new());
        }

        let unit = self.get_weight_unit(user_id).await?;
        let states = self
            .db
            .get_tracker_states(user_id)
            .await
            .map_err(internal_error)?;

        let mut messages = Vec::new();
        for (exercise_value, outcome) in session_outcomes(record) {
            let Ok(exercise) = Exercise::try_from(exercise_value) else {
                continue;
            };
            if exercise == Exercise::Unspecified {
                continue;
            }
            let before = states.get(&exercise_value).copied().unwrap_or_default();
            let after = advance_tracker(exercise, &before, &outcome, unit);
            self.db
                .upsert_tracker_state(
                    user_id,
                    exercise_value,
                    &after,
                    &format!("workout:{}", record.workout.id),
                )
                .await
                .map_err(internal_error)?;
            if let Some(message) = progression_message_for_change(
                exercise,
                outcome.performed_weight,
                &after,
                &record.workout.id,
            ) {
                messages.push(message);
            }
        }
        if !messages.is_empty() {
            self.db
                .upsert_user_message_events(user_id, &messages)
                .await
                .map_err(internal_error)?;
        }
        Ok(messages)
    }

    /// Resolve exercises into plans: weights from the trackers, sets/reps/
    /// rest from the prescription, and the layoff deload applied at
    /// resolution time only (never written back — it sticks only once the
    /// user trains).
    async fn exercise_plans(
        &self,
        user_id: &str,
        exercises: &[i32],
        now: i64,
    ) -> Result<Vec<ExercisePlan>, Status> {
        let unit = self.get_weight_unit(user_id).await?;
        let states = self
            .db
            .get_tracker_states(user_id)
            .await
            .map_err(internal_error)?;

        let mut plans = Vec::new();
        for exercise_value in exercises {
            let Ok(exercise) = Exercise::try_from(*exercise_value) else {
                continue;
            };
            if exercise == Exercise::Unspecified {
                continue;
            }
            let resolved = resolve_tracker(exercise, states.get(exercise_value), unit);
            let weight = layoff_adjusted_weight(
                exercise,
                resolved.working_weight,
                resolved.last_performed_at,
                now,
                unit,
            );
            plans.push(ExercisePlan {
                exercise: *exercise_value,
                working_weight: weight,
                sets: resolved.sets,
                reps: resolved.target_reps,
                rest_success: resolved.rest_seconds,
                rest_failure: resolved.rest_seconds_failure,
                include_warmup: resolved.include_warmup,
            });
        }
        Ok(plans)
    }

    /// Load a workout, apply one plan-shaping change, persist, and answer
    /// with the full visible plan — the shared spine of the four plan ops.
    async fn apply_plan_op(
        &self,
        user_id: &str,
        workout_id: &str,
        apply: impl FnOnce(&mut ActiveWorkout) -> Result<(), crate::workout::WorkoutError>,
    ) -> Result<WorkoutPlanResponse, Status> {
        let resp = self
            .db
            .load_workout_full(user_id, workout_id)
            .await
            .map_err(internal_error)?
            .ok_or_else(|| Status::not_found("Workout not found"))?;
        let mut active = active_from_get_workout_response(resp)?;

        apply(&mut active)?;

        self.db
            .persist_workout_state(
                user_id,
                &active.workout,
                &active.proposed_sets,
                &active.completed_sets,
            )
            .await
            .map_err(internal_error)?;

        let visible = active_proposed_sets(&active.proposed_sets);
        let next_up = compute_next_up_set(&visible, &active.completed_sets);
        let snapshot = Some(workout_state_snapshot_from_state(
            &active.proposed_sets,
            &active.completed_sets,
            now_unix(),
        ));

        let session_id = self.get_session_id_for_user(user_id).await?;
        if !session_id.is_empty() {
            refresh_participant_for_user(&self.db, user_id, &session_id, Some(workout_id))
                .await?;
        }

        Ok(WorkoutPlanResponse {
            proposed_sets: visible,
            next_up_set: next_up,
            state_snapshot: snapshot,
        })
    }

    /// Everything the home screen needs, in one response.
    async fn build_home(&self, user_id: &str) -> Result<GetHomeResponse, Status> {
        let now = now_unix();
        let unit = self.get_weight_unit(user_id).await?;
        let history = self.load_recent_history(user_id).await?;
        let states = self
            .db
            .get_tracker_states(user_id)
            .await
            .map_err(internal_error)?;
        let templates = self
            .db
            .list_templates(user_id)
            .await
            .map_err(internal_error)?;
        let history_series = weight_history(&history);

        let trackers: Vec<ExerciseTracker> = crate::exercise_catalog::all_exercises()
            .into_iter()
            .map(|exercise| {
                let value = exercise as i32;
                let resolved = resolve_tracker(exercise, states.get(&value), unit);
                ExerciseTracker {
                    exercise: value,
                    working_weight: resolved.working_weight,
                    sets: resolved.sets,
                    target_reps: resolved.target_reps,
                    rep_range_low: resolved.rep_low,
                    rep_range_high: resolved.rep_high,
                    rest_seconds: resolved.rest_seconds,
                    rest_seconds_failure: resolved.rest_seconds_failure,
                    include_warmup: resolved.include_warmup,
                    last_performed_at: resolved.last_performed_at,
                    weight_history: history_series.get(&value).cloned().unwrap_or_default(),
                    overridden: resolved.overridden,
                    primary_muscle: primary_muscle(exercise) as i32,
                    category: category(exercise) as i32,
                    equipment: load_style(exercise).to_proto() as i32,
                }
            })
            .collect();

        let volume = muscle_volume_7d(&history, now);
        let recovery = per_muscle_recovery(&history, now)
            .into_iter()
            .map(|entry| MuscleRecoveryStatus {
                muscle_key: crate::exercise_catalog::muscle_key(entry.muscle).to_string(),
                label: crate::exercise_catalog::muscle_label(entry.muscle).to_string(),
                last_trained_at: entry.last_trained_at,
                recovered_at: entry.recovered_at,
                fraction: entry.fraction,
                hours_remaining: entry.hours_remaining(now),
                recovered: entry.is_recovered(now),
            })
            .collect();

        let last_started = self
            .db
            .template_last_started(user_id)
            .await
            .map_err(internal_error)?;
        let (suggested_template_id, suggestion_reason) =
            suggest_template(&templates, &volume, &last_started).unwrap_or_default();

        let active_workout_id = self
            .db
            .get_active_workout_id(user_id)
            .await
            .map_err(internal_error)?
            .unwrap_or_default();

        let user_messages = self
            .db
            .get_pending_workout_briefing_messages(user_id)
            .await
            .map_err(internal_error)?;

        let onboarded = !templates.is_empty() || !history.is_empty();

        Ok(GetHomeResponse {
            templates,
            trackers,
            active_workout_id,
            user_messages,
            volume,
            recovery,
            suggested_template_id,
            suggestion_reason,
            onboarded,
        })
    }

    /// Load proposed_sets + completed_sets for a workout and compute next_up + snapshot.
    async fn load_sets_and_compute(
        &self,
        user_id: &str,
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
        // Ownership gate: everything below is keyed by workout_id alone.
        self.db
            .get_workout(user_id, workout_id)
            .await
            .map_err(internal_error)?
            .ok_or_else(|| Status::not_found("Workout not found"))?;
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
        info!(rpc = "StartWorkout", %user_id, template_id = %req.template_id, exercise_count = req.exercises.len(), %session_id, "request");
        let workout_id = Uuid::new_v4().to_string();
        let started_at = if req.started_at > 0 {
            req.started_at
        } else {
            now_unix()
        };

        // A start is always server-resolved: weights from the trackers,
        // sets/reps/rest from the prescription. The client sends a template
        // id, an explicit exercise list, or nothing (an empty workout).
        let (exercises, workout_name) = if !req.template_id.is_empty() {
            let template = self
                .db
                .get_template(&user_id, &req.template_id)
                .await
                .map_err(internal_error)?
                .ok_or_else(|| Status::not_found("Template not found"))?;
            let name = if req.name.is_empty() {
                template.name.clone()
            } else {
                req.name.clone()
            };
            (template.exercises, name)
        } else {
            let name = if req.name.is_empty() {
                "Workout".to_string()
            } else {
                req.name.clone()
            };
            (req.exercises, name)
        };
        let plans = self.exercise_plans(&user_id, &exercises, started_at).await?;

        let workout = Workout {
            id: workout_id.clone(),
            name: workout_name,
            start_time: started_at,
            end_time: 0,
            session_id: session_id.clone(),
            template_id: req.template_id.clone(),
        };
        // Warmups snap to loadable weights in the user's unit, so we need it here.
        let unit = self.get_weight_unit(&user_id).await?;

        let mut active = ActiveWorkout::new(workout, Vec::new(), Vec::new());
        apply_add_exercises(&mut active, &workout_id, &plans, &[], unit)?;

        // Insert real rows
        self.db
            .insert_workout(&user_id, &active.workout, &active.proposed_sets)
            .await
            .map_err(internal_error)?;

        let pending_messages = self
            .db
            .get_pending_workout_briefing_messages(&user_id)
            .await
            .map_err(internal_error)?;
        let plan_exercises: Vec<i32> = plans.iter().map(|plan| plan.exercise).collect();
        let attachment_keys =
            attachable_briefing_messages_for_workout(&pending_messages, &plan_exercises);
        let pending_by_key = pending_messages
            .into_iter()
            .map(|message| (message.message_key.clone(), message))
            .collect::<HashMap<_, _>>();
        let attached_messages = attachment_keys
            .iter()
            .filter_map(|message_key| {
                let base = pending_by_key.get(message_key)?;
                let mut message = retarget_progression_message(base);
                message.workout_id = workout_id.clone();
                // Tie the message to this workout so subsequent reads
                // (get_workout / mutation refreshes) keyed by source_workout_id
                // keep returning it for the whole session.
                message.source_workout_id = workout_id.clone();
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
        let workout_record = WorkoutRecord {
            workout: workout.clone(),
            proposed_sets,
            completed_sets,
        };
        let completion_messages = self
            .apply_progression_for_workout(&user_id, &workout_record)
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
        // The app renders visible sets; cancelled rows are server-side
        // state (they mark a bailed exercise for progression).
        workout.proposed_sets.retain(|set| !set.cancelled);
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
            .get_proposed_set(&user_id, &req.proposed_set_id)
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
            .get_proposed_set(&user_id, &req.proposed_set_id)
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

        let is_final = is_final_set_of_exercise_after_completion(
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
            rest_seconds = END_OF_EXERCISE_REST_SECONDS;
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

            let session_messages = session_messages_for_completed_set(
                &req.workout_id,
                &proposed,
                req.actual_reps,
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

            let session_messages = session_messages_for_completed_set(
                &req.workout_id,
                &proposed,
                req.actual_reps,
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
            .delete_completed_set(&user_id, &req.completed_set_id, &req.workout_id)
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
            .cancel_proposed_set(&user_id, &req.proposed_set_id, &req.workout_id)
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

    async fn add_exercises(
        &self,
        request: Request<AddExercisesRequest>,
    ) -> Result<Response<WorkoutPlanResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "AddExercises", %user_id, workout_id = %req.workout_id, exercise_count = req.exercises.len(), "request");
        let plans = self
            .exercise_plans(&user_id, &req.exercises, now_unix())
            .await?;
        let unit = self.get_weight_unit(&user_id).await?;
        let response = self
            .apply_plan_op(&user_id, &req.workout_id, |active| {
                apply_add_exercises(
                    active,
                    &req.workout_id,
                    &plans,
                    &req.client_working_set_ids,
                    unit,
                )
            })
            .await?;
        Ok(Response::new(response))
    }

    async fn adjust_exercise_weight(
        &self,
        request: Request<AdjustExerciseWeightRequest>,
    ) -> Result<Response<WorkoutPlanResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "AdjustExerciseWeight", %user_id, workout_id = %req.workout_id, exercise = req.exercise, working_weight = req.working_weight, "request");
        let unit = self.get_weight_unit(&user_id).await?;
        let response = self
            .apply_plan_op(&user_id, &req.workout_id, |active| {
                apply_adjust_exercise_weight(active, &req, unit)
            })
            .await?;
        Ok(Response::new(response))
    }

    async fn remove_exercise(
        &self,
        request: Request<RemoveExerciseRequest>,
    ) -> Result<Response<WorkoutPlanResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "RemoveExercise", %user_id, workout_id = %req.workout_id, exercise = req.exercise, "request");
        let response = self
            .apply_plan_op(&user_id, &req.workout_id, |active| {
                apply_remove_exercise(active, &req)
            })
            .await?;
        Ok(Response::new(response))
    }

    async fn reorder_exercises(
        &self,
        request: Request<ReorderExercisesRequest>,
    ) -> Result<Response<WorkoutPlanResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "ReorderExercises", %user_id, workout_id = %req.workout_id, "request");
        let response = self
            .apply_plan_op(&user_id, &req.workout_id, |active| {
                apply_reorder_exercises(active, &req)
            })
            .await?;
        Ok(Response::new(response))
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
            Some(Mutation::AddExercises(m)) => m.workout_id.clone(),
            Some(Mutation::AdjustExerciseWeight(m)) => m.workout_id.clone(),
            Some(Mutation::RemoveExercise(m)) => m.workout_id.clone(),
            Some(Mutation::ReorderExercises(m)) => m.workout_id.clone(),
            None => return Err(Status::invalid_argument("mutation payload missing")),
        };
        info!(rpc = "AppendWorkoutMutations", %user_id, %workout_id, mutation_count = req.mutations.len(), "request");

        // For batch mutations, load full state and use reducers (same as before)
        // An unknown workout (deleted, or a stale queue from another
        // device) means none of these mutations can ever apply — consume
        // them rather than erroring, or the client retries the batch
        // forever and every later mutation wedges behind it.
        let Some(resp) = self
            .db
            .load_workout_full(&user_id, &workout_id)
            .await
            .map_err(internal_error)?
        else {
            tracing::warn!(%user_id, %workout_id, "consuming queued mutations for an unknown workout");
            let applied = req
                .mutations
                .iter()
                .map(|m| {
                    if m.event_id.is_empty() {
                        Uuid::new_v4().to_string()
                    } else {
                        m.event_id.clone()
                    }
                })
                .collect();
            return Ok(Response::new(AppendWorkoutMutationsResponse {
                applied_event_ids: applied,
                workout_state: None,
            }));
        };
        let mut active = active_from_get_workout_response(resp)?;
        let mut applied = Vec::with_capacity(req.mutations.len());
        let mut generated_messages = Vec::<UserMessage>::new();

        // Plan edits generate/regenerate warmups, which snap to the user's
        // unit — but the common batch (start/complete a set) doesn't, so only
        // pay the settings read when a plan op is actually present.
        let unit = if req.mutations.iter().any(|m| {
            matches!(
                &m.mutation,
                Some(Mutation::AddExercises(_)) | Some(Mutation::AdjustExerciseWeight(_))
            )
        }) {
            self.get_weight_unit(&user_id).await?
        } else {
            AppWeightUnit::Lb
        };

        for mutation in req.mutations {
            let event_id = if mutation.event_id.is_empty() {
                Uuid::new_v4().to_string()
            } else {
                mutation.event_id.clone()
            };
            // The queue is at-least-once and survives app restarts, so a
            // mutation that can never apply (stale workout id, a plan op on
            // a finished workout, a rejected weight) must be consumed, not
            // retried forever — one poison mutation would wedge every set
            // completion queued behind it. Skips are logged and acked.
            let applied_result: Result<(), Status> = match mutation
                .mutation
                .ok_or_else(|| Status::invalid_argument("mutation missing"))?
            {
                Mutation::StartSet(req) => {
                    apply_start_set_to_active(&mut active, &req).map_err(Into::into)
                }
                Mutation::CompleteSet(req) => {
                    let result = apply_complete_set_to_active(&mut active, &req);
                    if result.is_ok() {
                        if let Some(proposed) = active
                            .proposed_sets
                            .iter()
                            .find(|s| s.id == req.proposed_set_id)
                        {
                            generated_messages.extend(session_messages_for_completed_set(
                                &workout_id,
                                proposed,
                                req.actual_reps,
                                if req.completed_at > 0 {
                                    req.completed_at
                                } else {
                                    now_unix()
                                },
                            ));
                        }
                    }
                    result.map_err(Into::into)
                }
                Mutation::DeleteCompletedSet(req) => {
                    apply_delete_completed_set_to_active(&mut active, &req).map_err(Into::into)
                }
                Mutation::CancelProposedSet(req) => {
                    apply_cancel_proposed_set_to_active(&mut active, &req).map_err(Into::into)
                }
                Mutation::EndWorkout(req) => {
                    let ended_at = if req.ended_at > 0 {
                        req.ended_at
                    } else {
                        now_unix()
                    };
                    active.workout.end_time = ended_at;
                    Ok(())
                }
                Mutation::AddExercises(req) => {
                    let plans = self
                        .exercise_plans(&user_id, &req.exercises, now_unix())
                        .await?;
                    apply_add_exercises(
                        &mut active,
                        &req.workout_id,
                        &plans,
                        &req.client_working_set_ids,
                        unit,
                    )
                    .map_err(Into::into)
                }
                Mutation::AdjustExerciseWeight(req) => {
                    apply_adjust_exercise_weight(&mut active, &req, unit).map_err(Into::into)
                }
                Mutation::RemoveExercise(req) => {
                    apply_remove_exercise(&mut active, &req).map_err(Into::into)
                }
                Mutation::ReorderExercises(req) => {
                    apply_reorder_exercises(&mut active, &req).map_err(Into::into)
                }
            };
            if let Err(error) = applied_result {
                tracing::warn!(
                    %user_id,
                    %workout_id,
                    %event_id,
                    %error,
                    "skipping unappliable queued mutation"
                );
            }
            applied.push(event_id);
        }

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
            let workout_record = WorkoutRecord {
                workout: active.workout.clone(),
                proposed_sets: active.proposed_sets.clone(),
                completed_sets: active.completed_sets.clone(),
            };
            let _ = self
                .apply_progression_for_workout(&user_id, &workout_record)
                .await?;
        } else {
            self.db
                .persist_workout_state(
                    &user_id,
                    &active.workout,
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



    // ── Home, templates, trackers ──

    async fn get_home(
        &self,
        request: Request<GetHomeRequest>,
    ) -> Result<Response<GetHomeResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "GetHome", %user_id, "request");
        Ok(Response::new(self.build_home(&user_id).await?))
    }

    async fn save_template(
        &self,
        request: Request<SaveTemplateRequest>,
    ) -> Result<Response<SaveTemplateResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let template = req
            .template
            .ok_or_else(|| Status::invalid_argument("template is required"))?;
        info!(rpc = "SaveTemplate", %user_id, template_id = %template.id, "request");
        if template.name.trim().is_empty() {
            return Err(Status::invalid_argument("A template needs a name"));
        }
        if template.exercises.is_empty() {
            return Err(Status::invalid_argument(
                "A template needs at least one exercise",
            ));
        }
        let stored = self
            .db
            .save_template(&user_id, &template)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(SaveTemplateResponse {
            template: Some(stored),
        }))
    }

    async fn delete_template(
        &self,
        request: Request<DeleteTemplateRequest>,
    ) -> Result<Response<DeleteTemplateResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "DeleteTemplate", %user_id, template_id = %req.template_id, "request");
        self.db
            .delete_template(&user_id, &req.template_id)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(DeleteTemplateResponse {}))
    }

    async fn reorder_templates(
        &self,
        request: Request<ReorderTemplatesRequest>,
    ) -> Result<Response<ReorderTemplatesResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "ReorderTemplates", %user_id, count = req.template_ids.len(), "request");
        self.db
            .reorder_templates(&user_id, &req.template_ids)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(ReorderTemplatesResponse {}))
    }

    async fn set_exercise_tracker(
        &self,
        request: Request<SetExerciseTrackerRequest>,
    ) -> Result<Response<SetExerciseTrackerResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "SetExerciseTracker", %user_id, exercise = req.exercise, weight = req.working_weight, "request");
        let exercise = Exercise::try_from(req.exercise)
            .ok()
            .filter(|ex| *ex != Exercise::Unspecified)
            .ok_or_else(|| Status::invalid_argument("Unknown exercise"))?;
        if req.override_rep_low > 0 && req.override_rep_high < req.override_rep_low {
            return Err(Status::invalid_argument(
                "The rep range top must be at or above the bottom",
            ));
        }

        let unit = self.get_weight_unit(&user_id).await?;
        let states = self
            .db
            .get_tracker_states(&user_id)
            .await
            .map_err(internal_error)?;
        let previous = states.get(&req.exercise).copied().unwrap_or_default();
        let state = TrackerState {
            working_weight: crate::exercise_catalog::snap_weight_lb(
                exercise,
                req.working_weight.max(0.0),
                unit,
            ),
            // A manual correction restarts the rep climb at the range
            // bottom; resolution clamps 0 there.
            current_reps: 0,
            consecutive_misses: 0,
            last_performed_at: previous.last_performed_at,
            override_sets: req.override_sets.max(0),
            override_rep_low: req.override_rep_low.max(0),
            override_rep_high: req.override_rep_high.max(0),
        };
        self.db
            .upsert_tracker_state(&user_id, req.exercise, &state, "manual")
            .await
            .map_err(internal_error)?;

        let resolved = resolve_tracker(exercise, Some(&state), unit);
        Ok(Response::new(SetExerciseTrackerResponse {
            tracker: Some(ExerciseTracker {
                exercise: req.exercise,
                working_weight: resolved.working_weight,
                sets: resolved.sets,
                target_reps: resolved.target_reps,
                rep_range_low: resolved.rep_low,
                rep_range_high: resolved.rep_high,
                rest_seconds: resolved.rest_seconds,
                rest_seconds_failure: resolved.rest_seconds_failure,
                include_warmup: resolved.include_warmup,
                last_performed_at: resolved.last_performed_at,
                weight_history: Vec::new(),
                overridden: resolved.overridden,
                primary_muscle: primary_muscle(exercise) as i32,
                category: category(exercise) as i32,
                equipment: load_style(exercise).to_proto() as i32,
            }),
        }))
    }

    async fn complete_onboarding(
        &self,
        request: Request<CompleteOnboardingRequest>,
    ) -> Result<Response<CompleteOnboardingResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "CompleteOnboarding", %user_id, unit = req.unit, bodyweight_kg = req.body_weight_kg, "request");

        // The unit is the one thing onboarding always sets.
        if req.unit != WeightUnit::Unspecified as i32 {
            self.db
                .put_setting(
                    &user_id,
                    "weight_unit",
                    &UserSetting {
                        setting: Some(schlift::workout::v1::user_setting::Setting::WeightUnit(
                            WeightUnitConfig { unit: req.unit },
                        )),
                    },
                )
                .await
                .map_err(internal_error)?;
        }
        let unit = crate::weight_units::unit_from_proto(req.unit);

        // Idempotent: with templates already present this is a repeat call
        // (or a returning user) and seeding again would duplicate.
        let existing = self
            .db
            .list_templates(&user_id)
            .await
            .map_err(internal_error)?;
        if existing.is_empty() {
            // Trackers for the main lifts, scaled from bodyweight and
            // experience when given; the catalog opener otherwise.
            let states = self
                .db
                .get_tracker_states(&user_id)
                .await
                .map_err(internal_error)?;
            let experience = ExperienceLevel::try_from(req.experience)
                .unwrap_or(ExperienceLevel::Unspecified);
            let gender = Gender::try_from(req.gender).unwrap_or(Gender::Unspecified);
            for (exercise, weight) in crate::onboarding::starting_tracker_weights(
                req.body_weight_kg,
                experience,
                gender,
                unit,
            ) {
                if states.contains_key(&(exercise as i32)) {
                    continue;
                }
                let state = TrackerState {
                    working_weight: weight,
                    ..Default::default()
                };
                self.db
                    .upsert_tracker_state(&user_id, exercise as i32, &state, "onboarding")
                    .await
                    .map_err(internal_error)?;
            }

            let now = now_unix();
            for (order, (name, exercises)) in
                crate::db::default_templates().into_iter().enumerate()
            {
                let template = WorkoutTemplate {
                    id: String::new(),
                    name: name.to_string(),
                    order: order as i32,
                    exercises: exercises.into_iter().map(|e| e as i32).collect(),
                    created_at: now,
                    updated_at: now,
                };
                self.db
                    .save_template(&user_id, &template)
                    .await
                    .map_err(internal_error)?;
            }
        }

        Ok(Response::new(CompleteOnboardingResponse {
            home: Some(self.build_home(&user_id).await?),
        }))
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





}

/// The layoff deload: 90% after 14 days away from this exercise, 80% after
/// 30, snapped loadable. Resolution-time only — the tracker is never
/// written here, so just looking never costs anything; the reduction
/// sticks only when the user performs the reduced session (progression
/// follows performed weight).
fn layoff_adjusted_weight(
    exercise: Exercise,
    weight: f32,
    last_performed_at: i64,
    now: i64,
    unit: AppWeightUnit,
) -> f32 {
    if last_performed_at <= 0 || weight <= 0.0 {
        return weight;
    }
    let days = (now - last_performed_at) / (24 * 3600);
    let factor = if days >= 30 {
        0.8
    } else if days >= 14 {
        0.9
    } else {
        return weight;
    };
    crate::exercise_catalog::snap_weight_lb(exercise, weight * factor, unit)
}

/// One progression card per exercise per workout: what you lifted and
/// what the tracker says next time. Weight moves name the delta; a hold
/// stays quiet unless a deload happened (a "nothing changed" card for
/// every exercise every session would be noise).
fn progression_message_for_change(
    exercise: Exercise,
    performed_weight: f32,
    after: &TrackerState,
    workout_id: &str,
) -> Option<UserMessage> {
    if performed_weight <= 0.0 {
        return None;
    }
    let next = after.working_weight;
    let slot_key = slot_key_for_exercise(exercise);
    let (kind, reason_kind) = if next > performed_weight + 0.1 {
        (
            UserMessageKind::LoadIncrease,
            ProgressionReasonKind::CompletedAllWorkingSets,
        )
    } else if next < performed_weight - 0.1 {
        (
            UserMessageKind::StallDeload,
            ProgressionReasonKind::RepeatedMisses,
        )
    } else {
        return None;
    };
    Some(build_progression_message(ProgressionMessage {
        key: format!("pending:{workout_id}:{}:{slot_key}", kind.as_str_name()),
        kind,
        exercise,
        slot_key,
        source_workout_id: workout_id,
        previous_weight: performed_weight,
        next_weight: next,
        previous_stage: None,
        next_stage: None,
        context_label: None,
        metric_kind: ProgressionMetricKind::WorkingWeight,
        reason_kind,
        reason_text: None,
    }))
}
