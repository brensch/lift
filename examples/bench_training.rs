//! Benchmark: v2 row-level ops vs the v1 whole-workout-rewrite path.
//!
//! The v1 mutation flush (`AppendWorkoutMutations`) and structural edits
//! (`ReplaceExerciseGroupPlan`) both load the whole workout, delete every set,
//! and reinsert every set — O(N) in the workout's size, per operation. The v2
//! `MutateWorkout` applies each op as a row-level INSERT/UPDATE — O(1).
//!
//! This spawns a real backend and measures true gRPC latency for "apply one
//! mutation" and "edit one set", across workout sizes, on both APIs.
//!
//!   cargo run --release --example bench_training
//!
//! Runs are deliberately short (a few seconds total) — this is meant to be run
//! on a working machine without tanking it.
//!
//! Representative result (WSL2 dev box, DB on tmpfs; latency in ms):
//!
//!   per op (1 op/call):   v1 grows 44 → 56 with size (O(N) rewrite);
//!                         v2 flat ~44 (O(1)).
//!   full session:         v1 N calls   v2 N calls   v2 1 call   DB-only / +batch
//!     5 sets                  224          220          48        1.0x /  4.7x
//!    15 sets                  720          660          52        1.1x / 13.8x
//!    48 sets                 2516         2072          72        1.2x / 34.9x
//!   100 sets                 5992         4364         104        1.4x / 57.6x
//!
//! Reading it honestly:
//!  - A fixed ~44ms per-round-trip floor sits on every call (same for v1 and v2;
//!    a WSL2 localhost artifact — sub-ms on a real server). It masks the per-op
//!    DB difference in wall-clock until you batch or run on a faster RTT.
//!  - DB-only (both doing N calls): v2 is strictly cheaper and the gap widens
//!    with size, because v1 rewrites the whole workout each op (O(N)) while v2
//!    is one row (O(1)). Over a full session that is O(N²) vs O(N).
//!  - The op-list lets a whole session flush in ONE round-trip (v2 "1 call"),
//!    collapsing N requests/transactions to one — the dominant real-world win,
//!    and strictly less load on the machine.

use std::process::{Child, Command, Stdio};
use std::time::Instant;

use schlift::workout::v1::auth_service_client::AuthServiceClient;
use schlift::workout::v1::training_service_client::TrainingServiceClient;
use schlift::workout::v1::workout_service_client::WorkoutServiceClient;
use schlift::workout::v1::workout_op::Op;
use schlift::workout::v1::*;
use tonic::transport::Channel;
use tonic::Request;

const PORT: u16 = 51_070;
const ITERS: usize = 150;
const WARMUP: usize = 20;

struct Backend {
    child: Option<Child>,
    dir: std::path::PathBuf,
}
impl Drop for Backend {
    fn drop(&mut self) {
        if let Some(c) = self.child.as_mut() {
            let _ = c.kill();
            let _ = c.wait();
        }
        let _ = std::fs::remove_dir_all(&self.dir);
    }
}

fn authed<T>(token: &str, msg: T) -> Request<T> {
    let mut r = Request::new(msg);
    r.metadata_mut().insert("x-session-token", token.parse().unwrap());
    r
}

fn v1_groups(blocks: usize, sets_per: i32) -> Vec<ExerciseGroup> {
    (0..blocks)
        .map(|i| ExerciseGroup {
            id: String::new(),
            workout_id: String::new(),
            name: format!("Block {i}"),
            sets: sets_per,
            interleave_warmups: false,
            workout_order: i as i32,
            exercise_configs: vec![ExerciseTypeConfig {
                exercise: Exercise::Squat as i32,
                start_weight: 135.0,
                end_weight: 135.0,
                reps: 5,
                include_warmup: false,
                rest_config: None,
                last_set_amrap: false,
                working_sets: Vec::new(),
            }],
            rest_config: None,
            instruction: String::new(),
            prescribed_by_regime: false,
            materialized_sets: Vec::new(),
        })
        .collect()
}

fn v2_blocks(blocks: usize, sets_per: usize) -> Vec<BlockPlan> {
    (0..blocks)
        .map(|i| BlockPlan {
            name: format!("Block {i}"),
            interleave_warmups: false,
            rest_config: None,
            sets: (0..sets_per)
                .map(|_| SetPlan {
                    exercise: Exercise::Squat as i32,
                    role: SetRole::Working as i32,
                    target: Some(Measure { weight: 135.0, reps: 5, duration_s: 0, distance_m: 0.0 }),
                    is_amrap: false,
                    instruction: String::new(),
                    counts_toward_program: true,
                    slot_key: String::new(),
                    client_id: String::new(),
                })
                .collect(),
        })
        .collect()
}

/// mean and p90 (ms) of a set of durations
fn stats(mut samples: Vec<f64>) -> (f64, f64) {
    samples.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let mean = samples.iter().sum::<f64>() / samples.len() as f64;
    let p90 = samples[(samples.len() as f64 * 0.9) as usize];
    (mean, p90)
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Build with test-auth for TestLogin.
    println!("building backend (--features test-auth --release)…");
    let status = Command::new("cargo")
        .args(["build", "--bin", "schlift", "--features", "test-auth", "--release"])
        .status()?;
    assert!(status.success());

    // RAM-backed storage so per-commit fsync doesn't dominate (representative of
    // a production SSD). Falls back to the temp dir if /dev/shm is absent.
    let shm = std::path::Path::new("/dev/shm");
    let base = if shm.is_dir() { shm.to_path_buf() } else { std::env::temp_dir() };
    let dir = base.join(format!("lift-bench-{}", std::process::id()));
    std::fs::create_dir_all(&dir)?;
    let child = Command::new("target/release/schlift")
        .env("DATA_DIR", dir.join("data"))
        .env("PORT", PORT.to_string())
        .env("RUST_LOG", "error")
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()?;
    let _backend = Backend { child: Some(child), dir };

    let endpoint = format!("http://127.0.0.1:{PORT}");
    let channel = loop_connect(&endpoint).await?;
    let mut auth = AuthServiceClient::new(channel.clone());
    let mut wk = WorkoutServiceClient::new(channel.clone());
    let mut tr = TrainingServiceClient::new(channel.clone());

    let token = auth
        .test_login(Request::new(TestLoginRequest { username: "bench".to_string() }))
        .await?
        .into_inner()
        .session_token;

    let sizes: &[(usize, usize)] = &[(1, 5), (3, 5), (6, 8), (10, 10)];

    println!("\n{ITERS} timed ops each (after {WARMUP} warmup). latency in ms.\n");
    println!(
        "{:<10} {:<6} | {:>22} | {:>22} | {:>8}",
        "workout", "sets", "v1 AppendMutations(1)", "v2 MutateWorkout(1)", "speedup"
    );
    println!("{}", "-".repeat(80));

    for &(blocks, sets_per) in sizes {
        let n = blocks * sets_per;

        // ── v1: one mutation flush against an N-set workout ──
        let start = wk
            .start_workout(authed(&token, StartWorkoutRequest {
                name: "v1".to_string(),
                exercise_groups: v1_groups(blocks, sets_per as i32),
                started_at: 0,
            }))
            .await?
            .into_inner();
        let v1_id = start.id.clone();
        let a_set = start.proposed_sets.first().map(|s| s.id.clone()).unwrap_or_default();
        let v1_mut = |set_id: String, wid: String| AppendWorkoutMutationsRequest {
            mutations: vec![WorkoutMutation {
                event_id: uuid::Uuid::new_v4().to_string(),
                client_created_at: 0,
                mutation: Some(workout_mutation::Mutation::StartSet(StartSetRequest {
                    workout_id: wid,
                    proposed_set_id: set_id,
                    started_at: 1,
                })),
            }],
        };
        for _ in 0..WARMUP {
            let _ = wk.append_workout_mutations(authed(&token, v1_mut(a_set.clone(), v1_id.clone()))).await?;
        }
        let mut v1_samples = Vec::with_capacity(ITERS);
        for _ in 0..ITERS {
            let t = Instant::now();
            wk.append_workout_mutations(authed(&token, v1_mut(a_set.clone(), v1_id.clone()))).await?;
            v1_samples.push(t.elapsed().as_secs_f64() * 1000.0);
        }

        // ── v2: one op against an N-set workout ──
        let w = tr
            .create_workout(authed(&token, CreateWorkoutRequest {
                name: "v2".to_string(),
                blocks: v2_blocks(blocks, sets_per),
                started_at: 0,
                from_program: false,
            }))
            .await?
            .into_inner();
        let v2_id = w.id.clone();
        let v2_set = w.blocks.first().and_then(|b| b.sets.first()).map(|s| s.id.clone()).unwrap_or_default();
        let v2_op = |set_id: String, wid: String| MutateWorkoutRequest {
            workout_id: wid,
            ops: vec![WorkoutOp {
                op: Some(Op::StartSet(StartSetOp { set_id, at: 1 })),
            }],
        };
        for _ in 0..WARMUP {
            let _ = tr.mutate_workout(authed(&token, v2_op(v2_set.clone(), v2_id.clone()))).await?;
        }
        let mut v2_samples = Vec::with_capacity(ITERS);
        for _ in 0..ITERS {
            let t = Instant::now();
            tr.mutate_workout(authed(&token, v2_op(v2_set.clone(), v2_id.clone()))).await?;
            v2_samples.push(t.elapsed().as_secs_f64() * 1000.0);
        }

        let (v1_mean, v1_p90) = stats(v1_samples);
        let (v2_mean, v2_p90) = stats(v2_samples);
        println!(
            "{:<10} {:<6} | {:>10.3} (p90 {:>5.2}) | {:>10.3} (p90 {:>5.2}) | {:>6.1}x",
            format!("{blocks}×{sets_per}"),
            n,
            v1_mean,
            v1_p90,
            v2_mean,
            v2_p90,
            v1_mean / v2_mean,
        );
    }

    // ── Full session: log every set once. v1 rewrites all N per set = O(N^2);
    //    v2 is one insert per set = O(N). This is the realistic per-workout cost.
    println!("\nfull session — log every set once (total ms for the whole workout):\n");
    println!("{:<10} {:<6} | {:>13} | {:>15} | {:>13} | {:>16}", "workout", "sets", "v1 N calls", "v2 N calls", "v2 1 call", "DB-only / +batch");
    println!("{}", "-".repeat(86));
    for &(blocks, sets_per) in sizes {
        let n = blocks * sets_per;

        // v1: start a fresh workout, log each set via its own AppendMutations flush.
        let start = wk.start_workout(authed(&token, StartWorkoutRequest {
            name: "v1s".to_string(), exercise_groups: v1_groups(blocks, sets_per as i32), started_at: 0,
        })).await?.into_inner();
        let wid = start.id.clone();
        let set_ids: Vec<String> = start.proposed_sets.iter().filter(|s| !s.warmup).map(|s| s.id.clone()).collect();
        let t = Instant::now();
        for sid in &set_ids {
            wk.append_workout_mutations(authed(&token, AppendWorkoutMutationsRequest {
                mutations: vec![WorkoutMutation {
                    event_id: uuid::Uuid::new_v4().to_string(),
                    client_created_at: 0,
                    mutation: Some(workout_mutation::Mutation::CompleteSet(CompleteSetRequest {
                        workout_id: wid.clone(), proposed_set_id: sid.clone(), actual_reps: 5, actual_weight: 135.0, completed_at: 1,
                    })),
                }],
            })).await?;
        }
        let v1_total = t.elapsed().as_secs_f64() * 1000.0;

        let make_log = |sid: &str| WorkoutOp {
            op: Some(Op::LogSet(LogSetOp { set_id: sid.to_string(), result: Some(Measure { weight: 135.0, reps: 5, duration_s: 0, distance_m: 0.0 }), performed_at: 1 })),
        };

        // v2 unbatched: N separate MutateWorkout calls — same N round-trips as v1,
        // so this isolates the DB cost (row op vs whole rewrite).
        let w = tr.create_workout(authed(&token, CreateWorkoutRequest {
            name: "v2u".to_string(), blocks: v2_blocks(blocks, sets_per), started_at: 0, from_program: false,
        })).await?.into_inner();
        let v2u_ids: Vec<String> = w.blocks.iter().flat_map(|b| b.sets.iter()).map(|s| s.id.clone()).collect();
        let t = Instant::now();
        for sid in &v2u_ids {
            tr.mutate_workout(authed(&token, MutateWorkoutRequest { workout_id: w.id.clone(), ops: vec![make_log(sid)] })).await?;
        }
        let v2u_total = t.elapsed().as_secs_f64() * 1000.0;

        // v2 batched: the whole session in one MutateWorkout — the op-list design bonus.
        let w = tr.create_workout(authed(&token, CreateWorkoutRequest {
            name: "v2b".to_string(), blocks: v2_blocks(blocks, sets_per), started_at: 0, from_program: false,
        })).await?.into_inner();
        let v2b_ids: Vec<String> = w.blocks.iter().flat_map(|b| b.sets.iter()).map(|s| s.id.clone()).collect();
        let ops: Vec<WorkoutOp> = v2b_ids.iter().map(|s| make_log(s)).collect();
        let t = Instant::now();
        tr.mutate_workout(authed(&token, MutateWorkoutRequest { workout_id: w.id.clone(), ops })).await?;
        let v2b_total = t.elapsed().as_secs_f64() * 1000.0;

        println!("{:<10} {:<6} | {:>13.2} | {:>15.2} | {:>13.2} | {:>6.1}x / {:>5.1}x",
            format!("{blocks}×{sets_per}"), n, v1_total, v2u_total, v2b_total,
            v1_total / v2u_total, v1_total / v2b_total);
    }

    println!(
        "\nv1 rewrites the whole workout per op (grows with size); v2 is a single\nrow op (flat). The gap widens with workout size — exactly the point."
    );
    Ok(())
}

async fn loop_connect(endpoint: &str) -> Result<Channel, Box<dyn std::error::Error>> {
    for attempt in 0..100 {
        let ep = Channel::from_shared(endpoint.to_string())?.tcp_nodelay(true);
        match ep.connect().await {
            Ok(c) => return Ok(c),
            Err(_) if attempt < 99 => tokio::time::sleep(std::time::Duration::from_millis(100)).await,
            Err(e) => return Err(e.into()),
        }
    }
    Err("backend never came up".into())
}
