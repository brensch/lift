use sqlx::{sqlite::{SqliteConnectOptions, SqlitePoolOptions, SqliteSynchronous, SqliteJournalMode}, Pool, Sqlite, Row, Arguments};
use std::str::FromStr;
use std::path::Path;
use std::fs;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;
use uuid::Uuid;
use std::time::{SystemTime, UNIX_EPOCH};
use lift::workout::v1::{Workout, ProposedSet, CompletedSet, User};

// Global cache of per-user database pools
static USER_DB_CACHE: std::sync::LazyLock<Arc<Mutex<HashMap<String, Pool<Sqlite>>>>> =
    std::sync::LazyLock::new(|| Arc::new(Mutex::new(HashMap::new())));

const SCHEMA: &str = r#"
CREATE TABLE IF NOT EXISTS workouts (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL DEFAULT '',
    start_time INTEGER NOT NULL,
    end_time INTEGER
);

CREATE TABLE IF NOT EXISTS proposed_sets (
    id TEXT PRIMARY KEY,
    workout_id TEXT NOT NULL,
    workout_order INTEGER NOT NULL,
    exercise INTEGER NOT NULL,
    target_reps INTEGER NOT NULL,
    target_weight REAL NOT NULL,
    warmup BOOLEAN NOT NULL,
    FOREIGN KEY(workout_id) REFERENCES workouts(id)
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

CREATE INDEX IF NOT EXISTS idx_proposed_sets_workout_id ON proposed_sets(workout_id);
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

fn row_to_proposed_set(row: sqlx::sqlite::SqliteRow) -> ProposedSet {
    ProposedSet {
        id: row.get("id"),
        workout_id: row.get("workout_id"),
        workout_order: row.get("workout_order"),
        exercise: row.get("exercise"),
        target_reps: row.get("target_reps"),
        target_weight: row.get("target_weight"),
        warmup: row.get("warmup"),
    }
}

fn row_to_completed_set(row: sqlx::sqlite::SqliteRow) -> CompletedSet {
    CompletedSet {
        id: row.get("id"),
        workout_id: row.get("workout_id"),
        proposed_set_id: row.get::<Option<String>, _>("proposed_set_id").unwrap_or_default(),
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

fn compute_rest_seconds(target_reps: i32, actual_reps: i32, warmup: bool, last_warmup: bool) -> i64 {
    if warmup && last_warmup {
        180 // 3 minutes before first working set
    } else if warmup {
        10
    } else if actual_reps >= target_reps {
        180 // 3 minutes
    } else {
        300 // 5 minutes
    }
}

#[derive(Clone)]
pub struct UserDb {
    pub pool: Pool<Sqlite>,
}

impl UserDb {
    pub async fn new(user_id: &str) -> Result<Self, Box<dyn std::error::Error + Send + Sync>> {
        let mut cache = USER_DB_CACHE.lock().await;

        if let Some(pool) = cache.get(user_id) {
            return Ok(Self { pool: pool.clone() });
        }

        let data_dir = "user_dbs";
        if !Path::new(data_dir).exists() {
            fs::create_dir(data_dir)?;
        }

        let db_path = format!("{}/{}.sqlite", data_dir, user_id);
        let db_url = format!("sqlite://{}", db_path);

        let options = SqliteConnectOptions::from_str(&db_url)?.create_if_missing(true)
            .synchronous(SqliteSynchronous::Normal)
            .journal_mode(SqliteJournalMode::Wal);
        let pool = SqlitePoolOptions::new().connect_with(options).await?;
        sqlx::query(SCHEMA).execute(&pool).await?;

        cache.insert(user_id.to_string(), pool.clone());
        Ok(Self { pool })
    }

    pub async fn create_workout(&self, name: &str, proposed_sets: Vec<ProposedSet>) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
        let workout_id = Uuid::new_v4().to_string();
        let start_time = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;

        sqlx::query("INSERT INTO workouts (id, name, start_time, end_time) VALUES (?, ?, ?, NULL)")
            .bind(&workout_id)
            .bind(name)
            .bind(start_time)
            .execute(&self.pool)
            .await?;

        for set in proposed_sets {
            let set_id = if set.id.is_empty() { Uuid::new_v4().to_string() } else { set.id };
            sqlx::query(
                "INSERT INTO proposed_sets (id, workout_id, workout_order, exercise, target_reps, target_weight, warmup)
                 VALUES (?, ?, ?, ?, ?, ?, ?)"
            )
            .bind(&set_id)
            .bind(&workout_id)
            .bind(set.workout_order)
            .bind(set.exercise)
            .bind(set.target_reps)
            .bind(set.target_weight)
            .bind(set.warmup)
            .execute(&self.pool)
            .await?;
        }

        Ok(workout_id)
    }

    pub async fn get_workout(&self, workout_id: &str) -> Result<Option<Workout>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query("SELECT id, name, start_time, end_time FROM workouts WHERE id = ?")
            .bind(workout_id)
            .map(row_to_workout)
            .fetch_optional(&self.pool)
            .await?)
    }

    pub async fn get_active_workout(&self) -> Result<Option<Workout>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query("SELECT id, name, start_time, end_time FROM workouts WHERE end_time IS NULL ORDER BY start_time DESC LIMIT 1")
            .map(row_to_workout)
            .fetch_optional(&self.pool)
            .await?)
    }

    pub async fn get_proposed_sets(&self, workout_id: &str) -> Result<Vec<ProposedSet>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query(
            "SELECT id, workout_id, workout_order, exercise, target_reps, target_weight, warmup
             FROM proposed_sets WHERE workout_id = ? ORDER BY workout_order"
        )
        .bind(workout_id)
        .map(row_to_proposed_set)
        .fetch_all(&self.pool)
        .await?)
    }

    pub async fn get_completed_sets(&self, workout_id: &str) -> Result<Vec<CompletedSet>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query(
            "SELECT id, workout_id, proposed_set_id, actual_reps, actual_weight, started_at, ended_at, rest_until
             FROM completed_sets WHERE workout_id = ? ORDER BY started_at"
        )
        .bind(workout_id)
        .map(row_to_completed_set)
        .fetch_all(&self.pool)
        .await?)
    }

    pub async fn list_workouts(&self) -> Result<Vec<Workout>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query("SELECT id, name, start_time, end_time FROM workouts ORDER BY start_time DESC")
            .map(row_to_workout)
            .fetch_all(&self.pool)
            .await?)
    }

    pub async fn get_last_completed_workout(&self) -> Result<Option<Workout>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query(
            "SELECT id, name, start_time, end_time FROM workouts WHERE end_time IS NOT NULL ORDER BY end_time DESC LIMIT 1"
        )
        .map(row_to_workout)
        .fetch_optional(&self.pool)
        .await?)
    }

    pub async fn get_last_weight_for_exercise(&self, exercise: i32) -> Result<Option<f32>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query_scalar(
            "SELECT cs.actual_weight FROM completed_sets cs
             JOIN proposed_sets ps ON cs.proposed_set_id = ps.id
             WHERE ps.exercise = ? AND cs.ended_at > 0 AND ps.warmup = 0
             ORDER BY cs.ended_at DESC LIMIT 1"
        )
        .bind(exercise)
        .fetch_optional(&self.pool)
        .await?)
    }

    pub async fn modify_proposed_sets(&self, workout_id: &str, proposed_sets: Vec<ProposedSet>) -> Result<Vec<ProposedSet>, Box<dyn std::error::Error + Send + Sync>> {
        let mut tx = self.pool.begin().await?;

        sqlx::query("DELETE FROM proposed_sets WHERE workout_id = ?")
            .bind(workout_id)
            .execute(&mut *tx)
            .await?;

        let mut result = Vec::new();
        let mut args = sqlx::sqlite::SqliteArguments::default();
        let mut values_placeholders: Vec<String> = Vec::new();

        for (idx, set) in proposed_sets.into_iter().enumerate() {
            let set_id = if set.id.is_empty() { Uuid::new_v4().to_string() } else { set.id };
            let workout_order = if set.workout_order == 0 { idx as i32 } else { set.workout_order };

            values_placeholders.push("(?, ?, ?, ?, ?, ?, ?)".to_string());
            args.add(set_id.clone())?;
            args.add(workout_id)?;
            args.add(workout_order)?;
            args.add(set.exercise)?;
            args.add(set.target_reps)?;
            args.add(set.target_weight)?;
            args.add(set.warmup)?;

            result.push(ProposedSet {
                id: set_id,
                workout_id: workout_id.to_string(),
                workout_order,
                exercise: set.exercise,
                target_reps: set.target_reps,
                target_weight: set.target_weight,
                warmup: set.warmup,
            });
        }

        if !result.is_empty() {
            let query_sql = format!(
                "INSERT INTO proposed_sets (id, workout_id, workout_order, exercise, target_reps, target_weight, warmup) VALUES {}",
                values_placeholders.join(", ")
            );

            sqlx::query_with(&query_sql, args)
                .execute(&mut *tx)
                .await?;
        }

        tx.commit().await?;
        Ok(result)
    }

    pub async fn start_set(&self, workout_id: &str, proposed_set_id: &str) -> Result<CompletedSet, Box<dyn std::error::Error + Send + Sync>> {
        let id = Uuid::new_v4().to_string();
        let started_at = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;

        let proposed: Option<ProposedSet> = sqlx::query(
            "SELECT id, workout_id, workout_order, exercise, target_reps, target_weight, warmup FROM proposed_sets WHERE id = ?"
        )
        .bind(proposed_set_id)
        .map(row_to_proposed_set)
        .fetch_optional(&self.pool)
        .await?;

        let (actual_reps, actual_weight) = proposed
            .map(|p| (p.target_reps, p.target_weight))
            .unwrap_or((0, 0.0));

        sqlx::query(
            "INSERT INTO completed_sets (id, workout_id, proposed_set_id, actual_reps, actual_weight, started_at, ended_at, rest_until)
             VALUES (?, ?, ?, ?, ?, ?, 0, NULL)"
        )
        .bind(&id)
        .bind(workout_id)
        .bind(proposed_set_id)
        .bind(actual_reps)
        .bind(actual_weight)
        .bind(started_at)
        .execute(&self.pool)
        .await?;

        Ok(CompletedSet {
            id,
            workout_id: workout_id.to_string(),
            proposed_set_id: proposed_set_id.to_string(),
            actual_reps,
            actual_weight,
            started_at,
            ended_at: 0,
            rest_until: 0,
        })
    }

    pub async fn complete_set(
        &self,
        workout_id: &str,
        proposed_set_id: &str,
        actual_reps: i32,
        actual_weight: f32,
    ) -> Result<CompletedSet, Box<dyn std::error::Error + Send + Sync>> {
        let ended_at = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;

        // Look up target_reps, warmup flag, exercise, and workout_order to compute rest
        let proposed_info: Option<(i32, bool, i32, i32)> = sqlx::query_as(
            "SELECT target_reps, warmup, exercise, workout_order FROM proposed_sets WHERE id = ?"
        )
        .bind(proposed_set_id)
        .fetch_optional(&self.pool)
        .await?;

        let (target_reps, warmup, exercise, workout_order) = proposed_info.unwrap_or((0, false, 0, 0));

        // Check if this is the last warmup in its exercise group:
        // the next set (by workout_order) is either not a warmup or a different exercise.
        let last_warmup = if warmup {
            let next: Option<(bool, i32)> = sqlx::query_as(
                "SELECT warmup, exercise FROM proposed_sets WHERE workout_id = ? AND workout_order > ? ORDER BY workout_order ASC LIMIT 1"
            )
            .bind(workout_id)
            .bind(workout_order)
            .fetch_optional(&self.pool)
            .await?;
            match next {
                Some((true, ex)) if ex == exercise => false, // more warmups in this group
                _ => true, // last warmup (next is working set, different exercise, or no next set)
            }
        } else {
            false
        };

        let rest_seconds = compute_rest_seconds(target_reps, actual_reps, warmup, last_warmup);
        let rest_until = ended_at + rest_seconds;

        let existing: Option<(String, i64)> = sqlx::query_as(
            "SELECT id, started_at FROM completed_sets WHERE workout_id = ? AND proposed_set_id = ? AND ended_at = 0"
        )
        .bind(workout_id)
        .bind(proposed_set_id)
        .fetch_optional(&self.pool)
        .await?;

        let (id, started_at) = if let Some((existing_id, existing_started)) = existing {
            sqlx::query(
                "UPDATE completed_sets SET actual_reps = ?, actual_weight = ?, ended_at = ?, rest_until = ? WHERE id = ?"
            )
            .bind(actual_reps)
            .bind(actual_weight)
            .bind(ended_at)
            .bind(rest_until)
            .bind(&existing_id)
            .execute(&self.pool)
            .await?;

            (existing_id, existing_started)
        } else {
            let id = Uuid::new_v4().to_string();

            sqlx::query(
                "INSERT INTO completed_sets (id, workout_id, proposed_set_id, actual_reps, actual_weight, started_at, ended_at, rest_until)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
            )
            .bind(&id)
            .bind(workout_id)
            .bind(proposed_set_id)
            .bind(actual_reps)
            .bind(actual_weight)
            .bind(ended_at)
            .bind(ended_at)
            .bind(rest_until)
            .execute(&self.pool)
            .await?;

            (id, ended_at)
        };

        Ok(CompletedSet {
            id,
            workout_id: workout_id.to_string(),
            proposed_set_id: proposed_set_id.to_string(),
            actual_reps,
            actual_weight,
            started_at,
            ended_at,
            rest_until,
        })
    }

    pub async fn end_workout(&self, workout_id: &str) -> Result<Option<Workout>, Box<dyn std::error::Error + Send + Sync>> {
        let end_time = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;

        sqlx::query("UPDATE workouts SET end_time = ? WHERE id = ?")
            .bind(end_time)
            .bind(workout_id)
            .execute(&self.pool)
            .await?;

        self.get_workout(workout_id).await
    }

    pub async fn add_session(&self, session_id: &str, is_active: bool) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if is_active {
            sqlx::query("UPDATE user_sessions SET is_active = 0").execute(&self.pool).await?;
        }
        sqlx::query("INSERT OR REPLACE INTO user_sessions (session_id, is_active) VALUES (?, ?)")
            .bind(session_id)
            .bind(is_active)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn get_active_session(&self) -> Result<Option<String>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query_scalar("SELECT session_id FROM user_sessions WHERE is_active = 1")
            .fetch_optional(&self.pool)
            .await?)
    }

    pub async fn deactivate_all_sessions(&self) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        println!("Deactivating all sessions for user");
        sqlx::query("UPDATE user_sessions SET is_active = 0").execute(&self.pool).await?;
        Ok(())
    }
}

#[derive(Clone)]
pub struct CentralDb {
    pub pool: Pool<Sqlite>,
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
        let data_dir = "user_dbs";
        if !Path::new(data_dir).exists() {
            fs::create_dir(data_dir)?;
        }

        let db_path = format!("{}/central.sqlite", data_dir);
        let db_url = format!("sqlite://{}", db_path);

        let options = SqliteConnectOptions::from_str(&db_url)?.create_if_missing(true);
        let pool = SqlitePoolOptions::new().connect_with(options).await?;
        sqlx::query(CENTRAL_SCHEMA).execute(&pool).await?;

        Ok(Self { pool })
    }

    pub async fn create_user(&self, name: &str) -> Result<User, Box<dyn std::error::Error + Send + Sync>> {
        let existing = self.get_user_by_name(name).await?;
        if let Some(user) = existing {
            return Ok(user);
        }

        let id = Uuid::new_v4().to_string();
        let created_at = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;

        sqlx::query("INSERT INTO users (id, name, created_at) VALUES (?, ?, ?)")
            .bind(&id)
            .bind(name)
            .bind(created_at)
            .execute(&self.pool)
            .await?;

        UserDb::new(&id).await?;

        Ok(User { id, name: name.to_string(), created_at })
    }

    pub async fn get_user(&self, user_id: &str) -> Result<Option<User>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query("SELECT id, name, created_at FROM users WHERE id = ?")
            .bind(user_id)
            .map(row_to_user)
            .fetch_optional(&self.pool)
            .await?)
    }

    pub async fn get_user_by_name(&self, name: &str) -> Result<Option<User>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query("SELECT id, name, created_at FROM users WHERE name = ?")
            .bind(name)
            .map(row_to_user)
            .fetch_optional(&self.pool)
            .await?)
    }

    pub async fn join_session(&self, user_id: &str, session_id: &str, workout_id: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let now = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;
        sqlx::query("INSERT OR REPLACE INTO active_sessions (user_id, session_id, workout_id, joined_at) VALUES (?, ?, ?, ?)")
            .bind(user_id)
            .bind(session_id)
            .bind(workout_id)
            .bind(now)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn leave_session(&self, user_id: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        sqlx::query("DELETE FROM active_sessions WHERE user_id = ?")
            .bind(user_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn get_session_id(&self, user_id: &str) -> Result<Option<String>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query_scalar("SELECT session_id FROM active_sessions WHERE user_id = ?")
            .bind(user_id)
            .fetch_optional(&self.pool)
            .await?)
    }

    pub async fn get_session_participants(&self, session_id: &str) -> Result<Vec<(String, String)>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query_as("SELECT user_id, workout_id FROM active_sessions WHERE session_id = ?")
            .bind(session_id)
            .fetch_all(&self.pool)
            .await?)
    }

    pub async fn store_credential(&self, credential_id: &str, user_id: &str, credential_json: &str) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let created_at = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;
        sqlx::query("INSERT OR REPLACE INTO passkey_credentials (credential_id, user_id, credential_json, created_at) VALUES (?, ?, ?, ?)")
            .bind(credential_id)
            .bind(user_id)
            .bind(credential_json)
            .bind(created_at)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn get_credentials_for_user(&self, user_id: &str) -> Result<Vec<String>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query_scalar("SELECT credential_json FROM passkey_credentials WHERE user_id = ?")
            .bind(user_id)
            .fetch_all(&self.pool)
            .await?)
    }

    pub async fn get_all_credentials(&self) -> Result<Vec<(String, String)>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(sqlx::query_as("SELECT user_id, credential_json FROM passkey_credentials")
            .fetch_all(&self.pool)
            .await?)
    }

    pub async fn create_auth_session(&self, user_id: &str) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
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
        Ok(token)
    }

    pub async fn validate_auth_session(&self, token: &str) -> Result<Option<String>, Box<dyn std::error::Error + Send + Sync>> {
        let now = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;
        Ok(sqlx::query_scalar("SELECT user_id FROM auth_sessions WHERE token = ? AND expires_at > ?")
            .bind(token)
            .bind(now)
            .fetch_optional(&self.pool)
            .await?)
    }
}
