use clap::Parser;
use lift::workout::v1::{
    auth_service_client::AuthServiceClient,
    multiplayer_service_client::MultiplayerServiceClient,
    workout_service_client::WorkoutServiceClient,
    CreateExerciseGroupRequest, EndWorkoutRequest, GetActiveWorkoutRequest,
    GetCurrentSessionRequest, GetProposedWorkoutScheduleRequest, JoinSessionRequest,
    StartSessionRequest, StartWorkoutRequest, TestLoginRequest,
    Exercise, ExerciseGroupType, StartSetRequest, CompleteSetRequest,
};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::{Mutex, RwLock};
use tonic::metadata::MetadataValue;
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
    requests: u64,
    errors: u64,
    total_latency: Duration,
    max_latency: Duration,
}

impl MethodStats {
    fn new() -> Self {
        Self {
            requests: 0,
            errors: 0,
            total_latency: Duration::ZERO,
            max_latency: Duration::ZERO,
        }
    }

    fn record(&mut self, latency: Duration, is_error: bool) {
        self.requests += 1;
        if is_error {
            self.errors += 1;
        } else {
            self.total_latency += latency;
            if latency > self.max_latency {
                self.max_latency = latency;
            }
        }
    }
}

struct GlobalStats {
    total_requests: u64,
    total_errors: u64,
    method_stats: std::collections::HashMap<String, MethodStats>,
    active_users: usize,
    latency_threshold_exceeded: bool,
}

impl GlobalStats {
    fn new() -> Self {
        Self {
            total_requests: 0,
            total_errors: 0,
            method_stats: std::collections::HashMap::new(),
            active_users: 0,
            latency_threshold_exceeded: false,
        }
    }

    fn record(&mut self, method: &str, latency: Duration, is_error: bool) {
        self.total_requests += 1;
        let stats = self.method_stats.entry(method.to_string()).or_insert_with(MethodStats::new);
        stats.record(latency, is_error);
        
        if is_error {
            self.total_errors += 1;
        } else if latency.as_secs() >= 1 {
            self.latency_threshold_exceeded = true;
        }
    }
}

#[derive(Default)]
struct SessionRegistry {
    // Maps group_index to session_id
    sessions: std::collections::HashMap<usize, String>,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();
    let stats = Arc::new(Mutex::new(GlobalStats::new()));
    let session_registry = Arc::new(RwLock::new(SessionRegistry::default()));
    let start_time = Instant::now();
    let duration = Duration::from_secs(args.duration);

    println!("Starting simulation against {} (duration={}s)", 
             args.addr, args.duration);

    // Reporting task
    let stats_reporter = Arc::clone(&stats);
    tokio::spawn(async move {
        let mut last_requests = 0;
        let mut last_time = Instant::now();

        loop {
            tokio::time::sleep(Duration::from_secs(5)).await;
            let mut s = stats_reporter.lock().await;
            let current_requests = s.total_requests;
            let elapsed = last_time.elapsed().as_secs_f64();
            let rps = (current_requests - last_requests) as f64 / elapsed;
            
            println!(
                "[{:4.0}s] Users: {:3} | RPS: {:6.1} | Errors: {}",
                start_time.elapsed().as_secs_f64(),
                s.active_users,
                rps,
                s.total_errors
            );

            let mut methods: Vec<_> = s.method_stats.iter().collect();
            methods.sort_by(|a, b| b.1.max_latency.cmp(&a.1.max_latency));

            for (name, ms) in methods.iter().take(5) {
                let avg = if ms.requests > 0 {
                    ms.total_latency.as_millis() as f64 / ms.requests as f64
                } else {
                    0.0
                };
                println!("  {:25}: avg={:6.1}ms, max={:6.1}ms, req={:<4}, err={}", 
                         name, avg, ms.max_latency.as_millis() as f64, ms.requests, ms.errors);
            }

            if s.latency_threshold_exceeded {
                println!("LATENCY THRESHOLD EXCEEDED (>= 1s)!");
            }

            last_requests = current_requests;
            last_time = Instant::now();
            // Clear method stats for next window
            s.method_stats.clear();
        }
    });

    let session_id_prefix = {
        let mut rng = rand::thread_rng();
        rng.gen_range(1000..9999)
    };

    // Exponential ramp up: user_count = 1.1^time
    let mut current_user_count = 0;
    loop {
        let elapsed = start_time.elapsed().as_secs_f64();
        if elapsed >= args.duration as f64 {
            break;
        }

        {
            let s = stats.lock().await;
            if s.latency_threshold_exceeded {
                println!("Stopping ramp-up due to latency threshold.");
                break;
            }
        }

        // target_users grows exponentially with time
        // 1.1^60 ~= 304 users
        // 1.1^90 ~= 5313 users
        let target_users = 1.1_f64.powf(elapsed).floor() as usize;

        while current_user_count < target_users {
            let user_index = current_user_count;
            let addr = args.addr.clone();
            let stats = Arc::clone(&stats);
            let registry = Arc::clone(&session_registry);
            let username = format!("__test__sim_{}_{}", session_id_prefix, user_index);

            tokio::spawn(async move {
                {
                    let mut s = stats.lock().await;
                    s.active_users += 1;
                }

                if let Err(e) = run_user_simulation(username, user_index, addr, stats.clone(), registry, start_time, duration).await {
                    // Ignore errors during shutdown or if they are just timeouts we are looking for
                    if !e.to_string().contains("transport error") {
                        eprintln!("User simulation failed: {}", e);
                    }
                    let mut s = stats.lock().await;
                    s.total_errors += 1;
                }

                {
                    let mut s = stats.lock().await;
                    s.active_users -= 1;
                }
            });

            current_user_count += 1;
        }

        tokio::time::sleep(Duration::from_millis(500)).await;
    }

    // Wait for duration to finish
    let remaining = duration.saturating_sub(start_time.elapsed());
    if !remaining.is_zero() {
        tokio::time::sleep(remaining).await;
    }

    println!("Simulation finished.");
    Ok(())
}

async fn run_user_simulation(
    username: String,
    user_index: usize,
    addr: String,
    stats: Arc<Mutex<GlobalStats>>,
    session_registry: Arc<RwLock<SessionRegistry>>,
    start_time: Instant,
    total_duration: Duration,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let mut auth_client = AuthServiceClient::connect(addr.clone()).await?;
    
    // Login
    let login_resp = auth_client.test_login(TestLoginRequest { username: username.clone() }).await?.into_inner();
    let token: MetadataValue<_> = login_resp.session_token.parse()?;

    let mut workout_client = WorkoutServiceClient::connect(addr.clone()).await?;
    let mut multiplayer_client = MultiplayerServiceClient::connect(addr).await?;

    // Periodic GetCurrentSession every 1s
    let stats_1s = Arc::clone(&stats);
    let token_1s = token.clone();
    let mut multiplayer_client_1s = multiplayer_client.clone();
    let session_loop_handle = tokio::spawn(async move {
        let mut interval = tokio::time::interval(Duration::from_secs(1));
        loop {
            interval.tick().await;
            
            let req_start = Instant::now();
            let mut req = Request::new(GetCurrentSessionRequest { session_id: String::new() });
            req.metadata_mut().insert("x-session-token", token_1s.clone());
            
            let res = multiplayer_client_1s.get_current_session(req).await;
            let latency = req_start.elapsed();
            
            let mut s = stats_1s.lock().await;
            s.record("GetCurrentSession", latency, res.is_err());
        }
    });

    // Grouping: users [0,1,2,3] are group 0, [4,5,6,7] are group 1...
    let group_index = user_index / 4;
    let is_leader = user_index % 4 == 0;

    // Scripted actions
    while start_time.elapsed() < total_duration {
        // 1. Initial check
        perform_request(&mut workout_client, &token, &stats, GetActiveWorkoutRequest {}, "GetActiveWorkout").await?;
        
        // 2. Get proposed schedule
        let _schedule = perform_request(&mut workout_client, &token, &stats, GetProposedWorkoutScheduleRequest {
            user_id: login_resp.user_id.clone()
        }, "GetProposedSchedule").await?;
        
        // 3. Start workout
        let workout_id = perform_request(&mut workout_client, &token, &stats, StartWorkoutRequest {
            name: "Simulated Workout".to_string(),
            exercise_groups: vec![],
            proposed_sets: vec![],
        }, "StartWorkout").await?.id;

        // Multiplayer logic: Leader starts session, others join.
        if is_leader {
            let mut req = Request::new(StartSessionRequest { workout_id: workout_id.clone() });
            req.metadata_mut().insert("x-session-token", token.clone());
            
            let req_start = Instant::now();
            let res = multiplayer_client.start_session(req).await;
            let latency = req_start.elapsed();
            
            let mut s = stats.lock().await;
            s.record("StartSession", latency, res.is_err());
            
            if let Ok(res) = res {
                let session_id = res.into_inner().session_id;
                let mut reg = session_registry.write().await;
                reg.sessions.insert(group_index, session_id);
            }
        } else {
            // Wait for leader to create session
            let mut session_id = None;
            for _ in 0..10 {
                {
                    let reg = session_registry.read().await;
                    if let Some(sid) = reg.sessions.get(&group_index) {
                        session_id = Some(sid.clone());
                        break;
                    }
                }
                tokio::time::sleep(Duration::from_secs(1)).await;
            }

            if let Some(sid) = session_id {
                let mut req = Request::new(JoinSessionRequest { session_id: sid, workout_id: workout_id.clone() });
                req.metadata_mut().insert("x-session-token", token.clone());
                
                let req_start = Instant::now();
                let res = multiplayer_client.join_session(req).await;
                let latency = req_start.elapsed();
                
                let mut s = stats.lock().await;
                s.record("JoinSession", latency, res.is_err());
            }
        }

        let num_groups = {
            let mut rng = rand::thread_rng();
            rng.gen_range(2..5)
        };
        
        for g_idx in 0..num_groups {
            // 4. Add exercise group
            let exercises = vec![
                Exercise::Squat, Exercise::BenchPress, Exercise::Deadlift, 
                Exercise::OverheadPress, Exercise::BarbellRow
            ];
            let exercise = {
                let mut rng = rand::thread_rng();
                exercises.choose(&mut rng).copied().unwrap_or(Exercise::Squat)
            };
            
            let (sets_val, weight_val) = {
                let mut rng = rand::thread_rng();
                (rng.gen_range(3..6), rng.gen_range(20..100) as f32)
            };

            let group_res = perform_request(&mut workout_client, &token, &stats, CreateExerciseGroupRequest {
                workout_id: workout_id.clone(),
                name: format!("Group {}", g_idx),
                r#type: ExerciseGroupType::Straight as i32,
                exercises: vec![exercise as i32],
                sets: sets_val,
                reps: 5,
                weights: vec![weight_val],
                include_warmup: true,
            }, "CreateExerciseGroup").await?;
            
            for p_set in group_res.generated_sets {
                // 5. Start set
                perform_request(&mut workout_client, &token, &stats, StartSetRequest {
                    workout_id: workout_id.clone(),
                    proposed_set_id: p_set.id.clone(),
                }, "StartSet").await?;
                
                // Simulate lifting (5-10s)
                let lift_duration = {
                    let mut rng = rand::thread_rng();
                    rng.gen_range(5..10)
                };
                tokio::time::sleep(Duration::from_secs(lift_duration)).await;
                
                // 6. Complete set
                perform_request(&mut workout_client, &token, &stats, CompleteSetRequest {
                    workout_id: workout_id.clone(),
                    proposed_set_id: p_set.id.clone(),
                    actual_reps: p_set.target_reps,
                    actual_weight: p_set.target_weight,
                }, "CompleteSet").await?;
                
                // Simulate rest (5-15s for simulation purposes, don't want to wait too long)
                let rest_duration = {
                    let mut rng = rand::thread_rng();
                    rng.gen_range(5..15)
                };
                tokio::time::sleep(Duration::from_secs(rest_duration)).await;
            }
        }
        
        // 7. End workout
        perform_request(&mut workout_client, &token, &stats, EndWorkoutRequest {
            workout_id: workout_id.clone(),
        }, "EndWorkout").await?;
        
        // Idle between workouts
        let idle_duration = {
            let mut rng = rand::thread_rng();
            rng.gen_range(10..30)
        };
        tokio::time::sleep(Duration::from_secs(idle_duration)).await;
    }

    session_loop_handle.abort();
    Ok(())
}

async fn perform_request<C, Req, Res>(
    client: &mut C,
    token: &MetadataValue<tonic::metadata::Ascii>,
    stats: &Arc<Mutex<GlobalStats>>,
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
    let latency = req_start.elapsed();
    
    let mut s = stats.lock().await;
    s.record(method_name, latency, res.is_err());
    
    res.map(|r| r.into_inner())
}

// Trait to allow generic request performing
#[tonic::async_trait]
trait WorkoutServiceTrait<Req, Res> {
    async fn call(&mut self, req: Request<Req>) -> Result<tonic::Response<Res>, Status>;
}

#[tonic::async_trait]
impl WorkoutServiceTrait<GetActiveWorkoutRequest, lift::workout::v1::GetActiveWorkoutResponse> for WorkoutServiceClient<tonic::transport::Channel> {
    async fn call(&mut self, req: Request<GetActiveWorkoutRequest>) -> Result<tonic::Response<lift::workout::v1::GetActiveWorkoutResponse>, Status> {
        self.get_active_workout(req).await
    }
}

#[tonic::async_trait]
impl WorkoutServiceTrait<GetProposedWorkoutScheduleRequest, lift::workout::v1::GetProposedWorkoutScheduleResponse> for WorkoutServiceClient<tonic::transport::Channel> {
    async fn call(&mut self, req: Request<GetProposedWorkoutScheduleRequest>) -> Result<tonic::Response<lift::workout::v1::GetProposedWorkoutScheduleResponse>, Status> {
        self.get_proposed_workout_schedule(req).await
    }
}

#[tonic::async_trait]
impl WorkoutServiceTrait<StartWorkoutRequest, lift::workout::v1::StartWorkoutResponse> for WorkoutServiceClient<tonic::transport::Channel> {
    async fn call(&mut self, req: Request<StartWorkoutRequest>) -> Result<tonic::Response<lift::workout::v1::StartWorkoutResponse>, Status> {
        self.start_workout(req).await
    }
}

#[tonic::async_trait]
impl WorkoutServiceTrait<CreateExerciseGroupRequest, lift::workout::v1::CreateExerciseGroupResponse> for WorkoutServiceClient<tonic::transport::Channel> {
    async fn call(&mut self, req: Request<CreateExerciseGroupRequest>) -> Result<tonic::Response<lift::workout::v1::CreateExerciseGroupResponse>, Status> {
        self.create_exercise_group(req).await
    }
}

#[tonic::async_trait]
impl WorkoutServiceTrait<StartSetRequest, lift::workout::v1::StartSetResponse> for WorkoutServiceClient<tonic::transport::Channel> {
    async fn call(&mut self, req: Request<StartSetRequest>) -> Result<tonic::Response<lift::workout::v1::StartSetResponse>, Status> {
        self.start_set(req).await
    }
}

#[tonic::async_trait]
impl WorkoutServiceTrait<CompleteSetRequest, lift::workout::v1::CompleteSetResponse> for WorkoutServiceClient<tonic::transport::Channel> {
    async fn call(&mut self, req: Request<CompleteSetRequest>) -> Result<tonic::Response<lift::workout::v1::CompleteSetResponse>, Status> {
        self.complete_set(req).await
    }
}

#[tonic::async_trait]
impl WorkoutServiceTrait<EndWorkoutRequest, lift::workout::v1::EndWorkoutResponse> for WorkoutServiceClient<tonic::transport::Channel> {
    async fn call(&mut self, req: Request<EndWorkoutRequest>) -> Result<tonic::Response<lift::workout::v1::EndWorkoutResponse>, Status> {
        self.end_workout(req).await
    }
}

use tonic::Status;
use rand::seq::SliceRandom;
