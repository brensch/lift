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
use schlift_core::events::Event;
use schlift_native::store::Store;
use schlift_testkit::{Lifter, Move};
use std::collections::VecDeque;
use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
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
    /// Only keeps the app open: never trains.
    watcher: bool,
    /// How this client trains, from its number: a run trains the same way.
    lifter: Lifter,
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
    /// What the server sends, handed over by the stream's reader.
    down: Option<mpsc::Receiver<SyncResponse>>,
    /// The last pending event this stream sent (`Store::pending_after`).
    sent_up_to: i64,
    /// The last head the server reported.
    head: i64,
    /// Pushes waiting to come back placed: (last event's id, when sent).
    in_flight: VecDeque<(String, Instant)>,
    lost: Arc<AtomicBool>,
}

impl Client {
    pub fn new(
        n: usize,
        watcher: bool,
        run: &str,
        channel: Channel,
        metrics: Arc<Metrics>,
        profile: Profile,
    ) -> Self {
        Client {
            username: format!("load-{run}-{n}"),
            watcher,
            lifter: Lifter::new(n as u64),
            ip: format!("10.{}.{}.{}", (n >> 16) & 255, (n >> 8) & 255, n & 255),
            token: String::new(),
            channel,
            metrics,
            profile,
            passkey: WebauthnAuthenticator::new(SoftPasskey::new(true)),
            store: None,
            up: None,
            down: None,
            sent_up_to: 0,
            head: 0,
            in_flight: VecDeque::new(),
            lost: Arc::default(),
        }
    }

    /// Sign up, onboard, restore the profile's history and connect: an
    /// account as it stands before the load being measured.
    pub async fn prepare(&mut self) -> Result<(), String> {
        self.sign_up().await?;
        self.sign_in().await?;
        self.onboard().await?;
        self.restore_history()?;
        self.dial().await?;
        self.settle("sync.restore").await
    }

    /// Join the client's group, train (or only watch) until `stop`, then
    /// sync everything.
    pub async fn run(
        mut self,
        role: Role,
        mut stop: watch::Receiver<bool>,
    ) -> Result<Outcome, String> {
        self.group(role).await?;
        while !*stop.borrow() {
            if self.watcher {
                self.pause(Duration::from_secs(3_600), None, &mut stop)
                    .await?;
                break;
            }
            let idle = self.jitter(self.profile.idle);
            if self.pause(idle, None, &mut stop).await? {
                break;
            }
            self.workout(&mut stop).await?;
            self.web_reads().await?;
        }
        self.drain().await?;
        let events = self.store()?.events()?;
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

    /// Open the stream: it starts with what this client holds.
    async fn dial(&mut self) -> Result<(), String> {
        let metrics = self.metrics.clone();
        let (up, rx) = mpsc::channel::<SyncRequest>(64);
        let confirmed = self.store()?.confirmed()?;
        up.send(SyncRequest {
            kind: Some(sync_request::Kind::AfterSeq(confirmed)),
        })
        .await
        .map_err(|_| "sync stream closed".to_string())?;
        let mut sync = SyncServiceClient::new(self.channel.clone());
        let mut down = metrics
            .time(
                "sync.open",
                sync.sync(self.request(ReceiverStream::new(rx))),
            )
            .await?
            .into_inner();
        let (to_client, from_server) = mpsc::channel(256);
        let lost = self.lost.clone();
        lost.store(false, Ordering::SeqCst);
        tokio::spawn(async move {
            loop {
                match down.message().await {
                    Ok(Some(message)) => {
                        if to_client.send(message).await.is_err() {
                            break;
                        }
                    }
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
        self.down = Some(from_server);
        self.sent_up_to = 0;
        Ok(())
    }

    /// Fold in what the server sent: events placed (this client's own coming
    /// back, or a resend), or anything else, which is only counted.
    fn heard(&mut self, message: SyncResponse) -> Result<(), String> {
        match message.kind {
            Some(sync_response::Kind::Events(events)) => {
                let metrics = self.metrics.clone();
                let placed = if events.packed.is_empty() {
                    Vec::new()
                } else {
                    schlift_core::sync::unpack(&events.packed).map_err(|e| e.to_string())?
                };
                self.head = events.head;
                let ids: Vec<String> = placed.iter().map(|e| e.id.clone()).collect();
                let store = self.store()?;
                metrics.time_sync("core.receive", || store.receive(placed, events.head))?;
                // A push is back once its last event is.
                while self
                    .in_flight
                    .front()
                    .is_some_and(|(last, _)| ids.contains(last))
                {
                    let (_, sent) = self.in_flight.pop_front().expect("front");
                    self.metrics.record("sync.push_acked", sent.elapsed());
                }
            }
            Some(sync_response::Kind::Session(_)) => {
                self.metrics.record("sync.session_update", Duration::ZERO)
            }
            // A partner's workout, folded here as the phone does.
            Some(sync_response::Kind::PartnerEvents(partner)) => {
                let events =
                    schlift_core::sync::unpack(&partner.packed).map_err(|e| e.to_string())?;
                let metrics = self.metrics.clone();
                let store = self.store()?;
                metrics.time_sync("core.partner", || {
                    store.receive_partner(&partner.user_id, events, partner.whole);
                    store.partner_status(&partner.user_id, 0, 0, now_unix());
                    Ok::<_, String>(())
                })?;
            }
            _ => {}
        }
        Ok(())
    }

    /// Everything the server has sent so far, folded in.
    fn hear_all(&mut self) -> Result<(), String> {
        while let Some(message) = self.down.as_mut().and_then(|down| down.try_recv().ok()) {
            self.heard(message)?;
        }
        Ok(())
    }

    /// Send what this client recorded that this stream hasn't sent.
    async fn push(&mut self) -> Result<(), String> {
        if self.lost.load(Ordering::SeqCst) {
            self.metrics.record("sync.redial", Duration::ZERO);
            self.up = None;
            self.dial().await?;
        }
        self.hear_all()?;
        let after = self.sent_up_to;
        let (events, last) = self.store()?.pending_after(after)?;
        let Some(last_id) = events.last().map(|e| e.id.clone()) else {
            return Ok(());
        };
        self.in_flight.push_back((last_id, Instant::now()));
        self.send(sync_request::Kind::Events(schlift_core::sync::pack(
            &events,
        )))
        .await?;
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
    /// sending heart rate; what the server sends meanwhile is folded in as
    /// it arrives. True if asked to stop.
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
            let wake = Instant::now() + left.min(self.profile.heartbeat);
            let message = {
                let down = self.down.as_mut().ok_or("not connected")?;
                tokio::select! {
                    _ = tokio::time::sleep_until(wake.into()) => None,
                    _ = stop.changed() => return Ok(true),
                    message = down.recv() => message,
                }
            };
            if let Some(message) = message {
                self.heard(message)?;
                continue;
            }
            if let Some(workout_id) = training {
                self.heart_rate(workout_id).await?;
            } else {
                self.send(sync_request::Kind::Heartbeat(Heartbeat {}))
                    .await?;
            }
        }
    }

    /// A year (or the profile's weeks) of training recorded on this phone
    /// before it first syncs, as a restored phone would hold.
    fn restore_history(&mut self) -> Result<(), String> {
        let weeks = self.profile.history_weeks;
        if weeks == 0 {
            return Ok(());
        }
        let metrics = self.metrics.clone();
        let store = self.store.as_mut().ok_or("no account open")?;
        let lifter = &mut self.lifter;
        metrics.time_sync("core.history", || {
            schlift_testkit::history(store, lifter, weeks, 3, now_unix() - 86_400)
        })?;
        Ok(())
    }

    /// Send everything recorded, piece by piece, and wait until the server
    /// has placed it all; how long that took is `op`. Nothing to send is
    /// nothing timed.
    async fn settle(&mut self, op: &'static str) -> Result<(), String> {
        if self.store()?.pending_count()? == 0 {
            return Ok(());
        }
        let started = Instant::now();
        self.send_all().await?;
        // Timed here as a whole, not as pushes.
        self.in_flight.clear();
        self.wait_until_placed().await?;
        self.metrics.record(op, started.elapsed());
        Ok(())
    }

    /// Every piece this stream hasn't sent.
    async fn send_all(&mut self) -> Result<(), String> {
        loop {
            let sent = self.sent_up_to;
            self.push().await?;
            if self.sent_up_to == sent {
                return Ok(());
            }
        }
    }

    /// Wait until the server has placed everything, then hang up.
    async fn drain(&mut self) -> Result<(), String> {
        self.send_all().await?;
        self.wait_until_placed().await?;
        self.up = None;
        Ok(())
    }

    async fn wait_until_placed(&mut self) -> Result<(), String> {
        let deadline = Instant::now() + Duration::from_secs(120);
        loop {
            self.hear_all()?;
            let store = self.store()?;
            if store.pending_count()? == 0 && store.confirmed()? >= self.head {
                break;
            }
            if Instant::now() > deadline {
                self.metrics
                    .error("sync.drain", "server never placed everything");
                return Err("sync.drain timed out".into());
            }
            if self.lost.load(Ordering::SeqCst) {
                self.push().await?;
            }
            let down = self.down.as_mut().ok_or("not connected")?;
            if let Ok(Some(message)) =
                tokio::time::timeout(Duration::from_millis(200), down.recv()).await
            {
                self.heard(message)?;
            }
        }
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
            match self.lifter.next_move(&id, &state) {
                Move::AnswerRung(answer) => {
                    state = self.mutate(Mutation::AnswerRung(answer))?;
                }
                Move::Lift(begin, done) => {
                    self.mutate(Mutation::StartSet(begin))?;
                    self.push().await?;
                    state = self.mutate(Mutation::CompleteSet(done))?;
                }
                Move::End => break,
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

    /// A few seconds of the watch's readings, as it batches them.
    async fn heart_rate(&mut self, workout_id: &str) -> Result<(), String> {
        let now_ms = now_unix() * 1000;
        let samples = self.lifter.heart_rate(now_ms - 4_000, now_ms);
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
