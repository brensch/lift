//! One simulated user. It signs up with a software passkey, onboards and
//! trains through the phone's own core (schlift_native's `Store`), and keeps
//! the account synced the way the app does (app/lib/services/account_sync.dart):
//! every write pushes what the server hasn't acknowledged, a heartbeat goes
//! up every few seconds, and the server's head acknowledges.

use crate::metrics::Metrics;
use crate::server::ORIGIN;
use crate::Profile;
use prost::Message;
use rand::Rng;
use schlift::workout::v1::auth_service_client::AuthServiceClient;
use schlift::workout::v1::multiplayer_service_client::MultiplayerServiceClient;
use schlift::workout::v1::sync_service_client::SyncServiceClient;
use schlift::workout::v1::workout_mutation::Mutation;
use schlift::workout::v1::workout_service_client::WorkoutServiceClient;
use schlift::workout::v1::*;
use schlift_native::store::Store;
use std::collections::VecDeque;
use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use tokio::sync::{mpsc, watch};
use tokio_stream::wrappers::ReceiverStream;
use tonic::transport::Channel;
use tonic::Request;
use url::Url;
use webauthn_authenticator_rs::softpasskey::SoftPasskey;
use webauthn_authenticator_rs::WebauthnAuthenticator;
use webauthn_rs_proto::{CreationChallengeResponse, RequestChallengeResponse};

const APP_VERSION: &str = "0.14.1";

/// How a client takes part in multiplayer.
pub enum Role {
    Solo,
    /// Shares its invite token for the others in its group.
    Leads(watch::Sender<Option<String>>),
    /// Joins its group's leader through the leader's invite token.
    Joins(watch::Receiver<Option<String>>),
}

/// What a client leaves behind, for checking against the server.
pub struct Outcome {
    pub username: String,
    pub token: String,
    pub events: Vec<Event>,
}

pub struct Client {
    username: String,
    /// Stands in for the client's address: the server limits passkey
    /// ceremonies per address, and every load client is really 127.0.0.1.
    ip: String,
    token: String,
    channel: Channel,
    metrics: Arc<Metrics>,
    profile: Profile,
    passkey: WebauthnAuthenticator<SoftPasskey>,
    store: Option<Store>,
    up: Option<mpsc::Sender<SyncRequest>>,
    head: watch::Receiver<i64>,
    head_tx: watch::Sender<i64>,
    sent_up_to: i64,
    /// Pushes awaiting the head that acknowledges them: (last seq, sent).
    in_flight: Arc<Mutex<VecDeque<(i64, Instant)>>>,
    lost: Arc<AtomicBool>,
}

impl Client {
    pub fn new(
        n: usize,
        run: &str,
        channel: Channel,
        metrics: Arc<Metrics>,
        profile: Profile,
    ) -> Self {
        let (head_tx, head) = watch::channel(0);
        Client {
            username: format!("load-{run}-{n}"),
            ip: format!("10.{}.{}.{}", (n >> 16) & 255, (n >> 8) & 255, n & 255),
            token: String::new(),
            channel,
            metrics,
            profile,
            passkey: WebauthnAuthenticator::new(SoftPasskey::new(true)),
            store: None,
            up: None,
            head,
            head_tx,
            sent_up_to: 0,
            in_flight: Arc::default(),
            lost: Arc::default(),
        }
    }

    /// Sign up, onboard, train until `stop`, then sync everything.
    pub async fn run(
        mut self,
        role: Role,
        mut stop: watch::Receiver<bool>,
    ) -> Result<Outcome, String> {
        self.sign_up().await?;
        self.sign_in().await?;
        self.onboard().await?;
        self.dial().await?;
        self.push().await?;
        self.group(role).await?;
        while !*stop.borrow() {
            let idle = self.jitter(self.profile.idle);
            if self.pause(idle, None, &mut stop).await? {
                break;
            }
            self.workout(&mut stop).await?;
            self.web_reads().await?;
        }
        self.drain().await?;
        let events = self.store()?.events_after(0)?;
        Ok(Outcome {
            username: self.username,
            token: self.token,
            events,
        })
    }

    fn request<T>(&self, message: T) -> Request<T> {
        let mut request = Request::new(message);
        let metadata = request.metadata_mut();
        if !self.token.is_empty() {
            metadata.insert("x-session-token", self.token.parse().expect("ascii token"));
        }
        metadata.insert("x-app-version", APP_VERSION.parse().expect("ascii"));
        metadata.insert("x-platform", "loadtest".parse().expect("ascii"));
        metadata.insert("x-forwarded-for", self.ip.parse().expect("ascii"));
        request
    }

    fn store(&mut self) -> Result<&mut Store, String> {
        self.store
            .as_mut()
            .ok_or_else(|| "not signed in".to_string())
    }

    fn jitter(&self, around: Duration) -> Duration {
        around.mul_f64(rand::thread_rng().gen_range(0.5..1.5))
    }

    // --- Signing up and in, with a real passkey ceremony ---

    async fn sign_up(&mut self) -> Result<(), String> {
        let metrics = self.metrics.clone();
        let mut auth = AuthServiceClient::new(self.channel.clone());
        let start = metrics
            .time(
                "auth.register_start",
                auth.register_start(self.request(RegisterStartRequest {
                    username: self.username.clone(),
                })),
            )
            .await?
            .into_inner();
        let options: CreationChallengeResponse =
            serde_json::from_str(&start.options_json).map_err(|e| e.to_string())?;
        let origin = Url::parse(ORIGIN).expect("origin");
        let credential = metrics.time_sync("passkey.create", || {
            self.passkey
                .do_registration(origin, options)
                .map_err(|e| format!("{e:?}"))
        })?;
        let finish = RegisterFinishRequest {
            user_id: start.user_id,
            credential_json: serde_json::to_string(&credential).map_err(|e| e.to_string())?,
            name: None,
        };
        let done = metrics
            .time(
                "auth.register_finish",
                auth.register_finish(self.request(finish)),
            )
            .await?
            .into_inner();
        self.token = done.session_token;
        self.store = Some(Store::open(
            Path::new(":memory:"),
            &done.user_id,
            &done.username,
        )?);
        Ok(())
    }

    /// A second device's sign-in with the same passkey: the login ceremony.
    async fn sign_in(&mut self) -> Result<(), String> {
        let metrics = self.metrics.clone();
        let mut auth = AuthServiceClient::new(self.channel.clone());
        let start = metrics
            .time(
                "auth.login_start",
                auth.login_start(self.request(LoginStartRequest {
                    username: Some(self.username.clone()),
                })),
            )
            .await?
            .into_inner();
        let options: RequestChallengeResponse =
            serde_json::from_str(&start.options_json).map_err(|e| e.to_string())?;
        let origin = Url::parse(ORIGIN).expect("origin");
        let credential = metrics.time_sync("passkey.sign", || {
            self.passkey
                .do_authentication(origin, options)
                .map_err(|e| format!("{e:?}"))
        })?;
        let finish = LoginFinishRequest {
            challenge_id: start.challenge_id,
            credential_json: serde_json::to_string(&credential).map_err(|e| e.to_string())?,
        };
        let done = metrics
            .time("auth.login_finish", auth.login_finish(self.request(finish)))
            .await?
            .into_inner();
        self.token = done.session_token;
        Ok(())
    }

    // --- The phone's core ---

    /// One call into the phone's core, as the app makes it through the
    /// bridge: a proto request in, a proto response out.
    fn core<Req: Message, Resp: Message + Default>(
        &mut self,
        method: &str,
        op: &'static str,
        request: Req,
    ) -> Result<Resp, String> {
        let metrics = self.metrics.clone();
        let bytes = request.encode_to_vec();
        let now = now_unix();
        let store = self.store()?;
        let response = metrics.time_sync(op, || store.call(method, &bytes, now))?;
        Resp::decode(response.as_slice()).map_err(|e| e.to_string())
    }

    fn mutate(&mut self, mutation: Mutation) -> Result<GetWorkoutResponse, String> {
        let response: AppendWorkoutMutationsResponse = self.core(
            "AppendWorkoutMutations",
            "core.mutate",
            AppendWorkoutMutationsRequest {
                mutations: vec![WorkoutMutation {
                    mutation: Some(mutation),
                }],
            },
        )?;
        Ok(response.workout_state.unwrap_or_default())
    }

    async fn onboard(&mut self) -> Result<(), String> {
        let _: CompleteOnboardingResponse = self.core(
            "CompleteOnboarding",
            "core.onboard",
            CompleteOnboardingRequest::default(),
        )?;
        Ok(())
    }

    // --- Sync, as account_sync.dart does it ---

    async fn dial(&mut self) -> Result<(), String> {
        let metrics = self.metrics.clone();
        let (up, rx) = mpsc::channel::<SyncRequest>(64);
        let mut sync = SyncServiceClient::new(self.channel.clone());
        let mut down = metrics
            .time(
                "sync.open",
                sync.sync(self.request(ReceiverStream::new(rx))),
            )
            .await?
            .into_inner();
        let (head, in_flight, lost) = (
            self.head_tx.clone(),
            self.in_flight.clone(),
            self.lost.clone(),
        );
        lost.store(false, Ordering::SeqCst);
        tokio::spawn(async move {
            loop {
                match down.message().await {
                    Ok(Some(SyncResponse { kind: Some(kind) })) => match kind {
                        sync_response::Kind::Head(h) => {
                            head.send_replace(h);
                            let mut in_flight = in_flight.lock().expect("in-flight lock");
                            while in_flight.front().is_some_and(|(seq, _)| *seq <= h) {
                                let (_, sent) = in_flight.pop_front().expect("front");
                                metrics.record("sync.push_acked", sent.elapsed());
                            }
                        }
                        sync_response::Kind::Session(_) => {
                            metrics.record("sync.session_update", Duration::ZERO)
                        }
                        _ => {}
                    },
                    Ok(Some(_)) => {}
                    Ok(None) => break,
                    Err(status) => {
                        metrics.error("sync.stream", status.code());
                        break;
                    }
                }
            }
            lost.store(true, Ordering::SeqCst);
        });
        self.up = Some(up);
        self.sent_up_to = 0;
        Ok(())
    }

    /// Send what the server hasn't acknowledged and this stream hasn't sent.
    async fn push(&mut self) -> Result<(), String> {
        if self.lost.load(Ordering::SeqCst) {
            self.metrics.record("sync.redial", Duration::ZERO);
            self.up = None;
            self.dial().await?;
        }
        let acked = *self.head.borrow();
        let sent_up_to = self.sent_up_to;
        let store = self.store()?;
        store.set_acked(acked)?;
        if store.seq() <= sent_up_to.max(acked) {
            return Ok(());
        }
        let events = store.events_after(acked)?;
        let last = events.last().map_or(acked, |e| e.seq);
        let packed = schlift_core::sync::pack(events);
        self.in_flight
            .lock()
            .expect("in-flight lock")
            .push_back((last, Instant::now()));
        self.send(sync_request::Kind::Events(packed)).await?;
        self.sent_up_to = last;
        Ok(())
    }

    async fn send(&mut self, kind: sync_request::Kind) -> Result<(), String> {
        let up = self.up.as_ref().ok_or("not connected")?;
        up.send(SyncRequest { kind: Some(kind) })
            .await
            .map_err(|_| "sync stream closed".to_string())
    }

    /// Wait `total`, heartbeating as the app does and, while training,
    /// sending heart rate. True if asked to stop.
    async fn pause(
        &mut self,
        total: Duration,
        training: Option<&str>,
        stop: &mut watch::Receiver<bool>,
    ) -> Result<bool, String> {
        let end = Instant::now() + total;
        loop {
            let left = end.saturating_duration_since(Instant::now());
            if left.is_zero() {
                return Ok(false);
            }
            let step = left.min(self.profile.heartbeat);
            tokio::select! {
                _ = tokio::time::sleep(step) => {}
                _ = stop.changed() => return Ok(true),
            }
            if let Some(workout_id) = training {
                self.heart_rate(workout_id).await?;
            } else {
                self.send(sync_request::Kind::Heartbeat(Heartbeat {}))
                    .await?;
            }
        }
    }

    /// Wait until the server holds every event, then hang up.
    async fn drain(&mut self) -> Result<(), String> {
        self.push().await?;
        let seq = self.store()?.seq();
        let deadline = Instant::now() + Duration::from_secs(60);
        while *self.head.borrow() < seq {
            if Instant::now() > deadline {
                self.metrics
                    .error("sync.drain", "server never acknowledged");
                return Err("sync.drain timed out".into());
            }
            tokio::time::sleep(Duration::from_millis(200)).await;
            self.push().await?;
        }
        self.up = None;
        Ok(())
    }

    // --- Training ---

    async fn group(&mut self, role: Role) -> Result<(), String> {
        let metrics = self.metrics.clone();
        let mut multiplayer = MultiplayerServiceClient::new(self.channel.clone());
        match role {
            Role::Solo => {}
            Role::Leads(share) => {
                let token = metrics
                    .time(
                        "rpc.get_invite_token",
                        multiplayer.get_my_invite_token(self.request(GetMyInviteTokenRequest {})),
                    )
                    .await?
                    .into_inner()
                    .invite_token;
                share.send_replace(Some(token));
            }
            Role::Joins(mut leader) => {
                let token = tokio::time::timeout(Duration::from_secs(120), async {
                    loop {
                        if let Some(token) = leader.borrow().clone() {
                            return Some(token);
                        }
                        if leader.changed().await.is_err() {
                            return None;
                        }
                    }
                })
                .await
                .ok()
                .flatten()
                .ok_or("leader never shared an invite")?;
                metrics
                    .time(
                        "rpc.join_via_invite",
                        multiplayer.join_via_invite(self.request(JoinViaInviteRequest {
                            invite_token: token,
                        })),
                    )
                    .await?;
            }
        }
        Ok(())
    }

    /// A workout as the app runs one: the suggestion from home, each set
    /// started and done with a tap each, the ramp's question answered, heart
    /// rate every few seconds, ended when the plan runs out (or at the
    /// profile's cap).
    async fn workout(&mut self, stop: &mut watch::Receiver<bool>) -> Result<(), String> {
        let home: GetHomeResponse = self.core(
            "GetHome",
            "core.get_home",
            GetHomeRequest { budget_minutes: 45 },
        )?;
        let template_id = if home.suggested_template_id.is_empty() {
            home.templates
                .first()
                .map(|t| t.id.clone())
                .unwrap_or_default()
        } else {
            home.suggested_template_id
        };
        let started: StartWorkoutResponse = self.core(
            "StartWorkout",
            "core.start_workout",
            StartWorkoutRequest {
                template_id,
                budget_minutes: 45,
                ..Default::default()
            },
        )?;
        self.push().await?;
        let id = started.id;
        let mut state = GetWorkoutResponse {
            next_up_set: started.next_up_set,
            ..Default::default()
        };
        for _ in 0..self.profile.max_sets {
            let rest = self.jitter(self.profile.set_every);
            if self.pause(rest, Some(&id), stop).await? {
                break;
            }
            if !state.rung_question_set_id.is_empty() {
                let reps_left = rand::thread_rng().gen_range(1..=3);
                state = self.mutate(Mutation::AnswerRung(AnswerRungRequest {
                    workout_id: id.clone(),
                    proposed_set_id: state.rung_question_set_id.clone(),
                    reps_left,
                    jump_lb: 0.0,
                }))?;
            } else if let Some(set) = state.next_up_set.clone() {
                self.mutate(Mutation::StartSet(StartSetRequest {
                    workout_id: id.clone(),
                    proposed_set_id: set.id.clone(),
                    started_at: 0,
                }))?;
                self.push().await?;
                let missed = i32::from(rand::thread_rng().gen_bool(0.15));
                state = self.mutate(Mutation::CompleteSet(CompleteSetRequest {
                    workout_id: id.clone(),
                    proposed_set_id: set.id,
                    actual_reps: (set.target_reps - missed).max(0),
                    actual_weight: set.target_weight,
                    completed_at: 0,
                }))?;
            } else {
                break;
            }
            self.push().await?;
        }
        let _: EndWorkoutResponse = self.core(
            "EndWorkout",
            "core.end_workout",
            EndWorkoutRequest {
                workout_id: id,
                ended_at: 0,
            },
        )?;
        self.push().await
    }

    /// Five one-second samples, as the watch batches them.
    async fn heart_rate(&mut self, workout_id: &str) -> Result<(), String> {
        let now_ms = now_unix() * 1000;
        let samples = {
            let mut rng = rand::thread_rng();
            (0..5)
                .map(|i| WorkoutHeartRatePoint {
                    sampled_at: now_ms - (4 - i) * 1000,
                    bpm: rng.gen_range(90.0..170.0),
                })
                .collect()
        };
        let _: AppendWorkoutHeartRateResponse = self.core(
            "AppendWorkoutHeartRate",
            "core.heart_rate",
            AppendWorkoutHeartRateRequest {
                workout_id: workout_id.to_string(),
                samples,
            },
        )?;
        self.push().await
    }

    /// What the website asks the server for after a workout: answered from
    /// the server's own fold of the account.
    async fn web_reads(&mut self) -> Result<(), String> {
        let metrics = self.metrics.clone();
        let mut workouts = WorkoutServiceClient::new(self.channel.clone());
        metrics
            .time(
                "rpc.list_workout_summaries",
                workouts.list_workout_summaries(self.request(ListWorkoutSummariesRequest {})),
            )
            .await?;
        Ok(())
    }
}

fn now_unix() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}
