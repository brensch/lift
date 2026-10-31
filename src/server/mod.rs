use crate::db::ServerDb;
use crate::time::now_unix;
use schlift::workout::v1::admin_service_server::AdminService;
use schlift::workout::v1::analytics_service_server::AnalyticsService;
use schlift::workout::v1::auth_service_server::AuthService;
use schlift::workout::v1::multiplayer_service_server::MultiplayerService;
use schlift::workout::v1::settings_service_server::SettingsService;
use schlift::workout::v1::sync_service_server::SyncService;
use schlift::workout::v1::user_service_server::UserService;
use schlift::workout::v1::workout_service_server::WorkoutService;
use schlift::workout::v1::*;
use schlift_core::account::CoreError;
use schlift_core::api::View;
use schlift_core::workout::get_workout_response_from_active;
use std::pin::Pin;
use tonic::{Request, Response, Status};
use tracing::info;
use uuid::Uuid;

mod analytics;
mod auth;
mod multiplayer;
#[cfg(test)]
mod multiplayer_tests;
mod settings;
mod support;
mod sync;
#[cfg(test)]
mod sync_tests;
mod user;
mod workout;

pub use analytics::{ServerAdminService, ServerAnalyticsService};
pub use auth::ServerAuthService;
pub use multiplayer::ServerMultiplayerService;
pub use settings::ServerSettingsService;
pub use sync::ServerSyncService;
pub use user::ServerUserService;
pub use workout::ServerWorkoutService;

use multiplayer::{current_session, join_requests};
use support::{
    authed_admin_id, authed_user_id, build_participant_status, client_labels, core_status,
    internal_error, participant_status, read_api, refresh_participant_for_user, ServerResult,
};
