//! One workout, hydrated: the record every derived computation reads
//! (the plan's walk, volume, recovery, progress).

use std::collections::HashSet;

use crate::pb::{
    CompletedSet, ExerciseDecision, ExerciseLog, ProposedSet, WeightChange, WeightChangeCause,
    Workout, WorkoutHeartRatePoint,
};
use crate::weight_units::AppWeightUnit;

/// A workout's full state: the row, its ordered flat set list (there is no
/// group structure — "the sets for one exercise" is derived wherever it's
/// needed), what was done, the heart rate through it, and per lift the
/// decision it started from with every change to its weight since.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct WorkoutRecord {
    pub workout: Workout,
    pub proposed_sets: Vec<ProposedSet>,
    pub completed_sets: Vec<CompletedSet>,
    pub heart_rate: Vec<WorkoutHeartRatePoint>,
    pub exercise_logs: Vec<ExerciseLog>,
    /// The unit it was planned in, which every snap and step in it rounds
    /// in: the workout's own, so it folds the same with or without the rest
    /// of the account.
    pub unit: AppWeightUnit,
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
            ..Default::default()
        }
    }

    /// A copy for changing the sets on: everything but the heart rate, which
    /// no change to the sets reads and which grows through the workout.
    pub fn without_heart_rate(&self) -> Self {
        Self {
            workout: self.workout.clone(),
            proposed_sets: self.proposed_sets.clone(),
            completed_sets: self.completed_sets.clone(),
            heart_rate: Vec::new(),
            exercise_logs: self.exercise_logs.clone(),
            unit: self.unit,
        }
    }

    /// Reassign workout_order to match the vec's current order. Plan-shaping
    /// operations arrange the vec, then call this to make the order canonical.
    pub fn renumber_sets(&mut self) {
        for (idx, set) in self.proposed_sets.iter_mut().enumerate() {
            set.workout_order = idx as i32;
        }
    }

    /// The decision a lift was last given in this workout.
    pub fn decision(&self, exercise: i32) -> Option<&ExerciseDecision> {
        self.exercise_logs
            .iter()
            .rev()
            .filter_map(|log| log.decision.as_ref())
            .find(|d| d.exercise == exercise)
    }

    /// The working weight a lift is at now: its last change (a correction
    /// fixes a done set, not the plan) or, before any, its decision's.
    pub fn planned_weight(&self, exercise: i32) -> f32 {
        let Some(log) = self.log(exercise) else {
            return 0.0;
        };
        log.changes
            .iter()
            .rev()
            .find(|c| c.cause != WeightChangeCause::Correction as i32)
            .map(|c| c.after)
            .or(log.decision.as_ref().map(|d| d.weight))
            .unwrap_or(0.0)
    }

    fn log(&self, exercise: i32) -> Option<&ExerciseLog> {
        self.exercise_logs.iter().rev().find(|log| {
            log.decision
                .as_ref()
                .is_some_and(|d| d.exercise == exercise)
        })
    }

    /// Record a change to a lift's weight on its log. A change that leaves
    /// the weight where it was is not one.
    pub fn log_change(&mut self, exercise: i32, change: WeightChange) {
        if (change.after - change.before).abs() < 1e-3 {
            return;
        }
        if let Some(log) = self.exercise_logs.iter_mut().rev().find(|log| {
            log.decision
                .as_ref()
                .is_some_and(|d| d.exercise == exercise)
        }) {
            log.changes.push(change);
        }
    }
}

impl ProposedSet {
    /// A set that counts as work: neither a warmup nor a calibration rung.
    pub fn is_working(&self) -> bool {
        !self.warmup && !self.calibration
    }
}

/// The proposed sets with a finished completion, by id.
pub fn done_set_ids(completed_sets: &[CompletedSet]) -> HashSet<String> {
    completed_sets
        .iter()
        .filter(|c| c.ended_at > 0)
        .map(|c| c.proposed_set_id.clone())
        .collect()
}

/// The moment a workout "happened": its end, or its start while open.
pub fn workout_time(record: &WorkoutRecord) -> i64 {
    if record.workout.end_time > 0 {
        record.workout.end_time
    } else {
        record.workout.start_time
    }
}
