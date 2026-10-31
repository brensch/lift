//! One workout, hydrated: the record every derived computation reads
//! (progression, volume, recovery, weight history).

use crate::pb::{CompletedSet, ProposedSet, Workout, WorkoutHeartRatePoint};

/// A workout's full state: the row, its ordered flat set list (there is no
/// group structure — "the sets for one exercise" is derived wherever it's
/// needed), what was done, and the heart rate through it.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct WorkoutRecord {
    pub workout: Workout,
    pub proposed_sets: Vec<ProposedSet>,
    pub completed_sets: Vec<CompletedSet>,
    pub heart_rate: Vec<WorkoutHeartRatePoint>,
}

impl WorkoutRecord {
    pub fn new(
        workout: Workout,
        proposed_sets: Vec<ProposedSet>,
        completed_sets: Vec<CompletedSet>,
    ) -> Self {
        Self {
            workout,
            proposed_sets,
            completed_sets,
            heart_rate: Vec::new(),
        }
    }

    /// Reassign workout_order to match the vec's current order. Plan-shaping
    /// operations arrange the vec, then call this to make the order canonical.
    pub fn renumber_sets(&mut self) {
        for (idx, set) in self.proposed_sets.iter_mut().enumerate() {
            set.workout_order = idx as i32;
        }
    }
}

/// The moment a workout "happened": its end, or its start while open.
pub fn workout_time(record: &WorkoutRecord) -> i64 {
    if record.workout.end_time > 0 {
        record.workout.end_time
    } else {
        record.workout.start_time
    }
}
