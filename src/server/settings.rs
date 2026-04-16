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

    async fn get_training_program_catalog(
        &self,
        _request: Request<GetTrainingProgramCatalogRequest>,
    ) -> Result<Response<GetTrainingProgramCatalogResponse>, Status> {
        info!(rpc = "GetTrainingProgramCatalog", "request");
        let mut programs = catalog_regime_types()
            .into_iter()
            .map(|rt| get_regime(rt).training_program_definition(rt))
            .collect::<Vec<_>>();
        programs.sort_by_key(|p| (p.sort_order, p.regime_type));
        Ok(Response::new(GetTrainingProgramCatalogResponse {
            programs,
        }))
    }

    async fn get_active_training_program_state(
        &self,
        request: Request<GetActiveTrainingProgramStateRequest>,
    ) -> Result<Response<GetActiveTrainingProgramStateResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "GetActiveTrainingProgramState", %user_id, "request");
        if let Some(state) = self
            .db
            .get_program_state(&user_id)
            .await
            .map_err(internal_error)?
        {
            return Ok(Response::new(state));
        }
        let regime_type = RegimeType::Linear5x5;
        let regime = get_regime(regime_type);
        let response = GetActiveTrainingProgramStateResponse {
            state: Some(TrainingProgramState {
                regime_type: regime_type as i32,
                fields: payload_to_proto(&regime.default_state()),
                updated_at: 0,
                source: "default".to_string(),
            }),
            schema: Some(regime.state_schema()),
        };
        self.db
            .put_program_state(&user_id, &response)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(response))
    }

    async fn set_active_training_program_state(
        &self,
        request: Request<SetActiveTrainingProgramStateRequest>,
    ) -> Result<Response<SetActiveTrainingProgramStateResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let regime_type = RegimeType::try_from(req.regime_type).unwrap_or(RegimeType::Linear5x5);
        info!(rpc = "SetActiveTrainingProgramState", %user_id, ?regime_type, "request");
        let regime = get_regime(regime_type);
        let payload = payload_from_proto(&req.fields);
        let state = TrainingProgramState {
            regime_type: regime_type as i32,
            fields: payload_to_proto(&payload),
            updated_at: now_unix(),
            source: if req.source.is_empty() {
                "manual_edit".to_string()
            } else {
                req.source
            },
        };
        let response = GetActiveTrainingProgramStateResponse {
            state: Some(state.clone()),
            schema: Some(regime.state_schema()),
        };
        self.db
            .put_program_state(&user_id, &response)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(SetActiveTrainingProgramStateResponse {
            state: Some(state),
            validation_warnings: regime.validate_state(&payload),
        }))
    }

    async fn get_training_program_state_history(
        &self,
        _request: Request<GetTrainingProgramStateHistoryRequest>,
    ) -> Result<Response<GetTrainingProgramStateHistoryResponse>, Status> {
        Err(Status::unimplemented(
            "server settings does not store state history yet",
        ))
    }
}
