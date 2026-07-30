use super::*;

// ── Multiplayer Service ──
//
// Session membership invariant: `user_current_session(user_id PK, session_id)` is the
// single source of truth for "is this user in a group right now?". Everything else
// (workouts.session_id, session_participants_current) is derived/historical cache.
//
// Transitions:
//   - JoinViaInvite: upsert both users' rows, backfill their active workouts' session_id,
//     refresh both participant blobs.
//   - StartWorkout: the workout row is stamped with the caller's current-session at start
//     (handled in workout.rs).
//   - Set actions: refresh caller's blob (handled in workout.rs).
//   - EndWorkout: refresh caller's final blob, then delete caller's row (workout.rs).
//   - LeaveCurrentSession: delete caller's row, prune their live blob so peers stop
//     seeing them, and stamp left_at on the durable session_members roster.
//
// Durable history: session_members(session_id, user_id, first_joined_at, left_at) is
// never deleted — it records who trained together and backs GetTrainingPartners /
// GetSharedSessions / JoinPartnerSession.

/// Serialises the JoinViaInvite read-decide-write so two people joining the same
/// inviter at once can't each read "no session yet", mint separate sessions, and
/// leave the inviter in only one of them (orphaning the other joiner). Joins are
/// rare, so a single global lock is simpler than per-target locking and just as
/// correct for a single backend instance.
static JOIN_LOCK: tokio::sync::Mutex<()> = tokio::sync::Mutex::const_new(());

#[derive(Clone)]
pub struct ServerMultiplayerService {
    pub db: ServerDb,
}

impl ServerMultiplayerService {
    /// Place `user_id` into `session_id` (upsert), backfill their active workout's
    /// historical session stamp if any, and refresh their participant blob so peers see
    /// them immediately on the next poll.
    async fn place_user_in_session(&self, user_id: &str, session_id: &str) -> Result<(), Status> {
        self.db
            .set_user_current_session(user_id, session_id)
            .await
            .map_err(internal_error)?;
        // Durable roster: record that this user was in this session (survives leave).
        self.db
            .upsert_session_member(session_id, user_id)
            .await
            .map_err(internal_error)?;
        let active_workout_id = self
            .db
            .get_active_workout_id(user_id)
            .await
            .map_err(internal_error)?;
        if let Some(workout_id) = active_workout_id.as_deref() {
            self.db
                .update_workout_session_id(user_id, workout_id, session_id)
                .await
                .map_err(internal_error)?;
        }
        refresh_participant_for_user(&self.db, user_id, session_id, active_workout_id.as_deref())
            .await
    }

    /// If `user_id` is currently in a session other than `target`, cleanly leave
    /// it (prune the live blob + stamp left_at) so its roster doesn't strand them.
    async fn leave_other_session(&self, user_id: &str, target: &str) -> Result<(), Status> {
        if let Some(current) = self
            .db
            .get_user_current_session(user_id)
            .await
            .map_err(internal_error)?
        {
            if current != target {
                self.db
                    .prune_session_participant(&current, user_id)
                    .await
                    .map_err(internal_error)?;
                self.db
                    .mark_session_member_left(&current, user_id)
                    .await
                    .map_err(internal_error)?;
            }
        }
        Ok(())
    }

    /// The single session-placement path for both invite-accept and
    /// request-accept: `joiner` joins `anchor`'s session, creating one if the
    /// anchor has none, and leaving whatever session `joiner` was in. Because
    /// everyone gathers into the *anchor* (invite owner / requester), one host
    /// pulling in several people forms one group — not a chain of 1:1s. Serialised
    /// behind a global lock so two people joining the same anchor at once can't
    /// each mint a separate session and orphan one of them.
    async fn gather_into_session(&self, anchor: &str, joiner: &str) -> Result<String, Status> {
        let _guard = JOIN_LOCK.lock().await;
        let session_id = self
            .db
            .get_user_current_session(anchor)
            .await
            .map_err(internal_error)?
            .unwrap_or_else(|| Uuid::new_v4().to_string());
        self.leave_other_session(joiner, &session_id).await?;
        self.place_user_in_session(anchor, &session_id).await?;
        self.place_user_in_session(joiner, &session_id).await?;
        Ok(session_id)
    }
}

#[tonic::async_trait]
impl MultiplayerService for ServerMultiplayerService {
    type SubscribeSessionStream =
        Pin<Box<dyn futures_util::Stream<Item = Result<SessionSubscriptionEvent, Status>> + Send>>;

    async fn join_via_invite(
        &self,
        request: Request<JoinViaInviteRequest>,
    ) -> Result<Response<JoinViaInviteResponse>, Status> {
        let caller_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let invite_token = req.invite_token;
        if invite_token.is_empty() {
            return Err(Status::invalid_argument("invite_token is required"));
        }
        let target_id = self
            .db
            .lookup_user_by_invite_token(&invite_token)
            .await
            .map_err(internal_error)?
            .ok_or_else(|| Status::not_found("Invite token not recognised"))?;
        info!(rpc = "JoinViaInvite", %caller_id, %target_id, "request");
        if target_id == caller_id {
            return Err(Status::invalid_argument(
                "cannot join via your own invite token",
            ));
        }

        // The invite owner is the host; the scanner joins their session. Same path
        // the request-accept flow uses, so several people scanning one code gather
        // into that one group.
        let session_id = self.gather_into_session(&target_id, &caller_id).await?;
        Ok(Response::new(JoinViaInviteResponse { session_id }))
    }

    async fn get_my_invite_token(
        &self,
        request: Request<GetMyInviteTokenRequest>,
    ) -> Result<Response<GetMyInviteTokenResponse>, Status> {
        let caller_id = authed_user_id(&request, &self.db).await?;
        let invite_token = self
            .db
            .get_invite_token(&caller_id)
            .await
            .map_err(internal_error)?
            .ok_or_else(|| Status::not_found("User not found"))?;
        Ok(Response::new(GetMyInviteTokenResponse { invite_token }))
    }

    async fn rotate_invite_token(
        &self,
        request: Request<RotateInviteTokenRequest>,
    ) -> Result<Response<RotateInviteTokenResponse>, Status> {
        let caller_id = authed_user_id(&request, &self.db).await?;
        let invite_token = self
            .db
            .rotate_invite_token(&caller_id)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(RotateInviteTokenResponse { invite_token }))
    }

    async fn get_participant_workout(
        &self,
        request: Request<GetParticipantWorkoutRequest>,
    ) -> Result<Response<ParticipantStatus>, Status> {
        let _caller_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "GetParticipantWorkout", user_id = %req.user_id, "request");
        let user = self
            .db
            .get_user(&req.user_id)
            .await
            .map_err(internal_error)?
            .ok_or_else(|| Status::not_found("User not found"))?;
        let active = if let Some(workout_id) = self
            .db
            .get_active_workout_id(&req.user_id)
            .await
            .map_err(internal_error)?
        {
            self.db
                .load_workout_full(&req.user_id, &workout_id)
                .await
                .map_err(internal_error)?
        } else {
            None
        };
        Ok(Response::new(build_participant_status(
            user,
            active.as_ref(),
        )))
    }

    async fn get_current_session(
        &self,
        request: Request<GetCurrentSessionRequest>,
    ) -> Result<Response<GetCurrentSessionResponse>, Status> {
        let caller_id = authed_user_id(&request, &self.db).await?;
        let session_id = self
            .db
            .get_user_current_session(&caller_id)
            .await
            .map_err(internal_error)?
            .unwrap_or_default();
        info!(rpc = "GetCurrentSession", %caller_id, %session_id, "request");
        if session_id.is_empty() {
            return Ok(Response::new(GetCurrentSessionResponse {
                session_id,
                session_status: None,
            }));
        }
        let mut participants = self
            .db
            .get_session_participants(&session_id)
            .await
            .map_err(internal_error)?;
        participants.retain(|p| p.user.as_ref().map(|u| u.id.as_str()) != Some(caller_id.as_str()));
        Ok(Response::new(GetCurrentSessionResponse {
            session_id: session_id.clone(),
            session_status: Some(SessionStatus {
                session_id,
                participants,
                next_up_user_id: String::new(),
                next_up_set: None,
                next_up_rest_until: 0,
                currently_lifting_user_id: String::new(),
            }),
        }))
    }

    async fn get_session_participants(
        &self,
        request: Request<GetSessionParticipantsRequest>,
    ) -> Result<Response<GetSessionParticipantsResponse>, Status> {
        let _caller_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "GetSessionParticipants", session_id = %req.session_id, "request");
        if req.session_id.is_empty() {
            return Err(Status::invalid_argument("session_id is required"));
        }
        // Historical roster: read from the durable session_members table, not the
        // live participant cache (which is pruned when members leave). This is what
        // backs "who did I train with" on a past workout's summary, so it must
        // survive everyone leaving. Identity only — live progress isn't retained.
        let member_ids = self
            .db
            .list_session_member_ids(&req.session_id)
            .await
            .map_err(internal_error)?;
        let mut participants = Vec::with_capacity(member_ids.len());
        for user_id in member_ids {
            if let Some(user) = self.db.get_user(&user_id).await.map_err(internal_error)? {
                participants.push(build_participant_status(user, None));
            }
        }
        Ok(Response::new(GetSessionParticipantsResponse {
            session_id: req.session_id,
            participants,
        }))
    }

    async fn leave_current_session(
        &self,
        request: Request<LeaveCurrentSessionRequest>,
    ) -> Result<Response<LeaveCurrentSessionResponse>, Status> {
        let caller_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "LeaveCurrentSession", %caller_id, "request");
        // Capture which session we're leaving before clearing the live pointer, so
        // we can prune the live cache and stamp the durable roster.
        let session_id = self
            .db
            .get_user_current_session(&caller_id)
            .await
            .map_err(internal_error)?;
        self.db
            .clear_user_current_session(&caller_id)
            .await
            .map_err(internal_error)?;
        if let Some(session_id) = session_id {
            // Remove our live snapshot so remaining members stop seeing us as
            // present (the stale-peer bug), and mark the durable roster row left.
            self.db
                .prune_session_participant(&session_id, &caller_id)
                .await
                .map_err(internal_error)?;
            self.db
                .mark_session_member_left(&session_id, &caller_id)
                .await
                .map_err(internal_error)?;
        }
        Ok(Response::new(LeaveCurrentSessionResponse {}))
    }

    async fn subscribe_session(
        &self,
        _request: Request<SubscribeSessionRequest>,
    ) -> Result<Response<Self::SubscribeSessionStream>, Status> {
        Err(Status::unimplemented(
            "server multiplayer uses polling, not streaming",
        ))
    }

    async fn update_active_workout(
        &self,
        request: Request<UpdateActiveWorkoutRequest>,
    ) -> Result<Response<UpdateActiveWorkoutResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "UpdateActiveWorkout", %user_id, "request");
        if let Some(session_id) = self
            .db
            .get_user_current_session(&user_id)
            .await
            .map_err(internal_error)?
        {
            refresh_participant_for_user(&self.db, &user_id, &session_id, None).await?;
        }
        Ok(Response::new(UpdateActiveWorkoutResponse {}))
    }

    async fn get_training_partners(
        &self,
        request: Request<GetTrainingPartnersRequest>,
    ) -> Result<Response<GetTrainingPartnersResponse>, Status> {
        let caller_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "GetTrainingPartners", %caller_id, "request");
        let rows = self
            .db
            .list_training_partners(&caller_id)
            .await
            .map_err(internal_error)?;
        let mut partners = Vec::with_capacity(rows.len());
        for (partner_id, sessions_together, last_trained_at) in rows {
            if let Some(user) = self.db.get_user(&partner_id).await.map_err(internal_error)? {
                partners.push(TrainingPartner {
                    user: Some(user),
                    sessions_together: sessions_together as i32,
                    last_trained_at,
                });
            }
        }
        Ok(Response::new(GetTrainingPartnersResponse { partners }))
    }

    async fn get_shared_sessions(
        &self,
        request: Request<GetSharedSessionsRequest>,
    ) -> Result<Response<GetSharedSessionsResponse>, Status> {
        let caller_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        if req.partner_user_id.is_empty() {
            return Err(Status::invalid_argument("partner_user_id is required"));
        }
        info!(rpc = "GetSharedSessions", %caller_id, partner = %req.partner_user_id, "request");
        let rows = self
            .db
            .list_shared_sessions(&caller_id, &req.partner_user_id)
            .await
            .map_err(internal_error)?;
        let sessions = rows
            .into_iter()
            .map(
                |(session_id, trained_at, caller_wo, partner_wo)| SharedSession {
                    session_id,
                    trained_at,
                    caller_worked_out: caller_wo,
                    partner_worked_out: partner_wo,
                },
            )
            .collect();
        Ok(Response::new(GetSharedSessionsResponse { sessions }))
    }

    async fn request_join_partner(
        &self,
        request: Request<RequestJoinPartnerRequest>,
    ) -> Result<Response<RequestJoinPartnerResponse>, Status> {
        let caller_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        let partner_id = req.partner_user_id;
        if partner_id.is_empty() {
            return Err(Status::invalid_argument("partner_user_id is required"));
        }
        if partner_id == caller_id {
            return Err(Status::invalid_argument("cannot request yourself"));
        }
        info!(rpc = "RequestJoinPartner", %caller_id, %partner_id, "request");
        // Gate on an existing relationship — you must have paired (via QR) at least
        // once before you can ping someone to train.
        if !self
            .db
            .have_trained_together(&caller_id, &partner_id)
            .await
            .map_err(internal_error)?
        {
            return Err(Status::failed_precondition(
                "You haven't trained with this person yet — scan their code first.",
            ));
        }
        let request_id = Uuid::new_v4().to_string();
        self.db
            .create_join_request(&request_id, &caller_id, &partner_id)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(RequestJoinPartnerResponse { request_id }))
    }

    async fn get_join_requests(
        &self,
        request: Request<GetJoinRequestsRequest>,
    ) -> Result<Response<GetJoinRequestsResponse>, Status> {
        let caller_id = authed_user_id(&request, &self.db).await?;
        // Only fresh asks (last 2 minutes) so a stale request doesn't linger.
        let since = now_unix() - 120;
        let rows = self
            .db
            .list_incoming_join_requests(&caller_id, since)
            .await
            .map_err(internal_error)?;
        let mut requests = Vec::with_capacity(rows.len());
        for (request_id, from_id, created_at) in rows {
            if let Some(user) = self.db.get_user(&from_id).await.map_err(internal_error)? {
                requests.push(JoinRequest {
                    request_id,
                    from_user: Some(user),
                    created_at,
                });
            }
        }
        Ok(Response::new(GetJoinRequestsResponse { requests }))
    }

    async fn respond_join_request(
        &self,
        request: Request<RespondJoinRequestRequest>,
    ) -> Result<Response<RespondJoinRequestResponse>, Status> {
        let caller_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        if req.request_id.is_empty() {
            return Err(Status::invalid_argument("request_id is required"));
        }
        let (from_id, to_id) = self
            .db
            .get_join_request(&req.request_id)
            .await
            .map_err(internal_error)?
            .ok_or_else(|| Status::not_found("request not found or already handled"))?;
        // Only the recipient may answer their own request.
        if to_id != caller_id {
            return Err(Status::permission_denied("not your request to answer"));
        }
        info!(rpc = "RespondJoinRequest", %caller_id, %from_id, accept = req.accept, "request");
        self.db
            .delete_join_request(&req.request_id)
            .await
            .map_err(internal_error)?;
        if !req.accept {
            return Ok(Response::new(RespondJoinRequestResponse {
                session_id: String::new(),
            }));
        }
        // Approved: everyone gathers into the *requester's* session — the person
        // who sent the asks is the host, so asking several people forms one group
        // instead of pulling the requester into a fresh 1:1 per accept. Same helper
        // the invite flow uses.
        let session_id = self.gather_into_session(&from_id, &caller_id).await?;
        Ok(Response::new(RespondJoinRequestResponse { session_id }))
    }
}
