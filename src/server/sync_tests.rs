//! Sync end to end: events pushed, placed and folded on the server, and the
//! Sync stream carrying them to every device and one partner's progress to
//! the other — over a real server on a local port.

use super::*;
use schlift::workout::v1::multiplayer_service_client::MultiplayerServiceClient;
use schlift::workout::v1::multiplayer_service_server::MultiplayerServiceServer;
use schlift::workout::v1::sync_service_client::SyncServiceClient;
use schlift::workout::v1::sync_service_server::SyncServiceServer;
use schlift_core::account::Account;
use schlift_core::api::Call;
use schlift_core::events::Event;
use schlift_core::sync::{pack, unpack};
use std::time::Duration;
use tokio::sync::mpsc;
use tokio_stream::wrappers::ReceiverStream;
use tonic::transport::Channel;

/// A fresh database holding the account `u1`.
async fn db() -> ServerDb {
    let dir = std::env::temp_dir().join(format!("lift-sync-test-{}", Uuid::new_v4()));
    let db = ServerDb::new_in_dir(&dir).await.unwrap();
    db.create_user_with_id("u1", "u1").await.unwrap();
    db
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

    /// What the server holds for `u1`, in order.
    async fn held(db: &ServerDb) -> Vec<Event> {
        db.events_after("u1", 0, i64::MAX).await.unwrap()
    }

    #[tokio::test]
    async fn pushed_events_fold_into_the_same_account() {
        let db = db().await;
        let mut phone = Phone::new();
        let (started, events) = phone.start_squats(1_000);
        let pushed = db.push_events("u1", events).await.unwrap();
        assert_eq!(pushed.stored.iter().map(|e| e.seq).collect::<Vec<_>>(), [1]);

        let server = db.read_account("u1", Clone::clone).await.unwrap();
        let without_heart_rate = Account {
            without_heart_rate: true,
            ..phone.account.clone()
        };
        assert_eq!(
            server, without_heart_rate,
            "the server folds what the phone did"
        );
        assert_eq!(server.active_workout_id, started.id);
    }

    #[tokio::test]
    async fn a_resent_batch_is_placed_once() {
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
        assert_eq!(
            db.push_events("u1", first.clone())
                .await
                .unwrap()
                .stored
                .len(),
            1
        );
        // The whole outbox again, twice: what's held is skipped.
        let all: Vec<Event> = first.into_iter().chain(second).collect();
        let pushed = db.push_events("u1", all.clone()).await.unwrap();
        assert_eq!(pushed.stored.iter().map(|e| e.seq).collect::<Vec<_>>(), [2]);
        let again = db.push_events("u1", all).await.unwrap();
        assert!(again.stored.is_empty());
        let ids: Vec<&str> = phone.log.iter().map(|e| e.id.as_str()).collect();
        let server = held(&db).await;
        assert_eq!(
            server.iter().map(|e| e.id.as_str()).collect::<Vec<_>>(),
            ids
        );
        assert_eq!(server.iter().map(|e| e.seq).collect::<Vec<_>>(), [1, 2]);
    }

    #[tokio::test]
    async fn two_devices_events_are_placed_in_the_order_they_arrive() {
        let db = db().await;
        let mut phone = Phone::new();
        let mut tablet = Phone::new();
        let (_, started) = phone.start_squats(1_000);
        let (_, setting) = tablet.write(1_050, |call| {
            call.update_setting(UpdateSettingRequest {
                setting: Some(UserSetting {
                    setting: Some(user_setting::Setting::WeightUnit(WeightUnitConfig {
                        unit: WeightUnit::Kg as i32,
                    })),
                }),
            })
            .unwrap()
        });
        db.push_events("u1", setting.clone()).await.unwrap();
        db.push_events("u1", started.clone()).await.unwrap();
        let server = held(&db).await;
        assert_eq!(
            server
                .iter()
                .map(|e| (e.seq, e.id.as_str()))
                .collect::<Vec<_>>(),
            [(1, setting[0].id.as_str()), (2, started[0].id.as_str())]
        );
        assert_eq!(
            db.read_account("u1", Clone::clone).await.unwrap(),
            Account::fold_without_heart_rate(&server),
            "the server's account is the fold of its order"
        );
    }

    #[tokio::test]
    async fn a_push_after_the_account_is_deleted_stores_nothing() {
        let db = db().await;
        let mut phone = Phone::new();
        let (_, first) = phone.start_squats(1_000);
        db.push_events("u1", first).await.unwrap();
        db.delete_user_account_and_data("u1").await.unwrap();
        let (_, events) = Phone::new().start_squats(1_000);
        assert!(db.push_events("u1", events).await.is_err());
        assert!(held(&db).await.is_empty());
    }

    #[tokio::test]
    async fn events_read_back_as_they_were_pushed() {
        let db = db().await;
        let mut phone = Phone::new();
        let (_, events) = phone.start_squats(1_000);
        db.push_events("u1", events).await.unwrap();
        let server = held(&db).await;
        assert_eq!(unpack(&pack(&server)).unwrap(), server);
        assert_eq!(Account::fold(&server), phone.account);
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
        /// A device holding the account up to `after_seq`.
        async fn open_after(channel: Channel, token: &str, after_seq: i64) -> Self {
            let (up, rx) = mpsc::channel(8);
            up.send(SyncRequest {
                kind: Some(sync_request::Kind::AfterSeq(after_seq)),
            })
            .await
            .unwrap();
            let down = SyncServiceClient::new(channel)
                .sync(authed(token, ReceiverStream::new(rx)))
                .await
                .unwrap()
                .into_inner();
            Self { up, down }
        }

        async fn open(channel: Channel, token: &str) -> Self {
            Self::open_after(channel, token, 0).await
        }

        async fn push(&self, events: Vec<Event>) {
            self.up
                .send(SyncRequest {
                    kind: Some(sync_request::Kind::Events(pack(&events))),
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

        /// Events down until the device holds `seq`: everything it was sent.
        async fn events_through(&mut self, seq: i64) -> Vec<Event> {
            let mut events = Vec::new();
            while events.last().map_or(0, |e: &Event| e.seq) < seq {
                let packed = self
                    .next(|kind| match kind {
                        sync_response::Kind::Events(e) => Some(e.packed),
                        _ => None,
                    })
                    .await;
                if !packed.is_empty() {
                    events.extend(unpack(&packed).unwrap());
                }
            }
            events
        }

        /// The head the server says it holds, in the next message that says.
        async fn head(&mut self) -> i64 {
            self.next(|kind| match kind {
                sync_response::Kind::Events(e) => Some(e.head),
                sync_response::Kind::Head(head) => Some(head),
                _ => None,
            })
            .await
        }

        /// The next session view that satisfies `want`.
        async fn session(&mut self, mut want: impl FnMut(&Session) -> bool) -> Session {
            self.next(|kind| match kind {
                sync_response::Kind::Session(session) if want(&session) => Some(session),
                _ => None,
            })
            .await
        }

        /// A partner as this phone folds them, once it satisfies `want`:
        /// their workout's events, as they come (`held`, kept across calls).
        async fn partner(
            &mut self,
            partner: &str,
            held: &mut Vec<Event>,
            mut want: impl FnMut(&ParticipantStatus) -> bool,
        ) -> ParticipantStatus {
            loop {
                let status = schlift_core::session::partner_status(held, 0, 0, now_unix());
                if let Some(status) = status.filter(|s| want(s)) {
                    return status;
                }
                let (whole, events) = self
                    .next(|kind| match kind {
                        sync_response::Kind::PartnerEvents(p) if p.user_id == partner => {
                            Some((p.whole, unpack(&p.packed).unwrap()))
                        }
                        _ => None,
                    })
                    .await;
                if whole {
                    held.clear();
                }
                for event in events {
                    if !held.iter().any(|e| e.id == event.id) {
                        held.push(event);
                    }
                }
            }
        }
    }

    /// Alice and Bob train together: Alice's sets reach Bob as events as she
    /// does them, and his own core folds them; her ending the workout leaves
    /// her finished workout on show and takes her out of the session. The
    /// server holds none of it.
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
        assert_eq!(alice_link.head().await, 0, "nothing synced yet");
        // On connect: the session, Alice in it, not training.
        bob_link.session(|s| s.members.len() == 1).await;
        let mut alices = Vec::new();
        let idle = bob_link.partner(&alice.id, &mut alices, |_| true).await;
        assert!(idle.active_workout.is_none());

        let mut phone = Phone::new();
        let (started, events) = phone.start_squats(now_unix());
        alice_link.push(events).await;
        assert_eq!(
            alice_link.events_through(1).await.len(),
            1,
            "her own, placed"
        );
        let seen = bob_link
            .partner(&alice.id, &mut alices, |p| p.active_workout.is_some())
            .await;
        assert_eq!(
            seen.active_workout_id, started.id,
            "Bob sees Alice's workout"
        );

        let set = started.proposed_sets[0].clone();
        let (_, events) = phone.write(now_unix(), |call| {
            call.append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![WorkoutMutation {
                    mutation: Some(workout_mutation::Mutation::CompleteSet(
                        CompleteSetRequest {
                            workout_id: started.id.clone(),
                            proposed_set_id: set.id.clone(),
                            actual_reps: 8,
                            actual_weight: 0.0,
                            completed_at: now_unix(),
                        },
                    )),
                }],
            })
            .unwrap()
        });
        alice_link.push(events).await;
        let seen = bob_link
            .partner(&alice.id, &mut alices, |p| p.completed_sets.len() == 1)
            .await;
        assert_eq!(
            seen,
            schlift_core::session::partner_status(&alices, 0, 0, now_unix()).unwrap()
        );

        let (_, events) = phone.write(now_unix(), |call| {
            call.end_workout(EndWorkoutRequest {
                workout_id: started.id.clone(),
                ended_at: 0,
            })
            .unwrap()
        });
        alice_link.push(events).await;
        alice_link.events_through(3).await;
        // Alice is out of the session.
        alice_link.session(|s| s.session_id.is_empty()).await;
        assert!(db
            .get_user_current_session(&alice.id)
            .await
            .unwrap()
            .is_none());
        // Bob still has her finished workout, and her, ended.
        bob_link
            .partner(&alice.id, &mut alices, |p| {
                p.active_workout.as_ref().is_some_and(|w| w.end_time != 0)
            })
            .await;
        let roster = bob_link
            .session(|s| s.members.first().is_some_and(|m| m.ended_at > 0))
            .await;
        assert_eq!(roster.members.len(), 1);
    }

    /// Bob opens the app once Alice is mid-workout: he gets her workout so
    /// far, then each event as she records it — only what happens in it,
    /// never her heart rate or anything else of her account.
    #[tokio::test]
    async fn a_late_partner_gets_the_workout_so_far_and_only_the_workout() {
        let db = db().await;
        let channel = serve(db.clone()).await;
        let (alice, _) = db
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

        let mut phone = Phone::new();
        let (started, mut events) = phone.start_squats(now_unix());
        let set = started.proposed_sets[0].clone();
        let (_, done) = phone.write(now_unix(), |call| {
            call.append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![WorkoutMutation {
                    mutation: Some(workout_mutation::Mutation::CompleteSet(
                        CompleteSetRequest {
                            workout_id: started.id.clone(),
                            proposed_set_id: set.id.clone(),
                            actual_reps: 8,
                            actual_weight: 0.0,
                            completed_at: now_unix(),
                        },
                    )),
                }],
            })
            .unwrap()
        });
        events.extend(done);
        db.push_events(&alice.id, events).await.unwrap();

        let mut bob_link = Link::open(channel.clone(), &bob_token).await;
        let mut alices = Vec::new();
        let seen = bob_link
            .partner(&alice.id, &mut alices, |p| p.completed_sets.len() == 1)
            .await;
        assert_eq!(seen.active_workout_id, started.id);

        // Her heart rate is hers: it never reaches Bob.
        let (_, beats) = phone.write(now_unix(), |call| {
            call.record_heart_rate(
                &started.id,
                &[WorkoutHeartRatePoint {
                    sampled_at: now_unix() * 1000,
                    bpm: 120.0,
                }],
            )
            .unwrap()
        });
        let (_, ended) = phone.write(now_unix(), |call| {
            call.end_workout(EndWorkoutRequest {
                workout_id: started.id.clone(),
                ended_at: 0,
            })
            .unwrap()
        });
        db.push_events(&alice.id, [beats, ended].concat())
            .await
            .unwrap();
        bob_link
            .partner(&alice.id, &mut alices, |p| {
                p.active_workout.as_ref().is_some_and(|w| w.end_time != 0)
            })
            .await;
        assert!(
            alices
                .iter()
                .all(|e| schlift_core::session::shared_with_partners(&e.fact)),
            "only her workout reached Bob"
        );
        assert_eq!(alices.len(), 3, "the start, the set, the end");
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
        assert_eq!(link.head().await, 0, "caught up: there's nothing");
        link.up
            .send(SyncRequest {
                kind: Some(sync_request::Kind::Heartbeat(Heartbeat {})),
            })
            .await
            .unwrap();
        assert_eq!(link.head().await, 0, "the heartbeat's answer");
    }

    /// Deleting the account ends its open streams: a push after it is
    /// refused, so the deleted log is not stored again.
    #[tokio::test]
    async fn a_deleted_account_cannot_push_again() {
        let db = db().await;
        let channel = serve(db.clone()).await;
        let (dave, token) = db
            .get_or_create_user_with_auth_session("dave")
            .await
            .unwrap();
        let mut link = Link::open(channel, &token).await;
        let mut phone = Phone::new();
        let (_, events) = phone.start_squats(now_unix());
        link.push(events).await;
        link.events_through(1).await;

        db.delete_user_account_and_data(&dave.id).await.unwrap();
        link.push(phone.log.clone()).await;
        let status = tokio::time::timeout(Duration::from_secs(5), async {
            loop {
                match link.down.message().await {
                    Ok(Some(_)) => continue,
                    Ok(None) => panic!("closed without a status"),
                    Err(status) => return status,
                }
            }
        })
        .await
        .expect("the stream ends");
        assert_eq!(status.code(), tonic::Code::Unauthenticated);
        assert!(db
            .events_after(&dave.id, 0, i64::MAX)
            .await
            .unwrap()
            .is_empty());
    }

    /// Signing out ends the stream even when the phone sends nothing more:
    /// the next view it would be sent is refused instead.
    #[tokio::test]
    async fn a_signed_out_stream_is_sent_nothing_more() {
        let db = db().await;
        let channel = serve(db.clone()).await;
        let (erin, token) = db
            .get_or_create_user_with_auth_session("erin")
            .await
            .unwrap();
        let (frank, _) = db
            .get_or_create_user_with_auth_session("frank")
            .await
            .unwrap();
        let mut link = Link::open(channel, &token).await;
        link.next(|kind| matches!(kind, sync_response::Kind::JoinRequests(_)).then_some(()))
            .await;

        db.delete_auth_session(&token).await.unwrap();
        db.create_join_request("r1", &frank.id, &erin.id)
            .await
            .unwrap();
        let status = tokio::time::timeout(Duration::from_secs(5), async {
            loop {
                match link.down.message().await {
                    Ok(Some(message)) => assert!(
                        !matches!(message.kind, Some(sync_response::Kind::JoinRequests(_))),
                        "a join request reached a signed-out stream"
                    ),
                    Ok(None) => panic!("closed without a status"),
                    Err(status) => return status,
                }
            }
        })
        .await
        .expect("the stream ends");
        assert_eq!(status.code(), tonic::Code::Unauthenticated);
    }

    /// A device that connects gets everything after what it holds, in
    /// pieces, and another of the same account's devices hears new events
    /// as they are placed.
    #[tokio::test]
    async fn a_device_catches_up_and_hears_the_others() {
        let db = db().await;
        let channel = serve(db.clone()).await;
        let (gil, token) = db
            .get_or_create_user_with_auth_session("gil")
            .await
            .unwrap();
        let mut phone = Phone::new();
        let (started, first) = phone.start_squats(now_unix());
        let (_, beats) = phone.write(now_unix(), |call| {
            for n in 0..1_200 {
                call.record_heart_rate(
                    &started.id,
                    &[WorkoutHeartRatePoint {
                        sampled_at: n,
                        bpm: 100.0,
                    }],
                )
                .unwrap();
            }
        });
        db.push_events(&gil.id, [first, beats].concat())
            .await
            .unwrap();

        // A fresh install: everything, in pieces, in order.
        let mut tablet = Link::open(channel.clone(), &token).await;
        let all = tablet.events_through(1_201).await;
        assert_eq!(
            all.iter().map(|e| e.seq).collect::<Vec<_>>(),
            (1..=1_201).collect::<Vec<_>>()
        );
        assert_eq!(Account::fold(&all), phone.account);
        // A device that holds most of it: only the rest.
        let mut laptop = Link::open_after(channel, &token, 1_199).await;
        assert_eq!(laptop.events_through(1_201).await.len(), 2);

        // The phone writes; both other devices hear it.
        let (_, end) = phone.write(now_unix(), |call| {
            call.end_workout(EndWorkoutRequest {
                workout_id: started.id.clone(),
                ended_at: 0,
            })
            .unwrap()
        });
        db.push_events(&gil.id, end).await.unwrap();
        assert_eq!(tablet.events_through(1_202).await.len(), 1);
        assert_eq!(laptop.events_through(1_202).await.len(), 1);
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
