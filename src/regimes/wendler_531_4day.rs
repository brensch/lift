use std::collections::HashMap;

use lift::workout::v1::{
    Exercise, ExerciseStatus, ProposedExerciseGroup, RegimeContext, UserWorkoutConfig,
    WorkingSetSpec,
};
use serde::{Deserialize, Serialize};

use super::{
    cfg_field_exercise_weight, exercise_display_name, rest_cfg, ExerciseConfig, ExerciseProposal,
    ProgramAtAGlanceMeta, ProgramCatalogMeta, SessionHistory, WorkoutRegime,
};

// ─── Wendler state ─────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WendlerState {
    pub week: u8,   // 1-4 (1=volume, 2=intensity, 3=peak, 4=deload)
    pub cycle: u32, // starts at 1
    #[serde(default)]
    pub session_in_week: u8, // 0-based training day index within the week
}

impl Default for WendlerState {
    fn default() -> Self {
        Self {
            week: 1,
            cycle: 1,
            session_in_week: 0,
        }
    }
}

impl WendlerState {
    pub fn from_json(json: &str) -> Self {
        serde_json::from_str(json).unwrap_or_default()
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string(self)
            .unwrap_or_else(|_| r#"{"week":1,"cycle":1,"session_in_week":0}"#.to_string())
    }
}

// ─── Week definitions ─────────────────────────────────────────────────────────
//
// Each week: (start_pct, end_pct, reps, is_deload)
// The 3 working sets ramp linearly from start_pct*TM to end_pct*TM.
// e.g. Week 1: 65%/75%/85% TM, 5 reps → start=0.65, end=0.85
//
struct WeekDef {
    start_pct: f32,
    end_pct: f32,
    reps: i32,
    set_pcts: [f32; 3],
    set_reps: [i32; 3],
    top_set_amrap: bool,
    is_deload: bool,
    name: &'static str,
    preview: &'static str,
}

const WEEKS: [WeekDef; 4] = [
    WeekDef {
        start_pct: 0.65,
        end_pct: 0.85,
        reps: 5,
        set_pcts: [0.65, 0.75, 0.85],
        set_reps: [5, 5, 5],
        top_set_amrap: true,
        is_deload: false,
        name: "Week 1 — Volume (5-rep sets)",
        preview: "Next: Week 2 — Intensity (3-rep sets)",
    },
    WeekDef {
        start_pct: 0.70,
        end_pct: 0.90,
        reps: 3,
        set_pcts: [0.70, 0.80, 0.90],
        set_reps: [3, 3, 3],
        top_set_amrap: true,
        is_deload: false,
        name: "Week 2 — Intensity (3-rep sets)",
        preview: "Next: Week 3 — Peak (1-rep AMRAP)",
    },
    WeekDef {
        start_pct: 0.75,
        end_pct: 0.95,
        reps: 1,
        set_pcts: [0.75, 0.85, 0.95],
        set_reps: [5, 3, 1],
        top_set_amrap: true,
        is_deload: false,
        name: "Week 3 — Peak (1-rep AMRAP)",
        preview: "Next: Week 4 — Deload (light sets)",
    },
    WeekDef {
        start_pct: 0.40,
        end_pct: 0.60,
        reps: 5,
        set_pcts: [0.40, 0.50, 0.60],
        set_reps: [5, 5, 5],
        top_set_amrap: false,
        is_deload: true,
        name: "Week 4 — Deload (easy week)",
        preview: "Next: New cycle begins with higher Training Max",
    },
];

// Main lifts for Wendler
const WENDLER_LIFTS: &[Exercise] = &[
    Exercise::Squat,
    Exercise::BenchPress,
    Exercise::Deadlift,
    Exercise::OverheadPress,
];

fn classic_4day_lift_for_session(session_in_week: u8) -> Exercise {
    WENDLER_LIFTS[(session_in_week as usize) % WENDLER_LIFTS.len()]
}

fn is_lower_body(exercise: Exercise) -> bool {
    matches!(exercise, Exercise::Squat | Exercise::Deadlift)
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
                    format!("{}+ top set — AMRAP", reps)
                } else {
                    String::new()
                },
            }
        })
        .collect()
}

fn wendler_set_pattern_text(week_def: &WeekDef) -> String {
    week_def
        .set_reps
        .iter()
        .enumerate()
        .map(|(idx, reps)| {
            let plus = if idx == 2 && week_def.top_set_amrap {
                "+"
            } else {
                ""
            };
            format!("{}{}", reps, plus)
        })
        .collect::<Vec<_>>()
        .join(" / ")
}

// ─── Regime impl ─────────────────────────────────────────────────────────────

pub struct Wendler5314DayRegime;

impl WorkoutRegime for Wendler5314DayRegime {
    fn display_name(&self) -> &'static str {
        "Wendler 5/3/1 (4-Day)"
    }

    fn default_days_per_week(&self) -> i32 {
        4
    }

    fn catalog_meta(&self) -> ProgramCatalogMeta {
        ProgramCatalogMeta {
            headline: "Classic 4-day Wendler split",
            summary: "One main lift per session with 4-week 5/3/1 percentage waves and cycle-based TM increases.",
            description: "Classic Wendler structure split across four days: squat, bench, deadlift, and overhead press each get their own session.",
            how_it_works: "Train off a Training Max (90% of your estimated 1RM).\nWeek 1: 5s, Week 2: 3s, Week 3: 5/3/1, Week 4: deload.\nTop set is AMRAP except deload week.",
            at_a_glance: ProgramAtAGlanceMeta {
                days_per_week: "4",
                best_for: "Intermediate+",
                average_session_time: "45-75 min",
                progression_style: "Percentage periodization",
            },
            details: vec![
                "Training Max starts at 90% of 1RM.",
                "Upper-body TM increases +5 lbs per cycle.",
                "Lower-body TM increases +10 lbs per cycle.",
            ],
            learn_more_links: vec![
                ("The Fitness Wiki: 5/3/1 Primer", "https://thefitness.wiki/5-3-1-primer/"),
                ("Jim Wendler beginner article", "https://www.jimwendler.com/blogs/jimwendler-com/101065094-5-3-1-for-a-beginner"),
            ],
            config_fields: vec![
                cfg_field_exercise_weight("squat_1rm", "Squat 1RM", "Estimated 1RM (lbs).", 1, 225.0),
                cfg_field_exercise_weight("bench_press_1rm", "Bench Press 1RM", "Estimated 1RM (lbs).", 2, 185.0),
                cfg_field_exercise_weight("deadlift_1rm", "Deadlift 1RM", "Estimated 1RM (lbs).", 3, 315.0),
                cfg_field_exercise_weight("overhead_press_1rm", "Overhead Press 1RM", "Estimated 1RM (lbs).", 4, 115.0),
            ],
            sort_order: 30,
        }
    }

    fn recovery_seconds(&self, workout_config: &UserWorkoutConfig) -> i64 {
        let state = WendlerState::from_json(&workout_config.regime_state_json);
        // Deload week is lighter, allow 24h recovery; peak week needs 72h
        match state.week {
            4 => 24 * 3600,
            3 => 72 * 3600,
            _ => 48 * 3600,
        }
    }

    fn calculate_exercise_progression(
        &self,
        exercise: Exercise,
        config: &ExerciseConfig,
        _history: &[SessionHistory],
        _max_weight: f32,
        workout_config: &UserWorkoutConfig,
        _now_ts: i64,
    ) -> ExerciseProposal {
        let state = WendlerState::from_json(&workout_config.regime_state_json);
        let week = state.week.saturating_sub(1) as usize;
        let week_def = &WEEKS[week.min(3)];

        // Training max = 90% of 1RM
        let orm = workout_config
            .one_rep_maxes
            .get(&(exercise as i32))
            .copied()
            .unwrap_or(0.0);

        if orm <= 0.0 {
            return ExerciseProposal {
                weight: config.default_weight,
                sets: 3,
                reps: week_def.reps,
                explanation: format!(
                    "No 1RM set for {}. Go to Settings → Training Program to enter your max.",
                    exercise_display_name(exercise)
                ),
            };
        }

        let tm = orm * 0.9;

        // Round to nearest 5 lbs, apply cycle TM increments
        // After each 4-week cycle: upper +5 lbs, lower +10 lbs
        let cycle_bonus = if is_lower_body(exercise) {
            (state.cycle.saturating_sub(1) as f32) * 10.0
        } else {
            (state.cycle.saturating_sub(1) as f32) * 5.0
        };

        let start_w = (tm * week_def.start_pct / 5.0).round() * 5.0 + cycle_bonus;
        let weeks_remaining_after_this = 4_i32.saturating_sub(state.week as i32);
        let pattern = wendler_set_pattern_text(week_def);
        let phase_timing = if state.week < 4 {
            format!(
                "{} week{} until next phase ({}).",
                1,
                "",
                WEEKS[state.week as usize].name
            )
        } else {
            "1 week until next cycle (Week 1 restarts with a higher Training Max)."
                .to_string()
        };

        ExerciseProposal {
            weight: start_w, // start_weight; end_weight is set separately in the group builder
            sets: 3,
            reps: week_def.reps,
            explanation: format!(
                "5/3/1 Cycle {}, Week {}/4 ({} week{} left in cycle after this). {} Pattern: {}. TM: {} lbs (from {} lbs 1RM). First set: {} lbs.",
                state.cycle,
                state.week,
                weeks_remaining_after_this,
                if weeks_remaining_after_this == 1 { "" } else { "s" },
                phase_timing,
                pattern,
                (tm + cycle_bonus).round() as i32,
                orm as i32,
                start_w as i32,
            ),
        }
    }

    fn build_proposed_groups(
        &self,
        statuses: &[ExerciseStatus],
        workout_config: &UserWorkoutConfig,
    ) -> Vec<ProposedExerciseGroup> {
        let state = WendlerState::from_json(&workout_config.regime_state_json);
        let week = state.week.saturating_sub(1) as usize;
        let week_def = &WEEKS[week.min(3)];

        let mut groups = Vec::new();
        let main_lifts: Vec<Exercise> = vec![classic_4day_lift_for_session(state.session_in_week)];

        for &exercise in &main_lifts {
            let Some(status) = statuses.iter().find(|s| s.exercise == exercise as i32) else {
                continue;
            };

            let orm = workout_config
                .one_rep_maxes
                .get(&(exercise as i32))
                .copied()
                .unwrap_or(0.0);

            if orm <= 0.0 {
                // Show with placeholder — user needs to configure 1RM
                let config = lift::workout::v1::ExerciseTypeConfig {
                    exercise: exercise as i32,
                    start_weight: status.target_weight,
                    end_weight: status.target_weight,
                    reps: week_def.reps,
                    include_warmup: true,
                    rest_config: None,
                    last_set_amrap: false,
                    working_sets: vec![],
                };
                groups.push(ProposedExerciseGroup {
                    name: exercise_display_name(exercise),
                    sets: 3,
                    interleave_warmups: false,
                    exercise_configs: vec![config],
                    rest_config: None,
                    tags: vec!["recommended".to_string()],
                    explanation: format!(
                        "Set your 1RM in Settings → Training Program to unlock Wendler percentages."
                    ),
                    prescribed_by_regime: false,
                });
                continue;
            }

            let tm = orm * 0.9;
            let cycle_bonus = if is_lower_body(exercise) {
                (state.cycle.saturating_sub(1) as f32) * 10.0
            } else {
                (state.cycle.saturating_sub(1) as f32) * 5.0
            };
            let tm = tm + cycle_bonus;

            let working_sets = build_wendler_working_sets(tm, week_def);
            let start_w = working_sets
                .first()
                .map(|s| s.target_weight)
                .unwrap_or((tm * week_def.start_pct / 5.0).round() * 5.0);
            let end_w = working_sets
                .last()
                .map(|s| s.target_weight)
                .unwrap_or((tm * week_def.end_pct / 5.0).round() * 5.0);
            let first_reps = working_sets
                .first()
                .map(|s| s.target_reps)
                .unwrap_or(week_def.reps);
            let last_set_amrap = week_def.top_set_amrap;

            let config = lift::workout::v1::ExerciseTypeConfig {
                exercise: exercise as i32,
                start_weight: start_w,
                end_weight: end_w,
                reps: first_reps,
                include_warmup: true,
                rest_config: None,
                last_set_amrap,
                working_sets,
            };

            // Deload week: lighter rest; peak/volume: full rest
            let group_rest = if week_def.is_deload {
                rest_cfg(90, 90)
            } else {
                rest_cfg(180, 300)
            };

                groups.push(ProposedExerciseGroup {
                    name: exercise_display_name(exercise),
                sets: 3,
                interleave_warmups: false,
                exercise_configs: vec![config],
                rest_config: group_rest,
                    tags: vec!["recommended".to_string()],
                explanation: status.explanation.clone(),
                prescribed_by_regime: false,
            });
        }

        // Accessory work for Wendler — light, tagged "auxiliary"
        let aux_pairs: &[(Exercise, Exercise)] = &[
            (Exercise::HipThrust, Exercise::BulgarianSplitSquat),
            (Exercise::RomanianDeadlift, Exercise::LegCurl),
            (Exercise::GluteBridge, Exercise::Lunge),
        ];
        for &(ex_a, ex_b) in aux_pairs {
            let a = statuses.iter().find(|s| s.exercise == ex_a as i32);
            let b = statuses.iter().find(|s| s.exercise == ex_b as i32);
            if let (Some(a), Some(b)) = (a, b) {
                let ca = lift::workout::v1::ExerciseTypeConfig {
                    exercise: ex_a as i32,
                    start_weight: a.target_weight,
                    end_weight: a.target_weight,
                    reps: 10,
                    include_warmup: true,
                    rest_config: None,
                    last_set_amrap: false,
                    working_sets: vec![],
                };
                let cb = lift::workout::v1::ExerciseTypeConfig {
                    exercise: ex_b as i32,
                    start_weight: b.target_weight,
                    end_weight: b.target_weight,
                    reps: 10,
                    include_warmup: false,
                    rest_config: None,
                    last_set_amrap: false,
                    working_sets: vec![],
                };
                groups.push(ProposedExerciseGroup {
                    name: format!(
                        "{} + {}",
                        exercise_display_name(ex_a),
                        exercise_display_name(ex_b)
                    ),
                    sets: 5,
                    interleave_warmups: true,
                    exercise_configs: vec![ca, cb],
                    rest_config: rest_cfg(90, 90),
                    tags: vec!["auxiliary".to_string()],
                    explanation: format!("Accessory work. {}", b.explanation),
                    prescribed_by_regime: false,
                });
            }
        }

        groups
    }

    fn compute_updated_state(
        &self,
        _workout_config: &UserWorkoutConfig,
        history: &HashMap<i32, Vec<SessionHistory>>,
    ) -> String {
        // Classic 4-day 5/3/1 trains one main lift per session.
        let total_sessions: usize = WENDLER_LIFTS
            .iter()
            .map(|&ex| history.get(&(ex as i32)).map(|h| h.len()).unwrap_or(0))
            .sum();

        let sessions_per_week = 4;
        let sessions_per_cycle = sessions_per_week * 4;
        let session_in_cycle = total_sessions % sessions_per_cycle;
        let cycle = (total_sessions / sessions_per_cycle) as u32 + 1;
        let week = (session_in_cycle / sessions_per_week) as u8 + 1;
        let session_in_week = (session_in_cycle % sessions_per_week) as u8;

        let new_state = WendlerState {
            week: week.clamp(1, 4),
            cycle,
            session_in_week,
        };

        new_state.to_json()
    }

    fn build_regime_context(
        &self,
        workout_config: &UserWorkoutConfig,
        _statuses: &[ExerciseStatus],
    ) -> RegimeContext {
        let state = WendlerState::from_json(&workout_config.regime_state_json);
        let week = state.week.saturating_sub(1) as usize;
        let week_def = &WEEKS[week.min(3)];

        let coaching_notes = if week_def.is_deload {
            vec![
                "This is your deload week — intentionally light.".to_string(),
                "Focus on technique and recovery. Don't push for extra reps.".to_string(),
                "Your Training Max increases next cycle.".to_string(),
            ]
        } else if state.week == 3 {
            vec![
                "Peak week — push hard on the AMRAP set (last set = max reps).".to_string(),
                "How many reps you get predicts your next Training Max bump.".to_string(),
                "Warm up thoroughly before heavy singles.".to_string(),
            ]
        } else {
            vec![
                "Log all reps — the system tracks your progression automatically.".to_string(),
                "Last set can be pushed for extra reps to gauge strength.".to_string(),
            ]
        };

        let ex = classic_4day_lift_for_session(state.session_in_week);
        let day_suffix = format!(" — {}", exercise_display_name(ex));

        RegimeContext {
            regime_display_name: format!("Wendler 5/3/1 — Cycle {}{}", state.cycle, day_suffix),
            session_description: week_def.name.to_string(),
            next_session_preview: week_def.preview.to_string(),
            coaching_notes,
        }
    }

    fn suggested_workout_name(&self, workout_config: &UserWorkoutConfig) -> String {
        let state = WendlerState::from_json(&workout_config.regime_state_json);
        let week = state.week.saturating_sub(1) as usize;
        let week_def = &WEEKS[week.min(3)];
        let ex = classic_4day_lift_for_session(state.session_in_week);
        format!(
            "5/3/1 — Cycle {}, {}, {}",
            state.cycle,
            week_def.name,
            exercise_display_name(ex)
        )
    }
}

#[cfg(test)]
#[path = "wendler_531_4day_tests.rs"]
mod wendler_531_4day_tests;
