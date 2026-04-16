use crate::program_state::{FieldVal, StatePayload};

pub const STATE_WEIGHT_UNIT_KEY: &str = "__weight_unit";
const LB_TO_KG: f32 = 0.453_592_37;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AppWeightUnit {
    Lb,
    Kg,
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

pub fn min_weight_lb(unit: AppWeightUnit, min_lb: f32, min_kg: f32) -> f32 {
    match unit {
        AppWeightUnit::Lb => min_lb,
        AppWeightUnit::Kg => kg_to_pounds(min_kg),
    }
}
