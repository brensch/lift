/// Typed key-value state for training program state machine.
///
/// Stored as JSON in `training_program_state_events` and `training_program_state_latest`.
/// Each regime defines its own set of keys and their expected types.
use std::collections::HashMap;

use schlift::workout::v1::{
    state_field_value, Exercise, StateEnumOption, StateFieldKind, StateFieldValue,
    TrainingProgramStateFieldSchema, TrainingProgramStateSchema, UserMessageKind,
    UserMessageSurface,
};
use serde::{Deserialize, Serialize};

// ─── Serialisable field value ─────────────────────────────────────────────────

/// Rust representation of a typed state field value. Uses serde untagged so that
/// JSON round-trips cleanly: `"A"`, `135.0`, `3`, `true`.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(untagged)]
pub enum FieldVal {
    Int(i64),
    Float(f64),
    Bool(bool),
    Str(String),
}

impl FieldVal {
    pub fn as_int(&self) -> Option<i64> {
        match self {
            Self::Int(v) => Some(*v),
            _ => None,
        }
    }

    pub fn as_float(&self) -> Option<f64> {
        match self {
            Self::Float(v) => Some(*v),
            Self::Int(v) => Some(*v as f64),
            _ => None,
        }
    }

    pub fn as_f32(&self) -> Option<f32> {
        self.as_float().map(|v| v as f32)
    }

    pub fn as_str(&self) -> Option<&str> {
        match self {
            Self::Str(v) => Some(v.as_str()),
            _ => None,
        }
    }
}

pub type StatePayload = HashMap<String, FieldVal>;

// ─── Accessor helpers ─────────────────────────────────────────────────────────

pub fn get_int(s: &StatePayload, key: &str) -> Option<i64> {
    s.get(key).and_then(|v| v.as_int())
}

pub fn get_f32(s: &StatePayload, key: &str) -> Option<f32> {
    s.get(key).and_then(|v| v.as_f32())
}

pub fn get_str<'a>(s: &'a StatePayload, key: &str) -> Option<&'a str> {
    s.get(key).and_then(|v| v.as_str())
}

// Defaults for missing keys
pub fn get_int_or(s: &StatePayload, key: &str, default: i64) -> i64 {
    get_int(s, key).unwrap_or(default)
}

pub fn get_f32_or(s: &StatePayload, key: &str, default: f32) -> f32 {
    get_f32(s, key).unwrap_or(default)
}

pub fn get_str_or<'a>(s: &'a StatePayload, key: &str, default: &'a str) -> &'a str {
    get_str(s, key).unwrap_or(default)
}

// ─── Mutator helpers ──────────────────────────────────────────────────────────

pub fn set_int(s: &mut StatePayload, key: &str, val: i64) {
    s.insert(key.to_string(), FieldVal::Int(val));
}

pub fn set_f32(s: &mut StatePayload, key: &str, val: f32) {
    s.insert(key.to_string(), FieldVal::Float(val as f64));
}

pub fn set_str(s: &mut StatePayload, key: impl Into<String>, val: impl Into<String>) {
    s.insert(key.into(), FieldVal::Str(val.into()));
}

// ─── Proto conversion ─────────────────────────────────────────────────────────

/// Convert our `StatePayload` → proto `map<string, StateFieldValue>`.
pub fn payload_to_proto(s: &StatePayload) -> HashMap<String, StateFieldValue> {
    s.iter()
        .map(|(k, v)| {
            let proto_val = match v {
                FieldVal::Int(n) => StateFieldValue {
                    value: Some(state_field_value::Value::IntVal(*n)),
                },
                FieldVal::Float(f) => StateFieldValue {
                    value: Some(state_field_value::Value::FloatVal(*f)),
                },
                FieldVal::Bool(b) => StateFieldValue {
                    value: Some(state_field_value::Value::BoolVal(*b)),
                },
                FieldVal::Str(st) => StateFieldValue {
                    value: Some(state_field_value::Value::StringVal(st.clone())),
                },
            };
            (k.clone(), proto_val)
        })
        .collect()
}

/// Convert proto `map<string, StateFieldValue>` → our `StatePayload`.
pub fn payload_from_proto(map: &HashMap<String, StateFieldValue>) -> StatePayload {
    map.iter()
        .filter_map(|(k, v)| {
            let fv = match &v.value {
                Some(state_field_value::Value::IntVal(n)) => FieldVal::Int(*n),
                Some(state_field_value::Value::FloatVal(f)) => FieldVal::Float(*f),
                Some(state_field_value::Value::BoolVal(b)) => FieldVal::Bool(*b),
                Some(state_field_value::Value::StringVal(s)) => FieldVal::Str(s.clone()),
                None => return None,
            };
            Some((k.clone(), fv))
        })
        .collect()
}

// ─── Domain structs ───────────────────────────────────────────────────────────

/// Result of `propose_from_state` — everything needed for the home screen.
pub struct ProposeResult {
    pub proposed_groups: Vec<schlift::workout::v1::ProposedExerciseGroup>,
    pub regime_context: schlift::workout::v1::RegimeContext,
    pub suggested_workout_name: String,
    pub schedule_messages: Vec<ProposalMessage>,
}

pub struct ProposalMessage {
    pub key: String,
    pub kind: UserMessageKind,
    pub surface: UserMessageSurface,
    pub title: String,
    pub body: String,
    pub exercise: Exercise,
    pub slot_key: String,
}

// ─── Schema builder helpers ───────────────────────────────────────────────────

pub struct FieldSchemaBuilder {
    pub key: &'static str,
    pub label: &'static str,
    pub help_text: &'static str,
    pub section: &'static str,
    pub order: i32,
    pub kind: StateFieldKind,
    pub required: bool,
    pub min_value: f64,
    pub max_value: f64,
    pub step: f64,
    pub enum_options: Vec<(&'static str, &'static str)>,
}

#[derive(Clone, Copy)]
pub struct FloatFieldBounds {
    pub min: f64,
    pub max: f64,
    pub step: f64,
}

impl FieldSchemaBuilder {
    pub fn build(self) -> TrainingProgramStateFieldSchema {
        TrainingProgramStateFieldSchema {
            key: self.key.to_string(),
            label: self.label.to_string(),
            help_text: self.help_text.to_string(),
            section: self.section.to_string(),
            order: self.order,
            kind: self.kind as i32,
            required: self.required,
            min_value: self.min_value,
            max_value: self.max_value,
            step: self.step,
            enum_options: self
                .enum_options
                .into_iter()
                .map(|(v, l)| StateEnumOption {
                    value: v.to_string(),
                    label: l.to_string(),
                })
                .collect(),
            onboarding_field: false,
        }
    }
}

/// Mark a field schema as visible during onboarding.
pub fn with_onboarding(mut f: TrainingProgramStateFieldSchema) -> TrainingProgramStateFieldSchema {
    f.onboarding_field = true;
    f
}

pub fn schema_float(
    key: &'static str,
    label: &'static str,
    help_text: &'static str,
    section: &'static str,
    order: i32,
    bounds: FloatFieldBounds,
) -> TrainingProgramStateFieldSchema {
    FieldSchemaBuilder {
        key,
        label,
        help_text,
        section,
        order,
        kind: StateFieldKind::Float,
        required: true,
        min_value: bounds.min,
        max_value: bounds.max,
        step: bounds.step,
        enum_options: vec![],
    }
    .build()
}

pub fn schema_int(
    key: &'static str,
    label: &'static str,
    help_text: &'static str,
    section: &'static str,
    order: i32,
    min: i64,
    max: i64,
) -> TrainingProgramStateFieldSchema {
    FieldSchemaBuilder {
        key,
        label,
        help_text,
        section,
        order,
        kind: StateFieldKind::Int,
        required: false,
        min_value: min as f64,
        max_value: max as f64,
        step: 1.0,
        enum_options: vec![],
    }
    .build()
}

pub fn schema_enum(
    key: &'static str,
    label: &'static str,
    help_text: &'static str,
    section: &'static str,
    order: i32,
    options: Vec<(&'static str, &'static str)>,
) -> TrainingProgramStateFieldSchema {
    FieldSchemaBuilder {
        key,
        label,
        help_text,
        section,
        order,
        kind: StateFieldKind::Enum,
        required: true,
        min_value: 0.0,
        max_value: 0.0,
        step: 0.0,
        enum_options: options,
    }
    .build()
}

pub fn build_schema(fields: Vec<TrainingProgramStateFieldSchema>) -> TrainingProgramStateSchema {
    TrainingProgramStateSchema { fields }
}
