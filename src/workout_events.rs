#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum WorkoutEventType {
    Checkpoint = 1,
    StartSet = 2,
    CompleteSet = 3,
    DeleteCompletedSet = 4,
    CancelProposedSet = 5,
    EndWorkout = 6,
    ReplaceExerciseGroupPlan = 7,
    ReorderExerciseGroups = 8,
}

impl WorkoutEventType {
    pub fn from_i32(value: i32) -> Option<Self> {
        match value {
            1 => Some(Self::Checkpoint),
            2 => Some(Self::StartSet),
            3 => Some(Self::CompleteSet),
            4 => Some(Self::DeleteCompletedSet),
            5 => Some(Self::CancelProposedSet),
            6 => Some(Self::EndWorkout),
            7 => Some(Self::ReplaceExerciseGroupPlan),
            8 => Some(Self::ReorderExerciseGroups),
            _ => None,
        }
    }
}

#[derive(Clone, Debug)]
pub struct WorkoutEventRecord {
    pub event_id: String,
    pub user_id: String,
    pub workout_id: String,
    pub recorded_at: i64,
    pub event_type: WorkoutEventType,
    pub payload: Vec<u8>,
}
