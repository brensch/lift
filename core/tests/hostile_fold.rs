//! Events no phone of ours writes, folded as a partner's phone or the
//! server folds them: they must fold, in bounded time and memory.

use schlift_core::account::Account;
use schlift_core::api::View;
use schlift_core::events::{Event, ExerciseAdjusted, Fact, WorkoutStarted};
use schlift_core::pb::{Exercise, ExerciseDecision};
use std::sync::mpsc;
use std::time::Duration;

/// Runs `f` on its own thread; fails if it hasn't finished in five seconds.
fn within_seconds(what: &str, f: impl FnOnce() + Send + 'static) {
    let (tx, rx) = mpsc::channel();
    std::thread::spawn(move || {
        f();
        let _ = tx.send(());
    });
    assert!(
        rx.recv_timeout(Duration::from_secs(5)).is_ok(),
        "{what}: still folding after 5 s"
    );
}

fn started(weight: f32) -> Event {
    Event {
        seq: 1,
        id: "w".into(),
        at: 1_700_000_000,
        fact: Fact::WorkoutStarted(WorkoutStarted {
            name: "Workout".into(),
            unit: 1,
            started_at: 1_700_000_000,
            exercises: vec![Exercise::Squat as i32],
            decisions: vec![ExerciseDecision {
                exercise: Exercise::Squat as i32,
                sets: 3,
                reps: 5,
                weight,
                rest_seconds: 120,
                warmups: true,
                rep_low: 5,
                rep_high: 8,
                ..Default::default()
            }],
            ..Default::default()
        }),
    }
}

#[test]
fn a_workout_started_at_an_absurd_weight_folds() {
    within_seconds("WorkoutStarted weight 1e12", || {
        let events = [started(1e12)];
        let account = Account::fold(&events);
        let _ = schlift_core::session::partner_status(&events, 0, 0, 1_700_000_100);
        let _ = View::new(&account, 1_700_000_100).list_workout_summaries();
    });
}

#[test]
fn an_exercise_adjusted_to_an_absurd_weight_folds() {
    within_seconds("ExerciseAdjusted weight 1e9", || {
        let events = [
            started(135.0),
            Event {
                seq: 2,
                id: "a".into(),
                at: 1_700_000_010,
                fact: Fact::ExerciseAdjusted(ExerciseAdjusted {
                    workout_id: "w".into(),
                    exercise: Exercise::Squat as i32,
                    working_weight: 1e9,
                    target_reps: 5,
                    sets: 0,
                }),
            },
        ];
        let _ = Account::fold(&events);
    });
}

#[test]
fn a_workout_started_with_absurdly_many_sets_folds() {
    within_seconds("WorkoutStarted sets i32::MAX", || {
        let mut event = started(135.0);
        if let Fact::WorkoutStarted(started) = &mut event.fact {
            started.decisions[0].sets = i32::MAX;
        }
        let _ = Account::fold(&[event]);
    });
}

/// Every time in the stored events (one of each fact) pushed to the ends of
/// i64, in turn: differences between them saturate rather than overflow, so
/// a debug build doesn't panic and a release one doesn't wrap.
#[test]
fn times_at_the_ends_of_i64_fold() {
    const TIMES: [&str; 12] = [
        "at",
        "completed_at",
        "created_at",
        "end_time",
        "ended_at",
        "lifting_started_at",
        "rest_until",
        "sampled_at",
        "start_ms",
        "start_time",
        "started_at",
        "updated_at",
    ];
    fn push_out(value: &mut serde_json::Value, flip: &mut bool) {
        match value {
            serde_json::Value::Object(fields) => {
                for (name, field) in fields.iter_mut() {
                    if TIMES.contains(&name.as_str()) && field.is_i64() {
                        *flip = !*flip;
                        *field = serde_json::json!(if *flip { i64::MIN } else { i64::MAX });
                    } else {
                        push_out(field, flip);
                    }
                }
            }
            serde_json::Value::Array(items) => items.iter_mut().for_each(|v| push_out(v, flip)),
            _ => {}
        }
    }
    let stored: serde_json::Value =
        serde_json::from_str(include_str!("testdata/stored_events.json")).unwrap();
    for mut flip in [false, true] {
        let mut corpus = stored.clone();
        push_out(&mut corpus, &mut flip);
        let events: Vec<Event> = serde_json::from_value(corpus).unwrap();
        let account = Account::fold(&events);
        // The clock is the phone's or the server's own, not the events'.
        for now in [0, 1_700_000_000, 4_000_000_000] {
            let view = View::new(&account, now);
            let _ = view.home(45);
            let _ = view.list_workout_summaries();
            let _ = view.get_exercise_progress();
            let _ = view.get_active_workout();
            for workout in &account.workouts {
                let _ = view.workout_response(&workout.workout.id);
            }
            let _ = schlift_core::session::partner_status(&events, 0, 0, now);
        }
    }
}
