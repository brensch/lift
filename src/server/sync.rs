use super::*;
use crate::db::{Change, Pushed, Topic};
use schlift_core::events::{Event, Fact};
use schlift_core::session::shared_with_partners;
use schlift_core::sync::{pack, unpack_push};
use std::collections::HashMap;
use tokio::sync::{broadcast, mpsc};
use tokio_stream::wrappers::ReceiverStream;
use tonic::Streaming;

// ── Sync Service ──
//
// One stream per connected device. It opens with the last seq the device
// holds; down go the account's events after it, in chunks, then every new one
// as it is stored, whichever device it came from. Up go the device's own
// events, which are given their places (once each, by id) and come back down
// with the others, and heartbeats, answered with the head. Also down, on
// connect and whenever they change: the caller's session (who else is in it)
// and requests to join them, whole; on connect the template library, which
// coupled templates follow. And for each session partner, their workout as
// events: the workout so far when they first appear, then each event as
// they record it. The phone folds those (schlift_core::session); the server
// keeps nothing of where anyone is up to.

/// Events per message down: a whole account's history arrives in pieces.
const EVENTS_PER_MESSAGE: i64 = 500;

// What one event in a push may hold (the batch's size and event count are
// limited as it is decoded, in schlift_core::sync). Far above anything a
// phone records; past them the push is refused whole.
/// A workout's heart rate is one event: a reading a second for over a day.
const MAX_HEART_RATE_SAMPLES_PER_EVENT: usize = 100_000;
const MAX_IMPORTED_WORKOUTS: usize = 10_000;
const MAX_IMPORTED_HEART_RATE_SAMPLES: usize = 2_000_000;

/// Refuse a push larger than any phone makes.
fn check_push(events: &[Event]) -> ServerResult<()> {
    let too_big = |what: &str, limit: usize| -> ServerResult<()> {
        Err(Status::invalid_argument(format!("push too large: more than {limit} {what}")).into())
    };
    for event in events {
        match &event.fact {
            Fact::HeartRateRecorded(recorded)
                if recorded.bpm.len() > MAX_HEART_RATE_SAMPLES_PER_EVENT =>
            {
                return too_big(
                    "heart-rate samples in one event",
                    MAX_HEART_RATE_SAMPLES_PER_EVENT,
                );
            }
            Fact::HistoryImported(import) => {
                if import.workouts.len() > MAX_IMPORTED_WORKOUTS {
                    return too_big("imported workouts", MAX_IMPORTED_WORKOUTS);
                }
                let samples: usize = import.workouts.iter().map(|w| w.heart_rate.len()).sum();
                if samples > MAX_IMPORTED_HEART_RATE_SAMPLES {
                    return too_big(
                        "imported heart-rate samples",
                        MAX_IMPORTED_HEART_RATE_SAMPLES,
                    );
                }
            }
            _ => {}
        }
    }
    Ok(())
}

#[derive(Clone)]
pub struct ServerSyncService {
    pub db: ServerDb,
}

type SyncResult = Result<SyncResponse, Status>;

#[tonic::async_trait]
impl SyncService for ServerSyncService {
    type SyncStream = Pin<Box<dyn futures_util::Stream<Item = SyncResult> + Send>>;

    async fn sync(
        &self,
        request: Request<Streaming<SyncRequest>>,
    ) -> Result<Response<Self::SyncStream>, Status> {
        // The inbound stream can't be held across an await (it isn't Sync):
        // authenticate on the headers alone.
        let (metadata, extensions, inbound) = request.into_parts();
        let headers = Request::from_parts(metadata, extensions, ());
        let user_id = authed_user_id(&headers, &self.db).await?;
        let token = session_token(&headers).unwrap_or_default().to_string();
        info!(rpc = "Sync", %user_id, "open");
        // Watching before the first send, so nothing between is missed.
        let changes = self.db.watch(Topic::User(user_id.clone()));
        let (tx, rx) = mpsc::channel(16);
        let db = self.db.clone();
        tokio::spawn(async move {
            let mut stream = Stream {
                db,
                user_id,
                token,
                tx,
                session: None,
                partners: HashMap::new(),
                sent: 0,
                last_session: None,
                last_requests: None,
            };
            if let Err(error) = stream.run(inbound, changes).await {
                let _ = stream.tx.send(Err(error.into())).await;
            }
            info!(rpc = "Sync", user_id = %stream.user_id, "closed");
        });
        Ok(Response::new(Box::pin(ReceiverStream::new(rx))))
    }
}

struct Stream {
    db: ServerDb,
    user_id: String,
    /// The session the stream was opened with: signing out, expiry or
    /// deleting the account ends it, and the stream with it, checked before
    /// anything is stored or sent.
    token: String,
    tx: mpsc::Sender<SyncResult>,
    /// The session the user's pointer named when the session was last sent,
    /// and its changes: the only session whose changes concern this stream.
    session: Option<(String, broadcast::Receiver<Change>)>,
    /// The partners in that session, and their accounts' changes: whose
    /// workout events go down this stream.
    partners: HashMap<String, broadcast::Receiver<Change>>,
    /// The last seq sent down.
    sent: i64,
    /// What was last sent, so an unchanged view isn't sent again.
    last_session: Option<Session>,
    last_requests: Option<GetJoinRequestsResponse>,
}

/// The phone hung up.
struct Closed;

/// What a stream woke for.
enum Woke {
    Up(Result<Option<SyncRequest>, Status>),
    Mine(Result<Change, broadcast::error::RecvError>),
    Session(Result<Change, broadcast::error::RecvError>),
    Partner(String, Result<Change, broadcast::error::RecvError>),
}

impl Stream {
    async fn run(
        &mut self,
        mut inbound: Streaming<SyncRequest>,
        mut changes: broadcast::Receiver<Change>,
    ) -> ServerResult<()> {
        // The device says what it holds; it gets the rest.
        self.sent = match inbound.message().await {
            Ok(Some(SyncRequest {
                kind: Some(sync_request::Kind::AfterSeq(after_seq)),
            })) => after_seq.max(0),
            Ok(Some(_)) => {
                return Err(Status::invalid_argument("the stream opens with after_seq").into())
            }
            Ok(None) | Err(_) => return Ok(()),
        };
        if self.send_events(true).await?.is_err() {
            return Ok(());
        }
        let library = ListTemplateLibraryResponse {
            templates: schlift_core::template_library::library().to_vec(),
            plans: Vec::new(),
        };
        if self
            .send(sync_response::Kind::Library(library))
            .await
            .is_err()
        {
            return Ok(());
        }
        if self.send_session().await?.is_err() || self.send_requests().await?.is_err() {
            return Ok(());
        }
        loop {
            // In order: the account's own changes before its session's, so
            // what was told first is sent first (its events, then the view
            // they changed), then the phone.
            let woke = tokio::select! {
                biased;
                change = changes.recv() => Woke::Mine(change),
                change = async {
                    match &mut self.session {
                        Some((_, session)) => session.recv().await,
                        None => std::future::pending().await,
                    }
                } => Woke::Session(change),
                (partner, change) = async {
                    if self.partners.is_empty() {
                        return std::future::pending().await;
                    }
                    let heard = self.partners.iter_mut().map(|(partner, changes)| {
                        Box::pin(async move { (partner.clone(), changes.recv().await) })
                    });
                    futures_util::future::select_all(heard).await.0
                } => Woke::Partner(partner, change),
                up = inbound.message() => Woke::Up(up),
            };
            let sent = match woke {
                Woke::Up(Ok(Some(up))) => self.receive(up).await?,
                // The phone closed its side, or the link died.
                Woke::Up(Ok(None) | Err(_)) => return Ok(()),
                Woke::Mine(Ok(change)) => self.changed(&change).await?,
                // Missed some: send everything again.
                Woke::Mine(Err(_)) => match self.send_events(false).await? {
                    Ok(()) => match self.send_session().await? {
                        Ok(()) => self.send_requests().await?,
                        closed => closed,
                    },
                    closed => closed,
                },
                Woke::Session(change) => {
                    if change.is_err() {
                        // Missed some, or (never, while watched) no longer
                        // told: watch afresh and send it whole.
                        self.session = None;
                    }
                    self.send_session().await?
                }
                Woke::Partner(partner, Ok(Change::Account(events))) => {
                    self.send_partner(&partner, &events, false).await
                }
                Woke::Partner(_, Ok(_)) => Ok(()),
                // Missed some of theirs: their workout so far, again.
                Woke::Partner(partner, Err(_)) => {
                    self.partners
                        .insert(partner.clone(), self.db.watch(Topic::User(partner.clone())));
                    self.send_partner_whole(&partner).await?
                }
            };
            if sent.is_err() {
                return Ok(());
            }
        }
    }

    async fn send(&self, kind: sync_response::Kind) -> Result<(), Closed> {
        self.tx
            .send(Ok(SyncResponse { kind: Some(kind) }))
            .await
            .map_err(|_| Closed)
    }

    /// Ends the stream once its session is signed out, expired or deleted.
    async fn ensure_signed_in(&self) -> ServerResult<()> {
        let signed_in = self
            .db
            .validate_auth_session(&self.token)
            .await
            .map_err(internal_error)?;
        if signed_in.as_ref() != Some(&self.user_id) {
            return Err(Status::unauthenticated("Invalid session token").into());
        }
        Ok(())
    }

    /// The device's own events (placed, stored, and sent back down with
    /// everyone else's) or a heartbeat (answered with the head).
    async fn receive(&mut self, up: SyncRequest) -> ServerResult<Result<(), Closed>> {
        self.ensure_signed_in().await?;
        match up.kind {
            Some(sync_request::Kind::Events(packed)) => {
                let events = unpack_push(&packed).map_err(core_status)?;
                check_push(&events)?;
                let pushed = self
                    .db
                    .push_events(&self.user_id, events)
                    .await
                    .map_err(internal_error)?;
                self.after_push(&pushed).await?;
                Ok(Ok(()))
            }
            Some(sync_request::Kind::Heartbeat(_)) | None => {
                let head = self.db.head(&self.user_id).await.map_err(internal_error)?;
                Ok(self.send(sync_response::Kind::Head(head)).await)
            }
            Some(sync_request::Kind::AfterSeq(_)) => {
                Err(Status::invalid_argument("after_seq opens the stream, once").into())
            }
        }
    }

    /// The account's events after the last sent, in pieces. With `always`,
    /// at least one message goes, so a device that holds everything hears
    /// the head and knows it has caught up.
    async fn send_events(&mut self, always: bool) -> ServerResult<Result<(), Closed>> {
        let head = self.db.head(&self.user_id).await.map_err(internal_error)?;
        let mut sent_any = false;
        loop {
            let events = self
                .db
                .events_after(&self.user_id, self.sent, EVENTS_PER_MESSAGE)
                .await
                .map_err(internal_error)?;
            let Some(last) = events.last().map(|e| e.seq) else {
                break;
            };
            let full = events.len() as i64 == EVENTS_PER_MESSAGE;
            let message = schlift::workout::v1::Events {
                packed: pack(&events),
                head: head.max(last),
            };
            if let Err(closed) = self.send(sync_response::Kind::Events(message)).await {
                return Ok(Err(closed));
            }
            self.sent = last;
            sent_any = true;
            if !full {
                break;
            }
        }
        if always && !sent_any {
            let message = schlift::workout::v1::Events {
                packed: Vec::new(),
                head,
            };
            return Ok(self.send(sync_response::Kind::Events(message)).await);
        }
        Ok(Ok(()))
    }

    /// Events just stored: sent as they are when they follow what was sent,
    /// read from the log when some were missed.
    async fn send_new(&mut self, events: &[Event]) -> ServerResult<Result<(), Closed>> {
        let (Some(first), Some(last)) = (events.first(), events.last()) else {
            return Ok(Ok(()));
        };
        if last.seq <= self.sent {
            return Ok(Ok(()));
        }
        if first.seq != self.sent + 1 {
            return self.send_events(false).await;
        }
        let message = schlift::workout::v1::Events {
            packed: pack(events),
            head: last.seq,
        };
        self.sent = last.seq;
        Ok(self.send(sync_response::Kind::Events(message)).await)
    }

    /// A workout ending takes the caller out of their session, its final
    /// state left on show to the others a while; one thrown away takes them
    /// out with nothing to show.
    async fn after_push(&self, pushed: &Pushed) -> ServerResult<()> {
        if !pushed.ended_workout && !pushed.discarded_workout {
            return Ok(());
        }
        let Some(session_id) = self
            .db
            .get_user_session_pointer(&self.user_id)
            .await
            .map_err(internal_error)?
        else {
            return Ok(());
        };
        let left = if pushed.discarded_workout {
            self.db.leave_session(&session_id, &self.user_id).await
        } else {
            self.db.end_session(&session_id, &self.user_id).await
        };
        left.map_err(internal_error)
    }

    /// A partner's workout events, of those just stored: what of them their
    /// partners see.
    async fn send_partner(
        &self,
        partner: &str,
        events: &[Event],
        whole: bool,
    ) -> Result<(), Closed> {
        let shared: Vec<Event> = events
            .iter()
            .filter(|e| shared_with_partners(&e.fact))
            .cloned()
            .collect();
        if shared.is_empty() && !whole {
            return Ok(());
        }
        let message = PartnerEvents {
            user_id: partner.to_string(),
            packed: pack(&shared),
            whole,
        };
        self.send(sync_response::Kind::PartnerEvents(message)).await
    }

    /// A partner's latest workout so far, replacing what the phone had.
    async fn send_partner_whole(&self, partner: &str) -> ServerResult<Result<(), Closed>> {
        let events = self
            .db
            .latest_workout_events(partner)
            .await
            .map_err(internal_error)?;
        Ok(self.send_partner(partner, &events, true).await)
    }

    async fn changed(&mut self, change: &Change) -> ServerResult<Result<(), Closed>> {
        match change {
            Change::Account(events) => self.send_new(events).await,
            Change::JoinRequests => self.send_requests().await,
            Change::Membership | Change::Session => self.send_session().await,
        }
    }

    async fn send_session(&mut self) -> ServerResult<Result<(), Closed>> {
        self.ensure_signed_in().await?;
        // Read, and its session watched, before the session: the pointer is
        // written before its change is announced, so a change that follows
        // is never missed.
        let pointer = self
            .db
            .get_user_session_pointer(&self.user_id)
            .await
            .map_err(internal_error)?;
        if self.session.as_ref().map(|(id, _)| id) != pointer.as_ref() {
            self.session = pointer.map(|id| {
                let changes = self.db.watch(Topic::Session(id.clone()));
                (id, changes)
            });
        }
        let session = current_session(&self.db, &self.user_id).await?;
        if self.last_session.as_ref() != Some(&session) {
            self.last_session = Some(session.clone());
            if let Err(closed) = self
                .send(sync_response::Kind::Session(session.clone()))
                .await
            {
                return Ok(Err(closed));
            }
        }
        // Each partner watched, before their workout so far is read, so
        // nothing they record between is missed (the phone skips an event
        // it already has).
        let members: Vec<String> = session
            .members
            .iter()
            .filter_map(|m| m.user.as_ref().map(|u| u.id.clone()))
            .collect();
        self.partners.retain(|partner, _| members.contains(partner));
        for partner in members {
            if self.partners.contains_key(&partner) {
                continue;
            }
            self.partners
                .insert(partner.clone(), self.db.watch(Topic::User(partner.clone())));
            if let Err(closed) = self.send_partner_whole(&partner).await? {
                return Ok(Err(closed));
            }
        }
        Ok(Ok(()))
    }

    async fn send_requests(&mut self) -> ServerResult<Result<(), Closed>> {
        self.ensure_signed_in().await?;
        let requests = join_requests(&self.db, &self.user_id).await?;
        if self.last_requests.as_ref() == Some(&requests) {
            return Ok(Ok(()));
        }
        self.last_requests = Some(requests.clone());
        Ok(self.send(sync_response::Kind::JoinRequests(requests)).await)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn event(fact: Fact) -> Event {
        Event {
            seq: 0,
            id: "e".to_string(),
            at: 1,
            fact,
        }
    }

    fn heart_rate(samples: usize) -> Event {
        event(Fact::HeartRateRecorded(
            schlift_core::events::HeartRateRecorded {
                workout_id: "w".to_string(),
                gaps_ms: vec![1_000; samples.saturating_sub(1)],
                bpm: vec![120; samples],
                ..Default::default()
            },
        ))
    }

    #[test]
    fn a_push_past_the_limits_is_refused() {
        assert!(check_push(&[heart_rate(MAX_HEART_RATE_SAMPLES_PER_EVENT)]).is_ok());
        let error = check_push(&[heart_rate(MAX_HEART_RATE_SAMPLES_PER_EVENT + 1)]).err();
        let status = Status::from(error.unwrap());
        assert_eq!(status.code(), tonic::Code::InvalidArgument);
    }

    #[test]
    fn a_large_import_is_allowed() {
        let workout = ImportedWorkout {
            heart_rate: vec![WorkoutHeartRatePoint::default(); 200],
            completed_sets: vec![CompletedSet::default(); 30],
            ..Default::default()
        };
        let import = event(Fact::HistoryImported(
            schlift_core::events::HistoryImported {
                workouts: vec![workout; 500],
                ..Default::default()
            },
        ));
        assert!(check_push(&[import]).is_ok());
    }
}
