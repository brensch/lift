//! Construction of user-facing messages: progression summaries after a
//! workout, in-session encouragement, and workout-briefing cards. Pure
//! functions from state to `UserMessage` — no I/O.

use super::*;
use crate::program_state::{ProposeResult, StatePayload};
use crate::regimes::exercise_display_name;
use std::collections::HashMap;

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

pub(super) fn proposed_group_slot_keys(group: &ProposedExerciseGroup) -> Vec<String> {
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

pub(super) fn exercise_group_slot_keys(group: &ExerciseGroup) -> Vec<String> {
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

pub(super) fn retarget_progression_message(message: &UserMessage) -> UserMessage {
    message.clone()
}

pub(super) fn schedule_messages_from_proposal(proposal: &ProposeResult, user_id: &str) -> Vec<UserMessage> {
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

pub(super) fn pending_briefing_messages_for_proposal(
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
    out.sort_by_key(|b| std::cmp::Reverse(b.updated_at));
    out
}

/// One-line recap of what the progression did last session, built from the same
/// progression messages that render as per-lift chips — e.g. "Since last time:
/// Squat +5, Bench held". Empty when there's nothing to say.
pub(super) fn summarize_last_session(pending_messages: &[UserMessage]) -> String {
    let mut parts: Vec<String> = Vec::new();
    let mut seen: Vec<i32> = Vec::new();
    for message in pending_messages {
        let Some(details) = message.details.as_ref().and_then(|d| match &d.detail {
            Some(user_message_details::Detail::Progression(p)) => Some(p),
            _ => None,
        }) else {
            continue;
        };
        // One phrase per lift (the newest message per exercise wins; list is
        // already newest-first from the caller).
        if seen.contains(&message.exercise) {
            continue;
        }
        seen.push(message.exercise);
        let name = exercise_display_name(message.exercise());
        let delta = details.next_weight - details.previous_weight;
        let phrase = match details.change_kind() {
            ProgressionChangeKind::Increase => format!("{name} +{}", trim_num(delta)),
            ProgressionChangeKind::Deload => format!("{name} −{}", trim_num(delta.abs())),
            ProgressionChangeKind::Hold => format!("{name} held"),
            ProgressionChangeKind::CycleAdvance => format!("{name} TM +{}", trim_num(delta)),
            ProgressionChangeKind::Unspecified => continue,
        };
        parts.push(phrase);
    }
    if parts.is_empty() {
        String::new()
    } else {
        format!("Since last time: {}.", parts.join(", "))
    }
}

fn trim_num(v: f32) -> String {
    if (v - v.round()).abs() < 0.05 {
        format!("{}", v.round() as i64)
    } else {
        format!("{v:.1}")
    }
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

pub(super) fn lp_completion_messages(
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
            out.push(build_progression_message(ProgressionMessage {
                    key: format!("pending:{workout_id}:increase:{slot_key}"),
                    kind: UserMessageKind::LoadIncrease,
                    exercise,
                    slot_key: slot_key.clone(),
                    source_workout_id: workout_id,
                    previous_weight: prev_weight,
                    next_weight,
                    previous_stage: None,
                    next_stage: None,
                    context_label: None,
                    metric_kind: ProgressionMetricKind::WorkingWeight,
                    reason_kind: ProgressionReasonKind::CompletedAllWorkingSets,
                    reason_text: None,
                }));
        } else if next_weight < prev_weight - 0.1 {
            out.push(build_progression_message(ProgressionMessage {
                    key: format!("pending:{workout_id}:deload:{slot_key}"),
                    kind: UserMessageKind::StallDeload,
                    exercise,
                    slot_key: slot_key.clone(),
                    source_workout_id: workout_id,
                    previous_weight: prev_weight,
                    next_weight,
                    previous_stage: None,
                    next_stage: None,
                    context_label: None,
                    metric_kind: ProgressionMetricKind::WorkingWeight,
                    reason_kind: ProgressionReasonKind::RepeatedMisses,
                    reason_text: None,
                }));
        } else if next_stall > prev_stall && !outcome.all_sets_hit_target() {
            out.push(build_progression_message(ProgressionMessage {
                    key: format!("pending:{workout_id}:hold:{slot_key}"),
                    kind: UserMessageKind::LoadHold,
                    exercise,
                    slot_key,
                    source_workout_id: workout_id,
                    previous_weight: prev_weight,
                    next_weight,
                    previous_stage: None,
                    next_stage: None,
                    context_label: None,
                    metric_kind: ProgressionMetricKind::WorkingWeight,
                    reason_kind: ProgressionReasonKind::MissedTargetReps,
                    reason_text: None,
                }));
        }
    }
    out
}

pub(super) fn completion_messages_for_regime(
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
                out.push(build_progression_message(ProgressionMessage {
                    key: format!("pending:{workout_id}:{}:{slot_key}", kind.as_str_name()),
                    kind,
                    exercise,
                    slot_key,
                    source_workout_id: workout_id,
                    previous_weight: prev_weight,
                    next_weight,
                    previous_stage: (!prev_stage.is_empty()).then_some(prev_stage),
                    next_stage: (!next_stage.is_empty()).then_some(next_stage),
                    context_label: Some(tier),
                    metric_kind: ProgressionMetricKind::WorkingWeight,
                    reason_kind: match kind {
                        UserMessageKind::LoadIncrease => {
                            ProgressionReasonKind::ClearedProgressionCheck
                        }
                        UserMessageKind::StallDeload => ProgressionReasonKind::RepeatedMisses,
                        UserMessageKind::LoadHold => ProgressionReasonKind::StageAdvance,
                        _ => ProgressionReasonKind::Unspecified,
                    },
                    reason_text: None,
                }));
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
                out.push(build_progression_message(ProgressionMessage {
                    key: format!(
                        "pending:{workout_id}:cycle:{}",
                        slot_key_for_exercise(exercise)
                    ),
                    kind: UserMessageKind::CycleAdvance,
                    exercise,
                    slot_key: slot_key_for_exercise(exercise),
                    source_workout_id: workout_id,
                    previous_weight: prev_tm,
                    next_weight: next_tm,
                    previous_stage: None,
                    next_stage: None,
                    context_label: None,
                    metric_kind: ProgressionMetricKind::TrainingMax,
                    reason_kind: ProgressionReasonKind::CycleCompleted,
                    reason_text: None,
                }));
            }
            out
        }
        _ => Vec::new(),
    }
}
