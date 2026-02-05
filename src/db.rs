use sqlx::{sqlite::{SqliteConnectOptions, SqlitePoolOptions}, Pool, Sqlite};
use std::str::FromStr;
use std::path::Path;
use std::fs;
use uuid::Uuid;
use std::time::{SystemTime, UNIX_EPOCH};
use lift::workout::v1::Workout;

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
    pub async fn new(user_id: &str) -> Result<Self, Box<dyn std::error::Error>> {
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

    pub async fn create_workout(&self) -> Result<Workout, Box<dyn std::error::Error>> {
        let id = Uuid::new_v4().to_string();
        let start_time = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;

        // Insert into SQLite
        sqlx::query(
            "INSERT INTO workouts (id, start_time, end_time) VALUES (?, ?, NULL)"
        )
        .bind(&id)
        .bind(start_time)
        .execute(&self.pool)
        .await?;

        // Return the proto object
        Ok(Workout {
            id,
            start_time,
            end_time: 0, 
        })
    }
}