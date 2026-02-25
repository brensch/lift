use lift::workout::v1::{Exercise, RegimeContext, TrainingProgramStateSchema};

use crate::program_state::{
    build_schema, get_f32_or, get_int_or, get_str_or, schema_enum, schema_float, schema_int,
    set_f32, set_int, set_str, with_onboarding, FieldVal, PendingUpdateDef, PendingUpdateFieldDef,
    ProposeResult, StatePayload, WorkoutCompletionResult,
};

use super::{
    build_single_group_amrap, exercise_display_name, rest_cfg, ProgramAtAGlanceMeta,
    ProgramCatalogMeta, WorkoutRegime,
};
use lift::workout::v1::StateFieldKind;

const UPPER_INCREMENT: f32 = 5.0;
const LOWER_INCREMENT: f32 = 5.0;
const DEADLIFT_INCREMENT: f32 = 10.0;
const RECOVERY_HOURS: i64 = 48;

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

fn increment(ex: Exercise) -> f32 {
    match ex {
        Exercise::Deadlift => DEADLIFT_INCREMENT,
        Exercise::Squat => LOWER_INCREMENT,
        _ => UPPER_INCREMENT,
    }
}

const WORKOUT_A: &[Exercise] = &[Exercise::Squat, Exercise::BenchPress, Exercise::BarbellRow];
const WORKOUT_B: &[Exercise] = &[Exercise::Squat, Exercise::OverheadPress, Exercise::Deadlift];

impl WorkoutRegime for Linear5x5Regime {
    fn display_name(&self) -> &'static str {
        "Stronglifts 5x5"
    }

    fn default_days_per_week(&self) -> i32 {
        3
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
                45.0,
                1000.0,
                5.0,
            )),
            with_onboarding(schema_float(
                KEY_BP_W,
                "Bench Press",
                "Starting working weight (lbs).",
                "Weights",
                11,
                45.0,
                1000.0,
                5.0,
            )),
            with_onboarding(schema_float(
                KEY_ROW_W,
                "Barbell Row",
                "Starting working weight (lbs).",
                "Weights",
                12,
                45.0,
                1000.0,
                5.0,
            )),
            with_onboarding(schema_float(
                KEY_OHP_W,
                "Overhead Press",
                "Starting working weight (lbs).",
                "Weights",
                13,
                45.0,
                1000.0,
                5.0,
            )),
            with_onboarding(schema_float(
                KEY_DL_W,
                "Deadlift",
                "Starting working weight (lbs).",
                "Weights",
                14,
                45.0,
                1000.0,
                10.0,
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
                vec!["recommended".to_string(), "compound".to_string()],
                format!("5×5 Workout {} — {} lbs", next_variant_label, w),
                rest_cfg(180, 300),
                true,
                false,
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
                vec!["compound".to_string()],
                format!(
                    "{} — optional (from Workout {})",
                    exercise_display_name(ex),
                    other_variant
                ),
                rest_cfg(180, 300),
                true,
                false,
            ));
        }

        let regime_context = RegimeContext {
            regime_display_name: format!("Stronglifts 5x5 — Workout {}", next_variant_label),
            session_description: format!(
                "Workout {} — Linear progression (StrongLifts-style A/B split)",
                next_variant_label
            ),
            next_session_preview: format!(
                "Next: Workout {}. Alternate A/B each session; add weight after successful lifts.",
                other_variant
            ),
            coaching_notes: vec![
                "Focus on form before chasing weight.".to_string(),
                "If a set feels like a 9/10 effort, consider deloading proactively.".to_string(),
            ],
        };

        ProposeResult {
            proposed_groups,
            regime_context,
            suggested_workout_name: format!("5×5 Workout {}", next_variant_label),
        }
    }

    fn transition_state_on_workout_complete(
        &self,
        state: &StatePayload,
        result: &WorkoutCompletionResult,
        _ended_at: i64,
    ) -> StatePayload {
        let mut new_state = state.clone();

        // Determine which exercises were in this workout from set_results
        let mut exercise_results: std::collections::HashMap<i32, (bool, i32)> =
            std::collections::HashMap::new();
        // (all_sets_success, total_sets_count)
        for sr in &result.set_results {
            let entry = exercise_results
                .entry(sr.exercise as i32)
                .or_insert((true, 0));
            entry.0 = entry.0 && (sr.actual_reps >= sr.target_reps);
            entry.1 += 1;
        }

        let all_main_lifts = [
            Exercise::Squat,
            Exercise::BenchPress,
            Exercise::BarbellRow,
            Exercise::OverheadPress,
            Exercise::Deadlift,
        ];

        for ex in all_main_lifts {
            let Some((success, _)) = exercise_results.get(&(ex as i32)) else {
                continue;
            };
            let current_w = get_f32_or(state, weight_key(ex), default_weight(ex));
            let stall = get_int_or(state, stall_key(ex), 0);
            let inc = increment(ex);

            if *success {
                // Success: store next weight (current + increment), reset stall
                set_f32(&mut new_state, weight_key(ex), current_w + inc);
                set_int(&mut new_state, stall_key(ex), 0);
            } else {
                let new_stall = stall + 1;
                if new_stall >= 3 {
                    // Three failures: deload 10%, reset stall
                    let deloaded = ((current_w * 0.9) / 5.0).round() * 5.0;
                    let deloaded = deloaded.max(45.0);
                    set_f32(&mut new_state, weight_key(ex), deloaded);
                    set_int(&mut new_state, stall_key(ex), 0);
                } else {
                    // Hold weight, increment stall counter
                    set_f32(&mut new_state, weight_key(ex), current_w);
                    set_int(&mut new_state, stall_key(ex), new_stall);
                }
            }
        }

        // Flip A/B
        let current_variant = get_str_or(state, KEY_VARIANT, "A");
        let next_variant = if current_variant.eq_ignore_ascii_case("A") {
            "B"
        } else {
            "A"
        };
        set_str(&mut new_state, KEY_VARIANT, next_variant);

        new_state
    }

    fn pending_updates_for_state(
        &self,
        _state: &StatePayload,
        last_session_at: i64,
        now_ts: i64,
    ) -> Vec<PendingUpdateDef> {
        if last_session_at == 0 {
            return vec![];
        }
        let days_since = (now_ts - last_session_at) / (24 * 3600);
        if days_since < 14 {
            return vec![];
        }
        let recommended_pct = if days_since >= 30 { 80 } else { 90 };
        vec![PendingUpdateDef {
            update_id: "temporal_deload".to_string(),
            title: "Long break — deload recommended".to_string(),
            message: format!(
                "It's been {} days since your last session. A deload is recommended to reduce injury risk and ease back in.",
                days_since
            ),
            fields: vec![PendingUpdateFieldDef {
                key: "deload_percent".to_string(),
                label: "Deload %".to_string(),
                kind: StateFieldKind::Int,
                default_value: FieldVal::Int(recommended_pct),
                min_value: 50.0,
                max_value: 100.0,
                step: 5.0,
                enum_options: vec![],
            }],
        }]
    }

    fn apply_pending_update_to_state(
        &self,
        state: &StatePayload,
        update_id: &str,
        field_values: &StatePayload,
    ) -> Result<StatePayload, String> {
        match update_id {
            "temporal_deload" => {
                let pct = match field_values.get("deload_percent") {
                    Some(FieldVal::Int(p)) => *p as f32 / 100.0,
                    Some(FieldVal::Float(p)) => *p as f32 / 100.0,
                    _ => return Err("deload_percent field is required".to_string()),
                };
                if !(0.5..=1.0).contains(&pct) {
                    return Err("deload_percent must be between 50 and 100".to_string());
                }
                let mut new_state = state.clone();
                for ex in &[
                    Exercise::Squat,
                    Exercise::BenchPress,
                    Exercise::BarbellRow,
                    Exercise::OverheadPress,
                    Exercise::Deadlift,
                ] {
                    let current = get_f32_or(state, weight_key(*ex), default_weight(*ex));
                    let deloaded = ((current * pct) / 5.0).round() * 5.0;
                    set_f32(&mut new_state, weight_key(*ex), deloaded.max(45.0));
                    set_int(&mut new_state, stall_key(*ex), 0);
                }
                Ok(new_state)
            }
            _ => Err(format!("Unknown update_id: {}", update_id)),
        }
    }

    fn recovery_seconds_for_state(&self, _state: &StatePayload) -> i64 {
        RECOVERY_HOURS * 3600
    }
}
