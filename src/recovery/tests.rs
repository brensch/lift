//! Time-mocked readiness transitions: build synthetic completed workouts at
//! controlled timestamps, advance `now`, and assert the state machine moves
//! train → recovering → ready → overdue correctly.

use super::*;
use crate::schplanner::SchplannerWorkoutRecord;
use schlift::workout::v1::{CompletedSet, ExerciseGroup, ProposedSet, Workout};

const HOUR: i64 = 3600;
const DAY: i64 = 24 * HOUR;

/// A workout that completed `exercises` at unix time `at`.
fn workout(at: i64, exercises: &[Exercise]) -> SchplannerWorkoutRecord {
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
            warmup: false,
            exercise_group_id: "g".into(),
            rest_after_success: 180,
            rest_after_failure: 300,
            cancelled: false,
            is_amrap: false,
            instruction: String::new(),
            progression_hint: None,
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
    SchplannerWorkoutRecord {
        workout: Workout {
            id: format!("w{at}"),
            name: "T".into(),
            start_time: at - 30 * 60,
            end_time: at,
            session_id: String::new(),
        },
        exercise_groups: vec![ExerciseGroup::default()],
        proposed_sets: proposed,
        completed_sets: completed,
    }
}

fn readiness_at(
    history: &[SchplannerWorkoutRecord],
    next: &[Exercise],
    weekly_target: i32,
    now: i64,
) -> Readiness {
    let rec = per_muscle_recovery(history, now);
    let cad = cadence(history, now);
    let last = history.iter().map(|r| r.workout.end_time).max().unwrap_or(0);
    let muscles = muscles_for_exercises(next);
    compute_readiness(&muscles, &rec, &cad, last, 24, weekly_target, now)
}

// ── Muscle map ──────────────────────────────────────────────────────────────

#[test]
fn muscle_map_parity() {
    // Spot-check the port against app/lib/logic/exercises.dart.
    use MuscleGroup::*;
    assert_eq!(muscle_groups(Exercise::Squat), &[Legs, Ass]);
    assert_eq!(muscle_groups(Exercise::BenchPress), &[Chest]);
    assert_eq!(muscle_groups(Exercise::Deadlift), &[Back, Ass]);
    assert_eq!(muscle_groups(Exercise::OverheadPress), &[Shoulders]);
    assert_eq!(muscle_groups(Exercise::BarbellRow), &[Back]);
    assert_eq!(muscle_groups(Exercise::PushUp), &[Chest, Arms]);
    assert_eq!(muscle_groups(Exercise::Plank), &[Core]);
    assert_eq!(muscle_groups(Exercise::Unspecified), &[] as &[MuscleGroup]);
    // Every real exercise maps to at least one group.
    for &ex in &[Exercise::HipThrust, Exercise::LatPulldown, Exercise::CalfRaise] {
        assert!(!muscle_groups(ex).is_empty());
    }
}

#[test]
fn heavy_compounds_recover_slower_than_isolation() {
    let base = 1_000_000_000i64;
    // Squat (heavy) trains legs; leg curl (not heavy) also trains legs.
    let squat = per_muscle_recovery(&[workout(base, &[Exercise::Squat])], base);
    let curl = per_muscle_recovery(&[workout(base, &[Exercise::LegCurl])], base);
    let legs_squat = squat.iter().find(|r| r.group == MuscleGroup::Legs).unwrap();
    let legs_curl = curl.iter().find(|r| r.group == MuscleGroup::Legs).unwrap();
    // Squat pushes legs to 72h; leg curl leaves the 60h baseline.
    assert_eq!(legs_squat.recovered_at - base, 72 * HOUR);
    assert_eq!(legs_curl.recovered_at - base, 60 * HOUR);
}

// ── The transition over time (the whole point) ──────────────────────────────

#[test]
fn first_time_user_is_ready_immediately() {
    let r = readiness_at(&[], &[Exercise::Squat, Exercise::BenchPress], 3, 1_000_000_000);
    assert_eq!(r.state, ReadinessState::FirstTime);
    assert!(r.blocking.is_empty());
}

#[test]
fn just_trained_then_recovers_then_ready() {
    let t0 = 1_700_000_000i64; // a Monday-ish anchor
    let history = vec![workout(t0, &[Exercise::Squat, Exercise::BenchPress])];
    let next = &[Exercise::Squat, Exercise::BenchPress]; // same muscles next

    // Right after finishing: recovering, legs are the blocker (squat = 72h).
    let just_after = readiness_at(&history, next, 3, t0 + HOUR);
    assert_eq!(just_after.state, ReadinessState::Recovering);
    assert!(just_after.blocking.contains(&MuscleGroup::Legs));
    assert_eq!(just_after.next_ready_at, t0 + 72 * HOUR);

    // +2 days: chest (48h) is back but the squat's legs + ass (72h) still cook.
    let two_days = readiness_at(&history, next, 3, t0 + 2 * DAY);
    assert_eq!(two_days.state, ReadinessState::Recovering);
    assert_eq!(two_days.blocking, vec![MuscleGroup::Legs, MuscleGroup::Ass]);

    // +3 days: legs recovered → ready to train.
    let three_days = readiness_at(&history, next, 3, t0 + 3 * DAY + HOUR);
    assert_eq!(three_days.state, ReadinessState::Ready);
    assert!(three_days.blocking.is_empty());
}

#[test]
fn min_rest_floor_holds_even_if_muscles_are_light() {
    // A core-only session recovers in 24h, but the program floor is also 24h, so
    // "ready" can't be earlier than last + 24h.
    let t0 = 1_700_000_000i64;
    let history = vec![workout(t0, &[Exercise::Plank])];
    let next = &[Exercise::Plank];
    let r = readiness_at(&history, next, 3, t0 + 12 * HOUR);
    assert_eq!(r.state, ReadinessState::Recovering);
    assert_eq!(r.next_ready_at, t0 + 24 * HOUR);
}

#[test]
fn long_layoff_behind_target_is_overdue() {
    let t0 = 1_700_000_000i64;
    let history = vec![workout(t0, &[Exercise::Squat, Exercise::BenchPress])];
    // 6 days later: everything recovered, 0 sessions this week, target 3 → overdue.
    let r = readiness_at(&history, &[Exercise::Squat], 3, t0 + 6 * DAY);
    assert_eq!(r.state, ReadinessState::Overdue);
    assert!(r.blocking.is_empty());
}

#[test]
fn met_weekly_target_reads_as_ahead() {
    // Three sessions across this week; recovered; target 3 → ahead (bonus).
    let now = 1_700_000_000i64 + 6 * DAY;
    let history = vec![
        workout(now - 5 * DAY, &[Exercise::Squat]),
        workout(now - 3 * DAY, &[Exercise::BenchPress]),
        workout(now - 1 * DAY - 12 * HOUR, &[Exercise::OverheadPress]),
    ];
    // Next hits arms (recovered) — not blocked.
    let r = readiness_at(&history, &[Exercise::BarbellCurl], 3, now);
    assert_eq!(r.state, ReadinessState::Ahead);
}

#[test]
fn cadence_learns_gap_and_weekly_count() {
    let now = 1_700_000_000i64 + 10 * DAY;
    let history = vec![
        workout(now - 8 * DAY, &[Exercise::Squat]),
        workout(now - 6 * DAY, &[Exercise::BenchPress]), // +2d
        workout(now - 4 * DAY, &[Exercise::Deadlift]),   // +2d
        workout(now - 2 * DAY, &[Exercise::OverheadPress]), // +2d
    ];
    let c = cadence(&history, now);
    assert_eq!(c.avg_gap_hours, Some(48)); // consistent 2-day rhythm
    assert_eq!(c.sessions_last_7d, 3); // the three within the last 7 days
}
