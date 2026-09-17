use crate::state::ActiveWorkout;
pub use schlift::workout::v1::{
    AdjustExerciseWeightRequest, CancelProposedSetRequest, CompleteSetRequest, CompletedSet,
    DeleteCompletedSetRequest, GetWorkoutResponse, ProposedSet, RemoveExerciseRequest,
    ReorderExercisesRequest, StartSetRequest, StartWorkoutResponse, WorkoutPlanChangeStats,
    WorkoutStateSnapshot,
};
use std::time::{SystemTime, UNIX_EPOCH};
use tonic::Status;
use uuid::Uuid;

mod planning;
mod reducer;

pub(crate) use planning::{
    apply_add_exercises, apply_adjust_exercise_weight, apply_remove_exercise,
    apply_reorder_exercises, ExercisePlan,
};
pub(crate) use reducer::{
    active_from_get_workout_response, active_proposed_sets, apply_cancel_proposed_set_to_active,
    apply_complete_set_to_active, apply_delete_completed_set_to_active, apply_start_set_to_active,
    get_workout_response_from_active, is_final_set_of_exercise_after_completion,
    start_workout_response_from_active, workout_plan_change_stats_from_sets,
    workout_state_snapshot_from_state,
};

#[derive(Clone, Copy, Debug)]
pub(crate) enum WorkoutError {
    FailedPrecondition(&'static str),
    Internal(&'static str),
    NotFound(&'static str),
}

impl WorkoutError {
    pub(crate) fn failed_precondition(message: &'static str) -> Self {
        Self::FailedPrecondition(message)
    }

    pub(crate) fn internal(message: &'static str) -> Self {
        Self::Internal(message)
    }

    pub(crate) fn not_found(message: &'static str) -> Self {
        Self::NotFound(message)
    }
}

impl From<WorkoutError> for Status {
    fn from(value: WorkoutError) -> Self {
        match value {
            WorkoutError::FailedPrecondition(message) => Status::failed_precondition(message),
            WorkoutError::Internal(message) => Status::internal(message),
            WorkoutError::NotFound(message) => Status::not_found(message),
        }
    }
}

// Helper to get current Unix timestamp
pub fn now_unix() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs() as i64
}

/// Rest after an exercise's final set — no point in a full working rest when
/// the next thing is a different exercise.
pub(crate) const END_OF_EXERCISE_REST_SECONDS: i64 = 60;
