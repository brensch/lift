//! One workout, hydrated: the record every derived computation reads
//! (progression, volume, recovery, weight history).

use schlift::workout::v1::{CompletedSet, ExerciseGroup, ProposedSet, Workout};

#[derive(Clone, Debug)]
pub struct WorkoutRecord {
    pub workout: Workout,
    /// Carried for completeness (hydration loads it); nothing derived reads
    /// group structure today.
    #[allow(dead_code)]
    pub exercise_groups: Vec<ExerciseGroup>,
    pub proposed_sets: Vec<ProposedSet>,
    pub completed_sets: Vec<CompletedSet>,
}

/// The moment a workout "happened": its end, or its start while open.
pub fn workout_time(record: &WorkoutRecord) -> i64 {
    if record.workout.end_time > 0 {
        record.workout.end_time
    } else {
        record.workout.start_time
    }
}
