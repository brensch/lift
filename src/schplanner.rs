use std::collections::HashMap;

use schlift::workout::v1::{
    CompletedSet, Exercise, ExerciseGroup, ProgressionHint, ProgressionRule, ProposedExerciseGroup,
    ProposedSet, Workout,
};

use crate::program_state::StatePayload;
use crate::regimes::WorkoutRegime;

#[allow(dead_code)]
#[derive(Clone, Debug)]
pub struct SchplannerWorkoutRecord {
    pub workout: Workout,
    pub exercise_groups: Vec<ExerciseGroup>,
    pub proposed_sets: Vec<ProposedSet>,
    pub completed_sets: Vec<CompletedSet>,
}

#[allow(dead_code)]
#[derive(Clone, Debug)]
pub struct SchplannerSlotOutcome {
    pub slot_key: String,
    pub exercise: Exercise,
    pub tier: String,
    pub rule: ProgressionRule,
    pub planned_sets: usize,
    pub completed_sets: usize,
    pub successful_sets: usize,
    pub top_set_target_reps: i32,
    pub top_set_actual_reps: i32,
    pub amrap_success_threshold: i32,
    pub workout_ended: bool,
}

impl SchplannerSlotOutcome {
    pub fn all_sets_hit_target(&self) -> bool {
        self.planned_sets > 0
            && self.completed_sets == self.planned_sets
            && self.successful_sets == self.planned_sets
    }

    pub fn top_set_hit_threshold(&self) -> bool {
        self.top_set_actual_reps > 0 && self.top_set_actual_reps >= self.amrap_threshold()
    }

    pub fn amrap_threshold(&self) -> i32 {
        self.amrap_success_threshold.max(self.top_set_target_reps)
    }
}

#[derive(Clone, Debug, Default)]
pub struct SchplannerDerivation {
    pub effective_state: StatePayload,
    pub slot_reasons: HashMap<String, String>,
    pub started_workout_count: usize,
    pub last_session_at: i64,
}

pub fn derive_state(
    regime: &dyn WorkoutRegime,
    base_state: &StatePayload,
    history: &[SchplannerWorkoutRecord],
) -> SchplannerDerivation {
    let mut effective_state = base_state.clone();
    let mut slot_reasons = HashMap::new();
    let mut started_workout_count = 0usize;
    let mut last_session_at = 0i64;

    let mut history_sorted = history.to_vec();
    history_sorted.sort_by(|a, b| {
        a.workout
            .start_time
            .cmp(&b.workout.start_time)
            .then_with(|| a.workout.id.cmp(&b.workout.id))
    });

    for workout in &history_sorted {
        started_workout_count += 1;
        last_session_at = last_session_at.max(if workout.workout.end_time > 0 {
            workout.workout.end_time
        } else {
            workout.workout.start_time
        });

        regime.schplanner_transition_on_workout_started(&mut effective_state, workout);

        let slot_outcomes = summarize_slot_outcomes(workout);
        regime.schplanner_apply_logged_results(
            &mut effective_state,
            workout,
            &slot_outcomes,
            &mut slot_reasons,
        );
    }

    SchplannerDerivation {
        effective_state,
        slot_reasons,
        started_workout_count,
        last_session_at,
    }
}

pub fn decorate_proposed_groups(
    regime: &dyn WorkoutRegime,
    groups: &mut [ProposedExerciseGroup],
    effective_state: &StatePayload,
    slot_reasons: &HashMap<String, String>,
    started_workout_count: usize,
) {
    for group in groups {
        regime.schplanner_decorate_proposed_group(
            group,
            effective_state,
            slot_reasons,
            started_workout_count,
        );
    }
}

pub fn group_slot_keys(group: &ProposedExerciseGroup) -> Vec<String> {
    let mut out = Vec::new();
    for config in &group.exercise_configs {
        let hinted = config.working_sets.iter().find_map(|set| {
            set.progression_hint
                .as_ref()
                .map(|hint| hint.slot_key.clone())
        });
        if let Some(key) = hinted {
            if !out.contains(&key) {
                out.push(key);
            }
            continue;
        }
        let key = Exercise::try_from(config.exercise)
            .unwrap_or(Exercise::Unspecified)
            .as_str_name()
            .to_ascii_lowercase();
        if !out.contains(&key) {
            out.push(key);
        }
    }
    out
}

fn summarize_slot_outcomes(
    workout: &SchplannerWorkoutRecord,
) -> HashMap<String, SchplannerSlotOutcome> {
    let completed_by_proposed = workout
        .completed_sets
        .iter()
        .filter(|set| set.ended_at > 0)
        .map(|set| (set.proposed_set_id.as_str(), set))
        .collect::<HashMap<_, _>>();

    let mut hinted_sets = HashMap::<String, Vec<(&ProposedSet, &ProgressionHint)>>::new();
    for set in workout
        .proposed_sets
        .iter()
        .filter(|set| !set.warmup && !set.cancelled)
    {
        let Some(hint) = set.progression_hint.as_ref() else {
            continue;
        };
        if !hint.counts_toward_program {
            continue;
        }
        hinted_sets
            .entry(hint.slot_key.clone())
            .or_default()
            .push((set, hint));
    }

    let mut outcomes = HashMap::new();
    for (slot_key, mut planned) in hinted_sets {
        planned.sort_by_key(|(set, _)| set.workout_order);
        let first_hint = planned[0].1;
        let rule = ProgressionRule::try_from(first_hint.rule).unwrap_or(ProgressionRule::None);
        let exercise = planned[0].0.exercise();
        let mut successful_sets = 0usize;
        let mut completed_sets = 0usize;
        let mut top_set_target_reps = 0;
        let mut top_set_actual_reps = 0;
        let amrap_success_threshold = first_hint.amrap_success_threshold;

        for (idx, (set, _)) in planned.iter().enumerate() {
            if let Some(completed) = completed_by_proposed.get(set.id.as_str()) {
                completed_sets += 1;
                if completed.actual_reps >= set.target_reps {
                    successful_sets += 1;
                }
                if idx + 1 == planned.len() {
                    top_set_target_reps = set.target_reps;
                    top_set_actual_reps = completed.actual_reps;
                }
            } else if idx + 1 == planned.len() {
                top_set_target_reps = set.target_reps;
            }
        }

        outcomes.insert(
            slot_key.clone(),
            SchplannerSlotOutcome {
                slot_key,
                exercise,
                tier: first_hint.tier.clone(),
                rule,
                planned_sets: planned.len(),
                completed_sets,
                successful_sets,
                top_set_target_reps,
                top_set_actual_reps,
                amrap_success_threshold,
                workout_ended: workout.workout.end_time > 0,
            },
        );
    }

    outcomes
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::program_state::{get_f32_or, get_int_or, get_str_or};
    use crate::regimes::{get_regime, progression_hint_for_set};
    use schlift::workout::v1::{ExerciseTypeConfig, RegimeType, WorkingSetSpec};

    fn linear_workout(success: bool) -> SchplannerWorkoutRecord {
        let workout = Workout {
            id: "w1".to_string(),
            name: "5x5".to_string(),
            start_time: 100,
            end_time: 200,
            session_id: String::new(),
        };
        let group = ExerciseGroup {
            id: "g1".to_string(),
            workout_id: workout.id.clone(),
            name: "Squat".to_string(),
            sets: 5,
            interleave_warmups: false,
            workout_order: 0,
            exercise_configs: vec![ExerciseTypeConfig {
                exercise: Exercise::Squat as i32,
                start_weight: 135.0,
                end_weight: 135.0,
                reps: 5,
                include_warmup: false,
                rest_config: None,
                last_set_amrap: false,
                working_sets: (0..5)
                    .map(|_| WorkingSetSpec {
                        target_weight: 135.0,
                        target_reps: 5,
                        is_amrap: false,
                        instruction: String::new(),
                        progression_hint: Some(progression_hint_for_set(
                            Exercise::Squat,
                            "MAIN",
                            ProgressionRule::AllSetsMatchTarget,
                            0,
                            true,
                        )),
                    })
                    .collect(),
            }],
            rest_config: None,
            instruction: String::new(),
            prescribed_by_regime: true,
        };
        let proposed_sets = (0..5)
            .map(|idx| ProposedSet {
                id: format!("p{idx}"),
                workout_id: workout.id.clone(),
                workout_order: idx,
                exercise: Exercise::Squat as i32,
                target_reps: 5,
                target_weight: 135.0,
                warmup: false,
                exercise_group_id: group.id.clone(),
                rest_after_success: 180,
                rest_after_failure: 300,
                cancelled: false,
                is_amrap: false,
                instruction: String::new(),
                progression_hint: Some(progression_hint_for_set(
                    Exercise::Squat,
                    "MAIN",
                    ProgressionRule::AllSetsMatchTarget,
                    0,
                    true,
                )),
            })
            .collect::<Vec<_>>();
        let completed_sets = proposed_sets
            .iter()
            .map(|set| CompletedSet {
                id: format!("c{}", set.id),
                workout_id: workout.id.clone(),
                proposed_set_id: set.id.clone(),
                actual_reps: if success { 5 } else { 4 },
                actual_weight: 135.0,
                started_at: 120,
                ended_at: 150,
                rest_until: 0,
            })
            .collect::<Vec<_>>();

        SchplannerWorkoutRecord {
            workout,
            exercise_groups: vec![group],
            proposed_sets,
            completed_sets,
        }
    }

    fn single_group_workout(
        workout_id: &str,
        exercise: Exercise,
        tier: &str,
        rule: ProgressionRule,
        weight: f32,
        reps: i32,
        set_count: i32,
        actual_reps: Vec<i32>,
        ended: bool,
        amrap_threshold: i32,
    ) -> SchplannerWorkoutRecord {
        let workout = Workout {
            id: workout_id.to_string(),
            name: workout_id.to_string(),
            start_time: 100,
            end_time: if ended { 200 } else { 0 },
            session_id: String::new(),
        };
        let group = ExerciseGroup {
            id: format!("{workout_id}-g1"),
            workout_id: workout.id.clone(),
            name: exercise.as_str_name().to_string(),
            sets: set_count,
            interleave_warmups: false,
            workout_order: 0,
            exercise_configs: vec![],
            rest_config: None,
            instruction: String::new(),
            prescribed_by_regime: true,
        };
        let proposed_sets = (0..set_count)
            .map(|idx| ProposedSet {
                id: format!("{workout_id}-p{idx}"),
                workout_id: workout.id.clone(),
                workout_order: idx,
                exercise: exercise as i32,
                target_reps: reps,
                target_weight: weight,
                warmup: false,
                exercise_group_id: group.id.clone(),
                rest_after_success: 180,
                rest_after_failure: 300,
                cancelled: false,
                is_amrap: idx == set_count - 1 && rule == ProgressionRule::TopSetAmrap,
                instruction: String::new(),
                progression_hint: Some(progression_hint_for_set(
                    exercise,
                    tier,
                    rule,
                    amrap_threshold,
                    true,
                )),
            })
            .collect::<Vec<_>>();
        let completed_sets = actual_reps
            .into_iter()
            .enumerate()
            .map(|(idx, actual)| CompletedSet {
                id: format!("{workout_id}-c{idx}"),
                workout_id: workout.id.clone(),
                proposed_set_id: proposed_sets[idx].id.clone(),
                actual_reps: actual,
                actual_weight: weight,
                started_at: 120 + idx as i64,
                ended_at: if ended { 150 + idx as i64 } else { 0 },
                rest_until: 0,
            })
            .collect::<Vec<_>>();
        SchplannerWorkoutRecord {
            workout,
            exercise_groups: vec![group],
            proposed_sets,
            completed_sets,
        }
    }

    #[test]
    fn linear_replay_advances_variant_and_weight_after_success() {
        let regime = get_regime(RegimeType::Linear5x5);
        let base = regime.default_state();
        let derived = derive_state(regime.as_ref(), &base, &[linear_workout(true)]);

        assert_eq!(
            get_str_or(&derived.effective_state, "next_workout_variant", "A"),
            "B"
        );
        assert_eq!(
            get_f32_or(&derived.effective_state, "squat_weight", 0.0),
            140.0
        );
        assert_eq!(
            get_int_or(&derived.effective_state, "squat_stall_count", -1),
            0
        );
    }

    #[test]
    fn linear_replay_tracks_stall_after_failure() {
        let regime = get_regime(RegimeType::Linear5x5);
        let base = regime.default_state();
        let derived = derive_state(regime.as_ref(), &base, &[linear_workout(false)]);

        assert_eq!(
            get_f32_or(&derived.effective_state, "squat_weight", 0.0),
            135.0
        );
        assert_eq!(
            get_int_or(&derived.effective_state, "squat_stall_count", -1),
            1
        );
    }

    #[test]
    fn gzclp_replay_moves_t1_stage_after_failure() {
        let regime = get_regime(RegimeType::Gzclp);
        let base = regime.default_state();
        let workout = single_group_workout(
            "g-t1-fail",
            Exercise::Squat,
            "T1",
            ProgressionRule::AllSetsMatchTarget,
            135.0,
            3,
            5,
            vec![3, 3, 3, 3, 2],
            true,
            0,
        );
        let derived = derive_state(regime.as_ref(), &base, &[workout]);
        assert_eq!(
            get_str_or(&derived.effective_state, "squat_t1_stage", ""),
            "stage_2_6x2"
        );
        assert_eq!(
            get_int_or(&derived.effective_state, "next_session_index", -1),
            1
        );
    }

    #[test]
    fn gzclp_replay_adds_t3_weight_after_25_rep_amrap() {
        let regime = get_regime(RegimeType::Gzclp);
        let base = regime.default_state();
        let workout = single_group_workout(
            "g-t3-pass",
            Exercise::HipThrust,
            "T3",
            ProgressionRule::TopSetAmrap,
            45.0,
            15,
            3,
            vec![15, 15, 25],
            true,
            25,
        );
        let derived = derive_state(regime.as_ref(), &base, &[workout]);
        assert_eq!(
            get_f32_or(&derived.effective_state, "hip_thrust_t3_weight", 0.0),
            50.0
        );
    }

    #[test]
    fn wendler_replay_bumps_training_maxes_after_completed_cycle() {
        let regime = get_regime(RegimeType::Wendler531);
        let mut base = regime.default_state();
        crate::program_state::set_str(&mut base, "schedule_variant", "four_day");
        crate::program_state::set_int(&mut base, "cycle", 1);
        crate::program_state::set_int(&mut base, "week", 4);
        crate::program_state::set_int(&mut base, "session_in_week", 3);
        crate::program_state::set_f32(&mut base, "squat_tm", 200.0);
        crate::program_state::set_f32(&mut base, "bench_press_tm", 150.0);
        crate::program_state::set_f32(&mut base, "deadlift_tm", 250.0);
        crate::program_state::set_f32(&mut base, "overhead_press_tm", 100.0);

        let workout = single_group_workout(
            "w-cycle-end",
            Exercise::OverheadPress,
            "MAIN",
            ProgressionRule::None,
            60.0,
            5,
            3,
            vec![5, 5, 5],
            true,
            0,
        );
        let derived = derive_state(regime.as_ref(), &base, &[workout]);
        assert_eq!(get_int_or(&derived.effective_state, "cycle", 0), 2);
        assert_eq!(get_int_or(&derived.effective_state, "week", 0), 1);
        assert_eq!(
            get_int_or(&derived.effective_state, "session_in_week", -1),
            0
        );
        assert_eq!(get_f32_or(&derived.effective_state, "squat_tm", 0.0), 210.0);
        assert_eq!(
            get_f32_or(&derived.effective_state, "deadlift_tm", 0.0),
            260.0
        );
        assert_eq!(
            get_f32_or(&derived.effective_state, "bench_press_tm", 0.0),
            155.0
        );
        assert_eq!(
            get_f32_or(&derived.effective_state, "overhead_press_tm", 0.0),
            105.0
        );
    }
}
