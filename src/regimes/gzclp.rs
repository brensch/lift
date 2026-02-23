use std::collections::HashMap;

use lift::workout::v1::{
    Exercise, ExerciseStatus, ProposedExerciseGroup, RegimeContext, UserWorkoutConfig,
    WorkingSetSpec,
};
use serde::{Deserialize, Serialize};

use super::{
    exercise_display_name, rest_cfg, ExerciseConfig, ExerciseProposal, SessionHistory,
    WorkoutRegime,
};

// ─── GZCLP tier assignments ───────────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum GzclTier {
    T1, // Heavy compounds: 5×3 → 6×2 → 10×1 state machine
    T2, // Supplemental:    3×10 → 3×8 → 3×6 state machine
    T3, // Accessories:     3×15 (simple linear)
}

fn exercise_tier(exercise: Exercise) -> GzclTier {
    match exercise {
        Exercise::Squat | Exercise::Deadlift => GzclTier::T1,
        Exercise::BenchPress | Exercise::OverheadPress | Exercise::BarbellRow => GzclTier::T2,
        _ => GzclTier::T3,
    }
}

fn t1_stage_prescription(stage: u8) -> (i32, i32) {
    // (sets, reps)
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

fn repeated_working_sets(
    sets: i32,
    reps: i32,
    weight: f32,
    last_set_amrap: bool,
) -> Vec<WorkingSetSpec> {
    (0..sets.max(1))
        .map(|idx| {
            let is_last = idx == sets.max(1) - 1;
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
            }
        })
        .collect()
}

// ─── State ────────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct GzclpState {
    /// exercise (as int32) → current stage (1/2/3)
    #[serde(default)]
    pub stages: HashMap<i32, u8>,
    /// exercise (as int32) → latest completed session timestamp already applied
    /// to the stage machine. Prevents plan refresh from re-applying the same
    /// success/failure result over and over.
    #[serde(default)]
    pub last_applied_session_ts: HashMap<i32, i64>,
}

impl GzclpState {
    pub fn stage_for(&self, exercise: Exercise) -> u8 {
        *self.stages.get(&(exercise as i32)).unwrap_or(&1)
    }

    pub fn set_stage(&mut self, exercise: Exercise, stage: u8) {
        self.stages.insert(exercise as i32, stage.clamp(1, 3));
    }

    pub fn last_applied_ts_for(&self, exercise: Exercise) -> i64 {
        *self
            .last_applied_session_ts
            .get(&(exercise as i32))
            .unwrap_or(&0)
    }

    pub fn set_last_applied_ts(&mut self, exercise: Exercise, ts: i64) {
        self.last_applied_session_ts.insert(exercise as i32, ts);
    }

    pub fn from_json(json: &str) -> Self {
        serde_json::from_str(json).unwrap_or_default()
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string(self).unwrap_or_else(|_| "{}".to_string())
    }
}

// ─── GZCLP increment ─────────────────────────────────────────────────────────

fn gzclp_increment(exercise: Exercise) -> f32 {
    match exercise {
        Exercise::Squat | Exercise::Deadlift => 10.0,
        _ => 5.0,
    }
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

    fn recovery_seconds(&self, _workout_config: &UserWorkoutConfig) -> i64 {
        48 * 3600
    }

    fn calculate_exercise_progression(
        &self,
        exercise: Exercise,
        config: &ExerciseConfig,
        history: &[SessionHistory],
        max_weight: f32,
        workout_config: &UserWorkoutConfig,
        _now_ts: i64,
    ) -> ExerciseProposal {
        let state = GzclpState::from_json(&workout_config.regime_state_json);
        let current_stage = state.stage_for(exercise);
        let tier = exercise_tier(exercise);
        let inc = gzclp_increment(exercise);

        match tier {
            GzclTier::T1 => {
                let (sets, reps) = t1_stage_prescription(current_stage);
                let (weight, explanation) = t1_weight(
                    exercise,
                    config.default_weight,
                    history,
                    max_weight,
                    current_stage,
                    inc,
                );
                ExerciseProposal {
                    weight,
                    sets,
                    reps,
                    explanation,
                }
            }
            GzclTier::T2 => {
                let (sets, reps) = t2_stage_prescription(current_stage);
                let (weight, explanation) = t2_weight(
                    exercise,
                    config.default_weight,
                    history,
                    max_weight,
                    current_stage,
                    inc,
                );
                ExerciseProposal {
                    weight,
                    sets,
                    reps,
                    explanation,
                }
            }
            GzclTier::T3 => {
                // T3: simple linear progression, 3×15
                let (weight, explanation) = t3_weight(config.default_weight, history);
                ExerciseProposal {
                    weight,
                    sets: 3,
                    reps: 15,
                    explanation,
                }
            }
        }
    }

    fn build_proposed_groups(
        &self,
        statuses: &[ExerciseStatus],
        workout_config: &UserWorkoutConfig,
    ) -> Vec<ProposedExerciseGroup> {
        let state = GzclpState::from_json(&workout_config.regime_state_json);
        build_gzclp_proposed_groups(statuses, &state)
    }

    fn compute_updated_state(
        &self,
        workout_config: &UserWorkoutConfig,
        history: &HashMap<i32, Vec<SessionHistory>>,
    ) -> String {
        let mut state = GzclpState::from_json(&workout_config.regime_state_json);

        for ex_int in [
            Exercise::Squat,
            Exercise::Deadlift,
            Exercise::BenchPress,
            Exercise::OverheadPress,
            Exercise::BarbellRow,
        ] {
            let ex_history = history.get(&(ex_int as i32));
            let Some(hist) = ex_history else { continue };
            if hist.is_empty() {
                continue;
            }

            let current_stage = state.stage_for(ex_int);
            let latest = &hist[0];
            let latest_ts = latest.timestamp;
            if latest_ts <= state.last_applied_ts_for(ex_int) {
                continue;
            }
            let last_success = latest.success;
            let tier = exercise_tier(ex_int);

            let new_stage = match tier {
                GzclTier::T1 => {
                    if last_success {
                        // Success: stay at stage 1 (or return from 2/3 to 1)
                        1
                    } else {
                        // Failure: advance or reset
                        if current_stage >= 3 {
                            1
                        } else {
                            current_stage + 1
                        }
                    }
                }
                GzclTier::T2 => {
                    if last_success {
                        1
                    } else {
                        if current_stage >= 3 {
                            1
                        } else {
                            current_stage + 1
                        }
                    }
                }
                GzclTier::T3 => 1, // T3 has no stage machine
            };
            state.set_stage(ex_int, new_stage);
            state.set_last_applied_ts(ex_int, latest_ts);
        }

        state.to_json()
    }

    fn build_regime_context(
        &self,
        workout_config: &UserWorkoutConfig,
        statuses: &[ExerciseStatus],
    ) -> RegimeContext {
        let state = GzclpState::from_json(&workout_config.regime_state_json);

        let t1_desc: Vec<String> = [Exercise::Squat, Exercise::Deadlift]
            .iter()
            .filter_map(|&ex| {
                statuses.iter().find(|s| s.exercise == ex as i32).map(|_| {
                    let stage = state.stage_for(ex);
                    let (sets, reps) = t1_stage_prescription(stage);
                    format!(
                        "T1 {}: Stage {} ({}×{})",
                        exercise_display_name(ex),
                        stage,
                        sets,
                        reps
                    )
                })
            })
            .collect();

        let t2_desc: Vec<String> = [
            Exercise::BenchPress,
            Exercise::OverheadPress,
            Exercise::BarbellRow,
        ]
        .iter()
        .filter_map(|&ex| {
            statuses.iter().find(|s| s.exercise == ex as i32).map(|_| {
                let stage = state.stage_for(ex);
                let (sets, reps) = t2_stage_prescription(stage);
                format!(
                    "T2 {}: Stage {} ({}×{})",
                    exercise_display_name(ex),
                    stage,
                    sets,
                    reps
                )
            })
        })
        .collect();

        let all_desc = [t1_desc, t2_desc].concat().join(" · ");

        RegimeContext {
            regime_display_name: "GZCLP".to_string(),
            session_description: if all_desc.is_empty() {
                "GZCLP — T1/T2/T3 tier system".to_string()
            } else {
                all_desc
            },
            next_session_preview:
                "State machine updates after each session based on success/failure.".to_string(),
            coaching_notes: vec![
                "T1: heavy, low reps — treat every rep as a max-effort lift.".to_string(),
                "T1/T3 last set: AMRAP — push for max reps to drive faster progression."
                    .to_string(),
                "T2: moderate weight, controlled tempo — build volume.".to_string(),
                "T3: light accessories — metabolic stress and recovery work.".to_string(),
            ],
        }
    }

    fn suggested_workout_name(&self, workout_config: &UserWorkoutConfig) -> String {
        let state = GzclpState::from_json(&workout_config.regime_state_json);
        // Describe current T1 stage to give context
        let squat_stage = state.stage_for(Exercise::Squat);
        let dl_stage = state.stage_for(Exercise::Deadlift);
        let (sq_sets, sq_reps) = t1_stage_prescription(squat_stage);
        let (dl_sets, dl_reps) = t1_stage_prescription(dl_stage);
        if squat_stage == dl_stage {
            format!("GZCLP — T1 Stage {} ({}×{})", squat_stage, sq_sets, sq_reps)
        } else {
            format!(
                "GZCLP — Squat {}×{} / DL {}×{}",
                sq_sets, sq_reps, dl_sets, dl_reps
            )
        }
    }
}

// ─── Weight calculation helpers ───────────────────────────────────────────────

fn t1_weight(
    _exercise: Exercise,
    default_weight: f32,
    history: &[SessionHistory],
    _max_weight: f32,
    stage: u8,
    inc: f32,
) -> (f32, String) {
    if history.is_empty() {
        return (
            default_weight,
            format!(
                "GZCLP T1 {}. Start at {} lbs. Stay in this phase until a failed session, then the next workout moves to the next phase.",
                t1_phase_text(stage),
                default_weight
            ),
        );
    }
    let h = &history[0];
    if h.success {
        let new_w = h.weight + inc;
        (
            new_w,
            format!(
                "GZCLP T1 {}. Successful session, so increase {} → {} lbs. Phase timing: stay here until you fail a session.",
                t1_phase_text(stage),
                h.weight,
                new_w
            ),
        )
    } else {
        // Failure — hold weight (stage change handled in compute_updated_state).
        // `stage` here is the *next* stage after applying the failure, so derive the
        // failed phase for the explanation from the transition.
        let failed_stage = if stage <= 1 { 3 } else { stage - 1 };
        let stage_label = match failed_stage {
            1 => "5×3",
            2 => "6×2",
            _ => "10×1",
        };
        (
            h.weight,
            format!(
                "GZCLP T1: Last session failed in Phase {} ({}) at {} lbs. Hold {} lbs. Next workout is {}.",
                failed_stage,
                stage_label,
                h.weight,
                h.weight,
                t1_phase_text(stage)
            ),
        )
    }
}

fn t2_weight(
    _exercise: Exercise,
    default_weight: f32,
    history: &[SessionHistory],
    _max_weight: f32,
    stage: u8,
    inc: f32,
) -> (f32, String) {
    if history.is_empty() {
        return (
            default_weight,
            format!(
                "GZCLP T2 {}. Start at {} lbs. Stay in this phase until a failed session, then the next workout moves to the next phase.",
                t2_phase_text(stage),
                default_weight
            ),
        );
    }
    let h = &history[0];
    if h.success {
        let new_w = h.weight + inc;
        (
            new_w,
            format!(
                "GZCLP T2 {}. Successful session, so increase {} → {} lbs. Phase timing: stay here until you fail a session.",
                t2_phase_text(stage),
                h.weight,
                new_w
            ),
        )
    } else {
        let failed_stage = if stage <= 1 { 3 } else { stage - 1 };
        let stage_label = match failed_stage {
            1 => "3×10",
            2 => "3×8",
            _ => "3×6",
        };
        (
            h.weight,
            format!(
                "GZCLP T2: Last session failed in Phase {} ({}) at {} lbs. Hold {} lbs. Next workout is {}.",
                failed_stage,
                stage_label,
                h.weight,
                h.weight,
                t2_phase_text(stage)
            ),
        )
    }
}

/// T3 (hypertrophy): weight increases ONLY when the AMRAP last set hits ≥ 25 reps.
/// Standard completion of 3×15 is NOT sufficient for progression.
fn t3_weight(default_weight: f32, history: &[SessionHistory]) -> (f32, String) {
    if history.is_empty() {
        return (
            default_weight,
            format!(
                "GZCLP T3 (accessory): Start at {} lbs. Do 3×15, then push the last set AMRAP. You only add weight when that last set reaches 25+ reps.",
                default_weight
            ),
        );
    }
    let h = &history[0];
    if h.last_set_reps >= 25 {
        let new_w = h.weight + 5.0;
        (
            new_w,
            format!(
                "GZCLP T3: last set AMRAP hit {} reps (25+ target), so add weight: {} → {} lbs. Keep building reps at the new weight.",
                h.last_set_reps, h.weight, new_w
            ),
        )
    } else if h.last_set_reps > 0 {
        (
            h.weight,
            format!(
                "GZCLP T3: last set AMRAP hit {} reps (need 25+). Hold {} lbs and try to build reps next session. Target 25+ on the last set.",
                h.last_set_reps, h.weight
            ),
        )
    } else {
        (
            h.weight,
            format!(
                "GZCLP T3: Hold {} lbs. Progress is based on the last-set AMRAP hitting 25+ reps. Repeat the same T3 prescription.",
                h.weight
            ),
        )
    }
}

// ─── Proposed groups ─────────────────────────────────────────────────────────

fn build_gzclp_proposed_groups(
    statuses: &[ExerciseStatus],
    state: &GzclpState,
) -> Vec<ProposedExerciseGroup> {
    let mut groups = Vec::new();

    let find = |ex: Exercise| statuses.iter().find(|s| s.exercise == ex as i32);

    // T1 exercises — always recommended. Last set is AMRAP in Stage 1.
    for ex in [Exercise::Squat, Exercise::Deadlift] {
        if let Some(s) = find(ex) {
            let stage = state.stage_for(ex);
            let (sets, reps) = t1_stage_prescription(stage);
            // T1 Stage 1 (5×3) and Stage 2 (6×2): last set is AMRAP per GZCLP spec.
            // Stage 3 (10×1) does not use AMRAP on the single-rep sets.
            let last_set_amrap = stage <= 2;
            let config = lift::workout::v1::ExerciseTypeConfig {
                exercise: ex as i32,
                start_weight: s.target_weight,
                end_weight: s.target_weight,
                reps,
                include_warmup: true,
                rest_config: None,
                last_set_amrap,
                working_sets: repeated_working_sets(sets, reps, s.target_weight, last_set_amrap),
            };
            groups.push(ProposedExerciseGroup {
                name: exercise_display_name(ex),
                sets,
                interleave_warmups: false,
                exercise_configs: vec![config],
                rest_config: rest_cfg(180, 300),
                tags: vec!["recommended".to_string(), "T1".to_string()],
                explanation: s.explanation.clone(),
                prescribed_by_regime: false,
            });
        }
    }

    // T2 exercises — rotate: 2 stalest are recommended
    let mut t2: Vec<(Exercise, &ExerciseStatus)> = [
        Exercise::BenchPress,
        Exercise::OverheadPress,
        Exercise::BarbellRow,
    ]
    .iter()
    .filter_map(|&ex| find(ex).map(|s| (ex, s)))
    .collect();
    t2.sort_by(|(ax, a), (bx, b)| {
        a.last_performed_at
            .cmp(&b.last_performed_at)
            .then((*ax as i32).cmp(&(*bx as i32)))
    });

    for (idx, (ex, s)) in t2.iter().enumerate() {
        let stage = state.stage_for(*ex);
        let (sets, reps) = t2_stage_prescription(stage);
        let config = lift::workout::v1::ExerciseTypeConfig {
            exercise: *ex as i32,
            start_weight: s.target_weight,
            end_weight: s.target_weight,
            reps,
            include_warmup: true,
            rest_config: None,
            last_set_amrap: false,
            working_sets: repeated_working_sets(sets, reps, s.target_weight, false),
        };
        let tags = if idx < 2 {
            vec!["recommended".to_string(), "T2".to_string()]
        } else {
            vec!["T2".to_string()]
        };
        groups.push(ProposedExerciseGroup {
            name: exercise_display_name(*ex),
            sets,
            interleave_warmups: false,
            exercise_configs: vec![config],
            rest_config: rest_cfg(90, 120),
            tags,
            explanation: s.explanation.clone(),
            prescribed_by_regime: false,
        });
    }

    // T3 accessories — paired
    let aux_pairs: &[(Exercise, Exercise)] = &[
        (Exercise::HipThrust, Exercise::BulgarianSplitSquat),
        (Exercise::RomanianDeadlift, Exercise::LegCurl),
        (Exercise::GluteBridge, Exercise::Lunge),
    ];
    for &(ex_a, ex_b) in aux_pairs {
        match (find(ex_a), find(ex_b)) {
            (Some(a), Some(b)) => {
                // T3: last set is AMRAP — 25+ reps triggers weight increase
                let ca = lift::workout::v1::ExerciseTypeConfig {
                    exercise: ex_a as i32,
                    start_weight: a.target_weight,
                    end_weight: a.target_weight,
                    reps: 15,
                    include_warmup: true,
                    rest_config: None,
                    last_set_amrap: true,
                    working_sets: repeated_working_sets(3, 15, a.target_weight, true),
                };
                let cb = lift::workout::v1::ExerciseTypeConfig {
                    exercise: ex_b as i32,
                    start_weight: b.target_weight,
                    end_weight: b.target_weight,
                    reps: 15,
                    include_warmup: false,
                    rest_config: None,
                    last_set_amrap: true,
                    working_sets: repeated_working_sets(3, 15, b.target_weight, true),
                };
                groups.push(ProposedExerciseGroup {
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
                    explanation: format!("{} {}", a.explanation, b.explanation),
                    prescribed_by_regime: false,
                });
            }
            _ => {}
        }
    }

    groups
}

#[cfg(test)]
#[path = "gzclp_tests.rs"]
mod tests;
