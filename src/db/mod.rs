use prost::Message;
use schlift::workout::v1::{
    CompletedSet, ExerciseGroup, ExerciseTypeConfig, GetActiveTrainingProgramStateResponse,
    GetProposedWorkoutScheduleResponse, GetWorkoutResponse, ParticipantStatus, ProgressionHint,
    ProposedSet, RestConfig, UserSetting, Workout, WorkoutDraft, WorkoutHeartRatePoint,
};
use sqlx::{
    sqlite::{SqliteConnectOptions, SqliteJournalMode, SqlitePoolOptions, SqliteSynchronous},
    Pool, Row, Sqlite,
};
use std::path::Path;
use std::str::FromStr;
use uuid::Uuid;

use crate::time::now_unix;

mod auth;
mod cache;
mod codec;
mod session;
mod workout;

const SERVER_SCHEMA: &str = r#"
CREATE TABLE IF NOT EXISTS users_current (
    user_id TEXT PRIMARY KEY,
    user_blob BLOB NOT NULL,
    username_ci TEXT NOT NULL UNIQUE,
    invite_token TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS auth_sessions (
    token TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    expires_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_auth_sessions_user_id ON auth_sessions(user_id);

CREATE TABLE IF NOT EXISTS passkey_credentials (
    credential_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    credential_json TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    created_at_ip TEXT
);
CREATE INDEX IF NOT EXISTS idx_passkey_credentials_user_id
    ON passkey_credentials(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS workouts (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL DEFAULT '',
    start_time INTEGER NOT NULL,
    end_time INTEGER NOT NULL DEFAULT 0,
    session_id TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_workouts_user_time ON workouts(user_id, start_time DESC);

CREATE TABLE IF NOT EXISTS exercise_groups (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    name TEXT NOT NULL,
    sets INTEGER NOT NULL DEFAULT 0,
    interleave_warmups INTEGER NOT NULL DEFAULT 0,
    prescribed_by_regime INTEGER NOT NULL DEFAULT 0,
    workout_order INTEGER NOT NULL,
    instruction TEXT NOT NULL DEFAULT '',
    rest_success INTEGER NOT NULL DEFAULT 0,
    rest_failure INTEGER NOT NULL DEFAULT 0,
    rest_warmup INTEGER NOT NULL DEFAULT 0,
    rest_last_warmup INTEGER NOT NULL DEFAULT 0,
    exercise_configs_blob BLOB
);
CREATE INDEX IF NOT EXISTS idx_exercise_groups_workout ON exercise_groups(workout_id, workout_order);

CREATE TABLE IF NOT EXISTS proposed_sets (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    exercise_group_id TEXT NOT NULL,
    workout_order INTEGER NOT NULL,
    exercise INTEGER NOT NULL,
    target_reps INTEGER NOT NULL,
    target_weight REAL NOT NULL,
    warmup INTEGER NOT NULL DEFAULT 0,
    cancelled INTEGER NOT NULL DEFAULT 0,
    rest_after_success INTEGER NOT NULL DEFAULT 0,
    rest_after_failure INTEGER NOT NULL DEFAULT 0,
    is_amrap INTEGER NOT NULL DEFAULT 0,
    instruction TEXT NOT NULL DEFAULT '',
    progression_blob BLOB
);
CREATE INDEX IF NOT EXISTS idx_proposed_sets_workout ON proposed_sets(workout_id, workout_order);

CREATE TABLE IF NOT EXISTS completed_sets (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    proposed_set_id TEXT NOT NULL,
    actual_reps INTEGER NOT NULL,
    actual_weight REAL NOT NULL,
    started_at INTEGER NOT NULL,
    ended_at INTEGER NOT NULL DEFAULT 0,
    rest_until INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_completed_sets_workout ON completed_sets(workout_id);
CREATE INDEX IF NOT EXISTS idx_completed_sets_proposed ON completed_sets(proposed_set_id);

CREATE TABLE IF NOT EXISTS active_workout_current (
    user_id TEXT PRIMARY KEY,
    workout_id TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS user_current_session (
    user_id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    joined_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_user_current_session_session
    ON user_current_session(session_id);

CREATE TABLE IF NOT EXISTS workout_events (
    event_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    recorded_at INTEGER NOT NULL,
    event_type INTEGER NOT NULL,
    payload BLOB NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_workout_events_user_workout_time
    ON workout_events(user_id, workout_id, recorded_at DESC);

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

CREATE TABLE IF NOT EXISTS sessions (
    session_id TEXT PRIMARY KEY,
    created_by TEXT NOT NULL,
    created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_workouts_session ON workouts(session_id)
    WHERE session_id != '';

CREATE TABLE IF NOT EXISTS session_participants_current (
    session_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    participant_blob BLOB NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY(session_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_session_participants_current_session
    ON session_participants_current(session_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS proposed_schedule_cache (
    user_id TEXT PRIMARY KEY,
    response_blob BLOB NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS training_program_state_latest (
    user_id TEXT PRIMARY KEY,
    response_blob BLOB NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS user_settings_current (
    user_id TEXT NOT NULL,
    setting_type TEXT NOT NULL,
    setting_blob BLOB NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY(user_id, setting_type)
);

CREATE TABLE IF NOT EXISTS workout_drafts_current (
    user_id TEXT PRIMARY KEY,
    draft_blob BLOB NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS profile_exercise_groups (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    sets INTEGER NOT NULL DEFAULT 0,
    interleave_warmups INTEGER NOT NULL DEFAULT 0,
    prescribed_by_regime INTEGER NOT NULL DEFAULT 0,
    profile_order INTEGER NOT NULL DEFAULT 0,
    instruction TEXT NOT NULL DEFAULT '',
    rest_success INTEGER NOT NULL DEFAULT 0,
    rest_failure INTEGER NOT NULL DEFAULT 0,
    rest_warmup INTEGER NOT NULL DEFAULT 0,
    rest_last_warmup INTEGER NOT NULL DEFAULT 0,
    exercise_configs_blob BLOB,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_profile_exercise_groups_user_updated
    ON profile_exercise_groups(user_id, updated_at DESC, created_at DESC);
"#;

pub type DbResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

#[derive(Clone)]
pub struct ServerDb {
    pub read_pool: Pool<Sqlite>,
    write_pool: Pool<Sqlite>,
}

impl ServerDb {
    pub async fn new_in_dir(data_dir: impl AsRef<Path>) -> DbResult<Self> {
        let data_dir = data_dir.as_ref();
        std::fs::create_dir_all(data_dir)?;
        let db_path = format!("{}/server.sqlite", data_dir.display());
        let options = SqliteConnectOptions::from_str(&format!("sqlite://{}", db_path))?
            .create_if_missing(true)
            .synchronous(SqliteSynchronous::Normal)
            .journal_mode(SqliteJournalMode::Wal)
            .busy_timeout(std::time::Duration::from_secs(30));
        let write_pool = SqlitePoolOptions::new()
            .max_connections(1)
            .acquire_slow_threshold(std::time::Duration::from_secs(60))
            .connect_with(options.clone())
            .await?;
        let read_pool = SqlitePoolOptions::new()
            .max_connections(16)
            .connect_with(options)
            .await?;
        sqlx::query(SERVER_SCHEMA).execute(&write_pool).await?;
        Ok(Self {
            read_pool,
            write_pool,
        })
    }
}
