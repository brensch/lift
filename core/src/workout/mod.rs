use crate::history::WorkoutRecord;
pub use crate::pb::{
    AdjustExerciseWeightRequest, CompleteSetRequest, CompletedSet, DeleteCompletedSetRequest,
    GetWorkoutResponse, ProposedSet, RemoveExerciseRequest, ReorderExercisesRequest,
    StartWorkoutResponse, WorkoutPlanChangeStats, WorkoutStateSnapshot,
};

mod planning;
mod reducer;

pub use planning::{
    apply_add_exercises, apply_adjust_exercise_weight, apply_remove_exercise,
    apply_reorder_exercises, ExercisePlan,
};
pub use reducer::{
    active_from_get_workout_response, active_proposed_sets, apply_complete_set_to_active,
    apply_delete_completed_set_to_active, apply_edit_completed_set_to_active,
    apply_skip_warmups_to_active, apply_start_set_to_active, get_workout_response_from_active,
    start_workout_response_from_active, workout_plan_change_stats_from_sets,
    workout_state_snapshot,
};

#[derive(Clone, Copy, Debug)]
pub enum WorkoutError {
    FailedPrecondition(&'static str),
    Internal(&'static str),
}

impl WorkoutError {
    pub fn failed_precondition(message: &'static str) -> Self {
        Self::FailedPrecondition(message)
    }

    pub fn internal(message: &'static str) -> Self {
        Self::Internal(message)
    }
}

/// Rest after an exercise's final set — no point in a full working rest when
/// the next thing is a different exercise.
pub const END_OF_EXERCISE_REST_SECONDS: i64 = 60;
