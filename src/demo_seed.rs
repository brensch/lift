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
//! A no-op for a user that already exists. Everything goes through the real
//! `ServerDb` write API and the real exercise catalog, so the data stays
//! valid as the schema and prescriptions evolve.

use std::collections::HashMap;

use crate::db::{DbResult, ServerDb};
use crate::exercise_catalog::{
    load_style, prescription, progression_increment_lb, snap_weight_lb, starting_weight_lb,
    LoadStyle, Prescription,
};
use crate::exercise_progress::TrackerState;
use crate::time::now_unix;
use crate::weight_units::AppWeightUnit;
use schlift::workout::v1::{CompletedSet, Exercise, ProposedSet, Workout, WorkoutTemplate};
use uuid::Uuid;

const DAY: i64 = 86_400;
/// How many weeks of history to write. Enough for sparklines and the volume
/// tracker to look lived-in, cheap enough to seed on every dev boot.
const WEEKS: i64 = 10;
/// Exercises already finished in the `-live` user's in-progress session.
const LIVE_DONE_EXERCISES: usize = 2;
/// When the live session's last rest ends, relative to seeding. Long enough
/// that a capture started a few minutes later still finds the lifter resting
/// (blue bar, countdown) rather than overdue.
const LIVE_REST_ENDS_IN: i64 = 5 * 60;

struct Template {
    name: &'static str,
    exercises: &'static [Exercise],
}

const TEMPLATES: &[Template] = &[
    Template {
        name: "Push",
        exercises: &[
            Exercise::BenchPress,
            Exercise::InclineDumbbellPress,
            Exercise::OverheadPress,
            Exercise::LateralRaise,
            Exercise::TricepPushdown,
        ],
    },
    Template {
        name: "Pull",
        exercises: &[
            Exercise::Deadlift,
            Exercise::LatPulldown,
            Exercise::BarbellRow,
            Exercise::FacePull,
            Exercise::BarbellCurl,
        ],
    },
    Template {
        name: "Legs",
        exercises: &[
            Exercise::Squat,
            Exercise::RomanianDeadlift,
            Exercise::LegPress,
            Exercise::LegCurl,
            Exercise::HipThrust,
        ],
    },
];

/// Where the demo lifter starts relative to the catalog's beginner default,
/// so the numbers read like someone a few months in rather than a first day.
fn opening_weight(ex: Exercise) -> f32 {
    let base = starting_weight_lb(ex, AppWeightUnit::Lb);
    let step = progression_increment_lb(ex, AppWeightUnit::Lb);
    let head_start = match ex {
        Exercise::Squat => 18.0,
        Exercise::Deadlift => 24.0,
        Exercise::BenchPress => 12.0,
        Exercise::BarbellRow => 10.0,
        Exercise::OverheadPress => 6.0,
        Exercise::RomanianDeadlift => 14.0,
        Exercise::HipThrust => 16.0,
        Exercise::LegPress => 20.0,
        _ => 4.0,
    };
    snap_weight_lb(ex, base + step * head_start, AppWeightUnit::Lb)
}

/// The progression a user would have felt: reps climb the range, then the
/// weight steps up and reps reset.
#[derive(Clone, Copy)]
struct Lift {
    weight: f32,
    reps: i32,
}

impl Lift {
    fn opening(ex: Exercise, p: &Prescription) -> Self {
        // Each lift starts somewhere different in its rep range so the weight
        // steps land on different sessions across exercises.
        Lift {
            weight: opening_weight(ex),
            reps: (p.rep_low + (ex as i32) % 3).min(p.rep_high),
        }
    }

    /// Double progression for next time: two reps a session (a lifter a few
    /// months in moves faster than the app's one-rep floor), weight up when
    /// the range tops out.
    fn advance(&mut self, ex: Exercise, p: &Prescription) {
        if self.reps >= p.rep_high {
            self.reps = p.rep_low;
            if !matches!(load_style(ex), LoadStyle::Bodyweight) {
                self.weight = snap_weight_lb(
                    ex,
                    self.weight + progression_increment_lb(ex, AppWeightUnit::Lb),
                    AppWeightUnit::Lb,
                );
            }
        } else {
            self.reps = (self.reps + 2).min(p.rep_high);
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
/// live session). `miss_first` plants one short rep on the first exercise's
/// last set. Advances `lifts` for every completed exercise.
fn build_session(
    template: &Template,
    template_id: &str,
    lifts: &mut HashMap<i32, Lift>,
    start: i64,
    done_exercises: usize,
    miss_first: bool,
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
        let planted_miss = miss_first && index == 0;

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
                    });
                    clock += 90;
                }
                order += 1;
            }
        }
        for set_no in 0..p.sets {
            let id = Uuid::new_v4().to_string();
            let last = set_no == p.sets - 1;
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
            });
            if done {
                let reps = if planted_miss && last { lift.reps - 1 } else { lift.reps };
                completed.push(CompletedSet {
                    id: Uuid::new_v4().to_string(),
                    workout_id: workout_id.clone(),
                    proposed_set_id: id,
                    actual_reps: reps,
                    actual_weight: lift.weight,
                    started_at: clock,
                    ended_at: clock + 35,
                    rest_until: clock + 35 + p.rest_seconds as i64,
                });
                clock += 35 + p.rest_seconds as i64;
            }
            order += 1;
        }
        if done && !planted_miss {
            let mut next = lift;
            next.advance(*ex, &p);
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
        },
        proposed,
        completed,
    }
}

async fn write_trackers(
    db: &ServerDb,
    user_id: &str,
    lifts: &HashMap<i32, Lift>,
    performed_at: i64,
) -> DbResult<()> {
    for (key, lift) in lifts {
        db.upsert_tracker_state(
            user_id,
            *key,
            &TrackerState {
                working_weight: lift.weight,
                current_reps: lift.reps,
                consecutive_misses: 0,
                last_performed_at: performed_at,
                override_sets: 0,
                override_rep_low: 0,
                override_rep_high: 0,
            },
            "demo",
        )
        .await?;
    }
    Ok(())
}

async fn seed_one(db: &ServerDb, username: &str, live: bool) -> DbResult<()> {
    if db.get_user_by_name(username).await?.is_some() {
        tracing::info!(username, "demo user already exists; not reseeding");
        return Ok(());
    }
    let user_id = format!("demo-{}", username.trim().to_lowercase());
    db.create_user_with_id(&user_id, username).await?;
    tracing::info!(username, %user_id, live, "seeding demo account");

    let mut template_ids = Vec::new();
    for t in TEMPLATES {
        let saved = db
            .save_template(
                &user_id,
                &WorkoutTemplate {
                    name: t.name.to_string(),
                    exercises: t.exercises.iter().map(|e| *e as i32).collect(),
                    ..Default::default()
                },
            )
            .await?;
        template_ids.push(saved.id);
    }

    let mut lifts: HashMap<i32, Lift> = HashMap::new();
    let now = now_unix();
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
            i == total / 3, // a planted miss a third of the way through
        );
        let end = session
            .completed
            .last()
            .map(|c| c.ended_at + 60)
            .unwrap_or(start + 3000);
        session.workout.end_time = end;
        db.insert_workout(&user_id, &session.workout, &session.proposed)
            .await?;
        for set in &session.completed {
            db.insert_completed_set(&user_id, set).await?;
        }
        // insert_workout marks the workout active; close it like EndWorkout does.
        db.end_workout(&user_id, &session.workout.id, end).await?;
        db.claim_progression(&user_id, &session.workout.id).await?;
        last_end = end;
    }
    write_trackers(db, &user_id, &lifts, last_end).await?;

    if live {
        // The next session in the rotation, in progress right now. The
        // trackers must not move until it ends, hence the cloned lifts.
        let index = total % TEMPLATES.len();
        let mut scratch = lifts.clone();
        let mut session = build_session(
            &TEMPLATES[index],
            &template_ids[index],
            &mut scratch,
            now,
            LIVE_DONE_EXERCISES,
            false,
        );
        // Slide the whole session back so the last completed set's rest ends
        // LIVE_REST_ENDS_IN from now; the elapsed timer falls out of that.
        if let Some(last) = session.completed.last() {
            let shift = now + LIVE_REST_ENDS_IN - last.rest_until;
            session.workout.start_time += shift;
            for set in &mut session.completed {
                set.started_at += shift;
                set.ended_at += shift;
                set.rest_until += shift;
            }
        }
        db.insert_workout(&user_id, &session.workout, &session.proposed)
            .await?;
        for set in &session.completed {
            db.insert_completed_set(&user_id, set).await?;
        }
        tracing::info!(username, workout = %session.workout.id, "live session in progress");
    }

    tracing::info!(username, sessions = total, "demo account seeded");
    Ok(())
}

pub async fn seed_demo_user(db: &ServerDb, username: &str) -> DbResult<()> {
    seed_one(db, username, false).await?;
    seed_one(db, &format!("{username}-live"), true).await
}
