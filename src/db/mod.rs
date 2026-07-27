use prost::Message;
use schlift::workout::v1::{
    CompletedSet, ExerciseGroup, ExerciseTypeConfig, GetActiveTrainingProgramStateResponse,
    GetProposedWorkoutScheduleResponse, GetWorkoutResponse, ParticipantStatus, ProgressionHint,
    ProposedSet, RestConfig, UserMessage, UserSetting, Workout, WorkoutDraft,
    WorkoutHeartRatePoint,
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
pub mod training;
mod workout;

pub use training::{TrainingBlockRow, TrainingEntryRow, TrainingSetRow};

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

-- Idempotency ledger for progression: one row per workout that has advanced the
-- program state. The PRIMARY KEY makes a second EndWorkout for the same workout a
-- no-op claim, so progression can't be applied twice.
CREATE TABLE IF NOT EXISTS program_progression_applied (
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

/// Training model v2 schema (blocks → sets → append-only entries + ledger).
/// Applied alongside SERVER_SCHEMA; coexists with the v1 workout tables.
const TRAINING_SCHEMA: &str = r#"
CREATE TABLE IF NOT EXISTS t_workouts (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL DEFAULT '',
    start_time INTEGER NOT NULL,
    end_time INTEGER NOT NULL DEFAULT 0,
    session_id TEXT NOT NULL DEFAULT '',
    active_set_id TEXT NOT NULL DEFAULT '',
    active_started_at INTEGER NOT NULL DEFAULT 0,
    from_program INTEGER NOT NULL DEFAULT 1,
    closed_at INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_t_workouts_user_time ON t_workouts(user_id, start_time DESC);

CREATE TABLE IF NOT EXISTS t_blocks (
    id TEXT PRIMARY KEY,
    workout_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    ord INTEGER NOT NULL,
    name TEXT NOT NULL DEFAULT '',
    interleave_warmups INTEGER NOT NULL DEFAULT 0,
    rest_success INTEGER NOT NULL DEFAULT 0,
    rest_failure INTEGER NOT NULL DEFAULT 0,
    rest_warmup INTEGER NOT NULL DEFAULT 0,
    rest_last_warmup INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_t_blocks_workout ON t_blocks(workout_id, ord);

CREATE TABLE IF NOT EXISTS t_sets (
    id TEXT PRIMARY KEY,
    workout_id TEXT NOT NULL,
    block_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    ord INTEGER NOT NULL,
    exercise INTEGER NOT NULL,
    role INTEGER NOT NULL,
    proposed_weight REAL NOT NULL DEFAULT 0,
    proposed_reps INTEGER NOT NULL DEFAULT 0,
    proposed_duration_s INTEGER NOT NULL DEFAULT 0,
    proposed_distance_m REAL NOT NULL DEFAULT 0,
    target_weight REAL NOT NULL DEFAULT 0,
    target_reps INTEGER NOT NULL DEFAULT 0,
    target_duration_s INTEGER NOT NULL DEFAULT 0,
    target_distance_m REAL NOT NULL DEFAULT 0,
    is_amrap INTEGER NOT NULL DEFAULT 0,
    instruction TEXT NOT NULL DEFAULT '',
    skipped INTEGER NOT NULL DEFAULT 0,
    counts_toward_program INTEGER NOT NULL DEFAULT 0,
    slot_key TEXT NOT NULL DEFAULT '',
    removed INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_t_sets_workout ON t_sets(workout_id, ord);

-- Append-only, bitemporal. The newest non-tombstoned row per set is the truth.
CREATE TABLE IF NOT EXISTS t_entries (
    entry_id TEXT PRIMARY KEY,
    set_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    weight REAL NOT NULL DEFAULT 0,
    reps INTEGER NOT NULL DEFAULT 0,
    duration_s INTEGER NOT NULL DEFAULT 0,
    distance_m REAL NOT NULL DEFAULT 0,
    performed_at INTEGER NOT NULL,  -- valid time: when the set happened (back-datable)
    recorded_at INTEGER NOT NULL,   -- transaction time: when this row was written
    tombstone INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_t_entries_set ON t_entries(set_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_t_entries_workout ON t_entries(workout_id);

-- Append-only progression ledger. One row per (user, workout) that advanced the
-- program. UNIQUE gives idempotency: a re-fired CloseWorkout is a no-op.
CREATE TABLE IF NOT EXISTS t_progression (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    at INTEGER NOT NULL,
    reason TEXT NOT NULL DEFAULT '',
    state_before BLOB,
    state_after BLOB,
    changes_blob BLOB,
    UNIQUE(user_id, workout_id)
);
CREATE INDEX IF NOT EXISTS idx_t_progression_user_time ON t_progression(user_id, at DESC);
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
        sqlx::query(TRAINING_SCHEMA).execute(&write_pool).await?;
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
