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
use std::time::{SystemTime, UNIX_EPOCH};
use uuid::Uuid;

const SCRATCH_SCHEMA: &str = r#"
CREATE TABLE IF NOT EXISTS users_current (
    user_id TEXT PRIMARY KEY,
    user_blob BLOB NOT NULL,
    username_ci TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS auth_sessions (
    token TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    expires_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_auth_sessions_user_id ON auth_sessions(user_id);

-- Real relational tables for workout data
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

-- Pointer to active workout (not a blob)
CREATE TABLE IF NOT EXISTS active_workout_current (
    user_id TEXT PRIMARY KEY,
    workout_id TEXT NOT NULL,
    session_id TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_active_workout_current_session ON active_workout_current(session_id);

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

CREATE TABLE IF NOT EXISTS session_memberships (
    membership_id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    joined_at INTEGER NOT NULL,
    left_at INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_session_memberships_active
    ON session_memberships(session_id, left_at, joined_at DESC);
CREATE INDEX IF NOT EXISTS idx_session_memberships_user_active
    ON session_memberships(user_id, left_at, joined_at DESC);

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
"#;

fn now_unix() -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
    Ok(SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64)
}

pub type DbResult<T> = Result<T, Box<dyn std::error::Error + Send + Sync>>;

#[derive(Clone)]
pub struct ServerDb {
    /// Read pool: many connections for concurrent SELECT queries (WAL mode allows this).
    pub read_pool: Pool<Sqlite>,
    /// Write pool: single connection — SQLite only allows one writer at a time,
    /// so a pool of 1 serializes writes naturally without "database is locked" errors.
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
        sqlx::query(SCRATCH_SCHEMA).execute(&write_pool).await?;
        Ok(Self {
            read_pool,
            write_pool,
        })
    }

    // ── Auth ──

    pub async fn get_or_create_user_with_auth_session(
        &self,
        username: &str,
    ) -> DbResult<(schlift::workout::v1::User, String)> {
        let mut tx = self.write_pool.begin().await?;
        let normalized = username.trim().to_lowercase();
        let existing: Option<Vec<u8>> =
            sqlx::query_scalar("SELECT user_blob FROM users_current WHERE username_ci = ?")
                .bind(&normalized)
                .fetch_optional(&mut *tx)
                .await?;
        let user = match existing {
            Some(blob) => schlift::workout::v1::User::decode(blob.as_slice())?,
            None => {
                let user = schlift::workout::v1::User {
                    id: Uuid::new_v4().to_string(),
                    name: username.trim().to_string(),
                    created_at: now_unix()?,
                };
                sqlx::query(
                    "INSERT INTO users_current (user_id, user_blob, username_ci) VALUES (?, ?, ?)",
                )
                .bind(&user.id)
                .bind(user.encode_to_vec())
                .bind(&normalized)
                .execute(&mut *tx)
                .await?;
                user
            }
        };
        let token = Uuid::new_v4().to_string();
        sqlx::query("INSERT INTO auth_sessions (token, user_id, expires_at) VALUES (?, ?, ?)")
            .bind(&token)
            .bind(&user.id)
            .bind(now_unix()? + 30 * 24 * 60 * 60)
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
        Ok((user, token))
    }

    pub async fn validate_auth_session(&self, token: &str) -> DbResult<Option<String>> {
        let now = now_unix()?;
        let user_id: Option<String> = sqlx::query_scalar(
            "SELECT user_id FROM auth_sessions WHERE token = ? AND expires_at > ?",
        )
        .bind(token)
        .bind(now)
        .fetch_optional(&self.read_pool)
        .await?;
        Ok(user_id)
    }

    pub async fn delete_auth_session(&self, token: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM auth_sessions WHERE token = ?")
            .bind(token)
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }

    pub async fn get_user(&self, user_id: &str) -> DbResult<Option<schlift::workout::v1::User>> {
        let blob: Option<Vec<u8>> =
            sqlx::query_scalar("SELECT user_blob FROM users_current WHERE user_id = ?")
                .bind(user_id)
                .fetch_optional(&self.read_pool)
                .await?;
        match blob {
            Some(blob) => Ok(Some(schlift::workout::v1::User::decode(blob.as_slice())?)),
            None => Ok(None),
        }
    }

    // ── Workout CRUD (real tables) ──

    /// Insert a new workout with its groups and proposed sets in one transaction.
    pub async fn insert_workout(
        &self,
        user_id: &str,
        workout: &Workout,
        groups: &[ExerciseGroup],
        proposed_sets: &[ProposedSet],
    ) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;

        sqlx::query(
            "INSERT INTO workouts (id, user_id, name, start_time, end_time, session_id) VALUES (?, ?, ?, ?, ?, ?)",
        )
        .bind(&workout.id)
        .bind(user_id)
        .bind(&workout.name)
        .bind(workout.start_time)
        .bind(workout.end_time)
        .bind(&workout.session_id)
        .execute(&mut *tx)
        .await?;

        for group in groups {
            Self::insert_exercise_group_tx(&mut tx, user_id, group).await?;
        }

        for set in proposed_sets {
            Self::insert_proposed_set_tx(&mut tx, user_id, set).await?;
        }

        // Set active workout pointer
        sqlx::query(
            "INSERT INTO active_workout_current (user_id, workout_id, session_id) VALUES (?, ?, ?)
             ON CONFLICT(user_id) DO UPDATE SET workout_id = excluded.workout_id, session_id = excluded.session_id",
        )
        .bind(user_id)
        .bind(&workout.id)
        .bind(&workout.session_id)
        .execute(&mut *tx)
        .await?;

        tx.commit().await?;
        Ok(())
    }

    async fn insert_exercise_group_tx(
        tx: &mut sqlx::Transaction<'_, Sqlite>,
        user_id: &str,
        group: &ExerciseGroup,
    ) -> DbResult<()> {
        let rest = group.rest_config.as_ref();
        let configs_blob = if group.exercise_configs.is_empty() {
            None
        } else {
            Some(encode_exercise_configs(&group.exercise_configs))
        };
        sqlx::query(
            "INSERT INTO exercise_groups (id, user_id, workout_id, name, sets, interleave_warmups,
             prescribed_by_regime, workout_order, instruction, rest_success, rest_failure,
             rest_warmup, rest_last_warmup, exercise_configs_blob)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(&group.id)
        .bind(user_id)
        .bind(&group.workout_id)
        .bind(&group.name)
        .bind(group.sets)
        .bind(group.interleave_warmups as i32)
        .bind(group.prescribed_by_regime as i32)
        .bind(group.workout_order)
        .bind(&group.instruction)
        .bind(rest.map(|r| r.rest_after_success).unwrap_or(0))
        .bind(rest.map(|r| r.rest_after_failure).unwrap_or(0))
        .bind(rest.map(|r| r.rest_after_warmup).unwrap_or(0))
        .bind(rest.map(|r| r.rest_after_last_warmup).unwrap_or(0))
        .bind(configs_blob)
        .execute(&mut **tx)
        .await?;
        Ok(())
    }

    async fn insert_proposed_set_tx(
        tx: &mut sqlx::Transaction<'_, Sqlite>,
        user_id: &str,
        set: &ProposedSet,
    ) -> DbResult<()> {
        let prog_blob = set.progression_hint.as_ref().map(|p| p.encode_to_vec());
        sqlx::query(
            "INSERT INTO proposed_sets (id, user_id, workout_id, exercise_group_id, workout_order,
             exercise, target_reps, target_weight, warmup, cancelled, rest_after_success,
             rest_after_failure, is_amrap, instruction, progression_blob)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(&set.id)
        .bind(user_id)
        .bind(&set.workout_id)
        .bind(&set.exercise_group_id)
        .bind(set.workout_order)
        .bind(set.exercise)
        .bind(set.target_reps)
        .bind(set.target_weight as f64)
        .bind(set.warmup as i32)
        .bind(set.cancelled as i32)
        .bind(set.rest_after_success)
        .bind(set.rest_after_failure)
        .bind(set.is_amrap as i32)
        .bind(&set.instruction)
        .bind(prog_blob)
        .execute(&mut **tx)
        .await?;
        Ok(())
    }

    /// Insert a single completed set.
    pub async fn insert_completed_set(&self, user_id: &str, set: &CompletedSet) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO completed_sets (id, user_id, workout_id, proposed_set_id,
             actual_reps, actual_weight, started_at, ended_at, rest_until)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(&set.id)
        .bind(user_id)
        .bind(&set.workout_id)
        .bind(&set.proposed_set_id)
        .bind(set.actual_reps)
        .bind(set.actual_weight as f64)
        .bind(set.started_at)
        .bind(set.ended_at)
        .bind(set.rest_until)
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    /// Update a completed set (for CompleteSet: fills in ended_at, actual_reps/weight, rest_until).
    pub async fn update_completed_set(
        &self,
        set_id: &str,
        actual_reps: i32,
        actual_weight: f32,
        ended_at: i64,
        rest_until: i64,
    ) -> DbResult<()> {
        sqlx::query(
            "UPDATE completed_sets SET actual_reps = ?, actual_weight = ?, ended_at = ?, rest_until = ? WHERE id = ?",
        )
        .bind(actual_reps)
        .bind(actual_weight as f64)
        .bind(ended_at)
        .bind(rest_until)
        .bind(set_id)
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    /// Delete a completed set by id.
    pub async fn delete_completed_set(&self, set_id: &str, workout_id: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM completed_sets WHERE id = ? AND workout_id = ?")
            .bind(set_id)
            .bind(workout_id)
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }

    /// Cancel a proposed set.
    pub async fn cancel_proposed_set(&self, set_id: &str, workout_id: &str) -> DbResult<()> {
        sqlx::query("UPDATE proposed_sets SET cancelled = 1 WHERE id = ? AND workout_id = ?")
            .bind(set_id)
            .bind(workout_id)
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }

    /// End a workout: set end_time and remove active pointer.
    pub async fn end_workout(
        &self,
        user_id: &str,
        workout_id: &str,
        end_time: i64,
    ) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;
        sqlx::query("UPDATE workouts SET end_time = ? WHERE id = ? AND user_id = ?")
            .bind(end_time)
            .bind(workout_id)
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM active_workout_current WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
        Ok(())
    }

    /// Update workout session_id (when joining a multiplayer session).
    pub async fn update_workout_session_id(
        &self,
        user_id: &str,
        workout_id: &str,
        session_id: &str,
    ) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;
        sqlx::query("UPDATE workouts SET session_id = ? WHERE id = ? AND user_id = ?")
            .bind(session_id)
            .bind(workout_id)
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("UPDATE active_workout_current SET session_id = ? WHERE user_id = ?")
            .bind(session_id)
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        tx.commit().await?;
        Ok(())
    }

    /// Persist full workout state from an ActiveWorkout (used after ReplaceExerciseGroupPlan
    /// and other structural mutations that modify groups/sets).
    pub async fn persist_workout_state(
        &self,
        user_id: &str,
        workout: &Workout,
        groups: &[ExerciseGroup],
        proposed_sets: &[ProposedSet],
        completed_sets: &[CompletedSet],
    ) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;

        // Update workout row
        sqlx::query("UPDATE workouts SET name = ?, start_time = ?, end_time = ?, session_id = ? WHERE id = ? AND user_id = ?")
            .bind(&workout.name)
            .bind(workout.start_time)
            .bind(workout.end_time)
            .bind(&workout.session_id)
            .bind(&workout.id)
            .bind(user_id)
            .execute(&mut *tx)
            .await?;

        // Replace groups: delete old, insert new
        sqlx::query("DELETE FROM exercise_groups WHERE workout_id = ? AND user_id = ?")
            .bind(&workout.id)
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        for group in groups {
            Self::insert_exercise_group_tx(&mut tx, user_id, group).await?;
        }

        // Replace proposed sets: delete old, insert new
        sqlx::query("DELETE FROM proposed_sets WHERE workout_id = ? AND user_id = ?")
            .bind(&workout.id)
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        for set in proposed_sets {
            Self::insert_proposed_set_tx(&mut tx, user_id, set).await?;
        }

        // Replace completed sets: delete old, insert new
        sqlx::query("DELETE FROM completed_sets WHERE workout_id = ? AND user_id = ?")
            .bind(&workout.id)
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        for set in completed_sets {
            sqlx::query(
                "INSERT INTO completed_sets (id, user_id, workout_id, proposed_set_id,
                 actual_reps, actual_weight, started_at, ended_at, rest_until)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            )
            .bind(&set.id)
            .bind(user_id)
            .bind(&set.workout_id)
            .bind(&set.proposed_set_id)
            .bind(set.actual_reps)
            .bind(set.actual_weight as f64)
            .bind(set.started_at)
            .bind(set.ended_at)
            .bind(set.rest_until)
            .execute(&mut *tx)
            .await?;
        }

        tx.commit().await?;
        Ok(())
    }

    // ── Workout Reads ──

    /// Get active workout_id for a user.
    pub async fn get_active_workout_id(&self, user_id: &str) -> DbResult<Option<(String, String)>> {
        let row: Option<(String, String)> = sqlx::query_as(
            "SELECT workout_id, session_id FROM active_workout_current WHERE user_id = ?",
        )
        .bind(user_id)
        .fetch_optional(&self.read_pool)
        .await?;
        Ok(row)
    }

    /// Load a workout row by id.
    pub async fn get_workout(&self, user_id: &str, workout_id: &str) -> DbResult<Option<Workout>> {
        let row = sqlx::query(
            "SELECT id, name, start_time, end_time, session_id FROM workouts WHERE id = ? AND user_id = ?",
        )
        .bind(workout_id)
        .bind(user_id)
        .fetch_optional(&self.read_pool)
        .await?;
        Ok(row.map(|r| Workout {
            id: r.get("id"),
            name: r.get("name"),
            start_time: r.get("start_time"),
            end_time: r.get("end_time"),
            session_id: r.get("session_id"),
        }))
    }

    /// Load exercise groups for a workout.
    pub async fn get_exercise_groups(&self, workout_id: &str) -> DbResult<Vec<ExerciseGroup>> {
        let rows = sqlx::query(
            "SELECT id, workout_id, name, sets, interleave_warmups, prescribed_by_regime,
             workout_order, instruction, rest_success, rest_failure, rest_warmup,
             rest_last_warmup, exercise_configs_blob
             FROM exercise_groups WHERE workout_id = ? ORDER BY workout_order",
        )
        .bind(workout_id)
        .fetch_all(&self.read_pool)
        .await?;
        let mut groups = Vec::with_capacity(rows.len());
        for r in rows {
            let configs_blob: Option<Vec<u8>> = r.get("exercise_configs_blob");
            let exercise_configs = configs_blob
                .map(|b| decode_exercise_configs(&b))
                .unwrap_or_default();
            groups.push(ExerciseGroup {
                id: r.get("id"),
                workout_id: r.get("workout_id"),
                name: r.get("name"),
                sets: r.get("sets"),
                interleave_warmups: r.get::<i32, _>("interleave_warmups") != 0,
                workout_order: r.get("workout_order"),
                exercise_configs,
                rest_config: Some(RestConfig {
                    rest_after_success: r.get("rest_success"),
                    rest_after_failure: r.get("rest_failure"),
                    rest_after_warmup: r.get("rest_warmup"),
                    rest_after_last_warmup: r.get("rest_last_warmup"),
                }),
                instruction: r.get("instruction"),
                prescribed_by_regime: r.get::<i32, _>("prescribed_by_regime") != 0,
            });
        }
        Ok(groups)
    }

    /// Load proposed sets for a workout.
    pub async fn get_proposed_sets(&self, workout_id: &str) -> DbResult<Vec<ProposedSet>> {
        let rows = sqlx::query(
            "SELECT id, workout_id, exercise_group_id, workout_order, exercise,
             target_reps, target_weight, warmup, cancelled, rest_after_success,
             rest_after_failure, is_amrap, instruction, progression_blob
             FROM proposed_sets WHERE workout_id = ? ORDER BY workout_order",
        )
        .bind(workout_id)
        .fetch_all(&self.read_pool)
        .await?;
        let mut sets = Vec::with_capacity(rows.len());
        for r in rows {
            let prog_blob: Option<Vec<u8>> = r.get("progression_blob");
            let progression_hint =
                prog_blob.and_then(|b| ProgressionHint::decode(b.as_slice()).ok());
            sets.push(ProposedSet {
                id: r.get("id"),
                workout_id: r.get("workout_id"),
                exercise_group_id: r.get("exercise_group_id"),
                workout_order: r.get("workout_order"),
                exercise: r.get("exercise"),
                target_reps: r.get("target_reps"),
                target_weight: r.get::<f64, _>("target_weight") as f32,
                warmup: r.get::<i32, _>("warmup") != 0,
                cancelled: r.get::<i32, _>("cancelled") != 0,
                rest_after_success: r.get("rest_after_success"),
                rest_after_failure: r.get("rest_after_failure"),
                is_amrap: r.get::<i32, _>("is_amrap") != 0,
                instruction: r.get("instruction"),
                progression_hint,
            });
        }
        Ok(sets)
    }

    /// Load completed sets for a workout.
    pub async fn get_completed_sets(&self, workout_id: &str) -> DbResult<Vec<CompletedSet>> {
        let rows = sqlx::query(
            "SELECT id, workout_id, proposed_set_id, actual_reps, actual_weight,
             started_at, ended_at, rest_until
             FROM completed_sets WHERE workout_id = ? ORDER BY started_at",
        )
        .bind(workout_id)
        .fetch_all(&self.read_pool)
        .await?;
        let mut sets = Vec::with_capacity(rows.len());
        for r in rows {
            sets.push(CompletedSet {
                id: r.get("id"),
                workout_id: r.get("workout_id"),
                proposed_set_id: r.get("proposed_set_id"),
                actual_reps: r.get("actual_reps"),
                actual_weight: r.get::<f64, _>("actual_weight") as f32,
                started_at: r.get("started_at"),
                ended_at: r.get("ended_at"),
                rest_until: r.get("rest_until"),
            });
        }
        Ok(sets)
    }

    /// Load full workout response from real tables.
    pub async fn load_workout_full(
        &self,
        user_id: &str,
        workout_id: &str,
    ) -> DbResult<Option<GetWorkoutResponse>> {
        let workout = match self.get_workout(user_id, workout_id).await? {
            Some(w) => w,
            None => return Ok(None),
        };
        let exercise_groups = self.get_exercise_groups(workout_id).await?;
        let proposed_sets = self.get_proposed_sets(workout_id).await?;
        let completed_sets = self.get_completed_sets(workout_id).await?;

        use crate::progress::compute_next_up_set;
        use crate::workout::{
            active_proposed_sets, workout_plan_change_stats_from_sets,
            workout_state_snapshot_from_state,
        };

        let now = now_unix()?;
        let active_proposed = active_proposed_sets(&proposed_sets);
        let next_up_set = compute_next_up_set(&active_proposed, &completed_sets);
        let state_snapshot = Some(workout_state_snapshot_from_state(
            &proposed_sets,
            &completed_sets,
            now,
        ));
        let plan_change_stats = Some(workout_plan_change_stats_from_sets(&proposed_sets));

        Ok(Some(GetWorkoutResponse {
            workout: Some(workout),
            exercise_groups,
            proposed_sets: active_proposed,
            completed_sets,
            next_up_set,
            plan_change_stats,
            state_snapshot,
        }))
    }

    /// Get a proposed set by id (for StartSet to look up target values).
    pub async fn get_proposed_set(&self, set_id: &str) -> DbResult<Option<ProposedSet>> {
        let row = sqlx::query(
            "SELECT id, workout_id, exercise_group_id, workout_order, exercise,
             target_reps, target_weight, warmup, cancelled, rest_after_success,
             rest_after_failure, is_amrap, instruction, progression_blob
             FROM proposed_sets WHERE id = ?",
        )
        .bind(set_id)
        .fetch_optional(&self.read_pool)
        .await?;
        Ok(row.map(|r| {
            let prog_blob: Option<Vec<u8>> = r.get("progression_blob");
            let progression_hint =
                prog_blob.and_then(|b| ProgressionHint::decode(b.as_slice()).ok());
            ProposedSet {
                id: r.get("id"),
                workout_id: r.get("workout_id"),
                exercise_group_id: r.get("exercise_group_id"),
                workout_order: r.get("workout_order"),
                exercise: r.get("exercise"),
                target_reps: r.get("target_reps"),
                target_weight: r.get::<f64, _>("target_weight") as f32,
                warmup: r.get::<i32, _>("warmup") != 0,
                cancelled: r.get::<i32, _>("cancelled") != 0,
                rest_after_success: r.get("rest_after_success"),
                rest_after_failure: r.get("rest_after_failure"),
                is_amrap: r.get::<i32, _>("is_amrap") != 0,
                instruction: r.get("instruction"),
                progression_hint,
            }
        }))
    }

    /// Find the in-progress completed set for a proposed_set_id.
    pub async fn find_in_progress_completed_set(
        &self,
        workout_id: &str,
        proposed_set_id: &str,
    ) -> DbResult<Option<CompletedSet>> {
        let row = sqlx::query(
            "SELECT id, workout_id, proposed_set_id, actual_reps, actual_weight,
             started_at, ended_at, rest_until
             FROM completed_sets WHERE workout_id = ? AND proposed_set_id = ? AND ended_at = 0",
        )
        .bind(workout_id)
        .bind(proposed_set_id)
        .fetch_optional(&self.read_pool)
        .await?;
        Ok(row.map(|r| CompletedSet {
            id: r.get("id"),
            workout_id: r.get("workout_id"),
            proposed_set_id: r.get("proposed_set_id"),
            actual_reps: r.get("actual_reps"),
            actual_weight: r.get::<f64, _>("actual_weight") as f32,
            started_at: r.get("started_at"),
            ended_at: r.get("ended_at"),
            rest_until: r.get("rest_until"),
        }))
    }

    /// List finished workouts for a user.
    pub async fn list_workouts(&self, user_id: &str) -> DbResult<Vec<Workout>> {
        let rows = sqlx::query(
            "SELECT id, name, start_time, end_time, session_id
             FROM workouts WHERE user_id = ? AND end_time > 0 ORDER BY start_time DESC",
        )
        .bind(user_id)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| Workout {
                id: r.get("id"),
                name: r.get("name"),
                start_time: r.get("start_time"),
                end_time: r.get("end_time"),
                session_id: r.get("session_id"),
            })
            .collect())
    }

    // ── Session ──

    pub async fn upsert_session_participant(
        &self,
        session_id: &str,
        user_id: &str,
        status: &ParticipantStatus,
    ) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO session_participants_current (session_id, user_id, participant_blob, updated_at)
             VALUES (?, ?, ?, ?)
             ON CONFLICT(session_id, user_id) DO UPDATE SET
               participant_blob = excluded.participant_blob,
               updated_at = excluded.updated_at",
        )
        .bind(session_id)
        .bind(user_id)
        .bind(status.encode_to_vec())
        .bind(now_unix()?)
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    pub async fn remove_session_participant(
        &self,
        session_id: &str,
        user_id: &str,
    ) -> DbResult<()> {
        sqlx::query(
            "DELETE FROM session_participants_current WHERE session_id = ? AND user_id = ?",
        )
        .bind(session_id)
        .bind(user_id)
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    pub async fn get_current_session_id_for_user(&self, user_id: &str) -> DbResult<Option<String>> {
        let session_id: Option<String> = sqlx::query_scalar(
            "SELECT session_id FROM session_memberships WHERE user_id = ? AND left_at = 0 ORDER BY joined_at DESC LIMIT 1",
        )
        .bind(user_id)
        .fetch_optional(&self.read_pool)
        .await?;
        Ok(session_id)
    }

    pub async fn join_session(&self, user_id: &str, session_id: &str) -> DbResult<()> {
        let now = now_unix()?;
        let mut tx = self.write_pool.begin().await?;
        sqlx::query(
            "UPDATE session_memberships SET left_at = ? WHERE user_id = ? AND left_at = 0 AND session_id != ?",
        )
        .bind(now)
        .bind(user_id)
        .bind(session_id)
        .execute(&mut *tx)
        .await?;
        sqlx::query(
            "INSERT INTO session_memberships (membership_id, session_id, user_id, joined_at, left_at)
             SELECT ?, ?, ?, ?, 0
             WHERE NOT EXISTS (
                SELECT 1 FROM session_memberships WHERE user_id = ? AND session_id = ? AND left_at = 0
             )",
        )
        .bind(Uuid::new_v4().to_string())
        .bind(session_id)
        .bind(user_id)
        .bind(now)
        .bind(user_id)
        .bind(session_id)
        .execute(&mut *tx)
        .await?;
        tx.commit().await?;
        Ok(())
    }

    pub async fn leave_session(&self, user_id: &str, session_id: &str) -> DbResult<()> {
        sqlx::query(
            "UPDATE session_memberships SET left_at = ? WHERE user_id = ? AND session_id = ? AND left_at = 0",
        )
        .bind(now_unix()?)
        .bind(user_id)
        .bind(session_id)
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    pub async fn get_session_participants(
        &self,
        session_id: &str,
    ) -> DbResult<Vec<ParticipantStatus>> {
        let rows = sqlx::query(
            "SELECT participant_blob FROM session_participants_current WHERE session_id = ? ORDER BY updated_at DESC",
        )
        .bind(session_id)
        .fetch_all(&self.read_pool)
        .await?;
        let mut out = Vec::with_capacity(rows.len());
        for row in rows {
            let blob: Vec<u8> = row.get("participant_blob");
            out.push(ParticipantStatus::decode(blob.as_slice())?);
        }
        Ok(out)
    }

    // ── Schedule/Program/Settings/Drafts (blob caches, unchanged) ──

    pub async fn put_schedule_cache(
        &self,
        user_id: &str,
        response: &GetProposedWorkoutScheduleResponse,
    ) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO proposed_schedule_cache (user_id, response_blob, updated_at)
             VALUES (?, ?, ?)
             ON CONFLICT(user_id) DO UPDATE SET response_blob = excluded.response_blob, updated_at = excluded.updated_at",
        )
        .bind(user_id)
        .bind(response.encode_to_vec())
        .bind(now_unix()?)
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    pub async fn put_setting(
        &self,
        user_id: &str,
        setting_type: &str,
        setting: &UserSetting,
    ) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO user_settings_current (user_id, setting_type, setting_blob, updated_at)
             VALUES (?, ?, ?, ?)
             ON CONFLICT(user_id, setting_type) DO UPDATE SET setting_blob = excluded.setting_blob, updated_at = excluded.updated_at",
        )
        .bind(user_id)
        .bind(setting_type)
        .bind(setting.encode_to_vec())
        .bind(now_unix()?)
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    pub async fn get_settings(&self, user_id: &str) -> DbResult<Vec<UserSetting>> {
        let rows = sqlx::query(
            "SELECT setting_blob FROM user_settings_current WHERE user_id = ? ORDER BY setting_type ASC",
        )
        .bind(user_id)
        .fetch_all(&self.read_pool)
        .await?;
        let mut out = Vec::with_capacity(rows.len());
        for row in rows {
            let blob: Vec<u8> = row.get("setting_blob");
            out.push(UserSetting::decode(blob.as_slice())?);
        }
        Ok(out)
    }

    pub async fn put_program_state(
        &self,
        user_id: &str,
        response: &GetActiveTrainingProgramStateResponse,
    ) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO training_program_state_latest (user_id, response_blob, updated_at)
             VALUES (?, ?, ?)
             ON CONFLICT(user_id) DO UPDATE SET response_blob = excluded.response_blob, updated_at = excluded.updated_at",
        )
        .bind(user_id)
        .bind(response.encode_to_vec())
        .bind(now_unix()?)
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    pub async fn get_program_state(
        &self,
        user_id: &str,
    ) -> DbResult<Option<GetActiveTrainingProgramStateResponse>> {
        let blob: Option<Vec<u8>> = sqlx::query_scalar(
            "SELECT response_blob FROM training_program_state_latest WHERE user_id = ?",
        )
        .bind(user_id)
        .fetch_optional(&self.read_pool)
        .await?;
        match blob {
            Some(blob) => Ok(Some(GetActiveTrainingProgramStateResponse::decode(
                blob.as_slice(),
            )?)),
            None => Ok(None),
        }
    }

    pub async fn put_workout_draft(&self, user_id: &str, draft: &WorkoutDraft) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO workout_drafts_current (user_id, draft_blob, updated_at)
             VALUES (?, ?, ?)
             ON CONFLICT(user_id) DO UPDATE SET draft_blob = excluded.draft_blob, updated_at = excluded.updated_at",
        )
        .bind(user_id)
        .bind(draft.encode_to_vec())
        .bind(now_unix()?)
        .execute(&self.write_pool)
        .await?;
        Ok(())
    }

    pub async fn get_workout_draft(&self, user_id: &str) -> DbResult<Option<WorkoutDraft>> {
        let blob: Option<Vec<u8>> =
            sqlx::query_scalar("SELECT draft_blob FROM workout_drafts_current WHERE user_id = ?")
                .bind(user_id)
                .fetch_optional(&self.read_pool)
                .await?;
        match blob {
            Some(blob) => Ok(Some(WorkoutDraft::decode(blob.as_slice())?)),
            None => Ok(None),
        }
    }

    pub async fn clear_workout_draft(&self, user_id: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM workout_drafts_current WHERE user_id = ?")
            .bind(user_id)
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }

    // ── Events & Heart Rate ──

    pub async fn append_workout_events(
        &self,
        user_id: &str,
        workout_id: &str,
        events: &[(String, i64, i32, Vec<u8>)],
    ) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;
        for (event_id, recorded_at, event_type, payload) in events {
            sqlx::query(
                "INSERT INTO workout_events (event_id, user_id, workout_id, recorded_at, event_type, payload) VALUES (?, ?, ?, ?, ?, ?)",
            )
            .bind(event_id)
            .bind(user_id)
            .bind(workout_id)
            .bind(recorded_at)
            .bind(event_type)
            .bind(payload)
            .execute(&mut *tx)
            .await?;
        }
        tx.commit().await?;
        Ok(())
    }

    pub async fn insert_heart_rate_samples(
        &self,
        user_id: &str,
        workout_id: &str,
        samples: &[WorkoutHeartRatePoint],
    ) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;
        for sample in samples {
            sqlx::query(
                "INSERT INTO workout_heart_rate_samples (id, user_id, workout_id, sampled_at, bpm, availability) VALUES (?, ?, ?, ?, ?, ?)",
            )
            .bind(Uuid::new_v4().to_string())
            .bind(user_id)
            .bind(workout_id)
            .bind(sample.sampled_at)
            .bind(sample.bpm as f64)
            .bind(sample.availability)
            .execute(&mut *tx)
            .await?;
        }
        tx.commit().await?;
        Ok(())
    }

    pub async fn get_workout_heart_rate(
        &self,
        user_id: &str,
        workout_id: &str,
    ) -> DbResult<Vec<WorkoutHeartRatePoint>> {
        let rows = sqlx::query(
            "SELECT sampled_at, bpm, availability FROM workout_heart_rate_samples
             WHERE user_id = ? AND workout_id = ? ORDER BY sampled_at ASC",
        )
        .bind(user_id)
        .bind(workout_id)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| WorkoutHeartRatePoint {
                sampled_at: r.get("sampled_at"),
                bpm: r.get::<f64, _>("bpm") as f32,
                availability: r.get("availability"),
            })
            .collect())
    }
}

// ── ExerciseTypeConfig blob encoding ──
// We store repeated ExerciseTypeConfig as a length-delimited sequence of protos.

fn encode_exercise_configs(configs: &[ExerciseTypeConfig]) -> Vec<u8> {
    let mut buf = Vec::new();
    for config in configs {
        let encoded = config.encode_to_vec();
        buf.extend_from_slice(&(encoded.len() as u32).to_le_bytes());
        buf.extend_from_slice(&encoded);
    }
    buf
}

fn decode_exercise_configs(data: &[u8]) -> Vec<ExerciseTypeConfig> {
    let mut configs = Vec::new();
    let mut offset = 0;
    while offset + 4 <= data.len() {
        let len = u32::from_le_bytes([
            data[offset],
            data[offset + 1],
            data[offset + 2],
            data[offset + 3],
        ]) as usize;
        offset += 4;
        if offset + len > data.len() {
            break;
        }
        if let Ok(config) = ExerciseTypeConfig::decode(&data[offset..offset + len]) {
            configs.push(config);
        }
        offset += len;
    }
    configs
}
