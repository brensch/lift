//! What one session says about a lift: every working set and calibration
//! rung done, in the order done, whether the session ran its course, and
//! whether a miss was rushed.
//! The plan's walk (`crate::plan`) reads these and nothing else from
//! history.
//!
//! Warmups, cancelled sets and sets never finished say nothing about the
//! user's strength and are left out. Each set is judged against the target
//! stamped on it, so a session changed mid-way is judged by what was
//! attempted.

use std::collections::{HashMap, HashSet};

use crate::history::{workout_time, WorkoutRecord};
use crate::pb::ProposedSet;

/// One set as lifted.
#[derive(Clone, Debug, PartialEq)]
pub struct SetDone {
    pub set_id: String,
    pub weight: f32, // lb
    pub reps: i32,
    /// The reps it was planned for.
    pub target: i32,
    /// Every target rep done.
    pub hit: bool,
}

/// One session of one lift.
#[derive(Clone, Debug, PartialEq)]
pub struct SessionOutcome {
    pub workout_id: String,
    pub started_at: i64,
    /// When it happened: the workout's end.
    pub at: i64,
    /// The working sets judged, in the order done.
    pub sets: Vec<SetDone>,
    /// The calibration rungs done, in the order done.
    pub rungs: Vec<SetDone>,
    /// The session did not run its course: a working set of this lift was
    /// left undone (the lift removed, or the workout ended first).
    pub stopped_early: bool,
    /// A working set was missed before the previous set's rest was over:
    /// excused, not a real miss. The set is left out of `sets`.
    pub rushed: bool,
    /// The working sets planned for it, done or not: the decision's when
    /// the workout recorded one.
    pub planned_sets: i32,
}

impl SessionOutcome {
    /// Every working set done, every rep hit (none of it rushed).
    pub fn all_hit(&self) -> bool {
        !self.stopped_early
            && !self.rushed
            && !self.sets.is_empty()
            && self.sets.iter().all(|s| s.hit)
    }

    /// The max holds: the session stopped early, or a miss was rushed.
    pub fn excused(&self) -> bool {
        self.stopped_early || self.rushed
    }
}

/// Reduce one workout to per-lift outcomes. A lift with nothing done (no
/// working set and no rung) has none.
pub fn session_outcomes(record: &WorkoutRecord) -> HashMap<i32, SessionOutcome> {
    let proposed_by_id: HashMap<&str, &ProposedSet> = record
        .proposed_sets
        .iter()
        .map(|set| (set.id.as_str(), set))
        .collect();
    let mut done: Vec<_> = record
        .completed_sets
        .iter()
        .filter(|set| set.ended_at > 0)
        .collect();
    done.sort_by_key(|set| set.ended_at);
    let done_ids: HashSet<&str> = done.iter().map(|c| c.proposed_set_id.as_str()).collect();

    let mut out: HashMap<i32, SessionOutcome> = HashMap::new();
    for completed in &done {
        let Some(proposed) = proposed_by_id.get(completed.proposed_set_id.as_str()) else {
            continue;
        };
        if proposed.warmup || proposed.cancelled {
            continue;
        }
        let set = SetDone {
            set_id: proposed.id.clone(),
            weight: completed.actual_weight,
            reps: completed.actual_reps,
            target: proposed.target_reps,
            hit: proposed.target_reps > 0 && completed.actual_reps >= proposed.target_reps,
        };
        let outcome = out
            .entry(proposed.exercise)
            .or_insert_with(|| SessionOutcome {
                workout_id: record.workout.id.clone(),
                started_at: record.workout.start_time,
                at: workout_time(record),
                sets: Vec::new(),
                rungs: Vec::new(),
                stopped_early: false,
                rushed: false,
                planned_sets: 0,
            });
        if proposed.calibration {
            outcome.rungs.push(set);
        } else if !set.hit && done_early(record, completed.ended_at) {
            outcome.rushed = true;
        } else {
            outcome.sets.push(set);
        }
    }
    // The sets planned: the decision's, or (history brought in without
    // one) the working sets laid out.
    for set in record
        .proposed_sets
        .iter()
        .filter(|s| !s.warmup && !s.calibration && !s.cancelled)
    {
        if let Some(outcome) = out.get_mut(&set.exercise) {
            outcome.planned_sets += 1;
        }
    }
    for decision in record
        .exercise_logs
        .iter()
        .filter_map(|l| l.decision.as_ref())
    {
        if let Some(outcome) = out.get_mut(&decision.exercise) {
            outcome.planned_sets = decision.sets;
        }
    }
    // A working set never done: the lift was removed or the workout ended
    // first.
    for set in record
        .proposed_sets
        .iter()
        .filter(|s| !s.warmup && !s.calibration && !done_ids.contains(s.id.as_str()))
    {
        if let Some(outcome) = out.get_mut(&set.exercise) {
            outcome.stopped_early = true;
        }
    }
    out
}

/// Whether a set finished at `ended_at` was done early: before the rest
/// of the previous done set in the whole workout (any exercise, warmups
/// included) had ended.
fn done_early(record: &WorkoutRecord, ended_at: i64) -> bool {
    record
        .completed_sets
        .iter()
        .filter(|set| set.ended_at > 0 && set.ended_at < ended_at)
        .max_by_key(|set| set.ended_at)
        .is_some_and(|set| ended_at < set.rest_until)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pb::{CompletedSet, Exercise, Workout};

    fn proposed(id: &str, ex: Exercise, weight: f32, reps: i32) -> ProposedSet {
        ProposedSet {
            id: id.to_string(),
            exercise: ex as i32,
            target_weight: weight,
            target_reps: reps,
            ..Default::default()
        }
    }

    fn completed(proposed_id: &str, reps: i32, weight: f32, ended_at: i64) -> CompletedSet {
        CompletedSet {
            proposed_set_id: proposed_id.to_string(),
            actual_reps: reps,
            actual_weight: weight,
            ended_at,
            ..Default::default()
        }
    }

    /// One session: one set per entry of `actuals` at `weight`, each
    /// targeting `target` reps.
    fn session(ex: Exercise, weight: f32, target: i32, actuals: &[i32]) -> WorkoutRecord {
        let mut record = WorkoutRecord::new(
            Workout {
                id: "w1".to_string(),
                start_time: 1000,
                end_time: 5000,
                ..Default::default()
            },
            Vec::new(),
            Vec::new(),
        );
        for (i, actual) in actuals.iter().enumerate() {
            let set_id = format!("s{i}");
            record
                .proposed_sets
                .push(proposed(&set_id, ex, weight, target));
            record
                .completed_sets
                .push(completed(&set_id, *actual, weight, 2000 + i as i64));
        }
        record
    }

    fn outcome(record: &WorkoutRecord, ex: Exercise) -> SessionOutcome {
        session_outcomes(record)[&(ex as i32)].clone()
    }

    #[test]
    fn sets_come_in_the_order_done_and_are_judged_by_their_target() {
        let hit = outcome(
            &session(Exercise::Squat, 200.0, 5, &[5, 6, 5]),
            Exercise::Squat,
        );
        assert!(hit.all_hit());
        assert_eq!(hit.sets.len(), 3);
        assert_eq!((hit.sets[1].reps, hit.sets[1].weight), (6, 200.0));
        assert_eq!(
            (hit.workout_id.as_str(), hit.started_at, hit.at),
            ("w1", 1000, 5000)
        );

        let miss = outcome(
            &session(Exercise::Squat, 200.0, 5, &[5, 5, 4]),
            Exercise::Squat,
        );
        assert!(!miss.all_hit() && !miss.stopped_early);
        assert!(!miss.sets[2].hit);
    }

    /// A miss done before the previous set's rest ended is rushed, not a
    /// real miss, and every set was done: not stopped early.
    #[test]
    fn a_miss_done_early_is_rushed() {
        let mut record = session(Exercise::Squat, 200.0, 8, &[8, 8, 6]);
        record.completed_sets[1].rest_until = record.completed_sets[1].ended_at + 10;
        let outcome = outcome(&record, Exercise::Squat);
        assert!(outcome.rushed && !outcome.stopped_early);
        assert!(outcome.excused() && !outcome.all_hit());
        assert_eq!(outcome.sets.len(), 2, "the rushed miss is not judged");
    }

    /// A hit done before the rest ended is just a hit.
    #[test]
    fn a_hit_done_early_is_not_rushed() {
        let mut record = session(Exercise::Squat, 200.0, 8, &[8, 8, 8]);
        record.completed_sets[1].rest_until = record.completed_sets[1].ended_at + 10;
        let outcome = outcome(&record, Exercise::Squat);
        assert!(!outcome.rushed && outcome.all_hit());
    }

    /// A working set left undone (removed, or the workout ended) is
    /// stopping early.
    #[test]
    fn an_undone_working_set_stops_the_session_early() {
        let mut record = session(Exercise::Squat, 200.0, 6, &[6]);
        let mut cancelled = proposed("x1", Exercise::Squat, 200.0, 6);
        cancelled.cancelled = true;
        record.proposed_sets.push(cancelled);
        assert!(outcome(&record, Exercise::Squat).stopped_early);
        assert!(!outcome(&record, Exercise::Squat).rushed);

        let mut record = session(Exercise::Squat, 200.0, 6, &[6]);
        record
            .proposed_sets
            .push(proposed("x2", Exercise::Squat, 200.0, 6));
        assert!(outcome(&record, Exercise::Squat).stopped_early);
    }

    /// Rungs are kept apart from the working sets; warmups say nothing.
    #[test]
    fn rungs_are_apart_and_warmups_are_left_out() {
        let mut record = session(Exercise::Squat, 95.0, 5, &[5, 5]);
        for (i, weight) in [45.0, 65.0].iter().enumerate() {
            let id = format!("rung{i}");
            let mut rung = proposed(&id, Exercise::Squat, *weight, 5);
            rung.calibration = true;
            record.proposed_sets.push(rung);
            record
                .completed_sets
                .push(completed(&id, 5 - i as i32, *weight, 1500 + i as i64));
        }
        let mut warm = proposed("warm", Exercise::Squat, 45.0, 5);
        warm.warmup = true;
        record.proposed_sets.push(warm);
        record.completed_sets.push(completed("warm", 1, 45.0, 1400));
        let outcome = outcome(&record, Exercise::Squat);
        assert!(outcome.all_hit());
        assert_eq!(outcome.rungs.len(), 2);
        assert!(outcome.rungs[0].hit && !outcome.rungs[1].hit);
    }
}
