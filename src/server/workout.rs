use super::*;
use crate::program_state::{FieldVal, ProposalMessage, ProposeResult, StatePayload};
use crate::regimes::exercise_display_name;
use std::collections::HashMap;

fn build_message(
    key: impl Into<String>,
    kind: UserMessageKind,
    surface: UserMessageSurface,
    title: impl Into<String>,
    body: impl Into<String>,
) -> UserMessage {
    let now = now_unix();
    UserMessage {
        message_key: key.into(),
        kind: kind as i32,
        surface: surface as i32,
        title: title.into(),
        body: body.into(),
        dismissible: true,
        created_at: now,
        updated_at: now,
        workout_id: String::new(),
        source_workout_id: String::new(),
        exercise_group_id: String::new(),
        exercise: Exercise::Unspecified as i32,
        slot_key: String::new(),
        details: None,
    }
}

fn slot_key_for_exercise(exercise: Exercise) -> String {
    exercise.as_str_name().to_ascii_lowercase()
}

fn build_progression_message(
    key: impl Into<String>,
    kind: UserMessageKind,
    exercise: Exercise,
    slot_key: String,
    source_workout_id: &str,
    previous_weight: f32,
    next_weight: f32,
    previous_stage: Option<&str>,
    next_stage: Option<&str>,
    context_label: Option<&str>,
    metric_kind: ProgressionMetricKind,
    reason_kind: ProgressionReasonKind,
    reason_text: Option<&str>,
) -> UserMessage {
    let change_kind = match kind {
        UserMessageKind::LoadIncrease => ProgressionChangeKind::Increase,
        UserMessageKind::LoadHold => ProgressionChangeKind::Hold,
        UserMessageKind::StallDeload => ProgressionChangeKind::Deload,
        UserMessageKind::CycleAdvance => ProgressionChangeKind::CycleAdvance,
        _ => ProgressionChangeKind::Unspecified,
    };
    let mut message = build_message(
        key,
        kind,
        UserMessageSurface::WorkoutBriefing,
        String::new(),
        String::new(),
    );
    message.exercise = exercise as i32;
    message.slot_key = slot_key;
    message.source_workout_id = source_workout_id.to_string();
    message.details = Some(UserMessageDetails {
        detail: Some(user_message_details::Detail::Progression(
            ProgressionDetails {
                change_kind: change_kind as i32,
                metric_kind: metric_kind as i32,
                previous_weight,
                next_weight,
                previous_stage: previous_stage.unwrap_or_default().to_string(),
                next_stage: next_stage.unwrap_or_default().to_string(),
                source_workout_id: source_workout_id.to_string(),
                context_label: context_label.unwrap_or_default().to_string(),
                reason_kind: reason_kind as i32,
                reason_text: reason_text.unwrap_or_default().to_string(),
            },
        )),
    });
    message
}

fn proposed_group_slot_keys(group: &ProposedExerciseGroup) -> Vec<String> {
    let mut out = Vec::new();
    for config in &group.exercise_configs {
        let hinted = config.working_sets.iter().find_map(|set| {
            set.progression_hint
                .as_ref()
                .map(|hint| hint.slot_key.clone())
        });
        let key = hinted.unwrap_or_else(|| {
            Exercise::try_from(config.exercise)
                .unwrap_or(Exercise::Unspecified)
                .as_str_name()
                .to_ascii_lowercase()
        });
        if !key.is_empty() && !out.contains(&key) {
            out.push(key);
        }
    }
    out
}

fn exercise_group_slot_keys(group: &ExerciseGroup) -> Vec<String> {
    let mut out = Vec::new();
    for config in &group.exercise_configs {
        let hinted = config.working_sets.iter().find_map(|set| {
            set.progression_hint
                .as_ref()
                .map(|hint| hint.slot_key.clone())
        });
        let key = hinted.unwrap_or_else(|| {
            Exercise::try_from(config.exercise)
                .unwrap_or(Exercise::Unspecified)
                .as_str_name()
                .to_ascii_lowercase()
        });
        if !key.is_empty() && !out.contains(&key) {
            out.push(key);
        }
    }
    out
}

fn retarget_progression_message(message: &UserMessage) -> UserMessage {
    message.clone()
}

fn schedule_messages_from_proposal(proposal: &ProposeResult, user_id: &str) -> Vec<UserMessage> {
    proposal
        .schedule_messages
        .iter()
        .filter(|message| {
            !message.body.trim().is_empty() && message.kind == UserMessageKind::TemporalDeload
        })
        .map(|message| {
            let mut out = build_message(
                format!("schedule:{user_id}:{}", message.key),
                message.kind,
                message.surface,
                message.title.clone(),
                message.body.clone(),
            );
            out.exercise = message.exercise as i32;
            out.slot_key = message.slot_key.clone();
            out
        })
        .collect()
}

fn pending_briefing_messages_for_proposal(
    pending_messages: &[UserMessage],
    proposed_groups: &[ProposedExerciseGroup],
) -> Vec<UserMessage> {
    let mut out = Vec::new();
    let mut seen = Vec::<String>::new();
    for group in proposed_groups
        .iter()
        .filter(|group| group.tags.iter().any(|tag| tag == "recommended"))
    {
        let slot_keys = proposed_group_slot_keys(group);
        for message in pending_messages {
            if seen.contains(&message.message_key) {
                continue;
            }
            if !slot_keys.contains(&message.slot_key) {
                continue;
            }
            out.push(retarget_progression_message(message));
            seen.push(message.message_key.clone());
        }
    }
    out.sort_by(|a, b| b.updated_at.cmp(&a.updated_at));
    out
}

fn attachable_briefing_messages_for_workout(
    pending_messages: &[UserMessage],
    groups: &[ExerciseGroup],
) -> Vec<(String, String)> {
    let mut attachments = Vec::new();
    let mut seen = Vec::<String>::new();
    for group in groups {
        let slot_keys = exercise_group_slot_keys(group);
        for message in pending_messages {
            if seen.contains(&message.message_key) {
                continue;
            }
            if !slot_keys.contains(&message.slot_key) {
                continue;
            }
            attachments.push((message.message_key.clone(), group.id.clone()));
            seen.push(message.message_key.clone());
        }
    }
    attachments
}

fn session_messages_for_completed_set(
    workout_id: &str,
    proposed_set: &ProposedSet,
    group_name: &str,
    actual_reps: i32,
    _actual_weight: f32,
    ended_at: i64,
) -> Vec<UserMessage> {
    let mut out = Vec::new();
    let hit_target = actual_reps >= proposed_set.target_reps;
    let body = if proposed_set.is_amrap && actual_reps >= proposed_set.target_reps + 2 {
        Some(format!(
            "{} beat the AMRAP floor with {} reps in {}.",
            exercise_display_name(proposed_set.exercise()),
            actual_reps,
            group_name
        ))
    } else if !hit_target {
        Some(format!(
            "{} finished at {} of {} reps in {}.",
            exercise_display_name(proposed_set.exercise()),
            actual_reps,
            proposed_set.target_reps,
            group_name
        ))
    } else {
        None
    };
    let Some(body) = body else {
        return out;
    };
    let mut message = build_message(
        format!("workout:{workout_id}:set:{}", proposed_set.id),
        UserMessageKind::SessionUpdate,
        UserMessageSurface::WorkoutFeed,
        if hit_target {
            "Top set pushed"
        } else {
            "Target missed"
        },
        body,
    );
    message.workout_id = workout_id.to_string();
    message.source_workout_id = workout_id.to_string();
    message.exercise_group_id = proposed_set.exercise_group_id.clone();
    message.exercise = proposed_set.exercise;
    message.updated_at = ended_at;
    out.push(message);
    out
}

fn lp_completion_messages(
    prev: &StatePayload,
    next: &StatePayload,
    slot_outcomes: &HashMap<String, crate::schplanner::SchplannerSlotOutcome>,
    workout_id: &str,
) -> Vec<UserMessage> {
    let lifts = [
        (Exercise::Squat, "squat_weight", "squat_stall_count"),
        (
            Exercise::BenchPress,
            "bench_press_weight",
            "bench_press_stall_count",
        ),
        (
            Exercise::BarbellRow,
            "barbell_row_weight",
            "barbell_row_stall_count",
        ),
        (
            Exercise::OverheadPress,
            "overhead_press_weight",
            "overhead_press_stall_count",
        ),
        (
            Exercise::Deadlift,
            "deadlift_weight",
            "deadlift_stall_count",
        ),
    ];
    let mut out = Vec::new();
    for (exercise, weight_key, stall_key) in lifts {
        let prev_weight = crate::program_state::get_f32_or(prev, weight_key, 0.0);
        let next_weight = crate::program_state::get_f32_or(next, weight_key, 0.0);
        let prev_stall = crate::program_state::get_int_or(prev, stall_key, 0);
        let next_stall = crate::program_state::get_int_or(next, stall_key, 0);
        let Some(outcome) = slot_outcomes.get(&exercise.as_str_name().to_ascii_lowercase()) else {
            continue;
        };
        let slot_key = slot_key_for_exercise(exercise);
        if next_weight > prev_weight + 0.1 {
            out.push(build_progression_message(
                format!("pending:{workout_id}:increase:{slot_key}"),
                UserMessageKind::LoadIncrease,
                exercise,
                slot_key.clone(),
                workout_id,
                prev_weight,
                next_weight,
                None,
                None,
                None,
                ProgressionMetricKind::WorkingWeight,
                ProgressionReasonKind::CompletedAllWorkingSets,
                None,
            ));
        } else if next_weight < prev_weight - 0.1 {
            out.push(build_progression_message(
                format!("pending:{workout_id}:deload:{slot_key}"),
                UserMessageKind::StallDeload,
                exercise,
                slot_key.clone(),
                workout_id,
                prev_weight,
                next_weight,
                None,
                None,
                None,
                ProgressionMetricKind::WorkingWeight,
                ProgressionReasonKind::RepeatedMisses,
                None,
            ));
        } else if next_stall > prev_stall && !outcome.all_sets_hit_target() {
            out.push(build_progression_message(
                format!("pending:{workout_id}:hold:{slot_key}"),
                UserMessageKind::LoadHold,
                exercise,
                slot_key,
                workout_id,
                prev_weight,
                next_weight,
                None,
                None,
                None,
                ProgressionMetricKind::WorkingWeight,
                ProgressionReasonKind::MissedTargetReps,
                None,
            ));
        }
    }
    out
}

fn completion_messages_for_regime(
    regime_type: RegimeType,
    prev: &StatePayload,
    next: &StatePayload,
    slot_outcomes: &HashMap<String, crate::schplanner::SchplannerSlotOutcome>,
    workout_id: &str,
) -> Vec<UserMessage> {
    match regime_type {
        RegimeType::Linear5x5 => lp_completion_messages(prev, next, slot_outcomes, workout_id),
        RegimeType::Gzclp => {
            let lifts = [
                (
                    Exercise::Squat,
                    "squat_t1_weight",
                    Some("squat_t1_stage"),
                    "T1",
                ),
                (
                    Exercise::Deadlift,
                    "deadlift_t1_weight",
                    Some("deadlift_t1_stage"),
                    "T1",
                ),
                (
                    Exercise::BenchPress,
                    "bench_press_t2_weight",
                    Some("bench_press_t2_stage"),
                    "T2",
                ),
                (
                    Exercise::OverheadPress,
                    "overhead_press_t2_weight",
                    Some("overhead_press_t2_stage"),
                    "T2",
                ),
                (
                    Exercise::BarbellRow,
                    "barbell_row_t2_weight",
                    Some("barbell_row_t2_stage"),
                    "T2",
                ),
            ];
            let mut out = Vec::new();
            for (exercise, weight_key, stage_key, tier) in lifts {
                let prev_weight = crate::program_state::get_f32_or(prev, weight_key, 0.0);
                let next_weight = crate::program_state::get_f32_or(next, weight_key, 0.0);
                let prev_stage = stage_key
                    .map(|k| crate::program_state::get_str_or(prev, k, ""))
                    .unwrap_or("");
                let next_stage = stage_key
                    .map(|k| crate::program_state::get_str_or(next, k, ""))
                    .unwrap_or("");
                let slot_key = slot_key_for_exercise(exercise);
                let kind = if next_weight > prev_weight + 0.1 {
                    UserMessageKind::LoadIncrease
                } else if next_weight < prev_weight - 0.1 {
                    UserMessageKind::StallDeload
                } else if prev_stage != next_stage && !next_stage.is_empty() {
                    UserMessageKind::LoadHold
                } else {
                    continue;
                };
                out.push(build_progression_message(
                    format!("pending:{workout_id}:{}:{slot_key}", kind.as_str_name()),
                    kind,
                    exercise,
                    slot_key,
                    workout_id,
                    prev_weight,
                    next_weight,
                    (!prev_stage.is_empty()).then_some(prev_stage),
                    (!next_stage.is_empty()).then_some(next_stage),
                    Some(tier),
                    ProgressionMetricKind::WorkingWeight,
                    match kind {
                        UserMessageKind::LoadIncrease => {
                            ProgressionReasonKind::ClearedProgressionCheck
                        }
                        UserMessageKind::StallDeload => ProgressionReasonKind::RepeatedMisses,
                        UserMessageKind::LoadHold => ProgressionReasonKind::StageAdvance,
                        _ => ProgressionReasonKind::Unspecified,
                    },
                    None,
                ));
            }
            out
        }
        RegimeType::Wendler531 => {
            let lifts = [
                (Exercise::Squat, "squat_tm"),
                (Exercise::BenchPress, "bench_press_tm"),
                (Exercise::Deadlift, "deadlift_tm"),
                (Exercise::OverheadPress, "overhead_press_tm"),
            ];
            let mut out = Vec::new();
            for (exercise, tm_key) in lifts {
                let prev_tm = crate::program_state::get_f32_or(prev, tm_key, 0.0);
                let next_tm = crate::program_state::get_f32_or(next, tm_key, 0.0);
                if next_tm <= prev_tm + 0.1 {
                    continue;
                }
                out.push(build_progression_message(
                    format!(
                        "pending:{workout_id}:cycle:{}",
                        slot_key_for_exercise(exercise)
                    ),
                    UserMessageKind::CycleAdvance,
                    exercise,
                    slot_key_for_exercise(exercise),
                    workout_id,
                    prev_tm,
                    next_tm,
                    None,
                    None,
                    None,
                    ProgressionMetricKind::TrainingMax,
                    ProgressionReasonKind::CycleCompleted,
                    None,
                ));
            }
            out
        }
        _ => Vec::new(),
    }
}

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

    async fn load_schplanner_history(
        &self,
        user_id: &str,
        started_since: i64,
    ) -> Result<Vec<SchplannerWorkoutRecord>, Status> {
        let workouts = self
            .db
            .list_workouts_started_since(user_id, started_since)
            .await
            .map_err(internal_error)?;
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
        let history = self.load_schplanner_history(user_id, 0).await?;
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

        let response = GetProposedWorkoutScheduleResponse {
            exercise_statuses: Vec::new(),
            active_workout_id,
            proposed_groups: proposal.proposed_groups,
            regime_context: Some(proposal.regime_context),
            training_status: Some(training_status),
            suggested_workout_name: proposal.suggested_workout_name,
            draft: self
                .db
                .get_workout_draft(user_id)
                .await
                .map_err(internal_error)?,
            saved_exercise_groups: self
                .db
                .list_profile_exercise_groups(user_id)
                .await
                .map_err(internal_error)?,
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
        let history = self.load_schplanner_history(user_id, 0).await?;
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
        let messages = completion_messages_for_regime(
            regime_type,
            &prev_payload,
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

#[cfg(test)]
mod live_progression_tests {
    use super::*;

    fn authed<T>(token: &str, msg: T) -> Request<T> {
        let mut req = Request::new(msg);
        req.metadata_mut()
            .insert("x-session-token", token.parse().unwrap());
        req
    }

    async fn setup() -> (ServerWorkoutService, String, String) {
        let dir = std::env::temp_dir().join(format!("lift-live-test-{}", Uuid::new_v4()));
        let db = ServerDb::new_in_dir(&dir).await.unwrap();
        let (user, token) = db
            .get_or_create_user_with_auth_session("tester")
            .await
            .unwrap();
        (ServerWorkoutService { db }, user.id, token)
    }

    /// End-to-end through the real RPCs: start a Linear 5x5 squat session, then edit
    /// the weight mid-workout exactly as the app does (ReplaceExerciseGroupPlan with the
    /// progression hints stripped off), complete it heavier, end the workout, and confirm
    /// the next proposal increments from the weight actually lifted. This exercises the
    /// live EndWorkout glue (propose_from_state -> prescribed_slots_from_groups -> reconcile)
    /// that the replay-based unit/scenario tests don't cover.
    #[tokio::test]
    async fn edited_weight_progresses_through_live_end_workout_path() {
        let (svc, user_id, token) = setup().await;

        // Seed Linear 5x5 program state with squat at 175.
        let regime = get_regime(RegimeType::Linear5x5);
        let mut payload = regime.default_state();
        crate::program_state::set_f32(&mut payload, "squat_weight", 175.0);
        svc.db
            .put_program_state(
                &user_id,
                &GetActiveTrainingProgramStateResponse {
                    state: Some(TrainingProgramState {
                        regime_type: RegimeType::Linear5x5 as i32,
                        fields: payload_to_proto(&payload),
                        updated_at: 1,
                        source: "test".to_string(),
                    }),
                    schema: Some(regime.state_schema()),
                },
            )
            .await
            .unwrap();

        // Start a squat 5x5 @175 group WITH hints, as the app does from the proposal.
        let hint = ProgressionHint {
            slot_key: slot_key_for_exercise(Exercise::Squat),
            tier: "MAIN".to_string(),
            rule: ProgressionRule::AllSetsMatchTarget as i32,
            amrap_success_threshold: 0,
            counts_toward_program: true,
        };
        let working_sets = (0..5)
            .map(|_| WorkingSetSpec {
                target_weight: 175.0,
                target_reps: 5,
                is_amrap: false,
                instruction: String::new(),
                progression_hint: Some(hint.clone()),
            })
            .collect::<Vec<_>>();
        let group = ExerciseGroup {
            id: String::new(),
            workout_id: String::new(),
            name: "Squat".to_string(),
            sets: 5,
            interleave_warmups: false,
            workout_order: 0,
            exercise_configs: vec![ExerciseTypeConfig {
                exercise: Exercise::Squat as i32,
                start_weight: 175.0,
                end_weight: 175.0,
                reps: 5,
                include_warmup: false,
                rest_config: None,
                last_set_amrap: false,
                working_sets,
            }],
            rest_config: None,
            instruction: String::new(),
            prescribed_by_regime: false,
        };
        let start = svc
            .start_workout(authed(
                &token,
                StartWorkoutRequest {
                    name: "Workout A".to_string(),
                    exercise_groups: vec![group],
                    started_at: 1000,
                },
            ))
            .await
            .unwrap()
            .into_inner();
        let workout_id = start.workout.unwrap().id;
        let group_id = start.exercise_groups[0].id.clone();

        // Edit the weight mid-workout the way the app does: replace the group's plan with
        // 5 sets @185 and NO progression hints.
        let planned = (0..5)
            .map(|_| PlannedGroupSet {
                exercise: Exercise::Squat as i32,
                target_reps: 5,
                target_weight: 185.0,
                warmup: false,
                rest_after_success: 180,
                rest_after_failure: 300,
                is_amrap: false,
                instruction: String::new(),
                progression_hint: None,
                client_set_id: String::new(),
            })
            .collect::<Vec<_>>();
        let replaced = svc
            .replace_exercise_group_plan(authed(
                &token,
                ReplaceExerciseGroupPlanRequest {
                    workout_id: workout_id.clone(),
                    exercise_group_id: group_id.clone(),
                    name: "Squat".to_string(),
                    interleave_warmups: false,
                    sets: planned,
                    rest_config: None,
                    delete_group_if_empty: false,
                    instruction: String::new(),
                    create_if_missing: false,
                },
            ))
            .await
            .unwrap()
            .into_inner();

        // The edit really did strip the hints (the bug condition).
        assert!(
            replaced
                .generated_sets
                .iter()
                .all(|s| s.progression_hint.is_none()),
            "edit should leave the working sets hint-less, like the real app"
        );
        assert_eq!(replaced.generated_sets.len(), 5);

        // Complete all 5 working sets at the heavier 185x5.
        let mut ts = 1100;
        for set in &replaced.generated_sets {
            svc.complete_set(authed(
                &token,
                CompleteSetRequest {
                    workout_id: workout_id.clone(),
                    proposed_set_id: set.id.clone(),
                    actual_reps: 5,
                    actual_weight: 185.0,
                    completed_at: ts,
                },
            ))
            .await
            .unwrap();
            ts += 10;
        }

        // End the workout: this runs the live reconciliation against program state.
        svc.end_workout(authed(
            &token,
            EndWorkoutRequest {
                workout_id: workout_id.clone(),
                ended_at: ts,
            },
        ))
        .await
        .unwrap();

        // The next proposal should put squat at 190 (185 lifted + 5), proving progression
        // tracked the edited weight even though the hints were gone.
        let sched = svc
            .get_proposed_workout_schedule(authed(
                &token,
                GetProposedWorkoutScheduleRequest {
                    user_id: user_id.clone(),
                    at_time: ts + 100,
                },
            ))
            .await
            .unwrap()
            .into_inner();

        let squat_cfg = sched
            .proposed_groups
            .iter()
            .flat_map(|g| g.exercise_configs.iter())
            .find(|c| c.exercise == Exercise::Squat as i32)
            .expect("squat should appear in the next proposal");
        assert_eq!(
            squat_cfg.start_weight, 190.0,
            "next squat weight should increment from the edited 185"
        );
    }

    /// Editing a group's weight after completing some sets must keep completed sets first
    /// and the regenerated pending sets after them — not interleave them (the "jump around"
    /// bug from a colliding workout_order on the regenerated sets).
    #[tokio::test]
    async fn editing_weight_after_completing_sets_keeps_order_stable() {
        let (svc, _user_id, token) = setup().await;

        let working_sets = (0..5)
            .map(|_| WorkingSetSpec {
                target_weight: 175.0,
                target_reps: 5,
                is_amrap: false,
                instruction: String::new(),
                progression_hint: None,
            })
            .collect::<Vec<_>>();
        let group = ExerciseGroup {
            id: String::new(),
            workout_id: String::new(),
            name: "Squat".to_string(),
            sets: 5,
            interleave_warmups: false,
            workout_order: 0,
            exercise_configs: vec![ExerciseTypeConfig {
                exercise: Exercise::Squat as i32,
                start_weight: 175.0,
                end_weight: 175.0,
                reps: 5,
                include_warmup: false,
                rest_config: None,
                last_set_amrap: false,
                working_sets,
            }],
            rest_config: None,
            instruction: String::new(),
            prescribed_by_regime: false,
        };
        let start = svc
            .start_workout(authed(
                &token,
                StartWorkoutRequest {
                    name: "Workout A".to_string(),
                    exercise_groups: vec![group],
                    started_at: 1000,
                },
            ))
            .await
            .unwrap()
            .into_inner();
        let workout_id = start.workout.unwrap().id;
        let group_id = start.exercise_groups[0].id.clone();
        let working: Vec<_> = start.proposed_sets.iter().filter(|s| !s.warmup).collect();
        assert_eq!(working.len(), 5);

        // Complete the first two working sets at the original 175.
        for (i, set) in working.iter().take(2).enumerate() {
            svc.complete_set(authed(
                &token,
                CompleteSetRequest {
                    workout_id: workout_id.clone(),
                    proposed_set_id: set.id.clone(),
                    actual_reps: 5,
                    actual_weight: 175.0,
                    completed_at: 1100 + i as i64 * 10,
                },
            ))
            .await
            .unwrap();
        }

        // Edit the whole group up to 185 (like the app: no hints).
        let planned = (0..5)
            .map(|_| PlannedGroupSet {
                exercise: Exercise::Squat as i32,
                target_reps: 5,
                target_weight: 185.0,
                warmup: false,
                rest_after_success: 180,
                rest_after_failure: 300,
                is_amrap: false,
                instruction: String::new(),
                progression_hint: None,
                client_set_id: String::new(),
            })
            .collect::<Vec<_>>();
        svc.replace_exercise_group_plan(authed(
            &token,
            ReplaceExerciseGroupPlanRequest {
                workout_id: workout_id.clone(),
                exercise_group_id: group_id.clone(),
                name: "Squat".to_string(),
                interleave_warmups: false,
                sets: planned,
                rest_config: None,
                delete_group_if_empty: false,
                instruction: String::new(),
                create_if_missing: false,
            },
        ))
        .await
        .unwrap();

        // Read back the active (non-cancelled) working sets in order.
        let wk = svc
            .get_workout(authed(
                &token,
                GetWorkoutRequest {
                    workout_id: workout_id.clone(),
                },
            ))
            .await
            .unwrap()
            .into_inner();
        let mut active: Vec<_> = wk
            .proposed_sets
            .iter()
            .filter(|s| !s.warmup && !s.cancelled)
            .collect();
        active.sort_by_key(|s| s.workout_order);
        let weights: Vec<f32> = active.iter().map(|s| s.target_weight).collect();
        assert_eq!(
            weights,
            vec![175.0, 175.0, 185.0, 185.0, 185.0],
            "completed sets must stay first, then the new heavier sets — no interleaving"
        );
    }

    /// EndWorkout must be idempotent: a retry / double-fire on the same workout must not
    /// advance the program twice (175 -> 180, never 175 -> 180 -> 185).
    #[tokio::test]
    async fn end_workout_is_idempotent_and_does_not_double_progress() {
        let (svc, user_id, token) = setup().await;

        let regime = get_regime(RegimeType::Linear5x5);
        let mut payload = regime.default_state();
        crate::program_state::set_f32(&mut payload, "squat_weight", 175.0);
        svc.db
            .put_program_state(
                &user_id,
                &GetActiveTrainingProgramStateResponse {
                    state: Some(TrainingProgramState {
                        regime_type: RegimeType::Linear5x5 as i32,
                        fields: payload_to_proto(&payload),
                        updated_at: 1,
                        source: "test".to_string(),
                    }),
                    schema: Some(regime.state_schema()),
                },
            )
            .await
            .unwrap();

        let hint = ProgressionHint {
            slot_key: slot_key_for_exercise(Exercise::Squat),
            tier: "MAIN".to_string(),
            rule: ProgressionRule::AllSetsMatchTarget as i32,
            amrap_success_threshold: 0,
            counts_toward_program: true,
        };
        let working_sets = (0..5)
            .map(|_| WorkingSetSpec {
                target_weight: 175.0,
                target_reps: 5,
                is_amrap: false,
                instruction: String::new(),
                progression_hint: Some(hint.clone()),
            })
            .collect::<Vec<_>>();
        let group = ExerciseGroup {
            id: String::new(),
            workout_id: String::new(),
            name: "Squat".to_string(),
            sets: 5,
            interleave_warmups: false,
            workout_order: 0,
            exercise_configs: vec![ExerciseTypeConfig {
                exercise: Exercise::Squat as i32,
                start_weight: 175.0,
                end_weight: 175.0,
                reps: 5,
                include_warmup: false,
                rest_config: None,
                last_set_amrap: false,
                working_sets,
            }],
            rest_config: None,
            instruction: String::new(),
            prescribed_by_regime: false,
        };
        let start = svc
            .start_workout(authed(
                &token,
                StartWorkoutRequest {
                    name: "Workout A".to_string(),
                    exercise_groups: vec![group],
                    started_at: 1000,
                },
            ))
            .await
            .unwrap()
            .into_inner();
        let workout_id = start.workout.unwrap().id;

        let mut ts = 1100;
        for set in start.proposed_sets.iter().filter(|s| !s.warmup) {
            svc.complete_set(authed(
                &token,
                CompleteSetRequest {
                    workout_id: workout_id.clone(),
                    proposed_set_id: set.id.clone(),
                    actual_reps: 5,
                    actual_weight: 175.0,
                    completed_at: ts,
                },
            ))
            .await
            .unwrap();
            ts += 10;
        }

        // End it twice — second call is the retry / double-fire.
        for _ in 0..2 {
            svc.end_workout(authed(
                &token,
                EndWorkoutRequest {
                    workout_id: workout_id.clone(),
                    ended_at: ts,
                },
            ))
            .await
            .unwrap();
        }

        let sched = svc
            .get_proposed_workout_schedule(authed(
                &token,
                GetProposedWorkoutScheduleRequest {
                    user_id: user_id.clone(),
                    at_time: ts + 100,
                },
            ))
            .await
            .unwrap()
            .into_inner();
        let squat_cfg = sched
            .proposed_groups
            .iter()
            .flat_map(|g| g.exercise_configs.iter())
            .find(|c| c.exercise == Exercise::Squat as i32)
            .expect("squat should appear in the next proposal");
        assert_eq!(
            squat_cfg.start_weight, 180.0,
            "ending twice must progress 175 -> 180 only once, not 175 -> 180 -> 185"
        );
        // The A/B variant must advance exactly once. A double-apply would flip A->B->A and
        // the next proposal would come back as Workout A; the guard keeps it on B.
        assert!(
            sched.suggested_workout_name.contains('B'),
            "variant should advance exactly once (next session is Workout B), got {:?}",
            sched.suggested_workout_name
        );
    }
}

/// End-to-end coverage of the layoff deload path: a proposal after time away is
/// reduced, and completing that reduced workout must progress from what was
/// actually lifted rather than snapping back to the pre-layoff weight.
///
/// These go through the real RPCs because the deload lives in
/// `get_proposed_workout_schedule` (via `apply_temporal_adjustments_for_proposal`)
/// while reconciliation lives in `end_workout` — the scenario tests in
/// `src/scenario_tests.rs` call the regime directly and so exercise neither.
#[cfg(test)]
mod layoff_deload_tests {
    use super::*;

    const DAY: i64 = 24 * 3600;

    fn authed<T>(token: &str, msg: T) -> Request<T> {
        let mut req = Request::new(msg);
        req.metadata_mut()
            .insert("x-session-token", token.parse().unwrap());
        req
    }

    async fn setup() -> (ServerWorkoutService, String, String) {
        let dir = std::env::temp_dir().join(format!("lift-layoff-test-{}", Uuid::new_v4()));
        let db = ServerDb::new_in_dir(&dir).await.unwrap();
        let (user, token) = db
            .get_or_create_user_with_auth_session("layoff-tester")
            .await
            .unwrap();
        (ServerWorkoutService { db }, user.id, token)
    }

    async fn seed_linear_5x5_squat(svc: &ServerWorkoutService, user_id: &str, weight: f32) {
        let regime = get_regime(RegimeType::Linear5x5);
        let mut payload = regime.default_state();
        crate::program_state::set_f32(&mut payload, "squat_weight", weight);
        svc.db
            .put_program_state(
                user_id,
                &GetActiveTrainingProgramStateResponse {
                    state: Some(TrainingProgramState {
                        regime_type: RegimeType::Linear5x5 as i32,
                        fields: payload_to_proto(&payload),
                        updated_at: 1,
                        source: "test".to_string(),
                    }),
                    schema: Some(regime.state_schema()),
                },
            )
            .await
            .unwrap();
    }

    fn squat_group(weight: f32) -> ExerciseGroup {
        let hint = ProgressionHint {
            slot_key: slot_key_for_exercise(Exercise::Squat),
            tier: "MAIN".to_string(),
            rule: ProgressionRule::AllSetsMatchTarget as i32,
            amrap_success_threshold: 0,
            counts_toward_program: true,
        };
        ExerciseGroup {
            id: String::new(),
            workout_id: String::new(),
            name: "Squat".to_string(),
            sets: 5,
            interleave_warmups: false,
            workout_order: 0,
            exercise_configs: vec![ExerciseTypeConfig {
                exercise: Exercise::Squat as i32,
                start_weight: weight,
                end_weight: weight,
                reps: 5,
                include_warmup: false,
                rest_config: None,
                last_set_amrap: false,
                working_sets: (0..5)
                    .map(|_| WorkingSetSpec {
                        target_weight: weight,
                        target_reps: 5,
                        is_amrap: false,
                        instruction: String::new(),
                        progression_hint: Some(hint.clone()),
                    })
                    .collect(),
            }],
            rest_config: None,
            instruction: String::new(),
            prescribed_by_regime: true,
        }
    }

    /// Perform a full successful squat session at `weight`, starting at `at`.
    /// Returns the timestamp the workout ended.
    async fn do_squat_session(
        svc: &ServerWorkoutService,
        token: &str,
        weight: f32,
        at: i64,
    ) -> i64 {
        let start = svc
            .start_workout(authed(
                token,
                StartWorkoutRequest {
                    name: "Workout A".to_string(),
                    exercise_groups: vec![squat_group(weight)],
                    started_at: at,
                },
            ))
            .await
            .unwrap()
            .into_inner();
        let workout_id = start.workout.unwrap().id;

        let mut ts = at + 60;
        for set in start.proposed_sets.iter().filter(|s| !s.warmup) {
            svc.complete_set(authed(
                token,
                CompleteSetRequest {
                    workout_id: workout_id.clone(),
                    proposed_set_id: set.id.clone(),
                    actual_reps: 5,
                    actual_weight: weight,
                    completed_at: ts,
                },
            ))
            .await
            .unwrap();
            ts += 60;
        }

        svc.end_workout(authed(
            token,
            EndWorkoutRequest {
                workout_id,
                ended_at: ts,
            },
        ))
        .await
        .unwrap();
        ts
    }

    async fn proposed_squat_weight(
        svc: &ServerWorkoutService,
        token: &str,
        user_id: &str,
        at: i64,
    ) -> f32 {
        let sched = svc
            .get_proposed_workout_schedule(authed(
                token,
                GetProposedWorkoutScheduleRequest {
                    user_id: user_id.to_string(),
                    at_time: at,
                },
            ))
            .await
            .unwrap()
            .into_inner();
        sched
            .proposed_groups
            .iter()
            .flat_map(|g| g.exercise_configs.iter())
            .find(|c| c.exercise == Exercise::Squat as i32)
            .expect("squat should appear in the proposal")
            .start_weight
    }

    async fn stored_squat_weight(svc: &ServerWorkoutService, user_id: &str) -> f32 {
        let resp = svc.db.get_program_state(user_id).await.unwrap().unwrap();
        let payload = payload_from_proto(&resp.state.unwrap().fields);
        crate::program_state::get_f32(&payload, "squat_weight").unwrap()
    }

    /// Baseline: a normal gap between sessions must not reduce anything.
    #[tokio::test]
    async fn a_short_gap_does_not_deload() {
        let (svc, user_id, token) = setup().await;
        seed_linear_5x5_squat(&svc, &user_id, 175.0).await;

        let ended = do_squat_session(&svc, &token, 175.0, 1_000_000).await;
        // 175 completed successfully -> next session prescribes 180.
        assert_eq!(stored_squat_weight(&svc, &user_id).await, 180.0);

        for days in [0, 1, 3, 7, 13] {
            let proposed = proposed_squat_weight(&svc, &token, &user_id, ended + days * DAY).await;
            assert_eq!(
                proposed, 180.0,
                "a {days}-day gap is under the 14-day threshold and must not deload"
            );
        }
    }

    /// 14 days away drops the proposal to 90%; 30 days drops it to 80%.
    #[tokio::test]
    async fn a_long_layoff_deloads_the_proposal() {
        let (svc, user_id, token) = setup().await;
        seed_linear_5x5_squat(&svc, &user_id, 175.0).await;
        let ended = do_squat_session(&svc, &token, 175.0, 1_000_000).await;
        assert_eq!(stored_squat_weight(&svc, &user_id).await, 180.0);

        // 90% of 180 = 162, rounded to the nearest 5 lb.
        let at_14 = proposed_squat_weight(&svc, &token, &user_id, ended + 14 * DAY).await;
        assert_eq!(at_14, 160.0, "14 days away should propose 90% of 180");

        let at_29 = proposed_squat_weight(&svc, &token, &user_id, ended + 29 * DAY).await;
        assert_eq!(at_29, 160.0, "29 days is still in the 90% band");

        // 80% of 180 = 144, rounded to the nearest 5 lb.
        let at_30 = proposed_squat_weight(&svc, &token, &user_id, ended + 30 * DAY).await;
        assert_eq!(at_30, 145.0, "30 days away should propose 80% of 180");

        let at_90 = proposed_squat_weight(&svc, &token, &user_id, ended + 90 * DAY).await;
        assert_eq!(at_90, 145.0, "the 80% band has no further steps");
    }

    /// The deload is advisory: it changes what is proposed, not what is stored.
    /// Until a workout is actually completed the program state is untouched, so
    /// simply opening the app after a holiday does not lose your progress.
    #[tokio::test]
    async fn viewing_a_deloaded_proposal_does_not_mutate_stored_state() {
        let (svc, user_id, token) = setup().await;
        seed_linear_5x5_squat(&svc, &user_id, 175.0).await;
        let ended = do_squat_session(&svc, &token, 175.0, 1_000_000).await;
        assert_eq!(stored_squat_weight(&svc, &user_id).await, 180.0);

        for _ in 0..3 {
            let proposed =
                proposed_squat_weight(&svc, &token, &user_id, ended + 60 * DAY).await;
            assert_eq!(proposed, 145.0);
        }

        assert_eq!(
            stored_squat_weight(&svc, &user_id).await,
            180.0,
            "repeatedly viewing a deloaded proposal must not write the deload to state"
        );
    }

    /// The important one. After a layoff the app proposes a reduced weight; when
    /// the user completes exactly that, progression must continue from the weight
    /// they actually lifted. Reconciliation in `end_workout` builds its
    /// prescription WITHOUT the temporal adjustment, so this pins the behaviour
    /// at the seam between the two.
    #[tokio::test]
    async fn completing_a_deloaded_workout_progresses_from_the_deloaded_weight() {
        let (svc, user_id, token) = setup().await;
        seed_linear_5x5_squat(&svc, &user_id, 175.0).await;
        let ended = do_squat_session(&svc, &token, 175.0, 1_000_000).await;
        assert_eq!(stored_squat_weight(&svc, &user_id).await, 180.0);

        let comeback_at = ended + 45 * DAY;
        let deloaded = proposed_squat_weight(&svc, &token, &user_id, comeback_at).await;
        assert_eq!(deloaded, 145.0, "45 days away should propose 80%");

        // Do exactly what the app proposed, successfully.
        let comeback_ended = do_squat_session(&svc, &token, deloaded, comeback_at).await;

        assert_eq!(
            stored_squat_weight(&svc, &user_id).await,
            150.0,
            "a successful comeback session at 145 must progress to 150, not jump \
             back to 185 as if the pre-layoff 180 had been lifted"
        );

        let next = proposed_squat_weight(&svc, &token, &user_id, comeback_ended + DAY).await;
        assert_eq!(next, 150.0, "the next proposal should follow the new weight");
    }

    /// A failed comeback session must stall from the deloaded weight, not the
    /// pre-layoff one.
    #[tokio::test]
    async fn failing_a_deloaded_workout_holds_the_deloaded_weight() {
        let (svc, user_id, token) = setup().await;
        seed_linear_5x5_squat(&svc, &user_id, 175.0).await;
        let ended = do_squat_session(&svc, &token, 175.0, 1_000_000).await;

        let comeback_at = ended + 45 * DAY;
        let deloaded = proposed_squat_weight(&svc, &token, &user_id, comeback_at).await;
        assert_eq!(deloaded, 145.0);

        // Start the deloaded session but miss reps on every set.
        let start = svc
            .start_workout(authed(
                &token,
                StartWorkoutRequest {
                    name: "Comeback".to_string(),
                    exercise_groups: vec![squat_group(deloaded)],
                    started_at: comeback_at,
                },
            ))
            .await
            .unwrap()
            .into_inner();
        let workout_id = start.workout.unwrap().id;
        let mut ts = comeback_at + 60;
        for set in start.proposed_sets.iter().filter(|s| !s.warmup) {
            svc.complete_set(authed(
                &token,
                CompleteSetRequest {
                    workout_id: workout_id.clone(),
                    proposed_set_id: set.id.clone(),
                    actual_reps: 3, // missed the target of 5
                    actual_weight: deloaded,
                    completed_at: ts,
                },
            ))
            .await
            .unwrap();
            ts += 60;
        }
        svc.end_workout(authed(
            &token,
            EndWorkoutRequest {
                workout_id,
                ended_at: ts,
            },
        ))
        .await
        .unwrap();

        assert_eq!(
            stored_squat_weight(&svc, &user_id).await,
            145.0,
            "a failed comeback holds the deloaded weight rather than reverting \
             to the pre-layoff weight"
        );
    }
}

/// A failed session must never make the next session heavier. Complements
/// `layoff_deload_tests`: the layoff case is fixed at the reconciliation seam,
/// these cover a user simply dialling the weight up or down themselves.
#[cfg(test)]
mod failed_session_never_raises_weight_tests {
    use super::*;
    use crate::schplanner::SchplannerSlotOutcome;
    use std::collections::HashMap;

    fn outcome(planned: usize, successful: usize, attempted: f32) -> SchplannerSlotOutcome {
        SchplannerSlotOutcome {
            slot_key: slot_key_for_exercise(Exercise::Squat),
            exercise: Exercise::Squat,
            tier: "MAIN".to_string(),
            rule: ProgressionRule::AllSetsMatchTarget,
            planned_sets: planned,
            completed_sets: planned,
            successful_sets: successful,
            last_completed_actual_weight: Some(attempted),
            last_successful_actual_weight: if successful > 0 { Some(attempted) } else { None },
            top_set_target_reps: 5,
            top_set_actual_reps: if successful > 0 { 5 } else { 3 },
            amrap_success_threshold: 0,
            workout_ended: true,
        }
    }

    fn squat_weight_after(stored: f32, stalls: i64, outcome: SchplannerSlotOutcome) -> f32 {
        let regime = get_regime(RegimeType::Linear5x5);
        let mut state = regime.default_state();
        crate::program_state::set_f32(&mut state, "squat_weight", stored);
        crate::program_state::set_int(&mut state, "squat_stall_count", stalls);

        let mut outcomes = HashMap::new();
        outcomes.insert(slot_key_for_exercise(Exercise::Squat), outcome);

        let record = crate::regimes::fake_completed_workout(1_000);
        regime.transition_state_on_workout_completed(&mut state, &record, &outcomes);
        crate::program_state::get_f32(&state, "squat_weight").unwrap()
    }

    #[tokio::test]
    async fn failing_below_the_stored_weight_holds_the_attempted_weight() {
        // Stored 180, user dialled down to 145 and missed reps.
        assert_eq!(squat_weight_after(180.0, 0, outcome(5, 2, 145.0)), 145.0);
    }

    #[tokio::test]
    async fn failing_above_the_stored_weight_does_not_raise_the_target() {
        // Stored 180, user tried 200 and missed. Next session must not be 200.
        assert_eq!(squat_weight_after(180.0, 0, outcome(5, 2, 200.0)), 180.0);
    }

    #[tokio::test]
    async fn failing_at_the_stored_weight_is_unchanged() {
        assert_eq!(squat_weight_after(180.0, 0, outcome(5, 2, 180.0)), 180.0);
    }

    #[tokio::test]
    async fn succeeding_still_progresses_from_what_was_lifted() {
        assert_eq!(squat_weight_after(180.0, 0, outcome(5, 5, 185.0)), 190.0);
    }

    #[tokio::test]
    async fn third_consecutive_stall_deloads_from_the_attempted_weight() {
        // Two stalls already recorded; this failure is the third -> 10% deload.
        assert_eq!(squat_weight_after(180.0, 2, outcome(5, 2, 180.0)), 160.0);
    }
}
