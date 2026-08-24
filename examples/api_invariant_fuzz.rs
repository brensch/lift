//! Drives a real backend through randomised but realistic workout sessions and
//! asserts invariants after every mutation.
//!
//! This exists to find the bugs unit tests do not: ones that need a specific
//! *sequence* of operations (edit a plan mid-set, delete a completed set, skip
//! warmups, reorder groups, end twice) against real persistence.
//!
//! It spawns its own backend on its own port with its own SQLite file, so it
//! never touches a dev database.
//!
//! ```text
//! cargo run --release --example api_invariant_fuzz -- --users 8 --sessions 12
//! make fuzz-api
//! ```
//!
//! Exit code is non-zero if any invariant is violated, so it can gate CI.

use std::collections::{HashMap, HashSet};
use std::process::{Child, Command, Stdio};

use clap::Parser;
use rand::rngs::StdRng;
use rand::{Rng, SeedableRng};
use schlift::workout::v1::{
    auth_service_client::AuthServiceClient, workout_service_client::WorkoutServiceClient,
    CancelProposedSetRequest, CompleteOnboardingRequest, CompleteSetRequest,
    DeleteCompletedSetRequest, EndWorkoutRequest, Exercise, ExerciseGroup, ExerciseTypeConfig,
    ExperienceLevel, GetActiveWorkoutRequest, GetHomeRequest, GetWorkoutRequest,
    GetWorkoutResponse, GroupWarmupPlan, PlannedGroupSet, ReorderExerciseGroupsRequest,
    ReplaceExerciseGroupPlanRequest, StartSetRequest, StartWorkoutRequest, TestLoginRequest,
    WeightUnit,
};
use tonic::transport::Channel;
use tonic::Request;

#[derive(Parser, Debug)]
#[command(about = "Randomised API sequence fuzzer with invariant checks")]
struct Args {
    /// Simulated users, run concurrently.
    #[arg(long, default_value_t = 6)]
    users: usize,
    /// Workouts per user.
    #[arg(long, default_value_t = 10)]
    sessions: usize,
    /// Seed for reproducibility — a failure prints the seed to replay it.
    #[arg(long, default_value_t = 0xC0FFEE)]
    seed: u64,
    /// Connect to an already-running backend instead of spawning one.
    #[arg(long)]
    connect: Option<String>,
    #[arg(long, default_value_t = 51_055)]
    port: u16,
}

/// A violated invariant, with enough context to reproduce it.
#[derive(Debug)]
struct Violation {
    user: String,
    workout_id: String,
    step: String,
    invariant: &'static str,
    detail: String,
}

struct Backend {
    child: Option<Child>,
    dir: std::path::PathBuf,
}

impl Drop for Backend {
    fn drop(&mut self) {
        if let Some(child) = self.child.as_mut() {
            let _ = child.kill();
            let _ = child.wait();
        }
        let _ = std::fs::remove_dir_all(&self.dir);
    }
}

fn spawn_backend(port: u16) -> Result<Backend, Box<dyn std::error::Error>> {
    let dir = std::env::temp_dir().join(format!("schlift-fuzz-{port}-{}", std::process::id()));
    std::fs::create_dir_all(&dir)?;

    // The harness needs TestLogin, which is only compiled in with `test-auth`.
    let status = Command::new("cargo")
        .args([
            "build",
            "--bin",
            "schlift",
            "--features",
            "test-auth",
            "--release",
        ])
        .status()?;
    if !status.success() {
        return Err("failed to build the backend with --features test-auth".into());
    }

    let child = Command::new("target/release/schlift")
        .env("DATA_DIR", dir.join("data"))
        .env("PORT", port.to_string())
        .env("RUST_LOG", "error")
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()?;

    Ok(Backend {
        child: Some(child),
        dir,
    })
}

/// One simulated user: a series of workouts, with invariants checked after every
/// mutation. Returns the violations it found and how many mutations it made.
async fn run_user(
    channel: Channel,
    seed: u64,
    user_idx: usize,
    sessions: usize,
) -> (Vec<Violation>, usize) {
    let mut auth = AuthServiceClient::new(channel.clone());
    let mut wk = WorkoutServiceClient::new(channel);
    // Decorrelate each user's stream so they do not all make the same choices.
    let mut rng = StdRng::seed_from_u64(seed ^ ((user_idx as u64 + 1) << 32));
    let mut violations: Vec<Violation> = Vec::new();
    let mut steps = 0usize;

    let username = format!("fuzz-user-{seed}-{user_idx}");
    let token = match auth
        .test_login(Request::new(TestLoginRequest {
            username: username.clone(),
        }))
        .await
    {
        Ok(r) => r.into_inner().session_token,
        Err(e) => {
            violations.push(Violation {
                user: username,
                workout_id: String::new(),
                step: "test_login".into(),
                invariant: "TestLogin failed — is the backend built with --features test-auth?",
                detail: e.to_string(),
            });
            return (violations, steps);
        }
    };

    // Onboard as the app does: seeds the default templates and trackers.
    let templates = match wk
        .complete_onboarding(authed(
            &token,
            CompleteOnboardingRequest {
                body_weight_kg: if rng.gen_bool(0.5) {
                    rng.gen_range(50..120) as f32
                } else {
                    0.0
                },
                experience: ExperienceLevel::Beginner as i32,
                unit: if rng.gen_bool(0.3) {
                    WeightUnit::Kg as i32
                } else {
                    WeightUnit::Lb as i32
                },
            },
        ))
        .await
    {
        Ok(r) => r
            .into_inner()
            .home
            .map(|h| h.templates)
            .unwrap_or_default(),
        Err(e) => {
            violations.push(Violation {
                user: username.clone(),
                workout_id: String::new(),
                step: "complete_onboarding".into(),
                invariant: "CompleteOnboarding returned an error",
                detail: e.to_string(),
            });
            Vec::new()
        }
    };

    for session_idx in 0..sessions {
        // Sometimes far in the future so the layoff deload path is exercised.
        let at_time = 1_700_000_000
            + (session_idx as i64) * 2 * 86_400
            + if rng.gen_bool(0.15) {
                rng.gen_range(15..70) * 86_400
            } else {
                0
            };

        let _ = wk.get_home(authed(&token, GetHomeRequest {})).await;

        // Half the sessions start from a template (the app's main path);
        // the rest send explicit groups (the "empty workout" path).
        let request = if !templates.is_empty() && rng.gen_bool(0.5) {
            let template = &templates[rng.gen_range(0..templates.len())];
            StartWorkoutRequest {
                name: String::new(),
                exercise_groups: vec![],
                started_at: at_time,
                template_id: template.id.clone(),
            }
        } else {
            let group_count = rng.gen_range(1..4);
            StartWorkoutRequest {
                name: format!("Fuzz {session_idx}"),
                exercise_groups: (0..group_count)
                    .map(|i| random_group(&mut rng, i))
                    .collect(),
                started_at: at_time,
                template_id: String::new(),
            }
        };

        let started = match wk.start_workout(authed(&token, request)).await {
            Ok(r) => r.into_inner(),
            Err(e) => {
                violations.push(Violation {
                    user: username.clone(),
                    workout_id: String::new(),
                    step: "start_workout".into(),
                    invariant: "StartWorkout returned an error",
                    detail: e.to_string(),
                });
                continue;
            }
        };
        let workout_id = started.workout.as_ref().unwrap().id.clone();

        let mut now = at_time + 60;
        let mut ops = rng.gen_range(6..26);

        while ops > 0 {
            ops -= 1;
            steps += 1;

            let state = match wk
                .get_workout(authed(
                    &token,
                    GetWorkoutRequest {
                        workout_id: workout_id.clone(),
                    },
                ))
                .await
            {
                Ok(r) => r.into_inner(),
                Err(e) => {
                    violations.push(Violation {
                        user: username.clone(),
                        workout_id: workout_id.clone(),
                        step: "get_workout".into(),
                        invariant: "GetWorkout returned an error",
                        detail: e.to_string(),
                    });
                    break;
                }
            };

            let pending: Vec<_> = state
                .proposed_sets
                .iter()
                .filter(|s| {
                    !s.cancelled
                        && !state
                            .completed_sets
                            .iter()
                            .any(|c| c.proposed_set_id == s.id)
                })
                .cloned()
                .collect();

            let action = rng.gen_range(0..100);
            let step_name;

            if pending.is_empty() && action < 70 {
                break;
            } else if action < 45 && !pending.is_empty() {
                // Start then complete a set.
                let set = &pending[rng.gen_range(0..pending.len())];
                step_name = format!("complete_set({})", set.id);
                let _ = wk
                    .start_set(authed(
                        &token,
                        StartSetRequest {
                            workout_id: workout_id.clone(),
                            proposed_set_id: set.id.clone(),
                            started_at: now,
                        },
                    ))
                    .await;
                now += 45;
                let _ = wk
                    .complete_set(authed(
                        &token,
                        CompleteSetRequest {
                            workout_id: workout_id.clone(),
                            proposed_set_id: set.id.clone(),
                            actual_reps: rng.gen_range(0..12),
                            actual_weight: set.target_weight,
                            completed_at: now,
                        },
                    ))
                    .await;
                now += 90;
            } else if action < 60 && !pending.is_empty() {
                // Skip a set.
                let set = &pending[rng.gen_range(0..pending.len())];
                step_name = format!("cancel_proposed_set({})", set.id);
                let _ = wk
                    .cancel_proposed_set(authed(
                        &token,
                        CancelProposedSetRequest {
                            workout_id: workout_id.clone(),
                            proposed_set_id: set.id.clone(),
                        },
                    ))
                    .await;
            } else if action < 72 && !state.completed_sets.is_empty() {
                // Undo a completed set.
                let c = &state.completed_sets[rng.gen_range(0..state.completed_sets.len())];
                step_name = format!("delete_completed_set({})", c.id);
                let _ = wk
                    .delete_completed_set(authed(
                        &token,
                        DeleteCompletedSetRequest {
                            workout_id: workout_id.clone(),
                            completed_set_id: c.id.clone(),
                        },
                    ))
                    .await;
            } else if action < 88 && !state.exercise_groups.is_empty() {
                // Edit a group's plan mid-workout, as the app does.
                let g = &state.exercise_groups[rng.gen_range(0..state.exercise_groups.len())];
                let exercise = g
                    .exercise_configs
                    .first()
                    .map(|c| c.exercise)
                    .unwrap_or(Exercise::Squat as i32);
                let weight = (rng.gen_range(9..60) * 5) as f32;
                let n = rng.gen_range(1..6);
                step_name = format!("replace_plan({})", g.id);
                let _ = wk
                    .replace_exercise_group_plan(authed(
                        &token,
                        ReplaceExerciseGroupPlanRequest {
                            workout_id: workout_id.clone(),
                            exercise_group_id: g.id.clone(),
                            name: g.name.clone(),
                            interleave_warmups: rng.gen_bool(0.3),
                            sets: (0..n)
                                .map(|_| PlannedGroupSet {
                                    exercise,
                                    target_reps: rng.gen_range(1..12),
                                    target_weight: weight,
                                    warmup: false,
                                    rest_after_success: 180,
                                    rest_after_failure: 300,
                                    is_amrap: false,
                                    instruction: String::new(),
                                    client_set_id: String::new(),
                                })
                                .collect(),
                            rest_config: None,
                            delete_group_if_empty: false,
                            instruction: String::new(),
                            create_if_missing: false,
                            // Cover all three warmup intents: silent (old
                            // client), explicitly on, explicitly off.
                            warmup_plan: match rng.gen_range(0..3) {
                                0 => None,
                                1 => Some(GroupWarmupPlan { exercises: vec![] }),
                                _ => Some(GroupWarmupPlan {
                                    exercises: vec![exercise],
                                }),
                            },
                        },
                    ))
                    .await;
            } else if state.exercise_groups.len() > 1 {
                // Reorder groups.
                let mut ids: Vec<String> =
                    state.exercise_groups.iter().map(|g| g.id.clone()).collect();
                for i in (1..ids.len()).rev() {
                    ids.swap(i, rng.gen_range(0..=i));
                }
                step_name = "reorder_groups".to_string();
                let _ = wk
                    .reorder_exercise_groups(authed(
                        &token,
                        ReorderExerciseGroupsRequest {
                            workout_id: workout_id.clone(),
                            exercise_group_ids: ids,
                        },
                    ))
                    .await;
            } else {
                continue;
            }

            if let Ok(after) = wk
                .get_workout(authed(
                    &token,
                    GetWorkoutRequest {
                        workout_id: workout_id.clone(),
                    },
                ))
                .await
            {
                check_invariants(&after.into_inner(), &username, &step_name, &mut violations);
            }
        }

        // End the workout, sometimes twice — EndWorkout must be idempotent,
        // and a re-fire must not advance a tracker a second time.
        let _ = wk
            .end_workout(authed(
                &token,
                EndWorkoutRequest {
                    workout_id: workout_id.clone(),
                    ended_at: now,
                },
            ))
            .await;
        if rng.gen_bool(0.25) {
            let before: HashMap<i32, (f32, i32)> = home_trackers(&mut wk, &token).await;
            let _ = wk
                .end_workout(authed(
                    &token,
                    EndWorkoutRequest {
                        workout_id: workout_id.clone(),
                        ended_at: now,
                    },
                ))
                .await;
            let after = home_trackers(&mut wk, &token).await;
            for (exercise, (weight, reps)) in &before {
                if let Some((weight_after, reps_after)) = after.get(exercise) {
                    if (weight_after - weight).abs() > 0.01 || reps_after != reps {
                        violations.push(Violation {
                            user: username.clone(),
                            workout_id: workout_id.clone(),
                            step: "end_workout(again)".into(),
                            invariant: "a re-fired EndWorkout moved a tracker",
                            detail: format!(
                                "exercise {exercise}: {weight}@{reps} -> {weight_after}@{reps_after}"
                            ),
                        });
                    }
                }
            }
        }

        // After ending, there must be no active workout left behind.
        if let Ok(active) = wk
            .get_active_workout(authed(&token, GetActiveWorkoutRequest {}))
            .await
        {
            let active = active.into_inner();
            if let Some(w) = active.workout.as_ref() {
                if w.id == workout_id {
                    violations.push(Violation {
                        user: username.clone(),
                        workout_id: workout_id.clone(),
                        step: "end_workout".into(),
                        invariant: "workout is still active after EndWorkout",
                        detail: format!("GetActiveWorkout still returns {}", w.id),
                    });
                }
            }
        }
    }


    (violations, steps)
}

async fn wait_for_backend(endpoint: &str) -> Result<Channel, Box<dyn std::error::Error>> {
    for attempt in 0..100 {
        match Channel::from_shared(endpoint.to_string())?.connect().await {
            Ok(channel) => return Ok(channel),
            Err(_) if attempt < 99 => {
                tokio::time::sleep(std::time::Duration::from_millis(100)).await;
            }
            Err(e) => return Err(e.into()),
        }
    }
    Err("backend never became reachable".into())
}

/// (exercise -> (working weight, target reps)) from GetHome.
async fn home_trackers(
    wk: &mut WorkoutServiceClient<Channel>,
    token: &str,
) -> HashMap<i32, (f32, i32)> {
    match wk.get_home(authed(token, GetHomeRequest {})).await {
        Ok(response) => response
            .into_inner()
            .trackers
            .into_iter()
            .map(|t| (t.exercise, (t.working_weight, t.target_reps)))
            .collect(),
        Err(_) => HashMap::new(),
    }
}

fn authed<T>(token: &str, msg: T) -> Request<T> {
    let mut req = Request::new(msg);
    req.metadata_mut()
        .insert("x-session-token", token.parse().unwrap());
    req
}

/// Everything we assert about a workout's state, checked after every mutation.
fn check_invariants(
    state: &GetWorkoutResponse,
    user: &str,
    step: &str,
    out: &mut Vec<Violation>,
) {
    let workout_id = state
        .workout
        .as_ref()
        .map(|w| w.id.clone())
        .unwrap_or_default();
    let mut push = |invariant: &'static str, detail: String| {
        out.push(Violation {
            user: user.to_string(),
            workout_id: workout_id.clone(),
            step: step.to_string(),
            invariant,
            detail,
        });
    };

    let proposed_ids: HashSet<&str> = state.proposed_sets.iter().map(|s| s.id.as_str()).collect();

    // Every completed set must point at a proposed set in this workout.
    for c in &state.completed_sets {
        if !proposed_ids.contains(c.proposed_set_id.as_str()) {
            push(
                "completed set references a proposed set that does not exist",
                format!("completed {} -> proposed {}", c.id, c.proposed_set_id),
            );
        }
    }

    // A proposed set may be completed at most once.
    let mut seen: HashMap<&str, usize> = HashMap::new();
    for c in &state.completed_sets {
        *seen.entry(c.proposed_set_id.as_str()).or_default() += 1;
    }
    for (set_id, count) in seen.iter().filter(|(_, n)| **n > 1) {
        push(
            "a proposed set has more than one completed set",
            format!("proposed {set_id} completed {count} times"),
        );
    }

    // workout_order must be unique across live sets, or the UI reorders itself.
    let mut orders: HashMap<i32, usize> = HashMap::new();
    for s in state.proposed_sets.iter().filter(|s| !s.cancelled) {
        *orders.entry(s.workout_order).or_default() += 1;
    }
    for (order, count) in orders.iter().filter(|(_, n)| **n > 1) {
        push(
            "duplicate workout_order among live proposed sets",
            format!("order {order} used {count} times"),
        );
    }

    // Every live set must belong to a group that exists.
    let group_ids: HashSet<&str> = state.exercise_groups.iter().map(|g| g.id.as_str()).collect();
    for s in state.proposed_sets.iter().filter(|s| !s.cancelled) {
        if !s.exercise_group_id.is_empty() && !group_ids.contains(s.exercise_group_id.as_str()) {
            push(
                "proposed set belongs to a group that does not exist",
                format!("set {} -> group {}", s.id, s.exercise_group_id),
            );
        }
    }

    // next_up must be a live, not-yet-completed set.
    if let Some(next) = state.next_up_set.as_ref() {
        let completed: HashSet<&str> = state
            .completed_sets
            .iter()
            .filter(|c| c.ended_at != 0)
            .map(|c| c.proposed_set_id.as_str())
            .collect();
        if !proposed_ids.contains(next.id.as_str()) {
            push(
                "next_up_set is not one of this workout's proposed sets",
                format!("next_up {}", next.id),
            );
        } else if next.cancelled {
            push("next_up_set is cancelled", format!("next_up {}", next.id));
        } else if completed.contains(next.id.as_str()) {
            push(
                "next_up_set has already been completed",
                format!("next_up {}", next.id),
            );
        }
    }

    // At most one set in progress at a time.
    let in_progress = state
        .completed_sets
        .iter()
        .filter(|c| c.ended_at == 0)
        .count();
    if in_progress > 1 {
        push(
            "more than one set is in progress",
            format!("{in_progress} sets have ended_at = 0"),
        );
    }

    // Weights and reps must be sane.
    for s in &state.proposed_sets {
        if s.target_weight < 0.0 || !s.target_weight.is_finite() {
            push(
                "proposed set has a nonsensical target weight",
                format!("set {} weight {}", s.id, s.target_weight),
            );
        }
        if s.target_reps < 0 {
            push(
                "proposed set has negative target reps",
                format!("set {} reps {}", s.id, s.target_reps),
            );
        }
    }
}

fn random_group(rng: &mut StdRng, order: i32) -> ExerciseGroup {
    const LIFTS: [Exercise; 5] = [
        Exercise::Squat,
        Exercise::BenchPress,
        Exercise::Deadlift,
        Exercise::OverheadPress,
        Exercise::BarbellRow,
    ];
    let exercise = LIFTS[rng.gen_range(0..LIFTS.len())];
    let weight = (rng.gen_range(9..60) * 5) as f32;
    let sets = rng.gen_range(1..6);
    ExerciseGroup {
        id: String::new(),
        workout_id: String::new(),
        name: format!("{exercise:?}"),
        sets,
        interleave_warmups: rng.gen_bool(0.3),
        workout_order: order,
        exercise_configs: vec![ExerciseTypeConfig {
            exercise: exercise as i32,
            start_weight: weight,
            end_weight: weight,
            reps: rng.gen_range(1..12),
            include_warmup: rng.gen_bool(0.6),
            rest_config: None,
            last_set_amrap: rng.gen_bool(0.2),
            working_sets: Vec::new(),
        }],
        rest_config: None,
        instruction: String::new(),
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();

    let (_backend, endpoint) = match &args.connect {
        Some(endpoint) => (None, endpoint.clone()),
        None => {
            println!("building and starting a throwaway backend on :{}", args.port);
            let b = spawn_backend(args.port)?;
            (Some(b), format!("http://127.0.0.1:{}", args.port))
        }
    };

    let channel = wait_for_backend(&endpoint).await?;

    // Users run concurrently: it is faster, and it puts real contention on the
    // single write connection and the session tables.
    let mut tasks = Vec::new();
    for user_idx in 0..args.users {
        let channel = channel.clone();
        let seed = args.seed;
        let sessions = args.sessions;
        tasks.push(tokio::spawn(async move {
            run_user(channel, seed, user_idx, sessions).await
        }));
    }

    let mut violations: Vec<Violation> = Vec::new();
    let mut steps = 0usize;
    for task in tasks {
        let (v, s) = task.await?;
        violations.extend(v);
        steps += s;
    }

    println!(
        "\n{} users x {} sessions, {} mutations checked",
        args.users, args.sessions, steps
    );

    if violations.is_empty() {
        println!("no invariant violations");
        return Ok(());
    }

    // Group identical invariants so a systemic bug reads as one finding.
    let mut by_invariant: HashMap<&str, Vec<&Violation>> = HashMap::new();
    for v in &violations {
        by_invariant.entry(v.invariant).or_default().push(v);
    }

    eprintln!("\n{} invariant violations:", violations.len());
    for (invariant, list) in &by_invariant {
        eprintln!("\n  {} ({} occurrences)", invariant, list.len());
        for v in list.iter().take(3) {
            eprintln!("    user={} workout={}", v.user, v.workout_id);
            eprintln!("    after: {}", v.step);
            eprintln!("    {}", v.detail);
        }
        if list.len() > 3 {
            eprintln!("    ... and {} more", list.len() - 3);
        }
    }
    eprintln!("\nreplay with --seed {}", args.seed);
    std::process::exit(1);
}
