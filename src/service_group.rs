use crate::db::CentralDb;
use crate::progress::{compute_participant_progress, compute_session_next_up};
use crate::service_workout::get_user_id_authenticated;
use crate::state::AppState;
use lift::workout::v1::multiplayer_service_server::MultiplayerService;
use lift::workout::v1::*;
use std::collections::HashSet;
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
            let members = self
                .state
                .sessions
                .get(&sid)
                .map(|r| r.clone())
                .unwrap_or_default();

            // Try to recover all members to ensure they are in memory
            for member_id in &members {
                self.state
                    .try_recover_user(&self.central_db, member_id)
                    .await;
            }

            // Re-read members after recovery in case more were found
            let members = self
                .state
                .sessions
                .get(&sid)
                .map(|r| r.clone())
                .unwrap_or_default();

            let mut participant_statuses = Vec::new();
            for member_id in &members {
                participant_statuses.push(self.build_participant_status(member_id));
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
        CancelProposedSetRequest, CompleteSetRequest, ExerciseGroup, ExerciseTypeConfig,
        GetCurrentSessionRequest, GetWorkoutRequest, JoinUserRequest, RestConfig, StartSetRequest,
        StartWorkoutRequest, UpdateExerciseGroupRequest,
    };
    use std::sync::Arc;
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
}
