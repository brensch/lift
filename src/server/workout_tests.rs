//! Tests for the workout service that exercise real RPC handlers against a
//! real `ServerDb` on a temp directory. Split from `workout.rs` to keep the
//! handler file focused on production code.

use super::messages::slot_key_for_exercise;
use super::*;

#[cfg(test)]
mod live_progression_tests {
    use super::*;

    fn authed<T>(token: &str, msg: T) -> Request<T> {
        let mut req = Request::new(msg);
        req.metadata_mut()
            .insert("x-session-token", token.parse().unwrap());
        req
    }

    async fn setup() -> (ServerWorkoutService, String, String) {
        let dir = std::env::temp_dir().join(format!("lift-live-test-{}", Uuid::new_v4()));
        let db = ServerDb::new_in_dir(&dir).await.unwrap();
        let (user, token) = db
            .get_or_create_user_with_auth_session("tester")
            .await
            .unwrap();
        (ServerWorkoutService { db }, user.id, token)
    }

    /// End-to-end through the real RPCs: start a Linear 5x5 squat session, then edit
    /// the weight mid-workout exactly as the app does (ReplaceExerciseGroupPlan with the
    /// progression hints stripped off), complete it heavier, end the workout, and confirm
    /// the next proposal increments from the weight actually lifted. This exercises the
    /// live EndWorkout glue (propose_from_state -> prescribed_slots_from_groups -> reconcile)
    /// that the replay-based unit/scenario tests don't cover.
    #[tokio::test]
    async fn edited_weight_progresses_through_live_end_workout_path() {
        let (svc, user_id, token) = setup().await;

        // Seed Linear 5x5 program state with squat at 175.
        let regime = get_regime(RegimeType::Linear5x5);
        let mut payload = regime.default_state();
        crate::program_state::set_f32(&mut payload, "squat_weight", 175.0);
        svc.db
            .put_program_state(
                &user_id,
                &GetActiveTrainingProgramStateResponse {
                    state: Some(TrainingProgramState {
                        regime_type: RegimeType::Linear5x5 as i32,
                        fields: payload_to_proto(&payload),
                        updated_at: 1,
                        source: "test".to_string(),
                    }),
                    schema: Some(regime.state_schema()),
                },
            )
            .await
            .unwrap();

        // Start a squat 5x5 @175 group WITH hints, as the app does from the proposal.
        let hint = ProgressionHint {
            slot_key: slot_key_for_exercise(Exercise::Squat),
            tier: "MAIN".to_string(),
            rule: ProgressionRule::AllSetsMatchTarget as i32,
            amrap_success_threshold: 0,
            counts_toward_program: true,
        };
        let working_sets = (0..5)
            .map(|_| WorkingSetSpec {
                target_weight: 175.0,
                target_reps: 5,
                is_amrap: false,
                instruction: String::new(),
                progression_hint: Some(hint.clone()),
            })
            .collect::<Vec<_>>();
        let group = ExerciseGroup {
            id: String::new(),
            workout_id: String::new(),
            name: "Squat".to_string(),
            sets: 5,
            interleave_warmups: false,
            workout_order: 0,
            exercise_configs: vec![ExerciseTypeConfig {
                exercise: Exercise::Squat as i32,
                start_weight: 175.0,
                end_weight: 175.0,
                reps: 5,
                include_warmup: false,
                rest_config: None,
                last_set_amrap: false,
                working_sets,
            }],
            rest_config: None,
            instruction: String::new(),
            prescribed_by_regime: false,
        };
        let start = svc
            .start_workout(authed(
                &token,
                StartWorkoutRequest {
                    name: "Workout A".to_string(),
                    exercise_groups: vec![group],
                    started_at: 1000,
                },
            ))
            .await
            .unwrap()
            .into_inner();
        let workout_id = start.workout.unwrap().id;
        let group_id = start.exercise_groups[0].id.clone();

        // Edit the weight mid-workout the way the app does: replace the group's plan with
        // 5 sets @185 and NO progression hints.
        let planned = (0..5)
            .map(|_| PlannedGroupSet {
                exercise: Exercise::Squat as i32,
                target_reps: 5,
                target_weight: 185.0,
                warmup: false,
                rest_after_success: 180,
                rest_after_failure: 300,
                is_amrap: false,
                instruction: String::new(),
                progression_hint: None,
                client_set_id: String::new(),
            })
            .collect::<Vec<_>>();
        let replaced = svc
            .replace_exercise_group_plan(authed(
                &token,
                ReplaceExerciseGroupPlanRequest {
                    workout_id: workout_id.clone(),
                    exercise_group_id: group_id.clone(),
                    name: "Squat".to_string(),
                    interleave_warmups: false,
                    sets: planned,
                    rest_config: None,
                    delete_group_if_empty: false,
                    instruction: String::new(),
                    create_if_missing: false,
                },
            ))
            .await
            .unwrap()
            .into_inner();

        // The edit really did strip the hints (the bug condition).
        assert!(
            replaced
                .generated_sets
                .iter()
                .all(|s| s.progression_hint.is_none()),
            "edit should leave the working sets hint-less, like the real app"
        );
        assert_eq!(replaced.generated_sets.len(), 5);

        // Complete all 5 working sets at the heavier 185x5.
        let mut ts = 1100;
        for set in &replaced.generated_sets {
            svc.complete_set(authed(
                &token,
                CompleteSetRequest {
                    workout_id: workout_id.clone(),
                    proposed_set_id: set.id.clone(),
                    actual_reps: 5,
                    actual_weight: 185.0,
                    completed_at: ts,
                },
            ))
            .await
            .unwrap();
            ts += 10;
        }

        // End the workout: this runs the live reconciliation against program state.
        svc.end_workout(authed(
            &token,
            EndWorkoutRequest {
                workout_id: workout_id.clone(),
                ended_at: ts,
            },
        ))
        .await
        .unwrap();

        // The next proposal should put squat at 190 (185 lifted + 5), proving progression
        // tracked the edited weight even though the hints were gone.
        let sched = svc
            .get_proposed_workout_schedule(authed(
                &token,
                GetProposedWorkoutScheduleRequest {
                    user_id: user_id.clone(),
                    at_time: ts + 100,
                },
            ))
            .await
            .unwrap()
            .into_inner();

        let squat_cfg = sched
            .proposed_groups
            .iter()
            .flat_map(|g| g.exercise_configs.iter())
            .find(|c| c.exercise == Exercise::Squat as i32)
            .expect("squat should appear in the next proposal");
        assert_eq!(
            squat_cfg.start_weight, 190.0,
            "next squat weight should increment from the edited 185"
        );
    }

    /// Editing a group's weight after completing some sets must keep completed sets first
    /// and the regenerated pending sets after them — not interleave them (the "jump around"
    /// bug from a colliding workout_order on the regenerated sets).
    #[tokio::test]
    async fn editing_weight_after_completing_sets_keeps_order_stable() {
        let (svc, _user_id, token) = setup().await;

        let working_sets = (0..5)
            .map(|_| WorkingSetSpec {
                target_weight: 175.0,
                target_reps: 5,
                is_amrap: false,
                instruction: String::new(),
                progression_hint: None,
            })
            .collect::<Vec<_>>();
        let group = ExerciseGroup {
            id: String::new(),
            workout_id: String::new(),
            name: "Squat".to_string(),
            sets: 5,
            interleave_warmups: false,
            workout_order: 0,
            exercise_configs: vec![ExerciseTypeConfig {
                exercise: Exercise::Squat as i32,
                start_weight: 175.0,
                end_weight: 175.0,
                reps: 5,
                include_warmup: false,
                rest_config: None,
                last_set_amrap: false,
                working_sets,
            }],
            rest_config: None,
            instruction: String::new(),
            prescribed_by_regime: false,
        };
        let start = svc
            .start_workout(authed(
                &token,
                StartWorkoutRequest {
                    name: "Workout A".to_string(),
                    exercise_groups: vec![group],
                    started_at: 1000,
                },
            ))
            .await
            .unwrap()
            .into_inner();
        let workout_id = start.workout.unwrap().id;
        let group_id = start.exercise_groups[0].id.clone();
        let working: Vec<_> = start.proposed_sets.iter().filter(|s| !s.warmup).collect();
        assert_eq!(working.len(), 5);

        // Complete the first two working sets at the original 175.
        for (i, set) in working.iter().take(2).enumerate() {
            svc.complete_set(authed(
                &token,
                CompleteSetRequest {
                    workout_id: workout_id.clone(),
                    proposed_set_id: set.id.clone(),
                    actual_reps: 5,
                    actual_weight: 175.0,
                    completed_at: 1100 + i as i64 * 10,
                },
            ))
            .await
            .unwrap();
        }

        // Edit the whole group up to 185 (like the app: no hints).
        let planned = (0..5)
            .map(|_| PlannedGroupSet {
                exercise: Exercise::Squat as i32,
                target_reps: 5,
                target_weight: 185.0,
                warmup: false,
                rest_after_success: 180,
                rest_after_failure: 300,
                is_amrap: false,
                instruction: String::new(),
                progression_hint: None,
                client_set_id: String::new(),
            })
            .collect::<Vec<_>>();
        svc.replace_exercise_group_plan(authed(
            &token,
            ReplaceExerciseGroupPlanRequest {
                workout_id: workout_id.clone(),
                exercise_group_id: group_id.clone(),
                name: "Squat".to_string(),
                interleave_warmups: false,
                sets: planned,
                rest_config: None,
                delete_group_if_empty: false,
                instruction: String::new(),
                create_if_missing: false,
            },
        ))
        .await
        .unwrap();

        // Read back the active (non-cancelled) working sets in order.
        let wk = svc
            .get_workout(authed(
                &token,
                GetWorkoutRequest {
                    workout_id: workout_id.clone(),
                },
            ))
            .await
            .unwrap()
            .into_inner();
        let mut active: Vec<_> = wk
            .proposed_sets
            .iter()
            .filter(|s| !s.warmup && !s.cancelled)
            .collect();
        active.sort_by_key(|s| s.workout_order);
        let weights: Vec<f32> = active.iter().map(|s| s.target_weight).collect();
        assert_eq!(
            weights,
            vec![175.0, 175.0, 185.0, 185.0, 185.0],
            "completed sets must stay first, then the new heavier sets — no interleaving"
        );
    }

    /// EndWorkout must be idempotent: a retry / double-fire on the same workout must not
    /// advance the program twice (175 -> 180, never 175 -> 180 -> 185).
    #[tokio::test]
    async fn end_workout_is_idempotent_and_does_not_double_progress() {
        let (svc, user_id, token) = setup().await;

        let regime = get_regime(RegimeType::Linear5x5);
        let mut payload = regime.default_state();
        crate::program_state::set_f32(&mut payload, "squat_weight", 175.0);
        svc.db
            .put_program_state(
                &user_id,
                &GetActiveTrainingProgramStateResponse {
                    state: Some(TrainingProgramState {
                        regime_type: RegimeType::Linear5x5 as i32,
                        fields: payload_to_proto(&payload),
                        updated_at: 1,
                        source: "test".to_string(),
                    }),
                    schema: Some(regime.state_schema()),
                },
            )
            .await
            .unwrap();

        let hint = ProgressionHint {
            slot_key: slot_key_for_exercise(Exercise::Squat),
            tier: "MAIN".to_string(),
            rule: ProgressionRule::AllSetsMatchTarget as i32,
            amrap_success_threshold: 0,
            counts_toward_program: true,
        };
        let working_sets = (0..5)
            .map(|_| WorkingSetSpec {
                target_weight: 175.0,
                target_reps: 5,
                is_amrap: false,
                instruction: String::new(),
                progression_hint: Some(hint.clone()),
            })
            .collect::<Vec<_>>();
        let group = ExerciseGroup {
            id: String::new(),
            workout_id: String::new(),
            name: "Squat".to_string(),
            sets: 5,
            interleave_warmups: false,
            workout_order: 0,
            exercise_configs: vec![ExerciseTypeConfig {
                exercise: Exercise::Squat as i32,
                start_weight: 175.0,
                end_weight: 175.0,
                reps: 5,
                include_warmup: false,
                rest_config: None,
                last_set_amrap: false,
                working_sets,
            }],
            rest_config: None,
            instruction: String::new(),
            prescribed_by_regime: false,
        };
        let start = svc
            .start_workout(authed(
                &token,
                StartWorkoutRequest {
                    name: "Workout A".to_string(),
                    exercise_groups: vec![group],
                    started_at: 1000,
                },
            ))
            .await
            .unwrap()
            .into_inner();
        let workout_id = start.workout.unwrap().id;

        let mut ts = 1100;
        for set in start.proposed_sets.iter().filter(|s| !s.warmup) {
            svc.complete_set(authed(
                &token,
                CompleteSetRequest {
                    workout_id: workout_id.clone(),
                    proposed_set_id: set.id.clone(),
                    actual_reps: 5,
                    actual_weight: 175.0,
                    completed_at: ts,
                },
            ))
            .await
            .unwrap();
            ts += 10;
        }

        // End it twice — second call is the retry / double-fire.
        for _ in 0..2 {
            svc.end_workout(authed(
                &token,
                EndWorkoutRequest {
                    workout_id: workout_id.clone(),
                    ended_at: ts,
                },
            ))
            .await
            .unwrap();
        }

        let sched = svc
            .get_proposed_workout_schedule(authed(
                &token,
                GetProposedWorkoutScheduleRequest {
                    user_id: user_id.clone(),
                    at_time: ts + 100,
                },
            ))
            .await
            .unwrap()
            .into_inner();
        let squat_cfg = sched
            .proposed_groups
            .iter()
            .flat_map(|g| g.exercise_configs.iter())
            .find(|c| c.exercise == Exercise::Squat as i32)
            .expect("squat should appear in the next proposal");
        assert_eq!(
            squat_cfg.start_weight, 180.0,
            "ending twice must progress 175 -> 180 only once, not 175 -> 180 -> 185"
        );
        // The A/B variant must advance exactly once. A double-apply would flip A->B->A and
        // the next proposal would come back as Workout A; the guard keeps it on B.
        assert!(
            sched.suggested_workout_name.contains('B'),
            "variant should advance exactly once (next session is Workout B), got {:?}",
            sched.suggested_workout_name
        );
    }
}

/// End-to-end coverage of the layoff deload path: a proposal after time away is
/// reduced, and completing that reduced workout must progress from what was
/// actually lifted rather than snapping back to the pre-layoff weight.
///
/// These go through the real RPCs because the deload lives in
/// `get_proposed_workout_schedule` (via `apply_temporal_adjustments_for_proposal`)
/// while reconciliation lives in `end_workout` — the scenario tests in
/// `src/scenario_tests.rs` call the regime directly and so exercise neither.
#[cfg(test)]
mod layoff_deload_tests {
    use super::*;

    const DAY: i64 = 24 * 3600;

    fn authed<T>(token: &str, msg: T) -> Request<T> {
        let mut req = Request::new(msg);
        req.metadata_mut()
            .insert("x-session-token", token.parse().unwrap());
        req
    }

    async fn setup() -> (ServerWorkoutService, String, String) {
        let dir = std::env::temp_dir().join(format!("lift-layoff-test-{}", Uuid::new_v4()));
        let db = ServerDb::new_in_dir(&dir).await.unwrap();
        let (user, token) = db
            .get_or_create_user_with_auth_session("layoff-tester")
            .await
            .unwrap();
        (ServerWorkoutService { db }, user.id, token)
    }

    async fn seed_linear_5x5_squat(svc: &ServerWorkoutService, user_id: &str, weight: f32) {
        let regime = get_regime(RegimeType::Linear5x5);
        let mut payload = regime.default_state();
        crate::program_state::set_f32(&mut payload, "squat_weight", weight);
        svc.db
            .put_program_state(
                user_id,
                &GetActiveTrainingProgramStateResponse {
                    state: Some(TrainingProgramState {
                        regime_type: RegimeType::Linear5x5 as i32,
                        fields: payload_to_proto(&payload),
                        updated_at: 1,
                        source: "test".to_string(),
                    }),
                    schema: Some(regime.state_schema()),
                },
            )
            .await
            .unwrap();
    }

    fn squat_group(weight: f32) -> ExerciseGroup {
        let hint = ProgressionHint {
            slot_key: slot_key_for_exercise(Exercise::Squat),
            tier: "MAIN".to_string(),
            rule: ProgressionRule::AllSetsMatchTarget as i32,
            amrap_success_threshold: 0,
            counts_toward_program: true,
        };
        ExerciseGroup {
            id: String::new(),
            workout_id: String::new(),
            name: "Squat".to_string(),
            sets: 5,
            interleave_warmups: false,
            workout_order: 0,
            exercise_configs: vec![ExerciseTypeConfig {
                exercise: Exercise::Squat as i32,
                start_weight: weight,
                end_weight: weight,
                reps: 5,
                include_warmup: false,
                rest_config: None,
                last_set_amrap: false,
                working_sets: (0..5)
                    .map(|_| WorkingSetSpec {
                        target_weight: weight,
                        target_reps: 5,
                        is_amrap: false,
                        instruction: String::new(),
                        progression_hint: Some(hint.clone()),
                    })
                    .collect(),
            }],
            rest_config: None,
            instruction: String::new(),
            prescribed_by_regime: true,
        }
    }

    /// Perform a full successful squat session at `weight`, starting at `at`.
    /// Returns the timestamp the workout ended.
    async fn do_squat_session(
        svc: &ServerWorkoutService,
        token: &str,
        weight: f32,
        at: i64,
    ) -> i64 {
        let start = svc
            .start_workout(authed(
                token,
                StartWorkoutRequest {
                    name: "Workout A".to_string(),
                    exercise_groups: vec![squat_group(weight)],
                    started_at: at,
                },
            ))
            .await
            .unwrap()
            .into_inner();
        let workout_id = start.workout.unwrap().id;

        let mut ts = at + 60;
        for set in start.proposed_sets.iter().filter(|s| !s.warmup) {
            svc.complete_set(authed(
                token,
                CompleteSetRequest {
                    workout_id: workout_id.clone(),
                    proposed_set_id: set.id.clone(),
                    actual_reps: 5,
                    actual_weight: weight,
                    completed_at: ts,
                },
            ))
            .await
            .unwrap();
            ts += 60;
        }

        svc.end_workout(authed(
            token,
            EndWorkoutRequest {
                workout_id,
                ended_at: ts,
            },
        ))
        .await
        .unwrap();
        ts
    }

    async fn proposed_squat_weight(
        svc: &ServerWorkoutService,
        token: &str,
        user_id: &str,
        at: i64,
    ) -> f32 {
        let sched = svc
            .get_proposed_workout_schedule(authed(
                token,
                GetProposedWorkoutScheduleRequest {
                    user_id: user_id.to_string(),
                    at_time: at,
                },
            ))
            .await
            .unwrap()
            .into_inner();
        sched
            .proposed_groups
            .iter()
            .flat_map(|g| g.exercise_configs.iter())
            .find(|c| c.exercise == Exercise::Squat as i32)
            .expect("squat should appear in the proposal")
            .start_weight
    }

    async fn stored_squat_weight(svc: &ServerWorkoutService, user_id: &str) -> f32 {
        let resp = svc.db.get_program_state(user_id).await.unwrap().unwrap();
        let payload = payload_from_proto(&resp.state.unwrap().fields);
        crate::program_state::get_f32(&payload, "squat_weight").unwrap()
    }

    /// Baseline: a normal gap between sessions must not reduce anything.
    #[tokio::test]
    async fn a_short_gap_does_not_deload() {
        let (svc, user_id, token) = setup().await;
        seed_linear_5x5_squat(&svc, &user_id, 175.0).await;

        let ended = do_squat_session(&svc, &token, 175.0, 1_000_000).await;
        // 175 completed successfully -> next session prescribes 180.
        assert_eq!(stored_squat_weight(&svc, &user_id).await, 180.0);

        for days in [0, 1, 3, 7, 13] {
            let proposed = proposed_squat_weight(&svc, &token, &user_id, ended + days * DAY).await;
            assert_eq!(
                proposed, 180.0,
                "a {days}-day gap is under the 14-day threshold and must not deload"
            );
        }
    }

    /// 14 days away drops the proposal to 90%; 30 days drops it to 80%.
    #[tokio::test]
    async fn a_long_layoff_deloads_the_proposal() {
        let (svc, user_id, token) = setup().await;
        seed_linear_5x5_squat(&svc, &user_id, 175.0).await;
        let ended = do_squat_session(&svc, &token, 175.0, 1_000_000).await;
        assert_eq!(stored_squat_weight(&svc, &user_id).await, 180.0);

        // 90% of 180 = 162, rounded to the nearest 5 lb.
        let at_14 = proposed_squat_weight(&svc, &token, &user_id, ended + 14 * DAY).await;
        assert_eq!(at_14, 160.0, "14 days away should propose 90% of 180");

        let at_29 = proposed_squat_weight(&svc, &token, &user_id, ended + 29 * DAY).await;
        assert_eq!(at_29, 160.0, "29 days is still in the 90% band");

        // 80% of 180 = 144, rounded to the nearest 5 lb.
        let at_30 = proposed_squat_weight(&svc, &token, &user_id, ended + 30 * DAY).await;
        assert_eq!(at_30, 145.0, "30 days away should propose 80% of 180");

        let at_90 = proposed_squat_weight(&svc, &token, &user_id, ended + 90 * DAY).await;
        assert_eq!(at_90, 145.0, "the 80% band has no further steps");
    }

    /// The deload is advisory: it changes what is proposed, not what is stored.
    /// Until a workout is actually completed the program state is untouched, so
    /// simply opening the app after a holiday does not lose your progress.
    #[tokio::test]
    async fn viewing_a_deloaded_proposal_does_not_mutate_stored_state() {
        let (svc, user_id, token) = setup().await;
        seed_linear_5x5_squat(&svc, &user_id, 175.0).await;
        let ended = do_squat_session(&svc, &token, 175.0, 1_000_000).await;
        assert_eq!(stored_squat_weight(&svc, &user_id).await, 180.0);

        for _ in 0..3 {
            let proposed =
                proposed_squat_weight(&svc, &token, &user_id, ended + 60 * DAY).await;
            assert_eq!(proposed, 145.0);
        }

        assert_eq!(
            stored_squat_weight(&svc, &user_id).await,
            180.0,
            "repeatedly viewing a deloaded proposal must not write the deload to state"
        );
    }

    /// The important one. After a layoff the app proposes a reduced weight; when
    /// the user completes exactly that, progression must continue from the weight
    /// they actually lifted. Reconciliation in `end_workout` builds its
    /// prescription WITHOUT the temporal adjustment, so this pins the behaviour
    /// at the seam between the two.
    #[tokio::test]
    async fn completing_a_deloaded_workout_progresses_from_the_deloaded_weight() {
        let (svc, user_id, token) = setup().await;
        seed_linear_5x5_squat(&svc, &user_id, 175.0).await;
        let ended = do_squat_session(&svc, &token, 175.0, 1_000_000).await;
        assert_eq!(stored_squat_weight(&svc, &user_id).await, 180.0);

        let comeback_at = ended + 45 * DAY;
        let deloaded = proposed_squat_weight(&svc, &token, &user_id, comeback_at).await;
        assert_eq!(deloaded, 145.0, "45 days away should propose 80%");

        // Do exactly what the app proposed, successfully.
        let comeback_ended = do_squat_session(&svc, &token, deloaded, comeback_at).await;

        assert_eq!(
            stored_squat_weight(&svc, &user_id).await,
            150.0,
            "a successful comeback session at 145 must progress to 150, not jump \
             back to 185 as if the pre-layoff 180 had been lifted"
        );

        let next = proposed_squat_weight(&svc, &token, &user_id, comeback_ended + DAY).await;
        assert_eq!(next, 150.0, "the next proposal should follow the new weight");
    }

    /// A failed comeback session must stall from the deloaded weight, not the
    /// pre-layoff one.
    #[tokio::test]
    async fn failing_a_deloaded_workout_holds_the_deloaded_weight() {
        let (svc, user_id, token) = setup().await;
        seed_linear_5x5_squat(&svc, &user_id, 175.0).await;
        let ended = do_squat_session(&svc, &token, 175.0, 1_000_000).await;

        let comeback_at = ended + 45 * DAY;
        let deloaded = proposed_squat_weight(&svc, &token, &user_id, comeback_at).await;
        assert_eq!(deloaded, 145.0);

        // Start the deloaded session but miss reps on every set.
        let start = svc
            .start_workout(authed(
                &token,
                StartWorkoutRequest {
                    name: "Comeback".to_string(),
                    exercise_groups: vec![squat_group(deloaded)],
                    started_at: comeback_at,
                },
            ))
            .await
            .unwrap()
            .into_inner();
        let workout_id = start.workout.unwrap().id;
        let mut ts = comeback_at + 60;
        for set in start.proposed_sets.iter().filter(|s| !s.warmup) {
            svc.complete_set(authed(
                &token,
                CompleteSetRequest {
                    workout_id: workout_id.clone(),
                    proposed_set_id: set.id.clone(),
                    actual_reps: 3, // missed the target of 5
                    actual_weight: deloaded,
                    completed_at: ts,
                },
            ))
            .await
            .unwrap();
            ts += 60;
        }
        svc.end_workout(authed(
            &token,
            EndWorkoutRequest {
                workout_id,
                ended_at: ts,
            },
        ))
        .await
        .unwrap();

        assert_eq!(
            stored_squat_weight(&svc, &user_id).await,
            145.0,
            "a failed comeback holds the deloaded weight rather than reverting \
             to the pre-layoff weight"
        );
    }

    /// The completion message after a deloaded session must describe what the
    /// user actually did (145 -> 150, an increase), not a phantom 180 -> 150
    /// decrease against the stale pre-layoff weight.
    #[tokio::test]
    async fn completion_message_after_layoff_reflects_the_deloaded_weight() {
        let (svc, user_id, token) = setup().await;
        seed_linear_5x5_squat(&svc, &user_id, 175.0).await;
        let ended = do_squat_session(&svc, &token, 175.0, 1_000_000).await;
        assert_eq!(stored_squat_weight(&svc, &user_id).await, 180.0);

        let comeback_at = ended + 45 * DAY;
        let deloaded = proposed_squat_weight(&svc, &token, &user_id, comeback_at).await;
        assert_eq!(deloaded, 145.0);

        // Perform the deloaded session successfully and capture EndWorkout's messages.
        let start = svc
            .start_workout(authed(
                &token,
                StartWorkoutRequest {
                    name: "Comeback".to_string(),
                    exercise_groups: vec![squat_group(deloaded)],
                    started_at: comeback_at,
                },
            ))
            .await
            .unwrap()
            .into_inner();
        let workout_id = start.workout.unwrap().id;
        let mut ts = comeback_at + 60;
        for set in start.proposed_sets.iter().filter(|s| !s.warmup) {
            svc.complete_set(authed(
                &token,
                CompleteSetRequest {
                    workout_id: workout_id.clone(),
                    proposed_set_id: set.id.clone(),
                    actual_reps: 5,
                    actual_weight: deloaded,
                    completed_at: ts,
                },
            ))
            .await
            .unwrap();
            ts += 60;
        }
        let end = svc
            .end_workout(authed(
                &token,
                EndWorkoutRequest {
                    workout_id,
                    ended_at: ts,
                },
            ))
            .await
            .unwrap()
            .into_inner();

        let squat_msg = end
            .user_messages
            .iter()
            .filter_map(|m| match m.details.as_ref()?.detail.as_ref()? {
                user_message_details::Detail::Progression(p)
                    if m.exercise == Exercise::Squat as i32 =>
                {
                    Some(p)
                }
                _ => None,
            })
            .next()
            .expect("a squat progression message should be emitted");

        assert_eq!(
            squat_msg.previous_weight, 145.0,
            "the message baseline must be the deloaded weight the user lifted, \
             not the stale pre-layoff 180"
        );
        assert_eq!(squat_msg.next_weight, 150.0);
        assert_eq!(
            squat_msg.change_kind,
            ProgressionChangeKind::Increase as i32,
            "145 -> 150 is an increase, not the deload a 180 baseline would imply"
        );
    }
}

/// A failed session must never make the next session heavier. Complements
/// `layoff_deload_tests`: the layoff case is fixed at the reconciliation seam,
/// these cover a user simply dialling the weight up or down themselves.
#[cfg(test)]
mod failed_session_never_raises_weight_tests {
    use super::*;
    use crate::schplanner::SchplannerSlotOutcome;
    use std::collections::HashMap;

    fn outcome(planned: usize, successful: usize, attempted: f32) -> SchplannerSlotOutcome {
        SchplannerSlotOutcome {
            slot_key: slot_key_for_exercise(Exercise::Squat),
            exercise: Exercise::Squat,
            tier: "MAIN".to_string(),
            rule: ProgressionRule::AllSetsMatchTarget,
            planned_sets: planned,
            completed_sets: planned,
            successful_sets: successful,
            last_completed_actual_weight: Some(attempted),
            last_successful_actual_weight: if successful > 0 { Some(attempted) } else { None },
            top_set_target_reps: 5,
            top_set_actual_reps: if successful > 0 { 5 } else { 3 },
            amrap_success_threshold: 0,
            workout_ended: true,
        }
    }

    fn squat_weight_after(stored: f32, stalls: i64, outcome: SchplannerSlotOutcome) -> f32 {
        let regime = get_regime(RegimeType::Linear5x5);
        let mut state = regime.default_state();
        crate::program_state::set_f32(&mut state, "squat_weight", stored);
        crate::program_state::set_int(&mut state, "squat_stall_count", stalls);

        let mut outcomes = HashMap::new();
        outcomes.insert(slot_key_for_exercise(Exercise::Squat), outcome);

        let record = crate::regimes::fake_completed_workout(1_000);
        regime.transition_state_on_workout_completed(&mut state, &record, &outcomes);
        crate::program_state::get_f32(&state, "squat_weight").unwrap()
    }

    #[tokio::test]
    async fn failing_below_the_stored_weight_holds_the_attempted_weight() {
        // Stored 180, user dialled down to 145 and missed reps.
        assert_eq!(squat_weight_after(180.0, 0, outcome(5, 2, 145.0)), 145.0);
    }

    #[tokio::test]
    async fn failing_above_the_stored_weight_does_not_raise_the_target() {
        // Stored 180, user tried 200 and missed. Next session must not be 200.
        assert_eq!(squat_weight_after(180.0, 0, outcome(5, 2, 200.0)), 180.0);
    }

    #[tokio::test]
    async fn failing_at_the_stored_weight_is_unchanged() {
        assert_eq!(squat_weight_after(180.0, 0, outcome(5, 2, 180.0)), 180.0);
    }

    #[tokio::test]
    async fn succeeding_still_progresses_from_what_was_lifted() {
        assert_eq!(squat_weight_after(180.0, 0, outcome(5, 5, 185.0)), 190.0);
    }

    #[tokio::test]
    async fn third_consecutive_stall_deloads_from_the_attempted_weight() {
        // Two stalls already recorded; this failure is the third -> 10% deload.
        assert_eq!(squat_weight_after(180.0, 2, outcome(5, 2, 180.0)), 160.0);
    }
}
