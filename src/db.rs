use dashmap::DashMap;
use lift::workout::v1::{
    CompletedSet, ExerciseTypeConfig, ProposedSet, RestConfig, User, Workout, WorkoutHeartRatePoint,
};
use crate::regimes::SessionHistory;
use sqlx::{
    sqlite::{SqliteConnectOptions, SqliteJournalMode, SqlitePoolOptions, SqliteSynchronous},
    Pool, Row, Sqlite,
};
use std::collections::HashMap;
use std::fs;
use std::path::Path;
use std::str::FromStr;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};
use uuid::Uuid;

// Row mapping functions - single place to define DB <-> Proto mapping. Yes
fn rest_config_from_columns(
    rest_success: Option<i32>,
    rest_failure: Option<i32>,
    rest_warmup: Option<i32>,
    rest_last_warmup: Option<i32>,
) -> Option<RestConfig> {
    let rest_config = RestConfig {
        rest_after_success: rest_success.unwrap_or(0),
        rest_after_failure: rest_failure.unwrap_or(0),
        rest_after_warmup: rest_warmup.unwrap_or(0),
        rest_after_last_warmup: rest_last_warmup.unwrap_or(0),
    };

    if rest_config.rest_after_success > 0
        || rest_config.rest_after_failure > 0
        || rest_config.rest_after_warmup > 0
        || rest_config.rest_after_last_warmup > 0
    {
        Some(rest_config)
    } else {
        None
    }
}

fn row_to_workout(row: sqlx::sqlite::SqliteRow) -> Workout {
    Workout {
        id: row.get("id"),
        name: row.get("name"),
        start_time: row.get("start_time"),
        end_time: row.get::<Option<i64>, _>("end_time").unwrap_or(0),
        session_id: row
            .get::<Option<String>, _>("session_id")
            .unwrap_or_default(),
    }
}

fn row_to_exercise_group(row: sqlx::sqlite::SqliteRow) -> lift::workout::v1::ExerciseGroup {
    lift::workout::v1::ExerciseGroup {
        id: row.get("id"),
        workout_id: row.get("workout_id"),
        name: row.get("name"),
        sets: row.get("sets"),
        interleave_warmups: row.get("interleave_warmups"),
        workout_order: row.get("workout_order"),
        exercise_configs: vec![], // filled by caller
        rest_config: rest_config_from_columns(
            row.get::<Option<i32>, _>("rest_success"),
            row.get::<Option<i32>, _>("rest_failure"),
            row.get::<Option<i32>, _>("rest_warmup"),
            row.get::<Option<i32>, _>("rest_last_warmup"),
        ),
        instruction: String::new(), // not persisted; coaching text from regime
    }
}

fn row_to_exercise_type_config(row: sqlx::sqlite::SqliteRow) -> ExerciseTypeConfig {
    ExerciseTypeConfig {
        exercise: row.get("exercise"),
        start_weight: row.get("start_weight"),
        end_weight: row.get("end_weight"),
        reps: row.get("reps"),
        include_warmup: row.get("include_warmup"),
        rest_config: rest_config_from_columns(
            row.get::<Option<i32>, _>("rest_success"),
            row.get::<Option<i32>, _>("rest_failure"),
            row.get::<Option<i32>, _>("rest_warmup"),
            row.get::<Option<i32>, _>("rest_last_warmup"),
        ),
        last_set_amrap: false, // not persisted; set by regime when generating proposed groups
    }
}

fn row_to_proposed_set(row: sqlx::sqlite::SqliteRow) -> ProposedSet {
    let rest_after_success = row
        .get::<Option<i32>, _>("rest_after_success")
        .unwrap_or(180);
    let rest_after_failure = row
        .get::<Option<i32>, _>("rest_after_failure")
        .unwrap_or(300);
    ProposedSet {
        id: row.get("id"),
        workout_id: row.get("workout_id"),
        workout_order: row.get("workout_order"),
        exercise: row.get("exercise"),
        target_reps: row.get("target_reps"),
        target_weight: row.get("target_weight"),
        warmup: row.get("warmup"),
        exercise_group_id: row
            .get::<Option<String>, _>("exercise_group_id")
            .unwrap_or_default(),
        rest_after_success,
        rest_after_failure,
        cancelled: row.get::<Option<bool>, _>("cancelled").unwrap_or(false),
        is_amrap: false,       // not persisted; set during set generation
        instruction: String::new(),
    }
}

fn row_to_completed_set(row: sqlx::sqlite::SqliteRow) -> CompletedSet {
    CompletedSet {
        id: row.get("id"),
        workout_id: row.get("workout_id"),
        proposed_set_id: row
            .get::<Option<String>, _>("proposed_set_id")
            .unwrap_or_default(),
        actual_reps: row.get("actual_reps"),
        actual_weight: row.get("actual_weight"),
        started_at: row.get("started_at"),
        ended_at: row.get("ended_at"),
        rest_until: row.get::<Option<i64>, _>("rest_until").unwrap_or(0),
    }
}

fn row_to_user(row: sqlx::sqlite::SqliteRow) -> User {
    User {
        id: row.get("id"),
        name: row.get("name"),
        created_at: row.get("created_at"),
    }
}

#[derive(Clone)]
pub enum WriteCommand {
    CreateWorkout(String, Workout),
    InsertGroupWithSets(String, lift::workout::v1::ExerciseGroup, Vec<ProposedSet>),
    UpsertCompletedSet(String, CompletedSet),
    InsertWorkoutHeartRate(String, String, Vec<WorkoutHeartRatePoint>),
    UpdateWorkoutEnd(String, String, i64),
    UpdateWorkoutSession(String, String, String),
    DeleteCompletedSet(String, String, String),
    JoinSession(String, String),
    LeaveSession(String, String),
    InsertUserSetting(String, String, String, Vec<u8>),
    #[cfg(feature = "test-auth")]
    TestLoginUpsert(User, String, i64),
}

#[derive(Clone)]
pub struct CentralDb {
    pub pool: Pool<Sqlite>,
    // In-memory cache: token -> (user_id, expires_at_secs)
    auth_cache: Arc<DashMap<String, (String, i64)>>,
    // Cache for user lookups by name to speed up TestLogin
    user_by_name_cache: Arc<DashMap<String, User>>,
    // Serializes all write operations to prevent SQLite lock contention
    write_lock: Arc<tokio::sync::Mutex<()>>,
    // Channel to send write commands to the background worker
    write_tx: tokio::sync::mpsc::UnboundedSender<WriteCommand>,
}

const CENTRAL_SCHEMA: &str = r#"
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS active_sessions (
    user_id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    joined_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_active_sessions_session ON active_sessions(session_id);

CREATE TABLE IF NOT EXISTS passkey_credentials (
    credential_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    credential_json TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    created_at_ip TEXT,
    FOREIGN KEY(user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS auth_sessions (
    token TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    FOREIGN KEY(user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS workouts (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL DEFAULT '',
    start_time INTEGER NOT NULL,
    end_time INTEGER,
    session_id TEXT,
    FOREIGN KEY(user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS exercise_groups (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    name TEXT NOT NULL,
    sets INTEGER NOT NULL,
    interleave_warmups BOOLEAN NOT NULL,
    workout_order INTEGER NOT NULL,
    rest_success INTEGER,
    rest_failure INTEGER,
    rest_warmup INTEGER,
    rest_last_warmup INTEGER,
    FOREIGN KEY(user_id) REFERENCES users(id),
    FOREIGN KEY(workout_id) REFERENCES workouts(id)
);

CREATE TABLE IF NOT EXISTS exercise_type_configs (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    exercise_group_id TEXT NOT NULL,
    exercise INTEGER NOT NULL,
    start_weight REAL NOT NULL,
    end_weight REAL NOT NULL,
    reps INTEGER NOT NULL,
    include_warmup BOOLEAN NOT NULL,
    config_order INTEGER NOT NULL,
    rest_success INTEGER,
    rest_failure INTEGER,
    rest_warmup INTEGER,
    rest_last_warmup INTEGER,
    FOREIGN KEY(user_id) REFERENCES users(id),
    FOREIGN KEY(exercise_group_id) REFERENCES exercise_groups(id)
);

CREATE TABLE IF NOT EXISTS proposed_sets (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    workout_order INTEGER NOT NULL,
    exercise INTEGER NOT NULL,
    target_reps INTEGER NOT NULL,
    target_weight REAL NOT NULL,
    warmup BOOLEAN NOT NULL,
    cancelled BOOLEAN NOT NULL DEFAULT 0,
    exercise_group_id TEXT,
    rest_after_success INTEGER,
    rest_after_failure INTEGER,
    FOREIGN KEY(user_id) REFERENCES users(id),
    FOREIGN KEY(workout_id) REFERENCES workouts(id),
    FOREIGN KEY(exercise_group_id) REFERENCES exercise_groups(id)
);

CREATE TABLE IF NOT EXISTS completed_sets (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    proposed_set_id TEXT,
    actual_reps INTEGER NOT NULL,
    actual_weight REAL NOT NULL,
    started_at INTEGER NOT NULL,
    ended_at INTEGER NOT NULL,
    rest_until INTEGER,
    FOREIGN KEY(user_id) REFERENCES users(id),
    FOREIGN KEY(workout_id) REFERENCES workouts(id)
);

CREATE TABLE IF NOT EXISTS workout_heart_rate_samples (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    sampled_at INTEGER NOT NULL,
    bpm REAL NOT NULL,
    availability INTEGER NOT NULL,
    source TEXT NOT NULL DEFAULT 'wear',
    FOREIGN KEY(user_id) REFERENCES users(id),
    FOREIGN KEY(workout_id) REFERENCES workouts(id)
);

CREATE TABLE IF NOT EXISTS sessions (
    session_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    joined_at INTEGER NOT NULL,
    left_at INTEGER,
    PRIMARY KEY(session_id, user_id, joined_at),
    FOREIGN KEY(user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_sessions_joined_at ON sessions(joined_at DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_active ON sessions(session_id) WHERE left_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_sessions_session_user_joined ON sessions(session_id, user_id, joined_at DESC);

-- Speed up deletion during flush
CREATE INDEX IF NOT EXISTS idx_exercise_groups_user_workout ON exercise_groups(user_id, workout_id);
CREATE INDEX IF NOT EXISTS idx_proposed_sets_user_workout ON proposed_sets(user_id, workout_id);
CREATE INDEX IF NOT EXISTS idx_completed_sets_user_workout ON completed_sets(user_id, workout_id);
CREATE INDEX IF NOT EXISTS idx_exercise_type_configs_group ON exercise_type_configs(exercise_group_id);

CREATE INDEX IF NOT EXISTS idx_exercise_groups_workout_id ON exercise_groups(workout_id);
CREATE INDEX IF NOT EXISTS idx_proposed_sets_workout_id ON proposed_sets(workout_id);
CREATE INDEX IF NOT EXISTS idx_proposed_sets_group_id ON proposed_sets(exercise_group_id);
CREATE INDEX IF NOT EXISTS idx_proposed_sets_cancelled ON proposed_sets(user_id, workout_id, cancelled);
CREATE INDEX IF NOT EXISTS idx_completed_sets_workout_id ON completed_sets(workout_id);
CREATE INDEX IF NOT EXISTS idx_completed_sets_proposed_id ON completed_sets(proposed_set_id);
CREATE INDEX IF NOT EXISTS idx_hr_samples_user_workout_time ON workout_heart_rate_samples(user_id, workout_id, sampled_at);
CREATE INDEX IF NOT EXISTS idx_workouts_start_time ON workouts(start_time DESC);
CREATE INDEX IF NOT EXISTS idx_workouts_user_id ON workouts(user_id);
CREATE INDEX IF NOT EXISTS idx_workouts_session_user_start ON workouts(session_id, user_id, start_time DESC);
CREATE INDEX IF NOT EXISTS idx_users_name_lower ON users(lower(name));

CREATE TABLE IF NOT EXISTS user_settings (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    setting_type TEXT NOT NULL,
    setting_blob BLOB NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_user_settings_latest
    ON user_settings(user_id, setting_type, created_at DESC);
"#;

impl CentralDb {
    pub async fn new() -> Result<Self, Box<dyn std::error::Error + Send + Sync>> {
        Self::new_in_dir("data").await
    }

    pub async fn new_in_dir(
        data_dir: impl AsRef<Path>,
    ) -> Result<Self, Box<dyn std::error::Error + Send + Sync>> {
        let data_dir = data_dir.as_ref();
        if !data_dir.exists() {
            fs::create_dir_all(data_dir)?;
        }

        let db_path = format!("{}/central.sqlite", data_dir.display());
        let db_url = format!("sqlite://{}", db_path);

        let options = SqliteConnectOptions::from_str(&db_url)?
            .create_if_missing(true)
            .synchronous(SqliteSynchronous::Normal)
            .journal_mode(SqliteJournalMode::Wal)
            .busy_timeout(std::time::Duration::from_secs(30)); // Allow waiting for write lock

        let pool = SqlitePoolOptions::new()
            .max_connections(10)
            .connect_with(options)
            .await?;
        sqlx::query(CENTRAL_SCHEMA).execute(&pool).await?;

        // Manual migration for created_at_ip column
        let _ = sqlx::query("ALTER TABLE passkey_credentials ADD COLUMN created_at_ip TEXT")
            .execute(&pool)
            .await;

        // Manual migration for password_hash column
        let _ = sqlx::query("ALTER TABLE users ADD COLUMN password_hash TEXT")
            .execute(&pool)
            .await;

        // Manual migration for proposed set cancellation tracking
        let _ = sqlx::query(
            "ALTER TABLE proposed_sets ADD COLUMN cancelled BOOLEAN NOT NULL DEFAULT 0",
        )
        .execute(&pool)
        .await;

        // Manual migration for workout session_id
        let _ = sqlx::query("ALTER TABLE workouts ADD COLUMN session_id TEXT")
            .execute(&pool)
            .await;

        let (write_tx, write_rx) = tokio::sync::mpsc::unbounded_channel();
        let db = Self {
            pool,
            auth_cache: Arc::new(DashMap::new()),
            user_by_name_cache: Arc::new(DashMap::new()),
            write_lock: Arc::new(tokio::sync::Mutex::new(())),
            write_tx,
        };

        // Start background persistence worker
        db.clone().spawn_persistence_worker(write_rx);

        Ok(db)
    }

    fn spawn_persistence_worker(self, mut rx: tokio::sync::mpsc::UnboundedReceiver<WriteCommand>) {
        tokio::spawn(async move {
            let mut buffer = Vec::with_capacity(1000);

            loop {
                // Wait for at least one command
                match rx.recv().await {
                    Some(cmd) => buffer.push(cmd),
                    None => break, // Channel closed
                }

                // Collect more commands if available immediately
                while buffer.len() < 1000 {
                    match rx.try_recv() {
                        Ok(cmd) => buffer.push(cmd),
                        Err(_) => break,
                    }
                }

                // Batch process the buffer
                if let Err(e) = self.process_batch(&buffer).await {
                    eprintln!("Persistence worker error: {}", e);
                }
                buffer.clear();

                // Pacing: don't spin 100% CPU if the channel is constantly full
                tokio::task::yield_now().await;
            }
        });
    }

    async fn process_batch(
        &self,
        commands: &[WriteCommand],
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let _lock = self.write_lock.lock().await;
        let mut tx = self.pool.begin().await?;

        for cmd in commands {
            match cmd {
                WriteCommand::CreateWorkout(user_id, workout) => {
                    sqlx::query(
                        "INSERT OR REPLACE INTO workouts (id, user_id, name, start_time, end_time, session_id) VALUES (?, ?, ?, ?, ?, ?)",
                    )
                    .bind(&workout.id)
                    .bind(user_id)
                    .bind(&workout.name)
                    .bind(workout.start_time)
                    .bind(if workout.end_time == 0 { None } else { Some(workout.end_time) })
                    .bind(if workout.session_id.is_empty() { None } else { Some(&workout.session_id) })
                    .execute(&mut *tx)
                    .await?;
                }
                WriteCommand::InsertGroupWithSets(user_id, group, sets) => {
                    sqlx::query(
                        "INSERT OR REPLACE INTO exercise_groups (id, user_id, workout_id, name, sets, interleave_warmups, workout_order, rest_success, rest_failure, rest_warmup, rest_last_warmup)
                         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    )
                    .bind(&group.id)
                    .bind(user_id)
                    .bind(&group.workout_id)
                    .bind(&group.name)
                    .bind(group.sets)
                    .bind(group.interleave_warmups)
                    .bind(group.workout_order)
                    .bind(group.rest_config.as_ref().map(|rc| rc.rest_after_success))
                    .bind(group.rest_config.as_ref().map(|rc| rc.rest_after_failure))
                    .bind(group.rest_config.as_ref().map(|rc| rc.rest_after_warmup))
                    .bind(
                        group
                            .rest_config
                            .as_ref()
                            .map(|rc| rc.rest_after_last_warmup),
                    )
                    .execute(&mut *tx)
                    .await?;

                    // Insert exercise_type_configs
                    for (idx, config) in group.exercise_configs.iter().enumerate() {
                        let config_id = Uuid::new_v4().to_string();
                        sqlx::query(
                            "INSERT OR REPLACE INTO exercise_type_configs (id, user_id, exercise_group_id, exercise, start_weight, end_weight, reps, include_warmup, config_order, rest_success, rest_failure, rest_warmup, rest_last_warmup)
                             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                        )
                        .bind(&config_id)
                        .bind(user_id)
                        .bind(&group.id)
                        .bind(config.exercise)
                        .bind(config.start_weight)
                        .bind(config.end_weight)
                        .bind(config.reps)
                        .bind(config.include_warmup)
                        .bind(idx as i32)
                        .bind(config.rest_config.as_ref().map(|rc| rc.rest_after_success))
                        .bind(config.rest_config.as_ref().map(|rc| rc.rest_after_failure))
                        .bind(config.rest_config.as_ref().map(|rc| rc.rest_after_warmup))
                        .bind(
                            config
                                .rest_config
                                .as_ref()
                                .map(|rc| rc.rest_after_last_warmup),
                        )
                        .execute(&mut *tx)
                        .await?;
                    }

                    for set in sets {
                        sqlx::query(
                            "INSERT OR REPLACE INTO proposed_sets (id, user_id, workout_id, workout_order, exercise, target_reps, target_weight, warmup, cancelled, exercise_group_id, rest_after_success, rest_after_failure)
                             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                        )
                        .bind(&set.id)
                        .bind(user_id)
                        .bind(&set.workout_id)
                        .bind(set.workout_order)
                        .bind(set.exercise)
                        .bind(set.target_reps)
                        .bind(set.target_weight)
                        .bind(set.warmup)
                        .bind(set.cancelled)
                        .bind(if set.exercise_group_id.is_empty() {
                            None
                        } else {
                            Some(&set.exercise_group_id)
                        })
                        .bind(set.rest_after_success)
                        .bind(set.rest_after_failure)
                        .execute(&mut *tx)
                        .await?;
                    }
                }
                WriteCommand::UpsertCompletedSet(user_id, set) => {
                    sqlx::query(
                        "INSERT OR REPLACE INTO completed_sets (id, user_id, workout_id, proposed_set_id, actual_reps, actual_weight, started_at, ended_at, rest_until)
                         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    )
                    .bind(&set.id)
                    .bind(user_id)
                    .bind(&set.workout_id)
                    .bind(if set.proposed_set_id.is_empty() { None } else { Some(&set.proposed_set_id) })
                    .bind(set.actual_reps)
                    .bind(set.actual_weight)
                    .bind(set.started_at)
                    .bind(set.ended_at)
                    .bind(if set.rest_until == 0 { None } else { Some(set.rest_until) })
                    .execute(&mut *tx)
                    .await?;
                }
                WriteCommand::InsertWorkoutHeartRate(user_id, workout_id, samples) => {
                    if samples.is_empty() {
                        continue;
                    }
                    for sample in samples {
                        sqlx::query(
                            "INSERT INTO workout_heart_rate_samples (id, user_id, workout_id, sampled_at, bpm, availability, source)
                             VALUES (?, ?, ?, ?, ?, ?, 'wear')",
                        )
                        .bind(Uuid::new_v4().to_string())
                        .bind(user_id)
                        .bind(workout_id)
                        .bind(sample.sampled_at)
                        .bind(sample.bpm)
                        .bind(sample.availability)
                        .execute(&mut *tx)
                        .await?;
                    }
                }
                WriteCommand::UpdateWorkoutEnd(user_id, workout_id, end_time) => {
                    sqlx::query("UPDATE workouts SET end_time = ? WHERE user_id = ? AND id = ?")
                        .bind(end_time)
                        .bind(user_id)
                        .bind(workout_id)
                        .execute(&mut *tx)
                        .await?;
                }
                WriteCommand::UpdateWorkoutSession(user_id, workout_id, session_id) => {
                    sqlx::query("UPDATE workouts SET session_id = ? WHERE user_id = ? AND id = ?")
                        .bind(session_id)
                        .bind(user_id)
                        .bind(workout_id)
                        .execute(&mut *tx)
                        .await?;
                }
                WriteCommand::DeleteCompletedSet(user_id, workout_id, set_id) => {
                    sqlx::query("DELETE FROM completed_sets WHERE user_id = ? AND workout_id = ? AND id = ?")
                        .bind(user_id)
                        .bind(workout_id)
                        .bind(set_id)
                        .execute(&mut *tx)
                        .await?;
                }
                WriteCommand::JoinSession(user_id, session_id) => {
                    let now = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;
                    sqlx::query(
                        "INSERT INTO sessions (session_id, user_id, joined_at) VALUES (?, ?, ?)",
                    )
                    .bind(session_id)
                    .bind(user_id)
                    .bind(now)
                    .execute(&mut *tx)
                    .await?;
                }
                WriteCommand::LeaveSession(user_id, session_id) => {
                    let now = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;
                    sqlx::query("UPDATE sessions SET left_at = ? WHERE user_id = ? AND session_id = ? AND left_at IS NULL")
                        .bind(now)
                        .bind(user_id)
                        .bind(session_id)
                        .execute(&mut *tx)
                        .await?;
                }
                WriteCommand::InsertUserSetting(user_id, setting_type, id, blob) => {
                    let now = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;
                    sqlx::query(
                        "INSERT INTO user_settings (id, user_id, setting_type, setting_blob, created_at) VALUES (?, ?, ?, ?, ?)",
                    )
                    .bind(id)
                    .bind(user_id)
                    .bind(setting_type)
                    .bind(blob)
                    .bind(now)
                    .execute(&mut *tx)
                    .await?;
                }
                #[cfg(feature = "test-auth")]
                WriteCommand::TestLoginUpsert(user, token, expires_at) => {
                    // Double-check user existence in case cache was cold
                    let user_id = match sqlx::query_scalar::<_, String>(
                        "SELECT id FROM users WHERE lower(name) = lower(?)",
                    )
                    .bind(&user.name)
                    .fetch_optional(&mut *tx)
                    .await?
                    {
                        Some(id) => id,
                        None => {
                            sqlx::query(
                                "INSERT INTO users (id, name, created_at) VALUES (?, ?, ?)",
                            )
                            .bind(&user.id)
                            .bind(&user.name)
                            .bind(user.created_at)
                            .execute(&mut *tx)
                            .await?;
                            user.id.clone()
                        }
                    };

                    let now = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;
                    sqlx::query("INSERT INTO auth_sessions (token, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)")
                        .bind(&token)
                        .bind(&user_id)
                        .bind(now)
                        .bind(expires_at)
                        .execute(&mut *tx)
                        .await?;
                }
            }
        }

        tx.commit().await?;
        Ok(())
    }

    pub async fn create_user(
        &self,
        name: &str,
    ) -> Result<User, Box<dyn std::error::Error + Send + Sync>> {
        let id = Uuid::new_v4().to_string();
        self.create_user_with_id(&id, name).await
    }

    pub async fn create_user_with_id(
        &self,
        id: &str,
        name: &str,
    ) -> Result<User, Box<dyn std::error::Error + Send + Sync>> {
        let _lock = self.write_lock.lock().await;
        let created_at = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;

        sqlx::query("INSERT INTO users (id, name, created_at) VALUES (?, ?, ?)")
            .bind(id)
            .bind(name)
            .bind(created_at)
            .execute(&self.pool)
            .await
            .map_err(|e| {
                if let Some(sqlite_error) = e.as_database_error().and_then(|de| de.code()) {
                    if sqlite_error == "2067" || sqlite_error == "1555" {
                        // UNIQUE or PRIMARY KEY constraint
                        return Box::new(std::io::Error::new(
                            std::io::ErrorKind::AlreadyExists,
                            "User already exists",
                        ))
                            as Box<dyn std::error::Error + Send + Sync>;
                    }
                }
                Box::new(e) as Box<dyn std::error::Error + Send + Sync>
            })?;

        Ok(User {
            id: id.to_string(),
            name: name.to_string(),
            created_at,
        })
    }

    pub async fn get_user(
        &self,
        user_id: &str,
    ) -> Result<Option<User>, Box<dyn std::error::Error + Send + Sync>> {
        let res = sqlx::query("SELECT id, name, created_at FROM users WHERE id = ?")
            .bind(user_id)
            .map(row_to_user)
            .fetch_optional(&self.pool)
            .await?;

        if let Some(user) = &res {
            self.user_by_name_cache
                .insert(user.name.clone(), user.clone());
        }

        Ok(res)
    }

    pub async fn get_users_by_ids(
        &self,
        user_ids: &[String],
    ) -> Result<HashMap<String, User>, Box<dyn std::error::Error + Send + Sync>> {
        let mut out = HashMap::new();
        if user_ids.is_empty() {
            return Ok(out);
        }

        let mut query_builder: sqlx::QueryBuilder<Sqlite> =
            sqlx::QueryBuilder::new("SELECT id, name, created_at FROM users WHERE id IN (");
        {
            let mut separated = query_builder.separated(", ");
            for user_id in user_ids {
                separated.push_bind(user_id);
            }
        }
        query_builder.push(")");

        let rows = query_builder.build().fetch_all(&self.pool).await?;
        for row in rows {
            let user = row_to_user(row);
            self.user_by_name_cache
                .insert(user.name.clone(), user.clone());
            out.insert(user.id.clone(), user);
        }

        Ok(out)
    }

    pub async fn get_user_by_name(
        &self,
        name: &str,
    ) -> Result<Option<User>, Box<dyn std::error::Error + Send + Sync>> {
        if let Some(user) = self.user_by_name_cache.get(name) {
            return Ok(Some(user.value().clone()));
        }

        let res =
            sqlx::query("SELECT id, name, created_at FROM users WHERE lower(name) = lower(?)")
                .bind(name)
                .map(row_to_user)
                .fetch_optional(&self.pool)
                .await?;

        if let Some(user) = &res {
            self.user_by_name_cache
                .insert(name.to_string(), user.clone());
        }

        Ok(res)
    }

    pub async fn store_credential(
        &self,
        credential_id: &str,
        user_id: &str,
        credential_json: &str,
        created_at_ip: Option<&str>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let _lock = self.write_lock.lock().await;
        let created_at = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;
        sqlx::query("INSERT OR REPLACE INTO passkey_credentials (credential_id, user_id, credential_json, created_at, created_at_ip) VALUES (?, ?, ?, ?, ?)")
            .bind(credential_id)
            .bind(user_id)
            .bind(credential_json)
            .bind(created_at)
            .bind(created_at_ip)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn delete_credential(
        &self,
        user_id: &str,
        credential_id: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let _lock = self.write_lock.lock().await;
        let mut tx = self.pool.begin().await?;

        // Check how many credentials the user has
        let count: i64 =
            sqlx::query_scalar("SELECT COUNT(*) FROM passkey_credentials WHERE user_id = ?")
                .bind(user_id)
                .fetch_one(&mut *tx)
                .await?;

        if count <= 1 {
            return Err("Cannot delete the last passkey".into());
        }

        sqlx::query("DELETE FROM passkey_credentials WHERE user_id = ? AND credential_id = ?")
            .bind(user_id)
            .bind(credential_id)
            .execute(&mut *tx)
            .await?;

        tx.commit().await?;
        Ok(())
    }

    pub async fn update_credential_json(
        &self,
        credential_id: &str,
        new_json: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let _lock = self.write_lock.lock().await;
        sqlx::query("UPDATE passkey_credentials SET credential_json = ? WHERE credential_id = ?")
            .bind(new_json)
            .bind(credential_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn get_credentials_for_user(
        &self,
        user_id: &str,
    ) -> Result<Vec<String>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(
            sqlx::query_scalar("SELECT credential_json FROM passkey_credentials WHERE user_id = ?")
                .bind(user_id)
                .fetch_all(&self.pool)
                .await?,
        )
    }

    pub async fn list_passkey_metadata(
        &self,
        user_id: &str,
    ) -> Result<Vec<(String, i64, String, Option<String>)>, Box<dyn std::error::Error + Send + Sync>>
    {
        Ok(sqlx::query_as(
            "SELECT credential_id, created_at, credential_json, created_at_ip FROM passkey_credentials WHERE user_id = ?",
        )
        .bind(user_id)
        .fetch_all(&self.pool)
        .await?)
    }

    pub async fn create_auth_session(
        &self,
        user_id: &str,
    ) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
        let _lock = self.write_lock.lock().await;
        let token = Uuid::new_v4().to_string();
        let now = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;
        let expires_at = now + 30 * 24 * 60 * 60; // 30 days
        sqlx::query("INSERT INTO auth_sessions (token, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)")
            .bind(&token)
            .bind(user_id)
            .bind(now)
            .bind(expires_at)
            .execute(&self.pool)
            .await?;

        self.auth_cache
            .insert(token.clone(), (user_id.to_string(), expires_at));

        Ok(token)
    }

    pub async fn validate_auth_session(
        &self,
        token: &str,
    ) -> Result<Option<String>, Box<dyn std::error::Error + Send + Sync>> {
        let now = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;

        if let Some(entry) = self.auth_cache.get(token) {
            let (user_id, expires_at) = entry.value();
            if *expires_at > now {
                return Ok(Some(user_id.clone()));
            }
        }

        // Cache miss — fall back to DB
        let result: Option<(String, i64)> = sqlx::query_as(
            "SELECT user_id, expires_at FROM auth_sessions WHERE token = ? AND expires_at > ?",
        )
        .bind(token)
        .bind(now)
        .fetch_optional(&self.pool)
        .await?;

        if let Some((user_id, expires_at)) = &result {
            self.auth_cache
                .insert(token.to_string(), (user_id.clone(), *expires_at));
        }

        Ok(result.map(|(user_id, _)| user_id))
    }

    pub async fn invalidate_auth_session(
        &self,
        token: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let _lock = self.write_lock.lock().await;
        self.auth_cache.remove(token);
        sqlx::query("DELETE FROM auth_sessions WHERE token = ?")
            .bind(token)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn create_user_with_password(
        &self,
        name: &str,
        password_hash: &str,
    ) -> Result<User, Box<dyn std::error::Error + Send + Sync>> {
        let _lock = self.write_lock.lock().await;
        let existing = self.get_user_by_name(name).await?;
        if existing.is_some() {
            return Err(Box::new(std::io::Error::new(
                std::io::ErrorKind::AlreadyExists,
                "User already exists",
            )));
        }

        let id = Uuid::new_v4().to_string();
        let created_at = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;

        sqlx::query("INSERT INTO users (id, name, created_at, password_hash) VALUES (?, ?, ?, ?)")
            .bind(&id)
            .bind(name)
            .bind(created_at)
            .bind(password_hash)
            .execute(&self.pool)
            .await?;

        Ok(User {
            id,
            name: name.to_string(),
            created_at,
        })
    }

    pub async fn get_password_hash(
        &self,
        user_id: &str,
    ) -> Result<Option<String>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(
            sqlx::query_scalar("SELECT password_hash FROM users WHERE id = ?")
                .bind(user_id)
                .fetch_optional(&self.pool)
                .await?,
        )
    }

    // --- Incremental Write Methods ---

    pub async fn create_workout_record(
        &self,
        user_id: &str,
        workout: &Workout,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.write_tx.send(WriteCommand::CreateWorkout(
            user_id.to_string(),
            workout.clone(),
        ))?;
        Ok(())
    }

    pub async fn insert_exercise_group_with_sets(
        &self,
        user_id: &str,
        group: &lift::workout::v1::ExerciseGroup,
        sets: &[ProposedSet],
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.write_tx.send(WriteCommand::InsertGroupWithSets(
            user_id.to_string(),
            group.clone(),
            sets.to_vec(),
        ))?;
        Ok(())
    }

    pub async fn upsert_completed_set(
        &self,
        user_id: &str,
        set: &CompletedSet,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.write_tx.send(WriteCommand::UpsertCompletedSet(
            user_id.to_string(),
            set.clone(),
        ))?;
        Ok(())
    }

    pub async fn update_workout_end_time(
        &self,
        user_id: &str,
        workout_id: &str,
        end_time: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.write_tx.send(WriteCommand::UpdateWorkoutEnd(
            user_id.to_string(),
            workout_id.to_string(),
            end_time,
        ))?;
        Ok(())
    }

    pub async fn update_workout_session_id(
        &self,
        user_id: &str,
        workout_id: &str,
        session_id: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.write_tx.send(WriteCommand::UpdateWorkoutSession(
            user_id.to_string(),
            workout_id.to_string(),
            session_id.to_string(),
        ))?;
        Ok(())
    }

    pub async fn insert_workout_heart_rate_samples(
        &self,
        user_id: &str,
        workout_id: &str,
        samples: &[WorkoutHeartRatePoint],
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if samples.is_empty() {
            return Ok(());
        }
        self.write_tx.send(WriteCommand::InsertWorkoutHeartRate(
            user_id.to_string(),
            workout_id.to_string(),
            samples.to_vec(),
        ))?;
        Ok(())
    }

    #[cfg(feature = "test-auth")]
    pub async fn test_login_upsert(
        &self,
        username: &str,
    ) -> Result<(User, String), Box<dyn std::error::Error + Send + Sync>> {
        // 1. Check cache first
        if let Some(entry) = self.user_by_name_cache.get(username) {
            let user = entry.value().clone();
            let token = Uuid::new_v4().to_string();
            let expires_at = Self::now_plus_30_days();

            // Optimistically update auth cache
            self.auth_cache
                .insert(token.clone(), (user.id.clone(), expires_at));

            // Queue session creation
            self.write_tx.send(WriteCommand::TestLoginUpsert(
                user.clone(),
                token.clone(),
                expires_at,
            ))?;

            return Ok((user, token));
        }

        // 2. Cold cache: Generate new ID and queue full upsert
        let id = Uuid::new_v4().to_string();
        let created_at = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;
        let user = User {
            id,
            name: username.to_string(),
            created_at,
        };
        let token = Uuid::new_v4().to_string();
        let expires_at = Self::now_plus_30_days();

        // Optimistically cache both
        self.user_by_name_cache
            .insert(username.to_string(), user.clone());
        self.auth_cache
            .insert(token.clone(), (user.id.clone(), expires_at));

        // Queue background upsert
        self.write_tx.send(WriteCommand::TestLoginUpsert(
            user.clone(),
            token.clone(),
            expires_at,
        ))?;

        Ok((user, token))
    }

    #[cfg(feature = "test-auth")]
    fn now_plus_30_days() -> i64 {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64;
        now + 30 * 24 * 60 * 60
    }

    pub async fn delete_completed_set_record(
        &self,
        user_id: &str,
        workout_id: &str,
        completed_set_id: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.write_tx.send(WriteCommand::DeleteCompletedSet(
            user_id.to_string(),
            workout_id.to_string(),
            completed_set_id.to_string(),
        ))?;
        Ok(())
    }

    // --- Merged UserDb Functionality ---

    pub async fn get_exercise_groups(
        &self,
        user_id: &str,
        workout_id: &str,
    ) -> Result<Vec<lift::workout::v1::ExerciseGroup>, Box<dyn std::error::Error + Send + Sync>>
    {
        let mut groups: Vec<lift::workout::v1::ExerciseGroup> = sqlx::query(
            "SELECT id, workout_id, name, sets, interleave_warmups, workout_order, rest_success, rest_failure, rest_warmup, rest_last_warmup \
             FROM exercise_groups WHERE user_id = ? AND workout_id = ? ORDER BY workout_order",
        )
        .bind(user_id)
        .bind(workout_id)
        .map(row_to_exercise_group)
        .fetch_all(&self.pool)
        .await?;

        // Fetch all configs for this workout's groups
        let group_ids: Vec<String> = groups.iter().map(|g| g.id.clone()).collect();
        if !group_ids.is_empty() {
            let placeholders = group_ids.iter().map(|_| "?").collect::<Vec<_>>().join(",");
            let query = format!(
                "SELECT exercise_group_id, exercise, start_weight, end_weight, reps, include_warmup, rest_success, rest_failure, rest_warmup, rest_last_warmup \
                 FROM exercise_type_configs WHERE exercise_group_id IN ({}) ORDER BY config_order",
                placeholders
            );
            let mut q = sqlx::query(&query);
            for id in &group_ids {
                q = q.bind(id);
            }
            let config_rows = q.fetch_all(&self.pool).await?;

            let mut configs_by_group: HashMap<String, Vec<ExerciseTypeConfig>> = HashMap::new();
            for row in config_rows {
                let group_id: String = row.get("exercise_group_id");
                let config = row_to_exercise_type_config(row);
                configs_by_group.entry(group_id).or_default().push(config);
            }

            for group in &mut groups {
                if let Some(configs) = configs_by_group.remove(&group.id) {
                    group.exercise_configs = configs;
                }
            }
        }

        Ok(groups)
    }

    pub async fn get_workout(
        &self,
        user_id: &str,
        workout_id: &str,
    ) -> Result<Option<Workout>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query(
            "SELECT id, name, start_time, end_time, session_id FROM workouts WHERE user_id = ? AND id = ?",
        )
        .bind(user_id)
        .bind(workout_id)
        .map(row_to_workout)
        .fetch_optional(&self.pool)
        .await?)
    }

    pub async fn get_active_workout(
        &self,
        user_id: &str,
    ) -> Result<Option<Workout>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query("SELECT id, name, start_time, end_time, session_id FROM workouts WHERE user_id = ? AND end_time IS NULL ORDER BY start_time DESC LIMIT 1")
            .bind(user_id)
            .map(row_to_workout)
            .fetch_optional(&self.pool)
            .await?)
    }

    pub async fn get_proposed_sets(
        &self,
        user_id: &str,
        workout_id: &str,
    ) -> Result<Vec<ProposedSet>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query(
            "SELECT id, workout_id, workout_order, exercise, target_reps, target_weight, warmup, exercise_group_id, rest_after_success, rest_after_failure, cancelled \
             FROM proposed_sets WHERE user_id = ? AND workout_id = ? AND cancelled = 0 ORDER BY workout_order",
        )
        .bind(user_id)
        .bind(workout_id)
        .map(row_to_proposed_set)
        .fetch_all(&self.pool)
        .await?)
    }

    pub async fn get_completed_sets(
        &self,
        user_id: &str,
        workout_id: &str,
    ) -> Result<Vec<CompletedSet>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query(
            "SELECT id, workout_id, proposed_set_id, actual_reps, actual_weight, started_at, ended_at, rest_until
             FROM completed_sets WHERE user_id = ? AND workout_id = ? ORDER BY started_at"
        )
        .bind(user_id)
        .bind(workout_id)
        .map(row_to_completed_set)
        .fetch_all(&self.pool)
        .await?)
    }

    pub async fn list_workouts(
        &self,
        user_id: &str,
    ) -> Result<Vec<Workout>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query(
            "SELECT id, name, start_time, end_time, session_id FROM workouts WHERE user_id = ? ORDER BY start_time DESC",
        )
        .bind(user_id)
        .map(row_to_workout)
        .fetch_all(&self.pool)
        .await?)
    }

    #[allow(dead_code)]
    pub async fn get_session_participants(
        &self,
        session_id: &str,
    ) -> Result<Vec<String>, Box<dyn std::error::Error + Send + Sync>> {
        let rows = sqlx::query_scalar(
            "SELECT DISTINCT user_id FROM (
                SELECT user_id FROM sessions WHERE session_id = ? AND left_at IS NULL
                UNION
                SELECT user_id FROM workouts WHERE session_id = ?
            )",
        )
        .bind(session_id)
        .bind(session_id)
        .fetch_all(&self.pool)
        .await?;
        Ok(rows)
    }

    pub async fn get_session_membership_states(
        &self,
        session_id: &str,
    ) -> Result<Vec<(String, bool)>, Box<dyn std::error::Error + Send + Sync>> {
        let rows = sqlx::query(
            "SELECT s.user_id, s.left_at IS NULL AS is_active_member
             FROM sessions s
             WHERE s.session_id = ?
               AND NOT EXISTS (
                   SELECT 1
                   FROM sessions s2
                   WHERE s2.session_id = s.session_id
                     AND s2.user_id = s.user_id
                     AND (
                         s2.joined_at > s.joined_at
                         OR (s2.joined_at = s.joined_at AND s2.rowid > s.rowid)
                     )
               )",
        )
        .bind(session_id)
        .fetch_all(&self.pool)
        .await?;

        Ok(rows
            .into_iter()
            .map(|row| {
                (
                    row.get::<String, _>("user_id"),
                    row.get::<bool, _>("is_active_member"),
                )
            })
            .collect())
    }

    pub async fn get_session_workout_data(
        &self,
        session_id: &str,
    ) -> Result<
        (
            Vec<(String, Workout)>,
            Vec<lift::workout::v1::ExerciseGroup>,
            Vec<ProposedSet>,
            Vec<CompletedSet>,
        ),
        Box<dyn std::error::Error + Send + Sync>,
    > {
        let rows = sqlx::query(
            "SELECT id, user_id, name, start_time, end_time, session_id
             FROM (
                 SELECT
                     w.*,
                     ROW_NUMBER() OVER (
                         PARTITION BY w.user_id
                         ORDER BY
                             CASE WHEN w.end_time IS NULL THEN 0 ELSE 1 END,
                             w.start_time DESC,
                             w.id DESC
                     ) AS rn
                 FROM workouts w
                 WHERE w.session_id = ?
             ) ranked
             WHERE rn = 1",
        )
        .bind(session_id)
        .fetch_all(&self.pool)
        .await?;

        let mut workouts = Vec::new();
        for row in rows {
            let user_id: String = row.get("user_id");
            let workout = row_to_workout(row);
            workouts.push((user_id, workout));
        }

        if workouts.is_empty() {
            return Ok((vec![], vec![], vec![], vec![]));
        }

        let latest_workouts_cte = "WITH latest_workouts AS (
            SELECT id
            FROM (
                SELECT
                    w.id,
                    w.user_id,
                    ROW_NUMBER() OVER (
                        PARTITION BY w.user_id
                        ORDER BY
                            CASE WHEN w.end_time IS NULL THEN 0 ELSE 1 END,
                            w.start_time DESC,
                            w.id DESC
                    ) AS rn
                FROM workouts w
                WHERE w.session_id = ?
            ) ranked
            WHERE rn = 1
        )";

        let mut groups = sqlx::query(
            &format!(
                "{} \
                 SELECT id, workout_id, name, sets, interleave_warmups, workout_order, rest_success, rest_failure, rest_warmup, rest_last_warmup \
                 FROM exercise_groups \
                 WHERE workout_id IN (SELECT id FROM latest_workouts) \
                 ORDER BY workout_order",
                latest_workouts_cte
            ),
        )
        .bind(session_id)
        .map(row_to_exercise_group)
        .fetch_all(&self.pool)
        .await?;

        let configs_rows = sqlx::query(
            &format!(
                "{} \
                 SELECT exercise_group_id, exercise, start_weight, end_weight, reps, include_warmup, rest_success, rest_failure, rest_warmup, rest_last_warmup \
                 FROM exercise_type_configs \
                 WHERE exercise_group_id IN (
                     SELECT id
                     FROM exercise_groups
                     WHERE workout_id IN (SELECT id FROM latest_workouts)
                 ) \
                 ORDER BY config_order",
                latest_workouts_cte
            ),
        )
        .bind(session_id)
        .fetch_all(&self.pool)
        .await?;

        let mut configs_by_group: HashMap<String, Vec<ExerciseTypeConfig>> = HashMap::new();
        for row in configs_rows {
            let gid: String = row.get("exercise_group_id");
            let config = row_to_exercise_type_config(row);
            configs_by_group.entry(gid).or_default().push(config);
        }

        for group in &mut groups {
            if let Some(configs) = configs_by_group.remove(&group.id) {
                group.exercise_configs = configs;
            }
        }

        let proposed = sqlx::query(
            &format!(
                "{} \
                 SELECT id, workout_id, workout_order, exercise, target_reps, target_weight, warmup, exercise_group_id, rest_after_success, rest_after_failure, cancelled \
                 FROM proposed_sets \
                 WHERE workout_id IN (SELECT id FROM latest_workouts) AND cancelled = 0 \
                 ORDER BY workout_order",
                latest_workouts_cte
            ),
        )
        .bind(session_id)
        .map(row_to_proposed_set)
        .fetch_all(&self.pool)
        .await?;

        let completed = sqlx::query(
            &format!(
                "{} \
                 SELECT id, workout_id, proposed_set_id, actual_reps, actual_weight, started_at, ended_at, rest_until \
                 FROM completed_sets \
                 WHERE workout_id IN (SELECT id FROM latest_workouts) \
                 ORDER BY started_at",
                latest_workouts_cte
            ),
        )
        .bind(session_id)
        .map(row_to_completed_set)
        .fetch_all(&self.pool)
        .await?;

        Ok((workouts, groups, proposed, completed))
    }

    pub async fn get_completed_sets_by_session(
        &self,
        session_id: &str,
    ) -> Result<Vec<CompletedSet>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query(
            "SELECT id, workout_id, proposed_set_id, actual_reps, actual_weight, started_at, ended_at, rest_until \
             FROM completed_sets WHERE workout_id IN (SELECT id FROM workouts WHERE session_id = ?) ORDER BY started_at"
        )
        .bind(session_id)
        .map(row_to_completed_set)
        .fetch_all(&self.pool)
        .await?)
    }

    pub async fn get_all_exercise_history(
        &self,
        user_id: &str,
        limit_per_exercise: i32,
    ) -> Result<
        (HashMap<i32, Vec<SessionHistory>>, HashMap<i32, f32>),
        Box<dyn std::error::Error + Send + Sync>,
    > {
        // last_set_reps: actual reps on the last (highest workout_order) working set for this
        // exercise in that workout — used for AMRAP-gated progression (e.g. GZCLP T3 ≥25 reps).
        let rows = sqlx::query(
            "SELECT exercise, target_weight, successful, ended_at, COALESCE(last_set_reps, 0) as last_set_reps FROM (
                SELECT
                    g_ps.exercise,
                    g_ps.target_weight,
                    (COUNT(g_ps.id) = COUNT(g_cs.id) AND MIN(CASE WHEN g_cs.actual_reps >= g_ps.target_reps THEN 1 ELSE 0 END) = 1) as successful,
                    MAX(g_cs.ended_at) as ended_at,
                    (
                        SELECT cs2.actual_reps
                        FROM proposed_sets ps2
                        JOIN completed_sets cs2 ON ps2.id = cs2.proposed_set_id
                        WHERE ps2.workout_id = g_ps.workout_id
                          AND ps2.exercise = g_ps.exercise
                          AND ps2.warmup = 0
                          AND ps2.cancelled = 0
                          AND cs2.ended_at > 0
                        ORDER BY ps2.workout_order DESC
                        LIMIT 1
                    ) as last_set_reps,
                    ROW_NUMBER() OVER (PARTITION BY g_ps.exercise ORDER BY MAX(g_cs.ended_at) DESC) as rn
                FROM proposed_sets g_ps
                LEFT JOIN completed_sets g_cs ON g_ps.id = g_cs.proposed_set_id AND g_cs.ended_at > 0
                WHERE g_ps.user_id = ? AND g_ps.warmup = 0 AND g_ps.cancelled = 0
                GROUP BY g_ps.exercise, g_ps.workout_id
                HAVING ended_at IS NOT NULL
             ) WHERE rn <= ?",
        )
        .bind(user_id)
        .bind(limit_per_exercise)
        .fetch_all(&self.pool)
        .await?;

        let mut history: HashMap<i32, Vec<SessionHistory>> = HashMap::new();
        for row in rows {
            let exercise = row.get::<i32, _>("exercise");
            let weight = row.get::<f32, _>("target_weight");
            let successful = row.get::<bool, _>("successful");
            let ended_at = row.get::<i64, _>("ended_at");
            let last_set_reps = row.get::<i32, _>("last_set_reps");
            history
                .entry(exercise)
                .or_default()
                .push(SessionHistory { weight, success: successful, timestamp: ended_at, last_set_reps });
        }

        let max_rows = sqlx::query(
            "SELECT ps.exercise, MAX(cs.actual_weight) as max_weight
             FROM completed_sets cs
             JOIN proposed_sets ps ON cs.proposed_set_id = ps.id
             WHERE cs.user_id = ? AND cs.ended_at > 0 AND ps.warmup = 0 AND ps.cancelled = 0
             AND cs.actual_reps >= ps.target_reps
             GROUP BY ps.exercise",
        )
        .bind(user_id)
        .fetch_all(&self.pool)
        .await?;

        let mut max_weights: HashMap<i32, f32> = HashMap::new();
        for row in max_rows {
            let exercise = row.get::<i32, _>("exercise");
            let max_weight = row.get::<f32, _>("max_weight");
            max_weights.insert(exercise, max_weight);
        }

        Ok((history, max_weights))
    }

    pub async fn join_session(
        &self,
        user_id: &str,
        session_id: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.write_tx.send(WriteCommand::JoinSession(
            user_id.to_string(),
            session_id.to_string(),
        ))?;
        Ok(())
    }

    pub async fn leave_session(
        &self,
        user_id: &str,
        session_id: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.write_tx.send(WriteCommand::LeaveSession(
            user_id.to_string(),
            session_id.to_string(),
        ))?;
        Ok(())
    }

    pub async fn get_active_session(
        &self,
        user_id: &str,
    ) -> Result<Option<String>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(
            sqlx::query_scalar("SELECT session_id FROM sessions WHERE user_id = ? AND left_at IS NULL ORDER BY joined_at DESC LIMIT 1")
                .bind(user_id)
                .fetch_optional(&self.pool)
                .await?,
        )
    }

    pub async fn flush_workout(
        &self,
        user_id: &str,
        workout: &Workout,
        exercise_groups: &[lift::workout::v1::ExerciseGroup],
        proposed_sets: &[ProposedSet],
        completed_sets: &[CompletedSet],
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let _lock = self.write_lock.lock().await;
        let mut tx = self.pool.begin().await?;

        // Upsert workout
        sqlx::query(
            "INSERT OR REPLACE INTO workouts (id, user_id, name, start_time, end_time, session_id) VALUES (?, ?, ?, ?, ?, ?)",
        )
        .bind(&workout.id)
        .bind(user_id)
        .bind(&workout.name)
        .bind(workout.start_time)
        .bind(if workout.end_time == 0 {
            None
        } else {
            Some(workout.end_time)
        })
        .bind(if workout.session_id.is_empty() {
            None
        } else {
            Some(&workout.session_id)
        })
        .execute(&mut *tx)
        .await?;

        // Delete in order: configs -> completed_sets -> proposed_sets -> exercise_groups
        // Delete configs for groups in this workout
        sqlx::query("DELETE FROM exercise_type_configs WHERE user_id = ? AND exercise_group_id IN (SELECT id FROM exercise_groups WHERE user_id = ? AND workout_id = ?)")
            .bind(user_id)
            .bind(user_id)
            .bind(&workout.id)
            .execute(&mut *tx)
            .await?;

        sqlx::query("DELETE FROM completed_sets WHERE user_id = ? AND workout_id = ?")
            .bind(user_id)
            .bind(&workout.id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM proposed_sets WHERE user_id = ? AND workout_id = ?")
            .bind(user_id)
            .bind(&workout.id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM exercise_groups WHERE user_id = ? AND workout_id = ?")
            .bind(user_id)
            .bind(&workout.id)
            .execute(&mut *tx)
            .await?;

        // Batch inserts for groups
        if !exercise_groups.is_empty() {
            let mut query_builder: sqlx::QueryBuilder<Sqlite> = sqlx::QueryBuilder::new(
                "INSERT INTO exercise_groups (id, user_id, workout_id, name, sets, interleave_warmups, workout_order, rest_success, rest_failure, rest_warmup, rest_last_warmup) "
            );
            query_builder.push_values(exercise_groups, |mut b, group| {
                b.push_bind(&group.id)
                    .push_bind(user_id)
                    .push_bind(&group.workout_id)
                    .push_bind(&group.name)
                    .push_bind(group.sets)
                    .push_bind(group.interleave_warmups)
                    .push_bind(group.workout_order)
                    .push_bind(group.rest_config.as_ref().map(|rc| rc.rest_after_success))
                    .push_bind(group.rest_config.as_ref().map(|rc| rc.rest_after_failure))
                    .push_bind(group.rest_config.as_ref().map(|rc| rc.rest_after_warmup))
                    .push_bind(
                        group
                            .rest_config
                            .as_ref()
                            .map(|rc| rc.rest_after_last_warmup),
                    );
            });
            query_builder.build().execute(&mut *tx).await?;

            // Insert configs for all groups
            let all_configs: Vec<(String, i32, &ExerciseTypeConfig)> = exercise_groups
                .iter()
                .flat_map(|g| {
                    g.exercise_configs
                        .iter()
                        .enumerate()
                        .map(move |(idx, c)| (g.id.clone(), idx as i32, c))
                })
                .collect();

            if !all_configs.is_empty() {
                for chunk in all_configs.chunks(100) {
                    let mut query_builder: sqlx::QueryBuilder<Sqlite> = sqlx::QueryBuilder::new(
                        "INSERT INTO exercise_type_configs (id, user_id, exercise_group_id, exercise, start_weight, end_weight, reps, include_warmup, config_order, rest_success, rest_failure, rest_warmup, rest_last_warmup) "
                    );
                    query_builder.push_values(chunk, |mut b, (group_id, idx, config)| {
                        b.push_bind(Uuid::new_v4().to_string())
                            .push_bind(user_id)
                            .push_bind(group_id)
                            .push_bind(config.exercise)
                            .push_bind(config.start_weight)
                            .push_bind(config.end_weight)
                            .push_bind(config.reps)
                            .push_bind(config.include_warmup)
                            .push_bind(idx)
                            .push_bind(config.rest_config.as_ref().map(|rc| rc.rest_after_success))
                            .push_bind(config.rest_config.as_ref().map(|rc| rc.rest_after_failure))
                            .push_bind(config.rest_config.as_ref().map(|rc| rc.rest_after_warmup))
                            .push_bind(
                                config
                                    .rest_config
                                    .as_ref()
                                    .map(|rc| rc.rest_after_last_warmup),
                            );
                    });
                    query_builder.build().execute(&mut *tx).await?;
                }
            }
        }

        // Batch inserts for proposed sets
        if !proposed_sets.is_empty() {
            for chunk in proposed_sets.chunks(100) {
                let mut query_builder: sqlx::QueryBuilder<Sqlite> = sqlx::QueryBuilder::new(
                    "INSERT INTO proposed_sets (id, user_id, workout_id, workout_order, exercise, target_reps, target_weight, warmup, cancelled, exercise_group_id, rest_after_success, rest_after_failure) "
                );
                query_builder.push_values(chunk, |mut b, set| {
                    b.push_bind(&set.id)
                        .push_bind(user_id)
                        .push_bind(&set.workout_id)
                        .push_bind(set.workout_order)
                        .push_bind(set.exercise)
                        .push_bind(set.target_reps)
                        .push_bind(set.target_weight)
                        .push_bind(set.warmup)
                        .push_bind(set.cancelled)
                        .push_bind(if set.exercise_group_id.is_empty() {
                            None
                        } else {
                            Some(&set.exercise_group_id)
                        })
                        .push_bind(set.rest_after_success)
                        .push_bind(set.rest_after_failure);
                });
                query_builder.build().execute(&mut *tx).await?;
            }
        }

        // Batch inserts for completed sets
        if !completed_sets.is_empty() {
            for chunk in completed_sets.chunks(100) {
                let mut query_builder: sqlx::QueryBuilder<Sqlite> = sqlx::QueryBuilder::new(
                    "INSERT INTO completed_sets (id, user_id, workout_id, proposed_set_id, actual_reps, actual_weight, started_at, ended_at, rest_until) "
                );
                query_builder.push_values(chunk, |mut b, set| {
                    b.push_bind(&set.id)
                        .push_bind(user_id)
                        .push_bind(&set.workout_id)
                        .push_bind(if set.proposed_set_id.is_empty() {
                            None
                        } else {
                            Some(&set.proposed_set_id)
                        })
                        .push_bind(set.actual_reps)
                        .push_bind(set.actual_weight)
                        .push_bind(set.started_at)
                        .push_bind(set.ended_at)
                        .push_bind(if set.rest_until == 0 {
                            None
                        } else {
                            Some(set.rest_until)
                        });
                });
                query_builder.build().execute(&mut *tx).await?;
            }
        }

        tx.commit().await?;
        Ok(())
    }

    pub async fn insert_user_setting(
        &self,
        user_id: &str,
        setting_type: &str,
        blob: &[u8],
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let id = Uuid::new_v4().to_string();
        self.write_tx.send(WriteCommand::InsertUserSetting(
            user_id.to_string(),
            setting_type.to_string(),
            id,
            blob.to_vec(),
        ))?;
        Ok(())
    }

    /// Fetch the user's workout config (regime selection + state) from user_settings.
    pub async fn get_user_workout_config(
        &self,
        user_id: &str,
    ) -> Result<Option<lift::workout::v1::UserWorkoutConfig>, Box<dyn std::error::Error + Send + Sync>>
    {
        use prost::Message;
        let row: Option<Vec<u8>> = sqlx::query_scalar(
            "SELECT setting_blob FROM user_settings
             WHERE user_id = ? AND setting_type = 'workout_config'
             ORDER BY created_at DESC LIMIT 1",
        )
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await?;

        if let Some(blob) = row {
            // The blob is encoded as a UserSetting (with workout_config oneof).
            if let Ok(setting) = lift::workout::v1::UserSetting::decode(blob.as_slice()) {
                if let Some(lift::workout::v1::user_setting::Setting::WorkoutConfig(config)) =
                    setting.setting
                {
                    return Ok(Some(config));
                }
            }
        }
        Ok(None)
    }

    /// Return the end_time of the most recent completed workout for a user.
    pub async fn get_last_workout_end_time(
        &self,
        user_id: &str,
    ) -> Result<Option<i64>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query_scalar(
            "SELECT MAX(end_time) FROM workouts WHERE user_id = ? AND end_time IS NOT NULL",
        )
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await?
        .flatten())
    }

    pub async fn get_latest_settings(
        &self,
        user_id: &str,
    ) -> Result<Vec<(String, Vec<u8>)>, Box<dyn std::error::Error + Send + Sync>> {
        let rows: Vec<(String, Vec<u8>)> = sqlx::query_as(
            "SELECT setting_type, setting_blob FROM user_settings
             WHERE (user_id, setting_type, created_at) IN (
                 SELECT user_id, setting_type, MAX(created_at)
                 FROM user_settings
                 WHERE user_id = ?
                 GROUP BY user_id, setting_type
             )",
        )
        .bind(user_id)
        .fetch_all(&self.pool)
        .await?;
        Ok(rows)
    }

    pub async fn delete_user_account_and_data(
        &self,
        user_id: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let _lock = self.write_lock.lock().await;
        let mut tx = self.pool.begin().await?;

        let maybe_name: Option<String> = sqlx::query_scalar("SELECT name FROM users WHERE id = ?")
            .bind(user_id)
            .fetch_optional(&mut *tx)
            .await?;

        sqlx::query("DELETE FROM active_sessions WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM sessions WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM workout_heart_rate_samples WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM completed_sets WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM proposed_sets WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM exercise_type_configs WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM exercise_groups WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM workouts WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM user_settings WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM passkey_credentials WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM auth_sessions WHERE user_id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM users WHERE id = ?")
            .bind(user_id)
            .execute(&mut *tx)
            .await?;

        tx.commit().await?;

        self.auth_cache
            .retain(|_, (cached_user_id, _)| cached_user_id != user_id);
        if let Some(name) = maybe_name {
            self.user_by_name_cache.remove(&name);
        }

        Ok(())
    }
}
