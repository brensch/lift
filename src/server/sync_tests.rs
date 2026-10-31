//! Sync end to end: events pushed and folded on the server, the projections
//! they leave, and the Sync stream carrying one partner's progress to the
//! other — over a real server on a local port.

use super::*;
use schlift::workout::v1::multiplayer_service_client::MultiplayerServiceClient;
use schlift::workout::v1::multiplayer_service_server::MultiplayerServiceServer;
use schlift::workout::v1::sync_service_client::SyncServiceClient;
use schlift::workout::v1::sync_service_server::SyncServiceServer;
use schlift_core::account::Account;
use schlift_core::api::Call;
use schlift_core::sync::{pack, unpack};
use std::time::Duration;
use tokio::sync::mpsc;
use tokio_stream::wrappers::ReceiverStream;
use tonic::transport::Channel;

async fn db() -> ServerDb {
    let dir = std::env::temp_dir().join(format!("lift-sync-test-{}", Uuid::new_v4()));
    ServerDb::new_in_dir(&dir).await.unwrap()
}

/// A phone: an account and the events it has recorded.
struct Phone {
    account: Account,
    log: Vec<Event>,
}

impl Phone {
    fn new() -> Self {
        Self {
            account: Account::default(),
            log: Vec::new(),
        }
    }

    /// Make some writes at `now`; returns what they recorded.
    fn write<R>(&mut self, now: i64, f: impl FnOnce(&mut Call) -> R) -> (R, Vec<Event>) {
        let mut call = Call::new(&mut self.account, now, Uuid::new_v4().to_string());
        let out = f(&mut call);
        let events = std::mem::take(&mut call.events);
        self.log.extend(events.iter().cloned());
        (out, events)
    }

    fn start_squats(&mut self, now: i64) -> (StartWorkoutResponse, Vec<Event>) {
        self.write(now, |call| {
            call.start_workout(StartWorkoutRequest {
                exercises: vec![Exercise::PullUp as i32],
                ..Default::default()
            })
            .unwrap()
        })
    }
}

mod store {
    use super::*;

    #[tokio::test]
    async fn pushed_events_fold_into_the_same_account() {
        let db = db().await;
        let mut phone = Phone::new();
        let (started, events) = phone.start_squats(1_000);
        let pushed = db.push_events("u1", events).await.unwrap();
        assert_eq!(pushed.head, 1);
        assert!(pushed.changed);

        let server = db.read_account("u1", Clone::clone).await.unwrap();
        assert_eq!(server, phone.account, "the server folds what the phone did");
        assert_eq!(server.active_workout_id, started.id);
    }

    #[tokio::test]
    async fn a_resent_batch_is_skipped_and_a_gap_waits() {
        let db = db().await;
        let mut phone = Phone::new();
        let (_, first) = phone.start_squats(1_000);
        let (_, second) = phone.write(1_100, |call| {
            call.update_setting(UpdateSettingRequest {
                setting: Some(UserSetting {
                    setting: Some(user_setting::Setting::WeightUnit(WeightUnitConfig {
                        unit: WeightUnit::Kg as i32,
                    })),
                }),
            })
            .unwrap()
        });
        // Out of order: the second alone is after a gap, so it waits.
        let pushed = db.push_events("u1", second.clone()).await.unwrap();
        assert_eq!((pushed.head, pushed.changed), (0, false));
        // The whole outbox again, twice: applied once.
        let all: Vec<Event> = first.into_iter().chain(second).collect();
        assert_eq!(db.push_events("u1", all.clone()).await.unwrap().head, 2);
        let again = db.push_events("u1", all).await.unwrap();
        assert_eq!((again.head, again.changed), (2, false));
        assert_eq!(db.events_after("u1", 0).await.unwrap(), phone.log);
    }

    #[tokio::test]
    async fn a_second_device_with_a_different_log_is_refused() {
        let db = db().await;
        let (_, mine) = Phone::new().start_squats(1_000);
        db.push_events("u1", mine).await.unwrap();
        let (_, theirs) = Phone::new().start_squats(1_000);
        let error = db.push_events("u1", theirs).await.err().unwrap();
        assert!(error.downcast_ref::<crate::db::Diverged>().is_some());
    }

    #[tokio::test]
    async fn workouts_are_projected_for_analytics() {
        let db = db().await;
        let mut phone = Phone::new();
        let (started, events) = phone.start_squats(1_000);
        db.push_events("u1", events).await.unwrap();
        let set = started.proposed_sets[0].clone();
        let (_, events) = phone.write(1_100, |call| {
            call.complete_set(CompleteSetRequest {
                workout_id: started.id.clone(),
                proposed_set_id: set.id.clone(),
                actual_reps: 8,
                actual_weight: 0.0,
                completed_at: 1_100,
                effort: 0,
            })
            .unwrap()
        });
        db.push_events("u1", events).await.unwrap();

        let (sets, done): (i64, i64) = sqlx::query_as(
            "SELECT (SELECT COUNT(*) FROM proposed_sets WHERE workout_id = ?),
                    (SELECT COUNT(*) FROM completed_sets WHERE workout_id = ?)",
        )
        .bind(&started.id)
        .bind(&started.id)
        .fetch_one(&db.read_pool)
        .await
        .unwrap();
        assert_eq!(sets, started.proposed_sets.len() as i64);
        assert_eq!(done, 1);
    }

    #[tokio::test]
    async fn the_pull_is_the_whole_log() {
        let db = db().await;
        let mut phone = Phone::new();
        let (_, events) = phone.start_squats(1_000);
        db.push_events("u1", events).await.unwrap();
        let pulled = db.events_after("u1", 0).await.unwrap();
        assert_eq!(unpack(&pack(pulled.clone())).unwrap(), pulled);
        assert_eq!(Account::fold(&pulled), phone.account);
    }
}

mod stream {
    use super::*;

    /// A real server on a free local port with sync and multiplayer.
    async fn serve(db: ServerDb) -> Channel {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        tokio::spawn(
            tonic::transport::Server::builder()
                .add_service(SyncServiceServer::new(ServerSyncService { db: db.clone() }))
                .add_service(MultiplayerServiceServer::new(ServerMultiplayerService {
                    db,
                }))
                .serve_with_incoming(tokio_stream::wrappers::TcpListenerStream::new(listener)),
        );
        Channel::from_shared(format!("http://{addr}"))
            .unwrap()
            .connect()
            .await
            .unwrap()
    }

    fn authed<T>(token: &str, msg: T) -> Request<T> {
        let mut req = Request::new(msg);
        req.metadata_mut()
            .insert("x-session-token", token.parse().unwrap());
        req
    }

    /// An open Sync stream: send up, read down.
    struct Link {
        up: mpsc::Sender<SyncRequest>,
        down: tonic::Streaming<SyncResponse>,
    }

    impl Link {
        async fn open(channel: Channel, token: &str) -> Self {
            let (up, rx) = mpsc::channel(8);
            let down = SyncServiceClient::new(channel)
                .sync(authed(token, ReceiverStream::new(rx)))
                .await
                .unwrap()
                .into_inner();
            Self { up, down }
        }

        async fn push(&self, events: Vec<Event>) {
            self.up
                .send(SyncRequest {
                    kind: Some(sync_request::Kind::Events(pack(events))),
                })
                .await
                .unwrap();
        }

        /// The next message that matches, within a few seconds.
        async fn next<T>(&mut self, mut pick: impl FnMut(sync_response::Kind) -> Option<T>) -> T {
            tokio::time::timeout(Duration::from_secs(5), async {
                loop {
                    let message = self.down.message().await.unwrap().expect("stream open");
                    if let Some(found) = pick(message.kind.unwrap()) {
                        return found;
                    }
                }
            })
            .await
            .expect("it arrives")
        }

        /// The first ack of at least `seq` (earlier acks may still be queued).
        async fn acked(&mut self, seq: i64) -> i64 {
            self.next(|kind| match kind {
                sync_response::Kind::Head(head) if head >= seq => Some(head),
                _ => None,
            })
            .await
        }

        /// The next session view that satisfies `want`.
        async fn session(
            &mut self,
            mut want: impl FnMut(&GetCurrentSessionResponse) -> bool,
        ) -> GetCurrentSessionResponse {
            self.next(|kind| match kind {
                sync_response::Kind::Session(session) if want(&session) => Some(session),
                _ => None,
            })
            .await
        }
    }

    fn partner_workout(session: &GetCurrentSessionResponse) -> Option<&ParticipantStatus> {
        session
            .session_status
            .as_ref()
            .and_then(|s| s.participants.first())
            .filter(|p| p.active_workout.is_some())
    }

    /// Alice and Bob train together: Alice's sets reach Bob as she does
    /// them, and her ending the workout leaves her finished state on show
    /// and takes her out of the session.
    #[tokio::test]
    async fn a_partners_progress_arrives_as_it_happens() {
        let db = db().await;
        let channel = serve(db.clone()).await;
        let (alice, alice_token) = db
            .get_or_create_user_with_auth_session("alice")
            .await
            .unwrap();
        let (_, bob_token) = db
            .get_or_create_user_with_auth_session("bob")
            .await
            .unwrap();
        let invite = db.get_invite_token(&alice.id).await.unwrap().unwrap();
        MultiplayerServiceClient::new(channel.clone())
            .join_via_invite(authed(
                &bob_token,
                JoinViaInviteRequest {
                    invite_token: invite,
                },
            ))
            .await
            .unwrap();

        let mut alice_link = Link::open(channel.clone(), &alice_token).await;
        let mut bob_link = Link::open(channel.clone(), &bob_token).await;
        assert_eq!(alice_link.acked(0).await, 0, "nothing synced yet");
        // On connect: the session, Alice in it, not training.
        bob_link
            .session(|s| {
                s.session_status
                    .as_ref()
                    .is_some_and(|s| s.participants.len() == 1)
            })
            .await;

        let mut phone = Phone::new();
        let (started, events) = phone.start_squats(now_unix());
        alice_link.push(events).await;
        assert_eq!(alice_link.acked(1).await, 1, "acked");
        let seen = bob_link.session(|s| partner_workout(s).is_some()).await;
        assert_eq!(
            partner_workout(&seen).unwrap().active_workout_id,
            started.id,
            "Bob sees Alice's workout"
        );

        let set = started.proposed_sets[0].clone();
        let (_, events) = phone.write(now_unix(), |call| {
            call.complete_set(CompleteSetRequest {
                workout_id: started.id.clone(),
                proposed_set_id: set.id.clone(),
                actual_reps: 8,
                actual_weight: 0.0,
                completed_at: now_unix(),
                effort: 0,
            })
            .unwrap()
        });
        alice_link.push(events).await;
        bob_link
            .session(|s| partner_workout(s).is_some_and(|p| p.completed_sets.len() == 1))
            .await;

        let (_, events) = phone.write(now_unix(), |call| {
            call.end_workout(EndWorkoutRequest {
                workout_id: started.id.clone(),
                ended_at: 0,
            })
            .unwrap()
        });
        alice_link.push(events).await;
        assert_eq!(alice_link.acked(3).await, 3);
        // Alice is out of the session; her row keeps her finished workout.
        alice_link.session(|s| s.session_id.is_empty()).await;
        assert!(db
            .get_user_current_session(&alice.id)
            .await
            .unwrap()
            .is_none());
        // Bob still sees her, finished: her last state stays on show.
        bob_link
            .session(|s| {
                partner_workout(s)
                    .is_some_and(|p| p.active_workout.as_ref().is_some_and(|w| w.end_time != 0))
            })
            .await;
    }

    /// A heartbeat is answered with the head, so the phone knows the link
    /// is alive.
    #[tokio::test]
    async fn a_heartbeat_is_answered() {
        let db = db().await;
        let channel = serve(db.clone()).await;
        let (_, token) = db
            .get_or_create_user_with_auth_session("carol")
            .await
            .unwrap();
        let mut link = Link::open(channel, &token).await;
        assert_eq!(link.acked(0).await, 0);
        link.up
            .send(SyncRequest {
                kind: Some(sync_request::Kind::Heartbeat(Heartbeat {})),
            })
            .await
            .unwrap();
        assert_eq!(link.acked(0).await, 0, "the heartbeat's answer");
    }

    /// The stream needs a signed-in caller.
    #[tokio::test]
    async fn a_stranger_is_turned_away() {
        let channel = serve(db().await).await;
        let (_up, rx) = mpsc::channel::<SyncRequest>(1);
        let status = SyncServiceClient::new(channel)
            .sync(authed("nope", ReceiverStream::new(rx)))
            .await
            .unwrap_err();
        assert_eq!(status.code(), tonic::Code::Unauthenticated);
    }
}
