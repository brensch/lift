use schlift::workout::v1::{Exercise, RegimeContext, TrainingProgramStateSchema};

use crate::program_state::{
    build_schema, get_f32_or, get_int_or, get_str_or, schema_enum, schema_float, schema_int,
    set_f32, set_int, set_str, with_onboarding, FloatFieldBounds, ProposeResult, StatePayload,
};
use crate::schplanner::{SchplannerInsights, SchplannerSlotOutcome, SchplannerWorkoutRecord};
use crate::weight_units::{min_weight_lb, round_to_unit_increment, weight_unit_from_state};
use std::collections::HashMap;

use super::{
    build_single_group_amrap, build_training_status, exercise_display_name, exercise_short_label,
    format_weight_compact, recent_performance_notes, rest_cfg, simulate_target_slot_sets,
    ProgramAtAGlanceMeta, ProgramCatalogMeta, SingleGroupOptions, WorkoutRegime,
};
use std::collections::HashSet;

const UPPER_INCREMENT: f32 = 5.0;
const LOWER_INCREMENT: f32 = 5.0;
const DEADLIFT_INCREMENT: f32 = 10.0;
const STANDARD_WEIGHT_BOUNDS: FloatFieldBounds = FloatFieldBounds {
    min: 45.0,
    max: 1000.0,
    step: 5.0,
};
const DEADLIFT_WEIGHT_BOUNDS: FloatFieldBounds = FloatFieldBounds {
    min: 45.0,
    max: 1000.0,
    step: 5.0,
};

pub struct Linear5x5Regime;

// ─── State key constants ──────────────────────────────────────────────────────

const KEY_VARIANT: &str = "next_workout_variant";
const KEY_SQ_W: &str = "squat_weight";
const KEY_BP_W: &str = "bench_press_weight";
const KEY_ROW_W: &str = "barbell_row_weight";
const KEY_OHP_W: &str = "overhead_press_weight";
const KEY_DL_W: &str = "deadlift_weight";
const KEY_SQ_S: &str = "squat_stall_count";
const KEY_BP_S: &str = "bench_press_stall_count";
const KEY_ROW_S: &str = "barbell_row_stall_count";
const KEY_OHP_S: &str = "overhead_press_stall_count";
const KEY_DL_S: &str = "deadlift_stall_count";

fn weight_key(ex: Exercise) -> &'static str {
    match ex {
        Exercise::Squat => KEY_SQ_W,
        Exercise::BenchPress => KEY_BP_W,
        Exercise::BarbellRow => KEY_ROW_W,
        Exercise::OverheadPress => KEY_OHP_W,
        Exercise::Deadlift => KEY_DL_W,
        _ => KEY_SQ_W,
    }
}

fn stall_key(ex: Exercise) -> &'static str {
    match ex {
        Exercise::Squat => KEY_SQ_S,
        Exercise::BenchPress => KEY_BP_S,
        Exercise::BarbellRow => KEY_ROW_S,
        Exercise::OverheadPress => KEY_OHP_S,
        Exercise::Deadlift => KEY_DL_S,
        _ => KEY_SQ_S,
    }
}

fn default_weight(ex: Exercise) -> f32 {
    match ex {
        Exercise::Squat => 135.0,
        Exercise::BenchPress => 95.0,
        Exercise::BarbellRow => 95.0,
        Exercise::OverheadPress => 65.0,
        Exercise::Deadlift => 185.0,
        _ => 45.0,
    }
}

fn progression_increments(ex: Exercise) -> (f32, f32) {
    match ex {
        Exercise::Deadlift => (DEADLIFT_INCREMENT, 5.0),
        Exercise::Squat => (LOWER_INCREMENT, 2.5),
        _ => (UPPER_INCREMENT, 2.5),
    }
}

fn rounding_steps(_ex: Exercise) -> (f32, f32) {
    (5.0, 2.5)
}

const WORKOUT_A: &[Exercise] = &[Exercise::Squat, Exercise::BenchPress, Exercise::BarbellRow];
const WORKOUT_B: &[Exercise] = &[Exercise::Squat, Exercise::OverheadPress, Exercise::Deadlift];

fn workout_variant_exercises(variant: &str) -> &'static [Exercise] {
    if variant.eq_ignore_ascii_case("B") {
        WORKOUT_B
    } else {
        WORKOUT_A
    }
}

fn linear_group_explanation(
    exercise: Exercise,
    workout_label: &str,
    planned_weight: f32,
    state: &StatePayload,
    insights: &SchplannerInsights,
) -> String {
    let label = exercise_display_name(exercise);
    let planned = format_weight_compact(planned_weight, weight_unit_from_state(state));
    let Some(insight) = insights.for_exercise(exercise) else {
        return format!("Workout {} includes {}. Planned working weight is {}.", workout_label, label, planned);
    };

    let last_weight = format_weight_compact(insight.last_weight, weight_unit_from_state(state));
    if insight.last_hit_target && planned_weight > insight.last_weight + 0.1 {
        format!(
            "Workout {} includes {}. Planned working weight is {}, up from {} after you hit all prescribed reps last time.",
            workout_label, label, planned, last_weight
        )
    } else if !insight.last_hit_target && (planned_weight - insight.last_weight).abs() <= 0.1 {
        format!(
            "Workout {} includes {}. Planned working weight stays at {} because last time you got {} of {} reps on the final working set.",
            workout_label, label, planned, insight.last_actual_reps, insight.last_target_reps
        )
    } else {
        format!(
            "Workout {} includes {}. Planned working weight is {}.",
            workout_label, label, planned
        )
    }
}

impl WorkoutRegime for Linear5x5Regime {
    fn display_name(&self) -> &'static str {
        "Stronglifts 5x5"
    }

    fn catalog_meta(&self) -> ProgramCatalogMeta {
        ProgramCatalogMeta {
            headline: "Best for beginners",
            summary: "Simple session-to-session linear progression on the main barbell lifts.",
            description: "Alternate Workout A and B, add weight after successful sessions, and deload when you stall repeatedly.",
            how_it_works: "Workout A: Squat, Bench, Row.\nWorkout B: Squat, OHP, Deadlift.\n\nComplete the prescribed sets and the next session increases weight. Repeated misses at the same weight trigger a deload.",
            at_a_glance: ProgramAtAGlanceMeta {
                days_per_week: "3",
                best_for: "Beginners",
                average_session_time: "45-60 min",
                progression_style: "Linear progression",
            },
            details: vec![
                "Weights increase after successful sessions.",
                "A/B alternation is tracked automatically.",
                "Deloads happen after repeated failures.",
            ],
            learn_more_links: vec![
                (
                    "StrongLifts 5x5 overview",
                    "https://stronglifts.com/stronglifts-5x5/workout-program/",
                ),
                (
                    "Starting Strength novice program",
                    "https://startingstrength.com/get-started/programs",
                ),
            ],
            sort_order: 10,
        }
    }

    fn state_schema(&self) -> TrainingProgramStateSchema {
        build_schema(vec![
            schema_enum(
                KEY_VARIANT,
                "Next Workout",
                "Which workout to do next.",
                "Session",
                1,
                vec![
                    ("A", "Workout A (Squat / Bench / Row)"),
                    ("B", "Workout B (Squat / OHP / Deadlift)"),
                ],
            ),
            // Weights — shown during onboarding
            with_onboarding(schema_float(
                KEY_SQ_W,
                "Squat",
                "Starting working weight (lbs).",
                "Weights",
                10,
                STANDARD_WEIGHT_BOUNDS,
            )),
            with_onboarding(schema_float(
                KEY_BP_W,
                "Bench Press",
                "Starting working weight (lbs).",
                "Weights",
                11,
                STANDARD_WEIGHT_BOUNDS,
            )),
            with_onboarding(schema_float(
                KEY_ROW_W,
                "Barbell Row",
                "Starting working weight (lbs).",
                "Weights",
                12,
                STANDARD_WEIGHT_BOUNDS,
            )),
            with_onboarding(schema_float(
                KEY_OHP_W,
                "Overhead Press",
                "Starting working weight (lbs).",
                "Weights",
                13,
                STANDARD_WEIGHT_BOUNDS,
            )),
            with_onboarding(schema_float(
                KEY_DL_W,
                "Deadlift",
                "Starting working weight (lbs).",
                "Weights",
                14,
                DEADLIFT_WEIGHT_BOUNDS,
            )),
            // Stall counters — internal state, not shown during onboarding
            schema_int(
                KEY_SQ_S,
                "Squat Stall Count",
                "Consecutive failures at current weight. Resets to 0 after 3 (deload).",
                "Stall Counters",
                20,
                0,
                10,
            ),
            schema_int(
                KEY_BP_S,
                "Bench Stall Count",
                "Consecutive failures at current weight.",
                "Stall Counters",
                21,
                0,
                10,
            ),
            schema_int(
                KEY_ROW_S,
                "Row Stall Count",
                "Consecutive failures at current weight.",
                "Stall Counters",
                22,
                0,
                10,
            ),
            schema_int(
                KEY_OHP_S,
                "OHP Stall Count",
                "Consecutive failures at current weight.",
                "Stall Counters",
                23,
                0,
                10,
            ),
            schema_int(
                KEY_DL_S,
                "Deadlift Stall Count",
                "Consecutive failures at current weight.",
                "Stall Counters",
                24,
                0,
                10,
            ),
        ])
    }

    fn default_state(&self) -> StatePayload {
        let mut s = StatePayload::new();
        set_str(&mut s, KEY_VARIANT, "A");
        for ex in &[
            Exercise::Squat,
            Exercise::BenchPress,
            Exercise::BarbellRow,
            Exercise::OverheadPress,
            Exercise::Deadlift,
        ] {
            set_f32(&mut s, weight_key(*ex), default_weight(*ex));
            set_int(&mut s, stall_key(*ex), 0);
        }
        s
    }

    fn validate_state(&self, state: &StatePayload) -> Vec<String> {
        let mut warnings = Vec::new();
        let variant = get_str_or(state, KEY_VARIANT, "A");
        if variant != "A" && variant != "B" {
            warnings.push(format!(
                "next_workout_variant '{}' is not A or B — will default to A",
                variant
            ));
        }
        for ex in &[
            Exercise::Squat,
            Exercise::BenchPress,
            Exercise::BarbellRow,
            Exercise::OverheadPress,
            Exercise::Deadlift,
        ] {
            let w = get_f32_or(state, weight_key(*ex), 0.0);
            if w <= 0.0 {
                warnings.push(format!("{} weight must be > 0", exercise_display_name(*ex)));
            }
            let stall = get_int_or(state, stall_key(*ex), 0);
            if stall < 0 {
                warnings.push(format!(
                    "{} stall_count cannot be negative",
                    exercise_display_name(*ex)
                ));
            }
        }
        warnings
    }

    fn propose_from_state(
        &self,
        state: &StatePayload,
        _last_session_at: i64,
        _now_ts: i64,
        insights: &SchplannerInsights,
    ) -> ProposeResult {
        let variant = get_str_or(state, KEY_VARIANT, "A");
        let exercises = if variant.eq_ignore_ascii_case("B") {
            WORKOUT_B
        } else {
            WORKOUT_A
        };
        let next_variant_label = if variant.eq_ignore_ascii_case("B") {
            "B"
        } else {
            "A"
        };
        let other_variant = if next_variant_label == "A" { "B" } else { "A" };

        let mut proposed_groups = Vec::new();

        for &ex in exercises {
            let w = get_f32_or(state, weight_key(ex), default_weight(ex));
            let is_deadlift = ex == Exercise::Deadlift;
            let sets = if is_deadlift { 1 } else { 5 };
            let reps = 5;
            proposed_groups.push(build_single_group_amrap(
                ex,
                w,
                sets,
                reps,
                SingleGroupOptions {
                    tags: vec!["recommended".to_string(), "compound".to_string()],
                    explanation: linear_group_explanation(
                        ex,
                        next_variant_label,
                        w,
                        state,
                        insights,
                    ),
                    rest_config: rest_cfg(180, 300),
                    include_warmup: true,
                    last_set_amrap: false,
                },
            ));
        }

        // Show other day's compounds as optional
        let optional = if next_variant_label == "A" {
            WORKOUT_B
        } else {
            WORKOUT_A
        };
        for &ex in optional.iter().filter(|&&e| e != Exercise::Squat) {
            let w = get_f32_or(state, weight_key(ex), default_weight(ex));
            let sets = if ex == Exercise::Deadlift { 1 } else { 5 };
            proposed_groups.push(build_single_group_amrap(
                ex,
                w,
                sets,
                5,
                SingleGroupOptions {
                    tags: vec!["compound".to_string()],
                    explanation: format!(
                        "{} is part of Workout {}. Add it only if you want extra work beyond today's Workout {} prescription.",
                        exercise_display_name(ex),
                        other_variant,
                        next_variant_label
                    ),
                    rest_config: rest_cfg(180, 300),
                    include_warmup: true,
                    last_set_amrap: false,
                },
            ));
        }

        let mut coaching_notes = recent_performance_notes(insights, exercises, 3);
        if coaching_notes.len() < 3 {
            coaching_notes.push("Focus on form before chasing weight.".to_string());
        }
        if coaching_notes.len() < 3 {
            coaching_notes.push(
                "If a set feels like a 9/10 effort, consider deloading proactively.".to_string(),
            );
        }

        let regime_context = RegimeContext {
            regime_display_name: "Stronglifts 5x5".to_string(),
            session_description: {
                let lifts = workout_variant_exercises(next_variant_label)
                    .iter()
                    .map(|&ex| exercise_short_label(ex))
                    .collect::<Vec<_>>()
                    .join("/");
                let stall_notes = workout_variant_exercises(next_variant_label)
                    .iter()
                    .filter_map(|&ex| {
                        let stalls = get_int_or(state, stall_key(ex), 0);
                        if stalls > 0 {
                            Some(format!(
                                "stalled {}",
                                exercise_short_label(ex).to_ascii_lowercase()
                            ))
                        } else {
                            None
                        }
                    })
                    .collect::<Vec<_>>();
                if stall_notes.is_empty() {
                    format!("Workout {} • {}", next_variant_label, lifts)
                } else {
                    format!(
                        "Workout {} • {} • {}",
                        next_variant_label,
                        lifts,
                        stall_notes.join(" • ")
                    )
                }
            },
            next_session_preview: format!(
                "Next: Workout {}. Alternate A/B each session; add weight after successful lifts.",
                other_variant
            ),
            coaching_notes,
        };

        ProposeResult {
            proposed_groups,
            regime_context,
            suggested_workout_name: format!("5×5 Workout {}", next_variant_label),
        }
    }

    fn apply_temporal_adjustments_for_proposal(
        &self,
        state: &StatePayload,
        last_session_at: i64,
        now_ts: i64,
    ) -> StatePayload {
        if last_session_at == 0 {
            return state.clone();
        }
        let days_since = (now_ts - last_session_at) / (24 * 3600);
        if days_since < 14 {
            return state.clone();
        }
        let pct = if days_since >= 30 { 0.8 } else { 0.9 };
        let unit = weight_unit_from_state(state);
        let mut adjusted = state.clone();
        for ex in [
            Exercise::Squat,
            Exercise::BenchPress,
            Exercise::BarbellRow,
            Exercise::OverheadPress,
            Exercise::Deadlift,
        ] {
            let current = get_f32_or(state, weight_key(ex), default_weight(ex));
            let (lb_round, kg_round) = rounding_steps(ex);
            let deloaded = round_to_unit_increment(current * pct, unit, lb_round, kg_round)
                .max(min_weight_lb(unit, 45.0, 20.0));
            set_f32(&mut adjusted, weight_key(ex), deloaded);
        }
        adjusted
    }

    fn derive_training_status(
        &self,
        state: &StatePayload,
        history: &[SchplannerWorkoutRecord],
        last_session_at: i64,
        now_ts: i64,
    ) -> schlift::workout::v1::TrainingStatus {
        let next_session_at = if last_session_at == 0 {
            now_ts
        } else {
            last_session_at + 24 * 3600
        };
        let next_workout_slots = self.propose_from_state(
            state,
            last_session_at,
            now_ts,
            &SchplannerInsights::default(),
        );
        let next_workout_slots =
            crate::schplanner::summarize_proposed_slot_targets(&next_workout_slots.proposed_groups)
                .into_keys()
                .collect::<HashSet<_>>();
        let target_slot_sets = simulate_target_slot_sets(self, state, last_session_at, now_ts, 3);
        build_training_status(
            history,
            now_ts,
            last_session_at,
            next_session_at,
            3,
            &next_workout_slots,
            target_slot_sets,
        )
    }

    fn transition_state_on_workout_completed(
        &self,
        state: &mut StatePayload,
        _workout: &SchplannerWorkoutRecord,
        slot_outcomes: &HashMap<String, SchplannerSlotOutcome>,
    ) {
        let unit = weight_unit_from_state(state);
        for exercise in [
            Exercise::Squat,
            Exercise::BenchPress,
            Exercise::BarbellRow,
            Exercise::OverheadPress,
            Exercise::Deadlift,
        ] {
            let slot_key = super::progression_slot_key(exercise);
            let Some(outcome) = slot_outcomes.get(&slot_key) else {
                continue;
            };
            if !outcome.workout_ended {
                continue;
            }
            let current_weight = get_f32_or(state, weight_key(exercise), default_weight(exercise));
            let attempted_weight = outcome
                .last_completed_actual_weight
                .unwrap_or(current_weight);
            let (lb_step, _kg_step) = progression_increments(exercise);
            let (lb_round, kg_round) = rounding_steps(exercise);
            if outcome.all_sets_hit_target() {
                let base_weight = outcome
                    .last_successful_actual_weight
                    .unwrap_or(attempted_weight);
                let next_weight =
                    round_to_unit_increment(base_weight + lb_step, unit, lb_round, kg_round);
                set_f32(state, weight_key(exercise), next_weight);
                set_int(state, stall_key(exercise), 0);
            } else {
                let next_stall = get_int_or(state, stall_key(exercise), 0) + 1;
                if next_stall >= 3 {
                    let deloaded =
                        round_to_unit_increment(attempted_weight * 0.9, unit, lb_round, kg_round)
                            .max(min_weight_lb(unit, 45.0, 20.0));
                    set_f32(state, weight_key(exercise), deloaded);
                    set_int(state, stall_key(exercise), 0);
                } else {
                    set_int(state, stall_key(exercise), next_stall);
                }
            }
        }
        let next = if get_str_or(state, KEY_VARIANT, "A").eq_ignore_ascii_case("B") {
            "A"
        } else {
            "B"
        };
        set_str(state, KEY_VARIANT, next);
    }
}
