//! Replay-based tests for the scheduler: fabricated workout histories fed
//! through `derive_state` to check each regime's progression. Split from
//! `schplanner.rs` to keep the scheduler readable.

use crate::schplanner::*;
use crate::regimes::progression_slot_key;
use schlift::workout::v1::*;
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

#[test]
fn summarize_recent_insights_tracks_last_set_and_timing() {
    let mut workout = linear_workout(true);
    for (idx, set) in workout.completed_sets.iter_mut().enumerate() {
        set.started_at = 100 + idx as i64 * 70;
        set.ended_at = set.started_at + 20 + idx as i64 * 5;
        set.rest_until = set.ended_at + 90 + idx as i64 * 10;
    }
    let insights = summarize_recent_insights(&[workout]);
    let squat = insights.for_exercise(Exercise::Squat).unwrap();
    assert_eq!(squat.last_actual_reps, 5);
    assert_eq!(squat.last_target_reps, 5);
    assert!(squat.last_hit_target);
    assert_eq!(squat.set_durations.sample_count, 5);
    assert_eq!(squat.set_durations.max_secs, 40);
    assert_eq!(squat.rests.sample_count, 5);
    assert_eq!(squat.rests.max_secs, 130);
}

/// The prescription half of a fabricated workout; what the lifter did comes
/// in via `actual_reps` / `ended` so tests read as "prescription, outcome".
struct SingleGroupSpec<'a> {
    exercise: Exercise,
    tier: &'a str,
    rule: ProgressionRule,
    weight: f32,
    reps: i32,
    set_count: i32,
    amrap_threshold: i32,
}

fn single_group_workout(
    workout_id: &str,
    spec: SingleGroupSpec<'_>,
    actual_reps: Vec<i32>,
    ended: bool,
) -> SchplannerWorkoutRecord {
    let SingleGroupSpec {
        exercise,
        tier,
        rule,
        weight,
        reps,
        set_count,
        amrap_threshold,
    } = spec;
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
fn linear_replay_uses_actual_lifted_weight_for_progression() {
    let regime = get_regime(RegimeType::Linear5x5);
    let mut base = regime.default_state();
    crate::program_state::set_f32(&mut base, "squat_weight", 45.0);
    let mut workout = linear_workout(true);
    for set in &mut workout.completed_sets {
        set.actual_weight = 185.0;
    }

    let derived = derive_state(regime.as_ref(), &base, &[workout]);

    assert_eq!(
        get_f32_or(&derived.effective_state, "squat_weight", 0.0),
        190.0
    );
}

#[test]
fn linear_progression_uses_last_completed_weight_by_time() {
    // The set finished *last by wall-clock* (ended_at) drives progression, even if a
    // heavier set was done earlier and even if list order disagrees. Here the most
    // recently completed set is 175 (-> 180); an earlier 185 set must NOT win.
    let regime = get_regime(RegimeType::Linear5x5);
    let mut base = regime.default_state();
    crate::program_state::set_f32(&mut base, "squat_weight", 175.0);
    let mut workout = linear_workout(true);
    // (weight, ended_at) per set; linear_workout(true) records 5 reps so all succeed.
    let plan = [
        (175.0, 100),
        (175.0, 200), // most recently completed -> this is the one that should win
        (175.0, 120),
        (175.0, 130),
        (185.0, 110), // heavier, but completed earlier and last in list order
    ];
    for (set, (w, ended)) in workout.completed_sets.iter_mut().zip(plan) {
        set.actual_weight = w;
        set.ended_at = ended;
    }

    let derived = derive_state(regime.as_ref(), &base, &[workout]);

    assert_eq!(
        get_f32_or(&derived.effective_state, "squat_weight", 0.0),
        180.0,
        "should progress from the last-completed set (175 -> 180), not the heavier earlier 185"
    );
}

#[test]
fn edited_workout_without_hints_still_progresses_by_exercise() {
    // Reproduces the original bug: the user edited the squat group mid-workout
    // (bumping the weight), which strips progression hints off the proposed sets.
    // Progression must still happen — driven by the program-state prescription and
    // matched to completed work by exercise, not by surviving per-set hints.
    let regime = get_regime(RegimeType::Linear5x5);
    let mut base = regime.default_state();
    crate::program_state::set_f32(&mut base, "squat_weight", 175.0);

    // Prescription is derived from the proposal generated off program state.
    let insights = summarize_recent_insights(&[]);
    let proposal = regime.propose_from_state(&base, 0, 1, &insights);
    let prescribed = prescribed_slots_from_groups(&proposal.proposed_groups);
    let squat_slot = progression_slot_key(Exercise::Squat);
    assert!(prescribed.contains_key(&squat_slot));

    // A completed workout whose proposed sets carry NO progression hints (as if the
    // group was edited / regenerated), squat done for 5×5 at a heavier 185.
    let workout = Workout {
        id: "edited".to_string(),
        name: "Workout A".to_string(),
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
        exercise_configs: vec![],
        rest_config: None,
        instruction: String::new(),
        prescribed_by_regime: false,
    };
    let proposed_sets = (0..5)
        .map(|idx| ProposedSet {
            id: format!("p{idx}"),
            workout_id: workout.id.clone(),
            workout_order: idx,
            exercise: Exercise::Squat as i32,
            target_reps: 5,
            target_weight: 185.0,
            warmup: false,
            exercise_group_id: group.id.clone(),
            rest_after_success: 180,
            rest_after_failure: 300,
            cancelled: false,
            is_amrap: false,
            instruction: String::new(),
            progression_hint: None, // stripped by editing the group
        })
        .collect::<Vec<_>>();
    let completed_sets = proposed_sets
        .iter()
        .map(|set| CompletedSet {
            id: format!("c{}", set.id),
            workout_id: workout.id.clone(),
            proposed_set_id: set.id.clone(),
            actual_reps: 5,
            actual_weight: 185.0,
            started_at: 120,
            ended_at: 150,
            rest_until: 0,
        })
        .collect::<Vec<_>>();
    let record = SchplannerWorkoutRecord {
        workout,
        exercise_groups: vec![group],
        proposed_sets,
        completed_sets,
    };

    let slot_outcomes = summarize_slot_outcomes(&record, &prescribed);
    assert!(
        slot_outcomes.contains_key(&squat_slot),
        "squat must reconcile by exercise even without hints"
    );

    let mut state = base.clone();
    regime.transition_state_on_workout_completed(&mut state, &record, &slot_outcomes);
    assert_eq!(
        get_f32_or(&state, "squat_weight", 0.0),
        190.0,
        "next squat weight should increment from the 185 actually lifted"
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
        SingleGroupSpec {
            exercise: Exercise::Squat,
            tier: "T1",
            rule: ProgressionRule::AllSetsMatchTarget,
            weight: 135.0,
            reps: 3,
            set_count: 5,
            amrap_threshold: 0,
        },
        vec![3, 3, 3, 3, 2],
        true,
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
        SingleGroupSpec {
            exercise: Exercise::HipThrust,
            tier: "T3",
            rule: ProgressionRule::TopSetAmrap,
            weight: 45.0,
            reps: 15,
            set_count: 3,
            amrap_threshold: 25,
        },
        vec![15, 15, 25],
        true,
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
        SingleGroupSpec {
            exercise: Exercise::OverheadPress,
            tier: "MAIN",
            rule: ProgressionRule::None,
            weight: 60.0,
            reps: 5,
            set_count: 3,
            amrap_threshold: 0,
        },
        vec![5, 5, 5],
        true,
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
