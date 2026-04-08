use crate::db::CentralDb;
use crate::program_state::{
    parse_state_payload, serialize_state_payload, ProgramStateEventRecord, WorkingSetResult,
    WorkoutCompletionResult,
};
use crate::progress::compute_next_up_set;
use crate::regimes::get_regime;
use crate::scheduler::Scheduler;
use crate::state::{ActiveWorkout, AppState};
use crate::weight_units::{
    annotate_state_with_weight_unit, get_user_weight_unit, strip_weight_unit_context, AppWeightUnit,
};
use crate::workout_events::{WorkoutEventRecord, WorkoutEventType};
use prost::Message;
#[cfg(test)]
use schlift::workout::v1::UpdateExerciseGroupRequest;
use schlift::workout::v1::{
    workout_mutation, workout_service_server::WorkoutService, AppendWorkoutHeartRateRequest,
    AppendWorkoutHeartRateResponse, AppendWorkoutMutationsRequest, AppendWorkoutMutationsResponse,
    CancelProposedSetRequest, CancelProposedSetResponse, ClearWorkoutDraftRequest,
    ClearWorkoutDraftResponse, CompleteSetRequest, CompleteSetResponse, CompletedSet,
    DeleteCompletedSetRequest, DeleteCompletedSetResponse, EndWorkoutRequest, EndWorkoutResponse,
    ExerciseGroup, ExerciseTypeConfig, GetActiveWorkoutRequest, GetActiveWorkoutResponse,
    GetProposedWorkoutScheduleRequest, GetProposedWorkoutScheduleResponse,
    GetWorkoutHeartRateRequest, GetWorkoutHeartRateResponse, GetWorkoutRequest, GetWorkoutResponse,
    ListWorkoutsRequest, ListWorkoutsResponse, PlannedGroupSet, ProposedSet,
    RehydrateWorkoutFromEventsRequest, RehydrateWorkoutFromEventsResponse,
    ReorderExerciseGroupsRequest, ReorderExerciseGroupsResponse, ReplaceExerciseGroupPlanRequest,
    ReplaceExerciseGroupPlanResponse, RestConfig, SaveWorkoutDraftRequest,
    SaveWorkoutDraftResponse, StartSetRequest, StartSetResponse, StartWorkoutRequest,
    StartWorkoutResponse, WorkingSetSpec, Workout, WorkoutDraft, WorkoutPlanChangeStats,
    WorkoutStateSnapshot,
};
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};
use tonic::{Request, Response, Status};
use uuid::Uuid;

mod handlers;
mod planning;
mod reducer;

use planning::*;
pub(crate) use planning::{generate_sets_for_group, materialize_group_working_sets};
use reducer::*;

pub struct MyWorkoutService {
    central_db: CentralDb,
    state: Arc<AppState>,
}

impl MyWorkoutService {
    pub fn new(central_db: CentralDb, state: Arc<AppState>) -> Self {
        Self { central_db, state }
    }

    async fn log_delta_event<M: Message>(
        &self,
        user_id: &str,
        workout_id: &str,
        event_type: WorkoutEventType,
        message: &M,
    ) -> Result<(), Status> {
        let event = WorkoutEventRecord {
            event_id: Uuid::new_v4().to_string(),
            user_id: user_id.to_string(),
            workout_id: workout_id.to_string(),
            recorded_at: now_unix(),
            event_type,
            payload: message.encode_to_vec(),
        };
        self.central_db
            .append_workout_event(&event)
            .await
            .map_err(|e| Status::internal(format!("Failed to append workout event: {}", e)))?;
        Ok(())
    }
}

// Helper to extract user_id from request metadata.
pub async fn get_user_id_authenticated<T>(
    request: &Request<T>,
    central_db: &CentralDb,
) -> Result<String, Status> {
    if let Some(token) = request
        .metadata()
        .get("x-session-token")
        .and_then(|v| v.to_str().ok())
    {
        if let Ok(Some(user_id)) = central_db.validate_auth_session(token).await {
            return Ok(user_id);
        }
    }

    Err(Status::unauthenticated("Authentication required"))
}

const END_OF_EXERCISE_GROUP_REST_SECONDS: i64 = 10;
const WORKOUT_DRAFT_SETTING_TYPE: &str = "workout_draft";

#[cfg(test)]
#[path = "../service_workout_tests.rs"]
mod tests;
