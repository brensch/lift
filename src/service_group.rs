use crate::db::CentralDb;
use crate::progress::{compute_participant_progress, compute_session_next_up};
use crate::service_workout::get_user_id_authenticated;
use crate::state::AppState;
use lift::workout::v1::multiplayer_service_server::MultiplayerService;
use lift::workout::v1::*;
use std::collections::{HashMap, HashSet};
use std::sync::Arc;
use tonic::{Request, Response, Status};

#[derive(Clone)]
pub struct GroupService {
    central_db: CentralDb,
    state: Arc<AppState>,
}

impl GroupService {
    pub fn new(central_db: CentralDb, state: Arc<AppState>) -> Self {
        Self { central_db, state }
    }

    fn build_participant_status(&self, user_id: &str) -> ParticipantStatus {
        let user = self
            .state
            .users
            .get(user_id)
            .map(|u| u.clone())
            .unwrap_or_else(|| User {
                id: user_id.to_string(),
                name: String::new(),
                created_at: 0,
            });

        if let Some(w) = self.state.workouts.get(user_id) {
            let proposed_sets: Vec<ProposedSet> = w
                .proposed_sets
                .iter()
                .filter(|set| !set.cancelled)
                .cloned()
                .collect();
            let progress = compute_participant_progress(&proposed_sets, &w.completed_sets);
            ParticipantStatus {
                user: Some(user),
                active_workout_id: w.workout.id.clone(),
                active_workout: Some(w.workout.clone()),
                exercise_groups: w.exercise_groups.clone(),
                proposed_sets,
                completed_sets: w.completed_sets.clone(),
                next_up_set: progress.next_up_set,
                rest_until: progress.rest_until,
                has_active_set: progress.has_active_set,
            }
        } else {
            ParticipantStatus {
                user: Some(user),
                active_workout_id: String::new(),
                ..Default::default()
            }
        }
    }

    fn current_lifting_user_id(participants: &[ParticipantStatus]) -> String {
        participants
            .iter()
            .filter_map(|participant| {
                if !participant.has_active_set {
                    return None;
                }
                let started_at = participant
                    .completed_sets
                    .iter()
                    .filter(|set| set.ended_at == 0)
                    .map(|set| set.started_at)
                    .max()
                    .unwrap_or(0);
                let user_id = participant
                    .user
                    .as_ref()
                    .map(|u| u.id.clone())
                    .unwrap_or_default();
                Some((started_at, user_id))
            })
            .max_by_key(|(started_at, _)| *started_at)
            .map(|(_, user_id)| user_id)
            .unwrap_or_default()
    }
}

#[tonic::async_trait]
impl MultiplayerService for GroupService {
    async fn join_user(
        &self,
        request: Request<JoinUserRequest>,
    ) -> Result<Response<JoinUserResponse>, Status> {
        let caller_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let target_id = request.into_inner().user_id;

        if caller_id == target_id {
            return Err(Status::invalid_argument("Cannot join yourself"));
        }

        // Recover both users to ensure we have their latest session info
        self.state
            .try_recover_user(&self.central_db, &caller_id)
            .await;
        self.state
            .try_recover_user(&self.central_db, &target_id)
            .await;

        let caller_session_id = self.state.user_sessions.get(&caller_id).map(|r| r.clone());
        let target_session_id = self.state.user_sessions.get(&target_id).map(|r| r.clone());

        let session_id = match (caller_session_id, target_session_id) {
            (Some(c_sid), Some(t_sid)) => {
                if c_sid == t_sid {
                    c_sid
                } else {
                    return Err(Status::failed_precondition("Both users are already in different active sessions. Leave your current session first."));
                }
            }
            (None, Some(t_sid)) => {
                // Caller joins target's session
                self.state
                    .user_sessions
                    .insert(caller_id.clone(), t_sid.clone());
                self.state
                    .sessions
                    .entry(t_sid.clone())
                    .or_insert_with(HashSet::new)
                    .insert(caller_id.clone());
                self.central_db
                    .join_session(&caller_id, &t_sid)
                    .await
                    .map_err(|e| Status::internal(e.to_string()))?;
                t_sid
            }
            (Some(c_sid), None) => {
                // Target joins caller's session
                self.state
                    .user_sessions
                    .insert(target_id.clone(), c_sid.clone());
                self.state
                    .sessions
                    .entry(c_sid.clone())
                    .or_insert_with(HashSet::new)
                    .insert(target_id.clone());
                self.central_db
                    .join_session(&target_id, &c_sid)
                    .await
                    .map_err(|e| Status::internal(e.to_string()))?;
                c_sid
            }
            (None, None) => {
                // Create new session for both
                let sid = uuid::Uuid::new_v4().to_string();

                // Use entry logic to avoid race conditions where both create sessions simultaneously
                use dashmap::mapref::entry::Entry;
                match self.state.user_sessions.entry(target_id.clone()) {
                    Entry::Occupied(existing) => {
                        // Someone else just put the target in a session
                        let sid = existing.get().clone();
                        self.state
                            .user_sessions
                            .insert(caller_id.clone(), sid.clone());
                        self.state
                            .sessions
                            .entry(sid.clone())
                            .or_insert_with(HashSet::new)
                            .insert(caller_id.clone());
                        self.central_db
                            .join_session(&caller_id, &sid)
                            .await
                            .map_err(|e| Status::internal(e.to_string()))?;
                        sid
                    }
                    Entry::Vacant(vacant) => {
                        vacant.insert(sid.clone());
                        self.state
                            .user_sessions
                            .insert(caller_id.clone(), sid.clone());

                        let mut members = HashSet::new();
                        members.insert(caller_id.clone());
                        members.insert(target_id.clone());
                        self.state.sessions.insert(sid.clone(), members);

                        self.central_db
                            .join_session(&caller_id, &sid)
                            .await
                            .map_err(|e| Status::internal(e.to_string()))?;
                        self.central_db
                            .join_session(&target_id, &sid)
                            .await
                            .map_err(|e| Status::internal(e.to_string()))?;
                        sid
                    }
                }
            }
        };

        // Cache user info if needed
        for uid in &[&caller_id, &target_id] {
            if !self.state.users.contains_key(*uid) {
                if let Ok(Some(user)) = self.central_db.get_user(uid).await {
                    self.state.users.insert(uid.to_string(), user);
                }
            }

            // Update active workout with session_id if exists
            if let Some(mut active) = self.state.workouts.get_mut(*uid) {
                if active.workout.session_id != session_id {
                    active.workout.session_id = session_id.clone();
                    let _ = self
                        .central_db
                        .update_workout_session_id(uid, &active.workout.id, &session_id)
                        .await;
                }
            }
        }

        Ok(Response::new(JoinUserResponse { session_id }))
    }

    async fn leave_session(
        &self,
        request: Request<LeaveSessionRequest>,
    ) -> Result<Response<LeaveSessionResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        if let Some((_, session_id)) = self.state.user_sessions.remove(&user_id) {
            if let Some(mut members) = self.state.sessions.get_mut(&session_id) {
                members.remove(&user_id);
                if members.is_empty() {
                    drop(members);
                    self.state.sessions.remove(&session_id);
                }
            }
            // Record in user's DB
            let _ = self.central_db.leave_session(&user_id, &session_id).await;
        }

        Ok(Response::new(LeaveSessionResponse {}))
    }

    async fn get_participant_workout(
        &self,
        request: Request<GetParticipantWorkoutRequest>,
    ) -> Result<Response<ParticipantStatus>, Status> {
        let _ = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        // Ensure target is recovered if possible
        self.state
            .try_recover_user(&self.central_db, &req.user_id)
            .await;

        // Read directly from in-memory state
        let status = self.build_participant_status(&req.user_id);
        if status.active_workout_id.is_empty() {
            return Err(Status::not_found(
                "Participant not in an active session or workout not found",
            ));
        }

        Ok(Response::new(status))
    }

    async fn get_current_session(
        &self,
        request: Request<GetCurrentSessionRequest>,
    ) -> Result<Response<GetCurrentSessionResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        // Ensure user is recovered if possible
        self.state
            .try_recover_user(&self.central_db, &user_id)
            .await;

        // Determine session ID
        let session_id = if !req.session_id.is_empty() {
            Some(req.session_id)
        } else {
            self.state.user_sessions.get(&user_id).map(|r| r.clone())
        };

        if let Some(sid) = session_id {
            // 1. Get all participants (active + finished)
            let session_members = self
                .central_db
                .get_session_participants(&sid)
                .await
                .unwrap_or_default();

            // 2. Get all workout data for the session in bulk
            let (workouts_with_user, all_groups, all_proposed, all_completed) = self
                .central_db
                .get_session_workout_data(&sid)
                .await
                .unwrap_or_default();

            // 3. Index data for efficient assembly
            let workouts_by_user: HashMap<String, Workout> = workouts_with_user.into_iter().collect();

            let mut groups_by_workout: HashMap<String, Vec<ExerciseGroup>> = HashMap::new();
            for g in all_groups {
                groups_by_workout.entry(g.workout_id.clone()).or_default().push(g);
            }

            let mut proposed_by_workout: HashMap<String, Vec<ProposedSet>> = HashMap::new();
            for p in all_proposed {
                proposed_by_workout.entry(p.workout_id.clone()).or_default().push(p);
            }

            let mut completed_by_workout: HashMap<String, Vec<CompletedSet>> = HashMap::new();
            for c in all_completed {
                completed_by_workout.entry(c.workout_id.clone()).or_default().push(c);
            }

            let mut participant_statuses = Vec::new();
            for member_id in &session_members {
                // Get user info (check cache first)
                let user = if let Some(u) = self.state.users.get(member_id) {
                    u.clone()
                } else {
                    self.central_db
                        .get_user(member_id)
                        .await
                        .ok()
                        .flatten()
                        .unwrap_or_else(|| User {
                            id: member_id.clone(),
                            name: String::new(),
                            created_at: 0,
                        })
                };

                if let Some(workout) = workouts_by_user.get(member_id) {
                    let groups = groups_by_workout.remove(&workout.id).unwrap_or_default();
                    let proposed = proposed_by_workout.remove(&workout.id).unwrap_or_default();
                    let completed = completed_by_workout.remove(&workout.id).unwrap_or_default();

                    let proposed_active: Vec<ProposedSet> =
                        proposed.iter().filter(|s| !s.cancelled).cloned().collect();
                    let progress = compute_participant_progress(&proposed_active, &completed);

                    participant_statuses.push(ParticipantStatus {
                        user: Some(user),
                        active_workout_id: workout.id.clone(),
                        active_workout: Some(workout.clone()),
                        exercise_groups: groups,
                        proposed_sets: proposed_active,
                        completed_sets: completed,
                        next_up_set: progress.next_up_set,
                        rest_until: progress.rest_until,
                        has_active_set: progress.has_active_set,
                    });
                } else {
                    // Just a lurker
                    participant_statuses.push(ParticipantStatus {
                        user: Some(user),
                        active_workout_id: String::new(),
                        ..Default::default()
                    });
                }
            }

            let now_unix = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.as_secs() as i64)
                .unwrap_or(0);
            let session_next_up = compute_session_next_up(&participant_statuses, now_unix);
            let currently_lifting_user_id = Self::current_lifting_user_id(&participant_statuses);

            Ok(Response::new(GetCurrentSessionResponse {
                session_id: sid.clone(),
                session_status: Some(SessionStatus {
                    session_id: sid,
                    participants: participant_statuses,
                    next_up_user_id: session_next_up
                        .as_ref()
                        .map(|n| n.user_id.clone())
                        .unwrap_or_default(),
                    next_up_set: session_next_up.as_ref().map(|n| n.next_up_set.clone()),
                    next_up_rest_until: session_next_up.as_ref().map(|n| n.rest_until).unwrap_or(0),
                    currently_lifting_user_id,
                }),
            }))
        } else {
            Ok(Response::new(GetCurrentSessionResponse {
                session_id: String::new(),
                session_status: None,
            }))
        }
    }

    async fn update_active_workout(
        &self,
        request: Request<UpdateActiveWorkoutRequest>,
    ) -> Result<Response<UpdateActiveWorkoutResponse>, Status> {
        let _user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        // No-op: workout state is read directly from AppState.workouts
        Ok(Response::new(UpdateActiveWorkoutResponse {}))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::service_workout::MyWorkoutService;
    use crate::state::AppState;
    use lift::workout::v1::workout_service_server::WorkoutService;
    use lift::workout::v1::{
        CancelProposedSetRequest, CompleteSetRequest, CreateExerciseGroupRequest,
        DeleteCompletedSetRequest, EndWorkoutRequest, ExerciseGroup, ExerciseTypeConfig,
        GetCurrentSessionRequest, GetWorkoutRequest, JoinUserRequest, ReorderExerciseGroupsRequest,
        RestConfig, StartSetRequest, StartWorkoutRequest, UpdateExerciseGroupRequest,
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
            }],
            rest_config: None,
        }
    }

    #[tokio::test]
    async fn api_flow_exposes_next_up_after_mid_workout_group_update() {
        let temp_dir = std::env::temp_dir().join(format!("lift-test-{}", uuid::Uuid::new_v4()));
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

        let _ = WorkoutService::update_exercise_group(
            &workout_service,
            with_token(
                UpdateExerciseGroupRequest {
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
                    }],
                    rest_config: None,
                },
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
        let temp_dir = std::env::temp_dir().join(format!("lift-test-{}", uuid::Uuid::new_v4()));
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

        let u1_status = session
            .participants
            .iter()
            .find(|p| p.user.as_ref().map(|u| u.id.as_str()) == Some("u1"))
            .expect("u1 status");
        assert!(u1_status.has_active_set);

        let u2_status = session
            .participants
            .iter()
            .find(|p| p.user.as_ref().map(|u| u.id.as_str()) == Some("u2"))
            .expect("u2 status");
        assert!(!u2_status.has_active_set);
        assert!(u2_status.next_up_set.is_some());
    }

    #[tokio::test]
    async fn api_flow_cancel_warmup_tracks_plan_change_stats() {
        let temp_dir = std::env::temp_dir().join(format!("lift-test-{}", uuid::Uuid::new_v4()));
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
                        }],
                        rest_config: None,
                    }],
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

        assert!(workout_after.proposed_sets.iter().all(|set| !set.cancelled));
        assert!(workout_after
            .proposed_sets
            .iter()
            .all(|set| set.id != warmup_to_cancel));
        let stats = workout_after
            .plan_change_stats
            .expect("plan change stats expected");
        assert_eq!(stats.cancelled_total, 1);
        assert_eq!(stats.cancelled_warmups, 1);
        assert_eq!(stats.cancelled_working, 0);
    }

    #[tokio::test]
    async fn persisted_workout_sets_keep_rest_values_across_db_reload() {
        let temp_dir = std::env::temp_dir().join(format!("lift-test-{}", uuid::Uuid::new_v4()));
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
                },
                &token,
            ),
        )
        .await
        .expect("start")
        .into_inner();

        let _ = WorkoutService::create_exercise_group(
            &workout_service,
            with_token(
                CreateExerciseGroupRequest {
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
                    }],
                    rest_config: None,
                },
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
        let temp_dir = std::env::temp_dir().join(format!("lift-test-{}", uuid::Uuid::new_v4()));
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
        let created = WorkoutService::create_exercise_group(
            &workout_service,
            with_token(
                CreateExerciseGroupRequest {
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
                    }],
                    rest_config: None,
                },
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
        let _ = WorkoutService::update_exercise_group(
            &workout_service,
            with_token(
                UpdateExerciseGroupRequest {
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
                    }],
                    rest_config: None,
                },
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
        assert_eq!(bench_sets.len(), 3);
        assert!(bench_sets.iter().all(|s| s.target_weight == 155.0));

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
            .map(|s| s.id.clone())
            .collect::<Vec<_>>();
        assert_eq!(completion_order, expected_order);
        let snapshot = workout.state_snapshot.expect("state snapshot");
        assert_eq!(snapshot.state, 1, "expected WORKOUT_STATE_ALL_DONE");
        assert!(workout.next_up_set.is_none());

        // 6) End workout.
        let _ = WorkoutService::end_workout(
            &workout_service,
            with_token(
                EndWorkoutRequest {
                    workout_id: started.id.clone(),
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
            let completed_ok = completed_db.len() == 6
                && completed_db.iter().all(|c| c.ended_at > 0)
                && completed_db
                    .iter()
                    .map(|c| c.proposed_set_id.clone())
                    .collect::<HashSet<_>>()
                    .len()
                    == 6;

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
        let temp_dir = std::env::temp_dir().join(format!("lift-test-{}", uuid::Uuid::new_v4()));
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
                        }],
                        rest_config: None,
                    }],
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
        assert!(workout.proposed_sets.iter().all(|s| s.id != warmup_id));

        // 3) Complete first next-up set, then delete that completed set.
        let first_next = workout.next_up_set.expect("next set exists");
        let _ = WorkoutService::start_set(
            &workout_service,
            with_token(
                StartSetRequest {
                    workout_id: started.id.clone(),
                    proposed_set_id: first_next.id.clone(),
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
            let completed_ok = !completed_db.is_empty()
                && completed_db.iter().all(|c| c.ended_at > 0)
                && completed_db
                    .iter()
                    .map(|c| c.proposed_set_id.clone())
                    .collect::<HashSet<_>>()
                    .len()
                    == completed_db.len()
                && completed_db
                    .iter()
                    .all(|c| completed_ids.contains(&c.proposed_set_id));

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
}
