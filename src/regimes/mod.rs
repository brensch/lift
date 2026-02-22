pub mod gzclp;
pub mod linear_5x5;
pub mod wendler_531;

use std::collections::HashMap;

use lift::workout::v1::{
    Exercise, ExerciseStatus, ExerciseTypeConfig, MuscleGroup, ProposedExerciseGroup,
    RegimeContext, RegimeType, SessionReadiness, UserWorkoutConfig,
};

pub use gzclp::GzclpRegime;
pub use linear_5x5::Linear5x5Regime;
pub use wendler_531::Wendler531Regime;

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
        Exercise::OverheadPress => "Overhead Press".to_string(),
        Exercise::BarbellRow => "Barbell Row".to_string(),
        Exercise::HipThrust => "Hip Thrust".to_string(),
        Exercise::BulgarianSplitSquat => "Bulgarian Split Squat".to_string(),
        Exercise::RomanianDeadlift => "Romanian Deadlift".to_string(),
        Exercise::GluteBridge => "Glute Bridge".to_string(),
        Exercise::Lunge => "Lunge".to_string(),
        Exercise::LegCurl => "Leg Curl".to_string(),
        _ => "Unknown".to_string(),
    }
}

// ─── Proposal output from a regime ───────────────────────────────────────────

pub struct ExerciseProposal {
    pub weight: f32,
    pub sets: i32,
    pub reps: i32,
    pub explanation: String,
}

// ─── Trait ───────────────────────────────────────────────────────────────────

pub trait WorkoutRegime: Send + Sync {
    fn display_name(&self) -> &'static str;
    fn default_days_per_week(&self) -> i32;

    /// Compute next weight/sets/reps for a single exercise from its history.
    fn calculate_exercise_progression(
        &self,
        exercise: Exercise,
        config: &ExerciseConfig,
        history: &[(f32, bool, i64)], // (weight, success, timestamp) newest-first
        max_weight: f32,
        workout_config: &UserWorkoutConfig,
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
        history: &HashMap<i32, Vec<(f32, bool, i64)>>,
    ) -> String;

    /// Recovery window in seconds between sessions.
    fn recovery_seconds(&self, workout_config: &UserWorkoutConfig) -> i64;

    /// Build the RegimeContext (session description, coaching notes, etc.)
    fn build_regime_context(
        &self,
        workout_config: &UserWorkoutConfig,
        statuses: &[ExerciseStatus],
    ) -> RegimeContext;
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

// ─── Shared helpers ───────────────────────────────────────────────────────────

/// Build a basic ExerciseTypeConfig from a proposal + static config.
pub fn make_exercise_type_config(
    exercise: Exercise,
    proposal: &ExerciseProposal,
    include_warmup: bool,
) -> ExerciseTypeConfig {
    ExerciseTypeConfig {
        exercise: exercise as i32,
        start_weight: proposal.weight,
        end_weight: proposal.weight,
        reps: proposal.reps,
        include_warmup,
        rest_config: None,
    }
}

/// Build a single-exercise ProposedExerciseGroup.
pub fn build_single_group(
    exercise: Exercise,
    proposal: &ExerciseProposal,
    tags: Vec<String>,
    explanation: String,
) -> ProposedExerciseGroup {
    ProposedExerciseGroup {
        name: exercise_display_name(exercise),
        sets: proposal.sets,
        interleave_warmups: false,
        exercise_configs: vec![make_exercise_type_config(exercise, proposal, true)],
        rest_config: None,
        tags,
        explanation,
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
) -> SessionReadiness {
    use chrono::Utc;
    let now = Utc::now().timestamp();
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
