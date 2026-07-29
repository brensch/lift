use schlift::workout::v1::{
    Exercise, ExerciseTypeConfig, ProgressionRule, ProposedExerciseGroup, RegimeContext,
    TrainingProgramStateSchema, WorkingSetSpec,
};

use super::{
    build_training_status, exercise_display_name, exercise_short_label, progression_hint_for_set,
    rest_cfg, simulate_target_slot_sets, ProgramAtAGlanceMeta, ProgramCatalogMeta, WorkoutRegime,
};
use crate::program_state::{
    build_schema, get_f32_or, get_int_or, get_str_or, schema_enum, schema_float, schema_int,
    set_f32, set_int, set_str, with_onboarding, FloatFieldBounds, ProposeResult, StatePayload,
};
use crate::schplanner::{SchplannerInsights, SchplannerSlotOutcome, SchplannerWorkoutRecord};
use crate::weight_units::{min_weight_lb, round_to_unit_increment, weight_unit_from_state};
use std::collections::HashSet;

pub struct Wendler531Regime;

// ─── State key constants ──────────────────────────────────────────────────────

const KEY_VARIANT: &str = "schedule_variant";
const KEY_CYCLE: &str = "cycle";
const KEY_WEEK: &str = "week";
const KEY_SESSION: &str = "session_in_week";
const KEY_SQ_TM: &str = "squat_tm";
const KEY_BP_TM: &str = "bench_press_tm";
const KEY_DL_TM: &str = "deadlift_tm";
const KEY_OHP_TM: &str = "overhead_press_tm";
const TRAINING_MAX_BOUNDS: FloatFieldBounds = FloatFieldBounds {
    min: 45.0,
    max: 1000.0,
    step: 5.0,
};

const WENDLER_LIFTS: &[Exercise] = &[
    Exercise::Squat,
    Exercise::BenchPress,
    Exercise::Deadlift,
    Exercise::OverheadPress,
];

fn tm_key(ex: Exercise) -> &'static str {
    match ex {
        Exercise::Squat => KEY_SQ_TM,
        Exercise::BenchPress => KEY_BP_TM,
        Exercise::Deadlift => KEY_DL_TM,
        Exercise::OverheadPress => KEY_OHP_TM,
        _ => KEY_SQ_TM,
    }
}

fn default_tm(ex: Exercise) -> f32 {
    match ex {
        Exercise::Squat => 200.0,
        Exercise::BenchPress => 165.0,
        Exercise::Deadlift => 275.0,
        Exercise::OverheadPress => 100.0,
        _ => 100.0,
    }
}

// ─── Week definitions ─────────────────────────────────────────────────────────

struct WeekDef {
    set_pcts: [f32; 3],
    set_reps: [i32; 3],
    top_set_amrap: bool,
    is_deload: bool,
    name: &'static str,
    preview: &'static str,
}

const WEEKS: [WeekDef; 4] = [
    WeekDef {
        set_pcts: [0.65, 0.75, 0.85],
        set_reps: [5, 5, 5],
        top_set_amrap: true,
        is_deload: false,
        name: "Week 1 — Volume (5/5/5+)",
        preview: "Next: Week 2 — Intensity (3/3/3+)",
    },
    WeekDef {
        set_pcts: [0.70, 0.80, 0.90],
        set_reps: [3, 3, 3],
        top_set_amrap: true,
        is_deload: false,
        name: "Week 2 — Intensity (3/3/3+)",
        preview: "Next: Week 3 — Peak (5/3/1+)",
    },
    WeekDef {
        set_pcts: [0.75, 0.85, 0.95],
        set_reps: [5, 3, 1],
        top_set_amrap: true,
        is_deload: false,
        name: "Week 3 — Peak (5/3/1+)",
        preview: "Next: Week 4 — Deload",
    },
    WeekDef {
        set_pcts: [0.40, 0.50, 0.60],
        set_reps: [5, 5, 5],
        top_set_amrap: false,
        is_deload: true,
        name: "Week 4 — Deload",
        preview: "Next: New cycle with higher Training Maxes",
    },
];

// ─── Session helpers ──────────────────────────────────────────────────────────

fn sessions_per_variant(variant: &str) -> i64 {
    if variant == "four_day" {
        4
    } else {
        3
    }
}

/// Returns the main lift(s) for the given session.
///
/// 4-day: one lift per session cycling [Squat, Bench, Deadlift, OHP].
/// 3-day: paired lifts per session, with pairing flipping each week so all
///        lifts get equal week/intensity exposure over successive weeks.
///        Even week_zero → sessions start with Squat+Bench;
///        odd week_zero  → sessions start with Deadlift+OHP.
fn lifts_for_session(variant: &str, cycle: i64, week: i64, session_in_week: i64) -> Vec<Exercise> {
    if variant == "four_day" {
        let idx = (session_in_week as usize) % 4;
        vec![WENDLER_LIFTS[idx]]
    } else {
        // week_zero is 0-based total week count (used to flip pairing each week)
        let week_zero = (cycle - 1) * 4 + (week - 1);
        let start_with_squat_bench = week_zero % 2 == 0;
        match (session_in_week % 3, start_with_squat_bench) {
            (0, true) | (2, false) => vec![Exercise::Squat, Exercise::BenchPress],
            (1, true) | (0, false) => vec![Exercise::Deadlift, Exercise::OverheadPress],
            _ => vec![Exercise::Squat, Exercise::BenchPress],
        }
    }
}

fn build_wendler_working_sets(
    exercise: Exercise,
    tm: f32,
    week_def: &WeekDef,
    state: &StatePayload,
) -> Vec<WorkingSetSpec> {
    let unit = weight_unit_from_state(state);
    week_def
        .set_pcts
        .iter()
        .zip(week_def.set_reps.iter())
        .enumerate()
        .map(|(idx, (&pct, &reps))| {
            let w = round_to_unit_increment(tm * pct, unit, 5.0, 2.5);
            let is_top = idx == 2;
            let is_amrap = week_def.top_set_amrap && is_top;
            WorkingSetSpec {
                target_weight: w,
                target_reps: reps,
                is_amrap,
                instruction: if is_amrap {
                    format!("{}+ — push for max reps (AMRAP)", reps)
                } else {
                    String::new()
                },
                progression_hint: Some(progression_hint_for_set(
                    exercise,
                    "MAIN",
                    if is_amrap {
                        ProgressionRule::TopSetAmrap
                    } else {
                        ProgressionRule::None
                    },
                    reps,
                    is_amrap,
                )),
            }
        })
        .collect()
}

fn recovery_seconds_for_week(week: i64) -> i64 {
    match week {
        4 => 24 * 3600,
        3 => 72 * 3600,
        _ => 48 * 3600,
    }
}

// ─── Regime impl ─────────────────────────────────────────────────────────────

impl WorkoutRegime for Wendler531Regime {
    fn display_name(&self) -> &'static str {
        "Wendler 5/3/1"
    }

    fn catalog_meta(&self) -> ProgramCatalogMeta {
        ProgramCatalogMeta {
            headline: "For intermediates and beyond",
            summary: "Percentage-based periodization with AMRAP top sets. 4-week waves cycling through volume, intensity, and peak weeks.",
            description: "Jim Wendler's 5/3/1 runs a 4-week cycle off a Training Max set to ~90% of your 1RM. Choose 4-day (one main lift per session) or 3-day (paired lifts per session).",
            how_it_works: "Work off a Training Max (TM ≈ 90% of 1RM).\nWeek 1: 65%/75%/85% × 5/5/5+ (last set AMRAP).\nWeek 2: 70%/80%/90% × 3/3/3+ (last set AMRAP).\nWeek 3: 75%/85%/95% × 5/3/1+ (last set AMRAP).\nWeek 4: 40%/50%/60% × 5/5/5 (deload, no AMRAP).\nAfter each 4-week cycle: lower-body TM +10 lbs, upper-body TM +5 lbs.",
            at_a_glance: ProgramAtAGlanceMeta {
                days_per_week: "3 or 4",
                best_for: "Intermediate+",
                average_session_time: "45-90 min",
                progression_style: "Percentage periodization",
            },
            details: vec![
                "Choose 4-day (one lift/session) or 3-day (paired lifts) via schedule variant.",
                "Training Maxes increase automatically after each 4-week cycle.",
                "Top set is AMRAP in weeks 1-3 to track real progress.",
            ],
            learn_more_links: vec![
                ("The Fitness Wiki: 5/3/1 Primer", "https://thefitness.wiki/5-3-1-primer/"),
                (
                    "Jim Wendler beginner article",
                    "https://www.jimwendler.com/blogs/jimwendler-com/101065094-5-3-1-for-a-beginner",
                ),
            ],
            sort_order: 30,
        }
    }

    fn state_schema(&self) -> TrainingProgramStateSchema {
        build_schema(vec![
            with_onboarding(schema_enum(
                KEY_VARIANT,
                "Schedule Variant",
                "Number of training days per week.",
                "Schedule",
                1,
                vec![
                    ("four_day", "4-Day — one main lift per session"),
                    ("three_day", "3-Day — paired lifts per session"),
                ],
            )),
            // Progress — internal state, not shown during onboarding
            schema_int(
                KEY_CYCLE,
                "Cycle",
                "Current training cycle number (starts at 1).",
                "Progress",
                10,
                1,
                100,
            ),
            schema_int(
                KEY_WEEK,
                "Week",
                "Current week within cycle (1=Volume, 2=Intensity, 3=Peak, 4=Deload).",
                "Progress",
                11,
                1,
                4,
            ),
            schema_int(
                KEY_SESSION,
                "Session in Week",
                "0-based training day index within the current week.",
                "Progress",
                12,
                0,
                3,
            ),
            // Training maxes — shown during onboarding
            with_onboarding(schema_float(
                KEY_SQ_TM,
                "Squat TM",
                "Training Max (lbs). Set to ~90% of your estimated 1RM.",
                "Training Maxes",
                20,
                TRAINING_MAX_BOUNDS,
            )),
            with_onboarding(schema_float(
                KEY_BP_TM,
                "Bench Press TM",
                "Training Max (lbs). Set to ~90% of your estimated 1RM.",
                "Training Maxes",
                21,
                TRAINING_MAX_BOUNDS,
            )),
            with_onboarding(schema_float(
                KEY_DL_TM,
                "Deadlift TM",
                "Training Max (lbs). Set to ~90% of your estimated 1RM.",
                "Training Maxes",
                22,
                TRAINING_MAX_BOUNDS,
            )),
            with_onboarding(schema_float(
                KEY_OHP_TM,
                "Overhead Press TM",
                "Training Max (lbs). Set to ~90% of your estimated 1RM.",
                "Training Maxes",
                23,
                TRAINING_MAX_BOUNDS,
            )),
        ])
    }

    fn default_state(&self) -> StatePayload {
        let mut s = StatePayload::new();
        set_str(&mut s, KEY_VARIANT, "four_day");
        set_int(&mut s, KEY_CYCLE, 1);
        set_int(&mut s, KEY_WEEK, 1);
        set_int(&mut s, KEY_SESSION, 0);
        for &ex in WENDLER_LIFTS {
            set_f32(&mut s, tm_key(ex), default_tm(ex));
        }
        s
    }

    fn validate_state(&self, state: &StatePayload) -> Vec<String> {
        let mut warnings = Vec::new();
        let variant = get_str_or(state, KEY_VARIANT, "four_day");
        if variant != "three_day" && variant != "four_day" {
            warnings.push(format!(
                "schedule_variant '{}' must be 'three_day' or 'four_day'",
                variant
            ));
        }
        let week = get_int_or(state, KEY_WEEK, 1);
        if !(1..=4).contains(&week) {
            warnings.push(format!("week {} is out of range (must be 1-4)", week));
        }
        let cycle = get_int_or(state, KEY_CYCLE, 1);
        if cycle < 1 {
            warnings.push("cycle must be >= 1".to_string());
        }
        let sessions = sessions_per_variant(variant);
        let session_in_week = get_int_or(state, KEY_SESSION, 0);
        if session_in_week < 0 || session_in_week >= sessions {
            warnings.push(format!(
                "session_in_week {} is out of range (0-{}) for {} variant",
                session_in_week,
                sessions - 1,
                variant
            ));
        }
        for &ex in WENDLER_LIFTS {
            let tm = get_f32_or(state, tm_key(ex), 0.0);
            if tm <= 0.0 {
                warnings.push(format!(
                    "{} training max must be > 0",
                    exercise_display_name(ex)
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
        _insights: &SchplannerInsights,
    ) -> ProposeResult {
        let variant = get_str_or(state, KEY_VARIANT, "four_day");
        let cycle = get_int_or(state, KEY_CYCLE, 1).max(1);
        let week = get_int_or(state, KEY_WEEK, 1).clamp(1, 4);
        let session_in_week = get_int_or(state, KEY_SESSION, 0).max(0);

        let week_def = &WEEKS[(week - 1) as usize];
        let lifts = lifts_for_session(variant, cycle, week, session_in_week);
        let weight_unit = weight_unit_from_state(state);

        let mut proposed_groups = Vec::new();

        for &ex in &lifts {
            let tm = get_f32_or(state, tm_key(ex), default_tm(ex));
            let working_sets = build_wendler_working_sets(ex, tm, week_def, state);

            let start_w = working_sets
                .first()
                .map(|s| s.target_weight)
                .unwrap_or(round_to_unit_increment(tm * 0.65, weight_unit, 5.0, 2.5));
            let end_w = working_sets
                .last()
                .map(|s| s.target_weight)
                .unwrap_or(round_to_unit_increment(tm * 0.85, weight_unit, 5.0, 2.5));
            let first_reps = working_sets.first().map(|s| s.target_reps).unwrap_or(5);

            let group_rest = if week_def.is_deload {
                rest_cfg(90, 90)
            } else {
                rest_cfg(180, 300)
            };

            let config = ExerciseTypeConfig {
                exercise: ex as i32,
                start_weight: start_w,
                end_weight: end_w,
                reps: first_reps,
                include_warmup: true,
                rest_config: None,
                last_set_amrap: week_def.top_set_amrap,
                working_sets,
            };
            proposed_groups.push(ProposedExerciseGroup {
                name: exercise_display_name(ex),
                sets: 3,
                interleave_warmups: false,
                exercise_configs: vec![config],
                rest_config: group_rest,
                tags: vec!["recommended".to_string(), "compound".to_string()],
                prescribed_by_regime: false,
                estimated_duration_seconds: 0,
            });
        }

        let lifts_display: Vec<String> = lifts.iter().map(|&e| exercise_display_name(e)).collect();

        let regime_context = RegimeContext {
            regime_display_name: "Wendler 5/3/1".to_string(),
            session_description: format!(
                "Cycle {} • {} • {}",
                cycle,
                week_def.name,
                lifts
                    .iter()
                    .map(|&e| exercise_short_label(e))
                    .collect::<Vec<_>>()
                    .join("/")
            ),
            next_session_preview: week_def.preview.to_string(),
        };

        ProposeResult {
            proposed_groups,
            regime_context,
            suggested_workout_name: format!(
                "5/3/1 — Cycle {}, {}, {}",
                cycle,
                week_def.name,
                lifts_display.join(" + ")
            ),
            schedule_messages: Vec::new(),
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
        for &ex in WENDLER_LIFTS {
            let current = get_f32_or(state, tm_key(ex), default_tm(ex));
            let deloaded = round_to_unit_increment(current * pct, unit, 5.0, 2.5)
                .max(min_weight_lb(unit, 45.0, 20.0));
            set_f32(&mut adjusted, tm_key(ex), deloaded);
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
        let variant = get_str_or(state, KEY_VARIANT, "four_day");
        let week = get_int_or(state, KEY_WEEK, 1).clamp(1, 4);
        let target_sessions = sessions_per_variant(variant) as i32;
        let next_session_at = if last_session_at == 0 {
            now_ts
        } else {
            last_session_at + recovery_seconds_for_week(week)
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
        let target_slot_sets =
            simulate_target_slot_sets(self, state, last_session_at, now_ts, target_sessions);
        build_training_status(
            history,
            now_ts,
            last_session_at,
            next_session_at,
            target_sessions,
            &next_workout_slots,
            target_slot_sets,
        )
    }

    fn transition_state_on_workout_completed(
        &self,
        state: &mut StatePayload,
        _workout: &SchplannerWorkoutRecord,
        _slot_outcomes: &std::collections::HashMap<String, SchplannerSlotOutcome>,
    ) {
        let variant = get_str_or(state, KEY_VARIANT, "four_day");
        let sessions = sessions_per_variant(variant).max(1);
        let mut cycle = get_int_or(state, KEY_CYCLE, 1).max(1);
        let mut week = get_int_or(state, KEY_WEEK, 1).clamp(1, 4);
        let mut session = get_int_or(state, KEY_SESSION, 0).max(0) + 1;
        let wrapped_cycle = session >= sessions && week >= 4;
        if session >= sessions {
            session = 0;
            week += 1;
            if week > 4 {
                week = 1;
                cycle += 1;
            }
        }
        set_int(state, KEY_CYCLE, cycle);
        set_int(state, KEY_WEEK, week);
        set_int(state, KEY_SESSION, session);
        if !wrapped_cycle {
            return;
        }
        let unit = weight_unit_from_state(state);
        for &exercise in WENDLER_LIFTS {
            let current_tm = get_f32_or(state, tm_key(exercise), default_tm(exercise));
            let bump = if matches!(exercise, Exercise::Squat | Exercise::Deadlift) {
                10.0
            } else {
                5.0
            };
            let next_tm = if unit == crate::weight_units::AppWeightUnit::Kg {
                current_tm + (bump / 2.20462)
            } else {
                current_tm + bump
            };
            set_f32(state, tm_key(exercise), next_tm);
        }
    }
}
