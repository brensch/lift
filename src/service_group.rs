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
    async fn start_session(
        &self,
        request: Request<StartSessionRequest>,
    ) -> Result<Response<StartSessionResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let _req = request.into_inner();
        let session_id = uuid::Uuid::new_v4().to_string();

        // Cache user info
        if !self.state.users.contains_key(&user_id) {
            if let Ok(Some(user)) = self.central_db.get_user(&user_id).await {
                self.state.users.insert(user_id.clone(), user);
            }
        }

        // Add to session DashMaps
        let mut members = HashSet::new();
        members.insert(user_id.clone());
        self.state.sessions.insert(session_id.clone(), members);
        self.state.user_sessions.insert(user_id.clone(), session_id.clone());

        // Record in user's DB
        let user_db = UserDb::new(&user_id).await
            .map_err(|e| Status::internal(e.to_string()))?;
        user_db.add_session(&session_id, true).await
            .map_err(|e| Status::internal(e.to_string()))?;

        Ok(Response::new(StartSessionResponse {
            session_id,
        }))
    }

    async fn join_session(
        &self,
        request: Request<JoinSessionRequest>,
    ) -> Result<Response<JoinSessionResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        // Cache user info
        if !self.state.users.contains_key(&user_id) {
            if let Ok(Some(user)) = self.central_db.get_user(&user_id).await {
                self.state.users.insert(user_id.clone(), user);
            }
        }

        // Add to session
        self.state.sessions
            .entry(req.session_id.clone())
            .or_insert_with(HashSet::new)
            .insert(user_id.clone());
        self.state.user_sessions.insert(user_id.clone(), req.session_id.clone());

        // Record in user's DB
        let user_db = UserDb::new(&user_id).await
            .map_err(|e| Status::internal(e.to_string()))?;
        user_db.add_session(&req.session_id, true).await
            .map_err(|e| Status::internal(e.to_string()))?;

        Ok(Response::new(JoinSessionResponse {
            session_id: req.session_id,
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
                let _ = user_db.add_session(&session_id, false).await;
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
