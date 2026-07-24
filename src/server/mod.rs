use crate::db::ServerDb;
use crate::program_state::{payload_from_proto, payload_to_proto};
use crate::progress::compute_next_up_set;
use crate::regimes::{catalog_regime_types, get_regime};
use crate::schplanner::{
    prescribed_slots_from_groups, summarize_recent_insights, summarize_slot_outcomes,
    SchplannerWorkoutRecord,
};
use crate::state::ActiveWorkout;
use crate::time::now_unix;
use crate::workout::{
    active_from_get_workout_response, active_proposed_sets, apply_cancel_proposed_set_to_active,
    apply_complete_set_to_active, apply_delete_completed_set_to_active,
    apply_reorder_exercise_groups, apply_replace_exercise_group_plan, apply_start_set_to_active,
    generate_sets_for_group, get_workout_response_from_active,
    is_final_set_in_exercise_group_after_completion, start_workout_response_from_active,
    workout_state_snapshot_from_state, END_OF_EXERCISE_GROUP_REST_SECONDS,
};
use prost::Message;
use schlift::workout::v1::auth_service_server::AuthService;
use schlift::workout::v1::multiplayer_service_server::MultiplayerService;
use schlift::workout::v1::settings_service_server::SettingsService;
use schlift::workout::v1::user_service_server::UserService;
use schlift::workout::v1::workout_mutation::Mutation;
use schlift::workout::v1::workout_service_server::WorkoutService;
use schlift::workout::v1::*;
use std::pin::Pin;
use tonic::{Request, Response, Status};
use tracing::info;
use uuid::Uuid;

mod auth;
mod messages;
mod multiplayer;
mod settings;
mod support;
mod user;
mod workout;
#[cfg(test)]
mod workout_tests;

pub use auth::ServerAuthService;
pub use multiplayer::ServerMultiplayerService;
pub use settings::ServerSettingsService;
pub use user::ServerUserService;
pub use workout::ServerWorkoutService;

use support::{
    authed_user_id, build_participant_status, internal_error, refresh_participant_for_user,
    setting_type_key,
};
