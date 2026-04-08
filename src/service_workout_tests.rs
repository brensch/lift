use super::*;

#[derive(Clone)]
struct Case {
    name: &'static str,
    request: UpdateExerciseGroupRequest,
    initial_sets: i32,
    completed_indexes: Vec<usize>,
    expected_target_group_total_sets: usize,
    expected_target_group_working_set_count: usize,
    expected_target_group_working_weights: Vec<f32>,
    expected_target_group_rest_success: Vec<i32>,
    expected_target_group_rest_failure: Vec<i32>,
}

fn config(
    exercise: i32,
    start_weight: f32,
    end_weight: f32,
    reps: i32,
    include_warmup: bool,
    rest_config: Option<RestConfig>,
) -> ExerciseTypeConfig {
    ExerciseTypeConfig {
        exercise,
        start_weight,
        end_weight,
        reps,
        include_warmup,
        rest_config,
        last_set_amrap: false,
        working_sets: vec![],
    }
}

fn group(
    id: &str,
    name: &str,
    sets: i32,
    workout_order: i32,
    configs: Vec<ExerciseTypeConfig>,
    rest_config: Option<RestConfig>,
) -> ExerciseGroup {
    ExerciseGroup {
        id: id.to_string(),
        workout_id: "w1".to_string(),
        name: name.to_string(),
        sets,
        interleave_warmups: false,
        workout_order,
        exercise_configs: configs,
        rest_config,
        instruction: String::new(),
        prescribed_by_regime: false,
    }
}

fn rest(success: i32, failure: i32, warmup: i32, last_warmup: i32) -> RestConfig {
    RestConfig {
        rest_after_success: success,
        rest_after_failure: failure,
        rest_after_warmup: warmup,
        rest_after_last_warmup: last_warmup,
    }
}

fn with_stable_ids(group: &ExerciseGroup, mut sets: Vec<ProposedSet>) -> Vec<ProposedSet> {
    for (idx, set) in sets.iter_mut().enumerate() {
        set.id = format!("{}-{}", group.id, idx);
    }
    sets
}

fn proposed(id: &str, group_id: &str, cancelled: bool) -> ProposedSet {
    ProposedSet {
        id: id.to_string(),
        workout_id: "w1".to_string(),
        workout_order: 0,
        exercise: 1,
        target_reps: 5,
        target_weight: 100.0,
        warmup: false,
        exercise_group_id: group_id.to_string(),
        rest_after_success: 90,
        rest_after_failure: 180,
        cancelled,
        is_amrap: false,
        instruction: String::new(),
        progression_hint: None,
    }
}

fn completed(proposed_set_id: &str) -> CompletedSet {
    CompletedSet {
        id: format!("c-{}", proposed_set_id),
        workout_id: "w1".to_string(),
        proposed_set_id: proposed_set_id.to_string(),
        actual_reps: 5,
        actual_weight: 100.0,
        started_at: 10,
        ended_at: 20,
        rest_until: 100,
    }
}

#[test]
fn update_exercise_group_table_driven() {
    let cases = vec![
        Case {
            name: "no completed sets regenerates full target group",
            request: UpdateExerciseGroupRequest {
                workout_id: "w1".to_string(),
                exercise_group_id: "g1".to_string(),
                name: "Updated Squat".to_string(),
                sets: 3,
                interleave_warmups: false,
                exercise_configs: vec![config(1, 135.0, 155.0, 5, false, None)],
                rest_config: Some(rest(120, 240, 20, 150)),
            },
            initial_sets: 2,
            completed_indexes: vec![],
            expected_target_group_total_sets: 3,
            expected_target_group_working_set_count: 3,
            expected_target_group_working_weights: vec![135.0, 145.0, 155.0],
            expected_target_group_rest_success: vec![120, 120, 120],
            expected_target_group_rest_failure: vec![240, 240, 240],
        },
        Case {
            name: "one completed set keeps one old proposed and regenerates remaining",
            request: UpdateExerciseGroupRequest {
                workout_id: "w1".to_string(),
                exercise_group_id: "g1".to_string(),
                name: "Updated Squat".to_string(),
                sets: 4,
                interleave_warmups: false,
                exercise_configs: vec![config(1, 135.0, 165.0, 5, false, None)],
                rest_config: Some(rest(90, 210, 10, 180)),
            },
            initial_sets: 3,
            completed_indexes: vec![0],
            expected_target_group_total_sets: 4,
            expected_target_group_working_set_count: 4,
            expected_target_group_working_weights: vec![100.0, 145.0, 155.0, 165.0],
            expected_target_group_rest_success: vec![90, 90, 90, 90],
            expected_target_group_rest_failure: vec![210, 210, 210, 210],
        },
        Case {
            name: "two completed sets and fewer target sets keeps completed only",
            request: UpdateExerciseGroupRequest {
                workout_id: "w1".to_string(),
                exercise_group_id: "g1".to_string(),
                name: "Updated Squat".to_string(),
                sets: 1,
                interleave_warmups: false,
                exercise_configs: vec![config(1, 150.0, 150.0, 5, false, None)],
                rest_config: Some(rest(110, 220, 15, 160)),
            },
            initial_sets: 3,
            completed_indexes: vec![0, 1],
            expected_target_group_total_sets: 2,
            expected_target_group_working_set_count: 2,
            expected_target_group_working_weights: vec![100.0, 100.0],
            expected_target_group_rest_success: vec![110, 110],
            expected_target_group_rest_failure: vec![220, 220],
        },
        Case {
            name: "group rest config applies when config rest config absent",
            request: UpdateExerciseGroupRequest {
                workout_id: "w1".to_string(),
                exercise_group_id: "g1".to_string(),
                name: "Updated Squat".to_string(),
                sets: 2,
                interleave_warmups: false,
                exercise_configs: vec![config(1, 135.0, 145.0, 5, false, None)],
                rest_config: Some(rest(75, 135, 12, 100)),
            },
            initial_sets: 2,
            completed_indexes: vec![],
            expected_target_group_total_sets: 2,
            expected_target_group_working_set_count: 2,
            expected_target_group_working_weights: vec![135.0, 145.0],
            expected_target_group_rest_success: vec![75, 75],
            expected_target_group_rest_failure: vec![135, 135],
        },
        Case {
            name: "empty config rest config is normalized and does not override group rest config",
            request: UpdateExerciseGroupRequest {
                workout_id: "w1".to_string(),
                exercise_group_id: "g1".to_string(),
                name: "Updated Squat".to_string(),
                sets: 2,
                interleave_warmups: false,
                exercise_configs: vec![config(1, 135.0, 145.0, 5, false, Some(rest(0, 0, 0, 0)))],
                rest_config: Some(rest(95, 205, 12, 100)),
            },
            initial_sets: 2,
            completed_indexes: vec![],
            expected_target_group_total_sets: 2,
            expected_target_group_working_set_count: 2,
            expected_target_group_working_weights: vec![135.0, 145.0],
            expected_target_group_rest_success: vec![95, 95],
            expected_target_group_rest_failure: vec![205, 205],
        },
    ];

    for case in cases {
        let target_group = group(
            "g1",
            "Squat",
            case.initial_sets,
            0,
            vec![config(1, 100.0, 100.0, 5, false, None)],
            None,
        );
        let other_group = group(
            "g2",
            "Bench",
            1,
            1,
            vec![config(2, 185.0, 185.0, 5, false, None)],
            None,
        );

        let target_sets = with_stable_ids(
            &target_group,
            generate_sets_for_group("w1", &target_group, 0),
        );
        let other_sets = with_stable_ids(
            &other_group,
            generate_sets_for_group("w1", &other_group, 100),
        );

        let completed_sets: Vec<CompletedSet> = case
            .completed_indexes
            .iter()
            .enumerate()
            .map(|(idx, set_idx)| CompletedSet {
                id: format!("c{}", idx),
                workout_id: "w1".to_string(),
                proposed_set_id: target_sets[*set_idx].id.clone(),
                actual_reps: target_sets[*set_idx].target_reps,
                actual_weight: target_sets[*set_idx].target_weight,
                started_at: 0,
                ended_at: 0,
                rest_until: 0,
            })
            .collect();

        let mut workout = ActiveWorkout::new(
            Workout {
                id: "w1".to_string(),
                name: "Test".to_string(),
                start_time: 0,
                end_time: 0,
                session_id: String::new(),
            },
            vec![target_group, other_group],
            target_sets.into_iter().chain(other_sets).collect(),
            completed_sets,
        );
        workout.reindex_sets();

        let result = apply_update_exercise_group(&mut workout, &case.request).expect(case.name);
        let updated_sets = result.1;

        assert_eq!(
            updated_sets.len(),
            case.expected_target_group_total_sets,
            "{}",
            case.name
        );
        let working_sets: Vec<&ProposedSet> = updated_sets.iter().filter(|s| !s.warmup).collect();
        assert_eq!(
            working_sets.len(),
            case.expected_target_group_working_set_count,
            "{}",
            case.name
        );

        let working_weights: Vec<f32> = working_sets.iter().map(|s| s.target_weight).collect();
        assert_eq!(
            working_weights, case.expected_target_group_working_weights,
            "{}",
            case.name
        );

        let rest_successes: Vec<i32> = working_sets.iter().map(|s| s.rest_after_success).collect();
        assert_eq!(
            rest_successes, case.expected_target_group_rest_success,
            "{}",
            case.name
        );

        let rest_failures: Vec<i32> = working_sets.iter().map(|s| s.rest_after_failure).collect();
        assert_eq!(
            rest_failures, case.expected_target_group_rest_failure,
            "{}",
            case.name
        );

        let other_group_sets: Vec<&ProposedSet> = workout
            .proposed_sets
            .iter()
            .filter(|s| s.exercise_group_id == "g2")
            .collect();
        assert_eq!(other_group_sets.len(), 1, "{}", case.name);
    }
}

#[test]
fn last_warmup_rest_matches_success_rest_for_group() {
    let g = group(
        "g1",
        "Squat",
        2,
        0,
        vec![config(1, 135.0, 155.0, 5, true, None)],
        Some(rest(75, 135, 12, 240)),
    );

    let sets = generate_sets_for_group("w1", &g, 0);
    let warmups: Vec<&ProposedSet> = sets.iter().filter(|s| s.warmup).collect();
    assert!(warmups.len() >= 2);

    // Non-last warmup keeps warmup rest.
    assert_eq!(warmups[0].rest_after_success, 12);
    assert_eq!(warmups[0].rest_after_failure, 12);

    // Last warmup uses working-set success rest.
    let last = warmups[warmups.len() - 1];
    assert_eq!(last.rest_after_success, 75);
    assert_eq!(last.rest_after_failure, 75);
}

#[test]
fn update_group_weight_change_cancels_old_pending_and_preserves_working_count() {
    let initial_group = group(
        "g1",
        "Squat",
        3,
        0,
        vec![config(1, 100.0, 100.0, 5, false, None)],
        None,
    );

    let mut initial_sets = with_stable_ids(
        &initial_group,
        generate_sets_for_group("w1", &initial_group, 0),
    );
    assert_eq!(initial_sets.len(), 3);

    let completed = CompletedSet {
        id: "c1".to_string(),
        workout_id: "w1".to_string(),
        proposed_set_id: initial_sets.remove(0).id,
        actual_reps: 5,
        actual_weight: 100.0,
        started_at: 0,
        ended_at: 1,
        rest_until: 10,
    };

    let mut workout = ActiveWorkout::new(
        Workout {
            id: "w1".to_string(),
            name: "Test".to_string(),
            start_time: 0,
            end_time: 0,
            session_id: String::new(),
        },
        vec![initial_group],
        with_stable_ids(
            &group(
                "g1",
                "Squat",
                3,
                0,
                vec![config(1, 100.0, 100.0, 5, false, None)],
                None,
            ),
            generate_sets_for_group(
                "w1",
                &group(
                    "g1",
                    "Squat",
                    3,
                    0,
                    vec![config(1, 100.0, 100.0, 5, false, None)],
                    None,
                ),
                0,
            ),
        ),
        vec![completed],
    );

    let req = UpdateExerciseGroupRequest {
        workout_id: "w1".to_string(),
        exercise_group_id: "g1".to_string(),
        name: "Squat".to_string(),
        sets: 3,
        interleave_warmups: false,
        exercise_configs: vec![config(1, 185.0, 185.0, 5, true, None)],
        rest_config: None,
    };

    let _ = apply_update_exercise_group(&mut workout, &req).expect("update");

    let active_group_sets: Vec<&ProposedSet> = workout
        .proposed_sets
        .iter()
        .filter(|set| set.exercise_group_id == "g1" && !set.cancelled)
        .collect();
    let cancelled_group_sets: Vec<&ProposedSet> = workout
        .proposed_sets
        .iter()
        .filter(|set| set.exercise_group_id == "g1" && set.cancelled)
        .collect();
    let working_active: Vec<&ProposedSet> = active_group_sets
        .iter()
        .copied()
        .filter(|set| !set.warmup)
        .collect();

    // 4 warmups + 3 working in target plan, with 1 working already completed-associated set preserved.
    assert_eq!(active_group_sets.len(), 7);
    assert_eq!(working_active.len(), 3);
    assert_eq!(cancelled_group_sets.len(), 2);
}

#[test]
fn final_set_detection_true_when_group_done_after_completion() {
    let proposed_sets = vec![
        proposed("g1-1", "g1", false),
        proposed("g1-2", "g1", false),
        proposed("g2-1", "g2", false),
    ];
    let completed_sets = vec![completed("g1-2")];

    assert!(is_final_set_in_exercise_group_after_completion(
        "g1-1",
        &proposed_sets,
        &completed_sets
    ));
}

#[test]
fn final_set_detection_false_when_same_group_pending_exists() {
    let proposed_sets = vec![
        proposed("g1-1", "g1", false),
        proposed("g1-2", "g1", false),
        proposed("g2-1", "g2", false),
    ];
    let completed_sets = Vec::<CompletedSet>::new();

    assert!(!is_final_set_in_exercise_group_after_completion(
        "g1-1",
        &proposed_sets,
        &completed_sets
    ));
}

#[test]
fn final_set_detection_ignores_cancelled_remaining_sets() {
    let proposed_sets = vec![
        proposed("g1-1", "g1", false),
        proposed("g1-cancelled", "g1", true),
        proposed("g2-1", "g2", false),
    ];
    let completed_sets = Vec::<CompletedSet>::new();

    assert!(is_final_set_in_exercise_group_after_completion(
        "g1-1",
        &proposed_sets,
        &completed_sets
    ));
}

#[test]
fn state_snapshot_is_all_done_when_no_active_proposed_sets_remain() {
    let proposed_sets = Vec::<ProposedSet>::new();
    let completed_sets = Vec::<CompletedSet>::new();

    let snapshot = workout_state_snapshot_from_state(&proposed_sets, &completed_sets, 0);
    assert_eq!(snapshot.state, 1);
    assert!(snapshot.display_set.is_none());
}

#[test]
fn update_group_rest_config_is_ignored_if_exercise_configs_have_rest_config() {
    let exercise_rest = rest(180, 300, 10, 180);
    let initial_group = group(
        "g1",
        "Squat",
        2,
        0,
        vec![config(1, 100.0, 100.0, 5, false, Some(exercise_rest))],
        None,
    );

    let initial_sets = generate_sets_for_group("w1", &initial_group, 0);
    assert_eq!(initial_sets[0].rest_after_success, 180);

    let mut workout = ActiveWorkout::new(
        Workout {
            id: "w1".to_string(),
            name: "Test".to_string(),
            start_time: 0,
            end_time: 0,
            session_id: String::new(),
        },
        vec![initial_group],
        initial_sets,
        vec![],
    );

    // Update group rest config to 150, and keep same exercise config (with its default 180,300,10 rest config)
    let new_group_rest = rest(150, 300, 20, 150);
    let req = UpdateExerciseGroupRequest {
        workout_id: "w1".to_string(),
        exercise_group_id: "g1".to_string(),
        name: "Squat".to_string(),
        sets: 2,
        interleave_warmups: false,
        exercise_configs: vec![config(
            1,
            100.0,
            100.0,
            5,
            false,
            Some(rest(180, 300, 10, 180)),
        )],
        rest_config: Some(new_group_rest),
    };

    let result = apply_update_exercise_group(&mut workout, &req).expect("update");
    let updated_sets = result.1;

    // Now it should be 150 because the default 180,300,10 should be cleared
    assert_eq!(
        updated_sets[0].rest_after_success, 150,
        "Group rest config should have taken precedence because the exercise config had defaults"
    );
}

#[test]
fn explicit_working_sets_override_legacy_last_set_amrap_behavior() {
    let mut cfg = config(1, 100.0, 120.0, 5, false, None);
    cfg.last_set_amrap = true;
    cfg.working_sets = vec![
        WorkingSetSpec {
            target_weight: 105.0,
            target_reps: 5,
            is_amrap: true,
            instruction: "Top set first".to_string(),
            progression_hint: None,
        },
        WorkingSetSpec {
            target_weight: 95.0,
            target_reps: 8,
            is_amrap: false,
            instruction: "Backoff".to_string(),
            progression_hint: None,
        },
    ];
    let g = group("g1", "Custom", 5, 0, vec![cfg], None);

    let sets = generate_sets_for_group("w1", &g, 0);
    let working: Vec<&ProposedSet> = sets.iter().filter(|s| !s.warmup).collect();
    assert_eq!(working.len(), 2);
    assert_eq!(working[0].target_weight, 105.0);
    assert_eq!(working[0].target_reps, 5);
    assert!(working[0].is_amrap);
    assert_eq!(working[0].instruction, "Top set first");
    assert_eq!(working[1].target_weight, 95.0);
    assert_eq!(working[1].target_reps, 8);
    assert!(!working[1].is_amrap);
    assert_eq!(working[1].instruction, "Backoff");
}

#[test]
fn update_rejects_regime_prescribed_group() {
    let mut prescribed = group(
        "g1",
        "Squat",
        2,
        0,
        vec![config(1, 100.0, 100.0, 5, false, None)],
        None,
    );
    prescribed.prescribed_by_regime = true;
    let sets = generate_sets_for_group("w1", &prescribed, 0);

    let mut workout = ActiveWorkout::new(
        Workout {
            id: "w1".to_string(),
            name: "Test".to_string(),
            start_time: 0,
            end_time: 0,
            session_id: String::new(),
        },
        vec![prescribed],
        sets,
        vec![],
    );

    let req = UpdateExerciseGroupRequest {
        workout_id: "w1".to_string(),
        exercise_group_id: "g1".to_string(),
        name: "Changed".to_string(),
        sets: 3,
        interleave_warmups: false,
        exercise_configs: vec![config(1, 135.0, 155.0, 5, false, None)],
        rest_config: None,
    };

    let err = apply_update_exercise_group(&mut workout, &req).expect_err("should reject");
    assert_eq!(err.code(), tonic::Code::FailedPrecondition);
}
