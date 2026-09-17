//! A demo account with weeks of believable training history, for store
//! screenshots and local demos.
//!
//! Compiled only with the `test-auth` feature, like dev login, so it cannot
//! exist in a production binary. Triggered by `SEED_DEMO_USER=<username>` at
//! startup; a no-op if that user already exists. Everything goes through the
//! real `ServerDb` write API and the real exercise catalog, so the data stays
//! valid as the schema and prescriptions evolve.

use crate::db::{DbResult, ServerDb};
use crate::exercise_catalog::{
    prescription, progression_increment_lb, snap_weight_lb, starting_weight_lb, LoadStyle,
    load_style,
};
use crate::exercise_progress::TrackerState;
use crate::time::now_unix;
use crate::weight_units::AppWeightUnit;
use schlift::workout::v1::{
    CompletedSet, Exercise, ProposedSet, Workout, WorkoutTemplate,
};
use uuid::Uuid;

const DAY: i64 = 86_400;
/// How many weeks of history to write. Enough for sparklines and the volume
/// tracker to look lived-in, cheap enough to seed on every dev boot.
const WEEKS: i64 = 10;

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
/// weight steps up and reps reset. One planted miss keeps it honest.
struct Lift {
    weight: f32,
    reps: i32,
}

pub async fn seed_demo_user(db: &ServerDb, username: &str) -> DbResult<()> {
    if db.get_user_by_name(username).await?.is_some() {
        tracing::info!(username, "demo user already exists; not reseeding");
        return Ok(());
    }
    let user_id = format!("demo-{}", username.trim().to_lowercase());
    db.create_user_with_id(&user_id, username).await?;
    tracing::info!(username, %user_id, "seeding demo account");

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

    let mut lifts: std::collections::HashMap<i32, Lift> = std::collections::HashMap::new();
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

    for (session_index, days_ago) in session_days.into_iter().enumerate() {
        let template = &TEMPLATES[session_index % TEMPLATES.len()];
        let template_id = &template_ids[session_index % TEMPLATES.len()];
        // 07:10 local-ish start, ~55 minutes long.
        let start = now - days_ago * DAY - 9 * 3600 + (session_index as i64 % 3) * 600;
        let workout_id = Uuid::new_v4().to_string();
        let mut proposed = Vec::new();
        let mut completed = Vec::new();
        let mut clock = start + 120;
        let mut order = 0;

        for ex in template.exercises {
            let p = prescription(*ex);
            let key = *ex as i32;
            // Each lift starts somewhere different in its rep range so the
            // weight steps land on different sessions across exercises.
            let lift = lifts.entry(key).or_insert_with(|| Lift {
                weight: opening_weight(*ex),
                reps: (p.rep_low + key % 3).min(p.rep_high),
            });
            let is_bodyweight = matches!(load_style(*ex), LoadStyle::Bodyweight);
            // A planted miss a third of the way through the block: the last
            // set falls one rep short, and the weight holds next time.
            let planted_miss = session_index == total / 3 && *ex == template.exercises[0];

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
                    order += 1;
                }
            }
            for set_no in 0..p.sets {
                let id = Uuid::new_v4().to_string();
                let last = set_no == p.sets - 1;
                let reps = if planted_miss && last { lift.reps - 1 } else { lift.reps };
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
                order += 1;
            }
            // Double progression for next time: two reps a session (a
            // lifter a few months in moves faster than the app's one-rep
            // floor), weight up when the range tops out.
            if !planted_miss {
                if lift.reps >= p.rep_high {
                    lift.reps = p.rep_low;
                    if !is_bodyweight {
                        lift.weight = snap_weight_lb(
                            *ex,
                            lift.weight + progression_increment_lb(*ex, AppWeightUnit::Lb),
                            AppWeightUnit::Lb,
                        );
                    }
                } else {
                    lift.reps = (lift.reps + 2).min(p.rep_high);
                }
            }
        }

        let end = clock + 60;
        let workout = Workout {
            id: workout_id.clone(),
            name: template.name.to_string(),
            start_time: start,
            end_time: end,
            session_id: String::new(),
            template_id: template_id.clone(),
        };
        db.insert_workout(&user_id, &workout, &proposed).await?;
        for set in &completed {
            db.insert_completed_set(&user_id, set).await?;
        }
        // insert_workout marks the workout active; close it like EndWorkout does.
        db.end_workout(&user_id, &workout_id, end).await?;
        db.claim_progression(&user_id, &workout_id).await?;

        for ex in template.exercises {
            let lift = &lifts[&(*ex as i32)];
            db.upsert_tracker_state(
                &user_id,
                *ex as i32,
                &TrackerState {
                    working_weight: lift.weight,
                    current_reps: lift.reps,
                    consecutive_misses: 0,
                    last_performed_at: end,
                    override_sets: 0,
                    override_rep_low: 0,
                    override_rep_high: 0,
                },
                "demo",
            )
            .await?;
        }
    }

    tracing::info!(username, sessions = total, "demo account seeded");
    Ok(())
}
