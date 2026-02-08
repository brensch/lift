use tonic::{Request, Response, Status};
use lift::workout::v1::{
    user_service_server::UserService,
    CreateUserRequest, CreateUserResponse,
    GetUserRequest, GetUserResponse,
};
use crate::db::CentralDb;

pub struct MyUserService {
    central_db: CentralDb,
}

impl MyUserService {
    pub fn new(central_db: CentralDb) -> Self {
        Self { central_db }
    }
}

#[tonic::async_trait]
impl UserService for MyUserService {
    async fn create_user(
        &self,
        request: Request<CreateUserRequest>,
    ) -> Result<Response<CreateUserResponse>, Status> {
        let req = request.into_inner();

        if req.name.is_empty() {
            return Err(Status::invalid_argument("name is required"));
        }

        let user = self.central_db.create_user(&req.name).await
            .map_err(|e| Status::internal(format!("Failed to create user: {}", e)))?;

        Ok(Response::new(CreateUserResponse { user: Some(user) }))
    }

    async fn get_user(
        &self,
        request: Request<GetUserRequest>,
    ) -> Result<Response<GetUserResponse>, Status> {
        let req = request.into_inner();

        if req.user_id.is_empty() {
            return Err(Status::invalid_argument("user_id is required"));
        }

        let user = self.central_db.get_user(&req.user_id).await
            .map_err(|e| Status::internal(format!("Failed to get user: {}", e)))?
            .ok_or_else(|| Status::not_found("User not found"))?;

        Ok(Response::new(GetUserResponse { user: Some(user) }))
    }
}