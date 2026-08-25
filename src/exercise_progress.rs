//! Per-exercise trackers and the one progression rule: double progression.
//!
//! A tracker holds, per user per exercise, the working weight, the current
//! rep target inside the prescription's range, and the miss streak. After
//! a workout the tracker advances: reps first, then load.
//!
//! | Outcome | Next state |
//! |---|---|
//! | Every planned set hit its target, lowest reps `m >= range top` | weight + one equipment step, reps back to the range bottom |
//! | Every planned set hit its target, `m < top` | rep target becomes `m + 1` |
//! | A set missed or was skipped | hold; two misses running → weight × 0.9, reps to the bottom |
//! | No load (bodyweight) | reps only, weight stays 0 |
//!
//! The weight basis is always the weight you *performed* (the last working
//! set you completed), not the stored weight — a mid-session edit carries
//! through. All weights are stored in pounds and snapped to loadable
//! values in the user's display unit.

use std::collections::HashMap;

use crate::exercise_catalog::{
    prescription, progression_increment_lb, snap_weight_lb, starting_weight_lb, Prescription,
};
use crate::history::{workout_time, WorkoutRecord};
use crate::weight_units::AppWeightUnit;
use schlift::workout::v1::{Exercise, ProposedSet};

/// How many misses at a weight before backing off it.
const MISSES_BEFORE_DELOAD: i32 = 2;
/// How far a deload drops.
const DELOAD_FACTOR: f32 = 0.9;
/// Rep ceiling for bodyweight moves, which progress by reps alone.
const BODYWEIGHT_REP_CAP: i32 = 30;
/// Cap on the derived weight series (the client charts a recent window).
pub const WEIGHT_HISTORY_LIMIT: usize = 12;

/// The stored state of one tracker. `working_weight <= 0` and
/// `current_reps <= 0` mean "never set"; resolution fills them from the
/// catalog. Overrides of 0 mean "derived".
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct TrackerState {
    pub working_weight: f32, // lb
    pub current_reps: i32,
    pub consecutive_misses: i32,
    pub last_performed_at: i64,
    pub override_sets: i32,
    pub override_rep_low: i32,
    pub override_rep_high: i32,
}

/// A tracker with every value filled in: what the next workout will use.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ResolvedTracker {
    pub working_weight: f32, // lb, snapped
    pub sets: i32,
    pub target_reps: i32,
    pub rep_low: i32,
    pub rep_high: i32,
    pub rest_seconds: i32,
    pub rest_seconds_failure: i32,
    pub include_warmup: bool,
    pub last_performed_at: i64,
    pub overridden: bool,
}

/// The prescription with the tracker's overrides folded in.
pub fn effective_prescription(ex: Exercise, state: &TrackerState) -> Prescription {
    let mut p = prescription(ex);
    if state.override_sets > 0 {
        p.sets = state.override_sets;
    }
    if state.override_rep_low > 0 && state.override_rep_high >= state.override_rep_low {
        p.rep_low = state.override_rep_low;
        p.rep_high = state.override_rep_high;
    }
    p
}

pub fn resolve_tracker(
    ex: Exercise,
    state: Option<&TrackerState>,
    unit: AppWeightUnit,
) -> ResolvedTracker {
    let default_state = TrackerState::default();
    let state = state.unwrap_or(&default_state);
    let p = effective_prescription(ex, state);
    let weight = if state.working_weight > 0.0 {
        snap_weight_lb(ex, state.working_weight, unit)
    } else {
        starting_weight_lb(ex, unit)
    };
    let target_reps = state.current_reps.clamp(p.rep_low, p.rep_high);
    ResolvedTracker {
        working_weight: weight,
        sets: p.sets,
        target_reps,
        rep_low: p.rep_low,
        rep_high: p.rep_high,
        rest_seconds: p.rest_seconds,
        rest_seconds_failure: p.rest_seconds_failure,
        include_warmup: p.include_warmup,
        last_performed_at: state.last_performed_at,
        overridden: state.override_sets > 0 || state.override_rep_low > 0,
    }
}

/// One session's worth of one exercise, reduced to what progression needs.
#[derive(Clone, Copy, Debug)]
pub struct SessionOutcome {
    pub at: i64,
    /// Lowest actual reps across completed planned working sets.
    pub min_reps: i32,
    /// Weight of the last working set actually finished (wall-clock).
    pub performed_weight: f32,
    /// Heaviest completed working set (for the weight-history series).
    pub top_weight: f32,
    /// Whether every planned set was completed at its target.
    pub cleared: bool,
}

/// Reduce one workout to per-exercise outcomes. Warmups, cancelled sets
/// and sets never finished are excluded — they say nothing about whether
/// you cleared the work. Judgement uses the target stamped on each set,
/// so an edited session is judged by what was attempted.
pub fn session_outcomes(record: &WorkoutRecord) -> HashMap<i32, SessionOutcome> {
    let proposed_by_id: HashMap<&str, &ProposedSet> = record
        .proposed_sets
        .iter()
        .map(|set| (set.id.as_str(), set))
        .collect();

    let mut planned: HashMap<i32, usize> = HashMap::new();
    for set in record
        .proposed_sets
        .iter()
        .filter(|set| !set.warmup && !set.cancelled)
    {
        *planned.entry(set.exercise).or_insert(0) += 1;
    }

    struct Acc {
        successful: usize,
        completed: usize,
        min_reps: i32,
        last_done: (i64, f32),
        top_weight: f32,
    }
    let mut acc: HashMap<i32, Acc> = HashMap::new();
    for completed in record.completed_sets.iter().filter(|set| set.ended_at > 0) {
        let Some(proposed) = proposed_by_id.get(completed.proposed_set_id.as_str()) else {
            continue;
        };
        if proposed.warmup || proposed.cancelled {
            continue;
        }
        let entry = acc.entry(proposed.exercise).or_insert(Acc {
            successful: 0,
            completed: 0,
            min_reps: i32::MAX,
            last_done: (0, 0.0),
            top_weight: 0.0,
        });
        entry.completed += 1;
        entry.min_reps = entry.min_reps.min(completed.actual_reps);
        if proposed.target_reps > 0 && completed.actual_reps >= proposed.target_reps {
            entry.successful += 1;
        }
        if completed.ended_at >= entry.last_done.0 {
            entry.last_done = (completed.ended_at, completed.actual_weight);
        }
        if completed.actual_weight > entry.top_weight {
            entry.top_weight = completed.actual_weight;
        }
    }

    let at = workout_time(record);
    acc.into_iter()
        .map(|(exercise, a)| {
            let planned_sets = planned.get(&exercise).copied().unwrap_or(0);
            (
                exercise,
                SessionOutcome {
                    at,
                    min_reps: if a.min_reps == i32::MAX { 0 } else { a.min_reps },
                    performed_weight: a.last_done.1,
                    top_weight: a.top_weight,
                    cleared: planned_sets > 0
                        && a.completed >= planned_sets
                        && a.successful >= planned_sets,
                },
            )
        })
        .collect()
}

/// Advance one tracker by one session — the double-progression rule.
pub fn advance_tracker(
    ex: Exercise,
    state: &TrackerState,
    outcome: &SessionOutcome,
    unit: AppWeightUnit,
) -> TrackerState {
    let p = effective_prescription(ex, state);
    let mut next = *state;
    next.last_performed_at = outcome.at;

    // Bodyweight (or a set logged with no load): reps are the only lever.
    if outcome.performed_weight <= 0.0 {
        next.working_weight = 0.0;
        next.consecutive_misses = 0;
        if outcome.cleared {
            next.current_reps = (outcome.min_reps + 1).clamp(p.rep_low, BODYWEIGHT_REP_CAP);
        }
        return next;
    }

    if outcome.cleared {
        next.consecutive_misses = 0;
        if outcome.min_reps >= p.rep_high {
            // Range topped out on every set: add one equipment step and
            // drop back to the bottom of the range.
            let step = progression_increment_lb(ex, unit);
            next.working_weight =
                snap_weight_lb(ex, outcome.performed_weight + step, unit);
            next.current_reps = p.rep_low;
        } else {
            // Progress by reps: next target follows the worst set + 1, so
            // beating the target by more moves the target by more.
            next.working_weight = snap_weight_lb(ex, outcome.performed_weight, unit);
            next.current_reps = (outcome.min_reps + 1).clamp(p.rep_low, p.rep_high);
        }
    } else {
        next.working_weight = snap_weight_lb(ex, outcome.performed_weight, unit);
        next.consecutive_misses = state.consecutive_misses + 1;
        if next.consecutive_misses >= MISSES_BEFORE_DELOAD {
            // Two misses running: back off a tenth and rebuild through the
            // rep range rather than grinding the same weight forever.
            next.working_weight =
                snap_weight_lb(ex, outcome.performed_weight * DELOAD_FACTOR, unit);
            next.current_reps = p.rep_low;
            next.consecutive_misses = 0;
        }
    }
    next
}

/// Replay history into trackers. Seeds the migration and can repair a
/// tracker table; live updates go through `advance_tracker` at
/// EndWorkout.
pub fn derive_trackers_from_history(
    history: &[WorkoutRecord],
    unit: AppWeightUnit,
) -> HashMap<i32, TrackerState> {
    let mut ordered: Vec<&WorkoutRecord> = history
        .iter()
        .filter(|record| workout_time(record) > 0)
        .collect();
    ordered.sort_by_key(|record| workout_time(record));

    let mut trackers: HashMap<i32, TrackerState> = HashMap::new();
    for record in ordered {
        for (exercise_value, outcome) in session_outcomes(record) {
            let Ok(ex) = Exercise::try_from(exercise_value) else {
                continue;
            };
            if ex == Exercise::Unspecified {
                continue;
            }
            let state = trackers.entry(exercise_value).or_default();
            *state = advance_tracker(ex, state, &outcome, unit);
        }
    }
    trackers
}

/// Top working weight per session per exercise, oldest first, capped at
/// `WEIGHT_HISTORY_LIMIT` — the little sparkline series on a tracker.
pub fn weight_history(history: &[WorkoutRecord]) -> HashMap<i32, Vec<f32>> {
    let mut ordered: Vec<&WorkoutRecord> = history
        .iter()
        .filter(|record| workout_time(record) > 0)
        .collect();
    ordered.sort_by_key(|record| workout_time(record));

    let mut out: HashMap<i32, Vec<f32>> = HashMap::new();
    for record in ordered {
        for (exercise, outcome) in session_outcomes(record) {
            let series = out.entry(exercise).or_default();
            series.push(outcome.top_weight);
            if series.len() > WEIGHT_HISTORY_LIMIT {
                let overflow = series.len() - WEIGHT_HISTORY_LIMIT;
                series.drain(0..overflow);
            }
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use schlift::workout::v1::{CompletedSet, Workout};

    fn proposed(id: &str, ex: Exercise, weight: f32, reps: i32, warmup: bool) -> ProposedSet {
        ProposedSet {
            id: id.to_string(),
            exercise: ex as i32,
            target_weight: weight,
            target_reps: reps,
            warmup,
            ..Default::default()
        }
    }

    fn completed(proposed_id: &str, reps: i32, weight: f32, ended_at: i64) -> CompletedSet {
        CompletedSet {
            proposed_set_id: proposed_id.to_string(),
            actual_reps: reps,
            actual_weight: weight,
            started_at: ended_at - 30,
            ended_at,
            ..Default::default()
        }
    }

    /// One session: `sets` sets at `weight`, targets `target` reps, and
    /// the actual reps given per set.
    fn session(
        id: &str,
        at: i64,
        ex: Exercise,
        weight: f32,
        target: i32,
        actuals: &[i32],
    ) -> WorkoutRecord {
        let mut proposed_sets = Vec::new();
        let mut completed_sets = Vec::new();
        for (i, actual) in actuals.iter().enumerate() {
            let set_id = format!("{id}_s{i}");
            proposed_sets.push(proposed(&set_id, ex, weight, target, false));
            completed_sets.push(completed(&set_id, *actual, weight, at - (actuals.len() - i) as i64));
        }
        WorkoutRecord {
            workout: Workout {
                id: id.to_string(),
                start_time: at - 3600,
                end_time: at,
                ..Default::default()
            },
            proposed_sets,
            completed_sets,
        }
    }

    fn advance(ex: Exercise, state: TrackerState, record: &WorkoutRecord) -> TrackerState {
        let outcomes = session_outcomes(record);
        let outcome = outcomes.get(&(ex as i32)).expect("exercise in session");
        advance_tracker(ex, &state, outcome, AppWeightUnit::Lb)
    }

    /// The everyday case: clear the target below the top of the range and
    /// the reps move, not the weight.
    #[test]
    fn clearing_mid_range_adds_a_rep() {
        // Lateral raise 10–15. Target 10, did 11/10/10 → next target 11.
        let record = session("w1", 1000, Exercise::LateralRaise, 20.0, 10, &[11, 10, 10]);
        let next = advance(Exercise::LateralRaise, TrackerState::default(), &record);
        assert_eq!(next.current_reps, 11);
        assert_eq!(next.working_weight, 20.0, "weight holds while reps climb");
        assert_eq!(next.consecutive_misses, 0);
    }

    /// Beating the target by more moves the target by more: the next
    /// target follows the worst set.
    #[test]
    fn the_next_target_follows_the_worst_set() {
        let record = session("w1", 1000, Exercise::LateralRaise, 20.0, 10, &[14, 13, 13]);
        let next = advance(Exercise::LateralRaise, TrackerState::default(), &record);
        assert_eq!(next.current_reps, 14, "13 everywhere → target 14");
    }

    /// Top of the range on every set: one equipment step up, reps reset.
    #[test]
    fn topping_the_range_adds_load_and_resets_reps() {
        let record = session("w1", 1000, Exercise::LateralRaise, 20.0, 15, &[15, 15, 15]);
        let next = advance(Exercise::LateralRaise, TrackerState::default(), &record);
        assert_eq!(next.working_weight, 25.0, "one dumbbell step");
        assert_eq!(next.current_reps, 10, "back to the range bottom");
    }

    /// A barbell step lands on a loadable weight.
    #[test]
    fn barbell_load_bump_snaps_loadable() {
        let record = session("w1", 1000, Exercise::Squat, 137.0, 10, &[10, 10, 10]);
        let next = advance(Exercise::Squat, TrackerState::default(), &record);
        assert_eq!(
            next.working_weight,
            crate::weight_units::snap_loadable_lb(142.0, AppWeightUnit::Lb)
        );
        assert_eq!(next.current_reps, 6, "squat range bottom");
    }

    /// One miss holds everything; the second miss running deloads 10%.
    #[test]
    fn two_misses_running_deload() {
        let miss = session("w1", 1000, Exercise::Squat, 200.0, 8, &[8, 7, 6]);
        let s1 = advance(Exercise::Squat, TrackerState::default(), &miss);
        assert_eq!(s1.consecutive_misses, 1);
        assert_eq!(s1.working_weight, 200.0, "first miss holds the weight");

        let miss2 = session("w2", 2000, Exercise::Squat, 200.0, 8, &[8, 7, 7]);
        let s2 = advance(Exercise::Squat, s1, &miss2);
        assert_eq!(s2.consecutive_misses, 0);
        assert_eq!(
            s2.working_weight,
            crate::weight_units::snap_loadable_lb(180.0, AppWeightUnit::Lb),
            "second miss deloads a tenth"
        );
        assert_eq!(s2.current_reps, 6);
    }

    /// A clear between misses resets the streak — one bad day never
    /// compounds into a deload.
    #[test]
    fn a_clear_resets_the_miss_streak() {
        let miss = session("w1", 1000, Exercise::Squat, 200.0, 8, &[7, 7, 7]);
        let s1 = advance(Exercise::Squat, TrackerState::default(), &miss);
        let clear = session("w2", 2000, Exercise::Squat, 200.0, 8, &[8, 8, 8]);
        let s2 = advance(Exercise::Squat, s1, &clear);
        assert_eq!(s2.consecutive_misses, 0);
        let miss3 = session("w3", 3000, Exercise::Squat, 200.0, 9, &[8, 8, 8]);
        let s3 = advance(Exercise::Squat, s2, &miss3);
        assert_eq!(s3.consecutive_misses, 1, "streak restarted, no deload");
        assert_eq!(s3.working_weight, 200.0);
    }

    /// Progression follows the weight you performed, not the plan — a
    /// mid-session edit carries through.
    #[test]
    fn progression_follows_the_performed_weight() {
        let mut record = session("w1", 1000, Exercise::Squat, 200.0, 10, &[10, 10, 10]);
        for set in &mut record.completed_sets {
            set.actual_weight = 185.0;
        }
        let next = advance(Exercise::Squat, TrackerState::default(), &record);
        assert_eq!(
            next.working_weight,
            crate::weight_units::snap_loadable_lb(190.0, AppWeightUnit::Lb),
            "185 performed + 5, not 205"
        );
    }

    /// Bodyweight: reps climb without a cap at the range top, weight
    /// stays zero.
    #[test]
    fn bodyweight_progresses_by_reps_alone() {
        let record = session("w1", 1000, Exercise::PullUp, 0.0, 15, &[16, 15, 15]);
        let next = advance(Exercise::PullUp, TrackerState::default(), &record);
        assert_eq!(next.working_weight, 0.0);
        assert_eq!(next.current_reps, 16, "past the range top is fine");
    }

    /// Warmups say nothing about clearing the work.
    #[test]
    fn warmups_are_ignored() {
        let mut record = session("w1", 1000, Exercise::Squat, 200.0, 8, &[8, 8, 8]);
        record
            .proposed_sets
            .push(proposed("warm", Exercise::Squat, 95.0, 5, true));
        record.completed_sets.push(completed("warm", 5, 95.0, 900));
        let next = advance(Exercise::Squat, TrackerState::default(), &record);
        assert_eq!(next.working_weight, 200.0, "warmup weight never leaks in");
        assert_eq!(next.current_reps, 9);
    }

    /// A set with no rep target cannot be judged; it neither advances nor
    /// counts as a miss.
    #[test]
    fn a_targetless_session_holds() {
        let record = session("w1", 1000, Exercise::CableCrunch, 60.0, 0, &[12, 12, 12]);
        let next = advance(Exercise::CableCrunch, TrackerState::default(), &record);
        assert_eq!(next.working_weight, 60.0);
        assert_eq!(next.consecutive_misses, 1, "counts as not-cleared, held");
    }

    /// Overrides move the goalposts everywhere: a 5-set 6–8 override on
    /// the tracker drives both resolution and progression.
    #[test]
    fn overrides_change_the_range() {
        let state = TrackerState {
            override_sets: 5,
            override_rep_low: 6,
            override_rep_high: 8,
            ..Default::default()
        };
        let resolved = resolve_tracker(Exercise::LateralRaise, Some(&state), AppWeightUnit::Lb);
        assert_eq!(resolved.sets, 5);
        assert_eq!((resolved.rep_low, resolved.rep_high), (6, 8));
        assert!(resolved.overridden);

        let record = session("w1", 1000, Exercise::LateralRaise, 20.0, 8, &[8, 8, 8, 8, 8]);
        let next = advance(Exercise::LateralRaise, state, &record);
        assert_eq!(next.working_weight, 25.0, "topped the overridden range");
        assert_eq!(next.current_reps, 6, "reset to the overridden bottom");
    }

    /// Resolution with no tracker row: catalog opener, range bottom.
    #[test]
    fn a_fresh_exercise_resolves_to_the_opener() {
        let resolved = resolve_tracker(Exercise::Squat, None, AppWeightUnit::Lb);
        assert_eq!(resolved.working_weight, 45.0);
        assert_eq!(resolved.target_reps, 6);
        assert_eq!(resolved.sets, 3);
        assert!(resolved.include_warmup);
    }

    /// Replay: two cleared sessions land where live advancement would.
    #[test]
    fn derive_replays_history() {
        let history = vec![
            session("w1", 1000, Exercise::LateralRaise, 20.0, 15, &[15, 15, 15]),
            session("w2", 2000, Exercise::LateralRaise, 25.0, 10, &[11, 11, 11]),
        ];
        let trackers = derive_trackers_from_history(&history, AppWeightUnit::Lb);
        let state = trackers[&(Exercise::LateralRaise as i32)];
        assert_eq!(state.working_weight, 25.0);
        assert_eq!(state.current_reps, 12);
        assert_eq!(state.last_performed_at, 2000);
    }

    #[test]
    fn weight_history_is_per_session_tops_oldest_first() {
        let history = vec![
            session("w2", 2000, Exercise::Squat, 205.0, 8, &[8, 8, 8]),
            session("w1", 1000, Exercise::Squat, 200.0, 8, &[8, 8, 8]),
        ];
        let series = weight_history(&history);
        assert_eq!(series[&(Exercise::Squat as i32)], vec![200.0, 205.0]);
    }
}
