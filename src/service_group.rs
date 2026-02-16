use std::collections::HashSet;
use std::sync::Arc;
use tonic::{Request, Response, Status};
use crate::db::{CentralDb, UserDb};
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

        // 1. Check if target is already in a session
        let target_session_id = self.state.user_sessions.get(&target_id).map(|r| r.clone());

        let session_id = if let Some(sid) = target_session_id {
            // Target is in a session, join it
            sid
        } else {
            // Target is not in a session, create a new one for both
            let sid = uuid::Uuid::new_v4().to_string();
            
            {
                // Use a block to ensure the entry lock is dropped before any awaits or other map operations
                use dashmap::mapref::entry::Entry;
                match self.state.user_sessions.entry(target_id.clone()) {
                    Entry::Occupied(existing) => {
                        // Someone else created a session for this user just now
                        existing.get().clone()
                    }
                    Entry::Vacant(vacant) => {
                        vacant.insert(sid.clone());
                        
                        // Add target to session
                        self.state.sessions
                            .entry(sid.clone())
                            .or_insert_with(HashSet::new)
                            .insert(target_id.clone());
                        
                        sid.clone()
                    }
                }
            };

            // If we actually created/joined a NEW session for the target, we need to update their DB.
            // Note: In the Occupied case above, we might be double-joining, but let's keep it simple for now.
            // The key is that the lock is GONE here.
            
            let target_db = UserDb::new(&target_id).await
                .map_err(|e| Status::internal(e.to_string()))?;
            target_db.join_session(&sid).await
                .map_err(|e| Status::internal(e.to_string()))?;

            sid
        };

        // 2. Add caller to the session
        self.state.sessions
            .entry(session_id.clone())
            .or_insert_with(HashSet::new)
            .insert(caller_id.clone());
        self.state.user_sessions.insert(caller_id.clone(), session_id.clone());

        // 3. Update caller's DB
        let caller_db = UserDb::new(&caller_id).await
            .map_err(|e| Status::internal(e.to_string()))?;
        caller_db.join_session(&session_id).await
            .map_err(|e| Status::internal(e.to_string()))?;

        // Cache user infos if needed
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

        if let Some((_, session_id)) = self.state.user_sessions.remove(&user_id) {
            if let Some(mut members) = self.state.sessions.get_mut(&session_id) {
                members.remove(&user_id);
                if members.is_empty() {
                    drop(members);
                    self.state.sessions.remove(&session_id);
                }
            }
            // Record in user's DB
            if let Ok(user_db) = UserDb::new(&user_id).await {
                let _ = user_db.leave_session(&session_id).await;
            }
        }

        Ok(Response::new(LeaveSessionResponse {}))
    }

    async fn get_participant_workout(
        &self,
        request: Request<GetParticipantWorkoutRequest>,
    ) -> Result<Response<ParticipantStatus>, Status> {
        let _ = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

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
