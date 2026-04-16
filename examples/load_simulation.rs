use clap::Parser;
use dashmap::DashMap;
use rand::Rng;
use schlift::workout::v1::{
    auth_service_client::AuthServiceClient, multiplayer_service_client::MultiplayerServiceClient,
    settings_service_client::SettingsServiceClient, workout_mutation,
    workout_service_client::WorkoutServiceClient, AppendWorkoutHeartRateRequest,
    AppendWorkoutMutationsRequest, CompleteSetRequest, EndWorkoutRequest, Exercise, ExerciseGroup,
    ExerciseTypeConfig, GetActiveTrainingProgramStateRequest, GetActiveWorkoutRequest,
    GetCurrentSessionRequest, GetMyInviteTokenRequest, GetProposedWorkoutScheduleRequest,
    GetSettingsRequest, GetTrainingProgramCatalogRequest, GetWorkoutRequest, JoinViaInviteRequest,
    StartSetRequest, StartWorkoutRequest, TestLoginRequest, UpdateActiveWorkoutRequest,
    WorkoutHeartRatePoint, WorkoutMutation,
};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use tonic::metadata::MetadataValue;
use tonic::transport::{Channel, Endpoint};
use tonic::{Request, Status};

#[derive(Parser, Debug)]
#[command(about = "Load simulation for the schlift backend")]
struct Args {
    /// Server address
    #[arg(short, long, default_value = "http://127.0.0.1:50051")]
    addr: String,

    /// How many seconds to run the simulation
    #[arg(short, long, default_value_t = 300)]
    duration: u64,

    /// Groups of users spawned per second (each group is 3-5 users)
    #[arg(long, default_value_t = 100.0)]
    groups_per_sec: f64,
}

struct MethodStats {
    requests: AtomicU64,
    errors: AtomicU64,
    total_latency_ms: AtomicU64,
    max_latency_ms: AtomicU64,
}

impl MethodStats {
    fn new() -> Self {
        Self {
            requests: AtomicU64::new(0),
            errors: AtomicU64::new(0),
            total_latency_ms: AtomicU64::new(0),
            max_latency_ms: AtomicU64::new(0),
        }
    }

    fn record(&self, latency: Duration, is_error: bool) {
        self.requests.fetch_add(1, Ordering::Relaxed);
        if is_error {
            self.errors.fetch_add(1, Ordering::Relaxed);
        } else {
            let ms = latency.as_millis() as u64;
            self.total_latency_ms.fetch_add(ms, Ordering::Relaxed);
            let mut current_max = self.max_latency_ms.load(Ordering::Relaxed);
            while ms > current_max {
                match self.max_latency_ms.compare_exchange_weak(
                    current_max,
                    ms,
                    Ordering::Relaxed,
                    Ordering::Relaxed,
                ) {
                    Ok(_) => break,
                    Err(actual) => current_max = actual,
                }
            }
        }
    }
}

struct GlobalStats {
    total_requests: AtomicU64,
    total_errors: AtomicU64,
    active_users: AtomicU64,
    method_stats: DashMap<String, Arc<MethodStats>>,
}

impl GlobalStats {
    fn new() -> Self {
        Self {
            total_requests: AtomicU64::new(0),
            total_errors: AtomicU64::new(0),
            active_users: AtomicU64::new(0),
            method_stats: DashMap::new(),
        }
    }

    fn record(&self, method: &str, latency: Duration, is_error: bool) {
        self.total_requests.fetch_add(1, Ordering::Relaxed);
        if is_error {
            self.total_errors.fetch_add(1, Ordering::Relaxed);
        }
        let stats = self
            .method_stats
            .entry(method.to_string())
            .or_insert_with(|| Arc::new(MethodStats::new()));
        stats.record(latency, is_error);
    }
}

#[derive(Default)]
struct SessionRegistry {
    leader_ids: DashMap<usize, String>,
}

fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_millis() as i64
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();
    let stats = Arc::new(GlobalStats::new());
    let session_registry = Arc::new(SessionRegistry::default());
    let start_time = Instant::now();
    let duration = Duration::from_secs(args.duration);

    println!("Connecting to {}...", args.addr);
    println!("Connected successfully.");
    println!(
        "Starting simulation (duration={}s, groups/s={:.0})",
        args.duration, args.groups_per_sec
    );

    // Stats reporter task
    let stats_reporter = Arc::clone(&stats);
    tokio::spawn(async move {
        let mut last_requests = 0;
        let mut last_time = Instant::now();
        let mut method_last_counts = std::collections::HashMap::new();

        loop {
            tokio::time::sleep(Duration::from_secs(5)).await;
            let current_requests = stats_reporter.total_requests.load(Ordering::Relaxed);
            let elapsed = last_time.elapsed().as_secs_f64();
            let rps = (current_requests - last_requests) as f64 / elapsed;

            println!(
                "\n[{:4.0}s] Users: {:4} | RPS: {:7.1} | Errors: {}",
                start_time.elapsed().as_secs_f64(),
                stats_reporter.active_users.load(Ordering::Relaxed),
                rps,
                stats_reporter.total_errors.load(Ordering::Relaxed)
            );

            let mut methods: Vec<_> = stats_reporter
                .method_stats
                .iter()
                .map(|r| (r.key().clone(), r.value().clone()))
                .collect();
            methods.sort_by(|a, b| {
                b.1.requests
                    .load(Ordering::Relaxed)
                    .cmp(&a.1.requests.load(Ordering::Relaxed))
            });

            for (name, ms) in methods {
                let reqs = ms.requests.load(Ordering::Relaxed);
                let last_reqs = method_last_counts.get(&name).copied().unwrap_or(0);
                let interval_qps = (reqs - last_reqs) as f64 / elapsed;
                method_last_counts.insert(name.clone(), reqs);

                let active_users = stats_reporter.active_users.load(Ordering::Relaxed);
                let qps_per_user = if active_users > 0 {
                    interval_qps / active_users as f64
                } else {
                    0.0
                };

                let errs = ms.errors.load(Ordering::Relaxed);
                let total_ms = ms.total_latency_ms.load(Ordering::Relaxed);
                let max_ms = ms.max_latency_ms.load(Ordering::Relaxed);
                let avg = if reqs > 0 {
                    total_ms as f64 / reqs as f64
                } else {
                    0.0
                };
                println!(
                    "  {:30}: qps={:7.1}, qps/u={:7.4}, avg={:6.1}ms, max={:6.1}ms, req={:<5}, err={}",
                    name, interval_qps, qps_per_user, avg, max_ms as f64, reqs, errs
                );
            }
            last_requests = current_requests;
            last_time = Instant::now();
        }
    });

    let session_id_prefix = rand::thread_rng().gen_range(1000..9999);
    let mut current_group_count = 0;

    loop {
        let elapsed = start_time.elapsed().as_secs_f64();
        if elapsed >= args.duration as f64 {
            break;
        }

        let target_groups = (elapsed * args.groups_per_sec).floor() as usize + 1;

        while current_group_count < target_groups {
            let group_index = current_group_count;
            let addr = args.addr.clone();
            let stats = Arc::clone(&stats);
            let registry = Arc::clone(&session_registry);

            tokio::spawn(async move {
                let group_size = {
                    let mut rng = rand::thread_rng();
                    rng.gen_range(3..5)
                };

                for member_index in 0..group_size {
                    let username = format!(
                        "__test__sim_{}_{}_{}",
                        session_id_prefix, group_index, member_index
                    );
                    let stats = Arc::clone(&stats);
                    let registry = Arc::clone(&registry);
                    let addr = addr.clone();
                    let is_leader = member_index == 0;

                    tokio::spawn(async move {
                        stats.active_users.fetch_add(1, Ordering::Relaxed);
                        if let Err(e) = run_user_simulation(UserSimConfig {
                            username: username.clone(),
                            group_index,
                            is_leader,
                            addr,
                            stats: stats.clone(),
                            session_registry: registry,
                            start_time,
                            total_duration: duration,
                        })
                        .await
                        {
                            eprintln!("ERROR: Simulation failed for {}: {}", username, e);
                            stats.total_errors.fetch_add(1, Ordering::Relaxed);
                        }
                        stats.active_users.fetch_sub(1, Ordering::Relaxed);
                    });

                    tokio::time::sleep(Duration::from_millis(10)).await;
                }
            });

            current_group_count += 1;
            tokio::time::sleep(Duration::from_millis(20)).await;
        }
        tokio::time::sleep(Duration::from_millis(100)).await;
    }

    tokio::time::sleep(duration.saturating_sub(start_time.elapsed())).await;
    Ok(())
}

struct UserSimConfig {
    username: String,
    group_index: usize,
    is_leader: bool,
    addr: String,
    stats: Arc<GlobalStats>,
    session_registry: Arc<SessionRegistry>,
    start_time: Instant,
    total_duration: Duration,
}

async fn run_user_simulation(
    config: UserSimConfig,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let username = config.username;
    let group_index = config.group_index;
    let is_leader = config.is_leader;
    let addr = config.addr;
    let stats = config.stats;
    let session_registry = config.session_registry;
    let start_time = config.start_time;
    let total_duration = config.total_duration;

    let channel = Endpoint::from_shared(addr)?
        .connect_timeout(Duration::from_secs(5))
        .connect()
        .await?;

    let mut auth_client = AuthServiceClient::new(channel.clone());

    let login_start = Instant::now();
    let login_res = auth_client
        .test_login(TestLoginRequest {
            username: username.clone(),
        })
        .await;
    stats.record("TestLogin", login_start.elapsed(), login_res.is_err());
    let login_resp = login_res?.into_inner();

    let user_id = login_resp.user_id.clone();
    let token: MetadataValue<_> = login_resp.session_token.parse()?;

    let mut workout_client = WorkoutServiceClient::new(channel.clone());
    let mut multiplayer_client = MultiplayerServiceClient::new(channel.clone());
    let mut settings_client = SettingsServiceClient::new(channel.clone());

    if is_leader {
        let mut req = Request::new(GetMyInviteTokenRequest {});
        req.metadata_mut().insert("x-session-token", token.clone());
        let invite_token = multiplayer_client
            .get_my_invite_token(req)
            .await?
            .into_inner()
            .invite_token;
        session_registry
            .leader_ids
            .insert(group_index, invite_token);
    }

    // Real app startup runs these branches concurrently after session restore.
    let settings_branch = {
        let token = token.clone();
        let stats = Arc::clone(&stats);
        let mut client = settings_client.clone();
        tokio::spawn(async move {
            timed_call(
                &mut client,
                &token,
                &stats,
                "GetTrainingProgramCatalog",
                |c, req| Box::pin(c.get_training_program_catalog(req)),
                GetTrainingProgramCatalogRequest {},
            )
            .await?;
            timed_call(
                &mut client,
                &token,
                &stats,
                "GetSettings",
                |c, req| Box::pin(c.get_settings(req)),
                GetSettingsRequest {},
            )
            .await?;
            timed_call(
                &mut client,
                &token,
                &stats,
                "GetActiveTrainingProgramState",
                |c, req| Box::pin(c.get_active_training_program_state(req)),
                GetActiveTrainingProgramStateRequest {},
            )
            .await?;
            Ok::<(), Status>(())
        })
    };

    let workout_branch = {
        let token = token.clone();
        let stats = Arc::clone(&stats);
        let user_id = user_id.clone();
        let mut client = workout_client.clone();
        tokio::spawn(async move {
            let startup_active = timed_call(
                &mut client,
                &token,
                &stats,
                "GetActiveWorkout",
                |c, req| Box::pin(c.get_active_workout(req)),
                GetActiveWorkoutRequest {},
            )
            .await?;
            if let Some(active_workout) = startup_active.workout {
                timed_call(
                    &mut client,
                    &token,
                    &stats,
                    "GetWorkout",
                    |c, req| Box::pin(c.get_workout(req)),
                    GetWorkoutRequest {
                        workout_id: active_workout.id,
                    },
                )
                .await?;
            }
            let proposed_schedule = timed_call(
                &mut client,
                &token,
                &stats,
                "GetProposedSchedule",
                |c, req| Box::pin(c.get_proposed_workout_schedule(req)),
                GetProposedWorkoutScheduleRequest {
                    user_id,
                    at_time: 0,
                },
            )
            .await?;
            Ok::<_, Status>(proposed_schedule)
        })
    };

    let session_branch = {
        let token = token.clone();
        let stats = Arc::clone(&stats);
        let mut client = multiplayer_client.clone();
        tokio::spawn(async move {
            timed_call(
                &mut client,
                &token,
                &stats,
                "GetCurrentSession",
                |c, req| Box::pin(c.get_current_session(req)),
                GetCurrentSessionRequest {},
            )
            .await
        })
    };

    settings_branch.await??;
    workout_branch.await??;
    let startup_session = session_branch.await??;

    let mut current_session_id = if startup_session.session_id.is_empty() {
        None
    } else {
        Some(startup_session.session_id)
    };
    let mut session_poll_task = current_session_id.clone().map(|_session_id| {
        spawn_session_poll(multiplayer_client.clone(), token.clone(), stats.clone())
    });

    // Join session if not leader
    if !is_leader {
        let mut leader_invite: Option<String> = None;
        for _ in 0..30 {
            if let Some(t) = session_registry.leader_ids.get(&group_index) {
                leader_invite = Some(t.clone());
                break;
            }
            tokio::time::sleep(Duration::from_millis(500)).await;
        }

        if let Some(invite_token) = leader_invite {
            let mut req = Request::new(JoinViaInviteRequest { invite_token });
            req.metadata_mut().insert("x-session-token", token.clone());
            let req_start = Instant::now();
            let res = multiplayer_client.join_via_invite(req).await;
            stats.record("JoinViaInvite", req_start.elapsed(), res.is_err());
            res?;

            let joined_session = timed_call(
                &mut multiplayer_client,
                &token,
                &stats,
                "GetCurrentSession",
                |c, req| Box::pin(c.get_current_session(req)),
                GetCurrentSessionRequest {},
            )
            .await?;
            if !joined_session.session_id.is_empty() && session_poll_task.is_none() {
                current_session_id = Some(joined_session.session_id.clone());
                session_poll_task = Some(spawn_session_poll(
                    multiplayer_client.clone(),
                    token.clone(),
                    stats.clone(),
                ));
            }
        }
    }

    // Main workout loop
    while start_time.elapsed() < total_duration {
        // Returning to the home tab: sync active workout and proposed schedule.
        timed_call(
            &mut workout_client,
            &token,
            &stats,
            "GetActiveWorkout",
            |c, req| Box::pin(c.get_active_workout(req)),
            GetActiveWorkoutRequest {},
        )
        .await?;

        random_sleep(500, 1500).await;

        let proposed_schedule = timed_call(
            &mut workout_client,
            &token,
            &stats,
            "GetProposedSchedule",
            |c, req| Box::pin(c.get_proposed_workout_schedule(req)),
            GetProposedWorkoutScheduleRequest {
                user_id: user_id.clone(),
                at_time: 0,
            },
        )
        .await?;

        random_sleep(500, 1500).await;

        let start_groups = build_start_workout_groups(&proposed_schedule);
        let start_resp = timed_call(
            &mut workout_client,
            &token,
            &stats,
            "StartWorkout",
            |c, req| Box::pin(c.start_workout(req)),
            StartWorkoutRequest {
                name: "Simulated Workout".to_string(),
                exercise_groups: start_groups,
                started_at: 0,
            },
        )
        .await?;
        let workout_id = start_resp.id;

        timed_call(
            &mut workout_client,
            &token,
            &stats,
            "ClearWorkoutDraft",
            |c, req| Box::pin(c.clear_workout_draft(req)),
            schlift::workout::v1::ClearWorkoutDraftRequest {},
        )
        .await?;

        if current_session_id.is_some() {
            timed_call(
                &mut multiplayer_client,
                &token,
                &stats,
                "UpdateActiveWorkout",
                |c, req| Box::pin(c.update_active_workout(req)),
                UpdateActiveWorkoutRequest {
                    workout_id: workout_id.clone(),
                },
            )
            .await?;
        }

        for p_set in start_resp.proposed_sets {
            random_sleep(500, 2000).await;

            let mutations = vec![WorkoutMutation {
                event_id: uuid::Uuid::new_v4().to_string(),
                client_created_at: 0,
                mutation: Some(workout_mutation::Mutation::StartSet(StartSetRequest {
                    workout_id: workout_id.clone(),
                    proposed_set_id: p_set.id.clone(),
                    started_at: 0,
                })),
            }];

            timed_call(
                &mut workout_client,
                &token,
                &stats,
                "AppendMutations",
                |c, req| Box::pin(c.append_workout_mutations(req)),
                AppendWorkoutMutationsRequest { mutations },
            )
            .await?;

            random_sleep(2000, 5000).await;

            let hr_samples: Vec<WorkoutHeartRatePoint> = (0..5)
                .map(|i| WorkoutHeartRatePoint {
                    sampled_at: now_ms() - (5 - i) * 1000,
                    bpm: rand::thread_rng().gen_range(120.0..170.0),
                    availability: 1,
                })
                .collect();

            timed_call(
                &mut workout_client,
                &token,
                &stats,
                "AppendHeartRate",
                |c, req| Box::pin(c.append_workout_heart_rate(req)),
                AppendWorkoutHeartRateRequest {
                    workout_id: workout_id.clone(),
                    samples: hr_samples,
                },
            )
            .await?;

            let mutations = vec![WorkoutMutation {
                event_id: uuid::Uuid::new_v4().to_string(),
                client_created_at: 0,
                mutation: Some(workout_mutation::Mutation::CompleteSet(
                    CompleteSetRequest {
                        workout_id: workout_id.clone(),
                        proposed_set_id: p_set.id.clone(),
                        actual_reps: p_set.target_reps,
                        actual_weight: p_set.target_weight,
                        ..Default::default()
                    },
                )),
            }];

            timed_call(
                &mut workout_client,
                &token,
                &stats,
                "AppendMutations",
                |c, req| Box::pin(c.append_workout_mutations(req)),
                AppendWorkoutMutationsRequest { mutations },
            )
            .await?;

            random_sleep(2000, 5000).await;
        }

        random_sleep(1000, 3000).await;

        let ended = timed_call(
            &mut workout_client,
            &token,
            &stats,
            "EndWorkout",
            |c, req| Box::pin(c.end_workout(req)),
            EndWorkoutRequest {
                workout_id: workout_id.clone(),
                ended_at: 0,
            },
        )
        .await?;

        timed_call(
            &mut settings_client,
            &token,
            &stats,
            "GetActiveTrainingProgramState",
            |c, req| Box::pin(c.get_active_training_program_state(req)),
            GetActiveTrainingProgramStateRequest {},
        )
        .await?;
        timed_call(
            &mut workout_client,
            &token,
            &stats,
            "GetWorkout",
            |c, req| Box::pin(c.get_workout(req)),
            GetWorkoutRequest {
                workout_id: workout_id.clone(),
            },
        )
        .await?;
        if let Some(ended_workout) = ended.workout.as_ref() {
            if !ended_workout.session_id.is_empty() {
                timed_call(
                    &mut multiplayer_client,
                    &token,
                    &stats,
                    "GetCurrentSession",
                    |c, req| Box::pin(c.get_current_session(req)),
                    GetCurrentSessionRequest {},
                )
                .await?;
            }
        }
        timed_call(
            &mut workout_client,
            &token,
            &stats,
            "GetProposedSchedule",
            |c, req| Box::pin(c.get_proposed_workout_schedule(req)),
            GetProposedWorkoutScheduleRequest {
                user_id: user_id.clone(),
                at_time: 0,
            },
        )
        .await?;

        // Gap between workouts
        random_sleep(5000, 10000).await;
    }

    if let Some(handle) = session_poll_task {
        handle.abort();
    }

    Ok(())
}

async fn random_sleep(min_ms: u64, max_ms: u64) {
    let ms = rand::thread_rng().gen_range(min_ms..max_ms);
    tokio::time::sleep(Duration::from_millis(ms)).await;
}

fn build_start_workout_groups(
    schedule: &schlift::workout::v1::GetProposedWorkoutScheduleResponse,
) -> Vec<ExerciseGroup> {
    if !schedule.proposed_groups.is_empty() {
        let mut groups = Vec::new();
        for (idx, proposed) in schedule.proposed_groups.iter().take(2).enumerate() {
            groups.push(ExerciseGroup {
                id: uuid::Uuid::new_v4().to_string(),
                workout_id: String::new(),
                name: proposed.name.clone(),
                sets: proposed.sets,
                interleave_warmups: proposed.interleave_warmups,
                workout_order: idx as i32,
                prescribed_by_regime: proposed.prescribed_by_regime,
                exercise_configs: proposed.exercise_configs.clone(),
                instruction: String::new(),
                rest_config: proposed.rest_config,
            });
        }
        if !groups.is_empty() {
            return groups;
        }
    }

    vec![
        ExerciseGroup {
            id: uuid::Uuid::new_v4().to_string(),
            workout_id: String::new(),
            name: "Squat".to_string(),
            sets: 3,
            interleave_warmups: false,
            workout_order: 0,
            prescribed_by_regime: false,
            exercise_configs: vec![ExerciseTypeConfig {
                exercise: Exercise::Squat as i32,
                start_weight: 135.0,
                end_weight: 135.0,
                reps: 5,
                include_warmup: true,
                last_set_amrap: false,
                working_sets: vec![],
                rest_config: None,
            }],
            instruction: String::new(),
            rest_config: None,
        },
        ExerciseGroup {
            id: uuid::Uuid::new_v4().to_string(),
            workout_id: String::new(),
            name: "Bench".to_string(),
            sets: 3,
            interleave_warmups: false,
            workout_order: 1,
            prescribed_by_regime: false,
            exercise_configs: vec![ExerciseTypeConfig {
                exercise: Exercise::BenchPress as i32,
                start_weight: 95.0,
                end_weight: 95.0,
                reps: 5,
                include_warmup: true,
                last_set_amrap: false,
                working_sets: vec![],
                rest_config: None,
            }],
            instruction: String::new(),
            rest_config: None,
        },
    ]
}

fn spawn_session_poll(
    mut multiplayer_client: MultiplayerServiceClient<Channel>,
    token: MetadataValue<tonic::metadata::Ascii>,
    stats: Arc<GlobalStats>,
) -> tokio::task::JoinHandle<()> {
    tokio::spawn(async move {
        loop {
            let req_start = Instant::now();
            let mut req = Request::new(GetCurrentSessionRequest {});
            req.metadata_mut().insert("x-session-token", token.clone());
            let res = multiplayer_client.get_current_session(req).await;
            stats.record("GetCurrentSession", req_start.elapsed(), res.is_err());
            if res.is_err() {
                break;
            }
            tokio::time::sleep(Duration::from_secs(1)).await;
        }
    })
}

/// Generic timed RPC call — records latency stats
async fn timed_call<C, Req, Res, F>(
    client: &mut C,
    token: &MetadataValue<tonic::metadata::Ascii>,
    stats: &Arc<GlobalStats>,
    method_name: &str,
    call_fn: F,
    request: Req,
) -> Result<Res, Status>
where
    for<'a> F: FnOnce(
        &'a mut C,
        Request<Req>,
    ) -> std::pin::Pin<
        Box<dyn std::future::Future<Output = Result<tonic::Response<Res>, Status>> + Send + 'a>,
    >,
{
    let req_start = Instant::now();
    let mut req = Request::new(request);
    req.metadata_mut().insert("x-session-token", token.clone());
    let res = call_fn(client, req).await;
    stats.record(method_name, req_start.elapsed(), res.is_err());
    res.map(|r| r.into_inner())
}
