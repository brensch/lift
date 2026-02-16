use std::sync::Arc;
use tonic::{Request, Response, Status};
use crate::db::{CentralDb, UserDb, SessionDb};
use crate::service_workout::get_user_id_authenticated;
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

    pub async fn notify_user_update(&self, user_id: &str) {
        if let Err(e) = self.sync_user_state(user_id).await {
            eprintln!("Failed to sync user state for {}: {}", user_id, e);
        }
    }

    pub async fn sync_user_state(&self, user_id: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let session_id = match self.central_db.get_session_id(user_id).await? {
            Some(id) => id,
            None => return Ok(()),
        };

        let user_db = UserDb::new(user_id).await?;
        let session_db = SessionDb::new(&session_id).await?;

        // 1. Get user info
        let user = self.central_db.get_user(user_id).await?
            .ok_or("User not found")?;

        // 2. Use the workout_id from the session (persists after workout ends)
        let workout_id = self.central_db.get_session_workout_id(user_id).await?;

        // 3. Update participant info in SessionDb
        session_db.upsert_participant(user_id, &user.name, workout_id.as_deref()).await?;

        // 4. Sync workout data (works for both active and ended workouts)
        if let Some(wid) = &workout_id {
            if let Some(workout) = user_db.get_workout(wid).await? {
                session_db.upsert_workout(user_id, &workout).await?;

                // Clear old data for this user/workout to handle deletions and reorders
                sqlx::query("DELETE FROM exercise_groups WHERE user_id = ? AND workout_id = ?")
                    .bind(user_id)
                    .bind(wid)
                    .execute(&session_db.pool)
                    .await?;
                sqlx::query("DELETE FROM proposed_sets WHERE user_id = ? AND workout_id = ?")
                    .bind(user_id)
                    .bind(wid)
                    .execute(&session_db.pool)
                    .await?;

                let groups = user_db.get_exercise_groups(wid).await?;
                session_db.upsert_exercise_groups(user_id, &groups).await?;

                let proposed = user_db.get_proposed_sets(wid).await?;
                session_db.upsert_proposed_sets(user_id, &proposed).await?;

                let completed = user_db.get_completed_sets(wid).await?;
                for set in completed {
                    session_db.upsert_completed_set(user_id, &set).await?;
                }
            }
        }

        Ok(())
    }

    pub async fn finish_session(&self, user_id: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if let Some(session_id) = self.central_db.get_session_id(user_id).await? {
            self.central_db.leave_session(user_id).await?;

            let user_db = UserDb::new(user_id).await?;
            user_db.add_session(&session_id, false).await?;
        }
        Ok(())
    }

    pub async fn leave_session(&self, user_id: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.finish_session(user_id).await
    }

    pub async fn update_active_workout(&self, user_id: &str, workout_id: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if let Some(session_id) = self.central_db.get_session_id(user_id).await? {
            self.central_db.join_session(user_id, &session_id, workout_id).await?;
            self.sync_user_state(user_id).await?;
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
impl MultiplayerService for GroupService {
    async fn start_session(
        &self,
        request: Request<StartSessionRequest>,
    ) -> Result<Response<StartSessionResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();
        let session_id = uuid::Uuid::new_v4().to_string();

        self.central_db.join_session(&user_id, &session_id, &req.workout_id).await
            .map_err(|e| Status::internal(e.to_string()))?;

        let user_db = UserDb::new(&user_id).await
            .map_err(|e| Status::internal(e.to_string()))?;
        user_db.add_session(&session_id, true).await
            .map_err(|e| Status::internal(e.to_string()))?;

        // Initialize SessionDb state
        self.session_manager.sync_user_state(&user_id).await
             .map_err(|e| Status::internal(format!("Failed to sync initial state: {}", e)))?;

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
        
        println!("User {} joining session {} with workout {}", user_id, req.session_id, req.workout_id);

        self.central_db.join_session(&user_id, &req.session_id, &req.workout_id).await
            .map_err(|e| Status::internal(e.to_string()))?;

        let user_db = UserDb::new(&user_id).await
            .map_err(|e| Status::internal(e.to_string()))?;
        user_db.add_session(&req.session_id, true).await
            .map_err(|e| Status::internal(e.to_string()))?;

        // Sync state to SessionDb
        self.session_manager.sync_user_state(&user_id).await
             .map_err(|e| Status::internal(format!("Failed to sync state: {}", e)))?;

        Ok(Response::new(JoinSessionResponse {
            session_id: req.session_id,
        }))
    }

    async fn leave_session(
        &self,
        request: Request<LeaveSessionRequest>,
    ) -> Result<Response<LeaveSessionResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;

        self.session_manager.leave_session(&user_id).await
            .map_err(|e| Status::internal(e.to_string()))?;

        Ok(Response::new(LeaveSessionResponse {}))
    }

    async fn get_participant_workout(
        &self,
        request: Request<GetParticipantWorkoutRequest>,
    ) -> Result<Response<ParticipantStatus>, Status> {
        let _ = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();
        
        // Check if the target user is in a session
        if let Some(session_id) = self.central_db.get_session_id(&req.user_id).await.map_err(|e| Status::internal(e.to_string()))? {
             let session_db = SessionDb::new(&session_id).await
                .map_err(|e| Status::internal(e.to_string()))?;
            
             // Read from SessionDb
                          let workout = session_db.get_workout(&req.workout_id).await
                             .map_err(|e| Status::internal(e.to_string()))?
                             .ok_or_else(|| Status::not_found("Workout not found"))?;
             
                          let groups = session_db.get_exercise_groups(&req.workout_id).await
                              .map_err(|e| Status::internal(e.to_string()))?;
                          let proposed = session_db.get_proposed_sets(&req.workout_id).await
                              .map_err(|e| Status::internal(e.to_string()))?;
                          let completed = session_db.get_completed_sets(&req.workout_id).await
                              .map_err(|e| Status::internal(e.to_string()))?;
                          
                          // We need User info.
                          let user = self.central_db.get_user(&req.user_id).await
                              .map_err(|e| Status::internal(e.to_string()))?
                              .ok_or_else(|| Status::not_found("User not found"))?;
             
                          return Ok(Response::new(ParticipantStatus {
                             user: Some(user),
                             active_workout_id: workout.id.clone(),
                             active_workout: Some(workout),
                             exercise_groups: groups,
                             proposed_sets: proposed,
                             completed_sets: completed,
                          }));
             
        }

        Err(Status::not_found("Participant not in an active session or workout not found in session context"))
    }

    async fn get_current_session(
        &self,
        request: Request<GetCurrentSessionRequest>,
    ) -> Result<Response<GetCurrentSessionResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();
        
        // Determine target session ID:
        // 1. Explicitly requested (for peeking/joining)
        // 2. User's active session
        let session_id = if !req.session_id.is_empty() {
             Some(req.session_id)
        } else {
             self.central_db.get_session_id(&user_id).await
                .map_err(|e| Status::internal(e.to_string()))?
        };

        if let Some(sid) = session_id {
            let session_db = SessionDb::new(&sid).await
                .map_err(|e| Status::internal(e.to_string()))?;

            let participants = session_db.get_participants().await
                .map_err(|e| Status::internal(e.to_string()))?;

            let mut participant_statuses = Vec::new();
            for (p_user_id, name, active_workout_id) in participants {
                // We construct the User object. 
                // We might want to fetch real created_at from CentralDb if needed, but for UI name is most important.
                let user = User {
                    id: p_user_id,
                    name,
                    created_at: 0, 
                };

                if let Some(workout_id) = active_workout_id {
                    let workout = session_db.get_workout(&workout_id).await
                         .map_err(|e| Status::internal(e.to_string()))?
                         .unwrap_or_default();
                    let groups = session_db.get_exercise_groups(&workout_id).await
                         .map_err(|e| Status::internal(e.to_string()))?;
                    let proposed = session_db.get_proposed_sets(&workout_id).await
                         .map_err(|e| Status::internal(e.to_string()))?;
                    let completed = session_db.get_completed_sets(&workout_id).await
                         .map_err(|e| Status::internal(e.to_string()))?;

                     participant_statuses.push(ParticipantStatus {
                        user: Some(user),
                        active_workout_id: workout_id,
                        active_workout: Some(workout),
                        exercise_groups: groups,
                        proposed_sets: proposed,
                        completed_sets: completed,
                    });
                } else {
                     participant_statuses.push(ParticipantStatus {
                        user: Some(user),
                        active_workout_id: String::new(),
                        ..Default::default()
                    });
                }
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
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        self.session_manager.update_active_workout(&user_id, &req.workout_id).await
            .map_err(|e| Status::internal(e.to_string()))?;

        Ok(Response::new(UpdateActiveWorkoutResponse {}))
    }
}
