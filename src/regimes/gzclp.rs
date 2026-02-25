use lift::workout::v1::{
    Exercise, ExerciseTypeConfig, ProposedExerciseGroup, RegimeContext, TrainingProgramStateSchema,
    WorkingSetSpec,
};

use crate::program_state::{
    build_schema, get_f32_or, get_int_or, get_str_or, schema_enum, schema_float, schema_int,
    set_f32, set_int, set_str, with_onboarding, FieldVal, PendingUpdateDef, PendingUpdateFieldDef,
    ProposeResult, StatePayload, WorkoutCompletionResult,
};

use super::{
    exercise_display_name, rest_cfg, ProgramAtAGlanceMeta, ProgramCatalogMeta, WorkoutRegime,
};
use lift::workout::v1::StateFieldKind;

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

fn t1_phase_text(stage: u8) -> &'static str {
    match stage {
        1 => "Phase 1/3: 5×3 (last set AMRAP)",
        2 => "Phase 2/3: 6×2 (last set AMRAP)",
        _ => "Phase 3/3: 10×1 (no AMRAP)",
    }
}

fn t2_phase_text(stage: u8) -> &'static str {
    match stage {
        1 => "Phase 1/3: 3×10",
        2 => "Phase 2/3: 3×8",
        _ => "Phase 3/3: 3×6",
    }
}

// ─── State key helpers ────────────────────────────────────────────────────────

const KEY_SCHEDULE: &str = "schedule_variant";
const KEY_SESSION_IDX: &str = "next_session_index";

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

fn stage_u8_to_str_t1(n: u8) -> &'static str {
    match n {
        2 => "stage_2_6x2",
        3 => "stage_3_10x1",
        _ => "stage_1_5x3",
    }
}

fn stage_str_to_u8_t2(s: &str) -> u8 {
    match s {
        "stage_2_3x8" => 2,
        "stage_3_3x6" => 3,
        _ => 1,
    }
}

fn stage_u8_to_str_t2(n: u8) -> &'static str {
    match n {
        2 => "stage_2_3x8",
        3 => "stage_3_3x6",
        _ => "stage_1_3x10",
    }
}

fn gzclp_t1_increment(ex: Exercise) -> f32 {
    match ex {
        Exercise::Squat | Exercise::Deadlift => 10.0,
        _ => 5.0,
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
    t2: &'static [Exercise],   // 2 T2 exercises
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

    fn default_days_per_week(&self) -> i32 {
        4
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
            with_onboarding(schema_float("squat_t1_weight", "Squat (T1)", "Starting weight for T1 Squat (lbs).", "T1 Weights", 10, 45.0, 1000.0, 10.0)),
            schema_enum("squat_t1_stage", "Squat Stage", "T1 progression stage.", "T1 Stages", 11, T1_STAGE_OPTIONS.to_vec()),
            with_onboarding(schema_float("deadlift_t1_weight", "Deadlift (T1)", "Starting weight for T1 Deadlift (lbs).", "T1 Weights", 12, 45.0, 1000.0, 10.0)),
            schema_enum("deadlift_t1_stage", "Deadlift Stage", "T1 progression stage.", "T1 Stages", 13, T1_STAGE_OPTIONS.to_vec()),
            // T2 weights (onboarding) + stages (internal)
            with_onboarding(schema_float("bench_press_t2_weight", "Bench Press (T2)", "Starting weight for T2 Bench (lbs).", "T2 Weights", 20, 45.0, 1000.0, 5.0)),
            schema_enum("bench_press_t2_stage", "Bench Press Stage", "T2 progression stage.", "T2 Stages", 21, T2_STAGE_OPTIONS.to_vec()),
            with_onboarding(schema_float("overhead_press_t2_weight", "Overhead Press (T2)", "Starting weight for T2 OHP (lbs).", "T2 Weights", 22, 45.0, 1000.0, 5.0)),
            schema_enum("overhead_press_t2_stage", "OHP Stage", "T2 progression stage.", "T2 Stages", 23, T2_STAGE_OPTIONS.to_vec()),
            with_onboarding(schema_float("barbell_row_t2_weight", "Barbell Row (T2)", "Starting weight for T2 Row (lbs).", "T2 Weights", 24, 45.0, 1000.0, 5.0)),
            schema_enum("barbell_row_t2_stage", "Barbell Row Stage", "T2 progression stage.", "T2 Stages", 25, T2_STAGE_OPTIONS.to_vec()),
            // T3 weights — not shown in onboarding (defaults are fine)
            schema_float("hip_thrust_t3_weight", "Hip Thrust (T3)", "T3 weight — increments when AMRAP ≥ 25 reps.", "T3 Weights", 30, 45.0, 500.0, 5.0),
            schema_float("bss_t3_weight", "BSS (T3)", "Bulgarian Split Squat weight.", "T3 Weights", 31, 10.0, 500.0, 5.0),
            schema_float("rdl_t3_weight", "RDL (T3)", "Romanian Deadlift weight.", "T3 Weights", 32, 45.0, 500.0, 5.0),
            schema_float("leg_curl_t3_weight", "Leg Curl (T3)", "Leg Curl weight.", "T3 Weights", 33, 10.0, 300.0, 5.0),
            schema_float("glute_bridge_t3_weight", "Glute Bridge (T3)", "Glute Bridge weight.", "T3 Weights", 34, 45.0, 500.0, 5.0),
            schema_float("lunge_t3_weight", "Lunge (T3)", "Lunge weight.", "T3 Weights", 35, 10.0, 300.0, 5.0),
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
        for ex in [Exercise::BenchPress, Exercise::OverheadPress, Exercise::BarbellRow] {
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
            warnings.push(format!("schedule_variant '{}' is not 'three_day' or 'four_day'", variant));
        }
        let max_idx = session_count(variant) - 1;
        let idx = get_int_or(state, KEY_SESSION_IDX, 0);
        if idx < 0 || idx > max_idx {
            warnings.push(format!("next_session_index {} is out of range 0-{}", idx, max_idx));
        }
        warnings
    }

    fn propose_from_state(
        &self,
        state: &StatePayload,
        _last_session_at: i64,
        _now_ts: i64,
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
                        instruction: if is_amrap { "AMRAP — push for max reps".to_string() } else { String::new() },
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
                explanation: format!("GZCLP T1 {} — {}", t1_phase_text(stage), w),
                prescribed_by_regime: false,
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
                    .map(|_| WorkingSetSpec { target_weight: w, target_reps: reps, is_amrap: false, instruction: String::new() })
                    .collect(),
            };
            proposed_groups.push(ProposedExerciseGroup {
                name: exercise_display_name(ex),
                sets,
                interleave_warmups: false,
                exercise_configs: vec![cfg],
                rest_config: rest_cfg(90, 120),
                tags: vec!["recommended".to_string(), "T2".to_string()],
                explanation: format!("GZCLP T2 {} — {} lbs", t2_phase_text(stage), w),
                prescribed_by_regime: false,
            });
        }

        // T3 accessory pairs
        for &(ex_a, ex_b) in tmpl.t3 {
            let wa = get_f32_or(state, t3_weight_key(ex_a), 45.0);
            let wb = get_f32_or(state, t3_weight_key(ex_b), 10.0);
            let make_t3_sets = |w: f32| -> Vec<WorkingSetSpec> {
                (0..3)
                    .map(|i| {
                        let is_last = i == 2;
                        WorkingSetSpec {
                            target_weight: w,
                            target_reps: 15,
                            is_amrap: is_last,
                            instruction: if is_last { "AMRAP — 25+ reps to add weight next session".to_string() } else { String::new() },
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
                working_sets: make_t3_sets(wa),
            };
            let cb = ExerciseTypeConfig {
                exercise: ex_b as i32,
                start_weight: wb,
                end_weight: wb,
                reps: 15,
                include_warmup: false,
                rest_config: None,
                last_set_amrap: true,
                working_sets: make_t3_sets(wb),
            };
            proposed_groups.push(ProposedExerciseGroup {
                name: format!("{} + {}", exercise_display_name(ex_a), exercise_display_name(ex_b)),
                sets: 3,
                interleave_warmups: true,
                exercise_configs: vec![ca, cb],
                rest_config: rest_cfg(60, 60),
                tags: vec!["auxiliary".to_string(), "T3".to_string()],
                explanation: "T3 accessories — 3×15, last set AMRAP. Add weight when last set hits 25+ reps.".to_string(),
                prescribed_by_regime: false,
            });
        }

        // Build T1 stage descriptions for regime context
        let t1_stages: Vec<String> = [Exercise::Squat, Exercise::Deadlift]
            .iter()
            .map(|&ex| {
                let stage = stage_str_to_u8_t1(get_str_or(state, t1_stage_key(ex), "stage_1_5x3"));
                let (sets, reps) = t1_stage_prescription(stage);
                format!("T1 {}: Stage {} ({}×{})", exercise_display_name(ex), stage, sets, reps)
            })
            .collect();

        let session_count = sessions.len();
        let regime_context = RegimeContext {
            regime_display_name: "GZCLP".to_string(),
            session_description: t1_stages.join(" · "),
            next_session_preview: format!(
                "Session {} of {}. State machine updates after each session.",
                idx + 1,
                session_count
            ),
            coaching_notes: vec![
                "T1: heavy, low reps — treat every rep as a max-effort lift.".to_string(),
                "T1 last set (stages 1+2): AMRAP — push for max reps.".to_string(),
                "T2: moderate weight, controlled tempo — build volume.".to_string(),
                "T3: light accessories — metabolic stress. Add weight only at 25+ AMRAP reps.".to_string(),
            ],
        };

        ProposeResult {
            proposed_groups,
            regime_context,
            suggested_workout_name: {
                let sq_stage = stage_str_to_u8_t1(get_str_or(state, "squat_t1_stage", "stage_1_5x3"));
                let dl_stage = stage_str_to_u8_t1(get_str_or(state, "deadlift_t1_stage", "stage_1_5x3"));
                let (sq_sets, sq_reps) = t1_stage_prescription(sq_stage);
                let (dl_sets, dl_reps) = t1_stage_prescription(dl_stage);
                if sq_stage == dl_stage {
                    format!("GZCLP — T1 Stage {} ({}×{})", sq_stage, sq_sets, sq_reps)
                } else {
                    format!("GZCLP — SQ {}×{} / DL {}×{}", sq_sets, sq_reps, dl_sets, dl_reps)
                }
            },
        }
    }

    fn transition_state_on_workout_complete(
        &self,
        state: &StatePayload,
        result: &WorkoutCompletionResult,
        _ended_at: i64,
    ) -> StatePayload {
        let mut new_state = state.clone();

        // Collect success/failure per exercise and last-set AMRAP reps
        let mut ex_success: std::collections::HashMap<i32, bool> = std::collections::HashMap::new();
        let mut ex_last_amrap: std::collections::HashMap<i32, i32> = std::collections::HashMap::new();

        for sr in &result.set_results {
            let ex_key = sr.exercise as i32;
            let success = ex_success.entry(ex_key).or_insert(true);
            *success = *success && (sr.actual_reps >= sr.target_reps);
            // Track last set reps as potential AMRAP (will be overwritten until the actual last)
            ex_last_amrap.insert(ex_key, sr.actual_reps);
        }

        let variant = get_str_or(state, KEY_SCHEDULE, "four_day");

        // Update T1 lifts
        for ex in [Exercise::Squat, Exercise::Deadlift] {
            let Some(&success) = ex_success.get(&(ex as i32)) else { continue };
            let current_w = get_f32_or(state, t1_weight_key(ex), default_t1_weight(ex));
            let stage_str = get_str_or(state, t1_stage_key(ex), "stage_1_5x3");
            let stage = stage_str_to_u8_t1(stage_str);
            let inc = gzclp_t1_increment(ex);

            if success {
                // Success: increment weight, return to stage 1
                set_f32(&mut new_state, t1_weight_key(ex), current_w + inc);
                set_str(&mut new_state, t1_stage_key(ex), "stage_1_5x3");
            } else {
                // Failure: hold weight, advance stage (3→1 wraps)
                let new_stage = if stage >= 3 { 1 } else { stage + 1 };
                set_f32(&mut new_state, t1_weight_key(ex), current_w);
                set_str(&mut new_state, t1_stage_key(ex), stage_u8_to_str_t1(new_stage));
            }
        }

        // Update T2 lifts
        for ex in [Exercise::BenchPress, Exercise::OverheadPress, Exercise::BarbellRow] {
            let Some(&success) = ex_success.get(&(ex as i32)) else { continue };
            let current_w = get_f32_or(state, t2_weight_key(ex), default_t2_weight(ex));
            let stage_str = get_str_or(state, t2_stage_key(ex), "stage_1_3x10");
            let stage = stage_str_to_u8_t2(stage_str);
            let inc = 5.0f32;

            if success {
                set_f32(&mut new_state, t2_weight_key(ex), current_w + inc);
                set_str(&mut new_state, t2_stage_key(ex), "stage_1_3x10");
            } else {
                let new_stage = if stage >= 3 { 1 } else { stage + 1 };
                set_f32(&mut new_state, t2_weight_key(ex), current_w);
                set_str(&mut new_state, t2_stage_key(ex), stage_u8_to_str_t2(new_stage));
            }
        }

        // Update T3 lifts (increment if AMRAP last set >= 25 reps)
        for ex in [
            Exercise::HipThrust,
            Exercise::BulgarianSplitSquat,
            Exercise::RomanianDeadlift,
            Exercise::LegCurl,
            Exercise::GluteBridge,
            Exercise::Lunge,
        ] {
            let Some(&amrap_reps) = ex_last_amrap.get(&(ex as i32)) else { continue };
            let current_w = get_f32_or(state, t3_weight_key(ex), 45.0);
            if amrap_reps >= 25 {
                set_f32(&mut new_state, t3_weight_key(ex), current_w + 5.0);
            }
            // else hold weight
        }

        // Advance session index
        let count = session_count(variant);
        let idx = get_int_or(state, KEY_SESSION_IDX, 0);
        set_int(&mut new_state, KEY_SESSION_IDX, (idx + 1) % count);

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
                "It's been {} days since your last session. A deload is recommended.",
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
                    return Err("deload_percent must be 50–100".to_string());
                }
                let mut new_state = state.clone();
                for ex in [Exercise::Squat, Exercise::Deadlift] {
                    let w = get_f32_or(state, t1_weight_key(ex), default_t1_weight(ex));
                    set_f32(&mut new_state, t1_weight_key(ex), ((w * pct) / 5.0).round() * 5.0);
                }
                for ex in [Exercise::BenchPress, Exercise::OverheadPress, Exercise::BarbellRow] {
                    let w = get_f32_or(state, t2_weight_key(ex), default_t2_weight(ex));
                    set_f32(&mut new_state, t2_weight_key(ex), ((w * pct) / 5.0).round() * 5.0);
                }
                Ok(new_state)
            }
            _ => Err(format!("Unknown update_id: {}", update_id)),
        }
    }

    fn recovery_seconds_for_state(&self, _state: &StatePayload) -> i64 {
        48 * 3600
    }
}
