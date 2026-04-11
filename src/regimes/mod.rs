pub mod gzclp;
pub mod linear_5x5;
pub mod wendler_531;

use schlift::workout::v1::{
    Exercise, ProgressionHint, ProgressionRule, ProposedExerciseGroup, RegimeType, RestConfig,
    TrainingProgramAtAGlance, TrainingProgramDefinition, TrainingProgramLink, WorkingSetSpec,
};

pub use gzclp::GzclpRegime;
pub use linear_5x5::Linear5x5Regime;
pub use wendler_531::Wendler531Regime;

use crate::program_state::{PendingUpdateDef, ProposeResult, StatePayload};

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
    ) -> ProposeResult;

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
    pub explanation: String,
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
        explanation: options.explanation,
        prescribed_by_regime: false,
    }
}
