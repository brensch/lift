//! Demo accounts with weeks of believable training history, for store
//! screenshots and local demos.
//!
//! Compiled only with the `test-auth` feature, like dev login, so it cannot
//! exist in a production binary. Triggered by `SEED_DEMO_USER=<name>` at
//! startup, which seeds two users:
//!
//! - `<name>`: sixteen weeks of finished sessions, nothing in progress. Home,
//!   progress and history look lived-in.
//! - `<name>-live`: the same history plus a session under way, its first
//!   two exercises done and the last set just finished, so the live workout
//!   screens open mid-session with an elapsed timer and a rest running.
//!
//! A no-op for a user that already exists. The account is written as events,
//! made by the core's own API: the history as one import of plain, rising
//! sessions (the core's walk works out each lift's max from them, as it
//! would for anyone's), the live session through the real start, so it is
//! planned by the same rules as every other. The phone pulls it on sign-in
//! like any account.

use std::collections::{BTreeMap, HashMap};

use crate::db::{DbResult, ServerDb};
use crate::time::now_unix;
use schlift::workout::v1::{
    workout_mutation, AddLibraryTemplatesRequest, AppendWorkoutMutationsRequest,
    CompleteSetRequest, CompletedSet, Event, Exercise, ExerciseDecision, ExerciseLog,
    ExerciseWeight, ImportHistory, ImportedWorkout, ProposedSet, StartSetRequest,
    StartWorkoutRequest, Workout, WorkoutMutation,
};
use schlift_core::account::Account;
use schlift_core::api::Call;
use schlift_core::exercise_catalog::{progression_increment_lb, rules, snap_weight_lb};
use schlift_core::onboarding::starting_weights_for_strength;
use schlift_core::plan::{is_bodyweight, max_needed};
use schlift_core::weight_units::AppWeightUnit;
use uuid::Uuid;

const DAY: i64 = 86_400;
/// How many weeks of history to write. Enough for sparklines and the weekly
/// volume to look lived-in, cheap enough to seed on every dev boot.
const WEEKS: i64 = 16;
/// Exercises already finished in the `-live` user's in-progress session.
const LIVE_DONE_EXERCISES: usize = 2;
/// Working sets per lift in the history.
const SETS: i32 = 3;
/// Where the demo lifter sits on the setup slider: someone a few months in.
const STRENGTH: f32 = 0.3;
/// The library templates the demo lifter alternates between.
const TEMPLATES: &[&str] = &["stronglifts_a", "stronglifts_b"];

/// What the lifter did on their `n`th session of a lift (0-based): reps
/// climb the class's range a rep a session and the weight steps up past the
/// top, from `opening`. Every ninth session the last set comes up a rep
/// short. Simple and rising; the core's walk works out the max from it.
fn session_of(ex: Exercise, opening: f32, n: i32) -> (f32, i32, bool) {
    let r = rules(ex);
    let span = r.rep_high - r.rep_low + 1;
    let reps = r.rep_low + n % span;
    let weight = if is_bodyweight(ex) {
        0.0
    } else {
        let step = progression_increment_lb(ex, AppWeightUnit::Lb);
        snap_weight_lb(ex, opening + step * (n / span) as f32, AppWeightUnit::Lb)
    };
    (weight, reps, n % 9 == 8)
}

/// One finished session of `exercises`, starting at `start`. `done` counts
/// each lift's sessions so far and is advanced.
fn session(
    name: &str,
    template_id: &str,
    exercises: &[i32],
    openings: &BTreeMap<i32, f32>,
    done: &mut HashMap<i32, i32>,
    start: i64,
) -> ImportedWorkout {
    let workout_id = Uuid::new_v4().to_string();
    let mut proposed = Vec::new();
    let mut completed = Vec::new();
    let mut logs = Vec::new();
    let mut clock = start + 120;
    for &value in exercises {
        let Ok(ex) = Exercise::try_from(value) else {
            continue;
        };
        let r = rules(ex);
        let n = done.entry(value).or_insert(0);
        let opening = openings.get(&value).copied().unwrap_or(0.0);
        let (weight, reps, missed) = session_of(ex, opening, *n);
        *n += 1;
        let warmups: &[f32] = if r.warmups { &[0.5, 0.75] } else { &[] };
        let mut sets: Vec<(f32, i32, i32, bool)> = warmups
            .iter()
            .map(|f| {
                (
                    snap_weight_lb(ex, weight * f, AppWeightUnit::Lb),
                    5,
                    5,
                    true,
                )
            })
            .collect();
        for set_no in 0..SETS {
            let actual = if missed && set_no == SETS - 1 {
                reps - 1
            } else {
                reps
            };
            sets.push((weight, reps, actual, false));
        }
        for (w, target, actual, warmup) in sets {
            let rest = if warmup { 60 } else { r.rest_seconds };
            let id = Uuid::new_v4().to_string();
            proposed.push(ProposedSet {
                id: id.clone(),
                workout_id: workout_id.clone(),
                workout_order: proposed.len() as i32,
                exercise: value,
                target_reps: target,
                target_weight: w,
                warmup,
                rest_seconds: rest,
                ..Default::default()
            });
            completed.push(CompletedSet {
                id: Uuid::new_v4().to_string(),
                workout_id: workout_id.clone(),
                proposed_set_id: id,
                actual_reps: actual,
                actual_weight: w,
                started_at: clock,
                ended_at: clock + 35,
                rest_until: clock + 35 + rest as i64,
                ..Default::default()
            });
            clock += 35 + rest as i64;
        }
        logs.push(ExerciseLog {
            decision: Some(ExerciseDecision {
                exercise: value,
                sets: SETS,
                reps,
                weight,
                rest_seconds: r.rest_seconds,
                warmups: r.warmups,
                rep_low: r.rep_low,
                rep_high: r.rep_high,
                max: max_needed(weight, reps, SETS, is_bodyweight(ex)),
                budget_minutes: 60,
                ..Default::default()
            }),
            changes: Vec::new(),
        });
    }
    ImportedWorkout {
        workout: Some(Workout {
            id: workout_id,
            name: name.to_string(),
            start_time: start,
            end_time: clock + 60,
            template_id: template_id.to_string(),
            ..Default::default()
        }),
        proposed_sets: proposed,
        completed_sets: completed,
        exercise_logs: logs,
        ..Default::default()
    }
}

/// The live session: the next template in the rotation, started through the
/// real API, its first exercises done, slid back in time so the last set
/// ended just now: nothing lies in the future, and its rest (minutes, on a
/// work set) is still running when a capture gets there.
fn live_session(account: &mut Account, template_id: &str, now: i64) -> Vec<Event> {
    fn run(account: &mut Account, template_id: &str, start: i64) -> (Vec<Event>, i64) {
        let mut call = Call::new(account, start, Uuid::new_v4().to_string());
        let started = call
            .start_workout(StartWorkoutRequest {
                template_id: template_id.to_string(),
                started_at: start,
                ..Default::default()
            })
            .expect("the demo template starts");
        let mut exercises: Vec<i32> = Vec::new();
        for set in &started.proposed_sets {
            if !exercises.contains(&set.exercise) {
                exercises.push(set.exercise);
            }
        }
        let done: Vec<i32> = exercises.into_iter().take(LIVE_DONE_EXERCISES).collect();
        let mut clock = start + 120;
        let mut last_done = start;
        for set in started
            .proposed_sets
            .iter()
            .filter(|s| done.contains(&s.exercise))
        {
            // Started, then done after a warmup's 30 s or a work set's 40 s,
            // as the app does it: the lifting shows on the heart chart.
            call.append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![WorkoutMutation {
                    mutation: Some(workout_mutation::Mutation::StartSet(StartSetRequest {
                        workout_id: started.id.clone(),
                        proposed_set_id: set.id.clone(),
                        started_at: clock,
                    })),
                    ..Default::default()
                }],
            })
            .expect("a planned set starts");
            clock += if set.warmup { 30 } else { 40 };
            let response = call
                .complete_set(CompleteSetRequest {
                    workout_id: started.id.clone(),
                    proposed_set_id: set.id.clone(),
                    actual_reps: set.target_reps,
                    actual_weight: set.target_weight,
                    completed_at: clock,
                })
                .expect("a planned set completes");
            last_done = clock;
            clock = response
                .completed_set
                .map(|c| c.rest_until)
                .unwrap_or(clock);
        }
        (std::mem::take(&mut call.events), last_done)
    }
    // A dry run on a copy finds how long it takes; the real one is shifted.
    let (_, last_done) = run(&mut account.clone(), template_id, 0);
    run(account, template_id, now - last_done).0
}

async fn seed_one(db: &ServerDb, username: &str, live: bool) -> DbResult<()> {
    if db.get_user_by_name(username).await?.is_some() {
        tracing::info!(username, "demo user already exists; not reseeding");
        return Ok(());
    }
    let user_id = format!("demo-{}", username.trim().to_lowercase());
    db.create_user_with_id(&user_id, username).await?;
    tracing::info!(username, %user_id, live, "seeding demo account");

    let now = now_unix();
    let mut account = Account::default();
    let mut events = Vec::new();
    {
        let mut call = Call::new(&mut account, now, Uuid::new_v4().to_string());
        call.add_library_templates(AddLibraryTemplatesRequest {
            library_ids: TEMPLATES.iter().map(|id| id.to_string()).collect(),
            ..Default::default()
        })
        .expect("the demo templates are in the library");
        events.append(&mut call.events);
    }
    let templates = account.templates.clone();

    let openings: BTreeMap<i32, f32> = starting_weights_for_strength(STRENGTH, AppWeightUnit::Lb)
        .into_iter()
        .map(|(ex, w)| (ex as i32, w))
        .collect();
    let mut done = HashMap::new();
    // Sessions on a Mon/Wed/Fri rhythm, most recent one two days ago so the
    // recovery view shows a mix of recovered and recovering muscles.
    let mut session_days: Vec<i64> = (0..WEEKS)
        .flat_map(|week| [0, 2, 4].map(|offset| 2 + week * 7 + offset))
        .collect();
    session_days.sort_unstable_by(|a, b| b.cmp(a)); // oldest first
    let total = session_days.len();
    let workouts: Vec<ImportedWorkout> = session_days
        .into_iter()
        .enumerate()
        .map(|(i, days_ago)| {
            let template = &templates[i % templates.len()];
            // 07:10 local-ish start, ~55 minutes long.
            let start = now - days_ago * DAY - 9 * 3600 + (i as i64 % 3) * 600;
            session(
                &template.name,
                &template.id,
                &template.exercises,
                &openings,
                &mut done,
                start,
            )
        })
        .collect();
    {
        let mut call = Call::new(&mut account, now, Uuid::new_v4().to_string());
        call.import_history(ImportHistory {
            workouts,
            starting_weights: openings
                .iter()
                .map(|(&exercise, &weight_lb)| ExerciseWeight {
                    exercise,
                    weight_lb,
                })
                .collect(),
        })
        .expect("the demo history imports");
        events.append(&mut call.events);
    }

    if live {
        let template_id = &templates[total % templates.len()].id;
        events.extend(live_session(&mut account, template_id, now));
        tracing::info!(username, workout = %account.active_workout_id, "live session in progress");
    }

    db.push_events(&user_id, events).await?;
    tracing::info!(username, sessions = total, "demo account seeded");
    Ok(())
}

pub async fn seed_demo_user(db: &ServerDb, username: &str) -> DbResult<()> {
    seed_one(db, username, false).await?;
    seed_one(db, &format!("{username}-live"), true).await
}

#[cfg(test)]
mod tests {
    use super::*;
    use schlift_core::plan::Planner;

    #[tokio::test]
    async fn the_demo_history_walks_to_rising_maxes() {
        let dir = std::env::temp_dir().join(format!("lift-demo-seed-{}", Uuid::new_v4()));
        let db = ServerDb::new_in_dir(&dir).await.unwrap();
        seed_demo_user(&db, "demo").await.unwrap();
        let account = db.read_account("demo-demo", Clone::clone).await.unwrap();
        assert_eq!(account.workouts.len() as i64, WEEKS * 3);
        assert!(account.active_workout_id.is_empty());
        let walk = Planner::new(&account, now_unix()).walk(Exercise::Squat);
        let (first, last) = (walk.points.first().unwrap().1, walk.max.unwrap());
        assert!(last > first, "the squat's max rises: {first} -> {last}");

        let live = db
            .read_account("demo-demo-live", Clone::clone)
            .await
            .unwrap();
        let workout = live.active_workout().expect("a session under way");
        assert!(!workout.completed_sets.is_empty());
        assert!(workout
            .exercise_logs
            .iter()
            .all(|log| log.decision.is_some()));
    }
}
