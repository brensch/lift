//! Demo accounts with weeks of believable training history, for store
//! screenshots and local demos.
//!
//! Compiled only with the `test-auth` feature, like dev login, so it cannot
//! exist in a production binary. Triggered by `SEED_DEMO_USER=<name>` at
//! startup, which seeds two users:
//!
//! - `<name>`: ten weeks of finished sessions, nothing in progress. Home,
//!   progress and history look lived-in.
//! - `<name>-live`: the same history plus a session that started 24 minutes
//!   ago with the first two exercises done, so the live workout screens open
//!   mid-session with an elapsed timer and a heart-rate axis worth looking at.
//!
//! A no-op for a user that already exists. The account is written as events,
//! made by the core's own API (the history as one import, the live session
//! through the real start and complete), so it stays valid as the rules and
//! prescriptions evolve. The phone pulls it on sign-in like any account.

use std::collections::HashMap;

use crate::db::{DbResult, ServerDb};
use crate::time::now_unix;
use schlift::workout::v1::{
    workout_mutation, AddLibraryTemplatesRequest, AppendWorkoutMutationsRequest,
    CompleteSetRequest, CompletedSet, Event, Exercise, ImportHistory, ImportedWorkout, ProposedSet,
    StartSetRequest, StartWorkoutRequest, TrackerRecord, Workout, WorkoutMutation,
};
use schlift_core::account::Account;
use schlift_core::api::Call;
use schlift_core::exercise_catalog::{
    load_style, prescription, progression_increment_lb, snap_weight_lb, starting_weight_lb,
    LoadStyle, Prescription,
};
use schlift_core::weight_units::AppWeightUnit;
use uuid::Uuid;

const DAY: i64 = 86_400;
/// How many weeks of history to write. Enough for sparklines and the volume
/// tracker to look lived-in, cheap enough to seed on every dev boot.
const WEEKS: i64 = 16;
/// Exercises already finished in the `-live` user's in-progress session.
const LIVE_DONE_EXERCISES: usize = 2;

/// A template from the library (templates/library.yaml), added as a new
/// lifter adds it; `exercises` mirrors the library's so the history matches.
struct Template {
    library_id: &'static str,
    name: &'static str,
    exercises: &'static [Exercise],
}

const TEMPLATES: &[Template] = &[
    Template {
        library_id: "stronglifts_a",
        name: "StrongLifts A",
        exercises: &[Exercise::Squat, Exercise::BenchPress, Exercise::BarbellRow],
    },
    Template {
        library_id: "stronglifts_b",
        name: "StrongLifts B",
        exercises: &[Exercise::Squat, Exercise::OverheadPress, Exercise::Deadlift],
    },
];

/// Where the demo lifter starts relative to the catalog's beginner default,
/// so the numbers read like someone a few months in rather than a first day.
fn opening_weight(ex: Exercise) -> f32 {
    let base = starting_weight_lb(ex, AppWeightUnit::Lb);
    let step = progression_increment_lb(ex, AppWeightUnit::Lb);
    let head_start = match ex {
        Exercise::Squat => 12.0,
        Exercise::Deadlift => 16.0,
        Exercise::BenchPress => 8.0,
        Exercise::BarbellRow => 7.0,
        Exercise::OverheadPress => 4.0,
        Exercise::RomanianDeadlift => 9.0,
        Exercise::HipThrust => 10.0,
        Exercise::LegPress => 14.0,
        _ => 2.0,
    };
    snap_weight_lb(ex, base + step * head_start, AppWeightUnit::Lb)
}

/// A deterministic roll in [0, 1) from (exercise, session, salt), so the
/// "randomness" below is the same on every seed and the screenshots are
/// reproducible.
fn roll(ex: Exercise, session: usize, salt: u64) -> f32 {
    let mut x = (ex as u64)
        .wrapping_mul(0x9E37_79B9_7F4A_7C15)
        .wrapping_add((session as u64).wrapping_mul(0xD1B5_4A32_D192_ED03))
        .wrapping_add(salt.wrapping_mul(0x94D0_49BB_1331_11EB));
    x ^= x >> 31;
    x = x.wrapping_mul(0xBF58_476D_1CE4_E5B9);
    x ^= x >> 29;
    (x >> 40) as f32 / (1u64 << 24) as f32
}

/// What a session did to a lift, chosen before the sets are written so the
/// logged reps match.
#[derive(Clone, Copy, PartialEq)]
enum Outcome {
    /// Hit every target.
    Made,
    /// Fell short on the last set(s); the weight holds.
    Missed,
}

/// The progression a user would have felt: reps climb the range and the
/// weight steps up when they top out, but not every session goes to plan.
/// Roughly one in six sessions misses reps, a second miss in a row deloads
/// ten percent (the app's own rule), some sessions just hold, and after a
/// deload the lift rebuilds quickly back to where it was. Over sixteen
/// weeks the trend is up; the dips are detours.
#[derive(Clone, Copy)]
struct Lift {
    weight: f32,
    reps: i32,
    misses: i32,
    /// Highest working weight reached so far; below it the lift rebuilds fast.
    peak: f32,
}

impl Lift {
    fn opening(ex: Exercise, p: &Prescription) -> Self {
        // Each lift starts somewhere different in its rep range so the weight
        // steps land on different sessions across exercises.
        let weight = opening_weight(ex);
        Lift {
            weight,
            reps: (p.rep_low + (ex as i32) % 3).min(p.rep_high),
            misses: 0,
            peak: weight,
        }
    }

    fn outcome(ex: Exercise, session: usize) -> Outcome {
        // A bad day hits everything; otherwise each lift rolls on its own.
        let bad_day = roll(Exercise::Unspecified, session, 1) < 0.07;
        if bad_day || roll(ex, session, 2) < 0.16 {
            Outcome::Missed
        } else {
            Outcome::Made
        }
    }

    /// Reps actually logged on a set, given the outcome. A miss loses one to
    /// three reps on the final set and sometimes one on the set before.
    fn logged_reps(
        &self,
        ex: Exercise,
        session: usize,
        set_no: i32,
        sets: i32,
        outcome: Outcome,
    ) -> i32 {
        if outcome == Outcome::Made {
            return self.reps;
        }
        let last = set_no == sets - 1;
        let short = 1 + (roll(ex, session, 3) * 3.0) as i32;
        if last {
            (self.reps - short).max(1)
        } else if set_no == sets - 2 && roll(ex, session, 4) < 0.4 {
            (self.reps - 1).max(1)
        } else {
            self.reps
        }
    }

    fn advance(&mut self, ex: Exercise, p: &Prescription, session: usize, outcome: Outcome) {
        let loadable = !matches!(load_style(ex), LoadStyle::Bodyweight);
        match outcome {
            Outcome::Missed => {
                self.misses += 1;
                if self.misses >= 2 {
                    // Two in a row: back off ten percent and rebuild.
                    self.misses = 0;
                    self.reps = p.rep_low;
                    if loadable {
                        self.weight = snap_weight_lb(ex, self.weight * 0.9, AppWeightUnit::Lb);
                    }
                }
            }
            Outcome::Made => {
                self.misses = 0;
                let rebuilding = self.weight < self.peak;
                if !rebuilding && roll(ex, session, 7) < 0.03 && loadable {
                    // A setback that is not a miss: a week off, a tweak, a
                    // change of gym. Drop a notch and rebuild from there.
                    self.reps = p.rep_low;
                    self.weight = snap_weight_lb(ex, self.weight * 0.9, AppWeightUnit::Lb);
                    return;
                }
                if !rebuilding && roll(ex, session, 5) < 0.10 {
                    return; // made it, but no more than last time: a hold
                }
                if self.reps >= p.rep_high {
                    self.reps = p.rep_low;
                    if loadable {
                        self.weight = snap_weight_lb(
                            ex,
                            self.weight + progression_increment_lb(ex, AppWeightUnit::Lb),
                            AppWeightUnit::Lb,
                        );
                        self.peak = self.peak.max(self.weight);
                    }
                } else {
                    // Familiar ground comes back fast; new ground is slower.
                    let step = if rebuilding {
                        3
                    } else if roll(ex, session, 6) < 0.5 {
                        1
                    } else {
                        2
                    };
                    self.reps = (self.reps + step).min(p.rep_high);
                }
            }
        }
    }
}

/// Everything one session needs to be written.
struct Session {
    workout: Workout,
    proposed: Vec<ProposedSet>,
    completed: Vec<CompletedSet>,
}

/// Builds one session from the template. `done_exercises` caps how many
/// exercises have completed sets (all of them for history; a prefix for the
/// live session). `session` seeds the outcome rolls. Advances `lifts` for
/// every completed exercise.
fn build_session(
    template: &Template,
    template_id: &str,
    lifts: &mut HashMap<i32, Lift>,
    start: i64,
    done_exercises: usize,
    session: usize,
) -> Session {
    let workout_id = Uuid::new_v4().to_string();
    let mut proposed = Vec::new();
    let mut completed = Vec::new();
    let mut clock = start + 120;
    let mut order = 0;

    for (index, ex) in template.exercises.iter().enumerate() {
        let p = prescription(*ex);
        let key = *ex as i32;
        let lift = *lifts.entry(key).or_insert_with(|| Lift::opening(*ex, &p));
        let is_bodyweight = matches!(load_style(*ex), LoadStyle::Bodyweight);
        let done = index < done_exercises;
        let outcome = Lift::outcome(*ex, session);

        if p.include_warmup && !is_bodyweight {
            for fraction in [0.5f32, 0.75] {
                let w = snap_weight_lb(*ex, lift.weight * fraction, AppWeightUnit::Lb);
                let id = Uuid::new_v4().to_string();
                proposed.push(ProposedSet {
                    id: id.clone(),
                    workout_id: workout_id.clone(),
                    workout_order: order,
                    exercise: key,
                    target_reps: 5,
                    target_weight: w,
                    warmup: true,
                    rest_after_success: 60,
                    rest_after_failure: 60,
                    cancelled: false,
                    calibration: false,
                    skipped: false,
                });
                if done {
                    completed.push(CompletedSet {
                        id: Uuid::new_v4().to_string(),
                        workout_id: workout_id.clone(),
                        proposed_set_id: id,
                        actual_reps: 5,
                        actual_weight: w,
                        started_at: clock,
                        ended_at: clock + 25,
                        rest_until: clock + 85,
                        ..Default::default()
                    });
                    clock += 90;
                }
                order += 1;
            }
        }
        for set_no in 0..p.sets {
            let id = Uuid::new_v4().to_string();
            proposed.push(ProposedSet {
                id: id.clone(),
                workout_id: workout_id.clone(),
                workout_order: order,
                exercise: key,
                target_reps: lift.reps,
                target_weight: lift.weight,
                warmup: false,
                rest_after_success: p.rest_seconds,
                rest_after_failure: p.rest_seconds_failure,
                cancelled: false,
                calibration: false,
                skipped: false,
            });
            if done {
                let reps = lift.logged_reps(*ex, session, set_no, p.sets, outcome);
                completed.push(CompletedSet {
                    id: Uuid::new_v4().to_string(),
                    workout_id: workout_id.clone(),
                    proposed_set_id: id,
                    actual_reps: reps,
                    actual_weight: lift.weight,
                    started_at: clock,
                    ended_at: clock + 35,
                    rest_until: clock + 35 + p.rest_seconds as i64,
                    ..Default::default()
                });
                clock += 35 + p.rest_seconds as i64;
            }
            order += 1;
        }
        if done {
            let mut next = lift;
            next.advance(*ex, &p, session, outcome);
            lifts.insert(key, next);
        }
    }

    Session {
        workout: Workout {
            id: workout_id,
            name: template.name.to_string(),
            start_time: start,
            end_time: 0,
            session_id: String::new(),
            template_id: template_id.to_string(),
            ..Default::default()
        },
        proposed,
        completed,
    }
}

/// The lifts as trackers, as they stand after the history.
fn trackers(lifts: &HashMap<i32, Lift>, performed_at: i64) -> Vec<TrackerRecord> {
    let mut out: Vec<TrackerRecord> = lifts
        .iter()
        .map(|(key, lift)| TrackerRecord {
            exercise: *key,
            working_weight: lift.weight,
            current_reps: lift.reps,
            consecutive_misses: lift.misses,
            last_performed_at: performed_at,
            ..Default::default()
        })
        .collect();
    out.sort_by_key(|t| t.exercise);
    out
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
                    effort: 0,
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
    let mut template_ids = Vec::new();
    {
        let mut call = Call::new(&mut account, now, Uuid::new_v4().to_string());
        call.add_library_templates(AddLibraryTemplatesRequest {
            library_ids: TEMPLATES.iter().map(|t| t.library_id.to_string()).collect(),
            ..Default::default()
        })
        .expect("the demo templates are in the library");
        events.append(&mut call.events);
    }
    for t in TEMPLATES {
        let saved = account
            .templates
            .iter()
            .find(|saved| saved.name == t.name)
            .expect("the library template was added");
        template_ids.push(saved.id.clone());
    }

    let mut lifts: HashMap<i32, Lift> = HashMap::new();
    // Sessions on a Mon/Wed/Fri rhythm, most recent one two days ago so the
    // recovery view shows a mix of recovered and recovering muscles.
    let mut session_days: Vec<i64> = Vec::new();
    for week in 0..WEEKS {
        for offset in [0, 2, 4] {
            session_days.push(2 + week * 7 + offset);
        }
    }
    session_days.sort_unstable_by(|a, b| b.cmp(a)); // oldest first
    let total = session_days.len();
    let mut last_end = 0;
    let mut workouts = Vec::new();

    for (i, days_ago) in session_days.into_iter().enumerate() {
        let template = &TEMPLATES[i % TEMPLATES.len()];
        let template_id = &template_ids[i % TEMPLATES.len()];
        // 07:10 local-ish start, ~55 minutes long.
        let start = now - days_ago * DAY - 9 * 3600 + (i as i64 % 3) * 600;
        let mut session = build_session(
            template,
            template_id,
            &mut lifts,
            start,
            template.exercises.len(),
            i,
        );
        let end = session
            .completed
            .last()
            .map(|c| c.ended_at + 60)
            .unwrap_or(start + 3000);
        session.workout.end_time = end;
        workouts.push(ImportedWorkout {
            workout: Some(session.workout),
            proposed_sets: session.proposed,
            completed_sets: session.completed,
            heart_rate: Vec::new(),
        });
        last_end = end;
    }
    {
        let mut call = Call::new(&mut account, now, Uuid::new_v4().to_string());
        call.import_history(ImportHistory {
            workouts,
            trackers: trackers(&lifts, last_end),
        })
        .expect("the demo history imports");
        events.append(&mut call.events);
    }

    if live {
        let index = total % TEMPLATES.len();
        events.extend(live_session(&mut account, &template_ids[index], now));
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
