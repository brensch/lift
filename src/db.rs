use sqlx::{sqlite::{SqliteConnectOptions, SqlitePoolOptions}, Pool, Sqlite, Row};
use std::str::FromStr;
use std::path::Path;
use std::fs;
use uuid::Uuid;
use std::time::{SystemTime, UNIX_EPOCH};
use lift::workout::v1::{Workout, ProposedSet, CompletedSet, User};

// Define the database schema as a raw SQL string
const SCHEMA: &str = r#"
-- Tables
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS workouts (
    id TEXT PRIMARY KEY,
    start_time INTEGER NOT NULL,
    end_time INTEGER
);

CREATE TABLE IF NOT EXISTS proposed_sets (
    id TEXT PRIMARY KEY,
    workout_id TEXT NOT NULL,
    workout_order INTEGER NOT NULL,
    exercise TEXT NOT NULL,
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

-- Indexes
-- Optimize looking up sets by workout (crucial for loading a workout)
CREATE INDEX IF NOT EXISTS idx_proposed_sets_workout_id ON proposed_sets(workout_id);
CREATE INDEX IF NOT EXISTS idx_completed_sets_workout_id ON completed_sets(workout_id);

-- Optimize joining completed sets to their plan
CREATE INDEX IF NOT EXISTS idx_completed_sets_proposed_id ON completed_sets(proposed_set_id);

-- Optimize sorting workouts by date (for history view)
CREATE INDEX IF NOT EXISTS idx_workouts_start_time ON workouts(start_time DESC);
"#;

pub struct UserDb {
    pub pool: Pool<Sqlite>,
}

impl UserDb {
    /// Connects to a specific user's database.
    /// If the file doesn't exist, it creates it and runs the schema.
    pub async fn new(user_id: &str) -> Result<Self, Box<dyn std::error::Error + Send + Sync>> {
        // Ensure the "data" directory exists
        let data_dir = "user_dbs";
        if !Path::new(data_dir).exists() {
            fs::create_dir(data_dir)?;
        }

        let db_path = format!("{}/{}.sqlite", data_dir, user_id);
        let db_url = format!("sqlite://{}", db_path);
        
        // This option allows creating the DB file if it's missing
        let options = SqliteConnectOptions::from_str(&db_url)?
            .create_if_missing(true);

        let pool = SqlitePoolOptions::new()
            .connect_with(options)
            .await?;

        // Run the schema migration
        sqlx::query(SCHEMA).execute(&pool).await?;

        Ok(Self { pool })
    }

    pub async fn create_workout(&self, proposed_sets: Vec<ProposedSet>) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
        let workout_id = Uuid::new_v4().to_string();
        let start_time = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;

        // Insert workout
        sqlx::query("INSERT INTO workouts (id, start_time, end_time) VALUES (?, ?, NULL)")
            .bind(&workout_id)
            .bind(start_time)
            .execute(&self.pool)
            .await?;

        // Insert proposed sets
        for set in proposed_sets {
            let set_id = if set.id.is_empty() {
                Uuid::new_v4().to_string()
            } else {
                set.id
            };
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
        let row = sqlx::query("SELECT id, start_time, end_time FROM workouts WHERE id = ?")
            .bind(workout_id)
            .fetch_optional(&self.pool)
            .await?;

        Ok(row.map(|r| Workout {
            id: r.get("id"),
            start_time: r.get("start_time"),
            end_time: r.get::<Option<i64>, _>("end_time").unwrap_or(0),
        }))
    }

    pub async fn get_proposed_sets(&self, workout_id: &str) -> Result<Vec<ProposedSet>, Box<dyn std::error::Error + Send + Sync>> {
        let rows = sqlx::query(
            "SELECT id, workout_id, workout_order, exercise, target_reps, target_weight, warmup
             FROM proposed_sets WHERE workout_id = ? ORDER BY workout_order"
        )
        .bind(workout_id)
        .fetch_all(&self.pool)
        .await?;

        Ok(rows.into_iter().map(|r| ProposedSet {
            id: r.get("id"),
            workout_id: r.get("workout_id"),
            workout_order: r.get("workout_order"),
            exercise: r.get::<i32, _>("exercise"),
            target_reps: r.get("target_reps"),
            target_weight: r.get("target_weight"),
            warmup: r.get("warmup"),
        }).collect())
    }

    pub async fn get_completed_sets(&self, workout_id: &str) -> Result<Vec<CompletedSet>, Box<dyn std::error::Error + Send + Sync>> {
        let rows = sqlx::query(
            "SELECT id, workout_id, proposed_set_id, actual_reps, actual_weight, started_at, ended_at, rest_until
             FROM completed_sets WHERE workout_id = ? ORDER BY started_at"
        )
        .bind(workout_id)
        .fetch_all(&self.pool)
        .await?;

        Ok(rows.into_iter().map(|r| CompletedSet {
            id: r.get("id"),
            workout_id: r.get("workout_id"),
            proposed_set_id: r.get::<Option<String>, _>("proposed_set_id").unwrap_or_default(),
            actual_reps: r.get("actual_reps"),
            actual_weight: r.get("actual_weight"),
            started_at: r.get("started_at"),
            ended_at: r.get("ended_at"),
            rest_until: r.get::<Option<i64>, _>("rest_until").unwrap_or(0),
        }).collect())
    }

    pub async fn list_workouts(&self) -> Result<Vec<Workout>, Box<dyn std::error::Error + Send + Sync>> {
        let rows = sqlx::query("SELECT id, start_time, end_time FROM workouts ORDER BY start_time DESC")
            .fetch_all(&self.pool)
            .await?;

        Ok(rows.into_iter().map(|r| Workout {
            id: r.get("id"),
            start_time: r.get("start_time"),
            end_time: r.get::<Option<i64>, _>("end_time").unwrap_or(0),
        }).collect())
    }

    pub async fn modify_proposed_sets(&self, workout_id: &str, proposed_sets: Vec<ProposedSet>) -> Result<Vec<ProposedSet>, Box<dyn std::error::Error + Send + Sync>> {
        // Delete existing proposed sets for this workout
        sqlx::query("DELETE FROM proposed_sets WHERE workout_id = ?")
            .bind(workout_id)
            .execute(&self.pool)
            .await?;

        // Insert new proposed sets
        let mut result = Vec::new();
        for (idx, set) in proposed_sets.into_iter().enumerate() {
            let set_id = if set.id.is_empty() {
                Uuid::new_v4().to_string()
            } else {
                set.id
            };
            let workout_order = if set.workout_order == 0 { idx as i32 } else { set.workout_order };

            sqlx::query(
                "INSERT INTO proposed_sets (id, workout_id, workout_order, exercise, target_reps, target_weight, warmup)
                 VALUES (?, ?, ?, ?, ?, ?, ?)"
            )
            .bind(&set_id)
            .bind(workout_id)
            .bind(workout_order)
            .bind(set.exercise)
            .bind(set.target_reps)
            .bind(set.target_weight)
            .bind(set.warmup)
            .execute(&self.pool)
            .await?;

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

        Ok(result)
    }

    pub async fn start_set(&self, workout_id: &str, proposed_set_id: &str) -> Result<CompletedSet, Box<dyn std::error::Error + Send + Sync>> {
        let id = Uuid::new_v4().to_string();
        let started_at = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;

        // Get the proposed set to copy target values
        let proposed = sqlx::query(
            "SELECT target_reps, target_weight FROM proposed_sets WHERE id = ?"
        )
        .bind(proposed_set_id)
        .fetch_optional(&self.pool)
        .await?;

        let (actual_reps, actual_weight) = match proposed {
            Some(row) => (row.get::<i32, _>("target_reps"), row.get::<f32, _>("target_weight")),
            None => (0, 0.0),
        };

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
        rest_seconds: i32,
    ) -> Result<CompletedSet, Box<dyn std::error::Error + Send + Sync>> {
        let ended_at = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;
        let rest_until = ended_at + rest_seconds as i64;

        // Try to find an in-progress set (ended_at = 0)
        let existing = sqlx::query(
            "SELECT id, started_at FROM completed_sets WHERE workout_id = ? AND proposed_set_id = ? AND ended_at = 0"
        )
        .bind(workout_id)
        .bind(proposed_set_id)
        .fetch_optional(&self.pool)
        .await?;

        let (id, started_at) = if let Some(row) = existing {
            // Update existing set
            let id: String = row.get("id");
            let started_at: i64 = row.get("started_at");

            sqlx::query(
                "UPDATE completed_sets SET actual_reps = ?, actual_weight = ?, ended_at = ?, rest_until = ? WHERE id = ?"
            )
            .bind(actual_reps)
            .bind(actual_weight)
            .bind(ended_at)
            .bind(rest_until)
            .bind(&id)
            .execute(&self.pool)
            .await?;

            (id, started_at)
        } else {
            // Create new completed set
            let id = Uuid::new_v4().to_string();
            let started_at = ended_at; // Set started_at to now if no in-progress set

            sqlx::query(
                "INSERT INTO completed_sets (id, workout_id, proposed_set_id, actual_reps, actual_weight, started_at, ended_at, rest_until)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
            )
            .bind(&id)
            .bind(workout_id)
            .bind(proposed_set_id)
            .bind(actual_reps)
            .bind(actual_weight)
            .bind(started_at)
            .bind(ended_at)
            .bind(rest_until)
            .execute(&self.pool)
            .await?;

            (id, started_at)
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
}

// Central database for users
pub struct CentralDb {
    pub pool: Pool<Sqlite>,
}

const CENTRAL_SCHEMA: &str = r#"
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL
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

        let options = SqliteConnectOptions::from_str(&db_url)?
            .create_if_missing(true);

        let pool = SqlitePoolOptions::new()
            .connect_with(options)
            .await?;

        sqlx::query(CENTRAL_SCHEMA).execute(&pool).await?;

        Ok(Self { pool })
    }

    pub async fn create_user(&self, name: &str) -> Result<User, Box<dyn std::error::Error + Send + Sync>> {
        let id = Uuid::new_v4().to_string();
        let created_at = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;

        sqlx::query("INSERT INTO users (id, name, created_at) VALUES (?, ?, ?)")
            .bind(&id)
            .bind(name)
            .bind(created_at)
            .execute(&self.pool)
            .await?;

        // Also create the user's database
        UserDb::new(&id).await?;

        Ok(User {
            id,
            name: name.to_string(),
            created_at,
        })
    }

    pub async fn get_user(&self, user_id: &str) -> Result<Option<User>, Box<dyn std::error::Error + Send + Sync>> {
        let row = sqlx::query("SELECT id, name, created_at FROM users WHERE id = ?")
            .bind(user_id)
            .fetch_optional(&self.pool)
            .await?;

        Ok(row.map(|r| User {
            id: r.get("id"),
            name: r.get("name"),
            created_at: r.get("created_at"),
        }))
    }
}