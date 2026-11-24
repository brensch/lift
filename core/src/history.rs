//! One workout, hydrated: the record every derived computation reads
//! (the plan's walk, volume, recovery, progress).

use std::collections::HashSet;

use crate::pb::{
    CompletedSet, ExerciseDecision, ExerciseLog, ProposedSet, SetRole, WeightChange,
    WeightChangeCause, Workout, WorkoutHeartRatePoint,
};
use crate::program::ProgramRef;
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
    /// The program it was planned under: its warmups, ramp and loading lay
    /// its sets out, whatever program is set after it.
    pub program: ProgramRef,
}

/// A record, or one shared (`Account::workouts`): what the history's
/// readers take.
impl AsRef<WorkoutRecord> for WorkoutRecord {
    fn as_ref(&self) -> &WorkoutRecord {
        self
    }
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
            program: self.program.clone(),
        }
    }

    /// Reassign workout_order to match the vec's current order. Plan-shaping
    /// operations arrange the vec, then call this to make the order canonical.
    pub fn renumber_sets(&mut self) {
        interleave_groups(&mut self.proposed_sets);
        for (idx, set) in self.proposed_sets.iter_mut().enumerate() {
            set.workout_order = idx as i32;
        }
    }

    /// The decision a lift was last given in this workout.
    pub fn decision(&self, exercise: &str) -> Option<&ExerciseDecision> {
        self.exercise_logs
            .iter()
            .rev()
            .filter_map(|log| log.decision.as_ref())
            .find(|d| d.exercise == exercise)
    }

    /// The working weight a lift is at now: its last change (a correction
    /// fixes a done set, not the plan) or, before any, its decision's.
    pub fn planned_weight(&self, exercise: &str) -> f32 {
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

    fn log(&self, exercise: &str) -> Option<&ExerciseLog> {
        self.exercise_logs.iter().rev().find(|log| {
            log.decision
                .as_ref()
                .is_some_and(|d| d.exercise == exercise)
        })
    }

    /// Record a change to a lift's weight on its log. A change that leaves
    /// the weight where it was is not one.
    pub fn log_change(&mut self, exercise: &str, change: WeightChange) {
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

    /// A drop or a mini-set: work, but taken to failure by design, so it
    /// says nothing about whether the session was hit and counts partly
    /// toward a muscle's week.
    pub fn is_partial(&self) -> bool {
        matches!(
            SetRole::try_from(self.role),
            Ok(SetRole::Drop | SetRole::Mini)
        )
    }

    /// A working set that isn't partial: what a lift's sets count and its
    /// session is judged by.
    pub fn is_main(&self) -> bool {
        self.is_working() && !self.is_partial()
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

/// A group's sets in the order they're done: where the group's first set
/// is, every lift's warmups and ramp first (in the lifts' order), then
/// round by round, each lift's next main set with the drops and minis that
/// follow it. Lifts outside a group keep their places. Doing it again
/// changes nothing, and a workout without groups is untouched.
pub fn interleave_groups(sets: &mut Vec<ProposedSet>) {
    let mut groups: Vec<String> = Vec::new();
    for set in sets.iter() {
        if !set.group.is_empty() && !groups.contains(&set.group) {
            groups.push(set.group.clone());
        }
    }
    for group in groups {
        let Some(first) = sets.iter().position(|s| s.group == group) else {
            continue;
        };
        let mut taken: Vec<ProposedSet> = Vec::new();
        let mut kept: Vec<ProposedSet> = Vec::with_capacity(sets.len());
        for set in sets.drain(..) {
            if set.group == group {
                taken.push(set);
            } else {
                kept.push(set);
            }
        }
        let mut lifts: Vec<String> = Vec::new();
        for set in &taken {
            if !lifts.contains(&set.exercise) {
                lifts.push(set.exercise.clone());
            }
        }
        let mut leads: Vec<ProposedSet> = Vec::new();
        let mut rounds: Vec<Vec<Vec<ProposedSet>>> = vec![Vec::new(); lifts.len()];
        for set in taken {
            let lift = lifts.iter().position(|k| *k == set.exercise).unwrap_or(0);
            let main = !matches!(
                SetRole::try_from(set.role),
                Ok(SetRole::Drop | SetRole::Mini)
            );
            if set.warmup || set.calibration {
                leads.push(set);
            } else if main || rounds[lift].is_empty() {
                rounds[lift].push(vec![set]);
            } else if let Some(round) = rounds[lift].last_mut() {
                round.push(set);
            }
        }
        let most = rounds.iter().map(Vec::len).max().unwrap_or(0);
        let mut ordered = leads;
        for r in 0..most {
            for lift in &mut rounds {
                if let Some(round) = lift.get_mut(r) {
                    ordered.append(round);
                }
            }
        }
        let at = first.min(kept.len());
        kept.splice(at..at, ordered);
        *sets = kept;
    }
}
