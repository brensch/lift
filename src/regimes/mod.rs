pub mod gzclp;
pub mod linear_5x5;
#[cfg(test)]
pub mod simulator;
#[cfg(test)]
mod simulator_tests;
#[cfg(test)]
mod temporal_tests;
pub mod wendler_531;

use chrono::{Datelike, LocalResult, TimeZone, Utc};
use schlift::workout::v1::{
    Exercise, ProgressionHint, ProgressionRule, ProposedExerciseGroup, RegimeType, RestConfig,
    SlotTrainingStatus, TrainingProgramAtAGlance, TrainingProgramDefinition, TrainingProgramLink,
    TrainingStatus, WorkingSetSpec, Workout,
};

pub use gzclp::GzclpRegime;
pub use linear_5x5::Linear5x5Regime;
pub use wendler_531::Wendler531Regime;

use crate::program_state::{ProposeResult, StatePayload};
use crate::schplanner::{
    summarize_history_window, summarize_proposed_slot_targets, ProposedSlotTarget,
    SchplannerInsights, SchplannerSlotOutcome, SchplannerWorkoutRecord,
};
use std::collections::{HashMap, HashSet};

pub fn exercise_display_name(exercise: Exercise) -> String {
    match exercise {
        Exercise::Squat => "Squat".to_string(),
        Exercise::BenchPress => "Bench Press".to_string(),
        Exercise::Deadlift => "Deadlift".to_string(),
        Exercise::OverheadPress => "OHP".to_string(),
        Exercise::BarbellRow => "Barbell Row".to_string(),
        Exercise::HipThrust => "Hip Thrust".to_string(),
        Exercise::BulgarianSplitSquat => "BSS".to_string(),
        Exercise::RomanianDeadlift => "RDL".to_string(),
        Exercise::GluteBridge => "Glute Bridge".to_string(),
        Exercise::Lunge => "Lunge".to_string(),
        Exercise::LegCurl => "Leg Curl".to_string(),
        // Accessory exercises (added manually, not regime-driven): derive a
        // human label from the enum name rather than showing "Unknown".
        other => prettify_exercise_name(other.as_str_name()),
    }
}

/// Turns an enum name like `EXERCISE_INCLINE_BENCH_PRESS` into `Incline Bench Press`.
fn prettify_exercise_name(str_name: &str) -> String {
    let trimmed = str_name.strip_prefix("EXERCISE_").unwrap_or(str_name);
    if trimmed.is_empty() {
        return "Unknown".to_string();
    }
    trimmed
        .split('_')
        .map(|word| {
            let mut chars = word.chars();
            match chars.next() {
                Some(first) => {
                    first.to_uppercase().collect::<String>() + &chars.as_str().to_lowercase()
                }
                None => String::new(),
            }
        })
        .collect::<Vec<_>>()
        .join(" ")
}

pub fn exercise_short_label(exercise: Exercise) -> &'static str {
    match exercise {
        Exercise::Squat => "SQ",
        Exercise::BenchPress => "BP",
        Exercise::Deadlift => "DL",
        Exercise::OverheadPress => "OHP",
        Exercise::BarbellRow => "BBR",
        Exercise::HipThrust => "HT",
        Exercise::BulgarianSplitSquat => "BSS",
        Exercise::RomanianDeadlift => "RDL",
        Exercise::GluteBridge => "GB",
        Exercise::Lunge => "Lunge",
        Exercise::LegCurl => "LC",
        _ => "Unknown",
    }
}

// ─── Catalog metadata ─────────────────────────────────────────────────────────

pub struct ProgramCatalogMeta {
    pub headline: &'static str,
    pub summary: &'static str,
    pub description: &'static str,
    pub how_it_works: &'static str,
    pub at_a_glance: ProgramAtAGlanceMeta,
    pub details: Vec<&'static str>,
    pub learn_more_links: Vec<(&'static str, &'static str)>,
    pub sort_order: i32,
}

pub struct ProgramAtAGlanceMeta {
    pub days_per_week: &'static str,
    pub best_for: &'static str,
    pub average_session_time: &'static str,
    pub progression_style: &'static str,
}

// ─── Trait ────────────────────────────────────────────────────────────────────

pub trait WorkoutRegime: Send + Sync {
    fn display_name(&self) -> &'static str;
    fn catalog_meta(&self) -> ProgramCatalogMeta;

    /// Return the editable state schema for this regime (for UI rendering).
    fn state_schema(&self) -> schlift::workout::v1::TrainingProgramStateSchema;

    /// Return a default initial state (used when no state exists yet or for onboarding defaults).
    fn default_state(&self) -> StatePayload;

    /// Validate state fields. Returns a list of warning strings (non-fatal).
    /// Backend will accept even invalid state if explicitly set by the user.
    fn validate_state(&self, state: &StatePayload) -> Vec<String>;

    /// Compute the proposed workout from state + time. Pure function, no side effects.
    fn propose_from_state(
        &self,
        state: &StatePayload,
        last_session_at: i64,
        now_ts: i64,
        insights: &SchplannerInsights,
    ) -> ProposeResult;

    /// Apply non-persisted proposal-time adjustments such as long-break deloads.
    fn apply_temporal_adjustments_for_proposal(
        &self,
        state: &StatePayload,
        _last_session_at: i64,
        _now_ts: i64,
    ) -> StatePayload {
        state.clone()
    }

    fn derive_training_status(
        &self,
        state: &StatePayload,
        history: &[SchplannerWorkoutRecord],
        last_session_at: i64,
        now_ts: i64,
    ) -> TrainingStatus;

    fn transition_state_on_workout_completed(
        &self,
        _state: &mut StatePayload,
        _workout: &SchplannerWorkoutRecord,
        _slot_outcomes: &HashMap<String, SchplannerSlotOutcome>,
    ) {
    }

    fn training_program_definition(&self, regime_type: RegimeType) -> TrainingProgramDefinition {
        let meta = self.catalog_meta();
        TrainingProgramDefinition {
            regime_type: regime_type as i32,
            display_name: self.display_name().to_string(),
            headline: meta.headline.to_string(),
            summary: meta.summary.to_string(),
            description: meta.description.to_string(),
            how_it_works: meta.how_it_works.to_string(),
            at_a_glance: Some(TrainingProgramAtAGlance {
                days_per_week: meta.at_a_glance.days_per_week.to_string(),
                best_for: meta.at_a_glance.best_for.to_string(),
                average_session_time: meta.at_a_glance.average_session_time.to_string(),
                progression_style: meta.at_a_glance.progression_style.to_string(),
            }),
            details: meta.details.into_iter().map(str::to_string).collect(),
            learn_more_links: meta
                .learn_more_links
                .into_iter()
                .map(|(label, url)| TrainingProgramLink {
                    label: label.to_string(),
                    url: url.to_string(),
                })
                .collect(),
            sort_order: meta.sort_order,
            state_schema: Some(self.state_schema()),
        }
    }
}

// ─── Factory ─────────────────────────────────────────────────────────────────

pub fn get_regime(regime_type: RegimeType) -> Box<dyn WorkoutRegime> {
    match regime_type {
        RegimeType::Gzclp => Box::new(GzclpRegime),
        RegimeType::Wendler531 => Box::new(Wendler531Regime),
        // Default / Linear5x5
        _ => Box::new(Linear5x5Regime),
    }
}

pub fn catalog_regime_types() -> Vec<RegimeType> {
    vec![
        RegimeType::Linear5x5,
        RegimeType::Gzclp,
        RegimeType::Wendler531,
    ]
}

pub fn make_exercise_type_config_amrap(
    exercise: Exercise,
    weight: f32,
    sets: i32,
    reps: i32,
    include_warmup: bool,
    last_set_amrap: bool,
) -> schlift::workout::v1::ExerciseTypeConfig {
    let count = sets.max(1);
    let working_sets = (0..count)
        .map(|idx| {
            let is_last = idx == count - 1;
            let is_amrap = last_set_amrap && is_last;
            WorkingSetSpec {
                target_weight: weight,
                target_reps: reps,
                is_amrap,
                instruction: if is_amrap {
                    "AMRAP — push for max reps".to_string()
                } else {
                    String::new()
                },
                progression_hint: Some(progression_hint_for_set(
                    exercise,
                    "MAIN",
                    ProgressionRule::AllSetsMatchTarget,
                    0,
                    true,
                )),
            }
        })
        .collect();
    schlift::workout::v1::ExerciseTypeConfig {
        exercise: exercise as i32,
        start_weight: weight,
        end_weight: weight,
        reps,
        include_warmup,
        rest_config: None,
        last_set_amrap,
        working_sets,
    }
}

pub fn progression_slot_key(exercise: Exercise) -> String {
    exercise.as_str_name().to_ascii_lowercase()
}

pub fn progression_hint_for_set(
    exercise: Exercise,
    tier: &str,
    rule: ProgressionRule,
    amrap_success_threshold: i32,
    counts_toward_program: bool,
) -> ProgressionHint {
    ProgressionHint {
        slot_key: progression_slot_key(exercise),
        tier: tier.to_string(),
        rule: rule as i32,
        amrap_success_threshold,
        counts_toward_program,
    }
}

pub fn fake_completed_workout(at_time: i64) -> SchplannerWorkoutRecord {
    SchplannerWorkoutRecord {
        workout: Workout {
            id: String::new(),
            name: String::new(),
            start_time: at_time,
            end_time: at_time,
            session_id: String::new(),
        },
        exercise_groups: Vec::new(),
        proposed_sets: Vec::new(),
        completed_sets: Vec::new(),
    }
}

pub fn slot_status_label(
    now_ts: i64,
    next_session_at: i64,
    last_trained_at: i64,
    remaining_sets: i32,
    appears_next: bool,
) -> String {
    if appears_next && now_ts >= next_session_at {
        "Up next".to_string()
    } else if appears_next {
        "Scheduled next".to_string()
    } else if last_trained_at == 0 {
        "Untrained".to_string()
    } else if remaining_sets > 0 {
        format!("{} sets left", remaining_sets)
    } else {
        "On track".to_string()
    }
}

pub fn format_time_until(target_ts: i64, now_ts: i64) -> String {
    let delta = target_ts - now_ts;
    if delta <= 0 {
        return "now".to_string();
    }
    let hours = (delta + 3599) / 3600;
    if hours < 24 {
        format!("in {}h", hours)
    } else {
        let days = (hours + 23) / 24;
        format!("in {} day{}", days, if days == 1 { "" } else { "s" })
    }
}

fn this_week_bounds(now_ts: i64) -> (i64, i64) {
    let Some(now_dt) = Utc.timestamp_opt(now_ts, 0).single() else {
        return (now_ts, now_ts);
    };
    let days_since_sunday = i64::from(now_dt.weekday().num_days_from_sunday());
    let start_date = now_dt.date_naive() - chrono::Duration::days(days_since_sunday);
    let end_date = start_date + chrono::Duration::days(7);
    let start_ts = match Utc.with_ymd_and_hms(
        start_date.year(),
        start_date.month(),
        start_date.day(),
        0,
        0,
        0,
    ) {
        LocalResult::Single(dt) => dt.timestamp(),
        _ => now_ts,
    };
    let end_ts =
        match Utc.with_ymd_and_hms(end_date.year(), end_date.month(), end_date.day(), 0, 0, 0) {
            LocalResult::Single(dt) => dt.timestamp() - 1,
            _ => now_ts,
        };
    (start_ts, end_ts)
}

pub fn build_training_status(
    history: &[SchplannerWorkoutRecord],
    now_ts: i64,
    last_session_at: i64,
    next_session_at: i64,
    target_sessions_per_7_days: i32,
    next_workout_slots: &HashSet<String>,
    target_slot_sets: HashMap<String, ProposedSlotTarget>,
) -> TrainingStatus {
    let (window_start, window_end) = this_week_bounds(now_ts);
    let window = summarize_history_window(history, window_start, window_end);
    let target_sets_per_7_days = target_slot_sets
        .values()
        .map(|slot| slot.set_count)
        .sum::<i32>();
    let remaining_sessions_per_7_days =
        (target_sessions_per_7_days - window.completed_sessions).max(0);
    let remaining_sets_per_7_days = (target_sets_per_7_days - window.completed_sets).max(0);
    let should_train_now = now_ts >= next_session_at;

    let headline = if last_session_at == 0 {
        "First Schlift ready".to_string()
    } else if should_train_now {
        "Schlift today".to_string()
    } else {
        format!(
            "Next Schlift {}",
            format_time_until(next_session_at, now_ts)
        )
    };

    let mut slot_statuses = target_slot_sets
        .into_iter()
        .map(|(slot_key, target)| {
            let completed = window
                .slots
                .get(&slot_key)
                .map(|slot| slot.completed_sets)
                .unwrap_or(0);
            let last_trained_at = window
                .slots
                .get(&slot_key)
                .map(|slot| slot.last_trained_at)
                .unwrap_or(0);
            let remaining = (target.set_count - completed).max(0);
            let days_since = if last_trained_at > 0 {
                ((now_ts - last_trained_at).max(0) / (24 * 3600)) as i32
            } else {
                0
            };
            let appears_next = next_workout_slots.contains(&slot_key);
            SlotTrainingStatus {
                slot_key: target.slot_key.clone(),
                label: exercise_display_name(target.exercise),
                tier: target.tier.clone(),
                last_trained_at,
                days_since_last_trained: days_since,
                target_sets_per_7_days: target.set_count,
                completed_sets_per_7_days: completed,
                remaining_sets_per_7_days: remaining,
                appears_in_next_workout: appears_next,
                status_label: slot_status_label(
                    now_ts,
                    next_session_at,
                    last_trained_at,
                    remaining,
                    appears_next,
                ),
            }
        })
        .collect::<Vec<_>>();
    slot_statuses.sort_by(|a, b| a.label.cmp(&b.label));

    TrainingStatus {
        next_session_at,
        last_session_at,
        headline,
        detail: String::new(),
        should_train_now,
        target_sessions_per_7_days,
        completed_sessions_per_7_days: window.completed_sessions,
        remaining_sessions_per_7_days,
        target_sets_per_7_days,
        completed_sets_per_7_days: window.completed_sets,
        remaining_sets_per_7_days,
        slot_statuses,
    }
}

pub fn simulate_target_slot_sets(
    regime: &dyn WorkoutRegime,
    state: &StatePayload,
    last_session_at: i64,
    now_ts: i64,
    session_count: i32,
) -> HashMap<String, ProposedSlotTarget> {
    let mut sim_state = state.clone();
    let mut combined = HashMap::<String, ProposedSlotTarget>::new();
    let empty_insights = SchplannerInsights::default();
    let empty_outcomes = HashMap::<String, SchplannerSlotOutcome>::new();
    for idx in 0..session_count.max(0) {
        let proposal =
            regime.propose_from_state(&sim_state, last_session_at, now_ts, &empty_insights);
        for (slot_key, target) in summarize_proposed_slot_targets(&proposal.proposed_groups) {
            let entry = combined
                .entry(slot_key.clone())
                .or_insert_with(|| ProposedSlotTarget {
                    slot_key,
                    exercise: target.exercise,
                    tier: target.tier.clone(),
                    set_count: 0,
                });
            entry.set_count += target.set_count;
        }
        if idx + 1 < session_count {
            let fake = fake_completed_workout(now_ts + i64::from(idx) * 3600);
            regime.transition_state_on_workout_completed(&mut sim_state, &fake, &empty_outcomes);
        }
    }
    combined
}

/// Build a RestConfig with just success/failure values (warmup fields = 0 = system default).
pub fn rest_cfg(success_secs: i32, failure_secs: i32) -> Option<RestConfig> {
    Some(RestConfig {
        rest_after_success: success_secs,
        rest_after_failure: failure_secs,
        rest_after_warmup: 0,
        rest_after_last_warmup: 0,
    })
}

pub struct SingleGroupOptions {
    pub tags: Vec<String>,
    pub rest_config: Option<RestConfig>,
    pub include_warmup: bool,
    pub last_set_amrap: bool,
}

/// Build a single-exercise ProposedExerciseGroup.
pub fn build_single_group_amrap(
    exercise: Exercise,
    weight: f32,
    sets: i32,
    reps: i32,
    options: SingleGroupOptions,
) -> ProposedExerciseGroup {
    let cfg = make_exercise_type_config_amrap(
        exercise,
        weight,
        sets,
        reps,
        options.include_warmup,
        options.last_set_amrap,
    );
    ProposedExerciseGroup {
        name: exercise_display_name(exercise),
        sets,
        interleave_warmups: false,
        exercise_configs: vec![cfg],
        rest_config: options.rest_config,
        tags: options.tags,
        prescribed_by_regime: false,
                estimated_duration_seconds: 0,
    }
}
