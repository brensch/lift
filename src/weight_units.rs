use crate::db::CentralDb;
use crate::program_state::{set_str, FieldVal, StatePayload};
use prost::Message;
use schlift::workout::v1::{user_setting, UserSetting, WeightUnit};

pub const STATE_WEIGHT_UNIT_KEY: &str = "__weight_unit";
const LB_TO_KG: f32 = 0.453_592_37;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AppWeightUnit {
    Lb,
    Kg,
}

impl AppWeightUnit {
    pub fn from_proto(unit: i32) -> Self {
        match WeightUnit::try_from(unit).unwrap_or(WeightUnit::Lb) {
            WeightUnit::Kg => Self::Kg,
            _ => Self::Lb,
        }
    }

    pub fn suffix(self) -> &'static str {
        match self {
            Self::Lb => "lb",
            Self::Kg => "kg",
        }
    }
}

pub async fn get_user_weight_unit(
    central_db: &CentralDb,
    user_id: &str,
) -> Result<AppWeightUnit, Box<dyn std::error::Error + Send + Sync>> {
    let settings = central_db.get_latest_settings(user_id).await?;
    for (_type_key, blob) in settings {
        let Ok(setting) = UserSetting::decode(blob.as_slice()) else {
            continue;
        };
        if let Some(user_setting::Setting::WeightUnit(cfg)) = setting.setting {
            return Ok(AppWeightUnit::from_proto(cfg.unit));
        }
    }
    Ok(AppWeightUnit::Lb)
}

pub fn annotate_state_with_weight_unit(state: &StatePayload, unit: AppWeightUnit) -> StatePayload {
    let mut annotated = state.clone();
    set_str(&mut annotated, STATE_WEIGHT_UNIT_KEY, unit.suffix());
    annotated
}

pub fn strip_weight_unit_context(state: &mut StatePayload) {
    state.remove(STATE_WEIGHT_UNIT_KEY);
}

pub fn weight_unit_from_state(state: &StatePayload) -> AppWeightUnit {
    match state.get(STATE_WEIGHT_UNIT_KEY) {
        Some(FieldVal::Str(unit)) if unit.eq_ignore_ascii_case("kg") => AppWeightUnit::Kg,
        _ => AppWeightUnit::Lb,
    }
}

pub fn pounds_to_kg(lb: f32) -> f32 {
    lb * LB_TO_KG
}

pub fn kg_to_pounds(kg: f32) -> f32 {
    kg / LB_TO_KG
}

pub fn round_to_unit_increment(
    weight_lb: f32,
    unit: AppWeightUnit,
    lb_step: f32,
    kg_step: f32,
) -> f32 {
    match unit {
        AppWeightUnit::Lb => (weight_lb / lb_step).round() * lb_step,
        AppWeightUnit::Kg => kg_to_pounds((pounds_to_kg(weight_lb) / kg_step).round() * kg_step),
    }
}

pub fn add_unit_increment(weight_lb: f32, unit: AppWeightUnit, lb_step: f32, kg_step: f32) -> f32 {
    match unit {
        AppWeightUnit::Lb => weight_lb + lb_step,
        AppWeightUnit::Kg => kg_to_pounds(pounds_to_kg(weight_lb) + kg_step),
    }
}

pub fn min_weight_lb(unit: AppWeightUnit, min_lb: f32, min_kg: f32) -> f32 {
    match unit {
        AppWeightUnit::Lb => min_lb,
        AppWeightUnit::Kg => kg_to_pounds(min_kg),
    }
}
