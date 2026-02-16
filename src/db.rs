use dashmap::DashMap;
use lift::workout::v1::{CompletedSet, ProposedSet, User, Workout};
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
use tokio::sync::RwLock;
use uuid::Uuid;

// Global cache of per-user database pools — DashMap for per-shard locking
static USER_DB_CACHE: std::sync::LazyLock<DashMap<String, Pool<Sqlite>>> =
    std::sync::LazyLock::new(|| DashMap::new());

const SCHEMA: &str = r#"
CREATE TABLE IF NOT EXISTS workouts (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL DEFAULT '',
    start_time INTEGER NOT NULL,
    end_time INTEGER
);

CREATE TABLE IF NOT EXISTS exercise_groups (
    id TEXT PRIMARY KEY,
    workout_id TEXT NOT NULL,
    name TEXT NOT NULL,
    type INTEGER NOT NULL,
    include_warmup BOOLEAN NOT NULL,
    workout_order INTEGER NOT NULL,
    FOREIGN KEY(workout_id) REFERENCES workouts(id)
);

CREATE TABLE IF NOT EXISTS proposed_sets (
    id TEXT PRIMARY KEY,
    workout_id TEXT NOT NULL,
    workout_order INTEGER NOT NULL,
    exercise INTEGER NOT NULL,
    target_reps INTEGER NOT NULL,
    target_weight REAL NOT NULL,
    warmup BOOLEAN NOT NULL,
    exercise_group_id TEXT,
    FOREIGN KEY(workout_id) REFERENCES workouts(id),
    FOREIGN KEY(exercise_group_id) REFERENCES exercise_groups(id)
);

CREATE TABLE IF NOT EXISTS completed_sets (
    id TEXT PRIMARY KEY,
    workout_id TEXT NOT NULL,
    proposed_set_id TEXT,
    actual_reps INTEGER NOT NULL,
    actual_weight REAL NOT NULL,
    started_at INTEGER NOT NULL,
    ended_at INTEGER NOT NULL,
    rest_until INTEGER,
    FOREIGN KEY(workout_id) REFERENCES workouts(id)
);

CREATE TABLE IF NOT EXISTS user_sessions (
    session_id TEXT PRIMARY KEY,
    is_active BOOLEAN NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_exercise_groups_workout_id ON exercise_groups(workout_id);
CREATE INDEX IF NOT EXISTS idx_proposed_sets_workout_id ON proposed_sets(workout_id);
CREATE INDEX IF NOT EXISTS idx_proposed_sets_group_id ON proposed_sets(exercise_group_id);
CREATE INDEX IF NOT EXISTS idx_completed_sets_workout_id ON completed_sets(workout_id);
CREATE INDEX IF NOT EXISTS idx_completed_sets_proposed_id ON completed_sets(proposed_set_id);
CREATE INDEX IF NOT EXISTS idx_workouts_start_time ON workouts(start_time DESC);
"#;

// Row mapping functions - single place to define DB <-> Proto mapping. Yes
fn row_to_workout(row: sqlx::sqlite::SqliteRow) -> Workout {
    Workout {
        id: row.get("id"),
        name: row.get("name"),
        start_time: row.get("start_time"),
        end_time: row.get::<Option<i64>, _>("end_time").unwrap_or(0),
    }
}

fn row_to_exercise_group(row: sqlx::sqlite::SqliteRow) -> lift::workout::v1::ExerciseGroup {
    lift::workout::v1::ExerciseGroup {
        id: row.get("id"),
        workout_id: row.get("workout_id"),
        name: row.get("name"),
        r#type: row.get("type"),
        include_warmup: row.get("include_warmup"),
        workout_order: row.get("workout_order"),
    }
}

fn row_to_proposed_set(row: sqlx::sqlite::SqliteRow) -> ProposedSet {
    ProposedSet {
        id: row.get("id"),
        workout_id: row.get("workout_id"),
        workout_order: row.get("workout_order"),
        exercise: row.get("exercise"),
        target_reps: row.get("target_reps"),
        target_weight: row.get("target_weight"),
        warmup: row.get("warmup"),
        exercise_group_id: row.get::<Option<String>, _>("exercise_group_id").unwrap_or_default(),
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
pub struct UserDb {
    pub pool: Pool<Sqlite>,
}

impl UserDb {
    pub async fn new(user_id: &str) -> Result<Self, Box<dyn std::error::Error + Send + Sync>> {
        // Fast path: pool already cached (no global lock, just DashMap shard lock)
        if let Some(pool) = USER_DB_CACHE.get(user_id) {
            return Ok(Self { pool: pool.clone() });
        }

        // Slow path: create pool (only blocks the shard for this user_id)
        let data_dir = "data/user_dbs";
        if !Path::new(data_dir).exists() {
            fs::create_dir_all(data_dir)?;
        }

        let db_path = format!("{}/{}.sqlite", data_dir, user_id);
        let db_url = format!("sqlite://{}", db_path);

        let options = SqliteConnectOptions::from_str(&db_url)?
            .create_if_missing(true)
            .synchronous(SqliteSynchronous::Normal)
            .journal_mode(SqliteJournalMode::Wal);
        let pool = SqlitePoolOptions::new().connect_with(options).await?;
        sqlx::query(SCHEMA).execute(&pool).await?;

        USER_DB_CACHE.insert(user_id.to_string(), pool.clone());
        Ok(Self { pool })
    }

    pub async fn get_exercise_groups(
        &self,
        workout_id: &str,
    ) -> Result<Vec<lift::workout::v1::ExerciseGroup>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query(
            "SELECT id, workout_id, name, type, include_warmup, workout_order
             FROM exercise_groups WHERE workout_id = ? ORDER BY workout_order",
        )
        .bind(workout_id)
        .map(row_to_exercise_group)
        .fetch_all(&self.pool)
        .await?)
    }

    pub async fn get_workout(
        &self,
        workout_id: &str,
    ) -> Result<Option<Workout>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(
            sqlx::query("SELECT id, name, start_time, end_time FROM workouts WHERE id = ?")
                .bind(workout_id)
                .map(row_to_workout)
                .fetch_optional(&self.pool)
                .await?,
        )
    }

    pub async fn get_active_workout(
        &self,
    ) -> Result<Option<Workout>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query("SELECT id, name, start_time, end_time FROM workouts WHERE end_time IS NULL ORDER BY start_time DESC LIMIT 1")
            .map(row_to_workout)
            .fetch_optional(&self.pool)
            .await?)
    }

    pub async fn get_proposed_sets(
        &self,
        workout_id: &str,
    ) -> Result<Vec<ProposedSet>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query(
            "SELECT id, workout_id, workout_order, exercise, target_reps, target_weight, warmup, exercise_group_id
             FROM proposed_sets WHERE workout_id = ? ORDER BY workout_order",
        )
        .bind(workout_id)
        .map(row_to_proposed_set)
        .fetch_all(&self.pool)
        .await?)
    }

    pub async fn get_completed_sets(
        &self,
        workout_id: &str,
    ) -> Result<Vec<CompletedSet>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query(
            "SELECT id, workout_id, proposed_set_id, actual_reps, actual_weight, started_at, ended_at, rest_until
             FROM completed_sets WHERE workout_id = ? ORDER BY started_at"
        )
        .bind(workout_id)
        .map(row_to_completed_set)
        .fetch_all(&self.pool)
        .await?)
    }

    pub async fn list_workouts(
        &self,
    ) -> Result<Vec<Workout>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query(
            "SELECT id, name, start_time, end_time FROM workouts ORDER BY start_time DESC",
        )
        .map(row_to_workout)
        .fetch_all(&self.pool)
        .await?)
    }

    /// Fetch workout history for ALL exercises in 2 queries total.
    /// Returns a map of exercise_id -> Vec<(weight, successful, ended_at)> ordered by most recent first,
    /// and a map of exercise_id -> all-time max weight.
    pub async fn get_all_exercise_history(
        &self,
        limit_per_exercise: i32,
    ) -> Result<
        (HashMap<i32, Vec<(f32, bool, i64)>>, HashMap<i32, f32>),
        Box<dyn std::error::Error + Send + Sync>,
    > {
        // Query 1: Last N workout results per exercise using window function
        // ROW_NUMBER() partitions by (exercise, workout_id) so we rank workouts per exercise
        let rows = sqlx::query(
            "SELECT exercise, target_weight, successful, ended_at FROM (
                SELECT
                    ps.exercise,
                    ps.target_weight,
                    (COUNT(ps.id) = COUNT(cs.id) AND MIN(CASE WHEN cs.actual_reps >= ps.target_reps THEN 1 ELSE 0 END) = 1) as successful,
                    MAX(cs.ended_at) as ended_at,
                    ROW_NUMBER() OVER (PARTITION BY ps.exercise ORDER BY MAX(cs.ended_at) DESC) as rn
                FROM proposed_sets ps
                LEFT JOIN completed_sets cs ON ps.id = cs.proposed_set_id AND cs.ended_at > 0
                WHERE ps.warmup = 0
                GROUP BY ps.exercise, ps.workout_id
                HAVING ended_at IS NOT NULL
             ) WHERE rn <= ?",
        )
        .bind(limit_per_exercise)
        .fetch_all(&self.pool)
        .await?;

        let mut history: HashMap<i32, Vec<(f32, bool, i64)>> = HashMap::new();
        for row in rows {
            let exercise = row.get::<i32, _>("exercise");
            let weight = row.get::<f32, _>("target_weight");
            let successful = row.get::<bool, _>("successful");
            let ended_at = row.get::<i64, _>("ended_at");
            history.entry(exercise).or_default().push((weight, successful, ended_at));
        }

        // Query 2: All-time max successful weight per exercise
        let max_rows = sqlx::query(
            "SELECT ps.exercise, MAX(cs.actual_weight) as max_weight
             FROM completed_sets cs
             JOIN proposed_sets ps ON cs.proposed_set_id = ps.id
             WHERE cs.ended_at > 0 AND ps.warmup = 0
             AND cs.actual_reps >= ps.target_reps
             GROUP BY ps.exercise",
        )
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

    pub async fn add_session(
        &self,
        session_id: &str,
        is_active: bool,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if is_active {
            sqlx::query("UPDATE user_sessions SET is_active = 0")
                .execute(&self.pool)
                .await?;
        }
        sqlx::query("INSERT OR REPLACE INTO user_sessions (session_id, is_active) VALUES (?, ?)")
            .bind(session_id)
            .bind(is_active)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn get_active_session(
        &self,
    ) -> Result<Option<String>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(
            sqlx::query_scalar("SELECT session_id FROM user_sessions WHERE is_active = 1 LIMIT 1")
                .fetch_optional(&self.pool)
                .await?,
        )
    }

    /// Batch flush an entire active workout state to the DB in a single transaction.
    /// This does a full DELETE + re-INSERT for the workout's data.
    pub async fn flush_workout(
        &self,
        workout: &Workout,
        exercise_groups: &[lift::workout::v1::ExerciseGroup],
        proposed_sets: &[ProposedSet],
        completed_sets: &[CompletedSet],
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let mut tx = self.pool.begin().await?;

        // Upsert workout
        sqlx::query(
            "INSERT OR REPLACE INTO workouts (id, name, start_time, end_time) VALUES (?, ?, ?, ?)",
        )
        .bind(&workout.id)
        .bind(&workout.name)
        .bind(workout.start_time)
        .bind(if workout.end_time == 0 {
            None
        } else {
            Some(workout.end_time)
        })
        .execute(&mut *tx)
        .await?;

        // Clear and re-insert exercise_groups, proposed_sets, completed_sets
        sqlx::query("DELETE FROM completed_sets WHERE workout_id = ?")
            .bind(&workout.id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM proposed_sets WHERE workout_id = ?")
            .bind(&workout.id)
            .execute(&mut *tx)
            .await?;
        sqlx::query("DELETE FROM exercise_groups WHERE workout_id = ?")
            .bind(&workout.id)
            .execute(&mut *tx)
            .await?;

        for group in exercise_groups {
            sqlx::query(
                "INSERT INTO exercise_groups (id, workout_id, name, type, include_warmup, workout_order)
                 VALUES (?, ?, ?, ?, ?, ?)",
            )
            .bind(&group.id)
            .bind(&group.workout_id)
            .bind(&group.name)
            .bind(group.r#type)
            .bind(group.include_warmup)
            .bind(group.workout_order)
            .execute(&mut *tx)
            .await?;
        }

        for set in proposed_sets {
            sqlx::query(
                "INSERT INTO proposed_sets (id, workout_id, workout_order, exercise, target_reps, target_weight, warmup, exercise_group_id)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            )
            .bind(&set.id)
            .bind(&set.workout_id)
            .bind(set.workout_order)
            .bind(set.exercise)
            .bind(set.target_reps)
            .bind(set.target_weight)
            .bind(set.warmup)
            .bind(if set.exercise_group_id.is_empty() {
                None
            } else {
                Some(&set.exercise_group_id)
            })
            .execute(&mut *tx)
            .await?;
        }

        for set in completed_sets {
            sqlx::query(
                "INSERT INTO completed_sets (id, workout_id, proposed_set_id, actual_reps, actual_weight, started_at, ended_at, rest_until)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            )
            .bind(&set.id)
            .bind(&set.workout_id)
            .bind(if set.proposed_set_id.is_empty() {
                None
            } else {
                Some(&set.proposed_set_id)
            })
            .bind(set.actual_reps)
            .bind(set.actual_weight)
            .bind(set.started_at)
            .bind(set.ended_at)
            .bind(if set.rest_until == 0 {
                None
            } else {
                Some(set.rest_until)
            })
            .execute(&mut *tx)
            .await?;
        }

        tx.commit().await?;
        Ok(())
    }

}

#[derive(Clone)]
pub struct CentralDb {
    pub pool: Pool<Sqlite>,
    // In-memory cache: token -> (user_id, expires_at_secs)
    auth_cache: Arc<RwLock<HashMap<String, (String, i64)>>>,
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
"#;

impl CentralDb {
    pub async fn new() -> Result<Self, Box<dyn std::error::Error + Send + Sync>> {
        let data_dir = "data";
        if !Path::new(data_dir).exists() {
            fs::create_dir(data_dir)?;
        }

        let db_path = format!("{}/central.sqlite", data_dir);
        let db_url = format!("sqlite://{}", db_path);

        let options = SqliteConnectOptions::from_str(&db_url)?
            .create_if_missing(true)
            .synchronous(SqliteSynchronous::Normal)
            .journal_mode(SqliteJournalMode::Wal);
        let pool = SqlitePoolOptions::new()
            .max_connections(10)
            .connect_with(options).await?;
        sqlx::query(CENTRAL_SCHEMA).execute(&pool).await?;

        // Manual migration for created_at_ip column
        let _ = sqlx::query("ALTER TABLE passkey_credentials ADD COLUMN created_at_ip TEXT")
            .execute(&pool)
            .await;

        // Manual migration for password_hash column
        let _ = sqlx::query("ALTER TABLE users ADD COLUMN password_hash TEXT")
            .execute(&pool)
            .await;

        Ok(Self { pool, auth_cache: Arc::new(RwLock::new(HashMap::new())) })
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
        let existing = self.get_user_by_name(name).await?;
        if let Some(_user) = existing {
            return Err(Box::new(std::io::Error::new(
                std::io::ErrorKind::AlreadyExists,
                "User already exists",
            )));
        }

        let created_at = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;

        sqlx::query("INSERT INTO users (id, name, created_at) VALUES (?, ?, ?)")
            .bind(id)
            .bind(name)
            .bind(created_at)
            .execute(&self.pool)
            .await?;

        UserDb::new(id).await?;

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
        Ok(
            sqlx::query("SELECT id, name, created_at FROM users WHERE id = ?")
                .bind(user_id)
                .map(row_to_user)
                .fetch_optional(&self.pool)
                .await?,
        )
    }

    pub async fn get_user_by_name(
        &self,
        name: &str,
    ) -> Result<Option<User>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(
            sqlx::query("SELECT id, name, created_at FROM users WHERE lower(name) = lower(?)")
                .bind(name)
                .map(row_to_user)
                .fetch_optional(&self.pool)
                .await?,
        )
    }

    pub async fn store_credential(
        &self,
        credential_id: &str,
        user_id: &str,
        credential_json: &str,
        created_at_ip: Option<&str>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
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
        let mut tx = self.pool.begin().await?;

        // Check how many credentials the user has
        let count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM passkey_credentials WHERE user_id = ?")
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
    ) -> Result<Vec<(String, i64, String, Option<String>)>, Box<dyn std::error::Error + Send + Sync>> {
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

        // Populate auth cache
        let mut cache = self.auth_cache.write().await;
        cache.insert(token.clone(), (user_id.to_string(), expires_at));

        Ok(token)
    }

    pub async fn validate_auth_session(
        &self,
        token: &str,
    ) -> Result<Option<String>, Box<dyn std::error::Error + Send + Sync>> {
        let now = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;

        // Check in-memory cache first (fast path — no DB hit)
        {
            let cache = self.auth_cache.read().await;
            if let Some((user_id, expires_at)) = cache.get(token) {
                if *expires_at > now {
                    return Ok(Some(user_id.clone()));
                }
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
            let mut cache = self.auth_cache.write().await;
            cache.insert(token.to_string(), (user_id.clone(), *expires_at));
        }

        Ok(result.map(|(user_id, _)| user_id))
    }

    pub async fn invalidate_auth_session(
        &self,
        token: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        // Remove from cache
        {
            let mut cache = self.auth_cache.write().await;
            cache.remove(token);
        }
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

        UserDb::new(&id).await?;

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
}

