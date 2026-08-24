//! Per-exercise-type progression.
//!
//! The regimes progress the handful of lifts they prescribe. This progresses
//! *everything else* — every exercise you've actually performed gets a tracked
//! working weight that climbs when you clear it, holds when you miss, and
//! deloads when you keep missing. That number is what the app prefills when you
//! add the exercise to a workout, so a group added mid-session resumes from
//! where you left off rather than from a generic default.
//!
//! It's derived from workout history rather than stored, so there's no second
//! source of truth to keep in sync with the sets you actually logged: edit or
//! delete a set and the progression follows. The regimes stay authoritative for
//! the lifts they program — see `exercise_statuses_for_schedule`, which layers
//! the two.

use std::collections::HashMap;

use crate::exercise_catalog::{
    all_exercises, category, default_reps, default_sets, progression_increment_lb, snap_weight_lb,
    starting_weight_lb,
};
use crate::recovery::{muscle_groups, MuscleRecovery};
use crate::schplanner::SchplannerWorkoutRecord;
use crate::weight_units::AppWeightUnit;
use schlift::workout::v1::{
    Exercise, ExerciseStatus, ProposedExerciseGroup, ProposedSet,
};

/// How many misses at a weight before we back off it.
const MISSES_BEFORE_DELOAD: i32 = 2;
/// How far back a deload drops you.
const DELOAD_FACTOR: f32 = 0.9;
/// Cap on the returned weight series (the client charts a recent window).
const WEIGHT_HISTORY_LIMIT: usize = 12;

/// What we know about one exercise from the user's own history.
#[derive(Clone, Debug)]
pub struct ExerciseProgression {
    /// The weight to prescribe next time, in pounds.
    pub target_weight: f32,
    pub target_reps: i32,
    pub target_sets: i32,
    pub last_performed_at: i64,
    /// Top working weight per session, oldest first.
    pub weight_history: Vec<f32>,
}

/// One session's worth of one exercise, reduced to the facts progression needs.
struct SessionOutcome {
    at: i64,
    /// Non-cancelled working sets that were prescribed.
    planned_sets: usize,
    /// Completed working sets that met their own rep target.
    successful_sets: usize,
    /// The weight of the last set you actually finished — progression follows
    /// what you did, not what was planned, so a mid-session weight edit counts.
    performed_weight: f32,
    top_weight: f32,
    target_reps: i32,
}

fn workout_time(record: &SchplannerWorkoutRecord) -> i64 {
    if record.workout.end_time > 0 {
        record.workout.end_time
    } else {
        record.workout.start_time
    }
}

/// Reduce one workout to per-exercise outcomes. Warmups, cancelled sets and
/// sets that were never finished are all excluded — they say nothing about
/// whether you cleared the work.
fn session_outcomes(record: &SchplannerWorkoutRecord) -> HashMap<i32, SessionOutcome> {
    let proposed_by_id: HashMap<&str, &ProposedSet> = record
        .proposed_sets
        .iter()
        .map(|set| (set.id.as_str(), set))
        .collect();

    let mut planned: HashMap<i32, usize> = HashMap::new();
    let mut target_reps: HashMap<i32, i32> = HashMap::new();
    for set in record
        .proposed_sets
        .iter()
        .filter(|set| !set.warmup && !set.cancelled)
    {
        *planned.entry(set.exercise).or_insert(0) += 1;
        target_reps.entry(set.exercise).or_insert(set.target_reps);
    }

    let mut successful: HashMap<i32, usize> = HashMap::new();
    // (ended_at, weight) of the last finished set, and the heaviest.
    let mut last_done: HashMap<i32, (i64, f32)> = HashMap::new();
    let mut top: HashMap<i32, f32> = HashMap::new();
    for completed in record.completed_sets.iter().filter(|set| set.ended_at > 0) {
        let Some(proposed) = proposed_by_id.get(completed.proposed_set_id.as_str()) else {
            continue;
        };
        if proposed.warmup || proposed.cancelled {
            continue;
        }
        let exercise = proposed.exercise;
        if completed.actual_reps >= proposed.target_reps && proposed.target_reps > 0 {
            *successful.entry(exercise).or_insert(0) += 1;
        }
        let entry = last_done.entry(exercise).or_insert((0, 0.0));
        if completed.ended_at >= entry.0 {
            *entry = (completed.ended_at, completed.actual_weight);
        }
        let best = top.entry(exercise).or_insert(0.0);
        if completed.actual_weight > *best {
            *best = completed.actual_weight;
        }
    }

    let at = workout_time(record);
    last_done
        .into_iter()
        .map(|(exercise, (_, performed_weight))| {
            (
                exercise,
                SessionOutcome {
                    at,
                    planned_sets: planned.get(&exercise).copied().unwrap_or(0),
                    successful_sets: successful.get(&exercise).copied().unwrap_or(0),
                    performed_weight,
                    top_weight: top.get(&exercise).copied().unwrap_or(performed_weight),
                    target_reps: target_reps.get(&exercise).copied().unwrap_or(0),
                },
            )
        })
        .collect()
}

/// Replay history and land on the next weight for every exercise that appears
/// in it.
///
/// The rule is deliberately the same shape as linear progression, because that's
/// what an accessory wants: clear every prescribed set and you go up by one
/// equipment step; miss and you repeat the weight; miss twice running and you
/// drop 10% to build back into it.
pub fn derive_exercise_progressions(
    history: &[SchplannerWorkoutRecord],
    unit: AppWeightUnit,
) -> HashMap<i32, ExerciseProgression> {
    let mut ordered: Vec<&SchplannerWorkoutRecord> = history
        .iter()
        .filter(|record| workout_time(record) > 0)
        .collect();
    ordered.sort_by_key(|record| workout_time(record));

    struct Acc {
        weight: f32,
        reps: i32,
        sets: i32,
        last_at: i64,
        misses: i32,
        history: Vec<f32>,
    }
    let mut acc: HashMap<i32, Acc> = HashMap::new();

    for record in ordered {
        for (exercise_value, outcome) in session_outcomes(record) {
            let exercise = Exercise::try_from(exercise_value).unwrap_or(Exercise::Unspecified);
            if exercise == Exercise::Unspecified {
                continue;
            }
            let entry = acc.entry(exercise_value).or_insert(Acc {
                weight: 0.0,
                reps: 0,
                sets: 0,
                last_at: 0,
                misses: 0,
                history: Vec::new(),
            });

            // Without a rep target there's nothing to have hit or missed, so
            // such a session neither advances nor counts against you.
            let judged = outcome.planned_sets > 0 && outcome.target_reps > 0;
            let cleared = judged && outcome.successful_sets >= outcome.planned_sets;
            let increment = progression_increment_lb(exercise, unit);
            let next = if outcome.performed_weight <= 0.0 {
                // Bodyweight work (or a set logged with no load): there's no
                // weight to move, so the prescription just repeats.
                entry.misses = 0;
                0.0
            } else if !judged {
                outcome.performed_weight
            } else if cleared {
                entry.misses = 0;
                outcome.performed_weight + increment
            } else {
                entry.misses += 1;
                if entry.misses >= MISSES_BEFORE_DELOAD {
                    entry.misses = 0;
                    outcome.performed_weight * DELOAD_FACTOR
                } else {
                    outcome.performed_weight
                }
            };

            entry.weight = snap_weight_lb(exercise, next, unit);
            if outcome.target_reps > 0 {
                entry.reps = outcome.target_reps;
            }
            if outcome.planned_sets > 0 {
                entry.sets = outcome.planned_sets as i32;
            }
            entry.last_at = outcome.at;
            entry.history.push(outcome.top_weight);
            if entry.history.len() > WEIGHT_HISTORY_LIMIT {
                let overflow = entry.history.len() - WEIGHT_HISTORY_LIMIT;
                entry.history.drain(0..overflow);
            }
        }
    }

    acc.into_iter()
        .map(|(exercise_value, entry)| {
            let exercise = Exercise::try_from(exercise_value).unwrap_or(Exercise::Unspecified);
            (
                exercise_value,
                ExerciseProgression {
                    target_weight: entry.weight,
                    target_reps: if entry.reps > 0 {
                        entry.reps
                    } else {
                        default_reps(exercise)
                    },
                    target_sets: if entry.sets > 0 {
                        entry.sets
                    } else {
                        default_sets(exercise)
                    },
                    last_performed_at: entry.last_at,
                    weight_history: entry.history,
                },
            )
        })
        .collect()
}

/// The weight you finished each exercise at in one workout — the last working
/// set you actually completed, by wall-clock. Pairs with a derived progression
/// to say "you did X, next time do Y".
pub fn performed_working_weights(record: &SchplannerWorkoutRecord) -> HashMap<i32, f32> {
    session_outcomes(record)
        .into_iter()
        .map(|(exercise, outcome)| (exercise, outcome.performed_weight))
        .collect()
}

/// The weight/reps/sets the regime is prescribing for an exercise in today's
/// proposal, if it's in there at all.
fn regime_prescription(
    proposed_groups: &[ProposedExerciseGroup],
    exercise_value: i32,
) -> Option<(f32, i32, i32)> {
    for group in proposed_groups {
        for config in &group.exercise_configs {
            if config.exercise != exercise_value {
                continue;
            }
            let (weight, reps) = match config.working_sets.first() {
                Some(set) => (set.target_weight, set.target_reps),
                None => (config.start_weight, config.reps),
            };
            let sets = if config.working_sets.is_empty() {
                group.sets.max(1)
            } else {
                config.working_sets.len() as i32
            };
            return Some((weight, reps, sets));
        }
    }
    None
}

/// The per-exercise status the client prefills "add exercise" from.
///
/// Precedence for the weight, most authoritative first:
/// 1. what the regime is prescribing today — the program owns its own lifts,
///    and the home screen renders this same number, so disagreeing here would
///    show one weight and start the workout at another;
/// 2. the progression derived from your history;
/// 3. a sane opener from the catalogue for something you've never done.
pub fn exercise_statuses_for_schedule(
    history: &[SchplannerWorkoutRecord],
    proposed_groups: &[ProposedExerciseGroup],
    recovery: &[MuscleRecovery],
    unit: AppWeightUnit,
    now: i64,
) -> Vec<ExerciseStatus> {
    let progressions = derive_exercise_progressions(history, unit);

    all_exercises()
        .into_iter()
        .map(|exercise| {
            let value = exercise as i32;
            let progression = progressions.get(&value);
            let prescribed = regime_prescription(proposed_groups, value);

            let target_weight = prescribed
                .map(|(weight, _, _)| weight)
                .or_else(|| progression.map(|p| p.target_weight))
                .unwrap_or_else(|| starting_weight_lb(exercise, unit));
            let default_reps_value = prescribed
                .map(|(_, reps, _)| reps)
                .or_else(|| progression.map(|p| p.target_reps))
                .unwrap_or_else(|| default_reps(exercise));
            let default_sets_value = prescribed
                .map(|(_, _, sets)| sets)
                .or_else(|| progression.map(|p| p.target_sets))
                .unwrap_or_else(|| default_sets(exercise));

            // Recovered when every muscle it trains is. Never-trained muscles
            // report recovered, so an untouched exercise is ready by default.
            let recovered = muscle_groups(exercise).iter().all(|muscle| {
                recovery
                    .iter()
                    .find(|entry| entry.group == *muscle)
                    .map(|entry| entry.is_recovered(now))
                    .unwrap_or(true)
            });

            ExerciseStatus {
                exercise: value,
                target_weight,
                last_performed_at: progression.map(|p| p.last_performed_at).unwrap_or(0),
                weight_history: progression
                    .map(|p| p.weight_history.clone())
                    .unwrap_or_default(),
                // Left empty on purpose: the proto's MuscleGroup enum (quads /
                // hamstrings / biceps / …) doesn't line up with the recovery
                // model's groups, and no client reads this field. Populating it
                // would mean inventing a lossy mapping.
                muscle_groups: Vec::new(),
                default_sets: default_sets_value,
                default_reps: default_reps_value,
                recovered,
                always_include: prescribed.is_some(),
                category: category(exercise) as i32,
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use schlift::workout::v1::{CompletedSet, ExerciseTypeConfig, Workout, WorkingSetSpec};

    fn proposed(id: &str, exercise: Exercise, weight: f32, reps: i32, warmup: bool) -> ProposedSet {
        ProposedSet {
            id: id.to_string(),
            exercise: exercise as i32,
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

    /// One session of `sets` × `reps` at `weight`, of which `hit` met the target.
    fn session(
        id: &str,
        at: i64,
        exercise: Exercise,
        weight: f32,
        reps: i32,
        sets: usize,
        hit: usize,
    ) -> SchplannerWorkoutRecord {
        let mut proposed_sets = Vec::new();
        let mut completed_sets = Vec::new();
        for i in 0..sets {
            let set_id = format!("{id}_s{i}");
            proposed_sets.push(proposed(&set_id, exercise, weight, reps, false));
            let actual = if i < hit { reps } else { reps - 1 };
            completed_sets.push(completed(&set_id, actual, weight, at - (sets - i) as i64));
        }
        SchplannerWorkoutRecord {
            workout: Workout {
                id: id.to_string(),
                start_time: at - 3600,
                end_time: at,
                ..Default::default()
            },
            exercise_groups: Vec::new(),
            proposed_sets,
            completed_sets,
        }
    }

    fn weight_for(history: &[SchplannerWorkoutRecord], exercise: Exercise) -> f32 {
        derive_exercise_progressions(history, AppWeightUnit::Lb)
            .get(&(exercise as i32))
            .expect("exercise should have a progression")
            .target_weight
    }

    /// The headline behaviour: an accessory the regime knows nothing about still
    /// goes up when you clear it.
    #[test]
    fn clearing_every_set_adds_a_step() {
        let history = vec![session(
            "w1",
            1000,
            Exercise::LateralRaise,
            20.0,
            10,
            3,
            3,
        )];
        assert_eq!(weight_for(&history, Exercise::LateralRaise), 25.0);
    }

    #[test]
    fn missing_reps_repeats_the_weight() {
        let history = vec![session("w1", 1000, Exercise::LateralRaise, 20.0, 10, 3, 2)];
        assert_eq!(weight_for(&history, Exercise::LateralRaise), 20.0);
    }

    /// Two misses running and you back off rather than grinding the same weight
    /// forever.
    #[test]
    fn two_misses_running_deload() {
        let history = vec![
            session("w1", 1000, Exercise::LatPulldown, 100.0, 10, 3, 2),
            session("w2", 2000, Exercise::LatPulldown, 100.0, 10, 3, 2),
        ];
        // 100 * 0.9 = 90, already a clean stack step.
        assert_eq!(weight_for(&history, Exercise::LatPulldown), 90.0);
    }

    /// A miss between two clears doesn't count toward a deload — the streak
    /// resets, which is what stops a single bad day from unwinding progress.
    #[test]
    fn a_clear_resets_the_miss_streak() {
        let history = vec![
            session("w1", 1000, Exercise::LatPulldown, 100.0, 10, 3, 2),
            session("w2", 2000, Exercise::LatPulldown, 100.0, 10, 3, 3),
            session("w3", 3000, Exercise::LatPulldown, 105.0, 10, 3, 2),
        ];
        assert_eq!(
            weight_for(&history, Exercise::LatPulldown),
            105.0,
            "held, not deloaded"
        );
    }

    /// Progression follows the weight you actually lifted, so editing a set
    /// mid-workout carries through.
    #[test]
    fn progression_follows_the_weight_you_performed() {
        let mut record = session("w1", 1000, Exercise::Squat, 200.0, 5, 3, 3);
        // You dropped to 185 for every set but still hit the reps.
        for set in &mut record.completed_sets {
            set.actual_weight = 185.0;
        }
        assert_eq!(weight_for(&[record], Exercise::Squat), 190.0);
    }

    #[test]
    fn bodyweight_work_stays_unweighted() {
        let history = vec![session("w1", 1000, Exercise::PushUp, 0.0, 15, 3, 3)];
        assert_eq!(weight_for(&history, Exercise::PushUp), 0.0);
    }

    /// Barbell results stay loadable — a raw +5 on an unloadable weight would
    /// prescribe a bar you can't build.
    #[test]
    fn barbell_progression_snaps_to_a_loadable_weight() {
        let history = vec![session("w1", 1000, Exercise::Squat, 137.0, 5, 3, 3)];
        let next = weight_for(&history, Exercise::Squat);
        assert_eq!(
            next,
            crate::weight_units::snap_loadable_lb(142.0, AppWeightUnit::Lb)
        );
    }

    #[test]
    fn warmups_dont_count_toward_clearing_a_session() {
        let mut record = session("w1", 1000, Exercise::Squat, 200.0, 5, 3, 3);
        record
            .proposed_sets
            .push(proposed("warm", Exercise::Squat, 95.0, 5, true));
        record.completed_sets.push(completed("warm", 5, 95.0, 900));
        // The warmup is the lightest set but must not become the performed weight.
        assert_eq!(weight_for(&[record], Exercise::Squat), 205.0);
    }

    /// A set with no rep target can't be judged, so it must not read as a miss —
    /// otherwise repeating it would deload a weight you never failed.
    #[test]
    fn a_session_with_no_rep_target_holds_rather_than_deloads() {
        let mut first = session("w1", 1000, Exercise::CableCrunch, 60.0, 0, 3, 0);
        let mut second = session("w2", 2000, Exercise::CableCrunch, 60.0, 0, 3, 0);
        for record in [&mut first, &mut second] {
            for set in &mut record.proposed_sets {
                set.target_reps = 0;
            }
            for set in &mut record.completed_sets {
                set.actual_reps = 12;
            }
        }
        assert_eq!(weight_for(&[first, second], Exercise::CableCrunch), 60.0);
    }

    #[test]
    fn an_exercise_youve_never_done_isnt_in_the_progressions() {
        let history = vec![session("w1", 1000, Exercise::Squat, 200.0, 5, 3, 3)];
        let progressions = derive_exercise_progressions(&history, AppWeightUnit::Lb);
        assert!(!progressions.contains_key(&(Exercise::PecDeck as i32)));
    }

    // ── exercise_statuses_for_schedule ──

    fn regime_group(exercise: Exercise, weight: f32, reps: i32) -> ProposedExerciseGroup {
        ProposedExerciseGroup {
            sets: 5,
            exercise_configs: vec![ExerciseTypeConfig {
                exercise: exercise as i32,
                start_weight: weight,
                end_weight: weight,
                reps,
                working_sets: vec![
                    WorkingSetSpec {
                        target_weight: weight,
                        target_reps: reps,
                        ..Default::default()
                    };
                    5
                ],
                ..Default::default()
            }],
            ..Default::default()
        }
    }

    fn status_for(statuses: &[ExerciseStatus], exercise: Exercise) -> &ExerciseStatus {
        statuses
            .iter()
            .find(|status| status.exercise == exercise as i32)
            .expect("every exercise has a status")
    }

    /// Every exercise gets an entry, so "add exercise" always has a number to
    /// prefill.
    #[test]
    fn every_exercise_gets_a_status() {
        let statuses =
            exercise_statuses_for_schedule(&[], &[], &[], AppWeightUnit::Lb, 10_000);
        assert_eq!(statuses.len(), all_exercises().len());
        assert_eq!(status_for(&statuses, Exercise::Squat).target_weight, 45.0);
        assert_eq!(
            status_for(&statuses, Exercise::LateralRaise).target_weight,
            20.0
        );
    }

    /// What the user asked for: add an exercise mid-workout and it resumes from
    /// your current weight, not a generic default.
    #[test]
    fn a_performed_exercise_resumes_from_its_progression() {
        let history = vec![session("w1", 1000, Exercise::LateralRaise, 20.0, 10, 3, 3)];
        let statuses =
            exercise_statuses_for_schedule(&history, &[], &[], AppWeightUnit::Lb, 10_000);
        let status = status_for(&statuses, Exercise::LateralRaise);
        assert_eq!(status.target_weight, 25.0);
        assert_eq!(status.default_reps, 10);
        assert_eq!(status.default_sets, 3);
        assert_eq!(status.last_performed_at, 1000);
        assert_eq!(status.weight_history, vec![20.0]);
    }

    /// The program owns the lifts it prescribes: the home screen renders the
    /// status weight for those, so it has to match what the regime proposes.
    #[test]
    fn the_regime_wins_for_the_lifts_it_prescribes() {
        let history = vec![session("w1", 1000, Exercise::Squat, 200.0, 5, 3, 3)];
        let groups = vec![regime_group(Exercise::Squat, 185.0, 5)];
        let statuses =
            exercise_statuses_for_schedule(&history, &groups, &[], AppWeightUnit::Lb, 10_000);
        let status = status_for(&statuses, Exercise::Squat);
        assert_eq!(
            status.target_weight, 185.0,
            "the regime's prescription, not the 205 the history would suggest"
        );
        assert_eq!(status.default_sets, 5);
        assert!(status.always_include);
    }
}
