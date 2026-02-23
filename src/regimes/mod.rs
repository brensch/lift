pub mod gzclp;
pub mod linear_5x5;
#[cfg(test)]
pub mod test_harness;
pub mod wendler_531_3day;
pub mod wendler_531_4day;

use std::collections::HashMap;

use lift::workout::v1::{
    Exercise, ExerciseStatus, ExerciseTypeConfig, MuscleGroup, ProposedExerciseGroup,
    RegimeContext, RegimeType, RestConfig, SessionReadiness, TrainingProgramConfigField,
    TrainingProgramDefinition, TrainingProgramFieldBinding, TrainingProgramFieldKind,
    TrainingProgramIntChoice, TrainingProgramLink, TrainingProgramAtAGlance, UserWorkoutConfig,
    WorkingSetSpec,
};

pub use gzclp::GzclpRegime;
pub use linear_5x5::Linear5x5Regime;
pub use wendler_531_3day::Wendler5313DayRegime;
pub use wendler_531_4day::Wendler5314DayRegime;

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

// ─── Per-session history entry ────────────────────────────────────────────────

/// One workout session's result for a single exercise, newest-first.
#[derive(Debug, Clone)]
pub struct SessionHistory {
    pub weight: f32,
    pub success: bool,      // all prescribed reps completed
    pub timestamp: i64,     // unix seconds
    pub last_set_reps: i32, // actual reps logged on last working set; 0 if unknown
}

// ─── Proposal output from a regime ───────────────────────────────────────────

pub struct ExerciseProposal {
    pub weight: f32,
    pub sets: i32,
    pub reps: i32,
    pub explanation: String,
}

pub struct ProgramCatalogMeta {
    pub headline: &'static str,
    pub summary: &'static str,
    pub description: &'static str,
    pub how_it_works: &'static str,
    pub at_a_glance: ProgramAtAGlanceMeta,
    pub details: Vec<&'static str>,
    pub learn_more_links: Vec<(&'static str, &'static str)>,
    pub config_fields: Vec<ProgramConfigFieldDef>,
    pub sort_order: i32,
}

pub struct ProgramAtAGlanceMeta {
    pub days_per_week: &'static str,
    pub best_for: &'static str,
    pub average_session_time: &'static str,
    pub progression_style: &'static str,
}

#[allow(dead_code)]
pub enum ProgramFieldDefault {
    Int(i32),
    Float(f32),
    Bool(bool),
}

pub struct ProgramConfigFieldDef {
    pub key: &'static str,
    pub label: &'static str,
    pub help_text: &'static str,
    pub kind: TrainingProgramFieldKind,
    pub binding: TrainingProgramFieldBinding,
    pub required: bool,
    pub default_value: ProgramFieldDefault,
    pub exercise_id: i32,
    pub int_choices: Vec<(i32, &'static str)>,
}

pub fn cfg_field_days_per_week(
    key: &'static str,
    label: &'static str,
    help_text: &'static str,
    default_days: i32,
    choices: Vec<(i32, &'static str)>,
) -> ProgramConfigFieldDef {
    ProgramConfigFieldDef {
        key,
        label,
        help_text,
        kind: TrainingProgramFieldKind::Int32,
        binding: TrainingProgramFieldBinding::DaysPerWeek,
        required: true,
        default_value: ProgramFieldDefault::Int(default_days),
        exercise_id: 0,
        int_choices: choices,
    }
}

pub fn cfg_field_exercise_weight(
    key: &'static str,
    label: &'static str,
    help_text: &'static str,
    exercise_id: i32,
    default_weight: f32,
) -> ProgramConfigFieldDef {
    ProgramConfigFieldDef {
        key,
        label,
        help_text,
        kind: TrainingProgramFieldKind::Float,
        binding: TrainingProgramFieldBinding::OneRepMax,
        required: false,
        default_value: ProgramFieldDefault::Float(default_weight),
        exercise_id,
        int_choices: vec![],
    }
}

// ─── Trait ───────────────────────────────────────────────────────────────────

pub trait WorkoutRegime: Send + Sync {
    fn display_name(&self) -> &'static str;
    fn default_days_per_week(&self) -> i32;
    fn catalog_meta(&self) -> ProgramCatalogMeta;

    /// Compute next weight/sets/reps for a single exercise from its history.
    /// `now_ts` is the unix timestamp to use as "current time" for deload/break detection.
    fn calculate_exercise_progression(
        &self,
        exercise: Exercise,
        config: &ExerciseConfig,
        history: &[SessionHistory], // newest-first
        max_weight: f32,
        workout_config: &UserWorkoutConfig,
        now_ts: i64,
    ) -> ExerciseProposal;

    /// Build the full list of proposed groups for the home screen.
    fn build_proposed_groups(
        &self,
        statuses: &[ExerciseStatus],
        workout_config: &UserWorkoutConfig,
    ) -> Vec<ProposedExerciseGroup>;

    /// Compute updated regime_state_json from latest history.
    /// Called every time GetProposedWorkoutSchedule runs so state stays fresh.
    fn compute_updated_state(
        &self,
        workout_config: &UserWorkoutConfig,
        history: &HashMap<i32, Vec<SessionHistory>>,
    ) -> String;

    /// Recovery window in seconds between sessions.
    fn recovery_seconds(&self, workout_config: &UserWorkoutConfig) -> i64;

    /// Build the RegimeContext (session description, coaching notes, etc.)
    fn build_regime_context(
        &self,
        workout_config: &UserWorkoutConfig,
        statuses: &[ExerciseStatus],
    ) -> RegimeContext;

    /// Short name for the suggested workout, e.g. "5/3/1 — Cycle 2, Week 3 Peak".
    /// Default returns the regime display name.
    fn suggested_workout_name(&self, _workout_config: &UserWorkoutConfig) -> String {
        self.display_name().to_string()
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
            config_fields: meta
                .config_fields
                .into_iter()
                .map(|f| {
                    let mut field = TrainingProgramConfigField {
                        key: f.key.to_string(),
                        label: f.label.to_string(),
                        help_text: f.help_text.to_string(),
                        kind: f.kind as i32,
                        binding: f.binding as i32,
                        required: f.required,
                        default_int32: 0,
                        default_float: 0.0,
                        default_bool: false,
                        exercise_id: f.exercise_id,
                        int_choices: f
                            .int_choices
                            .into_iter()
                            .map(|(value, label)| TrainingProgramIntChoice {
                                value,
                                label: label.to_string(),
                            })
                            .collect(),
                    };
                    match f.default_value {
                        ProgramFieldDefault::Int(v) => field.default_int32 = v,
                        ProgramFieldDefault::Float(v) => field.default_float = v,
                        ProgramFieldDefault::Bool(v) => field.default_bool = v,
                    }
                    field
                })
                .collect(),
            sort_order: meta.sort_order,
        }
    }
}

// ─── Factory ─────────────────────────────────────────────────────────────────

pub fn get_regime(regime_type: RegimeType) -> Box<dyn WorkoutRegime> {
    match regime_type {
        RegimeType::Gzclp => Box::new(GzclpRegime),
        RegimeType::Wendler5314day => Box::new(Wendler5314DayRegime),
        RegimeType::Wendler5313day => Box::new(Wendler5313DayRegime),
        // Default / Linear5x5
        _ => Box::new(Linear5x5Regime),
    }
}

pub fn catalog_regime_types() -> Vec<RegimeType> {
    vec![
        RegimeType::Linear5x5,
        RegimeType::Gzclp,
        RegimeType::Wendler5314day,
        RegimeType::Wendler5313day,
    ]
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

/// Build a basic ExerciseTypeConfig from a proposal + static config.
pub fn make_exercise_type_config(
    exercise: Exercise,
    proposal: &ExerciseProposal,
    include_warmup: bool,
) -> ExerciseTypeConfig {
    make_exercise_type_config_amrap(exercise, proposal, include_warmup, false)
}

/// Like make_exercise_type_config but with explicit AMRAP control.
pub fn make_exercise_type_config_amrap(
    exercise: Exercise,
    proposal: &ExerciseProposal,
    include_warmup: bool,
    last_set_amrap: bool,
) -> ExerciseTypeConfig {
    ExerciseTypeConfig {
        exercise: exercise as i32,
        start_weight: proposal.weight,
        end_weight: proposal.weight,
        reps: proposal.reps,
        include_warmup,
        rest_config: None,
        last_set_amrap,
        working_sets: vec![],
    }
}

/// Build a regime-appropriate RestConfig (0 = use system default for warmup fields).
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
    proposal: &ExerciseProposal,
    tags: Vec<String>,
    explanation: String,
    rest_config: Option<RestConfig>,
) -> ProposedExerciseGroup {
    build_single_group_amrap(exercise, proposal, tags, explanation, rest_config, false)
}

/// Like build_single_group but with explicit AMRAP control on the last working set.
pub fn build_single_group_amrap(
    exercise: Exercise,
    proposal: &ExerciseProposal,
    tags: Vec<String>,
    explanation: String,
    rest_config: Option<RestConfig>,
    last_set_amrap: bool,
) -> ProposedExerciseGroup {
    let mut cfg = make_exercise_type_config_amrap(exercise, proposal, true, last_set_amrap);
    let count = proposal.sets.max(1);
    cfg.working_sets = (0..count)
        .map(|idx| {
            let is_last = idx == count - 1;
            let is_amrap = last_set_amrap && is_last;
            WorkingSetSpec {
                target_weight: proposal.weight,
                target_reps: proposal.reps,
                is_amrap,
                instruction: if is_amrap {
                    "AMRAP — push for max reps".to_string()
                } else {
                    String::new()
                },
            }
        })
        .collect();
    ProposedExerciseGroup {
        name: exercise_display_name(exercise),
        sets: proposal.sets,
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
) -> SessionReadiness {
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
    SessionReadiness {
        next_session_at,
        last_session_at,
        readiness_label: label,
        readiness_detail: detail,
        is_ready: last_session_at == 0 || is_ready,
        is_overdue,
    }
}
