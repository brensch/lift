use super::*;
use crate::service_workout::MyWorkoutService;
use crate::state::AppState;
use schlift::workout::v1::workout_service_server::WorkoutService;
use schlift::workout::v1::{
    CancelProposedSetRequest, CompleteSetRequest, CreateExerciseGroupRequest,
    DeleteCompletedSetRequest, EndWorkoutRequest, ExerciseGroup, ExerciseTypeConfig,
    GetCurrentSessionRequest, GetWorkoutRequest, JoinUserRequest, LeaveSessionRequest,
    PlannedGroupSet, ReorderExerciseGroupsRequest, ReplaceExerciseGroupPlanRequest, RestConfig,
    StartSetRequest, StartWorkoutRequest, UpdateExerciseGroupRequest,
};
use std::collections::HashSet;
use std::sync::Arc;
use tokio::time::{sleep, Duration};
use tonic::{metadata::MetadataValue, Request};

fn with_token<T>(payload: T, token: &str) -> Request<T> {
    let mut request = Request::new(payload);
    request.metadata_mut().insert(
        "x-session-token",
        MetadataValue::try_from(token).expect("valid token"),
    );
    request
}

fn single_exercise_group(
    id: &str,
    name: &str,
    weight: f32,
    sets: i32,
    order: i32,
) -> ExerciseGroup {
    ExerciseGroup {
        id: id.to_string(),
        workout_id: String::new(),
        name: name.to_string(),
        sets,
        interleave_warmups: false,
        workout_order: order,
        exercise_configs: vec![ExerciseTypeConfig {
            exercise: 1,
            start_weight: weight,
            end_weight: weight,
            reps: 5,
            include_warmup: false,
            rest_config: Some(RestConfig {
                rest_after_success: 90,
                rest_after_failure: 180,
                rest_after_warmup: 0,
                rest_after_last_warmup: 0,
            }),
            last_set_amrap: false,
            working_sets: vec![],
        }],
        rest_config: None,
        instruction: String::new(),
        prescribed_by_regime: false,
    }
}

fn planned_sets_from_legacy(sets: i32, configs: &[ExerciseTypeConfig]) -> Vec<PlannedGroupSet> {
    let mut out = Vec::new();
    for config in configs {
        for w in 0..sets.max(1) {
            let weight = if sets <= 1 {
                config.start_weight
            } else {
                config.start_weight
                    + (w as f32 / (sets - 1) as f32) * (config.end_weight - config.start_weight)
            };
            out.push(PlannedGroupSet {
                exercise: config.exercise,
                target_reps: config.reps,
                target_weight: (weight / 5.0).round() * 5.0,
                warmup: false,
                rest_after_success: 180,
                rest_after_failure: 300,
                is_amrap: false,
                instruction: String::new(),
                progression_hint: None,
                client_set_id: uuid::Uuid::new_v4().to_string(),
            });
        }
    }
    out
}

fn replace_req_from_update(req: UpdateExerciseGroupRequest) -> ReplaceExerciseGroupPlanRequest {
    ReplaceExerciseGroupPlanRequest {
        workout_id: req.workout_id,
        exercise_group_id: req.exercise_group_id,
        name: req.name,
        interleave_warmups: req.interleave_warmups,
        sets: planned_sets_from_legacy(req.sets, &req.exercise_configs),
        rest_config: req.rest_config,
        delete_group_if_empty: false,
        instruction: String::new(),
        create_if_missing: false,
    }
}

fn replace_req_from_create(req: CreateExerciseGroupRequest) -> ReplaceExerciseGroupPlanRequest {
    ReplaceExerciseGroupPlanRequest {
        workout_id: req.workout_id,
        exercise_group_id: String::new(),
        name: req.name,
        interleave_warmups: req.interleave_warmups,
        sets: planned_sets_from_legacy(req.sets, &req.exercise_configs),
        rest_config: req.rest_config,
        delete_group_if_empty: false,
        instruction: String::new(),
        create_if_missing: false,
    }
}

#[tokio::test]
async fn api_flow_exposes_next_up_after_mid_workout_group_update() {
    let temp_dir = std::env::temp_dir().join(format!("schlift-test-{}", uuid::Uuid::new_v4()));
    let central_db = CentralDb::new_in_dir(&temp_dir).await.expect("db");
    let state = Arc::new(AppState::new());
    let workout_service = MyWorkoutService::new(central_db.clone(), state);

    let user = central_db
        .create_user_with_id("u1", "u1")
        .await
        .expect("user");
    let token = central_db
        .create_auth_session(&user.id)
        .await
        .expect("token");

    let start = WorkoutService::start_workout(
        &workout_service,
        with_token(
            StartWorkoutRequest {
                name: "w".to_string(),
                exercise_groups: vec![
                    single_exercise_group("g1", "Squat", 100.0, 3, 0),
                    single_exercise_group("g2", "Bench", 185.0, 1, 1),
                ],
                started_at: 0,
            },
            &token,
        ),
    )
    .await
    .expect("start")
    .into_inner();

    let mut workout = WorkoutService::get_workout(
        &workout_service,
        with_token(
            GetWorkoutRequest {
                workout_id: start.id.clone(),
            },
            &token,
        ),
    )
    .await
    .expect("workout")
    .into_inner();

    let first_g1 = workout
        .proposed_sets
        .iter()
        .find(|set| set.exercise_group_id == "g1" && set.workout_order == 0)
        .expect("first group set")
        .id
        .clone();

    let _ = WorkoutService::complete_set(
        &workout_service,
        with_token(
            CompleteSetRequest {
                workout_id: start.id.clone(),
                proposed_set_id: first_g1,
                actual_reps: 5,
                actual_weight: 100.0,
                completed_at: 0,
            },
            &token,
        ),
    )
    .await
    .expect("complete first");

    let _ = WorkoutService::replace_exercise_group_plan(
        &workout_service,
        with_token(
            replace_req_from_update(UpdateExerciseGroupRequest {
                workout_id: start.id.clone(),
                exercise_group_id: "g1".to_string(),
                name: "Squat".to_string(),
                sets: 3,
                interleave_warmups: false,
                exercise_configs: vec![ExerciseTypeConfig {
                    exercise: 1,
                    start_weight: 120.0,
                    end_weight: 140.0,
                    reps: 5,
                    include_warmup: false,
                    rest_config: None,
                    last_set_amrap: false,
                    working_sets: vec![],
                }],
                rest_config: None,
            }),
            &token,
        ),
    )
    .await
    .expect("update group");

    workout = WorkoutService::get_workout(
        &workout_service,
        with_token(
            GetWorkoutRequest {
                workout_id: start.id.clone(),
            },
            &token,
        ),
    )
    .await
    .expect("workout after update")
    .into_inner();

    let next_up = workout.next_up_set.expect("next up should exist");
    assert_eq!(next_up.exercise_group_id, "g1");
    assert_eq!(next_up.target_weight, 130.0);
}

#[tokio::test]
async fn api_flow_exposes_group_session_next_up_user() {
    let temp_dir = std::env::temp_dir().join(format!("schlift-test-{}", uuid::Uuid::new_v4()));
    let central_db = CentralDb::new_in_dir(&temp_dir).await.expect("db");
    let state = Arc::new(AppState::new());
    let workout_service = MyWorkoutService::new(central_db.clone(), state.clone());
    let group_service = GroupService::new(central_db.clone(), state);

    let user1 = central_db
        .create_user_with_id("u1", "u1")
        .await
        .expect("user1");
    let user2 = central_db
        .create_user_with_id("u2", "u2")
        .await
        .expect("user2");
    let token1 = central_db
        .create_auth_session(&user1.id)
        .await
        .expect("token1");
    let token2 = central_db
        .create_auth_session(&user2.id)
        .await
        .expect("token2");

    let start1 = WorkoutService::start_workout(
        &workout_service,
        with_token(
            StartWorkoutRequest {
                name: "w1".to_string(),
                exercise_groups: vec![single_exercise_group("g1", "Squat", 100.0, 2, 0)],
                started_at: 0,
            },
            &token1,
        ),
    )
    .await
    .expect("start1")
    .into_inner();

    let start2 = WorkoutService::start_workout(
        &workout_service,
        with_token(
            StartWorkoutRequest {
                name: "w2".to_string(),
                exercise_groups: vec![single_exercise_group("g2", "Bench", 150.0, 2, 0)],
                started_at: 0,
            },
            &token2,
        ),
    )
    .await
    .expect("start2")
    .into_inner();

    let w1 = WorkoutService::get_workout(
        &workout_service,
        with_token(
            GetWorkoutRequest {
                workout_id: start1.id.clone(),
            },
            &token1,
        ),
    )
    .await
    .expect("w1")
    .into_inner();
    let w2 = WorkoutService::get_workout(
        &workout_service,
        with_token(
            GetWorkoutRequest {
                workout_id: start2.id.clone(),
            },
            &token2,
        ),
    )
    .await
    .expect("w2")
    .into_inner();

    let u1_first_set = w1.next_up_set.expect("u1 next").id;
    let u2_first_set = w2.next_up_set.expect("u2 next").id;

    let _ = WorkoutService::start_set(
        &workout_service,
        with_token(
            StartSetRequest {
                workout_id: start1.id.clone(),
                proposed_set_id: u1_first_set,
                started_at: 0,
            },
            &token1,
        ),
    )
    .await
    .expect("u1 start set");

    let _ = WorkoutService::complete_set(
        &workout_service,
        with_token(
            CompleteSetRequest {
                workout_id: start2.id.clone(),
                proposed_set_id: u2_first_set,
                actual_reps: 5,
                actual_weight: 150.0,
                completed_at: 0,
            },
            &token2,
        ),
    )
    .await
    .expect("u2 complete");

    let _ = MultiplayerService::join_user(
        &group_service,
        with_token(
            JoinUserRequest {
                user_id: user2.id.clone(),
            },
            &token1,
        ),
    )
    .await
    .expect("join");

    let session = MultiplayerService::get_current_session(
        &group_service,
        with_token(
            GetCurrentSessionRequest {
                session_id: String::new(),
            },
            &token1,
        ),
    )
    .await
    .expect("session")
    .into_inner()
    .session_status
    .expect("session status");

    assert_eq!(session.next_up_user_id, "u2");
    assert!(session.next_up_set.is_some());
    assert_eq!(session.currently_lifting_user_id, "u1");

    assert!(session
        .participants
        .iter()
        .all(|p| p.user.as_ref().map(|u| u.id.as_str()) != Some("u1")));

    let u2_status = session
        .participants
        .iter()
        .find(|p| p.user.as_ref().map(|u| u.id.as_str()) == Some("u2"))
        .expect("u2 status");
    assert!(!u2_status.has_active_set);
    assert!(u2_status.next_up_set.is_some());
}

#[tokio::test]
async fn finished_user_leaves_active_membership_but_remains_visible_in_session() {
    let temp_dir = std::env::temp_dir().join(format!("schlift-test-{}", uuid::Uuid::new_v4()));
    let central_db = CentralDb::new_in_dir(&temp_dir).await.expect("db");
    let state = Arc::new(AppState::new());
    let workout_service = MyWorkoutService::new(central_db.clone(), state.clone());
    let group_service = GroupService::new(central_db.clone(), state);

    let user1 = central_db
        .create_user_with_id("u1", "u1")
        .await
        .expect("user1");
    let user2 = central_db
        .create_user_with_id("u2", "u2")
        .await
        .expect("user2");
    let token1 = central_db
        .create_auth_session(&user1.id)
        .await
        .expect("token1");
    let token2 = central_db
        .create_auth_session(&user2.id)
        .await
        .expect("token2");

    let start1 = WorkoutService::start_workout(
        &workout_service,
        with_token(
            StartWorkoutRequest {
                name: "w1".to_string(),
                exercise_groups: vec![single_exercise_group("g1", "Squat", 100.0, 1, 0)],
                started_at: 0,
            },
            &token1,
        ),
    )
    .await
    .expect("start1")
    .into_inner();
    let _start2 = WorkoutService::start_workout(
        &workout_service,
        with_token(
            StartWorkoutRequest {
                name: "w2".to_string(),
                exercise_groups: vec![single_exercise_group("g2", "Bench", 150.0, 1, 0)],
                started_at: 0,
            },
            &token2,
        ),
    )
    .await
    .expect("start2")
    .into_inner();

    let session_id = MultiplayerService::join_user(
        &group_service,
        with_token(
            JoinUserRequest {
                user_id: user2.id.clone(),
            },
            &token1,
        ),
    )
    .await
    .expect("join")
    .into_inner()
    .session_id;

    let _ = WorkoutService::end_workout(
        &workout_service,
        with_token(
            EndWorkoutRequest {
                workout_id: start1.id.clone(),
                ended_at: 0,
            },
            &token1,
        ),
    )
    .await
    .expect("u1 end workout");

    let mut seen_finished_from_peer = false;
    let mut explicit_fetch_after_leave = false;

    for _ in 0..50 {
        let peer_session = MultiplayerService::get_current_session(
            &group_service,
            with_token(
                GetCurrentSessionRequest {
                    session_id: String::new(),
                },
                &token2,
            ),
        )
        .await
        .expect("peer session")
        .into_inner();

        if let Some(status) = peer_session.session_status {
            if let Some(u1) = status
                .participants
                .iter()
                .find(|p| p.user.as_ref().map(|u| u.id.as_str()) == Some("u1"))
            {
                if u1
                    .active_workout
                    .as_ref()
                    .map(|w| w.end_time > 0)
                    .unwrap_or(false)
                {
                    seen_finished_from_peer = true;
                }
            }
        }

        let explicit = MultiplayerService::get_current_session(
            &group_service,
            with_token(
                GetCurrentSessionRequest {
                    session_id: session_id.clone(),
                },
                &token1,
            ),
        )
        .await
        .expect("explicit session after leave")
        .into_inner();

        explicit_fetch_after_leave =
            explicit.session_id == session_id && explicit.session_status.is_some();

        if seen_finished_from_peer && explicit_fetch_after_leave {
            break;
        }

        sleep(Duration::from_millis(20)).await;
    }

    assert!(
        seen_finished_from_peer,
        "other participants should still see finished user in session snapshot"
    );
    assert!(
            explicit_fetch_after_leave,
            "finished user should be able to fetch session snapshot by explicit session_id after auto-leave"
        );
}

#[tokio::test]
async fn next_up_skips_user_after_leaving_session_membership() {
    let temp_dir = std::env::temp_dir().join(format!("schlift-test-{}", uuid::Uuid::new_v4()));
    let central_db = CentralDb::new_in_dir(&temp_dir).await.expect("db");
    let state = Arc::new(AppState::new());
    let workout_service = MyWorkoutService::new(central_db.clone(), state.clone());
    let group_service = GroupService::new(central_db.clone(), state);

    let user1 = central_db
        .create_user_with_id("u1", "u1")
        .await
        .expect("user1");
    let user2 = central_db
        .create_user_with_id("u2", "u2")
        .await
        .expect("user2");
    let token1 = central_db
        .create_auth_session(&user1.id)
        .await
        .expect("token1");
    let token2 = central_db
        .create_auth_session(&user2.id)
        .await
        .expect("token2");

    let _start1 = WorkoutService::start_workout(
        &workout_service,
        with_token(
            StartWorkoutRequest {
                name: "w1".to_string(),
                exercise_groups: vec![single_exercise_group("g1", "Squat", 100.0, 1, 0)],
                started_at: 0,
            },
            &token1,
        ),
    )
    .await
    .expect("start1")
    .into_inner();
    let start2 = WorkoutService::start_workout(
        &workout_service,
        with_token(
            StartWorkoutRequest {
                name: "w2".to_string(),
                exercise_groups: vec![single_exercise_group("g2", "Bench", 150.0, 1, 0)],
                started_at: 0,
            },
            &token2,
        ),
    )
    .await
    .expect("start2")
    .into_inner();

    let w2 = WorkoutService::get_workout(
        &workout_service,
        with_token(
            GetWorkoutRequest {
                workout_id: start2.id.clone(),
            },
            &token2,
        ),
    )
    .await
    .expect("w2")
    .into_inner();
    let u2_first_set = w2.next_up_set.expect("u2 next").id;

    let _ = WorkoutService::start_set(
        &workout_service,
        with_token(
            StartSetRequest {
                workout_id: start2.id.clone(),
                proposed_set_id: u2_first_set,
                started_at: 0,
            },
            &token2,
        ),
    )
    .await
    .expect("u2 start set");

    let session_id = MultiplayerService::join_user(
        &group_service,
        with_token(
            JoinUserRequest {
                user_id: user2.id.clone(),
            },
            &token1,
        ),
    )
    .await
    .expect("join")
    .into_inner()
    .session_id;

    let before_leave = MultiplayerService::get_current_session(
        &group_service,
        with_token(
            GetCurrentSessionRequest {
                session_id: String::new(),
            },
            &token2,
        ),
    )
    .await
    .expect("session before leave")
    .into_inner()
    .session_status
    .expect("session status before leave");
    assert_eq!(before_leave.next_up_user_id, "u1");

    let _ = MultiplayerService::leave_session(
        &group_service,
        with_token(LeaveSessionRequest {}, &token1),
    )
    .await
    .expect("u1 leave session");

    let after_leave = MultiplayerService::get_current_session(
        &group_service,
        with_token(
            GetCurrentSessionRequest {
                session_id: session_id.clone(),
            },
            &token2,
        ),
    )
    .await
    .expect("session after leave")
    .into_inner()
    .session_status
    .expect("session status after leave");

    assert_eq!(
        after_leave.next_up_user_id, "",
        "left user must be excluded from next-up calculation"
    );
}

#[tokio::test]
async fn api_flow_cancel_warmup_tracks_plan_change_stats() {
    let temp_dir = std::env::temp_dir().join(format!("schlift-test-{}", uuid::Uuid::new_v4()));
    let central_db = CentralDb::new_in_dir(&temp_dir).await.expect("db");
    let state = Arc::new(AppState::new());
    let workout_service = MyWorkoutService::new(central_db.clone(), state);

    let user = central_db
        .create_user_with_id("u1", "u1")
        .await
        .expect("user");
    let token = central_db
        .create_auth_session(&user.id)
        .await
        .expect("token");

    let start = WorkoutService::start_workout(
        &workout_service,
        with_token(
            StartWorkoutRequest {
                name: "w".to_string(),
                exercise_groups: vec![ExerciseGroup {
                    id: "g1".to_string(),
                    workout_id: String::new(),
                    name: "Squat".to_string(),
                    sets: 2,
                    interleave_warmups: false,
                    workout_order: 0,
                    exercise_configs: vec![ExerciseTypeConfig {
                        exercise: 1,
                        start_weight: 185.0,
                        end_weight: 185.0,
                        reps: 5,
                        include_warmup: true,
                        rest_config: Some(RestConfig {
                            rest_after_success: 90,
                            rest_after_failure: 180,
                            rest_after_warmup: 10,
                            rest_after_last_warmup: 0,
                        }),
                        last_set_amrap: false,
                        working_sets: vec![],
                    }],
                    rest_config: None,
                    instruction: String::new(),
                    prescribed_by_regime: false,
                }],
                started_at: 0,
            },
            &token,
        ),
    )
    .await
    .expect("start")
    .into_inner();

    let workout_before = WorkoutService::get_workout(
        &workout_service,
        with_token(
            GetWorkoutRequest {
                workout_id: start.id.clone(),
            },
            &token,
        ),
    )
    .await
    .expect("workout before")
    .into_inner();
    let warmup_to_cancel = workout_before
        .proposed_sets
        .iter()
        .find(|set| set.warmup)
        .expect("warmup exists")
        .id
        .clone();

    let _ = WorkoutService::cancel_proposed_set(
        &workout_service,
        with_token(
            CancelProposedSetRequest {
                workout_id: start.id.clone(),
                proposed_set_id: warmup_to_cancel.clone(),
            },
            &token,
        ),
    )
    .await
    .expect("cancel");

    let workout_after = WorkoutService::get_workout(
        &workout_service,
        with_token(
            GetWorkoutRequest {
                workout_id: start.id.clone(),
            },
            &token,
        ),
    )
    .await
    .expect("workout after")
    .into_inner();

    assert!(workout_after
        .proposed_sets
        .iter()
        .any(|set| set.id == warmup_to_cancel && set.cancelled));
    assert!(!workout_after
        .proposed_sets
        .iter()
        .any(|set| set.id == warmup_to_cancel && !set.cancelled));
    let stats = workout_after
        .plan_change_stats
        .expect("plan change stats expected");
    assert_eq!(stats.cancelled_total, 1);
    assert_eq!(stats.cancelled_warmups, 1);
    assert_eq!(stats.cancelled_working, 0);
}

#[tokio::test]
async fn persisted_workout_sets_keep_rest_values_across_db_reload() {
    let temp_dir = std::env::temp_dir().join(format!("schlift-test-{}", uuid::Uuid::new_v4()));
    let central_db = CentralDb::new_in_dir(&temp_dir).await.expect("db");
    let state = Arc::new(AppState::new());
    let workout_service = MyWorkoutService::new(central_db.clone(), state);

    let user = central_db
        .create_user_with_id("u1", "u1")
        .await
        .expect("user");
    let token = central_db
        .create_auth_session(&user.id)
        .await
        .expect("token");

    let started = WorkoutService::start_workout(
        &workout_service,
        with_token(
            StartWorkoutRequest {
                name: "w".to_string(),
                exercise_groups: vec![single_exercise_group("g1", "Squat", 155.0, 3, 0)],
                started_at: 0,
            },
            &token,
        ),
    )
    .await
    .expect("start")
    .into_inner();

    let _ = WorkoutService::replace_exercise_group_plan(
        &workout_service,
        with_token(
            replace_req_from_create(CreateExerciseGroupRequest {
                workout_id: started.id.clone(),
                name: "Bench".to_string(),
                sets: 2,
                interleave_warmups: false,
                exercise_configs: vec![ExerciseTypeConfig {
                    exercise: 2,
                    start_weight: 185.0,
                    end_weight: 185.0,
                    reps: 5,
                    include_warmup: true,
                    rest_config: Some(RestConfig {
                        rest_after_success: 95,
                        rest_after_failure: 205,
                        rest_after_warmup: 12,
                        rest_after_last_warmup: 95,
                    }),
                    last_set_amrap: false,
                    working_sets: vec![],
                }],
                rest_config: None,
            }),
            &token,
        ),
    )
    .await
    .expect("create group");

    let _ = WorkoutService::end_workout(
        &workout_service,
        with_token(
            EndWorkoutRequest {
                workout_id: started.id.clone(),
                ended_at: 0,
            },
            &token,
        ),
    )
    .await
    .expect("end");

    // Ended workouts are loaded from DB, not in-memory active state.
    // Persistence worker is async, so retry briefly until the workout is visible.
    let mut loaded = None;
    for _ in 0..25 {
        let result = WorkoutService::get_workout(
            &workout_service,
            with_token(
                GetWorkoutRequest {
                    workout_id: started.id.clone(),
                },
                &token,
            ),
        )
        .await;
        if let Ok(response) = result {
            loaded = Some(response.into_inner());
            break;
        }
        sleep(Duration::from_millis(20)).await;
    }
    let workout = loaded.expect("load from db");

    assert!(!workout.proposed_sets.is_empty());
    assert!(
        workout
            .proposed_sets
            .iter()
            .all(|set| set.rest_after_success > 0 && set.rest_after_failure > 0),
        "all proposed sets should carry persisted rest values"
    );
}

#[tokio::test]
async fn full_workout_flow_create_edit_reorder_complete_and_verify_db_state() {
    let temp_dir = std::env::temp_dir().join(format!("schlift-test-{}", uuid::Uuid::new_v4()));
    let central_db = CentralDb::new_in_dir(&temp_dir).await.expect("db");
    let state = Arc::new(AppState::new());
    let workout_service = MyWorkoutService::new(central_db.clone(), state);

    let user = central_db
        .create_user_with_id("u1", "u1")
        .await
        .expect("user");
    let token = central_db
        .create_auth_session(&user.id)
        .await
        .expect("token");

    // 1) Start workout with two groups.
    let started = WorkoutService::start_workout(
        &workout_service,
        with_token(
            StartWorkoutRequest {
                name: "integration".to_string(),
                exercise_groups: vec![
                    single_exercise_group("g1", "Squat", 100.0, 2, 0),
                    single_exercise_group("g2", "Bench", 150.0, 2, 1),
                ],
                started_at: 0,
            },
            &token,
        ),
    )
    .await
    .expect("start workout")
    .into_inner();

    let mut workout = WorkoutService::get_workout(
        &workout_service,
        with_token(
            GetWorkoutRequest {
                workout_id: started.id.clone(),
            },
            &token,
        ),
    )
    .await
    .expect("get workout after start")
    .into_inner();

    assert_eq!(workout.exercise_groups.len(), 2);
    assert_eq!(workout.exercise_groups[0].name, "Squat");
    assert_eq!(workout.exercise_groups[1].name, "Bench");
    assert_eq!(workout.proposed_sets.len(), 4);
    assert_eq!(workout.proposed_sets[0].exercise_group_id, "g1");
    assert_eq!(workout.proposed_sets[1].exercise_group_id, "g1");
    assert_eq!(workout.proposed_sets[2].exercise_group_id, "g2");
    assert_eq!(workout.proposed_sets[3].exercise_group_id, "g2");

    // 2) Create a third group.
    let created = WorkoutService::replace_exercise_group_plan(
        &workout_service,
        with_token(
            replace_req_from_create(CreateExerciseGroupRequest {
                workout_id: started.id.clone(),
                name: "Deadlift".to_string(),
                sets: 1,
                interleave_warmups: false,
                exercise_configs: vec![ExerciseTypeConfig {
                    exercise: 3,
                    start_weight: 200.0,
                    end_weight: 200.0,
                    reps: 5,
                    include_warmup: false,
                    rest_config: Some(RestConfig {
                        rest_after_success: 120,
                        rest_after_failure: 240,
                        rest_after_warmup: 10,
                        rest_after_last_warmup: 120,
                    }),
                    last_set_amrap: false,
                    working_sets: vec![],
                }],
                rest_config: None,
            }),
            &token,
        ),
    )
    .await
    .expect("create group")
    .into_inner();
    let g3_id = created.group.expect("created group").id;

    workout = WorkoutService::get_workout(
        &workout_service,
        with_token(
            GetWorkoutRequest {
                workout_id: started.id.clone(),
            },
            &token,
        ),
    )
    .await
    .expect("get workout after create group")
    .into_inner();
    assert_eq!(workout.exercise_groups.len(), 3);
    assert_eq!(workout.proposed_sets.len(), 5);

    // 3) Edit Bench group: 2 -> 3 sets, heavier weight.
    let _ = WorkoutService::replace_exercise_group_plan(
        &workout_service,
        with_token(
            replace_req_from_update(UpdateExerciseGroupRequest {
                workout_id: started.id.clone(),
                exercise_group_id: "g2".to_string(),
                name: "Bench Updated".to_string(),
                sets: 3,
                interleave_warmups: false,
                exercise_configs: vec![ExerciseTypeConfig {
                    exercise: 2,
                    start_weight: 155.0,
                    end_weight: 155.0,
                    reps: 5,
                    include_warmup: false,
                    rest_config: Some(RestConfig {
                        rest_after_success: 95,
                        rest_after_failure: 205,
                        rest_after_warmup: 10,
                        rest_after_last_warmup: 95,
                    }),
                    last_set_amrap: false,
                    working_sets: vec![],
                }],
                rest_config: None,
            }),
            &token,
        ),
    )
    .await
    .expect("update bench group");

    workout = WorkoutService::get_workout(
        &workout_service,
        with_token(
            GetWorkoutRequest {
                workout_id: started.id.clone(),
            },
            &token,
        ),
    )
    .await
    .expect("get workout after update")
    .into_inner();
    let bench_group = workout
        .exercise_groups
        .iter()
        .find(|g| g.id == "g2")
        .expect("bench group");
    assert_eq!(bench_group.name, "Bench Updated");
    let bench_sets = workout
        .proposed_sets
        .iter()
        .filter(|s| s.exercise_group_id == "g2")
        .collect::<Vec<_>>();
    let bench_active_sets = bench_sets
        .iter()
        .copied()
        .filter(|s| !s.cancelled)
        .collect::<Vec<_>>();
    let bench_cancelled_sets = bench_sets
        .iter()
        .copied()
        .filter(|s| s.cancelled)
        .collect::<Vec<_>>();
    assert_eq!(bench_active_sets.len(), 3);
    assert_eq!(bench_cancelled_sets.len(), 2);
    assert!(bench_active_sets.iter().all(|s| s.target_weight == 155.0));

    // 4) Reorder groups to: Deadlift, Squat, Bench Updated.
    let _ = WorkoutService::reorder_exercise_groups(
        &workout_service,
        with_token(
            ReorderExerciseGroupsRequest {
                workout_id: started.id.clone(),
                exercise_group_ids: vec![g3_id.clone(), "g1".to_string(), "g2".to_string()],
            },
            &token,
        ),
    )
    .await
    .expect("reorder");

    workout = WorkoutService::get_workout(
        &workout_service,
        with_token(
            GetWorkoutRequest {
                workout_id: started.id.clone(),
            },
            &token,
        ),
    )
    .await
    .expect("get workout after reorder")
    .into_inner();
    let mut groups_by_order = workout.exercise_groups.clone();
    groups_by_order.sort_by_key(|g| g.workout_order);
    let ordered_group_ids = groups_by_order
        .iter()
        .map(|g| g.id.clone())
        .collect::<Vec<_>>();
    assert_eq!(
        ordered_group_ids,
        vec![g3_id.clone(), "g1".to_string(), "g2".to_string()]
    );
    let ordered_set_group_ids = workout
        .proposed_sets
        .iter()
        .filter(|s| !s.cancelled)
        .map(|s| s.exercise_group_id.clone())
        .collect::<Vec<_>>();
    assert_eq!(
        ordered_set_group_ids,
        vec![
            g3_id.clone(),
            "g1".to_string(),
            "g1".to_string(),
            "g2".to_string(),
            "g2".to_string(),
            "g2".to_string(),
        ]
    );

    // 5) Complete all sets following next_up order.
    let mut completion_order = Vec::<String>::new();
    loop {
        let current = WorkoutService::get_workout(
            &workout_service,
            with_token(
                GetWorkoutRequest {
                    workout_id: started.id.clone(),
                },
                &token,
            ),
        )
        .await
        .expect("get workout during completion")
        .into_inner();

        let Some(next) = current.next_up_set else {
            break;
        };

        let _ = WorkoutService::start_set(
            &workout_service,
            with_token(
                StartSetRequest {
                    workout_id: started.id.clone(),
                    proposed_set_id: next.id.clone(),
                    started_at: 0,
                },
                &token,
            ),
        )
        .await
        .expect("start set");

        let _ = WorkoutService::complete_set(
            &workout_service,
            with_token(
                CompleteSetRequest {
                    workout_id: started.id.clone(),
                    proposed_set_id: next.id.clone(),
                    actual_reps: next.target_reps,
                    actual_weight: next.target_weight,
                    completed_at: 0,
                },
                &token,
            ),
        )
        .await
        .expect("complete set");
        completion_order.push(next.id);
    }

    workout = WorkoutService::get_workout(
        &workout_service,
        with_token(
            GetWorkoutRequest {
                workout_id: started.id.clone(),
            },
            &token,
        ),
    )
    .await
    .expect("get workout final")
    .into_inner();
    let expected_order = workout
        .proposed_sets
        .iter()
        .filter(|s| !s.cancelled)
        .map(|s| s.id.clone())
        .collect::<Vec<_>>();
    let mut seen = HashSet::<String>::new();
    let first_seen_completion_order = completion_order
        .into_iter()
        .filter(|id| seen.insert(id.clone()))
        .collect::<Vec<_>>();
    assert_eq!(first_seen_completion_order, expected_order);
    let snapshot = workout.state_snapshot.expect("state snapshot");
    assert_eq!(snapshot.state, 1, "expected WORKOUT_STATE_ALL_DONE");
    assert!(workout.next_up_set.is_none());

    // 6) End workout.
    let _ = WorkoutService::end_workout(
        &workout_service,
        with_token(
            EndWorkoutRequest {
                workout_id: started.id.clone(),
                ended_at: 0,
            },
            &token,
        ),
    )
    .await
    .expect("end workout");

    // 7) Verify DB final state matches expectations.
    let mut db_verified = false;
    for _ in 0..50 {
        let active = central_db
            .get_active_workout(&user.id)
            .await
            .expect("active query");
        let workout_db = central_db
            .get_workout(&user.id, &started.id)
            .await
            .expect("workout query");
        let groups_db = central_db
            .get_exercise_groups(&user.id, &started.id)
            .await
            .expect("groups query");
        let proposed_db = central_db
            .get_proposed_sets(&user.id, &started.id)
            .await
            .expect("proposed query");
        let completed_db = central_db
            .get_completed_sets(&user.id, &started.id)
            .await
            .expect("completed query");

        let groups_ok = groups_db.len() == 3
            && groups_db.iter().map(|g| g.id.as_str()).collect::<Vec<_>>()
                == vec![g3_id.as_str(), "g1", "g2"];
        let workout_ok = workout_db.as_ref().map(|w| w.end_time > 0).unwrap_or(false);
        let no_active_ok = active.is_none();
        let proposed_ok = proposed_db.len() == 6
            && proposed_db
                .iter()
                .all(|s| s.rest_after_success > 0 && s.rest_after_failure > 0);
        let completed_ended_ids = completed_db
            .iter()
            .filter(|c| c.ended_at > 0)
            .map(|c| c.proposed_set_id.clone())
            .collect::<HashSet<_>>();
        let completed_ok = completed_ended_ids.len() == 6
            && completed_ended_ids
                == proposed_db
                    .iter()
                    .filter(|s| !s.cancelled)
                    .map(|s| s.id.clone())
                    .collect::<HashSet<_>>();

        if groups_ok && workout_ok && no_active_ok && proposed_ok && completed_ok {
            db_verified = true;
            break;
        }
        sleep(Duration::from_millis(20)).await;
    }

    assert!(
        db_verified,
        "DB final state did not converge to expected values"
    );
}

#[tokio::test]
async fn full_workout_flow_cancel_warmup_delete_completed_and_verify_db_state() {
    let temp_dir = std::env::temp_dir().join(format!("schlift-test-{}", uuid::Uuid::new_v4()));
    let central_db = CentralDb::new_in_dir(&temp_dir).await.expect("db");
    let state = Arc::new(AppState::new());
    let workout_service = MyWorkoutService::new(central_db.clone(), state);

    let user = central_db
        .create_user_with_id("u1", "u1")
        .await
        .expect("user");
    let token = central_db
        .create_auth_session(&user.id)
        .await
        .expect("token");

    // 1) Start workout with warmups enabled to exercise cancel warmup path.
    let started = WorkoutService::start_workout(
        &workout_service,
        with_token(
            StartWorkoutRequest {
                name: "integration-warmup".to_string(),
                exercise_groups: vec![ExerciseGroup {
                    id: "g1".to_string(),
                    workout_id: String::new(),
                    name: "Squat".to_string(),
                    sets: 2,
                    interleave_warmups: false,
                    workout_order: 0,
                    exercise_configs: vec![ExerciseTypeConfig {
                        exercise: 1,
                        start_weight: 185.0,
                        end_weight: 185.0,
                        reps: 5,
                        include_warmup: true,
                        rest_config: Some(RestConfig {
                            rest_after_success: 90,
                            rest_after_failure: 180,
                            rest_after_warmup: 12,
                            rest_after_last_warmup: 90,
                        }),
                        last_set_amrap: false,
                        working_sets: vec![],
                    }],
                    rest_config: None,
                    instruction: String::new(),
                    prescribed_by_regime: false,
                }],
                started_at: 0,
            },
            &token,
        ),
    )
    .await
    .expect("start workout")
    .into_inner();

    let mut workout = WorkoutService::get_workout(
        &workout_service,
        with_token(
            GetWorkoutRequest {
                workout_id: started.id.clone(),
            },
            &token,
        ),
    )
    .await
    .expect("workout after start")
    .into_inner();

    let warmup_id = workout
        .proposed_sets
        .iter()
        .find(|s| s.warmup)
        .expect("warmup exists")
        .id
        .clone();

    // 2) Cancel one warmup.
    let _ = WorkoutService::cancel_proposed_set(
        &workout_service,
        with_token(
            CancelProposedSetRequest {
                workout_id: started.id.clone(),
                proposed_set_id: warmup_id.clone(),
            },
            &token,
        ),
    )
    .await
    .expect("cancel warmup");

    workout = WorkoutService::get_workout(
        &workout_service,
        with_token(
            GetWorkoutRequest {
                workout_id: started.id.clone(),
            },
            &token,
        ),
    )
    .await
    .expect("workout after cancel warmup")
    .into_inner();
    assert!(workout
        .proposed_sets
        .iter()
        .any(|s| s.id == warmup_id && s.cancelled));
    assert!(!workout
        .proposed_sets
        .iter()
        .any(|s| s.id == warmup_id && !s.cancelled));

    // 3) Complete first next-up set, then delete that completed set.
    let first_next = workout.next_up_set.expect("next set exists");
    let _ = WorkoutService::start_set(
        &workout_service,
        with_token(
            StartSetRequest {
                workout_id: started.id.clone(),
                proposed_set_id: first_next.id.clone(),
                started_at: 0,
            },
            &token,
        ),
    )
    .await
    .expect("start first set");

    let completed_first = WorkoutService::complete_set(
        &workout_service,
        with_token(
            CompleteSetRequest {
                workout_id: started.id.clone(),
                proposed_set_id: first_next.id.clone(),
                actual_reps: first_next.target_reps,
                actual_weight: first_next.target_weight,
                completed_at: 0,
            },
            &token,
        ),
    )
    .await
    .expect("complete first set")
    .into_inner()
    .completed_set
    .expect("completed set response");

    let _ = WorkoutService::delete_completed_set(
        &workout_service,
        with_token(
            DeleteCompletedSetRequest {
                workout_id: started.id.clone(),
                completed_set_id: completed_first.id.clone(),
            },
            &token,
        ),
    )
    .await
    .expect("delete completed set");

    workout = WorkoutService::get_workout(
        &workout_service,
        with_token(
            GetWorkoutRequest {
                workout_id: started.id.clone(),
            },
            &token,
        ),
    )
    .await
    .expect("workout after delete completed")
    .into_inner();
    assert!(
        !workout
            .completed_sets
            .iter()
            .any(|c| c.id == completed_first.id),
        "deleted completed set should be gone"
    );
    let next_after_delete = workout.next_up_set.expect("next should exist");
    assert_eq!(next_after_delete.id, first_next.id);

    // 4) Complete all remaining sets in next_up order.
    let mut completed_ids = HashSet::<String>::new();
    loop {
        let current = WorkoutService::get_workout(
            &workout_service,
            with_token(
                GetWorkoutRequest {
                    workout_id: started.id.clone(),
                },
                &token,
            ),
        )
        .await
        .expect("get workout in finish loop")
        .into_inner();

        let Some(next) = current.next_up_set else {
            break;
        };

        let _ = WorkoutService::start_set(
            &workout_service,
            with_token(
                StartSetRequest {
                    workout_id: started.id.clone(),
                    proposed_set_id: next.id.clone(),
                    started_at: 0,
                },
                &token,
            ),
        )
        .await
        .expect("start next");

        let done = WorkoutService::complete_set(
            &workout_service,
            with_token(
                CompleteSetRequest {
                    workout_id: started.id.clone(),
                    proposed_set_id: next.id,
                    actual_reps: next.target_reps,
                    actual_weight: next.target_weight,
                    completed_at: 0,
                },
                &token,
            ),
        )
        .await
        .expect("complete next")
        .into_inner()
        .completed_set
        .expect("completed");
        completed_ids.insert(done.proposed_set_id);
    }

    workout = WorkoutService::get_workout(
        &workout_service,
        with_token(
            GetWorkoutRequest {
                workout_id: started.id.clone(),
            },
            &token,
        ),
    )
    .await
    .expect("workout all done")
    .into_inner();
    let snapshot = workout.state_snapshot.expect("snapshot");
    assert_eq!(snapshot.state, 1, "expected WORKOUT_STATE_ALL_DONE");
    assert!(workout.next_up_set.is_none());

    // 5) End workout.
    let _ = WorkoutService::end_workout(
        &workout_service,
        with_token(
            EndWorkoutRequest {
                workout_id: started.id.clone(),
                ended_at: 0,
            },
            &token,
        ),
    )
    .await
    .expect("end workout");

    // 6) Verify DB final state converges.
    let mut db_verified = false;
    for _ in 0..50 {
        let active = central_db
            .get_active_workout(&user.id)
            .await
            .expect("active query");
        let workout_db = central_db
            .get_workout(&user.id, &started.id)
            .await
            .expect("workout query");
        let proposed_db = central_db
            .get_proposed_sets(&user.id, &started.id)
            .await
            .expect("proposed query");
        let completed_db = central_db
            .get_completed_sets(&user.id, &started.id)
            .await
            .expect("completed query");

        let workout_ok = workout_db.as_ref().map(|w| w.end_time > 0).unwrap_or(false);
        let no_active_ok = active.is_none();
        let proposed_ok = proposed_db
            .iter()
            .all(|s| s.rest_after_success > 0 && s.rest_after_failure > 0);
        let completed_ended_ids = completed_db
            .iter()
            .filter(|c| c.ended_at > 0)
            .map(|c| c.proposed_set_id.clone())
            .collect::<HashSet<_>>();
        let completed_ok = !completed_ended_ids.is_empty() && completed_ended_ids == completed_ids;

        if workout_ok && no_active_ok && proposed_ok && completed_ok {
            db_verified = true;
            break;
        }
        sleep(Duration::from_millis(20)).await;
    }

    assert!(
        db_verified,
        "DB final state did not converge for warmup-cancel/delete-completed flow"
    );
}

/// Regression test for deadlock: DashMap sync locks held across .await points
/// in append_workout_mutations would block tokio threads when multiplayer
/// get_current_session polls concurrently. With 1-2 tokio worker threads
/// (production OCI with 1 vCPU), this deadlocks the entire server.
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn concurrent_mutations_and_session_poll_does_not_deadlock() {
    use schlift::workout::v1::workout_mutation;

    let temp_dir = std::env::temp_dir().join(format!("schlift-test-{}", uuid::Uuid::new_v4()));
    let central_db = CentralDb::new_in_dir(&temp_dir).await.expect("db");
    let state = Arc::new(AppState::new());
    let workout_service = Arc::new(MyWorkoutService::new(central_db.clone(), state.clone()));
    let group_service = Arc::new(GroupService::new(central_db.clone(), state));

    // Create two users
    let user1 = central_db
        .create_user_with_id("u1", "u1")
        .await
        .expect("user1");
    let user2 = central_db
        .create_user_with_id("u2", "u2")
        .await
        .expect("user2");
    let token1 = central_db
        .create_auth_session(&user1.id)
        .await
        .expect("token1");
    let token2 = central_db
        .create_auth_session(&user2.id)
        .await
        .expect("token2");

    // Start workouts for both users
    let start1 = WorkoutService::start_workout(
        &*workout_service,
        with_token(
            StartWorkoutRequest {
                name: "w1".to_string(),
                exercise_groups: vec![single_exercise_group("g1", "Squat", 100.0, 3, 0)],
                started_at: 0,
            },
            &token1,
        ),
    )
    .await
    .expect("start1")
    .into_inner();

    let _start2 = WorkoutService::start_workout(
        &*workout_service,
        with_token(
            StartWorkoutRequest {
                name: "w2".to_string(),
                exercise_groups: vec![single_exercise_group("g2", "Bench", 150.0, 3, 0)],
                started_at: 0,
            },
            &token2,
        ),
    )
    .await
    .expect("start2");

    // Join session (user1 joins user2)
    let _ = MultiplayerService::join_user(
        &*group_service,
        with_token(
            JoinUserRequest {
                user_id: user2.id.clone(),
            },
            &token1,
        ),
    )
    .await
    .expect("join");

    // Get proposed set IDs for user1
    let w1 = WorkoutService::get_workout(
        &*workout_service,
        with_token(
            GetWorkoutRequest {
                workout_id: start1.id.clone(),
            },
            &token1,
        ),
    )
    .await
    .expect("w1")
    .into_inner();
    let proposed_set_ids: Vec<String> = w1
        .proposed_sets
        .iter()
        .filter(|s| !s.warmup && !s.cancelled)
        .map(|s| s.id.clone())
        .collect();
    assert!(proposed_set_ids.len() >= 3, "Need at least 3 proposed sets");

    // Fire off concurrent tasks:
    // Task A: user1 sends mutations (start_set + complete_set via append_workout_mutations)
    // Task B: user2 polls get_current_session in a tight loop
    //
    // With the old code (DashMap lock held across .await), this deadlocks
    // within a few iterations because both tasks need the same DashMap shard.

    let ws = workout_service.clone();
    let gs = group_service.clone();
    let t1 = token1.clone();
    let t2 = token2.clone();
    let w1_id = start1.id.clone();
    let ps_ids = proposed_set_ids.clone();

    let mutation_task = tokio::spawn(async move {
        for ps_id in &ps_ids {
            // Send start_set as a mutation batch
            let start_mutation = schlift::workout::v1::WorkoutMutation {
                event_id: uuid::Uuid::new_v4().to_string(),
                client_created_at: 0,
                mutation: Some(workout_mutation::Mutation::StartSet(StartSetRequest {
                    workout_id: w1_id.clone(),
                    proposed_set_id: ps_id.clone(),
                    started_at: 0,
                })),
            };
            let complete_mutation = schlift::workout::v1::WorkoutMutation {
                event_id: uuid::Uuid::new_v4().to_string(),
                client_created_at: 0,
                mutation: Some(workout_mutation::Mutation::CompleteSet(
                    CompleteSetRequest {
                        workout_id: w1_id.clone(),
                        proposed_set_id: ps_id.clone(),
                        actual_reps: 5,
                        actual_weight: 100.0,
                        completed_at: 0,
                    },
                )),
            };
            WorkoutService::append_workout_mutations(
                &*ws,
                with_token(
                    schlift::workout::v1::AppendWorkoutMutationsRequest {
                        mutations: vec![start_mutation, complete_mutation],
                    },
                    &t1,
                ),
            )
            .await
            .expect("mutation should succeed");
        }
    });

    let poll_task = tokio::spawn(async move {
        // Poll aggressively — this is what the Flutter client does at 1s intervals
        for _ in 0..20 {
            let _ = MultiplayerService::get_current_session(
                &*gs,
                with_token(GetCurrentSessionRequest::default(), &t2),
            )
            .await;
            tokio::task::yield_now().await;
        }
    });

    // If this test deadlocks, the timeout will catch it.
    let result = tokio::time::timeout(Duration::from_secs(10), async {
        let (r1, r2) = tokio::join!(mutation_task, poll_task);
        r1.expect("mutation task panicked");
        r2.expect("poll task panicked");
    })
    .await;

    assert!(
        result.is_ok(),
        "Deadlock detected: concurrent mutations + session polling timed out"
    );

    let _ = std::fs::remove_dir_all(&temp_dir);
}
