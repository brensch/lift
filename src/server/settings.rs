use super::*;

// ── Settings Service ──

#[derive(Clone)]
pub struct ServerSettingsService {
    pub db: ServerDb,
}

#[tonic::async_trait]
impl SettingsService for ServerSettingsService {
    async fn update_setting(
        &self,
        request: Request<UpdateSettingRequest>,
    ) -> Result<Response<UpdateSettingResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "UpdateSetting", %user_id, "request");
        let req = request.into_inner();
        let setting = req
            .setting
            .ok_or_else(|| Status::invalid_argument("setting is required"))?;
        let type_key = setting_type_key(&setting)
            .ok_or_else(|| Status::invalid_argument("unknown setting type"))?;
        self.db
            .put_setting(&user_id, type_key, &setting)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(UpdateSettingResponse {}))
    }

    async fn get_settings(
        &self,
        request: Request<GetSettingsRequest>,
    ) -> Result<Response<GetSettingsResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "GetSettings", %user_id, "request");
        let settings = self
            .db
            .get_settings(&user_id)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(GetSettingsResponse { settings }))
    }

}
