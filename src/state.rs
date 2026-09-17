use schlift::workout::v1::{CompletedSet, ProposedSet, Workout};

/// A workout's full mutable state: the row plus its ordered flat set list.
/// There is no group structure — "the sets for one exercise" is derived
/// wherever it's needed.
#[derive(Clone, Debug)]
pub struct ActiveWorkout {
    pub workout: Workout,
    pub proposed_sets: Vec<ProposedSet>,
    pub completed_sets: Vec<CompletedSet>,
}

impl ActiveWorkout {
    pub fn new(
        workout: Workout,
        proposed_sets: Vec<ProposedSet>,
        completed_sets: Vec<CompletedSet>,
    ) -> Self {
        Self {
            workout,
            proposed_sets,
            completed_sets,
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
