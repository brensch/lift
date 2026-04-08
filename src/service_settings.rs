use crate::db::CentralDb;
use crate::program_state::{
    parse_state_payload, payload_from_proto, payload_to_proto, serialize_state_payload,
    ProgramStateEventRecord,
};
use crate::regimes::{catalog_regime_types, get_regime};
use crate::service_workout::get_user_id_authenticated;
use crate::weight_units::{
    annotate_state_with_weight_unit, get_user_weight_unit, strip_weight_unit_context,
};
use prost::Message;
use schlift::workout::v1::{
    settings_service_server::SettingsService, ApplyPendingStateUpdateRequest,
    ApplyPendingStateUpdateResponse, GetActiveTrainingProgramStateRequest,
    GetActiveTrainingProgramStateResponse, GetSettingsRequest, GetSettingsResponse,
    GetTrainingProgramCatalogRequest, GetTrainingProgramCatalogResponse,
    GetTrainingProgramStateHistoryRequest, GetTrainingProgramStateHistoryResponse, RegimeType,
    SetActiveTrainingProgramStateRequest, SetActiveTrainingProgramStateResponse,
    TrainingProgramState, UpdateSettingRequest, UpdateSettingResponse, UserSetting,
};
use tonic::{Request, Response, Status};
use uuid::Uuid;

pub struct MySettingsService {
    central_db: CentralDb,
}

impl MySettingsService {
    pub fn new(central_db: CentralDb) -> Self {
        Self { central_db }
    }
}

fn setting_type_key(setting: &UserSetting) -> Option<&'static str> {
    match &setting.setting {
        Some(schlift::workout::v1::user_setting::Setting::PlateColors(_)) => Some("plate_colors"),
        Some(schlift::workout::v1::user_setting::Setting::WeightUnit(_)) => Some("weight_unit"),
        None => None,
    }
}

#[tonic::async_trait]
impl SettingsService for MySettingsService {
    async fn update_setting(
        &self,
        request: Request<UpdateSettingRequest>,
    ) -> Result<Response<UpdateSettingResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        let setting = req
            .setting
            .ok_or_else(|| Status::invalid_argument("setting is required"))?;

        let type_key = setting_type_key(&setting)
            .ok_or_else(|| Status::invalid_argument("unknown setting type"))?;

        let blob = setting.encode_to_vec();

        self.central_db
            .insert_user_setting(&user_id, type_key, &blob)
            .await
            .map_err(|e| Status::internal(format!("Failed to save setting: {}", e)))?;

        Ok(Response::new(UpdateSettingResponse {}))
    }

    async fn get_settings(
        &self,
        request: Request<GetSettingsRequest>,
    ) -> Result<Response<GetSettingsResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;

        let rows = self
            .central_db
            .get_latest_settings(&user_id)
            .await
            .map_err(|e| Status::internal(format!("Failed to get settings: {}", e)))?;

        let mut settings = Vec::new();
        for (_type_key, blob) in rows {
            if let Ok(setting) = UserSetting::decode(blob.as_slice()) {
                settings.push(setting);
            }
        }

        Ok(Response::new(GetSettingsResponse { settings }))
    }

    async fn get_training_program_catalog(
        &self,
        _request: Request<GetTrainingProgramCatalogRequest>,
    ) -> Result<Response<GetTrainingProgramCatalogResponse>, Status> {
        // Public endpoint — catalog is static data, no auth required

        let mut programs = catalog_regime_types()
            .into_iter()
            .map(|regime_type| {
                let regime = get_regime(regime_type);
                regime.training_program_definition(regime_type)
            })
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
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;

        let record = self
            .central_db
            .get_latest_program_state(&user_id)
            .await
            .map_err(|e| Status::internal(e.to_string()))?;

        let (regime_type_int, payload) = match record {
            Some(ref rec) => {
                let payload = parse_state_payload(&rec.state_payload_json);
                (rec.regime_type, payload)
            }
            None => {
                let regime = get_regime(RegimeType::Linear5x5);
                (RegimeType::Linear5x5 as i32, regime.default_state())
            }
        };

        let regime_type = RegimeType::try_from(regime_type_int).unwrap_or(RegimeType::Linear5x5);
        let regime = get_regime(regime_type);

        let updated_at = record.as_ref().map(|r| r.updated_at).unwrap_or(0);
        let state = TrainingProgramState {
            regime_type: regime_type_int,
            fields: payload_to_proto(&payload),
            updated_at,
            source: String::new(),
        };
        let schema = regime.state_schema();

        Ok(Response::new(GetActiveTrainingProgramStateResponse {
            state: Some(state),
            schema: Some(schema),
        }))
    }

    async fn set_active_training_program_state(
        &self,
        request: Request<SetActiveTrainingProgramStateRequest>,
    ) -> Result<Response<SetActiveTrainingProgramStateResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        let regime_type = RegimeType::try_from(req.regime_type).unwrap_or(RegimeType::Linear5x5);
        let regime = get_regime(regime_type);

        let payload = payload_from_proto(&req.fields);
        let validation_warnings = regime.validate_state(&payload);

        let now = chrono::Utc::now().timestamp();
        let source = if req.source.is_empty() {
            "manual_edit".to_string()
        } else {
            req.source.clone()
        };
        let event = ProgramStateEventRecord {
            event_id: Uuid::new_v4().to_string(),
            user_id: user_id.clone(),
            regime_type: regime_type as i32,
            effective_at: now,
            recorded_at: now,
            source: source.clone(),
            state_payload_json: serialize_state_payload(&payload),
            source_workout_id: None,
        };

        self.central_db
            .append_program_state_event(event)
            .await
            .map_err(|e| Status::internal(format!("Failed to save state: {}", e)))?;

        let state = TrainingProgramState {
            regime_type: regime_type as i32,
            fields: payload_to_proto(&payload),
            updated_at: now,
            source,
        };

        Ok(Response::new(SetActiveTrainingProgramStateResponse {
            state: Some(state),
            validation_warnings,
        }))
    }

    async fn get_training_program_state_history(
        &self,
        request: Request<GetTrainingProgramStateHistoryRequest>,
    ) -> Result<Response<GetTrainingProgramStateHistoryResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;

        let events = self
            .central_db
            .get_program_state_history(&user_id, 100)
            .await
            .map_err(|e| Status::internal(e.to_string()))?;

        let proto_events = events.into_iter().map(|e| e.to_proto()).collect();

        Ok(Response::new(GetTrainingProgramStateHistoryResponse {
            events: proto_events,
        }))
    }

    async fn apply_pending_state_update(
        &self,
        request: Request<ApplyPendingStateUpdateRequest>,
    ) -> Result<Response<ApplyPendingStateUpdateResponse>, Status> {
        let user_id = get_user_id_authenticated(&request, &self.central_db).await?;
        let req = request.into_inner();

        // Load current state
        let record = self
            .central_db
            .get_latest_program_state(&user_id)
            .await
            .map_err(|e| Status::internal(e.to_string()))?
            .ok_or_else(|| Status::failed_precondition("No active training program state found"))?;

        let regime_type = RegimeType::try_from(record.regime_type).unwrap_or(RegimeType::Linear5x5);
        let regime = get_regime(regime_type);
        let current_state = parse_state_payload(&record.state_payload_json);
        let weight_unit = get_user_weight_unit(&self.central_db, &user_id)
            .await
            .unwrap_or(crate::weight_units::AppWeightUnit::Lb);
        let annotated_state = annotate_state_with_weight_unit(&current_state, weight_unit);
        let field_values = payload_from_proto(&req.field_values);

        let new_state = regime
            .apply_pending_update_to_state(&annotated_state, &req.update_id, &field_values)
            .map_err(|e| Status::invalid_argument(e))?;
        let mut new_state = new_state;
        strip_weight_unit_context(&mut new_state);

        let now = chrono::Utc::now().timestamp();
        let event = ProgramStateEventRecord {
            event_id: uuid::Uuid::new_v4().to_string(),
            user_id: user_id.clone(),
            regime_type: regime_type as i32,
            effective_at: now,
            recorded_at: now,
            source: format!("pending_update:{}", req.update_id),
            state_payload_json: serialize_state_payload(&new_state),
            source_workout_id: None,
        };

        self.central_db
            .append_program_state_event(event)
            .await
            .map_err(|e| Status::internal(format!("Failed to save state: {}", e)))?;

        let state = TrainingProgramState {
            regime_type: regime_type as i32,
            fields: payload_to_proto(&new_state),
            updated_at: now,
            source: format!("pending_update:{}", req.update_id),
        };

        Ok(Response::new(ApplyPendingStateUpdateResponse {
            state: Some(state),
        }))
    }
}
