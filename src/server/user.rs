use super::*;

// ── User Service ──

#[derive(Clone)]
pub struct ServerUserService {
    pub db: ServerDb,
}

#[tonic::async_trait]
impl UserService for ServerUserService {
    async fn get_user(
        &self,
        request: Request<GetUserRequest>,
    ) -> Result<Response<GetUserResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "GetUser", %user_id, "request");
        let user = self
            .db
            .get_user(&user_id)
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
            .update_user_profile(
                &user_id,
                &req.profile_emoji,
                &req.profile_color_hex,
                req.body_weight_kg,
            )
            .await
            .map_err(internal_error)?
            .ok_or_else(|| Status::not_found("User not found"))?;

        if let Some(session_id) = self
            .db
            .get_user_current_session(&user_id)
            .await
            .map_err(internal_error)?
        {
            // Their partners see the new profile.
            self.db.session_changed(&session_id);
        }

        Ok(Response::new(UpdateMyProfileResponse { user: Some(user) }))
    }
}
