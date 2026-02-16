use clap::Parser;
use dashmap::DashMap;
use lift::workout::v1::{
    auth_service_client::AuthServiceClient,
    multiplayer_service_client::MultiplayerServiceClient,
    workout_service_client::WorkoutServiceClient,
    CreateExerciseGroupRequest, EndWorkoutRequest, GetActiveWorkoutRequest,
    GetCurrentSessionRequest, GetProposedWorkoutScheduleRequest, JoinUserRequest,
    StartWorkoutRequest, TestLoginRequest,
    Exercise, ExerciseGroupType, StartSetRequest, CompleteSetRequest,
};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tonic::metadata::MetadataValue;
use tonic::transport::Channel;
use tonic::Request;
use rand::Rng;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Server address
    #[arg(short, long, default_value = "http://127.0.0.1:50051")]
    addr: String,

    /// How many seconds to run the simulation
    #[arg(short, long, default_value_t = 300)]
    duration: u64,
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
                match self.max_latency_ms.compare_exchange_weak(current_max, ms, Ordering::Relaxed, Ordering::Relaxed) {
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
        let stats = self.method_stats.entry(method.to_string()).or_insert_with(|| Arc::new(MethodStats::new()));
        stats.record(latency, is_error);
    }
}

#[derive(Default)]
struct SessionRegistry {
    leader_ids: DashMap<usize, String>,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();
    let stats = Arc::new(GlobalStats::new());
    let session_registry = Arc::new(SessionRegistry::default());
    let start_time = Instant::now();
    let duration = Duration::from_secs(args.duration);

    println!("Connecting to {}...", args.addr);
    let channel = Channel::from_shared(args.addr.clone())?
        .connect_timeout(Duration::from_secs(5))
        .connect()
        .await?;
    println!("Connected successfully.");

    println!("Starting simulation (duration={}s)", args.duration);

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
                "[{:4.0}s] Users: {:4} | RPS: {:7.1} | Errors: {}",
                start_time.elapsed().as_secs_f64(),
                stats_reporter.active_users.load(Ordering::Relaxed),
                rps,
                stats_reporter.total_errors.load(Ordering::Relaxed)
            );

            let mut methods: Vec<_> = stats_reporter.method_stats.iter().map(|r| (r.key().clone(), r.value().clone())).collect();
            methods.sort_by(|a, b| b.1.requests.load(Ordering::Relaxed).cmp(&a.1.requests.load(Ordering::Relaxed)));

            for (name, ms) in methods {
                let reqs = ms.requests.load(Ordering::Relaxed);
                let last_reqs = method_last_counts.get(&name).copied().unwrap_or(0);
                let interval_qps = (reqs - last_reqs) as f64 / elapsed;
                method_last_counts.insert(name.clone(), reqs);

                let active_users = stats_reporter.active_users.load(Ordering::Relaxed);
                let qps_per_user = if active_users > 0 { interval_qps / active_users as f64 } else { 0.0 };

                let errs = ms.errors.load(Ordering::Relaxed);
                let total_ms = ms.total_latency_ms.load(Ordering::Relaxed);
                let max_ms = ms.max_latency_ms.load(Ordering::Relaxed);
                let avg = if reqs > 0 { total_ms as f64 / reqs as f64 } else { 0.0 };
                println!("  {:25}: qps={:7.1}, qps/u={:7.4}, avg={:6.1}ms, max={:6.1}ms, req={:<5}, err={}", 
                         name, interval_qps, qps_per_user, avg, max_ms as f64, reqs, errs);
            }
            last_requests = current_requests;
            last_time = Instant::now();
        }
    });

    let session_id_prefix = rand::thread_rng().gen_range(1000..9999);
    let mut current_group_count = 0;
    
    loop {
        let elapsed = start_time.elapsed().as_secs_f64();
        if elapsed >= args.duration as f64 { break; }

        let target_groups = (elapsed * 100.0).floor() as usize + 1;

        while current_group_count < target_groups {
            let group_index = current_group_count;
            let channel = channel.clone();
            let stats = Arc::clone(&stats);
            let registry = Arc::clone(&session_registry);
            
            tokio::spawn(async move {
                let group_size = {
                    let mut rng = rand::thread_rng();
                    rng.gen_range(3..5)
                };

                for member_index in 0..group_size {
                    let username = format!("__test__sim_{}_{}_{}", session_id_prefix, group_index, member_index);
                    let stats = Arc::clone(&stats);
                    let registry = Arc::clone(&registry);
                    let channel = channel.clone();
                    let is_leader = member_index == 0;

                    tokio::spawn(async move {
                        stats.active_users.fetch_add(1, Ordering::Relaxed);
                        if let Err(e) = run_user_simulation(username.clone(), group_index, is_leader, channel, stats.clone(), registry, start_time, duration).await {
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

async fn run_user_simulation(
    username: String,
    group_index: usize,
    is_leader: bool,
    channel: Channel,
    stats: Arc<GlobalStats>,
    session_registry: Arc<SessionRegistry>,
    start_time: Instant,
    total_duration: Duration,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let mut auth_client = AuthServiceClient::new(channel.clone());
    
    let login_start = Instant::now();
    let login_res = auth_client.test_login(TestLoginRequest { username: username.clone() }).await;
    stats.record("TestLogin", login_start.elapsed(), login_res.is_err());
    let login_resp = login_res?;
    let login_resp = login_resp.into_inner();
    
    let user_id = login_resp.user_id.clone();
    let token: MetadataValue<_> = login_resp.session_token.parse()?;

    if is_leader {
        session_registry.leader_ids.insert(group_index, user_id.clone());
    }

    let mut workout_client = WorkoutServiceClient::new(channel.clone());
    let mut multiplayer_client = MultiplayerServiceClient::new(channel.clone());

    // Background session polling
    let stats_bg = Arc::clone(&stats);
    let token_bg = token.clone();
    let mut multiplayer_bg = multiplayer_client.clone();
    let _session_loop = tokio::spawn(async move {
        let mut interval = tokio::time::interval(Duration::from_secs(2));
        loop {
            interval.tick().await;
            let req_start = Instant::now();
            let mut req = Request::new(GetCurrentSessionRequest { session_id: String::new() });
            req.metadata_mut().insert("x-session-token", token_bg.clone());
            let res = multiplayer_bg.get_current_session(req).await;
            stats_bg.record("GetCurrentSession", req_start.elapsed(), res.is_err());
            if res.is_err() { break; }
        }
    });

    if !is_leader {
        let mut leader_id = None;
        for _ in 0..30 {
            if let Some(id) = session_registry.leader_ids.get(&group_index) {
                leader_id = Some(id.clone());
                break;
            }
            tokio::time::sleep(Duration::from_millis(500)).await;
        }

        if let Some(lid) = leader_id {
            let mut req = Request::new(JoinUserRequest { user_id: lid });
            req.metadata_mut().insert("x-session-token", token.clone());
            let req_start = Instant::now();
            let res = multiplayer_client.join_user(req).await;
            stats.record("JoinUser", req_start.elapsed(), res.is_err());
        }
    }

    while start_time.elapsed() < total_duration {
        perform_request(&mut workout_client, &token, &stats, GetActiveWorkoutRequest {}, "GetActiveWorkout").await?;
        {
            let ms = rand::thread_rng().gen_range(500..1500);
            tokio::time::sleep(Duration::from_millis(ms)).await;
        }
        
        perform_request(&mut workout_client, &token, &stats, GetProposedWorkoutScheduleRequest { user_id: user_id.clone() }, "GetProposedSchedule").await?;
        {
            let ms = rand::thread_rng().gen_range(500..1500);
            tokio::time::sleep(Duration::from_millis(ms)).await;
        }
        
        let workout_id = perform_request(&mut workout_client, &token, &stats, StartWorkoutRequest {
            name: "Simulated Workout".to_string(),
            exercise_groups: vec![],
            proposed_sets: vec![],
        }, "StartWorkout").await?.id;

        for g_idx in 0..2 {
            {
                let ms = rand::thread_rng().gen_range(1000..3000);
                tokio::time::sleep(Duration::from_millis(ms)).await;
            }
            let group_res = perform_request(&mut workout_client, &token, &stats, CreateExerciseGroupRequest {
                workout_id: workout_id.clone(),
                name: format!("Group {}", g_idx),
                r#type: ExerciseGroupType::Straight as i32,
                exercises: vec![Exercise::Squat as i32],
                sets: 3,
                reps: 5,
                weights: vec![100.0],
                include_warmup: false,
            }, "CreateExerciseGroup").await?;
            
            for p_set in group_res.generated_sets {
                // Simulate "getting ready"
                {
                    let ms = rand::thread_rng().gen_range(500..2000);
                    tokio::time::sleep(Duration::from_millis(ms)).await;
                }
                
                perform_request(&mut workout_client, &token, &stats, StartSetRequest { workout_id: workout_id.clone(), proposed_set_id: p_set.id.clone() }, "StartSet").await?;
                
                // Simulate doing the set (2-5 seconds)
                {
                    let ms = rand::thread_rng().gen_range(2000..5000);
                    tokio::time::sleep(Duration::from_millis(ms)).await;
                }
                
                perform_request(&mut workout_client, &token, &stats, CompleteSetRequest {
                    workout_id: workout_id.clone(),
                    proposed_set_id: p_set.id.clone(),
                    actual_reps: p_set.target_reps,
                    actual_weight: p_set.target_weight,
                }, "CompleteSet").await?;
                
                // Simulate rest (2-5 seconds)
                {
                    let ms = rand::thread_rng().gen_range(2000..5000);
                    tokio::time::sleep(Duration::from_millis(ms)).await;
                }
            }
        }
        
        {
            let ms = rand::thread_rng().gen_range(1000..3000);
            tokio::time::sleep(Duration::from_millis(ms)).await;
        }
        perform_request(&mut workout_client, &token, &stats, EndWorkoutRequest { workout_id: workout_id.clone() }, "EndWorkout").await?;
        
        // Gap between workouts
        {
            let ms = rand::thread_rng().gen_range(5000..10000);
            tokio::time::sleep(Duration::from_millis(ms)).await;
        }
    }

    Ok(())
}

async fn perform_request<C, Req, Res>(
    client: &mut C,
    token: &MetadataValue<tonic::metadata::Ascii>,
    stats: &Arc<GlobalStats>,
    request: Req,
    method_name: &str,
) -> Result<Res, Status> 
where 
    C: WorkoutServiceTrait<Req, Res>,
{
    let req_start = Instant::now();
    let mut req = Request::new(request);
    req.metadata_mut().insert("x-session-token", token.clone());
    let res = client.call(req).await;
    stats.record(method_name, req_start.elapsed(), res.is_err());
    res.map(|r| r.into_inner())
}

#[tonic::async_trait]
trait WorkoutServiceTrait<Req, Res> {
    async fn call(&mut self, req: Request<Req>) -> Result<tonic::Response<Res>, Status>;
}

#[tonic::async_trait]
impl WorkoutServiceTrait<GetActiveWorkoutRequest, lift::workout::v1::GetActiveWorkoutResponse> for WorkoutServiceClient<Channel> {
    async fn call(&mut self, req: Request<GetActiveWorkoutRequest>) -> Result<tonic::Response<lift::workout::v1::GetActiveWorkoutResponse>, Status> {
        self.get_active_workout(req).await
    }
}

#[tonic::async_trait]
impl WorkoutServiceTrait<GetProposedWorkoutScheduleRequest, lift::workout::v1::GetProposedWorkoutScheduleResponse> for WorkoutServiceClient<Channel> {
    async fn call(&mut self, req: Request<GetProposedWorkoutScheduleRequest>) -> Result<tonic::Response<lift::workout::v1::GetProposedWorkoutScheduleResponse>, Status> {
        self.get_proposed_workout_schedule(req).await
    }
}

#[tonic::async_trait]
impl WorkoutServiceTrait<StartWorkoutRequest, lift::workout::v1::StartWorkoutResponse> for WorkoutServiceClient<Channel> {
    async fn call(&mut self, req: Request<StartWorkoutRequest>) -> Result<tonic::Response<lift::workout::v1::StartWorkoutResponse>, Status> {
        self.start_workout(req).await
    }
}

#[tonic::async_trait]
impl WorkoutServiceTrait<CreateExerciseGroupRequest, lift::workout::v1::CreateExerciseGroupResponse> for WorkoutServiceClient<Channel> {
    async fn call(&mut self, req: Request<CreateExerciseGroupRequest>) -> Result<tonic::Response<lift::workout::v1::CreateExerciseGroupResponse>, Status> {
        self.create_exercise_group(req).await
    }
}

#[tonic::async_trait]
impl WorkoutServiceTrait<StartSetRequest, lift::workout::v1::StartSetResponse> for WorkoutServiceClient<Channel> {
    async fn call(&mut self, req: Request<StartSetRequest>) -> Result<tonic::Response<lift::workout::v1::StartSetResponse>, Status> {
        self.start_set(req).await
    }
}

#[tonic::async_trait]
impl WorkoutServiceTrait<CompleteSetRequest, lift::workout::v1::CompleteSetResponse> for WorkoutServiceClient<Channel> {
    async fn call(&mut self, req: Request<CompleteSetRequest>) -> Result<tonic::Response<lift::workout::v1::CompleteSetResponse>, Status> {
        self.complete_set(req).await
    }
}

#[tonic::async_trait]
impl WorkoutServiceTrait<EndWorkoutRequest, lift::workout::v1::EndWorkoutResponse> for WorkoutServiceClient<Channel> {
    async fn call(&mut self, req: Request<EndWorkoutRequest>) -> Result<tonic::Response<lift::workout::v1::EndWorkoutResponse>, Status> {
        self.end_workout(req).await
    }
}

use tonic::Status;
