//! The account as plain tables: what's in an exported file, and what the
//! server's analytics read. The log is the truth; these are rewritten from
//! the fold, so they can be dropped and rebuilt at any time. Both hosts run
//! the same statements — the phone through rusqlite, the server through
//! sqlx — so the tables are defined once, here.

use crate::account::{tracker_record, Account};
use crate::history::WorkoutRecord;

/// The workout tables, on the phone and the server alike.
pub const WORKOUT_SCHEMA: &str = r#"
CREATE TABLE IF NOT EXISTS workouts (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL DEFAULT '',
    start_time INTEGER NOT NULL,
    end_time INTEGER NOT NULL DEFAULT 0,
    session_id TEXT NOT NULL DEFAULT '',
    template_id TEXT NOT NULL DEFAULT '',
    lifting_set_id TEXT NOT NULL DEFAULT '',
    lifting_started_at INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_workouts_user_time ON workouts(user_id, start_time DESC);
CREATE INDEX IF NOT EXISTS idx_workouts_session ON workouts(session_id)
    WHERE session_id != '';

CREATE TABLE IF NOT EXISTS proposed_sets (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    workout_order INTEGER NOT NULL,
    exercise INTEGER NOT NULL,
    target_reps INTEGER NOT NULL,
    target_weight REAL NOT NULL,
    warmup INTEGER NOT NULL DEFAULT 0,
    cancelled INTEGER NOT NULL DEFAULT 0,
    rest_after_success INTEGER NOT NULL DEFAULT 0,
    rest_after_failure INTEGER NOT NULL DEFAULT 0,
    calibration INTEGER NOT NULL DEFAULT 0,
    skipped INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_proposed_sets_workout ON proposed_sets(workout_id, workout_order);

CREATE TABLE IF NOT EXISTS completed_sets (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    proposed_set_id TEXT NOT NULL,
    actual_reps INTEGER NOT NULL,
    actual_weight REAL NOT NULL,
    ended_at INTEGER NOT NULL DEFAULT 0,
    rest_until INTEGER NOT NULL DEFAULT 0,
    effort INTEGER NOT NULL DEFAULT 0,
    started_at INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_completed_sets_workout ON completed_sets(workout_id);
CREATE INDEX IF NOT EXISTS idx_completed_sets_proposed ON completed_sets(proposed_set_id);

CREATE TABLE IF NOT EXISTS workout_heart_rate_samples (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    sampled_at INTEGER NOT NULL,
    bpm REAL NOT NULL,
    availability INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_hr_user_workout_time
    ON workout_heart_rate_samples(user_id, workout_id, sampled_at);
"#;

/// The rest of the account, on the phone only (the server keeps it in the
/// fold): so an exported file reads as everything the app knows.
pub const ACCOUNT_SCHEMA: &str = r#"
CREATE TABLE IF NOT EXISTS exercise_trackers (
    user_id TEXT NOT NULL,
    exercise INTEGER NOT NULL,
    working_weight REAL NOT NULL,
    current_reps INTEGER NOT NULL,
    consecutive_misses INTEGER NOT NULL,
    last_performed_at INTEGER NOT NULL,
    override_sets INTEGER NOT NULL,
    override_rep_low INTEGER NOT NULL,
    override_rep_high INTEGER NOT NULL,
    consecutive_hard INTEGER NOT NULL,
    PRIMARY KEY(user_id, exercise)
);

CREATE TABLE IF NOT EXISTS workout_templates (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    template_order INTEGER NOT NULL,
    exercises TEXT NOT NULL,
    library_id TEXT NOT NULL DEFAULT '',
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
"#;

/// A value to bind.
#[derive(Clone, Debug, PartialEq)]
pub enum Value {
    Int(i64),
    Real(f64),
    Text(String),
}

impl From<i64> for Value {
    fn from(v: i64) -> Self {
        Self::Int(v)
    }
}

impl From<i32> for Value {
    fn from(v: i32) -> Self {
        Self::Int(v.into())
    }
}

impl From<bool> for Value {
    fn from(v: bool) -> Self {
        Self::Int(v.into())
    }
}

impl From<f32> for Value {
    fn from(v: f32) -> Self {
        Self::Real(v.into())
    }
}

impl From<&str> for Value {
    fn from(v: &str) -> Self {
        Self::Text(v.to_string())
    }
}

impl From<String> for Value {
    fn from(v: String) -> Self {
        Self::Text(v)
    }
}

/// One statement and its parameters, in order.
#[derive(Clone, Debug, PartialEq)]
pub struct Statement {
    pub sql: &'static str,
    pub params: Vec<Value>,
}

fn statement(sql: &'static str, params: Vec<Value>) -> Statement {
    Statement { sql, params }
}

/// Rewrite one workout's rows. `session_id` is the session it was trained
/// in, which only the server knows; the phone passes what the row had.
pub fn workout_statements(
    user_id: &str,
    record: &WorkoutRecord,
    session_id: &str,
) -> Vec<Statement> {
    let w = &record.workout;
    let mut out: Vec<Statement> = [
        "DELETE FROM workouts WHERE id = ? AND user_id = ?",
        "DELETE FROM proposed_sets WHERE workout_id = ? AND user_id = ?",
        "DELETE FROM completed_sets WHERE workout_id = ? AND user_id = ?",
        "DELETE FROM workout_heart_rate_samples WHERE workout_id = ? AND user_id = ?",
    ]
    .into_iter()
    .map(|sql| statement(sql, vec![w.id.as_str().into(), user_id.into()]))
    .collect();
    out.push(statement(
        "INSERT INTO workouts (id, user_id, name, start_time, end_time, session_id,
         template_id, lifting_set_id, lifting_started_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        vec![
            w.id.as_str().into(),
            user_id.into(),
            w.name.as_str().into(),
            w.start_time.into(),
            w.end_time.into(),
            session_id.into(),
            w.template_id.as_str().into(),
            w.lifting_set_id.as_str().into(),
            w.lifting_started_at.into(),
        ],
    ));
    for set in &record.proposed_sets {
        out.push(statement(
            "INSERT INTO proposed_sets (id, user_id, workout_id, workout_order, exercise,
             target_reps, target_weight, warmup, cancelled, rest_after_success,
             rest_after_failure, calibration, skipped)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            vec![
                set.id.as_str().into(),
                user_id.into(),
                set.workout_id.as_str().into(),
                set.workout_order.into(),
                set.exercise.into(),
                set.target_reps.into(),
                set.target_weight.into(),
                set.warmup.into(),
                set.cancelled.into(),
                set.rest_after_success.into(),
                set.rest_after_failure.into(),
                set.calibration.into(),
                set.skipped.into(),
            ],
        ));
    }
    for set in &record.completed_sets {
        out.push(statement(
            "INSERT INTO completed_sets (id, user_id, workout_id, proposed_set_id,
             actual_reps, actual_weight, ended_at, rest_until, effort, started_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            vec![
                set.id.as_str().into(),
                user_id.into(),
                set.workout_id.as_str().into(),
                set.proposed_set_id.as_str().into(),
                set.actual_reps.into(),
                set.actual_weight.into(),
                set.ended_at.into(),
                set.rest_until.into(),
                set.effort.into(),
                set.started_at.into(),
            ],
        ));
    }
    for (n, sample) in record.heart_rate.iter().enumerate() {
        out.push(statement(
            "INSERT INTO workout_heart_rate_samples
             (id, user_id, workout_id, sampled_at, bpm, availability)
             VALUES (?, ?, ?, ?, ?, ?)",
            vec![
                format!("{}:{n}", w.id).into(),
                user_id.into(),
                w.id.as_str().into(),
                sample.sampled_at.into(),
                sample.bpm.into(),
                sample.availability.into(),
            ],
        ));
    }
    out
}

/// Rewrite the trackers and templates (small: done whole).
pub fn account_statements(user_id: &str, account: &Account) -> Vec<Statement> {
    let mut out = vec![
        statement(
            "DELETE FROM exercise_trackers WHERE user_id = ?",
            vec![user_id.into()],
        ),
        statement(
            "DELETE FROM workout_templates WHERE user_id = ?",
            vec![user_id.into()],
        ),
    ];
    for (exercise, state) in &account.trackers {
        let t = tracker_record(*exercise, state);
        out.push(statement(
            "INSERT INTO exercise_trackers (user_id, exercise, working_weight, current_reps,
             consecutive_misses, last_performed_at, override_sets, override_rep_low,
             override_rep_high, consecutive_hard)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            vec![
                user_id.into(),
                t.exercise.into(),
                t.working_weight.into(),
                t.current_reps.into(),
                t.consecutive_misses.into(),
                t.last_performed_at.into(),
                t.override_sets.into(),
                t.override_rep_low.into(),
                t.override_rep_high.into(),
                t.consecutive_hard.into(),
            ],
        ));
    }
    for t in &account.templates {
        let exercises = t
            .exercises
            .iter()
            .map(|e| e.to_string())
            .collect::<Vec<_>>()
            .join(",");
        out.push(statement(
            "INSERT INTO workout_templates (id, user_id, name, template_order, exercises,
             library_id, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            vec![
                t.id.as_str().into(),
                user_id.into(),
                t.name.as_str().into(),
                t.order.into(),
                exercises.into(),
                t.library_id.as_str().into(),
                t.created_at.into(),
                t.updated_at.into(),
            ],
        ));
    }
    out
}
