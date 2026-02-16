use std::collections::HashSet;
use std::sync::Arc;
use tonic::{Request, Response, Status};
use crate::db::CentralDb;
use crate::service_workout::get_user_id_authenticated;
use crate::state::AppState;
use lift::workout::v1::multiplayer_service_server::MultiplayerService;
use lift::workout::v1::*;

#[derive(Clone)]
pub struct GroupService {
    central_db: CentralDb,
    state: Arc<AppState>,
}

impl GroupService {
    pub fn new(central_db: CentralDb, state: Arc<AppState>) -> Self {
        Self {
            central_db,
            state,
        }
    }

    fn build_participant_status(&self, user_id: &str) -> ParticipantStatus {
        let user = self.state.users.get(user_id)
            .map(|u| u.clone())
            .unwrap_or_else(|| User {
                id: user_id.to_string(),
                name: String::new(),
                created_at: 0,
            });

        if let Some(w) = self.state.workouts.get(user_id) {
            ParticipantStatus {
                user: Some(user),
                active_workout_id: w.workout.id.clone(),
                active_workout: Some(w.workout.clone()),
                exercise_groups: w.exercise_groups.clone(),
                proposed_sets: w.proposed_sets.clone(),
                completed_sets: w.completed_sets.clone(),
            }
        } else {
            ParticipantStatus {
                user: Some(user),
                active_workout_id: String::new(),
                ..Default::default()
            }
        }
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
        self.state.try_recover_user(&self.central_db, &caller_id).await;
        self.state.try_recover_user(&self.central_db, &target_id).await;

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
                self.state.user_sessions.insert(caller_id.clone(), t_sid.clone());
                self.state.sessions.entry(t_sid.clone()).or_insert_with(HashSet::new).insert(caller_id.clone());
                self.central_db.join_session(&caller_id, &t_sid).await
                    .map_err(|e| Status::internal(e.to_string()))?;
                t_sid
            }
            (Some(c_sid), None) => {
                // Target joins caller's session
                self.state.user_sessions.insert(target_id.clone(), c_sid.clone());
                self.state.sessions.entry(c_sid.clone()).or_insert_with(HashSet::new).insert(target_id.clone());
                self.central_db.join_session(&target_id, &c_sid).await
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
                        self.state.user_sessions.insert(caller_id.clone(), sid.clone());
                        self.state.sessions.entry(sid.clone()).or_insert_with(HashSet::new).insert(caller_id.clone());
                        self.central_db.join_session(&caller_id, &sid).await
                            .map_err(|e| Status::internal(e.to_string()))?;
                        sid
                    }
                    Entry::Vacant(vacant) => {
                        vacant.insert(sid.clone());
                        self.state.user_sessions.insert(caller_id.clone(), sid.clone());
                        
                        let mut members = HashSet::new();
                        members.insert(caller_id.clone());
                        members.insert(target_id.clone());
                        self.state.sessions.insert(sid.clone(), members);

                        self.central_db.join_session(&caller_id, &sid).await
                            .map_err(|e| Status::internal(e.to_string()))?;
                        self.central_db.join_session(&target_id, &sid).await
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

        Ok(Response::new(JoinUserResponse {
            session_id,
        }))
    }

    async fn leave_session(
        &self,
        request: Request<LeaveSessionRequest>,
    ) -> Result<Response<LeaveSessionResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        self.state.try_recover_user(&self.central_db, &user_id).await;

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
        self.state.try_recover_user(&self.central_db, &req.user_id).await;

        // Read directly from in-memory state
        let status = self.build_participant_status(&req.user_id);
        if status.active_workout_id.is_empty() {
            return Err(Status::not_found("Participant not in an active session or workout not found"));
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
        self.state.try_recover_user(&self.central_db, &user_id).await;

        // Determine session ID
        let session_id = if !req.session_id.is_empty() {
            Some(req.session_id)
        } else {
            self.state.user_sessions.get(&user_id).map(|r| r.clone())
        };

        if let Some(sid) = session_id {
            let members = self.state.sessions.get(&sid)
                .map(|r| r.clone())
                .unwrap_or_default();

            // Try to recover all members to ensure they are in memory
            for member_id in &members {
                self.state.try_recover_user(&self.central_db, member_id).await;
            }

            // Re-read members after recovery in case more were found
            let members = self.state.sessions.get(&sid)
                .map(|r| r.clone())
                .unwrap_or_default();

            let mut participant_statuses = Vec::new();
            for member_id in &members {
                participant_statuses.push(self.build_participant_status(member_id));
            }

            Ok(Response::new(GetCurrentSessionResponse {
                session_id: sid.clone(),
                session_status: Some(SessionStatus {
                    session_id: sid,
                    participants: participant_statuses,
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
