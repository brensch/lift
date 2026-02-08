use std::sync::Arc;
use tonic::{Request, Response, Status};
use crate::db::{CentralDb, UserDb};
use crate::service_workout::get_user_id;
use lift::workout::v1::social_service_server::SocialService;
use lift::workout::v1::multiplayer_service_server::MultiplayerService;
use lift::workout::v1::*;

pub struct SessionManager {
    central_db: CentralDb,
}

impl SessionManager {
    pub fn new(central_db: CentralDb) -> Self {
        Self {
            central_db,
        }
    }

    pub async fn get_participant_workout(&self, user_id: &str, workout_id: &str) -> Result<ParticipantStatus, Status> {
        let user = self.central_db.get_user(user_id).await
            .map_err(|e| Status::internal(e.to_string()))?
            .ok_or_else(|| Status::not_found("User not found"))?;

        let user_db = UserDb::new(user_id).await
            .map_err(|e| Status::internal(e.to_string()))?;
        
        let active_workout = user_db.get_workout(workout_id).await
            .map_err(|e| Status::internal(e.to_string()))?
            .ok_or_else(|| Status::not_found("Workout not found"))?;

        let mut status = ParticipantStatus {
            user: Some(user),
            active_workout_id: active_workout.id.clone(),
            active_workout: Some(active_workout),
            proposed_sets: Vec::new(),
            completed_sets: Vec::new(),
            current_set: None,
            is_resting: false,
            rest_until: 0,
        };

        let p_sets = user_db.get_proposed_sets(workout_id).await
            .map_err(|e| Status::internal(e.to_string()))?;
        let c_sets = user_db.get_completed_sets(workout_id).await
            .map_err(|e| Status::internal(e.to_string()))?;
        
        status.proposed_sets = p_sets.clone();
        status.completed_sets = c_sets.clone();

        // Find active completed set (one with ended_at == 0)
        let active_c = c_sets.iter().find(|c| c.ended_at == 0);
        if let Some(ac) = active_c {
            status.current_set = p_sets.iter().find(|p| p.id == ac.proposed_set_id).cloned();
        } else {
            // Check for rest
            let last_c = c_sets.iter()
                .filter(|c| c.ended_at > 0)
                .max_by_key(|c| c.ended_at);
            
            if let Some(lc) = last_c {
                let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs() as i64;
                if lc.rest_until > now {
                    status.is_resting = true;
                    status.rest_until = lc.rest_until;
                }
            }

            // If not resting or active, find next set
            if !status.is_resting {
                status.current_set = p_sets.iter()
                    .find(|p| !c_sets.iter().any(|c| c.proposed_set_id == p.id && c.ended_at > 0))
                    .cloned();
            }
        }

        Ok(status)
    }

    pub async fn notify_user_update(&self, _user_id: &str) {
        // No-op for polling model, or could be used for other purposes
    }

    pub async fn update_active_workout(&self, user_id: &str, workout_id: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if let Some(session_id) = self.central_db.get_session_id(user_id).await? {
            self.central_db.join_session(user_id, &session_id, workout_id).await?;
        }
        Ok(())
    }
}

#[derive(Clone)]
pub struct GroupService {
    central_db: CentralDb,
    session_manager: Arc<SessionManager>,
}

impl GroupService {
    pub fn new(central_db: CentralDb, session_manager: Arc<SessionManager>) -> Self {
        Self {
            central_db,
            session_manager,
        }
    }
}

#[tonic::async_trait]
impl SocialService for GroupService {
    async fn search_users(
        &self,
        request: Request<SearchUsersRequest>,
    ) -> Result<Response<SearchUsersResponse>, Status> {
        let req = request.into_inner();
        let users = self.central_db.search_users(&req.query).await
            .map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(SearchUsersResponse { users }))
    }

    async fn get_user_social_profile(
        &self,
        request: Request<GetUserSocialProfileRequest>,
    ) -> Result<Response<GetUserSocialProfileResponse>, Status> {
        let user_id = get_user_id(&request).unwrap_or_default();
        let req = request.into_inner();
        let user = self.central_db.get_user(&req.user_id).await
            .map_err(|e| Status::internal(e.to_string()))?
            .ok_or_else(|| Status::not_found("User not found"))?;
        
        let is_following = if !user_id.is_empty() {
            self.central_db.is_following(&user_id, &req.user_id).await
                .map_err(|e| Status::internal(e.to_string()))?
        } else {
            false
        };

        let user_db = UserDb::new(&req.user_id).await
            .map_err(|e| Status::internal(e.to_string()))?;
        let recent_workouts = user_db.list_workouts().await
            .map_err(|e| Status::internal(e.to_string()))?;

        Ok(Response::new(GetUserSocialProfileResponse {
            user: Some(user),
            recent_workouts,
            is_following,
        }))
    }

    async fn follow_user(
        &self,
        request: Request<FollowUserRequest>,
    ) -> Result<Response<FollowUserResponse>, Status> {
        let follower_id = get_user_id(&request)?;
        let req = request.into_inner();
        self.central_db.follow_user(&follower_id, &req.user_id).await
            .map_err(|e| Status::internal(e.to_string()))?;
        Ok(Response::new(FollowUserResponse {}))
    }
}

#[tonic::async_trait]
impl MultiplayerService for GroupService {
    async fn start_session(
        &self,
        request: Request<StartSessionRequest>,
    ) -> Result<Response<StartSessionResponse>, Status> {
        let user_id = get_user_id(&request)?;
        let req = request.into_inner();
        let session_id = uuid::Uuid::new_v4().to_string();

        self.central_db.join_session(&user_id, &session_id, &req.workout_id).await
            .map_err(|e| Status::internal(e.to_string()))?;

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
        let user_id = get_user_id(&request)?;
        let req = request.into_inner();
        
        println!("User {} joining session {} with workout {}", user_id, req.session_id, req.workout_id);

        self.central_db.join_session(&user_id, &req.session_id, &req.workout_id).await
            .map_err(|e| Status::internal(e.to_string()))?;

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
        let user_id = get_user_id(&request)?;
        
        if let Some(session_id) = self.central_db.get_session_id(&user_id).await.map_err(|e| Status::internal(e.to_string()))? {
            self.central_db.leave_session(&user_id).await
                .map_err(|e| Status::internal(e.to_string()))?;
            
            let user_db = UserDb::new(&user_id).await
                .map_err(|e| Status::internal(e.to_string()))?;
            user_db.add_session(&session_id, false).await
                .map_err(|e| Status::internal(e.to_string()))?;
        }

        Ok(Response::new(LeaveSessionResponse {}))
    }

    async fn get_session_status(
        &self,
        request: Request<GetSessionStatusRequest>,
    ) -> Result<Response<SessionStatus>, Status> {
        let req = request.into_inner();
        let participants = self.central_db.get_session_participants(&req.session_id).await
            .map_err(|e| Status::internal(e.to_string()))?;

        let mut participant_statuses = Vec::new();
        for (user_id, workout_id) in participants {
            let user = self.central_db.get_user(&user_id).await
                .map_err(|e| Status::internal(e.to_string()))?
                .ok_or_else(|| Status::not_found("User not found"))?;

            participant_statuses.push(ParticipantStatus {
                user: Some(user),
                active_workout_id: workout_id,
                ..Default::default()
            });
        }

        Ok(Response::new(SessionStatus {
            session_id: req.session_id,
            participants: participant_statuses,
        }))
    }

    async fn get_participant_workout(
        &self,
        request: Request<GetParticipantWorkoutRequest>,
    ) -> Result<Response<ParticipantStatus>, Status> {
        let req = request.into_inner();
        let status = self.session_manager.get_participant_workout(&req.user_id, &req.workout_id).await?;
        Ok(Response::new(status))
    }

    async fn get_my_active_session(
        &self,
        request: Request<GetMyActiveSessionRequest>,
    ) -> Result<Response<GetMyActiveSessionResponse>, Status> {
        let user_id = get_user_id(&request)?;
        let user_db = UserDb::new(&user_id).await
            .map_err(|e| Status::internal(e.to_string()))?;
        
        let session_id = user_db.get_active_session().await
            .map_err(|e| Status::internal(e.to_string()))?
            .unwrap_or_default();
        
        Ok(Response::new(GetMyActiveSessionResponse {
            session_id,
        }))
    }

    async fn update_active_workout(
        &self,
        request: Request<UpdateActiveWorkoutRequest>,
    ) -> Result<Response<UpdateActiveWorkoutResponse>, Status> {
        let user_id = get_user_id(&request)?;
        let req = request.into_inner();

        self.session_manager.update_active_workout(&user_id, &req.workout_id).await
            .map_err(|e| Status::internal(e.to_string()))?;

        Ok(Response::new(UpdateActiveWorkoutResponse {}))
    }
}

