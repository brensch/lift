pub use crate::events::{
    ExerciseAdjusted, ExerciseRemoved, ExercisesReordered, RungAnswered, SetCompleted, SetEdited,
    SetStarted, SetUndone, WarmupsSkipped,
};
use crate::history::WorkoutRecord;
pub use crate::pb::{
    CompletedSet, GetWorkoutResponse, ProposedSet, StartWorkoutResponse, WorkoutStateSnapshot,
};

mod planning;
mod reducer;

pub use planning::{
    apply_add_exercises, apply_adjust_exercise_weight, apply_remove_exercise,
    apply_reorder_exercises, MAX_CALIBRATION_RUNGS, TOO_HEAVY_REPS,
};
pub use reducer::{
    apply_answer_rung_to_active, apply_complete_set_to_active,
    apply_delete_completed_set_to_active, apply_edit_completed_set_to_active,
    apply_skip_warmups_to_active, apply_start_set_to_active, get_workout_response_from_active,
    start_workout_response_from_active,
};

#[derive(Clone, Copy, Debug)]
pub enum WorkoutError {
    FailedPrecondition(&'static str),
}

/// Rest after an exercise's final set — no point in a full working rest when
/// the next thing is a different exercise.
pub const END_OF_EXERCISE_REST_SECONDS: i64 = 60;
