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
        let user = self
            .db
            .get_user(&req.user_id)
            .await
            .map_err(internal_error)?
            .ok_or_else(|| Status::not_found("User not found"))?;
        Ok(Response::new(GetUserResponse { user: Some(user) }))
    }
}
