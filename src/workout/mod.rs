use crate::state::ActiveWorkout;
pub use schlift::workout::v1::{
    CancelProposedSetRequest, CompleteSetRequest, CompletedSet, DeleteCompletedSetRequest,
    ExerciseGroup, ExerciseTypeConfig, GetWorkoutResponse, PlannedGroupSet, ProposedSet,
    ReorderExerciseGroupsRequest, ReplaceExerciseGroupPlanRequest, RestConfig, StartSetRequest,
    StartWorkoutResponse, WorkingSetSpec, WorkoutPlanChangeStats, WorkoutStateSnapshot,
};
use std::time::{SystemTime, UNIX_EPOCH};
use tonic::Status;
use uuid::Uuid;

mod planning;
mod reducer;

pub(crate) use planning::{
    apply_reorder_exercise_groups, apply_replace_exercise_group_plan, generate_sets_for_group,
};
pub(crate) use reducer::{
    active_from_get_workout_response, active_proposed_sets, apply_cancel_proposed_set_to_active,
    apply_complete_set_to_active, apply_delete_completed_set_to_active, apply_start_set_to_active,
    get_workout_response_from_active, is_final_set_in_exercise_group_after_completion,
    start_workout_response_from_active, workout_plan_change_stats_from_sets,
    workout_state_snapshot_from_state,
};

// Helper to get current Unix timestamp
pub fn now_unix() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs() as i64
}

pub(crate) const END_OF_EXERCISE_GROUP_REST_SECONDS: i64 = 10;
