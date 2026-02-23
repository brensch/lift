use lift::workout::v1::{
    Exercise, ExerciseTypeConfig, ProposedExerciseGroup, RegimeContext, TrainingProgramStateSchema,
    WorkingSetSpec,
};

use crate::program_state::{
    build_schema, get_f32_or, get_int_or, get_str_or, schema_enum, schema_float, schema_int,
    set_f32, set_int, set_str, with_onboarding, FieldVal, PendingUpdateDef, PendingUpdateFieldDef,
    ProposeResult, StatePayload, WorkoutCompletionResult,
};

use super::{exercise_display_name, rest_cfg, ProgramAtAGlanceMeta, ProgramCatalogMeta, WorkoutRegime};
use lift::workout::v1::StateFieldKind;

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

fn tm_increment(ex: Exercise) -> f32 {
    match ex {
        Exercise::Squat | Exercise::Deadlift => 10.0,
        _ => 5.0,
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
    if variant == "four_day" { 4 } else { 3 }
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

fn build_wendler_working_sets(tm: f32, week_def: &WeekDef) -> Vec<WorkingSetSpec> {
    week_def
        .set_pcts
        .iter()
        .zip(week_def.set_reps.iter())
        .enumerate()
        .map(|(idx, (&pct, &reps))| {
            let w = (tm * pct / 5.0).round() * 5.0;
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
            }
        })
        .collect()
}

fn set_pattern_text(week_def: &WeekDef) -> String {
    week_def
        .set_reps
        .iter()
        .enumerate()
        .map(|(idx, &r)| {
            if idx == 2 && week_def.top_set_amrap {
                format!("{}+", r)
            } else {
                r.to_string()
            }
        })
        .collect::<Vec<_>>()
        .join("/")
}

fn coaching_notes_for_week(week: i64, week_def: &WeekDef) -> Vec<String> {
    if week_def.is_deload {
        vec![
            "Deload week — intentionally light.".to_string(),
            "Focus on technique and movement quality.".to_string(),
            "Your Training Maxes increase next cycle.".to_string(),
        ]
    } else if week == 3 {
        vec![
            "Peak week — push the AMRAP set hard.".to_string(),
            "Warm up thoroughly before the top set.".to_string(),
            "Your reps on the top set measure progress.".to_string(),
        ]
    } else {
        vec![
            "Push the last set for extra reps if you feel strong.".to_string(),
            "Log all reps accurately for best tracking.".to_string(),
        ]
    }
}

// ─── Regime impl ─────────────────────────────────────────────────────────────

impl WorkoutRegime for Wendler531Regime {
    fn display_name(&self) -> &'static str {
        "Wendler 5/3/1"
    }

    fn default_days_per_week(&self) -> i32 {
        4
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
            schema_int(KEY_CYCLE, "Cycle", "Current training cycle number (starts at 1).", "Progress", 10, 1, 100),
            schema_int(KEY_WEEK, "Week", "Current week within cycle (1=Volume, 2=Intensity, 3=Peak, 4=Deload).", "Progress", 11, 1, 4),
            schema_int(KEY_SESSION, "Session in Week", "0-based training day index within the current week.", "Progress", 12, 0, 3),
            // Training maxes — shown during onboarding
            with_onboarding(schema_float(KEY_SQ_TM, "Squat TM", "Training Max (lbs). Set to ~90% of your estimated 1RM.", "Training Maxes", 20, 45.0, 1000.0, 5.0)),
            with_onboarding(schema_float(KEY_BP_TM, "Bench Press TM", "Training Max (lbs). Set to ~90% of your estimated 1RM.", "Training Maxes", 21, 45.0, 1000.0, 5.0)),
            with_onboarding(schema_float(KEY_DL_TM, "Deadlift TM", "Training Max (lbs). Set to ~90% of your estimated 1RM.", "Training Maxes", 22, 45.0, 1000.0, 5.0)),
            with_onboarding(schema_float(KEY_OHP_TM, "Overhead Press TM", "Training Max (lbs). Set to ~90% of your estimated 1RM.", "Training Maxes", 23, 45.0, 1000.0, 5.0)),
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
        if week < 1 || week > 4 {
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
    ) -> ProposeResult {
        let variant = get_str_or(state, KEY_VARIANT, "four_day");
        let cycle = get_int_or(state, KEY_CYCLE, 1).max(1);
        let week = get_int_or(state, KEY_WEEK, 1).clamp(1, 4);
        let session_in_week = get_int_or(state, KEY_SESSION, 0).max(0);

        let week_def = &WEEKS[(week - 1) as usize];
        let lifts = lifts_for_session(variant, cycle, week, session_in_week);
        let pattern = set_pattern_text(week_def);

        let mut proposed_groups = Vec::new();

        for &ex in &lifts {
            let tm = get_f32_or(state, tm_key(ex), default_tm(ex));
            let working_sets = build_wendler_working_sets(tm, week_def);

            let start_w = working_sets
                .first()
                .map(|s| s.target_weight)
                .unwrap_or((tm * 0.65 / 5.0).round() * 5.0);
            let end_w = working_sets
                .last()
                .map(|s| s.target_weight)
                .unwrap_or((tm * 0.85 / 5.0).round() * 5.0);
            let first_reps = working_sets
                .first()
                .map(|s| s.target_reps)
                .unwrap_or(5);

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
                explanation: format!(
                    "5/3/1 Cycle {}, {} — {} ({}). TM: {:.0} lbs.",
                    cycle,
                    week_def.name,
                    exercise_display_name(ex),
                    pattern,
                    tm
                ),
                prescribed_by_regime: false,
            });
        }

        let display_variant = if variant == "four_day" { "4-Day" } else { "3-Day" };
        let lifts_display: Vec<String> = lifts.iter().map(|&e| exercise_display_name(e)).collect();

        let regime_context = RegimeContext {
            regime_display_name: format!("Wendler 5/3/1 {} — Cycle {}", display_variant, cycle),
            session_description: week_def.name.to_string(),
            next_session_preview: week_def.preview.to_string(),
            coaching_notes: coaching_notes_for_week(week, week_def),
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
            recovery_seconds: self.recovery_seconds_for_state(state),
        }
    }

    fn transition_state_on_workout_complete(
        &self,
        state: &StatePayload,
        _result: &WorkoutCompletionResult,
        _ended_at: i64,
    ) -> StatePayload {
        let mut new_state = state.clone();

        let variant = get_str_or(state, KEY_VARIANT, "four_day");
        let sessions = sessions_per_variant(variant);
        let cycle = get_int_or(state, KEY_CYCLE, 1).max(1);
        let week = get_int_or(state, KEY_WEEK, 1).clamp(1, 4);
        let session_in_week = get_int_or(state, KEY_SESSION, 0).max(0);

        let next_session = session_in_week + 1;
        if next_session >= sessions {
            // End of week
            set_int(&mut new_state, KEY_SESSION, 0);
            let next_week = week + 1;
            if next_week > 4 {
                // End of cycle: advance cycle, bump TMs, reset week
                set_int(&mut new_state, KEY_WEEK, 1);
                set_int(&mut new_state, KEY_CYCLE, cycle + 1);
                for &ex in WENDLER_LIFTS {
                    let current_tm = get_f32_or(state, tm_key(ex), default_tm(ex));
                    set_f32(&mut new_state, tm_key(ex), current_tm + tm_increment(ex));
                }
            } else {
                set_int(&mut new_state, KEY_WEEK, next_week);
            }
        } else {
            set_int(&mut new_state, KEY_SESSION, next_session);
        }

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
            title: "Long break — Training Max reset recommended".to_string(),
            message: format!(
                "It's been {} days since your last session. Reducing your Training Maxes will help you ease back in safely and avoid injury.",
                days_since
            ),
            fields: vec![PendingUpdateFieldDef {
                key: "deload_percent".to_string(),
                label: "Reset to % of current TM".to_string(),
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
                for &ex in WENDLER_LIFTS {
                    let current = get_f32_or(state, tm_key(ex), default_tm(ex));
                    let deloaded = ((current * pct) / 5.0).round() * 5.0;
                    set_f32(&mut new_state, tm_key(ex), deloaded.max(45.0));
                }
                Ok(new_state)
            }
            _ => Err(format!("Unknown update_id: {}", update_id)),
        }
    }

    fn recovery_seconds_for_state(&self, state: &StatePayload) -> i64 {
        let week = get_int_or(state, KEY_WEEK, 1);
        match week {
            4 => 24 * 3600,
            3 => 72 * 3600,
            _ => 48 * 3600,
        }
    }
}
