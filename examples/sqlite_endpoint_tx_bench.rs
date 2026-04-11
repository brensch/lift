use clap::Parser;
use sqlx::sqlite::{SqliteConnectOptions, SqliteJournalMode, SqlitePoolOptions, SqliteSynchronous};
use sqlx::{Pool, Sqlite};
use std::path::PathBuf;
use std::str::FromStr;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use tokio::sync::Barrier;

#[derive(Parser, Debug, Clone)]
#[command(about = "SQLite benchmark for simplified one-transaction-per-endpoint design")]
struct Args {
    #[arg(long, default_value = "tmp/sqlite-endpoint-tx.sqlite")]
    db_path: PathBuf,
    #[arg(long, default_value_t = 20_000)]
    users: usize,
    #[arg(long, default_value_t = 5_000)]
    active_users: usize,
    #[arg(long, default_value_t = 250)]
    session_count: usize,
    #[arg(long, default_value_t = 32)]
    concurrent_clients: usize,
    #[arg(long, default_value_t = 2_000)]
    iterations: usize,
    #[arg(long, default_value_t = 4)]
    groups_per_workout: usize,
    #[arg(long, default_value_t = 4)]
    sets_per_group: usize,
    #[arg(long)]
    duration_seconds: Option<u64>,
}

const SCHEMA: &str = r#"
CREATE TABLE users (id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, created_at INTEGER NOT NULL);
CREATE TABLE auth_sessions (token TEXT PRIMARY KEY, user_id TEXT NOT NULL, created_at INTEGER NOT NULL, expires_at INTEGER NOT NULL);
CREATE TABLE workouts (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, name TEXT NOT NULL DEFAULT '', start_time INTEGER NOT NULL, end_time INTEGER, session_id TEXT);
CREATE TABLE exercise_groups (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, workout_id TEXT NOT NULL, name TEXT NOT NULL, instruction TEXT NOT NULL DEFAULT '', sets INTEGER NOT NULL, interleave_warmups BOOLEAN NOT NULL, prescribed_by_regime BOOLEAN NOT NULL DEFAULT 0, workout_order INTEGER NOT NULL, rest_success INTEGER, rest_failure INTEGER, rest_warmup INTEGER, rest_last_warmup INTEGER);
CREATE TABLE proposed_sets (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, workout_id TEXT NOT NULL, workout_order INTEGER NOT NULL, exercise INTEGER NOT NULL, target_reps INTEGER NOT NULL, target_weight REAL NOT NULL, warmup BOOLEAN NOT NULL, cancelled BOOLEAN NOT NULL DEFAULT 0, exercise_group_id TEXT, rest_after_success INTEGER, rest_after_failure INTEGER);
CREATE TABLE completed_sets (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, workout_id TEXT NOT NULL, proposed_set_id TEXT, actual_reps INTEGER NOT NULL, actual_weight REAL NOT NULL, started_at INTEGER NOT NULL, ended_at INTEGER NOT NULL, rest_until INTEGER);
CREATE TABLE workout_heart_rate_samples (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, workout_id TEXT NOT NULL, sampled_at INTEGER NOT NULL, bpm REAL NOT NULL, availability INTEGER NOT NULL, source TEXT NOT NULL DEFAULT 'wear');
CREATE TABLE workout_events (event_id TEXT PRIMARY KEY, user_id TEXT NOT NULL, workout_id TEXT NOT NULL, recorded_at INTEGER NOT NULL, event_type INTEGER NOT NULL, payload BLOB NOT NULL);
CREATE TABLE sessions (session_id TEXT NOT NULL, user_id TEXT NOT NULL, joined_at INTEGER NOT NULL, left_at INTEGER, PRIMARY KEY(session_id, user_id, joined_at));
CREATE TABLE training_program_state_latest (user_id TEXT PRIMARY KEY, regime_type INTEGER NOT NULL, latest_event_id TEXT NOT NULL, state_payload_json TEXT NOT NULL, updated_at INTEGER NOT NULL);
CREATE TABLE active_workout_current (user_id TEXT PRIMARY KEY, workout_id TEXT NOT NULL, session_id TEXT NOT NULL, name TEXT NOT NULL, started_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
CREATE TABLE workout_snapshot_current (user_id TEXT PRIMARY KEY, workout_id TEXT NOT NULL, session_id TEXT NOT NULL, snapshot_blob BLOB NOT NULL, updated_at INTEGER NOT NULL);
CREATE TABLE session_participants_current (session_id TEXT NOT NULL, user_id TEXT NOT NULL, workout_id TEXT NOT NULL, user_name TEXT NOT NULL, state_blob BLOB NOT NULL, updated_at INTEGER NOT NULL, PRIMARY KEY (session_id, user_id));
CREATE TABLE proposed_schedule_cache (user_id TEXT PRIMARY KEY, active_workout_id TEXT, response_blob BLOB NOT NULL, updated_at INTEGER NOT NULL);
CREATE INDEX idx_auth_sessions_token ON auth_sessions(token);
CREATE INDEX idx_active_workout_current_session ON active_workout_current(session_id, user_id);
CREATE INDEX idx_session_participants_current_session ON session_participants_current(session_id, updated_at DESC);
CREATE INDEX idx_proposed_schedule_cache_user ON proposed_schedule_cache(user_id);
CREATE INDEX idx_workout_events_user_workout_time ON workout_events(user_id, workout_id, recorded_at, event_id);
CREATE INDEX idx_hr_samples_user_workout_time ON workout_heart_rate_samples(user_id, workout_id, sampled_at);
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
    p95_ms: u64,
    p99_ms: u64,
}

struct TimedMethodStats {
    ops: AtomicU64,
    errors: AtomicU64,
    total_latency_ms: AtomicU64,
    max_latency_ms: AtomicU64,
}

impl TimedMethodStats {
    fn new() -> Self {
        Self {
            ops: AtomicU64::new(0),
            errors: AtomicU64::new(0),
            total_latency_ms: AtomicU64::new(0),
            max_latency_ms: AtomicU64::new(0),
        }
    }

    fn record(&self, latency: Duration, is_error: bool) {
        self.ops.fetch_add(1, Ordering::Relaxed);
        if is_error {
            self.errors.fetch_add(1, Ordering::Relaxed);
            return;
        }
        let ms = latency.as_millis() as u64;
        self.total_latency_ms.fetch_add(ms, Ordering::Relaxed);
        let mut current = self.max_latency_ms.load(Ordering::Relaxed);
        while ms > current {
            match self.max_latency_ms.compare_exchange_weak(
                current,
                ms,
                Ordering::Relaxed,
                Ordering::Relaxed,
            ) {
                Ok(_) => break,
                Err(actual) => current = actual,
            }
        }
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let args = Args::parse();
    if let Some(parent) = args.db_path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    if args.db_path.exists() {
        std::fs::remove_file(&args.db_path)?;
    }

    let pool = open_pool(&args.db_path).await?;
    sqlx::query(SCHEMA).execute(&pool).await?;
    let seeded = seed_database(&pool, &args).await?;

    if let Some(duration_seconds) = args.duration_seconds {
        run_timed_mix(&pool, &seeded, &args, duration_seconds).await?;
        return Ok(());
    }

    let results = vec![
        bench_ep_validate_auth_session(&pool, &seeded, &args).await?,
        bench_ep_get_active_workout(&pool, &seeded, &args).await?,
        bench_ep_get_current_session(&pool, &seeded, &args).await?,
        bench_ep_get_proposed_schedule(&pool, &seeded, &args).await?,
        bench_ep_test_login_tx(&pool, &args).await?,
        bench_ep_join_session_tx(&pool, &seeded, &args).await?,
        bench_ep_start_workout_tx(&pool, &seeded, &args).await?,
        bench_ep_append_mutation_tx(&pool, &seeded, &args).await?,
        bench_ep_append_heart_rate_tx(&pool, &seeded, &args).await?,
        bench_ep_end_workout_tx(&pool, &seeded, &args).await?,
    ];

    println!("SQLite endpoint-tx benchmark");
    println!(
        "seeded: users={}, active_users={}, sessions={}, concurrent_clients={}, iterations/client={}",
        args.users, args.active_users, args.session_count, args.concurrent_clients, args.iterations
    );
    println!();
    for result in results {
        let ops_per_sec = result.total_ops as f64 / result.elapsed.as_secs_f64();
        println!(
            "{:<22} ops={:<7} ops/s={:>9.1} avg={:>7.3}ms p95={:>4}ms p99={:>4}ms",
            result.name, result.total_ops, ops_per_sec, result.avg_ms, result.p95_ms, result.p99_ms
        );
    }
    Ok(())
}

async fn run_timed_mix(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
    duration_seconds: u64,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let methods: Arc<Vec<(&'static str, Arc<TimedMethodStats>)>> = Arc::new(vec![
        ("ep_validate_auth", Arc::new(TimedMethodStats::new())),
        ("ep_get_active", Arc::new(TimedMethodStats::new())),
        ("ep_get_session", Arc::new(TimedMethodStats::new())),
        ("ep_get_schedule", Arc::new(TimedMethodStats::new())),
        ("ep_join_session_tx", Arc::new(TimedMethodStats::new())),
        ("ep_start_workout_tx", Arc::new(TimedMethodStats::new())),
        ("ep_append_mut_tx", Arc::new(TimedMethodStats::new())),
        ("ep_append_hr_tx", Arc::new(TimedMethodStats::new())),
        ("ep_end_workout_tx", Arc::new(TimedMethodStats::new())),
    ]);
    let end_at = Instant::now() + Duration::from_secs(duration_seconds);
    let barrier = Arc::new(Barrier::new(args.concurrent_clients + 1));
    let mut joins = Vec::with_capacity(args.concurrent_clients);

    println!("SQLite endpoint-tx timed mix");
    println!(
        "seeded: users={}, active_users={}, sessions={}, concurrent_clients={}, duration={}s",
        args.users,
        args.active_users,
        args.session_count,
        args.concurrent_clients,
        duration_seconds
    );

    for worker in 0..args.concurrent_clients {
        let pool = pool.clone();
        let seeded = seeded.clone();
        let methods = methods.clone();
        let barrier = barrier.clone();
        let groups_per_workout = args.groups_per_workout;
        let sets_per_group = args.sets_per_group;
        let session_count = args.session_count.max(1);
        joins.push(tokio::spawn(async move {
            barrier.wait().await;
            let mut iter = 0usize;
            while Instant::now() < end_at {
                let choice = iter % 9;
                let started = Instant::now();
                let result: Result<(), sqlx::Error> = match choice {
                    0 => {
                        let idx = (worker + iter) % seeded.token_pairs.len();
                        let token = seeded.token_pairs[idx].0.clone();
                        sqlx::query_as::<_, (String,)>(
                            "SELECT user_id FROM auth_sessions WHERE token = ? AND expires_at > ?",
                        )
                        .bind(token)
                        .bind(now_unix())
                        .fetch_optional(&pool)
                        .await
                        .map(|_| ())
                    }
                    1 => {
                        let idx = (worker + iter) % seeded.active_user_ids.len();
                        let user_id = seeded.active_user_ids[idx].clone();
                        sqlx::query(
                            "SELECT workout_id, session_id, name, started_at, updated_at FROM active_workout_current WHERE user_id = ?",
                        )
                        .bind(user_id)
                        .fetch_optional(&pool)
                        .await
                        .map(|_| ())
                    }
                    2 => {
                        let idx = (worker + iter) % seeded.session_ids.len();
                        let session_id = seeded.session_ids[idx].clone();
                        sqlx::query(
                            "SELECT user_id, workout_id, user_name, state_blob, updated_at FROM session_participants_current WHERE session_id = ? ORDER BY updated_at DESC, user_id",
                        )
                        .bind(session_id)
                        .fetch_all(&pool)
                        .await
                        .map(|_| ())
                    }
                    3 => {
                        let idx = (worker + iter) % seeded.token_pairs.len();
                        let user_id = seeded.token_pairs[idx].1.clone();
                        sqlx::query(
                            "SELECT active_workout_id, response_blob, updated_at FROM proposed_schedule_cache WHERE user_id = ?",
                        )
                        .bind(user_id)
                        .fetch_optional(&pool)
                        .await
                        .map(|_| ())
                    }
                    4 => {
                        let idx = (worker + iter) % seeded.active_user_ids.len();
                        let user_id = seeded.active_user_ids[idx].clone();
                        let session_id = format!("timed-join-session-{}", idx % session_count);
                        let now = now_unix_millis() + (worker as i64 * 1_000_000) + iter as i64;
                        let mut tx = pool.begin().await?;
                        sqlx::query("UPDATE sessions SET left_at = ? WHERE user_id = ? AND left_at IS NULL")
                            .bind(now)
                            .bind(&user_id)
                            .execute(&mut *tx)
                            .await?;
                        sqlx::query("INSERT INTO sessions (session_id, user_id, joined_at, left_at) VALUES (?, ?, ?, NULL)")
                            .bind(&session_id)
                            .bind(&user_id)
                            .bind(now)
                            .execute(&mut *tx)
                            .await?;
                        sqlx::query("INSERT OR REPLACE INTO session_participants_current (session_id, user_id, workout_id, user_name, state_blob, updated_at) VALUES (?, ?, ?, ?, ?, ?)")
                            .bind(&session_id)
                            .bind(&user_id)
                            .bind(format!("workout-{idx}"))
                            .bind(format!("bench_user_{idx}"))
                            .bind(format!(r#"{{"user":"{user_id}","joined_at":{now}}}"#).into_bytes())
                            .bind(now)
                            .execute(&mut *tx)
                            .await?;
                        tx.commit().await.map(|_| ())
                    }
                    5 => {
                        let idx = (worker + iter) % seeded.active_user_ids.len();
                        let user_id = seeded.active_user_ids[idx].clone();
                        let session_id = format!("session-{}", idx % session_count);
                        let now = now_unix();
                        let workout_id = format!("timed-start-workout-{worker}-{iter}");
                        let mut tx = pool.begin().await?;
                        sqlx::query("INSERT INTO workouts (id, user_id, name, start_time, end_time, session_id) VALUES (?, ?, ?, ?, NULL, ?)")
                            .bind(&workout_id)
                            .bind(&user_id)
                            .bind("Timed Benchmark Workout")
                            .bind(now)
                            .bind(&session_id)
                            .execute(&mut *tx)
                            .await?;
                        sqlx::query("INSERT OR REPLACE INTO active_workout_current (user_id, workout_id, session_id, name, started_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)")
                            .bind(&user_id)
                            .bind(&workout_id)
                            .bind(&session_id)
                            .bind("Timed Benchmark Workout")
                            .bind(now)
                            .bind(now)
                            .execute(&mut *tx)
                            .await?;
                        for g in 0..groups_per_workout {
                            let group_id = format!("timed-group-{worker}-{iter}-{g}");
                            sqlx::query("INSERT INTO exercise_groups (id, user_id, workout_id, name, instruction, sets, interleave_warmups, prescribed_by_regime, workout_order, rest_success, rest_failure, rest_warmup, rest_last_warmup) VALUES (?, ?, ?, ?, '', ?, 0, 0, ?, 180, 300, 90, 120)")
                                .bind(&group_id)
                                .bind(&user_id)
                                .bind(&workout_id)
                                .bind(format!("Group {g}"))
                                .bind(sets_per_group as i32)
                                .bind(g as i32)
                                .execute(&mut *tx)
                                .await?;
                            for s in 0..sets_per_group {
                                sqlx::query("INSERT INTO proposed_sets (id, user_id, workout_id, workout_order, exercise, target_reps, target_weight, warmup, cancelled, exercise_group_id, rest_after_success, rest_after_failure) VALUES (?, ?, ?, ?, 1, 5, 135.0, 0, 0, ?, 180, 300)")
                                    .bind(format!("timed-ps-{worker}-{iter}-{g}-{s}"))
                                    .bind(&user_id)
                                    .bind(&workout_id)
                                    .bind((g * sets_per_group + s) as i32)
                                    .bind(&group_id)
                                    .execute(&mut *tx)
                                    .await?;
                            }
                        }
                        tx.commit().await.map(|_| ())
                    }
                    6 => {
                        let idx = (worker + iter) % seeded.active_user_ids.len();
                        let user_id = seeded.active_user_ids[idx].clone();
                        let workout_id = format!("workout-{idx}");
                        let session_id = format!("session-{}", idx % session_count);
                        let now = now_unix();
                        let event_id = format!("timed-mut-{worker}-{iter}");
                        let mut tx = pool.begin().await?;
                        sqlx::query("INSERT INTO workout_events (event_id, user_id, workout_id, recorded_at, event_type, payload) VALUES (?, ?, ?, ?, 1, ?)")
                            .bind(&event_id)
                            .bind(&user_id)
                            .bind(&workout_id)
                            .bind(now)
                            .bind(vec![1_u8, 2, 3, (iter % 255) as u8])
                            .execute(&mut *tx)
                            .await?;
                        sqlx::query("UPDATE workout_snapshot_current SET snapshot_blob = ?, updated_at = ? WHERE user_id = ?")
                            .bind(format!(r#"{{"workout_id":"{workout_id}","last_event":"{event_id}"}}"#).into_bytes())
                            .bind(now)
                            .bind(&user_id)
                            .execute(&mut *tx)
                            .await?;
                        sqlx::query("UPDATE session_participants_current SET state_blob = ?, updated_at = ? WHERE session_id = ? AND user_id = ?")
                            .bind(format!(r#"{{"user":"{user_id}","workout_id":"{workout_id}","last_event":"{event_id}"}}"#).into_bytes())
                            .bind(now)
                            .bind(&session_id)
                            .bind(&user_id)
                            .execute(&mut *tx)
                            .await?;
                        tx.commit().await.map(|_| ())
                    }
                    7 => {
                        let idx = (worker + iter) % seeded.active_user_ids.len();
                        let user_id = seeded.active_user_ids[idx].clone();
                        let workout_id = format!("workout-{idx}");
                        let now = now_unix_millis();
                        let mut tx = pool.begin().await?;
                        for sample_idx in 0..5 {
                            sqlx::query("INSERT INTO workout_heart_rate_samples (id, user_id, workout_id, sampled_at, bpm, availability, source) VALUES (?, ?, ?, ?, ?, 1, 'wear')")
                                .bind(format!("timed-hr-{worker}-{iter}-{sample_idx}"))
                                .bind(&user_id)
                                .bind(&workout_id)
                                .bind(now + sample_idx as i64 * 1000)
                                .bind(120.0 + sample_idx as f32)
                                .execute(&mut *tx)
                                .await?;
                        }
                        tx.commit().await.map(|_| ())
                    }
                    _ => {
                        let idx = (worker + iter) % seeded.active_user_ids.len();
                        let user_id = seeded.active_user_ids[idx].clone();
                        let workout_id = format!("workout-{idx}");
                        let session_id = format!("session-{}", idx % session_count);
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
                        sqlx::query("UPDATE session_participants_current SET state_blob = ?, updated_at = ? WHERE session_id = ? AND user_id = ?")
                            .bind(format!(r#"{{"user":"{user_id}","workout_id":"{workout_id}","ended_at":{now}}}"#).into_bytes())
                            .bind(now)
                            .bind(&session_id)
                            .bind(&user_id)
                            .execute(&mut *tx)
                            .await?;
                        tx.commit().await.map(|_| ())
                    }
                };
                methods[choice].1.record(started.elapsed(), result.is_err());
                iter += 1;
            }
            Ok::<(), sqlx::Error>(())
        }));
    }

    barrier.wait().await;
    let started = Instant::now();
    let mut last_counts = vec![0_u64; methods.len()];
    while Instant::now() < end_at {
        tokio::time::sleep(Duration::from_secs(5)).await;
        println!("\n[{:.0}s]", started.elapsed().as_secs_f64());
        for (i, (name, stats)) in methods.iter().enumerate() {
            let ops = stats.ops.load(Ordering::Relaxed);
            let interval_ops = ops.saturating_sub(last_counts[i]);
            last_counts[i] = ops;
            let avg = if ops > 0 {
                stats.total_latency_ms.load(Ordering::Relaxed) as f64 / ops as f64
            } else {
                0.0
            };
            println!(
                "  {:20} qps={:7.1} avg={:7.3}ms max={:4}ms err={}",
                name,
                interval_ops as f64 / 5.0,
                avg,
                stats.max_latency_ms.load(Ordering::Relaxed),
                stats.errors.load(Ordering::Relaxed)
            );
        }
    }

    for join in joins {
        join.await??;
    }

    println!("\nFinal DB size:");
    for suffix in ["", "-wal", "-shm"] {
        let path = format!("{}{}", args.db_path.display(), suffix);
        if let Ok(meta) = std::fs::metadata(&path) {
            println!("  {}: {} bytes", path, meta.len());
        }
    }

    Ok(())
}

async fn open_pool(
    path: &PathBuf,
) -> Result<Pool<Sqlite>, Box<dyn std::error::Error + Send + Sync>> {
    let db_url = format!("sqlite://{}", path.display());
    let options = SqliteConnectOptions::from_str(&db_url)?
        .create_if_missing(true)
        .journal_mode(SqliteJournalMode::Wal)
        .synchronous(SqliteSynchronous::Normal)
        .busy_timeout(Duration::from_secs(30));
    Ok(SqlitePoolOptions::new()
        .max_connections(32)
        .connect_with(options)
        .await?)
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
        sqlx::query("INSERT INTO auth_sessions (token, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)")
            .bind(&token)
            .bind(&user_id)
            .bind(now)
            .bind(now + 30 * 24 * 60 * 60)
            .execute(&mut *tx)
            .await?;
        token_pairs.push((token, user_id.clone()));
        sqlx::query("INSERT INTO training_program_state_latest (user_id, regime_type, latest_event_id, state_payload_json, updated_at) VALUES (?, 1, ?, ?, ?)")
            .bind(&user_id)
            .bind(format!("state-event-{i}"))
            .bind(r#"{"week":1,"cycle":1}"#)
            .bind(now)
            .execute(&mut *tx)
            .await?;

        let workout_id = format!("workout-{i}");
        let active = i < args.active_users;
        let session_id = if active {
            Some(session_ids[i % session_ids.len()].clone())
        } else {
            None
        };
        if active {
            active_user_ids.push(user_id.clone());
        }

        sqlx::query("INSERT INTO workouts (id, user_id, name, start_time, end_time, session_id) VALUES (?, ?, ?, ?, ?, ?)")
            .bind(&workout_id)
            .bind(&user_id)
            .bind("Bench Workout")
            .bind(now - 3600)
            .bind(if active { None } else { Some(now - 86400) })
            .bind(session_id.as_deref())
            .execute(&mut *tx)
            .await?;
        sqlx::query("INSERT INTO proposed_schedule_cache (user_id, active_workout_id, response_blob, updated_at) VALUES (?, ?, ?, ?)")
            .bind(&user_id)
            .bind(if active { Some(workout_id.as_str()) } else { None })
            .bind(format!(r#"{{"user_id":"{user_id}","groups":{}}}"#, args.groups_per_workout).into_bytes())
            .bind(now)
            .execute(&mut *tx)
            .await?;

        if let Some(sid) = session_id.as_ref() {
            sqlx::query("INSERT INTO sessions (session_id, user_id, joined_at, left_at) VALUES (?, ?, ?, NULL)")
                .bind(sid)
                .bind(&user_id)
                .bind(now - 3600)
                .execute(&mut *tx)
                .await?;
            sqlx::query("INSERT INTO active_workout_current (user_id, workout_id, session_id, name, started_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)")
                .bind(&user_id)
                .bind(&workout_id)
                .bind(sid)
                .bind("Bench Workout")
                .bind(now - 3600)
                .bind(now)
                .execute(&mut *tx)
                .await?;
            sqlx::query("INSERT INTO workout_snapshot_current (user_id, workout_id, session_id, snapshot_blob, updated_at) VALUES (?, ?, ?, ?, ?)")
                .bind(&user_id)
                .bind(&workout_id)
                .bind(sid)
                .bind(format!(r#"{{"workout_id":"{workout_id}"}}"#).into_bytes())
                .bind(now)
                .execute(&mut *tx)
                .await?;
            sqlx::query("INSERT INTO session_participants_current (session_id, user_id, workout_id, user_name, state_blob, updated_at) VALUES (?, ?, ?, ?, ?, ?)")
                .bind(sid)
                .bind(&user_id)
                .bind(&workout_id)
                .bind(&username)
                .bind(format!(r#"{{"user":"{user_id}","workout_id":"{workout_id}"}}"#).into_bytes())
                .bind(now)
                .execute(&mut *tx)
                .await?;
        }
    }

    tx.commit().await?;
    Ok(SeededState {
        active_user_ids: Arc::new(active_user_ids),
        session_ids: Arc::new(session_ids),
        token_pairs: Arc::new(token_pairs),
    })
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
    run_benchmark("ep_get_active", pool, args.concurrent_clients, iterations, {
        let user_ids = seeded.active_user_ids.clone();
        move |pool, worker, iter| {
            let idx = (worker * iterations + iter) % user_ids.len();
            let user_id = user_ids[idx].clone();
            Box::pin(async move {
                let _ = sqlx::query("SELECT workout_id, session_id, name, started_at, updated_at FROM active_workout_current WHERE user_id = ?")
                    .bind(user_id)
                    .fetch_optional(&pool)
                    .await?;
                Ok(())
            })
        }
    }).await
}

async fn bench_ep_get_current_session(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations;
    run_benchmark("ep_get_session", pool, args.concurrent_clients, iterations, {
        let session_ids = seeded.session_ids.clone();
        move |pool, worker, iter| {
            let idx = (worker * iterations + iter) % session_ids.len();
            let session_id = session_ids[idx].clone();
            Box::pin(async move {
                let _ = sqlx::query("SELECT user_id, workout_id, user_name, state_blob, updated_at FROM session_participants_current WHERE session_id = ? ORDER BY updated_at DESC, user_id")
                    .bind(session_id)
                    .fetch_all(&pool)
                    .await?;
                Ok(())
            })
        }
    }).await
}

async fn bench_ep_get_proposed_schedule(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations;
    run_benchmark("ep_get_schedule", pool, args.concurrent_clients, iterations, {
        let token_pairs = seeded.token_pairs.clone();
        move |pool, worker, iter| {
            let idx = (worker * iterations + iter) % token_pairs.len();
            let user_id = token_pairs[idx].1.clone();
            Box::pin(async move {
                let _ = sqlx::query("SELECT active_workout_id, response_blob, updated_at FROM proposed_schedule_cache WHERE user_id = ?")
                    .bind(user_id)
                    .fetch_optional(&pool)
                    .await?;
                Ok(())
            })
        }
    }).await
}

async fn bench_ep_test_login_tx(
    pool: &Pool<Sqlite>,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations.min(3_000);
    run_benchmark("ep_test_login_tx", pool, args.concurrent_clients, iterations, {
        move |pool, worker, iter| Box::pin(async move {
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
            sqlx::query("INSERT INTO auth_sessions (token, user_id, created_at, expires_at) VALUES (?, ?, ?, ?)")
                .bind(&token)
                .bind(&user_id)
                .bind(now)
                .bind(now + 30 * 24 * 60 * 60)
                .execute(&mut *tx)
                .await?;
            sqlx::query("INSERT INTO training_program_state_latest (user_id, regime_type, latest_event_id, state_payload_json, updated_at) VALUES (?, 1, ?, ?, ?)")
                .bind(&user_id)
                .bind(format!("login-state-{worker}-{iter}"))
                .bind(r#"{"week":1,"cycle":1}"#)
                .bind(now)
                .execute(&mut *tx)
                .await?;
            tx.commit().await?;
            Ok(())
        })
    }).await
}

async fn bench_ep_join_session_tx(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations;
    run_benchmark("ep_join_session_tx", pool, args.concurrent_clients, iterations, {
        let user_ids = seeded.active_user_ids.clone();
        let session_count = args.session_count.max(1);
        move |pool, worker, iter| {
            let idx = (worker * iterations + iter) % user_ids.len();
            let user_id = user_ids[idx].clone();
            let session_id = format!("join-session-{}", idx % session_count);
            Box::pin(async move {
                let now = now_unix_millis() + (worker as i64 * 1_000_000) + iter as i64;
                let mut tx = pool.begin().await?;
                sqlx::query("UPDATE sessions SET left_at = ? WHERE user_id = ? AND left_at IS NULL")
                    .bind(now)
                    .bind(&user_id)
                    .execute(&mut *tx)
                    .await?;
                sqlx::query("INSERT INTO sessions (session_id, user_id, joined_at, left_at) VALUES (?, ?, ?, NULL)")
                    .bind(&session_id)
                    .bind(&user_id)
                    .bind(now)
                    .execute(&mut *tx)
                    .await?;
                sqlx::query("INSERT OR REPLACE INTO session_participants_current (session_id, user_id, workout_id, user_name, state_blob, updated_at) VALUES (?, ?, ?, ?, ?, ?)")
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
    }).await
}

async fn bench_ep_start_workout_tx(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations.min(3_000);
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
                sqlx::query("INSERT INTO workouts (id, user_id, name, start_time, end_time, session_id) VALUES (?, ?, ?, ?, NULL, ?)")
                    .bind(&workout_id)
                    .bind(&user_id)
                    .bind("Benchmark Workout")
                    .bind(now)
                    .bind(&session_id)
                    .execute(&mut *tx)
                    .await?;
                sqlx::query("INSERT OR REPLACE INTO active_workout_current (user_id, workout_id, session_id, name, started_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)")
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
                    sqlx::query("INSERT INTO exercise_groups (id, user_id, workout_id, name, instruction, sets, interleave_warmups, prescribed_by_regime, workout_order, rest_success, rest_failure, rest_warmup, rest_last_warmup) VALUES (?, ?, ?, ?, '', ?, 0, 0, ?, 180, 300, 90, 120)")
                        .bind(&group_id)
                        .bind(&user_id)
                        .bind(&workout_id)
                        .bind(format!("Group {g}"))
                        .bind(sets_per_group as i32)
                        .bind(g as i32)
                        .execute(&mut *tx)
                        .await?;
                    for s in 0..sets_per_group {
                        sqlx::query("INSERT INTO proposed_sets (id, user_id, workout_id, workout_order, exercise, target_reps, target_weight, warmup, cancelled, exercise_group_id, rest_after_success, rest_after_failure) VALUES (?, ?, ?, ?, 1, 5, 135.0, 0, 0, ?, 180, 300)")
                            .bind(format!("start-ps-{worker}-{iter}-{g}-{s}"))
                            .bind(&user_id)
                            .bind(&workout_id)
                            .bind((g * sets_per_group + s) as i32)
                            .bind(&group_id)
                            .execute(&mut *tx)
                            .await?;
                    }
                }
                sqlx::query("INSERT OR REPLACE INTO workout_snapshot_current (user_id, workout_id, session_id, snapshot_blob, updated_at) VALUES (?, ?, ?, ?, ?)")
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
    }).await
}

async fn bench_ep_append_mutation_tx(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations;
    run_benchmark("ep_append_mut_tx", pool, args.concurrent_clients, iterations, {
        let user_ids = seeded.active_user_ids.clone();
        let session_count = args.session_count.max(1);
        move |pool, worker, iter| {
            let idx = (worker * iterations + iter) % user_ids.len();
            let user_id = user_ids[idx].clone();
            let workout_id = format!("workout-{idx}");
            let session_id = format!("session-{}", idx % session_count);
            Box::pin(async move {
                let now = now_unix();
                let event_id = format!("ep-mut-{worker}-{iter}");
                let mut tx = pool.begin().await?;
                sqlx::query("INSERT INTO workout_events (event_id, user_id, workout_id, recorded_at, event_type, payload) VALUES (?, ?, ?, ?, 1, ?)")
                    .bind(&event_id)
                    .bind(&user_id)
                    .bind(&workout_id)
                    .bind(now)
                    .bind(vec![1_u8, 2, 3, (iter % 255) as u8])
                    .execute(&mut *tx)
                    .await?;
                sqlx::query("UPDATE workout_snapshot_current SET snapshot_blob = ?, updated_at = ? WHERE user_id = ?")
                    .bind(format!(r#"{{"workout_id":"{workout_id}","last_event":"{event_id}","updated_at":{now}}}"#).into_bytes())
                    .bind(now)
                    .bind(&user_id)
                    .execute(&mut *tx)
                    .await?;
                sqlx::query("UPDATE session_participants_current SET state_blob = ?, updated_at = ? WHERE session_id = ? AND user_id = ?")
                    .bind(format!(r#"{{"user":"{user_id}","workout_id":"{workout_id}","last_event":"{event_id}"}}"#).into_bytes())
                    .bind(now)
                    .bind(&session_id)
                    .bind(&user_id)
                    .execute(&mut *tx)
                    .await?;
                tx.commit().await?;
                Ok(())
            })
        }
    }).await
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
                    sqlx::query("INSERT INTO workout_heart_rate_samples (id, user_id, workout_id, sampled_at, bpm, availability, source) VALUES (?, ?, ?, ?, ?, 1, 'wear')")
                        .bind(format!("hr-{worker}-{iter}-{sample_idx}"))
                        .bind(&user_id)
                        .bind(&workout_id)
                        .bind(now + sample_idx as i64 * 1000)
                        .bind(120.0 + sample_idx as f32)
                        .execute(&mut *tx)
                        .await?;
                }
                tx.commit().await?;
                Ok(())
            })
        }
    }).await
}

async fn bench_ep_end_workout_tx(
    pool: &Pool<Sqlite>,
    seeded: &SeededState,
    args: &Args,
) -> Result<BenchResult, Box<dyn std::error::Error + Send + Sync>> {
    let iterations = args.iterations.min(3_000);
    run_benchmark("ep_end_workout_tx", pool, args.concurrent_clients, iterations, {
        let user_ids = seeded.active_user_ids.clone();
        let session_count = args.session_count.max(1);
        move |pool, worker, iter| {
            let idx = (worker * iterations + iter) % user_ids.len();
            let user_id = user_ids[idx].clone();
            let workout_id = format!("workout-{idx}");
            let session_id = format!("session-{}", idx % session_count);
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
                sqlx::query("UPDATE session_participants_current SET state_blob = ?, updated_at = ? WHERE session_id = ? AND user_id = ?")
                    .bind(format!(r#"{{"user":"{user_id}","workout_id":"{workout_id}","ended_at":{now}}}"#).into_bytes())
                    .bind(now)
                    .bind(&session_id)
                    .bind(&user_id)
                    .execute(&mut *tx)
                    .await?;
                sqlx::query("INSERT INTO workout_events (event_id, user_id, workout_id, recorded_at, event_type, payload) VALUES (?, ?, ?, ?, 9, ?)")
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
    }).await
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
                let started = Instant::now();
                factory(pool.clone(), worker, iter).await?;
                latencies.push(started.elapsed().as_millis() as u64);
            }
            Ok::<Vec<u64>, sqlx::Error>(latencies)
        }));
    }

    barrier.wait().await;
    let started = Instant::now();
    let mut latencies = Vec::with_capacity(concurrent_clients * iterations);
    for join in joins {
        latencies.extend(join.await??);
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
