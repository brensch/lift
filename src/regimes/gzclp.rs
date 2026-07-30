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
use crate::weight_units::{round_to_unit_increment, weight_unit_from_state};
use std::collections::HashMap;
use std::collections::HashSet;

// ─── Stage prescriptions ──────────────────────────────────────────────────────

fn t1_stage_prescription(stage: u8) -> (i32, i32) {
    match stage {
        1 => (5, 3),
        2 => (6, 2),
        _ => (10, 1),
    }
}

fn t2_stage_prescription(stage: u8) -> (i32, i32) {
    match stage {
        1 => (3, 10),
        2 => (3, 8),
        _ => (3, 6),
    }
}

// ─── State key helpers ────────────────────────────────────────────────────────

const KEY_SCHEDULE: &str = "schedule_variant";
const KEY_SESSION_IDX: &str = "next_session_index";
const T1_WEIGHT_BOUNDS: FloatFieldBounds = FloatFieldBounds {
    min: 45.0,
    max: 1000.0,
    step: 5.0,
};
const T2_WEIGHT_BOUNDS: FloatFieldBounds = FloatFieldBounds {
    min: 45.0,
    max: 1000.0,
    step: 5.0,
};
const T3_HEAVY_WEIGHT_BOUNDS: FloatFieldBounds = FloatFieldBounds {
    min: 45.0,
    max: 500.0,
    step: 5.0,
};
const T3_LIGHT_WEIGHT_BOUNDS: FloatFieldBounds = FloatFieldBounds {
    min: 10.0,
    max: 500.0,
    step: 5.0,
};
const LEG_CURL_WEIGHT_BOUNDS: FloatFieldBounds = FloatFieldBounds {
    min: 10.0,
    max: 300.0,
    step: 5.0,
};

fn t1_weight_key(ex: Exercise) -> &'static str {
    match ex {
        Exercise::Squat => "squat_t1_weight",
        Exercise::Deadlift => "deadlift_t1_weight",
        _ => "squat_t1_weight",
    }
}

fn t1_stage_key(ex: Exercise) -> &'static str {
    match ex {
        Exercise::Squat => "squat_t1_stage",
        Exercise::Deadlift => "deadlift_t1_stage",
        _ => "squat_t1_stage",
    }
}

fn t2_weight_key(ex: Exercise) -> &'static str {
    match ex {
        Exercise::BenchPress => "bench_press_t2_weight",
        Exercise::OverheadPress => "overhead_press_t2_weight",
        Exercise::BarbellRow => "barbell_row_t2_weight",
        _ => "bench_press_t2_weight",
    }
}

fn t2_stage_key(ex: Exercise) -> &'static str {
    match ex {
        Exercise::BenchPress => "bench_press_t2_stage",
        Exercise::OverheadPress => "overhead_press_t2_stage",
        Exercise::BarbellRow => "barbell_row_t2_stage",
        _ => "bench_press_t2_stage",
    }
}

fn t3_weight_key(ex: Exercise) -> &'static str {
    match ex {
        Exercise::HipThrust => "hip_thrust_t3_weight",
        Exercise::BulgarianSplitSquat => "bss_t3_weight",
        Exercise::RomanianDeadlift => "rdl_t3_weight",
        Exercise::LegCurl => "leg_curl_t3_weight",
        Exercise::GluteBridge => "glute_bridge_t3_weight",
        Exercise::Lunge => "lunge_t3_weight",
        _ => "hip_thrust_t3_weight",
    }
}

fn default_t1_weight(ex: Exercise) -> f32 {
    match ex {
        Exercise::Squat => 135.0,
        Exercise::Deadlift => 185.0,
        _ => 135.0,
    }
}

fn default_t2_weight(ex: Exercise) -> f32 {
    match ex {
        Exercise::BenchPress => 95.0,
        Exercise::OverheadPress => 65.0,
        Exercise::BarbellRow => 95.0,
        _ => 65.0,
    }
}

fn exercise_from_slot_key(slot_key: &str) -> Option<Exercise> {
    match slot_key {
        "exercise_squat" => Some(Exercise::Squat),
        "exercise_deadlift" => Some(Exercise::Deadlift),
        "exercise_bench_press" => Some(Exercise::BenchPress),
        "exercise_overhead_press" => Some(Exercise::OverheadPress),
        "exercise_barbell_row" => Some(Exercise::BarbellRow),
        "exercise_hip_thrust" => Some(Exercise::HipThrust),
        "exercise_bulgarian_split_squat" => Some(Exercise::BulgarianSplitSquat),
        "exercise_romanian_deadlift" => Some(Exercise::RomanianDeadlift),
        "exercise_leg_curl" => Some(Exercise::LegCurl),
        "exercise_glute_bridge" => Some(Exercise::GluteBridge),
        "exercise_lunge" => Some(Exercise::Lunge),
        _ => None,
    }
}

const T1_STAGE_OPTIONS: &[(&str, &str)] = &[
    ("stage_1_5x3", "Stage 1 — 5×3 (normal)"),
    ("stage_2_6x2", "Stage 2 — 6×2 (after 1st stall)"),
    ("stage_3_10x1", "Stage 3 — 10×1 (after 2nd stall)"),
];

const T2_STAGE_OPTIONS: &[(&str, &str)] = &[
    ("stage_1_3x10", "Stage 1 — 3×10"),
    ("stage_2_3x8", "Stage 2 — 3×8 (after 1st stall)"),
    ("stage_3_3x6", "Stage 3 — 3×6 (after 2nd stall)"),
];

fn stage_str_to_u8_t1(s: &str) -> u8 {
    match s {
        "stage_2_6x2" => 2,
        "stage_3_10x1" => 3,
        _ => 1,
    }
}

fn stage_str_to_u8_t2(s: &str) -> u8 {
    match s {
        "stage_2_3x8" => 2,
        "stage_3_3x6" => 3,
        _ => 1,
    }
}

// ─── Session templates ────────────────────────────────────────────────────────

// 4-day: 4 sessions. T1 alternates Squat/Deadlift; T2 cycles through 4 combos.
//   Session 0: T1 Squat  | T2 Bench + OHP   | T3 HipThrust + BSS
//   Session 1: T1 Deadlift | T2 OHP + Row    | T3 RDL + LegCurl
//   Session 2: T1 Squat  | T2 Row + Bench   | T3 GluteBridge + Lunge
//   Session 3: T1 Deadlift | T2 Bench + OHP  | T3 HipThrust + BSS  (repeats T2 combo)
//
// 3-day: 3 sessions. Both T1 each session; T2 cycles through 3 pairs.
//   Session 0: T1 Squat + Deadlift | T2 Bench + OHP   | T3 HipThrust + BSS
//   Session 1: T1 Squat + Deadlift | T2 OHP + Row     | T3 RDL + LegCurl
//   Session 2: T1 Squat + Deadlift | T2 Row + Bench   | T3 GluteBridge + Lunge

struct SessionTemplate {
    t1: &'static [Exercise],
    t2: &'static [Exercise],             // 2 T2 exercises
    t3: &'static [(Exercise, Exercise)], // paired T3 accessories
}

const SESSIONS_4DAY: &[SessionTemplate] = &[
    SessionTemplate {
        t1: &[Exercise::Squat],
        t2: &[Exercise::BenchPress, Exercise::OverheadPress],
        t3: &[(Exercise::HipThrust, Exercise::BulgarianSplitSquat)],
    },
    SessionTemplate {
        t1: &[Exercise::Deadlift],
        t2: &[Exercise::OverheadPress, Exercise::BarbellRow],
        t3: &[(Exercise::RomanianDeadlift, Exercise::LegCurl)],
    },
    SessionTemplate {
        t1: &[Exercise::Squat],
        t2: &[Exercise::BarbellRow, Exercise::BenchPress],
        t3: &[(Exercise::GluteBridge, Exercise::Lunge)],
    },
    SessionTemplate {
        t1: &[Exercise::Deadlift],
        t2: &[Exercise::BenchPress, Exercise::OverheadPress],
        t3: &[(Exercise::HipThrust, Exercise::BulgarianSplitSquat)],
    },
];

const SESSIONS_3DAY: &[SessionTemplate] = &[
    SessionTemplate {
        t1: &[Exercise::Squat, Exercise::Deadlift],
        t2: &[Exercise::BenchPress, Exercise::OverheadPress],
        t3: &[(Exercise::HipThrust, Exercise::BulgarianSplitSquat)],
    },
    SessionTemplate {
        t1: &[Exercise::Squat, Exercise::Deadlift],
        t2: &[Exercise::BarbellRow, Exercise::BenchPress],
        t3: &[(Exercise::RomanianDeadlift, Exercise::LegCurl)],
    },
    SessionTemplate {
        t1: &[Exercise::Squat, Exercise::Deadlift],
        t2: &[Exercise::OverheadPress, Exercise::BarbellRow],
        t3: &[(Exercise::GluteBridge, Exercise::Lunge)],
    },
];

fn sessions_for_variant(variant: &str) -> &'static [SessionTemplate] {
    if variant == "four_day" {
        SESSIONS_4DAY
    } else {
        SESSIONS_3DAY
    }
}

fn session_count(variant: &str) -> i64 {
    sessions_for_variant(variant).len() as i64
}

// ─── Regime impl ─────────────────────────────────────────────────────────────

pub struct GzclpRegime;

impl WorkoutRegime for GzclpRegime {
    fn display_name(&self) -> &'static str {
        "GZCLP"
    }

    fn catalog_meta(&self) -> ProgramCatalogMeta {
        ProgramCatalogMeta {
            headline: "Tiered progression that survives stalls",
            summary: "GZCLP uses T1/T2/T3 tiers with per-lift state transitions when a lift stalls.",
            description: "Heavy T1 lifts, moderate T2 lifts, and higher-rep T3 accessories progress independently at different paces.",
            how_it_works: "T1 lifts (Squat/Deadlift): 5x3 → 6x2 → 10x1 progression stages.\nT2 lifts (Bench/OHP/Row): 3x10 → 3x8 → 3x6.\nT3 accessories: simple higher-rep linear work.\n\nEach lift advances or resets based on that lift's own results.",
            at_a_glance: ProgramAtAGlanceMeta {
                days_per_week: "3-4 (default 4)",
                best_for: "Novice / early intermediate",
                average_session_time: "60-90 min",
                progression_style: "Tiered state machine",
            },
            details: vec![
                "T1 and T2 lifts can be in different stages at the same time.",
                "Last-set AMRAP is used on T1 stages 1 and 2.",
                "Accessory work remains flexible.",
            ],
            learn_more_links: vec![
                ("The Fitness Wiki: GZCLP", "https://thefitness.wiki/routines/gzclp/"),
                ("GZCL method archive", "https://thefitness.wiki/reddit-archive/gzcl-method-novice-to-elite/"),
            ],
            sort_order: 20,
        }
    }

    fn state_schema(&self) -> TrainingProgramStateSchema {
        build_schema(vec![
            with_onboarding(schema_enum(KEY_SCHEDULE, "Schedule", "Choose 3-day or 4-day rotation.", "Session", 1,
                vec![("three_day", "3-Day (both T1 lifts each session)"), ("four_day", "4-Day (alternating T1 each session)")])),
            schema_int(KEY_SESSION_IDX, "Next Session Index", "0-based index of the next session in the rotation. Edit to correct if out of sync.", "Session", 2, 0, 9),
            // T1 weights (onboarding) + stages (internal)
            with_onboarding(schema_float("squat_t1_weight", "Squat (T1)", "Starting weight for T1 Squat (lbs).", "T1 Weights", 10, T1_WEIGHT_BOUNDS)),
            schema_enum("squat_t1_stage", "Squat Stage", "T1 progression stage.", "T1 Stages", 11, T1_STAGE_OPTIONS.to_vec()),
            with_onboarding(schema_float("deadlift_t1_weight", "Deadlift (T1)", "Starting weight for T1 Deadlift (lbs).", "T1 Weights", 12, T1_WEIGHT_BOUNDS)),
            schema_enum("deadlift_t1_stage", "Deadlift Stage", "T1 progression stage.", "T1 Stages", 13, T1_STAGE_OPTIONS.to_vec()),
            // T2 weights (onboarding) + stages (internal)
            with_onboarding(schema_float("bench_press_t2_weight", "Bench Press (T2)", "Starting weight for T2 Bench (lbs).", "T2 Weights", 20, T2_WEIGHT_BOUNDS)),
            schema_enum("bench_press_t2_stage", "Bench Press Stage", "T2 progression stage.", "T2 Stages", 21, T2_STAGE_OPTIONS.to_vec()),
            with_onboarding(schema_float("overhead_press_t2_weight", "Overhead Press (T2)", "Starting weight for T2 OHP (lbs).", "T2 Weights", 22, T2_WEIGHT_BOUNDS)),
            schema_enum("overhead_press_t2_stage", "OHP Stage", "T2 progression stage.", "T2 Stages", 23, T2_STAGE_OPTIONS.to_vec()),
            with_onboarding(schema_float("barbell_row_t2_weight", "Barbell Row (T2)", "Starting weight for T2 Row (lbs).", "T2 Weights", 24, T2_WEIGHT_BOUNDS)),
            schema_enum("barbell_row_t2_stage", "Barbell Row Stage", "T2 progression stage.", "T2 Stages", 25, T2_STAGE_OPTIONS.to_vec()),
            // T3 weights — not shown in onboarding (defaults are fine)
            schema_float("hip_thrust_t3_weight", "Hip Thrust (T3)", "T3 weight — increments when AMRAP ≥ 25 reps.", "T3 Weights", 30, T3_HEAVY_WEIGHT_BOUNDS),
            schema_float("bss_t3_weight", "BSS (T3)", "Bulgarian Split Squat weight.", "T3 Weights", 31, T3_LIGHT_WEIGHT_BOUNDS),
            schema_float("rdl_t3_weight", "RDL (T3)", "Romanian Deadlift weight.", "T3 Weights", 32, T3_HEAVY_WEIGHT_BOUNDS),
            schema_float("leg_curl_t3_weight", "Leg Curl (T3)", "Leg Curl weight.", "T3 Weights", 33, LEG_CURL_WEIGHT_BOUNDS),
            schema_float("glute_bridge_t3_weight", "Glute Bridge (T3)", "Glute Bridge weight.", "T3 Weights", 34, T3_HEAVY_WEIGHT_BOUNDS),
            schema_float("lunge_t3_weight", "Lunge (T3)", "Lunge weight.", "T3 Weights", 35, LEG_CURL_WEIGHT_BOUNDS),
        ])
    }

    fn default_state(&self) -> StatePayload {
        let mut s = StatePayload::new();
        set_str(&mut s, KEY_SCHEDULE, "four_day");
        set_int(&mut s, KEY_SESSION_IDX, 0);
        // T1
        for ex in [Exercise::Squat, Exercise::Deadlift] {
            set_f32(&mut s, t1_weight_key(ex), default_t1_weight(ex));
            set_str(&mut s, t1_stage_key(ex), "stage_1_5x3");
        }
        // T2
        for ex in [
            Exercise::BenchPress,
            Exercise::OverheadPress,
            Exercise::BarbellRow,
        ] {
            set_f32(&mut s, t2_weight_key(ex), default_t2_weight(ex));
            set_str(&mut s, t2_stage_key(ex), "stage_1_3x10");
        }
        // T3
        for (ex, w) in [
            (Exercise::HipThrust, 45.0f32),
            (Exercise::BulgarianSplitSquat, 10.0),
            (Exercise::RomanianDeadlift, 45.0),
            (Exercise::LegCurl, 10.0),
            (Exercise::GluteBridge, 45.0),
            (Exercise::Lunge, 10.0),
        ] {
            set_f32(&mut s, t3_weight_key(ex), w);
        }
        s
    }

    fn validate_state(&self, state: &StatePayload) -> Vec<String> {
        let mut warnings = Vec::new();
        let variant = get_str_or(state, KEY_SCHEDULE, "four_day");
        if variant != "three_day" && variant != "four_day" {
            warnings.push(format!(
                "schedule_variant '{}' is not 'three_day' or 'four_day'",
                variant
            ));
        }
        let max_idx = session_count(variant) - 1;
        let idx = get_int_or(state, KEY_SESSION_IDX, 0);
        if idx < 0 || idx > max_idx {
            warnings.push(format!(
                "next_session_index {} is out of range 0-{}",
                idx, max_idx
            ));
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
        let variant = get_str_or(state, KEY_SCHEDULE, "four_day");
        let sessions = sessions_for_variant(variant);
        let idx = (get_int_or(state, KEY_SESSION_IDX, 0) as usize) % sessions.len();
        let tmpl = &sessions[idx];
        let mut proposed_groups = Vec::new();

        // T1 groups
        for &ex in tmpl.t1 {
            let w = get_f32_or(state, t1_weight_key(ex), default_t1_weight(ex));
            let stage = stage_str_to_u8_t1(get_str_or(state, t1_stage_key(ex), "stage_1_5x3"));
            let (sets, reps) = t1_stage_prescription(stage);
            let last_set_amrap = stage <= 2; // stages 1 and 2 use AMRAP on last set
            let working_sets: Vec<WorkingSetSpec> = (0..sets)
                .map(|i| {
                    let is_last = i == sets - 1;
                    let is_amrap = last_set_amrap && is_last;
                    WorkingSetSpec {
                        target_weight: w,
                        target_reps: reps,
                        is_amrap,
                        instruction: if is_amrap {
                            "AMRAP — push for max reps".to_string()
                        } else {
                            String::new()
                        },
                        progression_hint: Some(progression_hint_for_set(
                            ex,
                            "T1",
                            ProgressionRule::AllSetsMatchTarget,
                            0,
                            true,
                        )),
                    }
                })
                .collect();
            let cfg = ExerciseTypeConfig {
                exercise: ex as i32,
                start_weight: w,
                end_weight: w,
                reps,
                include_warmup: true,
                rest_config: None,
                last_set_amrap,
                working_sets,
            };
            proposed_groups.push(ProposedExerciseGroup {
                name: exercise_display_name(ex),
                sets,
                interleave_warmups: false,
                exercise_configs: vec![cfg],
                rest_config: rest_cfg(180, 300),
                tags: vec!["recommended".to_string(), "T1".to_string()],
                prescribed_by_regime: false,
                estimated_duration_seconds: 0,
                materialized_sets: Vec::new(),
            });
        }

        // T2 groups
        for &ex in tmpl.t2 {
            let w = get_f32_or(state, t2_weight_key(ex), default_t2_weight(ex));
            let stage = stage_str_to_u8_t2(get_str_or(state, t2_stage_key(ex), "stage_1_3x10"));
            let (sets, reps) = t2_stage_prescription(stage);
            let cfg = ExerciseTypeConfig {
                exercise: ex as i32,
                start_weight: w,
                end_weight: w,
                reps,
                include_warmup: true,
                rest_config: None,
                last_set_amrap: false,
                working_sets: (0..sets)
                    .map(|_| WorkingSetSpec {
                        target_weight: w,
                        target_reps: reps,
                        is_amrap: false,
                        instruction: String::new(),
                        progression_hint: Some(progression_hint_for_set(
                            ex,
                            "T2",
                            ProgressionRule::AllSetsMatchTarget,
                            0,
                            true,
                        )),
                    })
                    .collect(),
            };
            proposed_groups.push(ProposedExerciseGroup {
                name: exercise_display_name(ex),
                sets,
                interleave_warmups: false,
                exercise_configs: vec![cfg],
                rest_config: rest_cfg(90, 120),
                tags: vec!["recommended".to_string(), "T2".to_string()],
                prescribed_by_regime: false,
                estimated_duration_seconds: 0,
                materialized_sets: Vec::new(),
            });
        }

        // T3 accessory pairs
        for &(ex_a, ex_b) in tmpl.t3 {
            let wa = get_f32_or(state, t3_weight_key(ex_a), 45.0);
            let wb = get_f32_or(state, t3_weight_key(ex_b), 10.0);
            let make_t3_sets = |exercise: Exercise, w: f32| -> Vec<WorkingSetSpec> {
                (0..3)
                    .map(|i| {
                        let is_last = i == 2;
                        WorkingSetSpec {
                            target_weight: w,
                            target_reps: 15,
                            is_amrap: is_last,
                            instruction: if is_last {
                                "AMRAP — 25+ reps to add weight next session".to_string()
                            } else {
                                String::new()
                            },
                            progression_hint: Some(progression_hint_for_set(
                                exercise,
                                "T3",
                                ProgressionRule::TopSetAmrap,
                                25,
                                is_last,
                            )),
                        }
                    })
                    .collect()
            };
            let ca = ExerciseTypeConfig {
                exercise: ex_a as i32,
                start_weight: wa,
                end_weight: wa,
                reps: 15,
                include_warmup: true,
                rest_config: None,
                last_set_amrap: true,
                working_sets: make_t3_sets(ex_a, wa),
            };
            let cb = ExerciseTypeConfig {
                exercise: ex_b as i32,
                start_weight: wb,
                end_weight: wb,
                reps: 15,
                include_warmup: false,
                rest_config: None,
                last_set_amrap: true,
                working_sets: make_t3_sets(ex_b, wb),
            };
            proposed_groups.push(ProposedExerciseGroup {
                name: format!(
                    "{} + {}",
                    exercise_display_name(ex_a),
                    exercise_display_name(ex_b)
                ),
                sets: 3,
                interleave_warmups: true,
                exercise_configs: vec![ca, cb],
                rest_config: rest_cfg(60, 60),
                tags: vec!["auxiliary".to_string(), "T3".to_string()],
                prescribed_by_regime: false,
                estimated_duration_seconds: 0,
                materialized_sets: Vec::new(),
            });
        }

        let session_count = sessions.len();

        let regime_context = RegimeContext {
            regime_display_name: "GZCLP".to_string(),
            session_description: {
                let t1 = tmpl
                    .t1
                    .iter()
                    .map(|&ex| {
                        let stage =
                            stage_str_to_u8_t1(get_str_or(state, t1_stage_key(ex), "stage_1_5x3"));
                        format!("{} S{}", exercise_short_label(ex), stage)
                    })
                    .collect::<Vec<_>>()
                    .join(" / ");
                let t2 = tmpl
                    .t2
                    .iter()
                    .map(|&ex| {
                        let stage =
                            stage_str_to_u8_t2(get_str_or(state, t2_stage_key(ex), "stage_1_3x10"));
                        format!("{} S{}", exercise_short_label(ex), stage)
                    })
                    .collect::<Vec<_>>()
                    .join(" / ");
                format!("Session {} • T1 {} • T2 {}", idx + 1, t1, t2)
            },
            next_session_preview: format!(
                "Session {} of {}. State machine updates after each session.",
                idx + 1,
                session_count
            ),
            phase_narrative: {
                let t1_desc = tmpl
                    .t1
                    .iter()
                    .map(|&ex| {
                        let stage = stage_str_to_u8_t1(get_str_or(
                            state,
                            t1_stage_key(ex),
                            "stage_1_5x3",
                        ));
                        let (sets, reps) = t1_stage_prescription(stage);
                        format!(
                            "{} at Stage {stage} ({sets}×{reps})",
                            exercise_display_name(ex)
                        )
                    })
                    .collect::<Vec<_>>()
                    .join(" and ");
                format!(
                    "Session {} — your heavy T1 lift is {t1_desc}. Hit every rep and the weight climbs; miss and you cycle the scheme 5×3 → 6×2 → 10×1, then reset heavier. T2 is lighter volume behind it, T3 is the arms/abs finisher.",
                    idx + 1
                )
            },
            last_session_summary: String::new(),
        };

        ProposeResult {
            proposed_groups,
            regime_context,
            suggested_workout_name: {
                let sq_stage =
                    stage_str_to_u8_t1(get_str_or(state, "squat_t1_stage", "stage_1_5x3"));
                let dl_stage =
                    stage_str_to_u8_t1(get_str_or(state, "deadlift_t1_stage", "stage_1_5x3"));
                let (sq_sets, sq_reps) = t1_stage_prescription(sq_stage);
                let (dl_sets, dl_reps) = t1_stage_prescription(dl_stage);
                if sq_stage == dl_stage {
                    format!("GZCLP — T1 Stage {} ({}×{})", sq_stage, sq_sets, sq_reps)
                } else {
                    format!(
                        "GZCLP — SQ {}×{} / DL {}×{}",
                        sq_sets, sq_reps, dl_sets, dl_reps
                    )
                }
            },
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
        // GZCLP's comeback: reset every T1 back to Stage 1 (5×3) — the safe rebuild
        // scheme — and ease the loads, rather than returning to heavy 10×1 singles
        // cold. T2 likewise resets to its first stage (3×10).
        let pct = if days_since >= 30 { 0.8 } else { 0.9 };
        let unit = weight_unit_from_state(state);
        let mut adjusted = state.clone();
        for ex in [Exercise::Squat, Exercise::Deadlift] {
            let w = get_f32_or(state, t1_weight_key(ex), default_t1_weight(ex));
            set_f32(
                &mut adjusted,
                t1_weight_key(ex),
                round_to_unit_increment(w * pct, unit, 5.0, 2.5),
            );
            set_str(&mut adjusted, t1_stage_key(ex), "stage_1_5x3");
        }
        for ex in [
            Exercise::BenchPress,
            Exercise::OverheadPress,
            Exercise::BarbellRow,
        ] {
            let w = get_f32_or(state, t2_weight_key(ex), default_t2_weight(ex));
            set_f32(
                &mut adjusted,
                t2_weight_key(ex),
                round_to_unit_increment(w * pct, unit, 5.0, 2.5),
            );
            set_str(&mut adjusted, t2_stage_key(ex), "stage_1_3x10");
        }
        adjusted
    }

    fn describe_comeback(
        &self,
        stored: &StatePayload,
        adjusted: &StatePayload,
        days_off: i64,
    ) -> Option<String> {
        let (_, pct) = super::comeback_weight_ratio(stored, adjusted)?;
        let was_advanced = [Exercise::Squat, Exercise::Deadlift].iter().any(|&ex| {
            stage_str_to_u8_t1(get_str_or(stored, t1_stage_key(ex), "stage_1_5x3")) > 1
        });
        let mut s = format!(
            "Back after {days_off} days off. Today eases the loads to about {pct}%",
        );
        if was_advanced {
            s.push_str(" and resets your T1 lifts to Stage 1 (5×3)");
        }
        s.push_str(" — the safe rebuild scheme, rather than dropping you back onto heavy singles cold.");
        Some(s)
    }

    fn derive_training_status(
        &self,
        state: &StatePayload,
        history: &[SchplannerWorkoutRecord],
        last_session_at: i64,
        now_ts: i64,
    ) -> schlift::workout::v1::TrainingStatus {
        let variant = get_str_or(state, KEY_SCHEDULE, "four_day");
        let target_sessions = if variant == "four_day" { 4 } else { 3 };
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
        slot_outcomes: &HashMap<String, SchplannerSlotOutcome>,
    ) {
        let unit = weight_unit_from_state(state);
        for (slot_key, outcome) in slot_outcomes {
            if !outcome.workout_ended {
                continue;
            }
            let Some(exercise) = exercise_from_slot_key(slot_key) else {
                continue;
            };
            match outcome.tier.as_str() {
                "T1" => {
                    let current =
                        get_f32_or(state, t1_weight_key(exercise), default_t1_weight(exercise));
                    let attempted_weight = outcome.last_completed_actual_weight.unwrap_or(current);
                    let stage_key = t1_stage_key(exercise);
                    let stage = stage_str_to_u8_t1(get_str_or(state, stage_key, "stage_1_5x3"));
                    if outcome.all_sets_hit_target() {
                        let base_weight = outcome
                            .last_successful_actual_weight
                            .unwrap_or(attempted_weight);
                        let next_weight =
                            round_to_unit_increment(base_weight + 10.0, unit, 5.0, 2.5);
                        set_f32(state, t1_weight_key(exercise), next_weight);
                        set_str(state, stage_key, "stage_1_5x3");
                    } else {
                        match stage {
                            1 => {
                                set_str(state, stage_key, "stage_2_6x2");
                            }
                            2 => {
                                set_str(state, stage_key, "stage_3_10x1");
                            }
                            _ => {
                                let reset =
                                    round_to_unit_increment(attempted_weight * 0.9, unit, 5.0, 2.5);
                                set_f32(state, t1_weight_key(exercise), reset);
                                set_str(state, stage_key, "stage_1_5x3");
                            }
                        }
                    }
                }
                "T2" => {
                    let current =
                        get_f32_or(state, t2_weight_key(exercise), default_t2_weight(exercise));
                    let attempted_weight = outcome.last_completed_actual_weight.unwrap_or(current);
                    let stage_key = t2_stage_key(exercise);
                    let stage = stage_str_to_u8_t2(get_str_or(state, stage_key, "stage_1_3x10"));
                    if outcome.all_sets_hit_target() {
                        let base_weight = outcome
                            .last_successful_actual_weight
                            .unwrap_or(attempted_weight);
                        let next_weight =
                            round_to_unit_increment(base_weight + 5.0, unit, 5.0, 2.5);
                        set_f32(state, t2_weight_key(exercise), next_weight);
                        set_str(state, stage_key, "stage_1_3x10");
                    } else {
                        match stage {
                            1 => {
                                set_str(state, stage_key, "stage_2_3x8");
                            }
                            2 => {
                                set_str(state, stage_key, "stage_3_3x6");
                            }
                            _ => {
                                let reset =
                                    round_to_unit_increment(attempted_weight * 0.9, unit, 5.0, 2.5);
                                set_f32(state, t2_weight_key(exercise), reset);
                                set_str(state, stage_key, "stage_1_3x10");
                            }
                        }
                    }
                }
                "T3" => {
                    let current = get_f32_or(state, t3_weight_key(exercise), 10.0);
                    let base_weight = outcome
                        .last_successful_actual_weight
                        .or(outcome.last_completed_actual_weight)
                        .unwrap_or(current);
                    if outcome.top_set_hit_threshold() {
                        let next_weight =
                            round_to_unit_increment(base_weight + 5.0, unit, 5.0, 2.5);
                        set_f32(state, t3_weight_key(exercise), next_weight);
                    }
                }
                _ => {}
            }
        }
        let variant = get_str_or(state, KEY_SCHEDULE, "four_day");
        let next = (get_int_or(state, KEY_SESSION_IDX, 0) + 1).rem_euclid(session_count(variant));
        set_int(state, KEY_SESSION_IDX, next);
    }
}
