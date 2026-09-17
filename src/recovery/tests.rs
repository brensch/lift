//! Time-mocked recovery: build synthetic completed workouts at controlled
//! timestamps, advance `now`, and assert the windows behave.

use super::*;
use crate::history::WorkoutRecord;
use schlift::workout::v1::{CompletedSet, ProposedSet, Workout};

const DAY: i64 = 24 * HOUR;

/// A workout that completed `exercises` at unix time `at`.
fn workout(at: i64, exercises: &[Exercise]) -> WorkoutRecord {
    let mut proposed = Vec::new();
    let mut completed = Vec::new();
    for (i, &ex) in exercises.iter().enumerate() {
        let id = format!("p{at}-{i}");
        proposed.push(ProposedSet {
            id: id.clone(),
            workout_id: "w".into(),
            workout_order: i as i32,
            exercise: ex as i32,
            target_reps: 5,
            target_weight: 100.0,
            ..Default::default()
        });
        completed.push(CompletedSet {
            id: format!("c{at}-{i}"),
            workout_id: "w".into(),
            proposed_set_id: id,
            actual_reps: 5,
            actual_weight: 100.0,
            started_at: at - 60,
            ended_at: at,
            rest_until: 0,
        });
    }
    WorkoutRecord {
        workout: Workout {
            id: format!("w{at}"),
            name: "T".into(),
            start_time: at - 30 * 60,
            end_time: at,
            session_id: String::new(),
            ..Default::default()
        },
        proposed_sets: proposed,
        completed_sets: completed,
    }
}

fn recovery_for(list: &[MuscleRecovery], muscle: MuscleGroup) -> MuscleRecovery {
    *list.iter().find(|r| r.muscle == muscle).unwrap()
}

/// Squats train quads and glutes; both open a 48-hour window, and both
/// close it on schedule.
#[test]
fn a_squat_session_blocks_legs_for_two_days() {
    let t0 = 1_700_000_000i64;
    let history = vec![workout(t0, &[Exercise::Squat])];

    let after = per_muscle_recovery(&history, t0 + HOUR);
    let quads = recovery_for(&after, MuscleGroup::Quads);
    assert!(!quads.is_recovered(t0 + HOUR));
    assert_eq!(quads.recovered_at, t0 + 48 * HOUR);
    assert!(recovery_for(&after, MuscleGroup::Glutes).recovered_at == t0 + 48 * HOUR);
    // Chest untouched: recovered, never trained.
    let chest = recovery_for(&after, MuscleGroup::Chest);
    assert!(chest.is_recovered(t0 + HOUR));
    assert_eq!(chest.last_trained_at, 0);

    let later = per_muscle_recovery(&history, t0 + 2 * DAY + HOUR);
    assert!(recovery_for(&later, MuscleGroup::Quads).is_recovered(t0 + 2 * DAY + HOUR));
}

/// Small muscles come back faster than big ones.
#[test]
fn windows_scale_with_the_muscle() {
    let t0 = 1_700_000_000i64;
    let history = vec![workout(t0, &[Exercise::BarbellCurl, Exercise::Crunch])];
    let rec = per_muscle_recovery(&history, t0 + HOUR);
    assert_eq!(recovery_for(&rec, MuscleGroup::Biceps).recovered_at, t0 + 36 * HOUR);
    assert_eq!(recovery_for(&rec, MuscleGroup::Core).recovered_at, t0 + 24 * HOUR);
}

/// The most recent session that trained a muscle wins, and the fraction
/// climbs from 0 toward 1.
#[test]
fn the_latest_session_sets_the_clock() {
    let t0 = 1_700_000_000i64;
    let history = vec![
        workout(t0 - 5 * DAY, &[Exercise::BenchPress]),
        workout(t0, &[Exercise::PushUp]),
    ];
    let rec = per_muscle_recovery(&history, t0 + 24 * HOUR);
    let chest = recovery_for(&rec, MuscleGroup::Chest);
    assert_eq!(chest.last_trained_at, t0);
    assert!((chest.fraction - 0.5).abs() < 0.01, "24 of 48 hours elapsed");
    assert_eq!(chest.hours_remaining(t0 + 24 * HOUR), 24);
}

/// A planned-but-never-done set trains nothing.
#[test]
fn unfinished_sets_do_not_count() {
    let t0 = 1_700_000_000i64;
    let mut record = workout(t0, &[Exercise::Squat]);
    record.completed_sets.clear();
    let rec = per_muscle_recovery(&[record], t0 + HOUR);
    assert!(recovery_for(&rec, MuscleGroup::Quads).is_recovered(t0 + HOUR));
}

/// Always all ten muscles, in catalog order.
#[test]
fn every_muscle_reports() {
    let rec = per_muscle_recovery(&[], 1_000);
    assert_eq!(rec.len(), 10);
    for entry in &rec {
        assert!(entry.is_recovered(1_000));
    }
}
