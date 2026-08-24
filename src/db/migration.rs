//! The one-time cutover from the program-state world to trackers and
//! templates. Runs at startup, guarded by a `schema_migrations` marker.
//!
//! The promise: **no user loses a working weight.** Trackers seed from
//! workout history first (what the user actually lifted, replayed through
//! the progression rule); program state fills in main lifts with no
//! history. Templates come from the user's saved groups, their most
//! recent workout, and the six defaults.
//!
//! The old program-state blob is decoded with local prost structs — the
//! proto messages are deleted, but the wire format is stable, and this
//! module is the only place that still needs to read it.

use prost::Message;
use sqlx::{Pool, Row, Sqlite};
use std::collections::HashMap;
use uuid::Uuid;

use super::codec::decode_exercise_configs;
use super::DbResult;
use crate::exercise_catalog::snap_weight_lb;
use crate::exercise_progress::{derive_trackers_from_history, TrackerState};
use crate::history::WorkoutRecord;
use crate::time::now_unix;
use crate::weight_units::{unit_from_proto, AppWeightUnit};
use schlift::workout::v1::{
    user_setting, CompletedSet, Exercise, ProposedSet, UserSetting, Workout, WorkoutTemplate,
};

const MIGRATION_NAME: &str = "composable_workouts_v1";
/// Enough history to land the derivation on the current weight; migration
/// does not need a user's whole life story.
const HISTORY_CAP: i64 = 50;

// ── Legacy program-state decoding ────────────────────────────────────────────
// Field numbers mirror the deleted settings.proto messages:
// GetActiveTrainingProgramStateResponse.state = 1;
// TrainingProgramState.fields = 2 (map<string, StateFieldValue>);
// StateFieldValue oneof: int_val = 1, float_val = 2.

#[derive(Clone, PartialEq, Message)]
struct LegacyStateResponse {
    #[prost(message, optional, tag = "1")]
    state: Option<LegacyProgramState>,
}

#[derive(Clone, PartialEq, Message)]
struct LegacyProgramState {
    #[prost(int32, tag = "1")]
    regime_type: i32,
    #[prost(map = "string, message", tag = "2")]
    fields: HashMap<String, LegacyFieldValue>,
}

#[derive(Clone, PartialEq, Message)]
struct LegacyFieldValue {
    #[prost(oneof = "legacy_value::Value", tags = "1, 2, 3, 4")]
    value: Option<legacy_value::Value>,
}

mod legacy_value {
    // Named to mirror the deleted proto oneof members exactly.
    #[allow(clippy::enum_variant_names)]
    #[derive(Clone, PartialEq, prost::Oneof)]
    pub enum Value {
        #[prost(int64, tag = "1")]
        IntVal(i64),
        #[prost(double, tag = "2")]
        FloatVal(f64),
        #[prost(bool, tag = "3")]
        BoolVal(bool),
        #[prost(string, tag = "4")]
        StringVal(String),
    }
}

fn numeric(state: &LegacyProgramState, key: &str) -> Option<f32> {
    match state.fields.get(key)?.value.as_ref()? {
        legacy_value::Value::FloatVal(v) => Some(*v as f32),
        legacy_value::Value::IntVal(v) => Some(*v as f32),
        _ => None,
    }
}

/// The best weight the old program state knows for one lift, whichever
/// regime wrote it. A user has exactly one regime, so at most one family
/// of keys is present; taking the best of what exists is regime-agnostic.
/// Wendler stores a training max, which is above the working weight — the
/// classic 5/3/1 top set is ~85% of TM.
fn legacy_weight(state: &LegacyProgramState, lift: &str) -> Option<f32> {
    let direct = numeric(state, &format!("{lift}_weight"));
    let t1 = numeric(state, &format!("{lift}_t1_weight"));
    let t2 = numeric(state, &format!("{lift}_t2_weight"));
    let tm = numeric(state, &format!("{lift}_tm")).map(|tm| tm * 0.85);
    [direct, t1, t2, tm]
        .into_iter()
        .flatten()
        .filter(|w| *w > 0.0)
        .fold(None, |best: Option<f32>, w| {
            Some(best.map_or(w, |b| b.max(w)))
        })
}

const MAIN_LIFTS: [(Exercise, &str); 5] = [
    (Exercise::Squat, "squat"),
    (Exercise::BenchPress, "bench_press"),
    (Exercise::Deadlift, "deadlift"),
    (Exercise::OverheadPress, "overhead_press"),
    (Exercise::BarbellRow, "barbell_row"),
];

/// The six default templates, exercises only. Barbell, dumbbell and
/// bodyweight moves — startable at a rack without hunting for machines.
pub fn default_templates() -> Vec<(&'static str, Vec<Exercise>)> {
    use Exercise as E;
    vec![
        (
            "Full Body",
            vec![E::Squat, E::BenchPress, E::BarbellRow, E::DumbbellShoulderPress, E::BarbellCurl],
        ),
        (
            "Upper",
            vec![E::BenchPress, E::BarbellRow, E::OverheadPress, E::ChinUp, E::DumbbellCurl, E::SkullCrusher],
        ),
        (
            "Lower",
            vec![E::Squat, E::RomanianDeadlift, E::HipThrust, E::CalfRaise, E::Crunch],
        ),
        (
            "Push",
            vec![E::BenchPress, E::OverheadPress, E::InclineDumbbellPress, E::LateralRaise, E::SkullCrusher],
        ),
        (
            "Pull",
            vec![E::BarbellRow, E::PullUp, E::DumbbellRow, E::RearDeltFly, E::BarbellCurl],
        ),
        (
            "Legs",
            vec![E::Squat, E::RomanianDeadlift, E::Lunge, E::CalfRaise, E::HangingLegRaise],
        ),
    ]
}

pub(super) async fn run(pool: &Pool<Sqlite>) -> DbResult<()> {
    let applied: Option<(String,)> =
        sqlx::query_as("SELECT name FROM schema_migrations WHERE name = ?")
            .bind(MIGRATION_NAME)
            .fetch_optional(pool)
            .await?;
    if applied.is_some() {
        return Ok(());
    }

    // Column adjustments first — idempotent, and everything below reads
    // the tables with explicit column lists.
    if !column_exists(pool, "workouts", "template_id").await? {
        sqlx::query("ALTER TABLE workouts ADD COLUMN template_id TEXT NOT NULL DEFAULT ''")
            .execute(pool)
            .await?;
    }
    if column_exists(pool, "exercise_groups", "prescribed_by_regime").await? {
        sqlx::query("ALTER TABLE exercise_groups DROP COLUMN prescribed_by_regime")
            .execute(pool)
            .await?;
    }
    if column_exists(pool, "proposed_sets", "progression_blob").await? {
        sqlx::query("ALTER TABLE proposed_sets DROP COLUMN progression_blob")
            .execute(pool)
            .await?;
    }

    // An old database is one that has the program-state table. A fresh
    // database has nothing to convert.
    if table_exists(pool, "training_program_state_latest").await? {
        migrate_users(pool).await?;
        if table_exists(pool, "program_progression_applied").await? {
            sqlx::query(
                "INSERT OR IGNORE INTO progression_applied (workout_id, user_id, applied_at)
                 SELECT workout_id, user_id, applied_at FROM program_progression_applied",
            )
            .execute(pool)
            .await?;
        }
    }

    for table in [
        "training_program_state_latest",
        "proposed_schedule_cache",
        "workout_drafts_current",
        "profile_exercise_groups",
        "workout_events",
        "program_progression_applied",
        "t_workouts",
        "t_blocks",
        "t_sets",
        "t_entries",
        "t_progression",
    ] {
        sqlx::query(&format!("DROP TABLE IF EXISTS {table}"))
            .execute(pool)
            .await?;
    }

    sqlx::query("INSERT INTO schema_migrations (name, applied_at) VALUES (?, ?)")
        .bind(MIGRATION_NAME)
        .bind(now_unix())
        .execute(pool)
        .await?;
    Ok(())
}

async fn table_exists(pool: &Pool<Sqlite>, table: &str) -> DbResult<bool> {
    let row: (i64,) =
        sqlx::query_as("SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = ?")
            .bind(table)
            .fetch_one(pool)
            .await?;
    Ok(row.0 > 0)
}

async fn column_exists(pool: &Pool<Sqlite>, table: &str, column: &str) -> DbResult<bool> {
    let row: (i64,) = sqlx::query_as(&format!(
        "SELECT COUNT(*) FROM pragma_table_info('{table}') WHERE name = ?"
    ))
    .bind(column)
    .fetch_one(pool)
    .await?;
    Ok(row.0 > 0)
}

async fn migrate_users(pool: &Pool<Sqlite>) -> DbResult<()> {
    let users: Vec<(String,)> = sqlx::query_as("SELECT user_id FROM users_current")
        .fetch_all(pool)
        .await?;
    for (user_id,) in users {
        migrate_one_user(pool, &user_id).await?;
    }
    Ok(())
}

async fn migrate_one_user(pool: &Pool<Sqlite>, user_id: &str) -> DbResult<()> {
    let unit = load_weight_unit(pool, user_id).await?;
    let history = load_history(pool, user_id).await?;
    let now = now_unix();

    // 1. Trackers from what the user actually did.
    let mut trackers: HashMap<i32, TrackerState> = derive_trackers_from_history(&history, unit);

    // 2. Program state fills main lifts with no history. History wins:
    //    it is what the user did; state is what a program planned.
    if let Some(state) = load_legacy_state(pool, user_id).await? {
        for (exercise, key) in MAIN_LIFTS {
            let entry = trackers.entry(exercise as i32).or_default();
            if entry.working_weight <= 0.0 {
                if let Some(weight) = legacy_weight(&state, key) {
                    entry.working_weight = snap_weight_lb(exercise, weight, unit);
                }
            }
        }
    }

    for (exercise, state) in &trackers {
        if state.working_weight <= 0.0 && state.last_performed_at == 0 {
            continue;
        }
        sqlx::query(
            "INSERT OR REPLACE INTO exercise_trackers
             (user_id, exercise, working_weight, current_reps, consecutive_misses,
              last_performed_at, updated_at, source)
             VALUES (?, ?, ?, ?, ?, ?, ?, 'migration')",
        )
        .bind(user_id)
        .bind(exercise)
        .bind(state.working_weight)
        .bind(state.current_reps)
        .bind(state.consecutive_misses)
        .bind(state.last_performed_at)
        .bind(now)
        .execute(pool)
        .await?;
    }

    // 3. Templates: saved groups, the last workout, then the defaults.
    let mut order = 0i32;
    let mut names: Vec<String> = Vec::new();

    for (name, exercises) in load_profile_group_templates(pool, user_id).await? {
        insert_template(pool, user_id, &name, &exercises, order, now).await?;
        names.push(name.to_lowercase());
        order += 1;
    }

    if let Some((name, exercises)) = last_workout_template(&history) {
        if !names.contains(&name.to_lowercase()) && !exercises.is_empty() {
            insert_template(pool, user_id, &name, &exercises, order, now).await?;
            names.push(name.to_lowercase());
            order += 1;
        }
    }

    for (name, exercises) in default_templates() {
        if names.contains(&name.to_lowercase()) {
            continue;
        }
        let exercises: Vec<i32> = exercises.into_iter().map(|e| e as i32).collect();
        insert_template(pool, user_id, name, &exercises, order, now).await?;
        names.push(name.to_lowercase());
        order += 1;
    }

    Ok(())
}

async fn insert_template(
    pool: &Pool<Sqlite>,
    user_id: &str,
    name: &str,
    exercises: &[i32],
    order: i32,
    now: i64,
) -> DbResult<()> {
    let id = Uuid::new_v4().to_string();
    let template = WorkoutTemplate {
        id: id.clone(),
        name: name.to_string(),
        order,
        exercises: exercises.to_vec(),
        created_at: now,
        updated_at: now,
    };
    sqlx::query(
        "INSERT INTO workout_templates
         (id, user_id, name, template_order, template_blob, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(&id)
    .bind(user_id)
    .bind(name)
    .bind(order)
    .bind(template.encode_to_vec())
    .bind(now)
    .bind(now)
    .execute(pool)
    .await?;
    Ok(())
}

async fn load_weight_unit(pool: &Pool<Sqlite>, user_id: &str) -> DbResult<AppWeightUnit> {
    let row: Option<(Vec<u8>,)> = sqlx::query_as(
        "SELECT setting_blob FROM user_settings_current
         WHERE user_id = ? AND setting_type = 'weight_unit'",
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await?;
    Ok(match row {
        Some((blob,)) => match UserSetting::decode(blob.as_slice()) {
            Ok(UserSetting {
                setting: Some(user_setting::Setting::WeightUnit(config)),
            }) => unit_from_proto(config.unit),
            _ => AppWeightUnit::Lb,
        },
        None => AppWeightUnit::Lb,
    })
}

async fn load_legacy_state(
    pool: &Pool<Sqlite>,
    user_id: &str,
) -> DbResult<Option<LegacyProgramState>> {
    let row: Option<(Vec<u8>,)> = sqlx::query_as(
        "SELECT response_blob FROM training_program_state_latest WHERE user_id = ?",
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await?;
    Ok(row
        .and_then(|(blob,)| LegacyStateResponse::decode(blob.as_slice()).ok())
        .and_then(|response| response.state))
}

async fn load_history(pool: &Pool<Sqlite>, user_id: &str) -> DbResult<Vec<WorkoutRecord>> {
    let workouts: Vec<Workout> = sqlx::query(
        "SELECT id, name, start_time, end_time, session_id FROM workouts
         WHERE user_id = ? ORDER BY start_time DESC LIMIT ?",
    )
    .bind(user_id)
    .bind(HISTORY_CAP)
    .fetch_all(pool)
    .await?
    .into_iter()
    .map(|row| Workout {
        id: row.get(0),
        name: row.get(1),
        start_time: row.get(2),
        end_time: row.get(3),
        session_id: row.get(4),
    })
    .collect();

    let mut records = Vec::with_capacity(workouts.len());
    for workout in workouts {
        let proposed_sets: Vec<ProposedSet> = sqlx::query(
            "SELECT id, workout_order, exercise, target_reps, target_weight, warmup, cancelled,
                    exercise_group_id
             FROM proposed_sets WHERE workout_id = ? ORDER BY workout_order",
        )
        .bind(&workout.id)
        .fetch_all(pool)
        .await?
        .into_iter()
        .map(|row| ProposedSet {
            id: row.get(0),
            workout_id: workout.id.clone(),
            workout_order: row.get(1),
            exercise: row.get(2),
            target_reps: row.get(3),
            target_weight: row.get(4),
            warmup: row.get::<i64, _>(5) != 0,
            cancelled: row.get::<i64, _>(6) != 0,
            exercise_group_id: row.get(7),
            ..Default::default()
        })
        .collect();

        let completed_sets: Vec<CompletedSet> = sqlx::query(
            "SELECT id, proposed_set_id, actual_reps, actual_weight, started_at, ended_at
             FROM completed_sets WHERE workout_id = ?",
        )
        .bind(&workout.id)
        .fetch_all(pool)
        .await?
        .into_iter()
        .map(|row| CompletedSet {
            id: row.get(0),
            workout_id: workout.id.clone(),
            proposed_set_id: row.get(1),
            actual_reps: row.get(2),
            actual_weight: row.get(3),
            started_at: row.get(4),
            ended_at: row.get(5),
            rest_until: 0,
        })
        .collect();

        records.push(WorkoutRecord {
            workout,
            exercise_groups: Vec::new(),
            proposed_sets,
            completed_sets,
        });
    }
    Ok(records)
}

/// Saved profile groups → (name, ordered distinct exercises).
async fn load_profile_group_templates(
    pool: &Pool<Sqlite>,
    user_id: &str,
) -> DbResult<Vec<(String, Vec<i32>)>> {
    if !table_exists(pool, "profile_exercise_groups").await? {
        return Ok(Vec::new());
    }
    let rows: Vec<(String, Option<Vec<u8>>)> = sqlx::query_as(
        "SELECT name, exercise_configs_blob FROM profile_exercise_groups
         WHERE user_id = ? ORDER BY profile_order",
    )
    .bind(user_id)
    .fetch_all(pool)
    .await?;
    Ok(rows
        .into_iter()
        .filter_map(|(name, blob)| {
            let configs = decode_exercise_configs(&blob.unwrap_or_default());
            let mut exercises: Vec<i32> = Vec::new();
            for config in configs {
                if !exercises.contains(&config.exercise) {
                    exercises.push(config.exercise);
                }
            }
            (!exercises.is_empty()).then_some((name, exercises))
        })
        .collect())
}

/// The most recent completed workout as a template — a migrated user
/// always has the session they actually do.
fn last_workout_template(history: &[WorkoutRecord]) -> Option<(String, Vec<i32>)> {
    let last = history
        .iter()
        .filter(|record| record.workout.end_time > 0)
        .max_by_key(|record| record.workout.end_time)?;
    let mut ordered: Vec<&ProposedSet> = last
        .proposed_sets
        .iter()
        .filter(|set| !set.warmup && !set.cancelled)
        .collect();
    ordered.sort_by_key(|set| set.workout_order);
    let mut exercises: Vec<i32> = Vec::new();
    for set in ordered {
        if !exercises.contains(&set.exercise) {
            exercises.push(set.exercise);
        }
    }
    let name = if last.workout.name.is_empty() {
        "My Workout".to_string()
    } else {
        last.workout.name.clone()
    };
    (!exercises.is_empty()).then_some((name, exercises))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::ServerDb;
    use sqlx::sqlite::SqlitePoolOptions;

    /// The old-world schema, as production ran it the day before the
    /// cutover — the migration's input contract. Only the tables the
    /// migration reads or drops.
    const OLD_SCHEMA: &str = r#"
    CREATE TABLE users_current (
        user_id TEXT PRIMARY KEY,
        user_blob BLOB NOT NULL,
        username_ci TEXT NOT NULL UNIQUE,
        invite_token TEXT NOT NULL UNIQUE
    );
    CREATE TABLE workouts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL DEFAULT '',
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL DEFAULT 0,
        session_id TEXT NOT NULL DEFAULT ''
    );
    CREATE TABLE exercise_groups (
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
    CREATE TABLE proposed_sets (
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
    CREATE TABLE completed_sets (
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
    CREATE TABLE user_settings_current (
        user_id TEXT NOT NULL,
        setting_type TEXT NOT NULL,
        setting_blob BLOB NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY(user_id, setting_type)
    );
    CREATE TABLE training_program_state_latest (
        user_id TEXT PRIMARY KEY,
        response_blob BLOB NOT NULL,
        updated_at INTEGER NOT NULL
    );
    CREATE TABLE program_progression_applied (
        workout_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        applied_at INTEGER NOT NULL
    );
    CREATE TABLE proposed_schedule_cache (
        user_id TEXT PRIMARY KEY,
        response_blob BLOB NOT NULL,
        updated_at INTEGER NOT NULL
    );
    CREATE TABLE workout_drafts_current (
        user_id TEXT PRIMARY KEY,
        draft_blob BLOB NOT NULL,
        updated_at INTEGER NOT NULL
    );
    CREATE TABLE workout_events (
        event_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        workout_id TEXT NOT NULL,
        recorded_at INTEGER NOT NULL,
        event_type INTEGER NOT NULL,
        payload BLOB NOT NULL
    );
    CREATE TABLE profile_exercise_groups (
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
    CREATE TABLE t_workouts (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, start_time INTEGER NOT NULL DEFAULT 0);
    "#;

    /// Build an old-world sqlite file in `dir`, run `seed` against it, then
    /// open it through `ServerDb::new_in_dir` — which applies the new schema
    /// and the migration exactly as a production restart would.
    async fn migrate_fixture<F, Fut>(seed: F) -> ServerDb
    where
        F: FnOnce(Pool<Sqlite>) -> Fut,
        Fut: std::future::Future<Output = ()>,
    {
        let dir = std::env::temp_dir().join(format!("lift-migration-test-{}", Uuid::new_v4()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = format!("sqlite://{}/server.sqlite?mode=rwc", dir.display());
        let pool = SqlitePoolOptions::new()
            .max_connections(1)
            .connect(&path)
            .await
            .unwrap();
        sqlx::query(OLD_SCHEMA).execute(&pool).await.unwrap();
        seed(pool.clone()).await;
        pool.close().await;
        ServerDb::new_in_dir(&dir).await.unwrap()
    }

    fn legacy_state_blob(regime_type: i32, fields: &[(&str, f64)]) -> Vec<u8> {
        let state = LegacyProgramState {
            regime_type,
            fields: fields
                .iter()
                .map(|(key, value)| {
                    (
                        key.to_string(),
                        LegacyFieldValue {
                            value: Some(legacy_value::Value::FloatVal(*value)),
                        },
                    )
                })
                .collect(),
        };
        LegacyStateResponse { state: Some(state) }.encode_to_vec()
    }

    async fn seed_user(pool: &Pool<Sqlite>, user_id: &str) {
        sqlx::query(
            "INSERT INTO users_current (user_id, user_blob, username_ci, invite_token)
             VALUES (?, x'00', ?, ?)",
        )
        .bind(user_id)
        .bind(format!("{user_id}-name"))
        .bind(format!("{user_id}-invite"))
        .execute(pool)
        .await
        .unwrap();
    }

    async fn seed_state(pool: &Pool<Sqlite>, user_id: &str, blob: Vec<u8>) {
        sqlx::query(
            "INSERT INTO training_program_state_latest (user_id, response_blob, updated_at)
             VALUES (?, ?, 1)",
        )
        .bind(user_id)
        .bind(blob)
        .execute(pool)
        .await
        .unwrap();
    }

    /// One finished workout: `sets` × (exercise, target, actual, weight).
    async fn seed_workout(
        pool: &Pool<Sqlite>,
        user_id: &str,
        workout_id: &str,
        at: i64,
        sets: &[(i32, i32, i32, f64)],
    ) {
        sqlx::query(
            "INSERT INTO workouts (id, user_id, name, start_time, end_time) VALUES (?, ?, 'W', ?, ?)",
        )
        .bind(workout_id)
        .bind(user_id)
        .bind(at - 3600)
        .bind(at)
        .execute(pool)
        .await
        .unwrap();
        for (i, (exercise, target, actual, weight)) in sets.iter().enumerate() {
            let set_id = format!("{workout_id}-s{i}");
            sqlx::query(
                "INSERT INTO proposed_sets (id, user_id, workout_id, exercise_group_id,
                 workout_order, exercise, target_reps, target_weight)
                 VALUES (?, ?, ?, 'g', ?, ?, ?, ?)",
            )
            .bind(&set_id)
            .bind(user_id)
            .bind(workout_id)
            .bind(i as i32)
            .bind(exercise)
            .bind(target)
            .bind(weight)
            .execute(pool)
            .await
            .unwrap();
            sqlx::query(
                "INSERT INTO completed_sets (id, user_id, workout_id, proposed_set_id,
                 actual_reps, actual_weight, started_at, ended_at)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            )
            .bind(format!("{workout_id}-c{i}"))
            .bind(user_id)
            .bind(workout_id)
            .bind(&set_id)
            .bind(actual)
            .bind(weight)
            .bind(at - 100 + i as i64)
            .bind(at - 50 + i as i64)
            .execute(pool)
            .await
            .unwrap();
        }
    }

    async fn tracker_weight(db: &ServerDb, user_id: &str, exercise: Exercise) -> Option<f32> {
        db.get_tracker_states(user_id)
            .await
            .unwrap()
            .get(&(exercise as i32))
            .map(|state| state.working_weight)
    }

    /// Linear 5x5 user: the stored working weight becomes the tracker.
    #[tokio::test]
    async fn linear_state_seeds_the_tracker() {
        let db = migrate_fixture(|pool| async move {
            seed_user(&pool, "u1").await;
            seed_state(
                &pool,
                "u1",
                legacy_state_blob(1, &[("squat_weight", 175.0), ("bench_press_weight", 135.0)]),
            )
            .await;
        })
        .await;
        assert_eq!(tracker_weight(&db, "u1", Exercise::Squat).await, Some(175.0));
        assert_eq!(
            tracker_weight(&db, "u1", Exercise::BenchPress).await,
            Some(135.0)
        );
    }

    /// Wendler user: the training max converts at 85%, snapped loadable.
    #[tokio::test]
    async fn wendler_tm_converts_to_a_working_weight() {
        let db = migrate_fixture(|pool| async move {
            seed_user(&pool, "u1").await;
            seed_state(&pool, "u1", legacy_state_blob(3, &[("squat_tm", 200.0)])).await;
        })
        .await;
        let expected = crate::exercise_catalog::snap_weight_lb(
            Exercise::Squat,
            170.0,
            AppWeightUnit::Lb,
        );
        assert_eq!(
            tracker_weight(&db, "u1", Exercise::Squat).await,
            Some(expected)
        );
    }

    /// GZCLP user: the heavier of T1/T2 wins for a lift with both.
    #[tokio::test]
    async fn gzclp_takes_the_heavier_tier() {
        let db = migrate_fixture(|pool| async move {
            seed_user(&pool, "u1").await;
            seed_state(
                &pool,
                "u1",
                legacy_state_blob(
                    2,
                    &[
                        ("squat_t1_weight", 185.0),
                        ("bench_press_t2_weight", 115.0),
                    ],
                ),
            )
            .await;
        })
        .await;
        assert_eq!(tracker_weight(&db, "u1", Exercise::Squat).await, Some(185.0));
        assert_eq!(
            tracker_weight(&db, "u1", Exercise::BenchPress).await,
            Some(115.0)
        );
    }

    /// History beats program state: what the user lifted wins over what a
    /// program planned. A cleared 5x5 at 185 derives to 190 even with 175
    /// in the state blob.
    #[tokio::test]
    async fn history_wins_over_program_state() {
        let db = migrate_fixture(|pool| async move {
            seed_user(&pool, "u1").await;
            seed_state(&pool, "u1", legacy_state_blob(1, &[("squat_weight", 175.0)])).await;
            let squat = Exercise::Squat as i32;
            seed_workout(
                &pool,
                "u1",
                "w1",
                1_000_000,
                &[(squat, 5, 5, 185.0), (squat, 5, 5, 185.0), (squat, 5, 5, 185.0)],
            )
            .await;
        })
        .await;
        // 5-rep target is below the squat range top (10), so the session
        // clears mid-range: the weight holds at the performed 185 and reps
        // advance instead.
        assert_eq!(tracker_weight(&db, "u1", Exercise::Squat).await, Some(185.0));
    }

    /// Templates: saved groups first, then the last workout, then the six
    /// defaults, deduplicated by name. The last workout keeps its exercise
    /// order.
    #[tokio::test]
    async fn templates_come_from_groups_history_and_defaults() {
        let db = migrate_fixture(|pool| async move {
            seed_user(&pool, "u1").await;
            seed_state(&pool, "u1", legacy_state_blob(1, &[])).await;
            let configs = crate::db::codec::encode_exercise_configs(&[
                schlift::workout::v1::ExerciseTypeConfig {
                    exercise: Exercise::HipThrust as i32,
                    ..Default::default()
                },
                schlift::workout::v1::ExerciseTypeConfig {
                    exercise: Exercise::LegCurl as i32,
                    ..Default::default()
                },
            ]);
            sqlx::query(
                "INSERT INTO profile_exercise_groups
                 (id, user_id, name, profile_order, exercise_configs_blob, created_at, updated_at)
                 VALUES ('pg1', 'u1', 'Glute Day', 0, ?, 1, 1)",
            )
            .bind(configs)
            .execute(&pool)
            .await
            .unwrap();
            seed_workout(
                &pool,
                "u1",
                "w1",
                1_000_000,
                &[
                    (Exercise::BenchPress as i32, 5, 5, 135.0),
                    (Exercise::BarbellRow as i32, 5, 5, 115.0),
                ],
            )
            .await;
        })
        .await;

        let templates = db.list_templates("u1").await.unwrap();
        assert_eq!(templates[0].name, "Glute Day");
        assert_eq!(
            templates[0].exercises,
            vec![Exercise::HipThrust as i32, Exercise::LegCurl as i32]
        );
        assert_eq!(templates[1].name, "W", "the last workout, order preserved");
        assert_eq!(
            templates[1].exercises,
            vec![Exercise::BenchPress as i32, Exercise::BarbellRow as i32]
        );
        // Six defaults follow.
        assert_eq!(templates.len(), 2 + 6);
        let names: Vec<&str> = templates.iter().map(|t| t.name.as_str()).collect();
        assert!(names.contains(&"Push") && names.contains(&"Full Body"));
    }

    /// The migration drops the old tables, keeps every workout row, adds
    /// the new columns, copies the idempotency ledger, and never runs
    /// twice.
    #[tokio::test]
    async fn schema_cutover_is_complete_and_idempotent() {
        let db = migrate_fixture(|pool| async move {
            seed_user(&pool, "u1").await;
            seed_state(&pool, "u1", legacy_state_blob(1, &[("squat_weight", 175.0)])).await;
            seed_workout(&pool, "u1", "w1", 1_000_000, &[(1, 5, 5, 175.0)]).await;
            sqlx::query(
                "INSERT INTO program_progression_applied (workout_id, user_id, applied_at)
                 VALUES ('w1', 'u1', 1)",
            )
            .execute(&pool)
            .await
            .unwrap();
        })
        .await;

        for table in [
            "training_program_state_latest",
            "proposed_schedule_cache",
            "workout_drafts_current",
            "profile_exercise_groups",
            "workout_events",
            "program_progression_applied",
            "t_workouts",
        ] {
            let count: i64 = sqlx::query_scalar(
                "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = ?",
            )
            .bind(table)
            .fetch_one(&db.read_pool)
            .await
            .unwrap();
            assert_eq!(count, 0, "{table} should be dropped");
        }

        // The old ledger row survived the rename: w1 can't double-progress.
        assert!(!db.claim_progression("u1", "w1").await.unwrap());
        // Workouts kept, with the new column.
        let template_id: String =
            sqlx::query_scalar("SELECT template_id FROM workouts WHERE id = 'w1'")
                .fetch_one(&db.read_pool)
                .await
                .unwrap();
        assert_eq!(template_id, "");
        // Old columns gone.
        let cols: i64 = sqlx::query_scalar(
            "SELECT COUNT(*) FROM pragma_table_info('exercise_groups')
             WHERE name = 'prescribed_by_regime'",
        )
        .fetch_one(&db.read_pool)
        .await
        .unwrap();
        assert_eq!(cols, 0);

        // Second run: the marker short-circuits; nothing re-seeds. Simulate
        // by counting templates, re-running, and counting again.
        let before = db.list_templates("u1").await.unwrap().len();
        super::run(&db.read_pool).await.unwrap();
        assert_eq!(db.list_templates("u1").await.unwrap().len(), before);
    }

    /// A fresh database needs no conversion; the marker is set and the new
    /// tables just exist.
    #[tokio::test]
    async fn a_fresh_database_marks_and_moves_on() {
        let dir = std::env::temp_dir().join(format!("lift-migration-fresh-{}", Uuid::new_v4()));
        let db = ServerDb::new_in_dir(&dir).await.unwrap();
        let applied: i64 =
            sqlx::query_scalar("SELECT COUNT(*) FROM schema_migrations WHERE name = ?")
                .bind(MIGRATION_NAME)
                .fetch_one(&db.read_pool)
                .await
                .unwrap();
        assert_eq!(applied, 1);
        assert!(db.list_templates("nobody").await.unwrap().is_empty());
    }
}
