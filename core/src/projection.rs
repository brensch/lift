//! The account as plain tables, for an exported file: written from the fold
//! into an empty file, so it reads as everything the app knows. The log is
//! the truth; these are never stored anywhere live.

use prost::Message;

use crate::account::Account;
use crate::history::WorkoutRecord;

/// The workout tables. Ids are chosen by the client, so each row is keyed by
/// its owner and its id.
pub const WORKOUT_SCHEMA: &str = r#"
CREATE TABLE IF NOT EXISTS workouts (
    id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL DEFAULT '',
    start_time INTEGER NOT NULL,
    end_time INTEGER NOT NULL DEFAULT 0,
    session_id TEXT NOT NULL DEFAULT '',
    template_id TEXT NOT NULL DEFAULT '',
    lifting_set_id TEXT NOT NULL DEFAULT '',
    lifting_started_at INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, id)
);
CREATE INDEX IF NOT EXISTS idx_workouts_user_time ON workouts(user_id, start_time DESC);

CREATE TABLE IF NOT EXISTS proposed_sets (
    id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    workout_order INTEGER NOT NULL,
    exercise INTEGER NOT NULL,
    target_reps INTEGER NOT NULL,
    target_weight REAL NOT NULL,
    warmup INTEGER NOT NULL DEFAULT 0,
    cancelled INTEGER NOT NULL DEFAULT 0,
    rest_seconds INTEGER NOT NULL DEFAULT 0,
    calibration INTEGER NOT NULL DEFAULT 0,
    skipped INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, id)
);
CREATE INDEX IF NOT EXISTS idx_proposed_sets_workout ON proposed_sets(workout_id, workout_order);

CREATE TABLE IF NOT EXISTS completed_sets (
    id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    proposed_set_id TEXT NOT NULL,
    actual_reps INTEGER NOT NULL,
    actual_weight REAL NOT NULL,
    ended_at INTEGER NOT NULL DEFAULT 0,
    rest_until INTEGER NOT NULL DEFAULT 0,
    started_at INTEGER NOT NULL DEFAULT 0,
    reps_left INTEGER NOT NULL DEFAULT 0,
    jump_lb REAL NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, id)
);
CREATE INDEX IF NOT EXISTS idx_completed_sets_workout ON completed_sets(workout_id);

-- A reading a row, keyed by its workout and time and stored in that order:
-- years of readings every second or two are the bulk of an export, so no
-- more than that.
CREATE TABLE IF NOT EXISTS workout_heart_rate_samples (
    workout_id TEXT NOT NULL,
    sampled_at INTEGER NOT NULL,
    bpm REAL NOT NULL,
    PRIMARY KEY (workout_id, sampled_at)
) WITHOUT ROWID;

-- Per lift in a workout, in the order planned: the decision it started
-- from, and `log`, its ExerciseLog (proto: the decision with its reasons,
-- then every weight change).
CREATE TABLE IF NOT EXISTS exercise_decisions (
    id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    position INTEGER NOT NULL,
    exercise INTEGER NOT NULL,
    sets INTEGER NOT NULL,
    reps INTEGER NOT NULL,
    weight REAL NOT NULL,
    estimated_max REAL NOT NULL,
    budget_minutes INTEGER NOT NULL,
    log BLOB NOT NULL,
    PRIMARY KEY (user_id, id)
);
CREATE INDEX IF NOT EXISTS idx_exercise_decisions_workout
    ON exercise_decisions(workout_id, position);
"#;

/// The rest of the account.
pub const ACCOUNT_SCHEMA: &str = r#"
CREATE TABLE IF NOT EXISTS workout_templates (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    template_order INTEGER NOT NULL,
    exercises TEXT NOT NULL,
    library_id TEXT NOT NULL DEFAULT '',
    coupled INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    in_rotation INTEGER NOT NULL DEFAULT 0,
    origin_library_id TEXT NOT NULL DEFAULT ''
);
"#;

/// Every table the two schemas create. An export drops them before writing
/// them afresh, so a file that already has them (an account opened from an
/// export, perhaps from an older build) is exported again cleanly.
pub const READABLE_TABLES: &[&str] = &[
    "workouts",
    "proposed_sets",
    "completed_sets",
    "workout_heart_rate_samples",
    "exercise_decisions",
    "workout_templates",
];

/// A value to bind.
#[derive(Clone, Debug, PartialEq)]
pub enum Value {
    Int(i64),
    Real(f64),
    Text(String),
    Blob(Vec<u8>),
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

/// One workout's rows, heart rate included.
fn workout_rows(user_id: &str, record: &WorkoutRecord) -> Vec<Statement> {
    let w = &record.workout;
    let mut out = vec![statement(
        "INSERT INTO workouts (id, user_id, name, start_time, end_time, session_id,
         template_id, lifting_set_id, lifting_started_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        vec![
            w.id.as_str().into(),
            user_id.into(),
            w.name.as_str().into(),
            w.start_time.into(),
            w.end_time.into(),
            w.session_id.as_str().into(),
            w.template_id.as_str().into(),
            w.lifting_set_id.as_str().into(),
            w.lifting_started_at.into(),
        ],
    )];
    for set in &record.proposed_sets {
        out.push(statement(
            "INSERT INTO proposed_sets (id, user_id, workout_id, workout_order, exercise,
             target_reps, target_weight, warmup, cancelled, rest_seconds, calibration,
             skipped)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
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
                set.rest_seconds.into(),
                set.calibration.into(),
                set.skipped.into(),
            ],
        ));
    }
    for set in &record.completed_sets {
        out.push(statement(
            "INSERT INTO completed_sets (id, user_id, workout_id, proposed_set_id,
             actual_reps, actual_weight, ended_at, rest_until, started_at, reps_left, jump_lb)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            vec![
                set.id.as_str().into(),
                user_id.into(),
                set.workout_id.as_str().into(),
                set.proposed_set_id.as_str().into(),
                set.actual_reps.into(),
                set.actual_weight.into(),
                set.ended_at.into(),
                set.rest_until.into(),
                set.started_at.into(),
                set.reps_left.into(),
                set.jump_lb.into(),
            ],
        ));
    }
    for (n, log) in record.exercise_logs.iter().enumerate() {
        let d = log.decision.clone().unwrap_or_default();
        out.push(statement(
            "INSERT INTO exercise_decisions
             (id, user_id, workout_id, position, exercise, sets, reps, weight,
              estimated_max, budget_minutes, log)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            vec![
                format!("{}:{n}", w.id).into(),
                user_id.into(),
                w.id.as_str().into(),
                (n as i64).into(),
                d.exercise.into(),
                d.sets.into(),
                d.reps.into(),
                d.weight.into(),
                d.max.into(),
                d.budget_minutes.into(),
                Value::Blob(log.encode_to_vec()),
            ],
        ));
    }
    // Two readings at one millisecond are one.
    for sample in &record.heart_rate {
        out.push(statement(
            "INSERT OR REPLACE INTO workout_heart_rate_samples (workout_id, sampled_at, bpm)
             VALUES (?, ?, ?)",
            vec![
                w.id.as_str().into(),
                sample.sampled_at.into(),
                sample.bpm.into(),
            ],
        ));
    }
    out
}

/// Every readable row of the account, into empty tables: an export.
pub fn account_export_statements(user_id: &str, account: &Account) -> Vec<Statement> {
    let mut out = Vec::new();
    for t in &account.templates {
        let exercises = t
            .exercises
            .iter()
            .map(|e| e.to_string())
            .collect::<Vec<_>>()
            .join(",");
        out.push(statement(
            "INSERT INTO workout_templates (id, user_id, name, template_order, exercises,
             library_id, coupled, created_at, updated_at, in_rotation, origin_library_id)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            vec![
                t.id.as_str().into(),
                user_id.into(),
                t.name.as_str().into(),
                t.order.into(),
                exercises.into(),
                t.library_id.as_str().into(),
                t.coupled.into(),
                t.created_at.into(),
                t.updated_at.into(),
                t.in_rotation.into(),
                t.origin_library_id.as_str().into(),
            ],
        ));
    }
    for record in &account.workouts {
        out.extend(workout_rows(user_id, record));
    }
    out
}
