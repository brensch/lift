use crate::db::CentralDb;
use crate::regimes::{catalog_regime_types, get_regime};
use crate::service_workout::get_user_id_authenticated;
use lift::workout::v1::{
    settings_service_server::SettingsService, GetSettingsRequest, GetSettingsResponse,
    GetTrainingProgramCatalogRequest, GetTrainingProgramCatalogResponse,
    UpdateSettingRequest, UpdateSettingResponse, UserSetting,
};
use prost::Message;
use tonic::{Request, Response, Status};

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
        Some(lift::workout::v1::user_setting::Setting::PlateColors(_)) => Some("plate_colors"),
        Some(lift::workout::v1::user_setting::Setting::WorkoutConfig(_)) => Some("workout_config"),
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
        request: Request<GetTrainingProgramCatalogRequest>,
    ) -> Result<Response<GetTrainingProgramCatalogResponse>, Status> {
        let _user_id = get_user_id_authenticated(&request, &self.central_db).await?;

        let mut programs = catalog_regime_types()
            .into_iter()
            .map(|regime_type| {
                let regime = get_regime(regime_type);
                regime.training_program_definition(regime_type)
            })
            .collect::<Vec<_>>();
        programs.sort_by_key(|p| (p.sort_order, p.regime_type));

        Ok(Response::new(GetTrainingProgramCatalogResponse { programs }))
    }
}
