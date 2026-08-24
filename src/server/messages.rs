//! Construction of user-facing messages: progression summaries after a
//! workout, in-session encouragement, and workout-briefing cards. Pure
//! functions from state to `UserMessage` — no I/O.

use super::*;
use crate::exercise_catalog::exercise_display_name;

pub(super) fn build_message(
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

pub(super) fn slot_key_for_exercise(exercise: Exercise) -> String {
    exercise.as_str_name().to_ascii_lowercase()
}

/// Everything a progression message needs. A struct rather than a parameter
/// list because the call sites pass a dozen values, most of them optional, and
/// positional arguments made them unreadable and easy to transpose.
pub(super) struct ProgressionMessage<'a> {
    pub(super) key: String,
    pub(super) kind: UserMessageKind,
    pub(super) exercise: Exercise,
    pub(super) slot_key: String,
    pub(super) source_workout_id: &'a str,
    pub(super) previous_weight: f32,
    pub(super) next_weight: f32,
    pub(super) previous_stage: Option<&'a str>,
    pub(super) next_stage: Option<&'a str>,
    pub(super) context_label: Option<&'a str>,
    pub(super) metric_kind: ProgressionMetricKind,
    pub(super) reason_kind: ProgressionReasonKind,
    pub(super) reason_text: Option<&'a str>,
}

impl Default for ProgressionMessage<'_> {
    fn default() -> Self {
        Self {
            key: String::new(),
            kind: UserMessageKind::Unspecified,
            exercise: Exercise::Unspecified,
            slot_key: String::new(),
            source_workout_id: "",
            previous_weight: 0.0,
            next_weight: 0.0,
            previous_stage: None,
            next_stage: None,
            context_label: None,
            metric_kind: ProgressionMetricKind::Unspecified,
            reason_kind: ProgressionReasonKind::Unspecified,
            reason_text: None,
        }
    }
}

pub(super) fn build_progression_message(params: ProgressionMessage<'_>) -> UserMessage {
    let ProgressionMessage {
        key,
        kind,
        exercise,
        slot_key,
        source_workout_id,
        previous_weight,
        next_weight,
        previous_stage,
        next_stage,
        context_label,
        metric_kind,
        reason_kind,
        reason_text,
    } = params;
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

pub(super) fn exercise_group_slot_keys(group: &ExerciseGroup) -> Vec<String> {
    let mut out = Vec::new();
    for config in &group.exercise_configs {
        let key = Exercise::try_from(config.exercise)
            .unwrap_or(Exercise::Unspecified)
            .as_str_name()
            .to_ascii_lowercase();
        if !key.is_empty() && !out.contains(&key) {
            out.push(key);
        }
    }
    out
}

pub(super) fn retarget_progression_message(message: &UserMessage) -> UserMessage {
    message.clone()
}

pub(super) fn attachable_briefing_messages_for_workout(
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

pub(super) fn session_messages_for_completed_set(
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

