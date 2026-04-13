use clap::Parser;
use dashmap::DashMap;
use rand::Rng;
use schlift::workout::v1::{
    auth_service_client::AuthServiceClient, multiplayer_service_client::MultiplayerServiceClient,
    settings_service_client::SettingsServiceClient, workout_mutation,
    workout_service_client::WorkoutServiceClient, AppendWorkoutHeartRateRequest,
    AppendWorkoutMutationsRequest, CompleteSetRequest, EndWorkoutRequest, Exercise, ExerciseGroup,
    ExerciseTypeConfig, GetActiveTrainingProgramStateRequest, GetActiveWorkoutRequest,
    GetCurrentSessionRequest, GetProposedWorkoutScheduleRequest, GetSettingsRequest,
    GetMyInviteTokenRequest, GetTrainingProgramCatalogRequest, JoinViaInviteRequest,
    StartWorkoutRequest, TestLoginRequest,
    UpdateActiveWorkoutRequest, WorkoutHeartRatePoint, WorkoutMutation,
};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use tonic::metadata::MetadataValue;
use tonic::transport::{Channel, Endpoint};
use tonic::{Request, Status};
use uuid::Uuid;

#[derive(Parser, Debug)]
#[command(about = "Focused workout-session benchmark against the server gRPC surface")]
struct Args {
    #[arg(short, long, default_value = "http://127.0.0.1:50051")]
    addr: String,
    #[arg(long, default_value_t = 300)]
    users: usize,
    #[arg(long, default_value_t = 3)]
    group_size: usize,
    #[arg(long, default_value_t = 10)]
    sets_per_user: usize,
    #[arg(long, default_value_t = 1000)]
    poll_interval_ms: u64,
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

struct GlobalStats {
    active_users: AtomicU64,
    total_requests: AtomicU64,
    total_errors: AtomicU64,
    methods: DashMap<String, Arc<MethodStats>>,
}

impl GlobalStats {
    fn new() -> Self {
        Self {
            active_users: AtomicU64::new(0),
            total_requests: AtomicU64::new(0),
            total_errors: AtomicU64::new(0),
            methods: DashMap::new(),
        }
    }

    fn record(&self, method: &str, latency: Duration, is_error: bool) {
        self.total_requests.fetch_add(1, Ordering::Relaxed);
        if is_error {
            self.total_errors.fetch_add(1, Ordering::Relaxed);
        }
        let stats = self
            .methods
            .entry(method.to_string())
            .or_insert_with(|| Arc::new(MethodStats::new()));
        stats.record(latency, is_error);
    }
}

#[derive(Default)]
struct GroupRegistry {
    leaders: DashMap<usize, String>,
}

fn now_unix() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();
    let stats = Arc::new(GlobalStats::new());
    let registry = Arc::new(GroupRegistry::default());
    let started = Instant::now();

    let reporter = Arc::clone(&stats);
    tokio::spawn(async move {
        let mut last_total = 0;
        let mut last = Instant::now();
        let mut last_method = std::collections::HashMap::new();
        loop {
            tokio::time::sleep(Duration::from_secs(5)).await;
            let elapsed = last.elapsed().as_secs_f64().max(0.001);
            let total = reporter.total_requests.load(Ordering::Relaxed);
            println!(
                "\n[{:4.0}s] Users: {:4} | RPS: {:7.1} | Errors: {}",
                started.elapsed().as_secs_f64(),
                reporter.active_users.load(Ordering::Relaxed),
                (total - last_total) as f64 / elapsed,
                reporter.total_errors.load(Ordering::Relaxed)
            );
            let mut methods: Vec<_> = reporter
                .methods
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
                let prev = last_method.get(&name).copied().unwrap_or(0);
                let qps = (reqs - prev) as f64 / elapsed;
                last_method.insert(name.clone(), reqs);
                let avg = if reqs > 0 {
                    ms.total_latency_ms.load(Ordering::Relaxed) as f64 / reqs as f64
                } else {
                    0.0
                };
                println!(
                    "  {:28}: qps={:7.1}, avg={:6.1}ms, max={:6.1}ms, req={:<5}, err={}",
                    name,
                    qps,
                    avg,
                    ms.max_latency_ms.load(Ordering::Relaxed) as f64,
                    reqs,
                    ms.errors.load(Ordering::Relaxed)
                );
            }
            last_total = total;
            last = Instant::now();
        }
    });

    let run_id = rand::thread_rng().gen_range(1000..9999);
    let mut handles = Vec::new();
    for idx in 0..args.users {
        let username = format!("__session_bench_{}_{}", run_id, idx);
        let addr = args.addr.clone();
        let stats = Arc::clone(&stats);
        let registry = Arc::clone(&registry);
        let group_size = args.group_size.max(1);
        let sets_per_user = args.sets_per_user;
        let poll_interval_ms = args.poll_interval_ms;
        let group_idx = idx / group_size;
        let is_leader = idx % group_size == 0;
        handles.push(tokio::spawn(async move {
            stats.active_users.fetch_add(1, Ordering::Relaxed);
            let res = run_user(UserConfig {
                username,
                addr,
                stats: stats.clone(),
                registry,
                group_idx,
                is_leader,
                sets_per_user,
                poll_interval_ms,
            })
            .await;
            if let Err(err) = res {
                eprintln!("user failed: {err}");
            }
            stats.active_users.fetch_sub(1, Ordering::Relaxed);
        }));
    }

    for handle in handles {
        let _ = handle.await;
    }
    Ok(())
}

async fn connect_channel(addr: &str) -> Result<Channel, Box<dyn std::error::Error + Send + Sync>> {
    Ok(Endpoint::from_shared(addr.to_string())?.connect().await?)
}

async fn timed_call<C, Req, Res, F>(
    client: &mut C,
    token: &MetadataValue<tonic::metadata::Ascii>,
    stats: &Arc<GlobalStats>,
    method: &str,
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
    let start = Instant::now();
    let mut req = Request::new(request);
    req.metadata_mut().insert("x-session-token", token.clone());
    let res = call_fn(client, req).await;
    stats.record(method, start.elapsed(), res.is_err());
    res.map(|r| r.into_inner())
}

struct UserConfig {
    username: String,
    addr: String,
    stats: Arc<GlobalStats>,
    registry: Arc<GroupRegistry>,
    group_idx: usize,
    is_leader: bool,
    sets_per_user: usize,
    poll_interval_ms: u64,
}

async fn run_user(config: UserConfig) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let username = config.username;
    let addr = config.addr;
    let stats = config.stats;
    let registry = config.registry;
    let group_idx = config.group_idx;
    let is_leader = config.is_leader;
    let sets_per_user = config.sets_per_user;
    let poll_interval_ms = config.poll_interval_ms;

    let channel = connect_channel(&addr).await?;
    let mut auth = AuthServiceClient::new(channel.clone());
    let mut workout = WorkoutServiceClient::new(channel.clone());
    let mut settings = SettingsServiceClient::new(channel.clone());
    let mut multiplayer = MultiplayerServiceClient::new(channel);

    let login_start = Instant::now();
    let auth_res = auth
        .test_login(TestLoginRequest {
            username: username.clone(),
        })
        .await;
    stats.record("TestLogin", login_start.elapsed(), auth_res.is_err());
    let auth_res = auth_res?.into_inner();
    let token: MetadataValue<_> = auth_res.session_token.parse()?;
    let user_id = auth_res.user_id.clone();

    let _ = timed_call(
        &mut settings,
        &token,
        &stats,
        "GetTrainingProgramCatalog",
        |c, req| Box::pin(c.get_training_program_catalog(req)),
        GetTrainingProgramCatalogRequest {},
    )
    .await?;
    let _ = timed_call(
        &mut settings,
        &token,
        &stats,
        "GetSettings",
        |c, req| Box::pin(c.get_settings(req)),
        GetSettingsRequest {},
    )
    .await?;
    let _ = timed_call(
        &mut settings,
        &token,
        &stats,
        "GetActiveTrainingProgramState",
        |c, req| Box::pin(c.get_active_training_program_state(req)),
        GetActiveTrainingProgramStateRequest {},
    )
    .await?;
    let _ = timed_call(
        &mut workout,
        &token,
        &stats,
        "GetActiveWorkout",
        |c, req| Box::pin(c.get_active_workout(req)),
        GetActiveWorkoutRequest {},
    )
    .await?;
    let _proposed = timed_call(
        &mut workout,
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

    let startup_session = timed_call(
        &mut multiplayer,
        &token,
        &stats,
        "GetCurrentSession",
        |c, req| Box::pin(c.get_current_session(req)),
        GetCurrentSessionRequest {},
    )
    .await?;
    let mut current_session_id = if startup_session.session_id.is_empty() {
        None
    } else {
        Some(startup_session.session_id)
    };

    if is_leader {
        let mut req = Request::new(GetMyInviteTokenRequest {});
        req.metadata_mut().insert("x-session-token", token.clone());
        let invite_token = multiplayer.get_my_invite_token(req).await?.into_inner().invite_token;
        registry.leaders.insert(group_idx, invite_token);
    } else {
        let leader_invite = loop {
            if let Some(found) = registry.leaders.get(&group_idx) {
                break found.clone();
            }
            tokio::time::sleep(Duration::from_millis(50)).await;
        };
        let req_start = Instant::now();
        let mut req = Request::new(JoinViaInviteRequest {
            invite_token: leader_invite,
        });
        req.metadata_mut().insert("x-session-token", token.clone());
        let join_res = multiplayer.join_via_invite(req).await;
        stats.record("JoinViaInvite", req_start.elapsed(), join_res.is_err());
        let joined = join_res?.into_inner();
        current_session_id = Some(joined.session_id);
    }

    let poll_task = current_session_id.clone().map(|_session_id| {
        let token = token.clone();
        let stats = Arc::clone(&stats);
        let addr = addr.clone();
        tokio::spawn(async move {
            let channel = match connect_channel(&addr).await {
                Ok(ch) => ch,
                Err(_) => return,
            };
            let mut client = MultiplayerServiceClient::new(channel);
            loop {
                let start = Instant::now();
                let mut req = Request::new(GetCurrentSessionRequest {});
                req.metadata_mut().insert("x-session-token", token.clone());
                let res = client.get_current_session(req).await;
                stats.record("GetCurrentSession", start.elapsed(), res.is_err());
                if res.is_err() {
                    break;
                }
                tokio::time::sleep(Duration::from_millis(poll_interval_ms)).await;
            }
        })
    });

    let groups = build_start_workout_groups();
    let started = timed_call(
        &mut workout,
        &token,
        &stats,
        "StartWorkout",
        |c, req| Box::pin(c.start_workout(req)),
        StartWorkoutRequest {
            name: "bench".to_string(),
            exercise_groups: groups,
            started_at: now_unix(),
        },
    )
    .await?;
    let workout_id = started.id.clone();

    if current_session_id.is_some() {
        let _ = timed_call(
            &mut multiplayer,
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

    let mut proposed_sets = started.proposed_sets;
    proposed_sets.sort_by_key(|s| s.workout_order);
    for (idx, set) in proposed_sets.into_iter().take(sets_per_user).enumerate() {
        let start_set = WorkoutMutation {
            event_id: Uuid::new_v4().to_string(),
            client_created_at: now_unix(),
            mutation: Some(workout_mutation::Mutation::StartSet(
                schlift::workout::v1::StartSetRequest {
                    workout_id: workout_id.clone(),
                    proposed_set_id: set.id.clone(),
                    started_at: now_unix(),
                },
            )),
        };
        let complete_set = WorkoutMutation {
            event_id: Uuid::new_v4().to_string(),
            client_created_at: now_unix(),
            mutation: Some(workout_mutation::Mutation::CompleteSet(
                CompleteSetRequest {
                    workout_id: workout_id.clone(),
                    proposed_set_id: set.id.clone(),
                    actual_reps: set.target_reps,
                    actual_weight: set.target_weight,
                    completed_at: now_unix(),
                },
            )),
        };
        let _ = timed_call(
            &mut workout,
            &token,
            &stats,
            "AppendMutations",
            |c, req| Box::pin(c.append_workout_mutations(req)),
            AppendWorkoutMutationsRequest {
                mutations: vec![start_set, complete_set],
            },
        )
        .await?;

        if idx % 3 == 0 {
            let _ = timed_call(
                &mut workout,
                &token,
                &stats,
                "AppendHeartRate",
                |c, req| Box::pin(c.append_workout_heart_rate(req)),
                AppendWorkoutHeartRateRequest {
                    workout_id: workout_id.clone(),
                    samples: vec![WorkoutHeartRatePoint {
                        sampled_at: now_unix(),
                        bpm: 120.0,
                        availability: 1,
                    }],
                },
            )
            .await?;
        }
    }

    let _ = timed_call(
        &mut workout,
        &token,
        &stats,
        "EndWorkout",
        |c, req| Box::pin(c.end_workout(req)),
        EndWorkoutRequest {
            workout_id: workout_id.clone(),
            ended_at: now_unix(),
        },
    )
    .await?;

    if let Some(_session_id) = current_session_id {
        let _ = timed_call(
            &mut multiplayer,
            &token,
            &stats,
            "GetCurrentSession",
            |c, req| Box::pin(c.get_current_session(req)),
            GetCurrentSessionRequest {},
        )
        .await?;
    }

    if let Some(handle) = poll_task {
        handle.abort();
    }
    Ok(())
}

fn build_start_workout_groups() -> Vec<ExerciseGroup> {
    vec![ExerciseGroup {
        id: Uuid::new_v4().to_string(),
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
    }]
}
