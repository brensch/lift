use super::*;
use crate::db::{Change, Diverged, Pushed};
use schlift_core::sync::{pack, unpack_push};
use tokio::sync::{broadcast, mpsc};
use tokio_stream::wrappers::ReceiverStream;
use tonic::Streaming;

// ── Sync Service ──
//
// One stream per connected phone. Up: the phone's events (and heartbeats).
// Down: the head the server holds after each, and — whenever it changes,
// on connect, and every RESEND_EVERY regardless — the caller's session and
// requests to join them; and on connect the template library, which coupled
// templates follow. Every down message is whole, never a diff, so a dropped
// one is healed by the next.

/// How often the session and join requests are re-sent even with nothing
/// heard to change them: the backstop for a missed notification, and how a
/// request to join expires from view.
const RESEND_EVERY: std::time::Duration = std::time::Duration::from_secs(20);

// What one event in a push may hold (the batch's size and event count are
// limited as it is decoded, in schlift_core::sync). Far above anything a
// phone records; past them the push is refused whole.
const MAX_HEART_RATE_SAMPLES_PER_EVENT: usize = 20_000;
const MAX_IMPORTED_WORKOUTS: usize = 10_000;
const MAX_IMPORTED_HEART_RATE_SAMPLES: usize = 2_000_000;

/// Refuse a push larger than any phone makes.
fn check_push(events: &[Event]) -> ServerResult<()> {
    let too_big = |what: &str, limit: usize| -> ServerResult<()> {
        Err(Status::invalid_argument(format!("push too large: more than {limit} {what}")).into())
    };
    for event in events {
        match &event.kind {
            Some(event::Kind::HeartRate(req))
                if req.samples.len() > MAX_HEART_RATE_SAMPLES_PER_EVENT =>
            {
                return too_big(
                    "heart-rate samples in one event",
                    MAX_HEART_RATE_SAMPLES_PER_EVENT,
                );
            }
            Some(event::Kind::ImportHistory(import)) => {
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
        // Subscribed before the first send, so nothing between is missed.
        let changes = self.db.subscribe();
        let (tx, rx) = mpsc::channel(16);
        let db = self.db.clone();
        tokio::spawn(async move {
            let mut stream = Stream {
                db,
                user_id,
                token,
                tx,
                pointer: None,
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

    async fn pull_events(
        &self,
        request: Request<PullEventsRequest>,
    ) -> Result<Response<PullEventsResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "PullEvents", %user_id, after_seq = req.after_seq, "request");
        let events = self
            .db
            .events_after(&user_id, req.after_seq)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(PullEventsResponse {
            events: pack(events),
        }))
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
    /// The session the user's pointer named when the session was last sent:
    /// a session's changes concern this stream only when it is that one.
    pointer: Option<String>,
    /// What was last sent, so an unchanged view isn't sent again.
    last_session: Option<GetCurrentSessionResponse>,
    last_requests: Option<GetJoinRequestsResponse>,
}

/// The phone hung up.
struct Closed;

impl Stream {
    async fn run(
        &mut self,
        mut inbound: Streaming<SyncRequest>,
        mut changes: broadcast::Receiver<Change>,
    ) -> ServerResult<()> {
        let head = self.db.head(&self.user_id).await.map_err(internal_error)?;
        if self.send(sync_response::Kind::Head(head)).await.is_err() {
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
        let mut resend = tokio::time::interval(RESEND_EVERY);
        loop {
            let sent = tokio::select! {
                up = inbound.message() => match up {
                    Ok(Some(up)) => self.receive(up).await?,
                    // The phone closed its side, or the link died.
                    Ok(None) | Err(_) => return Ok(()),
                },
                change = changes.recv() => match change {
                    Ok(change) => self.changed(&change).await?,
                    // Missed some: send everything again.
                    Err(broadcast::error::RecvError::Lagged(_)) => self.send_views().await?,
                    Err(broadcast::error::RecvError::Closed) => return Ok(()),
                },
                _ = resend.tick() => self.send_views().await?,
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

    /// Events (stored, then acked with the head) or a heartbeat (acked).
    async fn receive(&mut self, up: SyncRequest) -> ServerResult<Result<(), Closed>> {
        self.ensure_signed_in().await?;
        let head = match up.kind {
            Some(sync_request::Kind::Events(packed)) => {
                let events = unpack_push(&packed).map_err(core_status)?;
                check_push(&events)?;
                let pushed = self
                    .db
                    .push_events(&self.user_id, events)
                    .await
                    .map_err(|error| match error.downcast_ref::<Diverged>() {
                        // The phone shows this and stops pushing; nothing is merged.
                        Some(diverged) => Status::failed_precondition(diverged.to_string()).into(),
                        None => internal_error(error),
                    })?;
                self.after_push(&pushed).await?;
                pushed.head
            }
            Some(sync_request::Kind::Heartbeat(_)) | None => {
                self.db.head(&self.user_id).await.map_err(internal_error)?
            }
        };
        Ok(self.send(sync_response::Kind::Head(head)).await)
    }

    /// New events other than heart rate change what session partners see; a
    /// workout ending takes the caller out of the session, its final state
    /// left on show.
    async fn after_push(&self, pushed: &Pushed) -> ServerResult<()> {
        if !pushed.progressed {
            return Ok(());
        }
        let Some(session_id) = self
            .db
            .get_user_current_session(&self.user_id)
            .await
            .map_err(internal_error)?
        else {
            return Ok(());
        };
        let done = if pushed.ended_workout.is_some() {
            // Ending is leaving: the final state stays on show to the others
            // until it goes idle.
            self.db.end_session(&session_id, &self.user_id).await
        } else {
            self.db.touch_session(&session_id, &self.user_id).await
        };
        done.map_err(internal_error)
    }

    async fn changed(&mut self, change: &Change) -> ServerResult<Result<(), Closed>> {
        match change {
            Change::JoinRequests(user) if *user == self.user_id => self.send_requests().await,
            Change::Membership(user) if *user == self.user_id => self.send_session().await,
            Change::Session(session) if self.pointer.as_ref() == Some(session) => {
                self.send_session().await
            }
            _ => Ok(Ok(())),
        }
    }

    async fn send_views(&mut self) -> ServerResult<Result<(), Closed>> {
        if let Err(closed) = self.send_session().await? {
            return Ok(Err(closed));
        }
        self.send_requests().await
    }

    async fn send_session(&mut self) -> ServerResult<Result<(), Closed>> {
        self.ensure_signed_in().await?;
        // Read before the session: the pointer is written before its change
        // is announced, so a change that follows is never missed.
        self.pointer = self
            .db
            .get_user_session_pointer(&self.user_id)
            .await
            .map_err(internal_error)?;
        let session = current_session(&self.db, &self.user_id).await?;
        if self.last_session.as_ref() == Some(&session) {
            return Ok(Ok(()));
        }
        self.last_session = Some(session.clone());
        Ok(self.send(sync_response::Kind::Session(session)).await)
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

    fn heart_rate(samples: usize) -> Event {
        Event {
            kind: Some(event::Kind::HeartRate(AppendWorkoutHeartRateRequest {
                workout_id: "w".to_string(),
                samples: vec![WorkoutHeartRatePoint::default(); samples],
            })),
            ..Default::default()
        }
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
        let import = Event {
            kind: Some(event::Kind::ImportHistory(ImportHistory {
                workouts: vec![workout; 500],
                ..Default::default()
            })),
            ..Default::default()
        };
        assert!(check_push(&[import]).is_ok());
    }
}
