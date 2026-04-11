use clap::Parser;
use sqlx::sqlite::{SqliteConnectOptions, SqliteJournalMode, SqlitePoolOptions, SqliteSynchronous};
use sqlx::{Pool, Sqlite};
use std::path::{Path, PathBuf};
use std::str::FromStr;
use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use tokio::sync::Barrier;
use uuid::Uuid;

#[derive(Parser, Debug, Clone)]
#[command(about = "Raw SQLite baseline benchmark for schlift-style access patterns")]
struct Args {
    #[arg(long, default_value = "tmp/sqlite-baseline-bench.sqlite")]
    db_path: PathBuf,

    #[arg(long, default_value_t = 20_000)]
    users: usize,

    #[arg(long, default_value_t = 5_000)]
    active_users: usize,

    #[arg(long, default_value_t = 250)]
    session_count: usize,

    #[arg(long, default_value_t = 16)]
    concurrent_clients: usize,

    #[arg(long, default_value_t = 20_000)]
    iterations: usize,

    #[arg(long, default_value_t = 4)]
    groups_per_workout: usize,

    #[arg(long, default_value_t = 4)]
    sets_per_group: usize,
}

const SCHEMA: &str = r#"
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS auth_sessions (
    token TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS workouts (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL DEFAULT '',
    start_time INTEGER NOT NULL,
    end_time INTEGER,
    session_id TEXT
);

CREATE TABLE IF NOT EXISTS exercise_groups (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    name TEXT NOT NULL,
    instruction TEXT NOT NULL DEFAULT '',
    sets INTEGER NOT NULL,
    interleave_warmups BOOLEAN NOT NULL,
    prescribed_by_regime BOOLEAN NOT NULL DEFAULT 0,
    workout_order INTEGER NOT NULL,
    rest_success INTEGER,
    rest_failure INTEGER,
    rest_warmup INTEGER,
    rest_last_warmup INTEGER
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
    rest_last_warmup INTEGER
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
    rest_after_failure INTEGER
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
    rest_until INTEGER
);

CREATE TABLE IF NOT EXISTS workout_heart_rate_samples (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    sampled_at INTEGER NOT NULL,
    bpm REAL NOT NULL,
    availability INTEGER NOT NULL,
    source TEXT NOT NULL DEFAULT 'wear'
);

CREATE TABLE IF NOT EXISTS workout_events (
    event_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    recorded_at INTEGER NOT NULL,
    event_type INTEGER NOT NULL,
    payload BLOB NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
    session_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    joined_at INTEGER NOT NULL,
    left_at INTEGER,
    PRIMARY KEY(session_id, user_id, joined_at)
);

CREATE TABLE IF NOT EXISTS training_program_state_latest (
    user_id TEXT PRIMARY KEY,
    regime_type INTEGER NOT NULL,
    latest_event_id TEXT NOT NULL,
    state_payload_json TEXT NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS active_workout_current (
    user_id TEXT PRIMARY KEY,
    workout_id TEXT NOT NULL,
    session_id TEXT NOT NULL,
    name TEXT NOT NULL,
    started_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS workout_snapshot_current (
    user_id TEXT PRIMARY KEY,
    workout_id TEXT NOT NULL,
    session_id TEXT NOT NULL,
    snapshot_blob BLOB NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS session_participants_current (
    session_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    user_name TEXT NOT NULL,
    state_blob BLOB NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (session_id, user_id)
);

CREATE TABLE IF NOT EXISTS proposed_schedule_cache (
    user_id TEXT PRIMARY KEY,
    active_workout_id TEXT,
    response_blob BLOB NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sessions_active ON sessions(session_id) WHERE left_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_sessions_session_user_joined ON sessions(session_id, user_id, joined_at DESC);
CREATE INDEX IF NOT EXISTS idx_exercise_groups_user_workout ON exercise_groups(user_id, workout_id);
CREATE INDEX IF NOT EXISTS idx_proposed_sets_user_workout ON proposed_sets(user_id, workout_id);
CREATE INDEX IF NOT EXISTS idx_completed_sets_user_workout ON completed_sets(user_id, workout_id);
CREATE INDEX IF NOT EXISTS idx_exercise_type_configs_group ON exercise_type_configs(exercise_group_id);
CREATE INDEX IF NOT EXISTS idx_exercise_groups_workout_id ON exercise_groups(workout_id);
CREATE INDEX IF NOT EXISTS idx_proposed_sets_workout_id ON proposed_sets(workout_id);
CREATE INDEX IF NOT EXISTS idx_proposed_sets_cancelled ON proposed_sets(user_id, workout_id, cancelled);
CREATE INDEX IF NOT EXISTS idx_completed_sets_workout_id ON completed_sets(workout_id);
CREATE INDEX IF NOT EXISTS idx_hr_samples_user_workout_time ON workout_heart_rate_samples(user_id, workout_id, sampled_at);
CREATE INDEX IF NOT EXISTS idx_workout_events_user_workout_time ON workout_events(user_id, workout_id, recorded_at, event_id);
CREATE INDEX IF NOT EXISTS idx_workouts_user_id ON workouts(user_id);
CREATE INDEX IF NOT EXISTS idx_workouts_session_user_start ON workouts(session_id, user_id, start_time DESC);
CREATE INDEX IF NOT EXISTS idx_active_workout_current_session ON active_workout_current(session_id, user_id);
CREATE INDEX IF NOT EXISTS idx_session_participants_current_session ON session_participants_current(session_id, updated_at DESC);
"#;

#[derive(Clone)]
struct SeededState {
    active_user_ids: Arc<Vec<String>>,
    session_ids: Arc<Vec<String>>,
    token_pairs: Arc<Vec<(String, String)>>,
}

struct BenchResult {
    name: &'static str,
    total_ops: usize,
    elapsed: Duration,
    avg_ms: f64,
    p50_ms: u64,
    p95_ms: u64,
    p99_ms: u64,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let args = Args::parse();
    if args.active_users > args.users {
        return Err("--active-users must be <= --users".into());
    }
    if args.session_count == 0 {
        return Err("--session-count must be > 0".into());
    }

    if let Some(parent) = args.db_path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    if args.db_path.exists() {
        std::fs::remove_file(&args.db_path)?;
    }

    let pool = open_pool(&args.db_path).await?;
    sqlx::query(SCHEMA).execute(&pool).await?;
    let seeded = seed_database(&pool, &args).await?;

    println!("SQLite baseline benchmark");
    println!("db: {}", args.db_path.display());
    println!(
        "seeded: users={}, active_users={}, sessions={}, groups/workout={}, sets/group={}",
        args.users,
        args.active_users,
        args.session_count,
        args.groups_per_workout,
        args.sets_per_group
    );
    println!(
        "run: concurrent_clients={}, iterations/client={}",
        args.concurrent_clients, args.iterations
    );

    let results = vec![
        bench_ep_validate_auth_session(&pool, &seeded, &args).await?,
        bench_ep_get_active_workout(&pool, &seeded, &args).await?,
        bench_ep_get_current_session(&pool, &seeded, &args).await?,
        bench_ep_get_proposed_schedule(&pool, &seeded, &args).await?,
        bench_ep_test_login_tx(&pool, &seeded, &args).await?,
        bench_ep_join_session_tx(&pool, &seeded, &args).await?,
        bench_ep_start_workout_tx(&pool, &seeded, &args).await?,
        bench_ep_append_mutation_tx(&pool, &seeded, &args).await?,
        bench_ep_append_heart_rate_tx(&pool, &seeded, &args).await?,
        bench_ep_end_workout_tx(&pool, &seeded, &args).await?,
        bench_simple_get_active_workout(&pool, &seeded, &args).await?,
        bench_simple_get_workout_snapshot(&pool, &seeded, &args).await?,
        bench_simple_get_current_session(&pool, &seeded, &args).await?,
        bench_simple_get_proposed_schedule(&pool, &seeded, &args).await?,
        bench_simple_multiplayer_write(&pool, &seeded, &args).await?,
        bench_simple_multiplayer_write_with_poll(&pool, &seeded, &args).await?,
        bench_validate_auth_session(&pool, &seeded, &args).await?,
        bench_get_active_workout(&pool, &seeded, &args).await?,
        bench_get_current_session(&pool, &seeded, &args).await?,
        bench_append_workout_event(&pool, &seeded, &args).await?,
        bench_append_heart_rate(&pool, &seeded, &args).await?,
        bench_upsert_completed_set(&pool, &seeded, &args).await?,
        bench_full_flush_workout(&pool, &seeded, &args).await?,
    ];

    println!();
    for result in results {
        let ops_per_sec = result.total_ops as f64 / result.elapsed.as_secs_f64();
        println!(
            "{:<24} ops={:<8} total={:>7.2}s  ops/s={:>9.1}  avg={:>7.3}ms  p50={:>4}ms  p95={:>4}ms  p99={:>4}ms",
            result.name,
            result.total_ops,
            result.elapsed.as_secs_f64(),
            ops_per_sec,
            result.avg_ms,
            result.p50_ms,
            result.p95_ms,
            result.p99_ms
        );
    }

    Ok(())
}

async fn open_pool(path: &Path) -> Result<Pool<Sqlite>, Box<dyn std::error::Error + Send + Sync>> {
    let db_url = format!("sqlite://{}", path.display());
    let options = SqliteConnectOptions::from_str(&db_url)?
        .create_if_missing(true)
        .journal_mode(SqliteJournalMode::Wal)
        .synchronous(SqliteSynchronous::Normal)
        .busy_timeout(Duration::from_secs(30));
    let pool = SqlitePoolOptions::new()
        .max_connections(32)
        .connect_with(options)
        .await?;
    Ok(pool)
}

async fn seed_database(
    pool: &Pool<Sqlite>,
    args: &Args,
) -> Result<SeededState, Box<dyn std::error::Error + Send + Sync>> {
    let now = now_unix();
    let mut tx = pool.begin().await?;

    let session_ids: Vec<String> = (0..args.session_count)
        .map(|i| format!("session-{i}"))
        .collect();
    let mut active_user_ids = Vec::with_capacity(args.active_users);
    let mut token_pairs = Vec::with_capacity(args.users);

    for i in 0..args.users {
        let user_id = format!("user-{i}");
        let username = format!("bench_user_{i}");
        let token = format!("token-{i}");
        sqlx::query("INSERT INTO users (id, name, created_at) VALUES (?, ?, ?)")
            .bind(&user_id)
            .bind(&username)
            .bind(now)
            .execute(&mut *tx)
            .await?;

        sqlx::query(
            "INSERT INTO auth_sessions (token, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)",
        )
        .bind(&token)
        .bind(&user_id)
        .bind(now)
        .bind(now + 30 * 24 * 60 * 60)
        .execute(&mut *tx)
        .await?;
        token_pairs.push((token, user_id.clone()));

        sqlx::query(
            "INSERT INTO training_program_state_latest (user_id, regime_type, latest_event_id, state_payload_json, updated_at)
             VALUES (?, 1, ?, ?, ?)",
        )
        .bind(&user_id)
        .bind(format!("state-event-{i}"))
        .bind(r#"{"week":1,"cycle":1}"#)
        .bind(now)
        .execute(&mut *tx)
        .await?;

        let active = i < args.active_users;
        let workout_id = format!("workout-{i}");
        let snapshot_blob = format!(
            "{{\"workout_id\":\"{workout_id}\",\"groups\":{},\"sets\":{}}}",
            args.groups_per_workout,
            args.groups_per_workout * args.sets_per_group
        )
        .into_bytes();
        let schedule_blob = format!(
            "{{\"user_id\":\"{user_id}\",\"can_start\":true,\"groups\":{},\"context\":\"linear_5x5\"}}",
            args.groups_per_workout
        )
        .into_bytes();
        let session_id = if active {
            let sid = session_ids[i % session_ids.len()].clone();
            active_user_ids.push(user_id.clone());
            Some(sid)
        } else {
            None
        };
        let end_time = if active { None } else { Some(now - 86_400) };

        sqlx::query(
            "INSERT INTO workouts (id, user_id, name, start_time, end_time, session_id) VALUES (?, ?, ?, ?, ?, ?)",
        )
        .bind(&workout_id)
        .bind(&user_id)
        .bind("Bench Workout")
        .bind(now - 3_600)
        .bind(end_time)
        .bind(session_id.as_deref())
        .execute(&mut *tx)
        .await?;

        sqlx::query(
            "INSERT INTO proposed_schedule_cache (user_id, active_workout_id, response_blob, updated_at)
             VALUES (?, ?, ?, ?)",
        )
        .bind(&user_id)
        .bind(if active { Some(workout_id.as_str()) } else { None })
        .bind(&schedule_blob)
        .bind(now)
        .execute(&mut *tx)
        .await?;

        if let Some(sid) = session_id.as_ref() {
            sqlx::query(
                "INSERT INTO sessions (session_id, user_id, joined_at, left_at) VALUES (?, ?, ?, NULL)",
            )
            .bind(sid)
            .bind(&user_id)
            .bind(now - 3_600)
            .execute(&mut *tx)
            .await?;

            sqlx::query(
                "INSERT INTO active_workout_current (user_id, workout_id, session_id, name, started_at, updated_at)
                 VALUES (?, ?, ?, ?, ?, ?)",
            )
            .bind(&user_id)
            .bind(&workout_id)
            .bind(sid)
            .bind("Bench Workout")
            .bind(now - 3_600)
            .bind(now)
            .execute(&mut *tx)
            .await?;

            sqlx::query(
                "INSERT INTO workout_snapshot_current (user_id, workout_id, session_id, snapshot_blob, updated_at)
                 VALUES (?, ?, ?, ?, ?)",
            )
            .bind(&user_id)
            .bind(&workout_id)
            .bind(sid)
            .bind(&snapshot_blob)
            .bind(now)
            .execute(&mut *tx)
            .await?;

            let participant_blob = format!(
                "{{\"user\":\"{user_id}\",\"workout_id\":\"{workout_id}\",\"next_up\":{{\"exercise\":1,\"reps\":5,\"weight\":135}},\"rest_until\":{}}}",
                now + 180
            )
            .into_bytes();
            sqlx::query(
                "INSERT INTO session_participants_current (session_id, user_id, workout_id, user_name, state_blob, updated_at)
                 VALUES (?, ?, ?, ?, ?, ?)",
            )
            .bind(sid)
            .bind(&user_id)
            .bind(&workout_id)
            .bind(&username)
            .bind(&participant_blob)
            .bind(now)
            .execute(&mut *tx)
            .await?;
        }

        let mut set_order = 0_i32;
        for g in 0..args.groups_per_workout {
            let group_id = format!("group-{i}-{g}");
            sqlx::query(
                "INSERT INTO exercise_groups (id, user_id, workout_id, name, instruction, sets, interleave_warmups, prescribed_by_regime, workout_order, rest_success, rest_failure, rest_warmup, rest_last_warmup)
                 VALUES (?, ?, ?, ?, '', ?, 0, 0, ?, 180, 300, 90, 120)",
            )
            .bind(&group_id)
            .bind(&user_id)
            .bind(&workout_id)
            .bind(format!("Group {g}"))
            .bind(args.sets_per_group as i32)
            .bind(g as i32)
            .execute(&mut *tx)
            .await?;

            sqlx::query(
                "INSERT INTO exercise_type_configs (id, user_id, exercise_group_id, exercise, start_weight, end_weight, reps, include_warmup, config_order, rest_success, rest_failure, rest_warmup, rest_last_warmup)
                 VALUES (?, ?, ?, 1, 135.0, 135.0, 5, 0, 0, 180, 300, 90, 120)",
            )
            .bind(format!("cfg-{i}-{g}"))
            .bind(&user_id)
            .bind(&group_id)
            .execute(&mut *tx)
            .await?;

            for s in 0..args.sets_per_group {
                let proposed_id = format!("ps-{i}-{g}-{s}");
                sqlx::query(
                    "INSERT INTO proposed_sets (id, user_id, workout_id, workout_order, exercise, target_reps, target_weight, warmup, cancelled, exercise_group_id, rest_after_success, rest_after_failure)
                     VALUES (?, ?, ?, ?, 1, 5, 135.0, 0, 0, ?, 180, 300)",
                )
                .bind(&proposed_id)
                .bind(&user_id)
                .bind(&workout_id)
                .bind(set_order)
                .bind(&group_id)
                .execute(&mut *tx)
                .await?;

                if s == 0 {
                    let ended_at = if active { 0 } else { now - 3_000 };
                    sqlx::query(
                        "INSERT INTO completed_sets (id, user_id, workout_id, proposed_set_id, actual_reps, actual_weight, started_at, ended_at, rest_until)
                         VALUES (?, ?, ?, ?, 5, 135.0, ?, ?, ?)",
                    )
                    .bind(format!("cs-{i}-{g}-{s}"))
                    .bind(&user_id)
                    .bind(&workout_id)
                    .bind(&proposed_id)
                    .bind(now - 3_100)
                    .bind(ended_at)
                    .bind(if ended_at == 0 { None } else { Some(ended_at + 180) })
                    .execute(&mut *tx)
                    .await?;
                }

                set_order += 1;
            }
        }
    }

    tx.commit().await?;

    Ok(SeededState {
        active_user_ids: Arc::new(active_user_ids),
        session_ids: Arc::new(session_ids),
        token_pairs: Arc::new(token_pairs),
    })
}

async fn bench_simple_get_active_workout(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations;
    run_benchmark(
        "simple_get_active",
        pool,
        args.concurrent_clients,
        iterations,
        {
            let user_ids = seeded.active_user_ids.clone();
            move |pool, worker, iter| {
                let idx = (worker * iterations + iter) % user_ids.len();
                let user_id = user_ids[idx].clone();
                Box::pin(async move {
                    let _row = sqlx::query(
                        "SELECT workout_id, session_id, name, started_at, updated_at
                     FROM active_workout_current
                     WHERE user_id = ?",
                    )
                    .bind(user_id)
                    .fetch_optional(&pool)
                    .await?;
                    Ok(())
                })
            }
        },
    )
    .await
}

async fn bench_simple_get_workout_snapshot(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations;
    run_benchmark(
        "simple_get_snapshot",
        pool,
        args.concurrent_clients,
        iterations,
        {
            let user_ids = seeded.active_user_ids.clone();
            move |pool, worker, iter| {
                let idx = (worker * iterations + iter) % user_ids.len();
                let user_id = user_ids[idx].clone();
                Box::pin(async move {
                    let _row = sqlx::query(
                        "SELECT workout_id, session_id, snapshot_blob, updated_at
                     FROM workout_snapshot_current
                     WHERE user_id = ?",
                    )
                    .bind(user_id)
                    .fetch_optional(&pool)
                    .await?;
                    Ok(())
                })
            }
        },
    )
    .await
}

async fn bench_simple_get_current_session(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations;
    run_benchmark(
        "simple_get_session",
        pool,
        args.concurrent_clients,
        iterations,
        {
            let session_ids = seeded.session_ids.clone();
            move |pool, worker, iter| {
                let idx = (worker * iterations + iter) % session_ids.len();
                let session_id = session_ids[idx].clone();
                Box::pin(async move {
                    let _rows = sqlx::query(
                        "SELECT user_id, workout_id, user_name, state_blob, updated_at
                     FROM session_participants_current
                     WHERE session_id = ?
                     ORDER BY updated_at DESC, user_id",
                    )
                    .bind(session_id)
                    .fetch_all(&pool)
                    .await?;
                    Ok(())
                })
            }
        },
    )
    .await
}

async fn bench_simple_get_proposed_schedule(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations;
    run_benchmark(
        "simple_get_schedule",
        pool,
        args.concurrent_clients,
        iterations,
        {
            let token_pairs = seeded.token_pairs.clone();
            move |pool, worker, iter| {
                let idx = (worker * iterations + iter) % token_pairs.len();
                let user_id = token_pairs[idx].1.clone();
                Box::pin(async move {
                    let _row = sqlx::query(
                        "SELECT active_workout_id, response_blob, updated_at
                     FROM proposed_schedule_cache
                     WHERE user_id = ?",
                    )
                    .bind(user_id)
                    .fetch_optional(&pool)
                    .await?;
                    Ok(())
                })
            }
        },
    )
    .await
}

async fn bench_simple_multiplayer_write(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations;
    run_benchmark("simple_mp_write", pool, args.concurrent_clients, iterations, {
        let user_ids = seeded.active_user_ids.clone();
        move |pool, worker, iter| {
            let idx = (worker * iterations + iter) % user_ids.len();
            let user_id = user_ids[idx].clone();
            let workout_id = format!("workout-{idx}");
            let session_id = format!("session-{}", idx % 80);
            Box::pin(async move {
                let now = now_unix();
                let event_id = format!("mp-event-{worker}-{iter}");
                let snapshot_blob = format!(
                    "{{\"workout_id\":\"{workout_id}\",\"event_id\":\"{event_id}\",\"completed\":{},\"updated_at\":{now}}}",
                    (iter % 32) + 1
                )
                .into_bytes();
                let state_blob = format!(
                    "{{\"user\":\"{user_id}\",\"workout_id\":\"{workout_id}\",\"last_event\":\"{event_id}\",\"next_up\":{{\"exercise\":1,\"reps\":5,\"weight\":135}},\"rest_until\":{}}}",
                    now + 180
                )
                .into_bytes();

                let mut tx = pool.begin().await?;
                sqlx::query(
                    "INSERT INTO workout_events (event_id, user_id, workout_id, recorded_at, event_type, payload)
                     VALUES (?, ?, ?, ?, 1, ?)",
                )
                .bind(&event_id)
                .bind(&user_id)
                .bind(&workout_id)
                .bind(now)
                .bind(vec![1_u8, 2, 3, 4, 5, (iter % 255) as u8])
                .execute(&mut *tx)
                .await?;

                sqlx::query(
                    "UPDATE workout_snapshot_current
                     SET snapshot_blob = ?, updated_at = ?
                     WHERE user_id = ?",
                )
                .bind(&snapshot_blob)
                .bind(now)
                .bind(&user_id)
                .execute(&mut *tx)
                .await?;

                sqlx::query(
                    "UPDATE session_participants_current
                     SET state_blob = ?, updated_at = ?
                     WHERE session_id = ? AND user_id = ?",
                )
                .bind(&state_blob)
                .bind(now)
                .bind(&session_id)
                .bind(&user_id)
                .execute(&mut *tx)
                .await?;
                tx.commit().await?;
                Ok(())
            })
        }
    })
    .await
}

async fn bench_simple_multiplayer_write_with_poll(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let writer_clients = args.concurrent_clients.max(2);
    let reader_clients = (writer_clients / 4).max(1);
    let total_clients = writer_clients + reader_clients;
    let iterations = args.iterations;
    let session_mod = args.session_count.max(1);

    run_benchmark("simple_mp_write+poll", pool, total_clients, iterations, {
        let user_ids = seeded.active_user_ids.clone();
        let session_ids = seeded.session_ids.clone();
        move |pool, worker, iter| {
            if worker < writer_clients {
                let idx = (worker * iterations + iter) % user_ids.len();
                let user_id = user_ids[idx].clone();
                let workout_id = format!("workout-{idx}");
                let session_id = format!("session-{}", idx % session_mod);
                Box::pin(async move {
                    let now = now_unix();
                    let event_id = format!("mpp-event-{worker}-{iter}");
                    let snapshot_blob = format!(
                        "{{\"workout_id\":\"{workout_id}\",\"event_id\":\"{event_id}\",\"completed\":{},\"updated_at\":{now}}}",
                        (iter % 32) + 1
                    )
                    .into_bytes();
                    let state_blob = format!(
                        "{{\"user\":\"{user_id}\",\"workout_id\":\"{workout_id}\",\"last_event\":\"{event_id}\",\"next_up\":{{\"exercise\":1,\"reps\":5,\"weight\":135}},\"rest_until\":{}}}",
                        now + 180
                    )
                    .into_bytes();

                    let mut tx = pool.begin().await?;
                    sqlx::query(
                        "INSERT INTO workout_events (event_id, user_id, workout_id, recorded_at, event_type, payload)
                         VALUES (?, ?, ?, ?, 1, ?)",
                    )
                    .bind(&event_id)
                    .bind(&user_id)
                    .bind(&workout_id)
                    .bind(now)
                    .bind(vec![7_u8, 8, 9, 10, (iter % 255) as u8])
                    .execute(&mut *tx)
                    .await?;
                    sqlx::query(
                        "UPDATE workout_snapshot_current
                         SET snapshot_blob = ?, updated_at = ?
                         WHERE user_id = ?",
                    )
                    .bind(&snapshot_blob)
                    .bind(now)
                    .bind(&user_id)
                    .execute(&mut *tx)
                    .await?;
                    sqlx::query(
                        "UPDATE session_participants_current
                         SET state_blob = ?, updated_at = ?
                         WHERE session_id = ? AND user_id = ?",
                    )
                    .bind(&state_blob)
                    .bind(now)
                    .bind(&session_id)
                    .bind(&user_id)
                    .execute(&mut *tx)
                    .await?;
                    tx.commit().await?;
                    Ok(())
                })
            } else {
                let idx = (worker * iterations + iter) % session_ids.len();
                let session_id = session_ids[idx].clone();
                Box::pin(async move {
                    let _rows = sqlx::query(
                        "SELECT user_id, workout_id, state_blob, updated_at
                         FROM session_participants_current
                         WHERE session_id = ?
                         ORDER BY updated_at DESC, user_id",
                    )
                    .bind(session_id)
                    .fetch_all(&pool)
                    .await?;
                    Ok(())
                })
            }
        }
    })
    .await
}

async fn bench_validate_auth_session(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations;
    run_benchmark("validate_auth_session", pool, args.concurrent_clients, iterations, {
        let token_pairs = seeded.token_pairs.clone();
        move |pool, worker, iter| {
            let idx = (worker * iterations + iter) % token_pairs.len();
            let token = token_pairs[idx].0.clone();
            Box::pin(async move {
                let now = now_unix();
                let _row = sqlx::query_as::<_, (String, i64)>(
                    "SELECT user_id, expires_at FROM auth_sessions WHERE token = ? AND expires_at > ?",
                )
                .bind(token)
                .bind(now)
                .fetch_optional(&pool)
                .await?;
                Ok(())
            })
        }
    })
    .await
}

async fn bench_get_active_workout(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations;
    run_benchmark(
        "get_active_workout",
        pool,
        args.concurrent_clients,
        iterations,
        {
            let user_ids = seeded.active_user_ids.clone();
            move |pool, worker, iter| {
                let idx = (worker * iterations + iter) % user_ids.len();
                let user_id = user_ids[idx].clone();
                Box::pin(async move {
                    let _row = sqlx::query(
                        "SELECT id, name, start_time, end_time, session_id
                     FROM workouts
                     WHERE user_id = ? AND end_time IS NULL
                     ORDER BY start_time DESC
                     LIMIT 1",
                    )
                    .bind(user_id)
                    .fetch_optional(&pool)
                    .await?;
                    Ok(())
                })
            }
        },
    )
    .await
}

async fn bench_get_current_session(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations;
    run_benchmark("get_current_session", pool, args.concurrent_clients, iterations, {
        let session_ids = seeded.session_ids.clone();
        move |pool, worker, iter| {
            let idx = (worker * iterations + iter) % session_ids.len();
            let session_id = session_ids[idx].clone();
            Box::pin(async move {
                let _membership = sqlx::query(
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
                .bind(&session_id)
                .fetch_all(&pool)
                .await?;

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

                let _workouts = sqlx::query(
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
                .bind(&session_id)
                .fetch_all(&pool)
                .await?;

                let _groups = sqlx::query(&format!(
                    "{latest_workouts_cte}
                     SELECT id, workout_id, name, instruction, sets, interleave_warmups, workout_order
                     FROM exercise_groups
                     WHERE workout_id IN (SELECT id FROM latest_workouts)
                     ORDER BY workout_order"
                ))
                .bind(&session_id)
                .fetch_all(&pool)
                .await?;

                let _proposed = sqlx::query(&format!(
                    "{latest_workouts_cte}
                     SELECT id, workout_id, workout_order, exercise, target_reps, target_weight, warmup, cancelled
                     FROM proposed_sets
                     WHERE workout_id IN (SELECT id FROM latest_workouts) AND cancelled = 0
                     ORDER BY workout_order"
                ))
                .bind(&session_id)
                .fetch_all(&pool)
                .await?;

                let _completed = sqlx::query(&format!(
                    "{latest_workouts_cte}
                     SELECT id, workout_id, proposed_set_id, actual_reps, actual_weight, started_at, ended_at, rest_until
                     FROM completed_sets
                     WHERE workout_id IN (SELECT id FROM latest_workouts)
                     ORDER BY started_at"
                ))
                .bind(&session_id)
                .fetch_all(&pool)
                .await?;

                Ok(())
            })
        }
    })
    .await
}

async fn bench_append_workout_event(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations;
    run_benchmark("append_workout_event", pool, args.concurrent_clients, iterations, {
        let user_ids = seeded.active_user_ids.clone();
        move |pool, worker, iter| {
            let idx = (worker * iterations + iter) % user_ids.len();
            let user_id = user_ids[idx].clone();
            let workout_id = format!("workout-{idx}");
            Box::pin(async move {
                sqlx::query(
                    "INSERT INTO workout_events (event_id, user_id, workout_id, recorded_at, event_type, payload)
                     VALUES (?, ?, ?, ?, 1, ?)",
                )
                .bind(Uuid::new_v4().to_string())
                .bind(user_id)
                .bind(workout_id)
                .bind(now_unix())
                .bind(vec![1_u8, 2, 3, 4, 5])
                .execute(&pool)
                .await?;
                Ok(())
            })
        }
    })
    .await
}

async fn bench_append_heart_rate(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations;
    run_benchmark("append_heart_rate_x5", pool, args.concurrent_clients, iterations, {
        let user_ids = seeded.active_user_ids.clone();
        move |pool, worker, iter| {
            let idx = (worker * iterations + iter) % user_ids.len();
            let user_id = user_ids[idx].clone();
            let workout_id = format!("workout-{idx}");
            Box::pin(async move {
                let mut tx = pool.begin().await?;
                let now = now_unix_millis();
                for sample_idx in 0..5 {
                    sqlx::query(
                        "INSERT INTO workout_heart_rate_samples (id, user_id, workout_id, sampled_at, bpm, availability, source)
                         VALUES (?, ?, ?, ?, ?, 1, 'wear')",
                    )
                    .bind(Uuid::new_v4().to_string())
                    .bind(&user_id)
                    .bind(&workout_id)
                    .bind(now + sample_idx as i64 * 1_000)
                    .bind(120.0 + sample_idx as f32)
                    .execute(&mut *tx)
                    .await?;
                }
                tx.commit().await?;
                Ok(())
            })
        }
    })
    .await
}

async fn bench_upsert_completed_set(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations;
    run_benchmark("upsert_completed_set", pool, args.concurrent_clients, iterations, {
        let user_ids = seeded.active_user_ids.clone();
        move |pool, worker, iter| {
            let idx = (worker * iterations + iter) % user_ids.len();
            let user_id = user_ids[idx].clone();
            let workout_id = format!("workout-{idx}");
            let proposed_set_id = format!("ps-{idx}-0-0");
            Box::pin(async move {
                sqlx::query(
                    "INSERT OR REPLACE INTO completed_sets (id, user_id, workout_id, proposed_set_id, actual_reps, actual_weight, started_at, ended_at, rest_until)
                     VALUES (?, ?, ?, ?, 5, 135.0, ?, ?, ?)",
                )
                .bind(format!("bench-cs-{worker}-{iter}"))
                .bind(user_id)
                .bind(workout_id)
                .bind(proposed_set_id)
                .bind(now_unix())
                .bind(now_unix())
                .bind(now_unix() + 180)
                .execute(&pool)
                .await?;
                Ok(())
            })
        }
    })
    .await
}

async fn bench_full_flush_workout(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations.min(2_000);
    let groups_per_workout = args.groups_per_workout;
    let sets_per_group = args.sets_per_group;
    run_benchmark("full_flush_workout", pool, args.concurrent_clients, iterations, {
        let user_ids = seeded.active_user_ids.clone();
        move |pool, worker, iter| {
            let idx = (worker * iterations + iter) % user_ids.len();
            let user_id = user_ids[idx].clone();
            let workout_id = format!("workout-{idx}");
            Box::pin(async move {
                let mut tx = pool.begin().await?;

                sqlx::query("DELETE FROM exercise_type_configs WHERE user_id = ? AND exercise_group_id IN (SELECT id FROM exercise_groups WHERE user_id = ? AND workout_id = ?)")
                    .bind(&user_id)
                    .bind(&user_id)
                    .bind(&workout_id)
                    .execute(&mut *tx)
                    .await?;
                sqlx::query("DELETE FROM completed_sets WHERE user_id = ? AND workout_id = ?")
                    .bind(&user_id)
                    .bind(&workout_id)
                    .execute(&mut *tx)
                    .await?;
                sqlx::query("DELETE FROM proposed_sets WHERE user_id = ? AND workout_id = ?")
                    .bind(&user_id)
                    .bind(&workout_id)
                    .execute(&mut *tx)
                    .await?;
                sqlx::query("DELETE FROM exercise_groups WHERE user_id = ? AND workout_id = ?")
                    .bind(&user_id)
                    .bind(&workout_id)
                    .execute(&mut *tx)
                    .await?;

                let mut order = 0_i32;
                for g in 0..groups_per_workout {
                    let group_id = format!("flush-group-{worker}-{iter}-{g}");
                    sqlx::query(
                        "INSERT INTO exercise_groups (id, user_id, workout_id, name, instruction, sets, interleave_warmups, prescribed_by_regime, workout_order, rest_success, rest_failure, rest_warmup, rest_last_warmup)
                         VALUES (?, ?, ?, ?, '', ?, 0, 0, ?, 180, 300, 90, 120)",
                    )
                    .bind(&group_id)
                    .bind(&user_id)
                    .bind(&workout_id)
                    .bind(format!("Flush Group {g}"))
                    .bind(sets_per_group as i32)
                    .bind(g as i32)
                    .execute(&mut *tx)
                    .await?;

                    sqlx::query(
                        "INSERT INTO exercise_type_configs (id, user_id, exercise_group_id, exercise, start_weight, end_weight, reps, include_warmup, config_order, rest_success, rest_failure, rest_warmup, rest_last_warmup)
                         VALUES (?, ?, ?, 1, 135.0, 135.0, 5, 0, 0, 180, 300, 90, 120)",
                    )
                    .bind(format!("flush-cfg-{worker}-{iter}-{g}"))
                    .bind(&user_id)
                    .bind(&group_id)
                    .execute(&mut *tx)
                    .await?;

                    for s in 0..sets_per_group {
                        let proposed_id = format!("flush-ps-{worker}-{iter}-{g}-{s}");
                        sqlx::query(
                            "INSERT INTO proposed_sets (id, user_id, workout_id, workout_order, exercise, target_reps, target_weight, warmup, cancelled, exercise_group_id, rest_after_success, rest_after_failure)
                             VALUES (?, ?, ?, ?, 1, 5, 135.0, 0, 0, ?, 180, 300)",
                        )
                        .bind(&proposed_id)
                        .bind(&user_id)
                        .bind(&workout_id)
                        .bind(order)
                        .bind(&group_id)
                        .execute(&mut *tx)
                        .await?;
                        if s == 0 {
                            sqlx::query(
                                "INSERT INTO completed_sets (id, user_id, workout_id, proposed_set_id, actual_reps, actual_weight, started_at, ended_at, rest_until)
                                 VALUES (?, ?, ?, ?, 5, 135.0, ?, ?, ?)",
                            )
                            .bind(format!("flush-cs-{worker}-{iter}-{g}-{s}"))
                            .bind(&user_id)
                            .bind(&workout_id)
                            .bind(&proposed_id)
                            .bind(now_unix())
                            .bind(now_unix())
                            .bind(now_unix() + 180)
                            .execute(&mut *tx)
                            .await?;
                        }
                        order += 1;
                    }
                }

                tx.commit().await?;
                Ok(())
            })
        }
    })
    .await
}

async fn run_benchmark<FutFactory>(
    name: &'static str,
    pool: &Pool<Sqlite>,
    concurrent_clients: usize,
    iterations: usize,
    factory: FutFactory,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>>
where
    FutFactory: Fn(
            Pool<Sqlite>,
            usize,
            usize,
        )
            -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), sqlx::Error>> + Send>>
        + Send
        + Sync
        + 'static,
{
    let pool = pool.clone();
    let factory = Arc::new(factory);
    let barrier = Arc::new(Barrier::new(concurrent_clients + 1));
    let mut joins = Vec::with_capacity(concurrent_clients);

    for worker in 0..concurrent_clients {
        let pool = pool.clone();
        let barrier = barrier.clone();
        let factory = factory.clone();
        joins.push(tokio::spawn(async move {
            let mut latencies = Vec::with_capacity(iterations);
            barrier.wait().await;
            for iter in 0..iterations {
                let start = Instant::now();
                factory(pool.clone(), worker, iter).await?;
                latencies.push(start.elapsed().as_millis() as u64);
            }
            Ok::<Vec<u64>, sqlx::Error>(latencies)
        }));
    }

    barrier.wait().await;
    let started = Instant::now();
    let mut latencies = Vec::with_capacity(concurrent_clients * iterations);
    for join in joins {
        let worker_latencies = join.await??;
        latencies.extend(worker_latencies);
    }
    let elapsed = started.elapsed();
    latencies.sort_unstable();

    let total_ops = latencies.len();
    let total_ms: u128 = latencies.iter().map(|v| *v as u128).sum();

    Ok(BenchResult {
        name,
        total_ops,
        elapsed,
        avg_ms: total_ms as f64 / total_ops as f64,
        p50_ms: percentile(&latencies, 0.50),
        p95_ms: percentile(&latencies, 0.95),
        p99_ms: percentile(&latencies, 0.99),
    })
}

fn percentile(latencies: &[u64], pct: f64) -> u64 {
    if latencies.is_empty() {
        return 0;
    }
    let idx = ((latencies.len() - 1) as f64 * pct).round() as usize;
    latencies[idx]
}

fn now_unix() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_else(|_| Duration::from_secs(0))
        .as_secs() as i64
}

fn now_unix_millis() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_else(|_| Duration::from_secs(0))
        .as_millis() as i64
}

async fn bench_ep_validate_auth_session(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations;
    run_benchmark(
        "ep_validate_auth",
        pool,
        args.concurrent_clients,
        iterations,
        {
            let token_pairs = seeded.token_pairs.clone();
            move |pool, worker, iter| {
                let idx = (worker * iterations + iter) % token_pairs.len();
                let token = token_pairs[idx].0.clone();
                Box::pin(async move {
                    let _ = sqlx::query_as::<_, (String,)>(
                        "SELECT user_id FROM auth_sessions WHERE token = ? AND expires_at > ?",
                    )
                    .bind(token)
                    .bind(now_unix())
                    .fetch_optional(&pool)
                    .await?;
                    Ok(())
                })
            }
        },
    )
    .await
}

async fn bench_ep_get_active_workout(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations;
    run_benchmark(
        "ep_get_active",
        pool,
        args.concurrent_clients,
        iterations,
        {
            let user_ids = seeded.active_user_ids.clone();
            move |pool, worker, iter| {
                let idx = (worker * iterations + iter) % user_ids.len();
                let user_id = user_ids[idx].clone();
                Box::pin(async move {
                    let _ = sqlx::query(
                        "SELECT workout_id, session_id, name, started_at, updated_at
                     FROM active_workout_current WHERE user_id = ?",
                    )
                    .bind(user_id)
                    .fetch_optional(&pool)
                    .await?;
                    Ok(())
                })
            }
        },
    )
    .await
}

async fn bench_ep_get_current_session(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations;
    run_benchmark(
        "ep_get_session",
        pool,
        args.concurrent_clients,
        iterations,
        {
            let session_ids = seeded.session_ids.clone();
            move |pool, worker, iter| {
                let idx = (worker * iterations + iter) % session_ids.len();
                let session_id = session_ids[idx].clone();
                Box::pin(async move {
                    let _ = sqlx::query(
                        "SELECT user_id, workout_id, user_name, state_blob, updated_at
                     FROM session_participants_current
                     WHERE session_id = ?
                     ORDER BY updated_at DESC, user_id",
                    )
                    .bind(session_id)
                    .fetch_all(&pool)
                    .await?;
                    Ok(())
                })
            }
        },
    )
    .await
}

async fn bench_ep_get_proposed_schedule(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations;
    run_benchmark(
        "ep_get_schedule",
        pool,
        args.concurrent_clients,
        iterations,
        {
            let token_pairs = seeded.token_pairs.clone();
            move |pool, worker, iter| {
                let idx = (worker * iterations + iter) % token_pairs.len();
                let user_id = token_pairs[idx].1.clone();
                Box::pin(async move {
                    let _ = sqlx::query(
                        "SELECT active_workout_id, response_blob, updated_at
                     FROM proposed_schedule_cache WHERE user_id = ?",
                    )
                    .bind(user_id)
                    .fetch_optional(&pool)
                    .await?;
                    Ok(())
                })
            }
        },
    )
    .await
}

async fn bench_ep_test_login_tx(
    pool: &Pool<Sqlite>,
    _seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations.min(5_000);
    run_benchmark("ep_test_login_tx", pool, args.concurrent_clients, iterations, {
        move |pool, worker, iter| {
            Box::pin(async move {
                let now = now_unix();
                let user_id = format!("login-user-{worker}-{iter}");
                let username = format!("login_name_{worker}_{iter}");
                let token = format!("login-token-{worker}-{iter}");
                let mut tx = pool.begin().await?;
                sqlx::query("INSERT INTO users (id, name, created_at) VALUES (?, ?, ?)")
                    .bind(&user_id)
                    .bind(&username)
                    .bind(now)
                    .execute(&mut *tx)
                    .await?;
                sqlx::query(
                    "INSERT INTO auth_sessions (token, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)",
                )
                .bind(&token)
                .bind(&user_id)
                .bind(now)
                .bind(now + 30 * 24 * 60 * 60)
                .execute(&mut *tx)
                .await?;
                sqlx::query(
                    "INSERT INTO training_program_state_latest (user_id, regime_type, latest_event_id, state_payload_json, updated_at)
                     VALUES (?, 1, ?, ?, ?)",
                )
                .bind(&user_id)
                .bind(format!("login-state-{worker}-{iter}"))
                .bind(r#"{"week":1,"cycle":1}"#)
                .bind(now)
                .execute(&mut *tx)
                .await?;
                tx.commit().await?;
                Ok(())
            })
        }
    })
    .await
}

async fn bench_ep_join_session_tx(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations;
    let session_mod = args.session_count.max(1);
    run_benchmark("ep_join_session_tx", pool, args.concurrent_clients, iterations, {
        let user_ids = seeded.active_user_ids.clone();
        move |pool, worker, iter| {
            let idx = (worker * iterations + iter) % user_ids.len();
            let user_id = user_ids[idx].clone();
            let session_id = format!("join-session-{}", idx % session_mod);
            Box::pin(async move {
                let now = now_unix();
                let mut tx = pool.begin().await?;
                sqlx::query("UPDATE sessions SET left_at = ? WHERE user_id = ? AND left_at IS NULL")
                    .bind(now)
                    .bind(&user_id)
                    .execute(&mut *tx)
                    .await?;
                sqlx::query(
                    "INSERT INTO sessions (session_id, user_id, joined_at, left_at) VALUES (?, ?, ?, NULL)",
                )
                .bind(&session_id)
                .bind(&user_id)
                .bind(now)
                .execute(&mut *tx)
                .await?;
                sqlx::query(
                    "INSERT INTO session_participants_current (session_id, user_id, workout_id, user_name, state_blob, updated_at)
                     VALUES (?, ?, ?, ?, ?, ?)
                     ON CONFLICT(session_id, user_id) DO UPDATE SET
                       workout_id = excluded.workout_id,
                       user_name = excluded.user_name,
                       state_blob = excluded.state_blob,
                       updated_at = excluded.updated_at",
                )
                .bind(&session_id)
                .bind(&user_id)
                .bind(format!("workout-{idx}"))
                .bind(format!("bench_user_{idx}"))
                .bind(format!(r#"{{"user":"{user_id}","joined_at":{now}}}"#).into_bytes())
                .bind(now)
                .execute(&mut *tx)
                .await?;
                tx.commit().await?;
                Ok(())
            })
        }
    })
    .await
}

async fn bench_ep_start_workout_tx(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations.min(5_000);
    let groups_per_workout = args.groups_per_workout;
    let sets_per_group = args.sets_per_group;
    run_benchmark("ep_start_workout_tx", pool, args.concurrent_clients, iterations, {
        let user_ids = seeded.active_user_ids.clone();
        let session_count = args.session_count.max(1);
        move |pool, worker, iter| {
            let idx = (worker * iterations + iter) % user_ids.len();
            let user_id = user_ids[idx].clone();
            let session_id = format!("session-{}", idx % session_count);
            Box::pin(async move {
                let now = now_unix();
                let workout_id = format!("start-workout-{worker}-{iter}");
                let mut tx = pool.begin().await?;
                sqlx::query(
                    "INSERT INTO workouts (id, user_id, name, start_time, end_time, session_id)
                     VALUES (?, ?, ?, ?, NULL, ?)",
                )
                .bind(&workout_id)
                .bind(&user_id)
                .bind("Benchmark Workout")
                .bind(now)
                .bind(&session_id)
                .execute(&mut *tx)
                .await?;
                sqlx::query(
                    "INSERT INTO active_workout_current (user_id, workout_id, session_id, name, started_at, updated_at)
                     VALUES (?, ?, ?, ?, ?, ?)
                     ON CONFLICT(user_id) DO UPDATE SET
                       workout_id = excluded.workout_id,
                       session_id = excluded.session_id,
                       name = excluded.name,
                       started_at = excluded.started_at,
                       updated_at = excluded.updated_at",
                )
                .bind(&user_id)
                .bind(&workout_id)
                .bind(&session_id)
                .bind("Benchmark Workout")
                .bind(now)
                .bind(now)
                .execute(&mut *tx)
                .await?;
                for g in 0..groups_per_workout {
                    let group_id = format!("start-group-{worker}-{iter}-{g}");
                    sqlx::query(
                        "INSERT INTO exercise_groups (id, user_id, workout_id, name, instruction, sets, interleave_warmups, prescribed_by_regime, workout_order, rest_success, rest_failure, rest_warmup, rest_last_warmup)
                         VALUES (?, ?, ?, ?, '', ?, 0, 0, ?, 180, 300, 90, 120)",
                    )
                    .bind(&group_id)
                    .bind(&user_id)
                    .bind(&workout_id)
                    .bind(format!("Group {g}"))
                    .bind(sets_per_group as i32)
                    .bind(g as i32)
                    .execute(&mut *tx)
                    .await?;
                    for s in 0..sets_per_group {
                        sqlx::query(
                            "INSERT INTO proposed_sets (id, user_id, workout_id, workout_order, exercise, target_reps, target_weight, warmup, cancelled, exercise_group_id, rest_after_success, rest_after_failure)
                             VALUES (?, ?, ?, ?, 1, 5, 135.0, 0, 0, ?, 180, 300)",
                        )
                        .bind(format!("start-ps-{worker}-{iter}-{g}-{s}"))
                        .bind(&user_id)
                        .bind(&workout_id)
                        .bind((g * sets_per_group + s) as i32)
                        .bind(&group_id)
                        .execute(&mut *tx)
                        .await?;
                    }
                }
                sqlx::query(
                    "INSERT OR REPLACE INTO workout_snapshot_current (user_id, workout_id, session_id, snapshot_blob, updated_at)
                     VALUES (?, ?, ?, ?, ?)",
                )
                .bind(&user_id)
                .bind(&workout_id)
                .bind(&session_id)
                .bind(format!(r#"{{"workout_id":"{workout_id}","groups":{groups_per_workout},"sets":{}}}"#, groups_per_workout * sets_per_group).into_bytes())
                .bind(now)
                .execute(&mut *tx)
                .await?;
                tx.commit().await?;
                Ok(())
            })
        }
    })
    .await
}

async fn bench_ep_append_mutation_tx(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations;
    let session_mod = args.session_count.max(1);
    run_benchmark("ep_append_mut_tx", pool, args.concurrent_clients, iterations, {
        let user_ids = seeded.active_user_ids.clone();
        move |pool, worker, iter| {
            let idx = (worker * iterations + iter) % user_ids.len();
            let user_id = user_ids[idx].clone();
            let workout_id = format!("workout-{idx}");
            let session_id = format!("session-{}", idx % session_mod);
            Box::pin(async move {
                let now = now_unix();
                let mut tx = pool.begin().await?;
                let event_id = format!("ep-mut-{worker}-{iter}");
                sqlx::query(
                    "INSERT INTO workout_events (event_id, user_id, workout_id, recorded_at, event_type, payload)
                     VALUES (?, ?, ?, ?, 1, ?)",
                )
                .bind(&event_id)
                .bind(&user_id)
                .bind(&workout_id)
                .bind(now)
                .bind(vec![1_u8, 2, 3, (iter % 255) as u8])
                .execute(&mut *tx)
                .await?;
                sqlx::query(
                    "UPDATE workout_snapshot_current SET snapshot_blob = ?, updated_at = ? WHERE user_id = ?",
                )
                .bind(format!(r#"{{"workout_id":"{workout_id}","last_event":"{event_id}","updated_at":{now}}}"#).into_bytes())
                .bind(now)
                .bind(&user_id)
                .execute(&mut *tx)
                .await?;
                sqlx::query(
                    "UPDATE session_participants_current SET state_blob = ?, updated_at = ? WHERE session_id = ? AND user_id = ?",
                )
                .bind(format!(r#"{{"user":"{user_id}","workout_id":"{workout_id}","last_event":"{event_id}","updated_at":{now}}}"#).into_bytes())
                .bind(now)
                .bind(&session_id)
                .bind(&user_id)
                .execute(&mut *tx)
                .await?;
                tx.commit().await?;
                Ok(())
            })
        }
    })
    .await
}

async fn bench_ep_append_heart_rate_tx(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations;
    run_benchmark("ep_append_hr_tx", pool, args.concurrent_clients, iterations, {
        let user_ids = seeded.active_user_ids.clone();
        move |pool, worker, iter| {
            let idx = (worker * iterations + iter) % user_ids.len();
            let user_id = user_ids[idx].clone();
            let workout_id = format!("workout-{idx}");
            Box::pin(async move {
                let now = now_unix_millis();
                let mut tx = pool.begin().await?;
                for sample_idx in 0..5 {
                    sqlx::query(
                        "INSERT INTO workout_heart_rate_samples (id, user_id, workout_id, sampled_at, bpm, availability, source)
                         VALUES (?, ?, ?, ?, ?, 1, 'wear')",
                    )
                    .bind(format!("hr-{worker}-{iter}-{sample_idx}"))
                    .bind(&user_id)
                    .bind(&workout_id)
                    .bind(now + sample_idx as i64 * 1_000)
                    .bind(120.0 + sample_idx as f32)
                    .execute(&mut *tx)
                    .await?;
                }
                tx.commit().await?;
                Ok(())
            })
        }
    })
    .await
}

async fn bench_ep_end_workout_tx(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations.min(5_000);
    let session_mod = args.session_count.max(1);
    run_benchmark("ep_end_workout_tx", pool, args.concurrent_clients, iterations, {
        let user_ids = seeded.active_user_ids.clone();
        move |pool, worker, iter| {
            let idx = (worker * iterations + iter) % user_ids.len();
            let user_id = user_ids[idx].clone();
            let workout_id = format!("workout-{idx}");
            let session_id = format!("session-{}", idx % session_mod);
            Box::pin(async move {
                let now = now_unix();
                let mut tx = pool.begin().await?;
                sqlx::query("UPDATE workouts SET end_time = ? WHERE id = ? AND user_id = ?")
                    .bind(now)
                    .bind(&workout_id)
                    .bind(&user_id)
                    .execute(&mut *tx)
                    .await?;
                sqlx::query("DELETE FROM active_workout_current WHERE user_id = ?")
                    .bind(&user_id)
                    .execute(&mut *tx)
                    .await?;
                sqlx::query(
                    "UPDATE session_participants_current SET state_blob = ?, updated_at = ? WHERE session_id = ? AND user_id = ?",
                )
                .bind(format!(r#"{{"user":"{user_id}","workout_id":"{workout_id}","ended_at":{now}}}"#).into_bytes())
                .bind(now)
                .bind(&session_id)
                .bind(&user_id)
                .execute(&mut *tx)
                .await?;
                sqlx::query(
                    "INSERT INTO workout_events (event_id, user_id, workout_id, recorded_at, event_type, payload)
                     VALUES (?, ?, ?, ?, 9, ?)",
                )
                .bind(format!("end-event-{worker}-{iter}"))
                .bind(&user_id)
                .bind(&workout_id)
                .bind(now)
                .bind(vec![9_u8, 9, 9])
                .execute(&mut *tx)
                .await?;
                tx.commit().await?;
                Ok(())
            })
        }
    })
    .await
}
