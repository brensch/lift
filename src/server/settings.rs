use super::*;

// ── Settings Service ──
//
// Settings are part of the account (changed on the phone, synced as events);
// the server only reads them back for the web.

#[derive(Clone)]
pub struct ServerSettingsService {
    pub db: ServerDb,
}

#[tonic::async_trait]
impl SettingsService for ServerSettingsService {
    async fn get_settings(
        &self,
        request: Request<GetSettingsRequest>,
    ) -> Result<Response<GetSettingsResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "GetSettings", %user_id, "request");
        Ok(Response::new(
            read_api(&self.db, &user_id, |call| call.get_settings()).await?,
        ))
    }
}
