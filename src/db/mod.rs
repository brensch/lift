use prost::Message;
use schlift::workout::v1::{
    CompletedSet, ExerciseGroup, ExerciseTypeConfig, GetWorkoutResponse, ParticipantStatus,
    ProposedSet, RestConfig, UserMessage, UserSetting, Workout, WorkoutHeartRatePoint,
    WorkoutTemplate,
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
mod migration;
mod session;
mod workout;

pub use migration::default_templates;

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
    session_id TEXT NOT NULL DEFAULT '',
    template_id TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_workouts_user_time ON workouts(user_id, start_time DESC);

CREATE TABLE IF NOT EXISTS exercise_groups (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    name TEXT NOT NULL,
    sets INTEGER NOT NULL DEFAULT 0,
    interleave_warmups INTEGER NOT NULL DEFAULT 0,
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
    instruction TEXT NOT NULL DEFAULT ''
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

-- Durable roster: every (session, user) that ever joined, with join/leave times.
-- Unlike user_current_session (live, one row per user) and
-- session_participants_current (live blob cache, pruned on leave), these rows are
-- never deleted — they are the authoritative record of who trained together.
CREATE TABLE IF NOT EXISTS session_members (
    session_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    first_joined_at INTEGER NOT NULL,
    last_seen_at INTEGER NOT NULL,
    left_at INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY(session_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_session_members_user
    ON session_members(user_id, first_joined_at DESC);
CREATE INDEX IF NOT EXISTS idx_session_members_session
    ON session_members(session_id);

-- Pending "train together" requests: from_user asks to_user; to_user approves or
-- declines. Rows are deleted once answered (or when they expire on read).
CREATE TABLE IF NOT EXISTS join_requests (
    request_id TEXT PRIMARY KEY,
    from_user_id TEXT NOT NULL,
    to_user_id TEXT NOT NULL,
    created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_join_requests_to
    ON join_requests(to_user_id, created_at DESC);

-- Idempotency ledger for progression: one row per workout that has advanced
-- the trackers. The PRIMARY KEY makes a second EndWorkout for the same workout
-- a no-op claim, so a tracker can't move twice for one workout.
CREATE TABLE IF NOT EXISTS progression_applied (
    workout_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    applied_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS user_settings_current (
    user_id TEXT NOT NULL,
    setting_type TEXT NOT NULL,
    setting_blob BLOB NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY(user_id, setting_type)
);

-- A template is a named, ordered exercise list; the blob is the proto
-- WorkoutTemplate (name/order mirrored in columns for listing).
CREATE TABLE IF NOT EXISTS workout_templates (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    template_order INTEGER NOT NULL DEFAULT 0,
    template_blob BLOB NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_workout_templates_user
    ON workout_templates(user_id, template_order);

-- One tracker per (user, exercise): the working weight and the position in
-- the rep range that double progression advances. Overrides of 0 = derived.
CREATE TABLE IF NOT EXISTS exercise_trackers (
    user_id TEXT NOT NULL,
    exercise INTEGER NOT NULL,
    working_weight REAL NOT NULL DEFAULT 0,
    current_reps INTEGER NOT NULL DEFAULT 0,
    consecutive_misses INTEGER NOT NULL DEFAULT 0,
    last_performed_at INTEGER NOT NULL DEFAULT 0,
    override_sets INTEGER NOT NULL DEFAULT 0,
    override_rep_low INTEGER NOT NULL DEFAULT 0,
    override_rep_high INTEGER NOT NULL DEFAULT 0,
    updated_at INTEGER NOT NULL,
    source TEXT NOT NULL DEFAULT '',
    PRIMARY KEY(user_id, exercise)
);

CREATE TABLE IF NOT EXISTS schema_migrations (
    name TEXT PRIMARY KEY,
    applied_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS user_message_events (
    user_id TEXT NOT NULL,
    message_key TEXT NOT NULL,
    surface INTEGER NOT NULL DEFAULT 0,
    workout_id TEXT NOT NULL DEFAULT '',
    source_workout_id TEXT NOT NULL DEFAULT '',
    exercise_group_id TEXT NOT NULL DEFAULT '',
    exercise INTEGER NOT NULL DEFAULT 0,
    slot_key TEXT NOT NULL DEFAULT '',
    dismissed_at INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    message_blob BLOB NOT NULL,
    PRIMARY KEY(user_id, message_key)
);
CREATE INDEX IF NOT EXISTS idx_user_message_events_user_surface
    ON user_message_events(user_id, surface, workout_id, dismissed_at, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_message_events_user_workout
    ON user_message_events(user_id, workout_id, dismissed_at, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_message_events_user_source_workout
    ON user_message_events(user_id, source_workout_id, dismissed_at, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_message_events_user_slot
    ON user_message_events(user_id, slot_key, dismissed_at, updated_at DESC);
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
        migration::run(&write_pool).await?;
        sqlx::query(
            "ALTER TABLE user_message_events ADD COLUMN source_workout_id TEXT NOT NULL DEFAULT ''",
        )
        .execute(&write_pool)
        .await
        .ok();
        sqlx::query(
            "CREATE INDEX IF NOT EXISTS idx_user_message_events_user_source_workout
             ON user_message_events(user_id, source_workout_id, dismissed_at, updated_at DESC)",
        )
        .execute(&write_pool)
        .await?;
        Ok(Self {
            read_pool,
            write_pool,
        })
    }
}
