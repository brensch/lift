use super::*;

// ── User Service ──

#[derive(Clone)]
pub struct ServerUserService {
    pub db: ServerDb,
}

#[tonic::async_trait]
impl UserService for ServerUserService {
    async fn create_user(
        &self,
        request: Request<CreateUserRequest>,
    ) -> Result<Response<CreateUserResponse>, Status> {
        let req = request.into_inner();
        let name = req.name.trim();
        info!(rpc = "CreateUser", %name, "request");
        if name.is_empty() {
            return Err(Status::invalid_argument("name is required"));
        }
        let (user, _) = self
            .db
            .get_or_create_user_with_auth_session(name)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(CreateUserResponse { user: Some(user) }))
    }

    async fn get_user(
        &self,
        request: Request<GetUserRequest>,
    ) -> Result<Response<GetUserResponse>, Status> {
        let req = request.into_inner();
        info!(rpc = "GetUser", user_id = %req.user_id, "request");
        let user = self
            .db
            .get_user(&req.user_id)
            .await
            .map_err(internal_error)?
            .ok_or_else(|| Status::not_found("User not found"))?;
        Ok(Response::new(GetUserResponse { user: Some(user) }))
    }

    async fn update_my_profile(
        &self,
        request: Request<UpdateMyProfileRequest>,
    ) -> Result<Response<UpdateMyProfileResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "UpdateMyProfile", %user_id, "request");

        let user = self
            .db
            .update_user_profile(&user_id, &req.profile_emoji, &req.profile_color_hex, req.body_weight_kg)
            .await
            .map_err(internal_error)?
            .ok_or_else(|| Status::not_found("User not found"))?;

        if let Some(session_id) = self
            .db
            .get_current_session_id_for_user(&user_id)
            .await
            .map_err(internal_error)?
        {
            refresh_participant_for_user(&self.db, &user_id, &session_id).await?;
        }

        Ok(Response::new(UpdateMyProfileResponse { user: Some(user) }))
    }
}
