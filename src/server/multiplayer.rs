use super::*;

// ── Multiplayer Service ──

#[derive(Clone)]
pub struct ServerMultiplayerService {
    pub db: ServerDb,
}

#[tonic::async_trait]
impl MultiplayerService for ServerMultiplayerService {
    type SubscribeSessionStream =
        Pin<Box<dyn futures_util::Stream<Item = Result<SessionSubscriptionEvent, Status>> + Send>>;

    async fn join_user(
        &self,
        request: Request<JoinUserRequest>,
    ) -> Result<Response<JoinUserResponse>, Status> {
        let caller_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let target_id = req.user_id;
        if target_id.is_empty() || target_id == caller_id {
            return Err(Status::invalid_argument("target user_id is required"));
        }
        let _target = self
            .db
            .get_user(&target_id)
            .await
            .map_err(internal_error)?
            .ok_or_else(|| Status::not_found("Target user not found"))?;

        let session_id = self
            .db
            .get_current_session_id_for_user(&target_id)
            .await
            .map_err(internal_error)?
            .unwrap_or_else(|| Uuid::new_v4().to_string());

        self.db
            .join_session(&target_id, &session_id)
            .await
            .map_err(internal_error)?;
        self.db
            .join_session(&caller_id, &session_id)
            .await
            .map_err(internal_error)?;

        // Update session_id on both users' active workouts
        for user_id in [&caller_id, &target_id] {
            if let Some((workout_id, _)) = self
                .db
                .get_active_workout_id(user_id)
                .await
                .map_err(internal_error)?
            {
                self.db
                    .update_workout_session_id(user_id, &workout_id, &session_id)
                    .await
                    .map_err(internal_error)?;
            }
            refresh_participant_for_user(&self.db, user_id, &session_id).await?;
        }

        Ok(Response::new(JoinUserResponse { session_id }))
    }

    async fn leave_session(
        &self,
        request: Request<LeaveSessionRequest>,
    ) -> Result<Response<LeaveSessionResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        if let Some(session_id) = self
            .db
            .get_current_session_id_for_user(&user_id)
            .await
            .map_err(internal_error)?
        {
            self.db
                .leave_session(&user_id, &session_id)
                .await
                .map_err(internal_error)?;
            self.db
                .remove_session_participant(&session_id, &user_id)
                .await
                .map_err(internal_error)?;
        }
        Ok(Response::new(LeaveSessionResponse {}))
    }

    async fn get_participant_workout(
        &self,
        request: Request<GetParticipantWorkoutRequest>,
    ) -> Result<Response<ParticipantStatus>, Status> {
        let _caller_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let user = self
            .db
            .get_user(&req.user_id)
            .await
            .map_err(internal_error)?
            .ok_or_else(|| Status::not_found("User not found"))?;
        let active = if let Some((workout_id, _)) = self
            .db
            .get_active_workout_id(&req.user_id)
            .await
            .map_err(internal_error)?
        {
            self.db
                .load_workout_full(&req.user_id, &workout_id)
                .await
                .map_err(internal_error)?
        } else {
            None
        };
        Ok(Response::new(build_participant_status(
            user,
            active.as_ref(),
        )))
    }

    async fn get_current_session(
        &self,
        request: Request<GetCurrentSessionRequest>,
    ) -> Result<Response<GetCurrentSessionResponse>, Status> {
        let caller_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let session_id = if req.session_id.is_empty() {
            self.db
                .get_current_session_id_for_user(&caller_id)
                .await
                .map_err(internal_error)?
                .unwrap_or_default()
        } else {
            req.session_id
        };
        if session_id.is_empty() {
            return Ok(Response::new(GetCurrentSessionResponse {
                session_id,
                session_status: None,
            }));
        }
        let mut participants = self
            .db
            .get_session_participants(&session_id)
            .await
            .map_err(internal_error)?;
        participants.retain(|p| p.user.as_ref().map(|u| u.id.as_str()) != Some(caller_id.as_str()));
        Ok(Response::new(GetCurrentSessionResponse {
            session_id: session_id.clone(),
            session_status: Some(SessionStatus {
                session_id,
                participants,
                next_up_user_id: String::new(),
                next_up_set: None,
                next_up_rest_until: 0,
                currently_lifting_user_id: String::new(),
            }),
        }))
    }

    async fn subscribe_session(
        &self,
        _request: Request<SubscribeSessionRequest>,
    ) -> Result<Response<Self::SubscribeSessionStream>, Status> {
        Err(Status::unimplemented(
            "server multiplayer uses polling, not streaming",
        ))
    }

    async fn update_active_workout(
        &self,
        request: Request<UpdateActiveWorkoutRequest>,
    ) -> Result<Response<UpdateActiveWorkoutResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        if let Some(session_id) = self
            .db
            .get_current_session_id_for_user(&user_id)
            .await
            .map_err(internal_error)?
        {
            refresh_participant_for_user(&self.db, &user_id, &session_id).await?;
        }
        Ok(Response::new(UpdateActiveWorkoutResponse {}))
    }
}
