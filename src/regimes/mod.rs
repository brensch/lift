pub mod gzclp;
pub mod linear_5x5;
#[cfg(test)]
pub mod test_harness;
pub mod wendler_531;

use lift::workout::v1::{
    Exercise, ExerciseStatus, MuscleGroup, ProposedExerciseGroup, RegimeType, RestConfig,
    TrainingProgramAtAGlance, TrainingProgramDefinition, TrainingProgramLink, WorkingSetSpec,
};

pub use gzclp::GzclpRegime;
pub use linear_5x5::Linear5x5Regime;
pub use wendler_531::Wendler531Regime;

use crate::program_state::{
    PendingUpdateDef, ProposeResult, StatePayload, WorkoutCompletionResult,
};

// ─── Static exercise metadata ─────────────────────────────────────────────────

#[derive(Clone)]
pub struct ExerciseConfig {
    pub exercise: Exercise,
    pub default_weight: f32,
    pub muscle_groups: &'static [MuscleGroup],
    pub default_sets: i32,
    pub default_reps: i32,
    pub category: lift::workout::v1::ExerciseCategory,
    pub always_include: bool,
}

pub const EXERCISE_CONFIGS: &[ExerciseConfig] = &[
    ExerciseConfig {
        exercise: Exercise::Squat,
        default_weight: 45.0,
        muscle_groups: &[MuscleGroup::Quads, MuscleGroup::Glutes],
        default_sets: 5,
        default_reps: 5,
        category: lift::workout::v1::ExerciseCategory::Compound,
        always_include: true,
    },
    ExerciseConfig {
        exercise: Exercise::BenchPress,
        default_weight: 45.0,
        muscle_groups: &[
            MuscleGroup::Chest,
            MuscleGroup::Triceps,
            MuscleGroup::Shoulders,
        ],
        default_sets: 5,
        default_reps: 5,
        category: lift::workout::v1::ExerciseCategory::Compound,
        always_include: false,
    },
    ExerciseConfig {
        exercise: Exercise::Deadlift,
        default_weight: 135.0,
        muscle_groups: &[
            MuscleGroup::Back,
            MuscleGroup::Hamstrings,
            MuscleGroup::Glutes,
        ],
        default_sets: 1,
        default_reps: 5,
        category: lift::workout::v1::ExerciseCategory::Compound,
        always_include: false,
    },
    ExerciseConfig {
        exercise: Exercise::OverheadPress,
        default_weight: 45.0,
        muscle_groups: &[MuscleGroup::Shoulders, MuscleGroup::Triceps],
        default_sets: 5,
        default_reps: 5,
        category: lift::workout::v1::ExerciseCategory::Compound,
        always_include: false,
    },
    ExerciseConfig {
        exercise: Exercise::BarbellRow,
        default_weight: 65.0,
        muscle_groups: &[MuscleGroup::Back, MuscleGroup::Biceps],
        default_sets: 5,
        default_reps: 5,
        category: lift::workout::v1::ExerciseCategory::Compound,
        always_include: false,
    },
    ExerciseConfig {
        exercise: Exercise::HipThrust,
        default_weight: 45.0,
        muscle_groups: &[MuscleGroup::Glutes, MuscleGroup::Hamstrings],
        default_sets: 5,
        default_reps: 5,
        category: lift::workout::v1::ExerciseCategory::Auxiliary,
        always_include: false,
    },
    ExerciseConfig {
        exercise: Exercise::BulgarianSplitSquat,
        default_weight: 45.0,
        muscle_groups: &[MuscleGroup::Quads, MuscleGroup::Glutes],
        default_sets: 5,
        default_reps: 5,
        category: lift::workout::v1::ExerciseCategory::Auxiliary,
        always_include: false,
    },
    ExerciseConfig {
        exercise: Exercise::RomanianDeadlift,
        default_weight: 45.0,
        muscle_groups: &[
            MuscleGroup::Hamstrings,
            MuscleGroup::Glutes,
            MuscleGroup::Back,
        ],
        default_sets: 5,
        default_reps: 5,
        category: lift::workout::v1::ExerciseCategory::Auxiliary,
        always_include: false,
    },
    ExerciseConfig {
        exercise: Exercise::GluteBridge,
        default_weight: 45.0,
        muscle_groups: &[MuscleGroup::Glutes],
        default_sets: 5,
        default_reps: 5,
        category: lift::workout::v1::ExerciseCategory::Auxiliary,
        always_include: false,
    },
    ExerciseConfig {
        exercise: Exercise::Lunge,
        default_weight: 45.0,
        muscle_groups: &[MuscleGroup::Quads, MuscleGroup::Glutes],
        default_sets: 5,
        default_reps: 5,
        category: lift::workout::v1::ExerciseCategory::Auxiliary,
        always_include: false,
    },
    ExerciseConfig {
        exercise: Exercise::LegCurl,
        default_weight: 45.0,
        muscle_groups: &[MuscleGroup::Hamstrings],
        default_sets: 5,
        default_reps: 5,
        category: lift::workout::v1::ExerciseCategory::Auxiliary,
        always_include: false,
    },
];

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
        _ => "Unknown".to_string(),
    }
}

// ─── Session history (still used for ExerciseStatus display) ─────────────────

/// One workout session's result for a single exercise, newest-first.
/// Used only for building ExerciseStatus for the exercise browser, not progression.
#[derive(Debug, Clone)]
pub struct SessionHistory {
    pub weight: f32,
    pub success: bool,
    pub timestamp: i64,
    pub last_set_reps: i32,
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
    fn default_days_per_week(&self) -> i32;
    fn catalog_meta(&self) -> ProgramCatalogMeta;

    /// Return the editable state schema for this regime (for UI rendering).
    fn state_schema(&self) -> lift::workout::v1::TrainingProgramStateSchema;

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
    ) -> ProposeResult;

    /// Compute the next state after completing a workout. Returns new state snapshot.
    fn transition_state_on_workout_complete(
        &self,
        state: &StatePayload,
        result: &WorkoutCompletionResult,
        ended_at: i64,
    ) -> StatePayload;

    /// Return pending state updates (e.g. temporal deload recommendations).
    /// These block workout start until resolved.
    fn pending_updates_for_state(
        &self,
        state: &StatePayload,
        last_session_at: i64,
        now_ts: i64,
    ) -> Vec<PendingUpdateDef>;

    /// Apply a pending update's resolved field values to state.
    /// Returns the new state or an error string if validation fails.
    fn apply_pending_update_to_state(
        &self,
        state: &StatePayload,
        update_id: &str,
        field_values: &StatePayload,
    ) -> Result<StatePayload, String>;

    /// Recovery window in seconds. Derived from state (e.g. Wendler week).
    fn recovery_seconds_for_state(&self, _state: &StatePayload) -> i64 {
        48 * 3600
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

// ─── Shared helpers ───────────────────────────────────────────────────────────

pub fn make_exercise_type_config(
    exercise: Exercise,
    weight: f32,
    sets: i32,
    reps: i32,
    include_warmup: bool,
) -> lift::workout::v1::ExerciseTypeConfig {
    make_exercise_type_config_amrap(exercise, weight, sets, reps, include_warmup, false)
}

pub fn make_exercise_type_config_amrap(
    exercise: Exercise,
    weight: f32,
    sets: i32,
    reps: i32,
    include_warmup: bool,
    last_set_amrap: bool,
) -> lift::workout::v1::ExerciseTypeConfig {
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
            }
        })
        .collect();
    lift::workout::v1::ExerciseTypeConfig {
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

/// Build a RestConfig with just success/failure values (warmup fields = 0 = system default).
pub fn rest_cfg(success_secs: i32, failure_secs: i32) -> Option<RestConfig> {
    Some(RestConfig {
        rest_after_success: success_secs,
        rest_after_failure: failure_secs,
        rest_after_warmup: 0,
        rest_after_last_warmup: 0,
        ..Default::default()
    })
}

/// Build a single-exercise ProposedExerciseGroup.
pub fn build_single_group(
    exercise: Exercise,
    weight: f32,
    sets: i32,
    reps: i32,
    tags: Vec<String>,
    explanation: String,
    rest_config: Option<RestConfig>,
    include_warmup: bool,
) -> ProposedExerciseGroup {
    build_single_group_amrap(
        exercise,
        weight,
        sets,
        reps,
        tags,
        explanation,
        rest_config,
        include_warmup,
        false,
    )
}

pub fn build_single_group_amrap(
    exercise: Exercise,
    weight: f32,
    sets: i32,
    reps: i32,
    tags: Vec<String>,
    explanation: String,
    rest_config: Option<RestConfig>,
    include_warmup: bool,
    last_set_amrap: bool,
) -> ProposedExerciseGroup {
    let cfg =
        make_exercise_type_config_amrap(exercise, weight, sets, reps, include_warmup, last_set_amrap);
    ProposedExerciseGroup {
        name: exercise_display_name(exercise),
        sets,
        interleave_warmups: false,
        exercise_configs: vec![cfg],
        rest_config,
        tags,
        explanation,
        prescribed_by_regime: false,
    }
}

/// Human-readable readiness label given seconds until next session.
pub fn readiness_label(seconds_until: i64) -> String {
    if seconds_until <= 0 {
        let overdue = -seconds_until;
        let hours = overdue / 3600;
        let days = hours / 24;
        if days > 0 {
            format!("Overdue — {} day{}", days, if days == 1 { "" } else { "s" })
        } else if hours > 0 {
            format!("Overdue — {}h", hours)
        } else {
            "Ready to train!".to_string()
        }
    } else {
        let hours = seconds_until / 3600;
        let days = hours / 24;
        if days >= 2 {
            format!("In {} days", days)
        } else if days == 1 {
            "Tomorrow".to_string()
        } else if hours > 0 {
            format!("In {}h", hours)
        } else {
            "Ready to train!".to_string()
        }
    }
}

/// Build a SessionReadiness struct from last workout end time + recovery window.
pub fn build_session_readiness(
    last_session_at: i64,
    recovery_seconds: i64,
    regime_display_name: &str,
    days_per_week: i32,
    now: i64,
) -> lift::workout::v1::SessionReadiness {
    let next_session_at = last_session_at + recovery_seconds;
    let seconds_until = next_session_at - now;
    let is_ready = now >= next_session_at;
    let is_overdue = now >= next_session_at + 24 * 3600;
    let label = if last_session_at == 0 {
        "Ready to train!".to_string()
    } else {
        readiness_label(seconds_until)
    };
    let detail = format!(
        "Based on {} ({} days/week, {}h recovery)",
        regime_display_name,
        days_per_week,
        recovery_seconds / 3600
    );
    lift::workout::v1::SessionReadiness {
        next_session_at,
        last_session_at,
        readiness_label: label,
        readiness_detail: detail,
        is_ready: last_session_at == 0 || is_ready,
        is_overdue,
    }
}

/// Build ExerciseStatus entries from history (used for display / exercise browser only).
pub fn build_exercise_statuses(
    all_history: &std::collections::HashMap<i32, Vec<SessionHistory>>,
    all_max_weights: &std::collections::HashMap<i32, f32>,
    now: i64,
) -> Vec<ExerciseStatus> {
    const MUSCLE_RECOVERY_HOURS: i64 = 24;
    let recovery_seconds = MUSCLE_RECOVERY_HOURS * 3600;

    let mut muscle_group_last_worked: std::collections::HashMap<i32, i64> =
        std::collections::HashMap::new();
    for config in EXERCISE_CONFIGS {
        let ex_int = config.exercise as i32;
        let last_performed = all_history
            .get(&ex_int)
            .and_then(|h| h.first())
            .map(|h| h.timestamp)
            .unwrap_or(0);
        if last_performed > 0 {
            for mg in config.muscle_groups {
                let entry = muscle_group_last_worked.entry(*mg as i32).or_insert(0);
                if last_performed > *entry {
                    *entry = last_performed;
                }
            }
        }
    }

    EXERCISE_CONFIGS
        .iter()
        .map(|config| {
            let ex_int = config.exercise as i32;
            let empty = Vec::new();
            let history = all_history.get(&ex_int).unwrap_or(&empty);
            let max_weight = all_max_weights.get(&ex_int).copied().unwrap_or(0.0);
            let last_perf = history.first().map(|h| h.timestamp).unwrap_or(0);
            let weight_history: Vec<f32> = history.iter().rev().map(|h| h.weight).collect();
            let recovered = config.muscle_groups.iter().all(|mg| {
                match muscle_group_last_worked.get(&(*mg as i32)) {
                    None => true,
                    Some(&last) => (now - last) >= recovery_seconds,
                }
            });
            ExerciseStatus {
                exercise: ex_int,
                target_weight: max_weight,
                explanation: String::new(),
                last_performed_at: last_perf,
                weight_history,
                muscle_groups: config.muscle_groups.iter().map(|mg| *mg as i32).collect(),
                default_sets: config.default_sets,
                default_reps: config.default_reps,
                recovered,
                always_include: config.always_include,
                category: config.category as i32,
            }
        })
        .collect()
}
