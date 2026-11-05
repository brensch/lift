use super::*;
use std::collections::HashMap;

// ── Multiplayer Service ──
//
// Who is in which session is session_members (db/session.rs): one row per
// (session, user), the user's current session being the row with left_at 0.
// Where a member is up to is never stored or computed here: each partner's
// phone folds their workout's events, which the Sync stream forwards
// (sync.rs, schlift_core::session).
//
// A member's part in a session is one workout (session_members.workout_id):
// the first they train in after joining. Only its events reach the others.
//
// Transitions, each one write:
//   - JoinViaInvite / RespondJoinRequest: both users join the anchor's session
//     (or a new one); any other session they were in is left.
//   - Their first workout in it, ended, thrown away, or another started:
//     followed from what they push (ServerDb::follow_session). Ending it is
//     leaving with it on show a while; the others are out at once.
//   - Idle: a member whose workout in the session (or, before one, whose
//     joining) is SHOWN_FOR_SECONDS old is out, written when first noticed
//     (get_user_current_session), so nothing they do later lands in it.
//   - LeaveCurrentSession: out and off show at once.
//
// The rows are never deleted (except with the account): they record who
// trained together, for GetTrainingPartners, rosters and the prior-pairing
// check in RequestJoinPartner.

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
    /// The single session-placement path for both invite-accept and
    /// request-accept: `joiner` joins `anchor`'s session, creating one if the
    /// anchor has none, and leaving whatever session `joiner` was in. Because
    /// everyone gathers into the *anchor* (invite owner / requester), one host
    /// pulling in several people forms one group — not a chain of 1:1s. Serialised
    /// behind a global lock so two people joining the same anchor at once can't
    /// each mint a separate session and orphan one of them.
    async fn gather_into_session(&self, anchor: &str, joiner: &str) -> ServerResult<String> {
        let _guard = JOIN_LOCK.lock().await;
        let session_id = self
            .db
            .get_user_current_session(anchor)
            .await
            .map_err(internal_error)?
            .unwrap_or_else(|| Uuid::new_v4().to_string());
        // An idle anchor has left their old session as it was read: they
        // start afresh, and no one joins the group they were idle in.
        for user in [anchor, joiner] {
            self.db
                .join_session(&session_id, user)
                .await
                .map_err(internal_error)?;
        }
        Ok(session_id)
    }
}

#[tonic::async_trait]
impl MultiplayerService for ServerMultiplayerService {
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

    async fn get_session_rosters(
        &self,
        request: Request<GetSessionRostersRequest>,
    ) -> Result<Response<GetSessionRostersResponse>, Status> {
        let caller_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "GetSessionRosters", %caller_id, sessions = req.session_ids.len(), "request");
        // Historical rosters: every member a session ever had, so they survive
        // everyone leaving. Identity only, and only for sessions the caller
        // was in.
        let mut sessions = self
            .db
            .list_session_partner_ids(&caller_id)
            .await
            .map_err(internal_error)?;
        let mut users: HashMap<String, Option<User>> = HashMap::new();
        let mut rosters = Vec::new();
        for session_id in req.session_ids {
            let Some(partner_ids) = sessions.remove(&session_id) else {
                continue;
            };
            let mut partners = Vec::with_capacity(partner_ids.len());
            for user_id in partner_ids {
                if !users.contains_key(&user_id) {
                    let user = self.db.get_user(&user_id).await.map_err(internal_error)?;
                    users.insert(user_id.clone(), user.map(as_seen_by_others));
                }
                if let Some(Some(user)) = users.get(&user_id) {
                    partners.push(user.clone());
                }
            }
            rosters.push(SessionRoster {
                session_id,
                partners,
            });
        }
        Ok(Response::new(GetSessionRostersResponse { rosters }))
    }

    async fn leave_current_session(
        &self,
        request: Request<LeaveCurrentSessionRequest>,
    ) -> Result<Response<LeaveCurrentSessionResponse>, Status> {
        let caller_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "LeaveCurrentSession", %caller_id, "request");
        if let Some(session_id) = self
            .db
            .get_user_session_pointer(&caller_id)
            .await
            .map_err(internal_error)?
        {
            self.db
                .leave_session(&session_id, &caller_id)
                .await
                .map_err(internal_error)?;
        }
        Ok(Response::new(LeaveCurrentSessionResponse {}))
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
            if let Some(user) = self
                .db
                .get_user(&partner_id)
                .await
                .map_err(internal_error)?
            {
                partners.push(TrainingPartner {
                    user: Some(as_seen_by_others(user)),
                    sessions_together: sessions_together as i32,
                    last_trained_at,
                });
            }
        }
        Ok(Response::new(GetTrainingPartnersResponse { partners }))
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
        Ok(Response::new(join_requests(&self.db, &caller_id).await?))
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
            .get_join_request(
                &req.request_id,
                now_unix() - crate::db::JOIN_REQUEST_TTL_SECONDS,
            )
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

/// The caller's current session as they see it: who else is in it. Where
/// each is up to the stream sends as their workout's events. Empty when not
/// in one.
pub(super) async fn current_session(db: &ServerDb, user_id: &str) -> ServerResult<Session> {
    let Some(session_id) = db
        .get_user_current_session(user_id)
        .await
        .map_err(internal_error)?
    else {
        return Ok(Session::default());
    };
    let mut members = Vec::new();
    for (member, joined_at, ended_at) in db
        .session_roster(&session_id)
        .await
        .map_err(internal_error)?
    {
        if member == user_id {
            continue;
        }
        if let Some(user) = db.get_user(&member).await.map_err(internal_error)? {
            members.push(SessionMember {
                user: Some(as_seen_by_others(user)),
                joined_at,
                ended_at,
            });
        }
    }
    Ok(Session {
        session_id,
        members,
    })
}

/// Fresh requests to join the user (the last two minutes, so a stale ask
/// doesn't linger).
pub(super) async fn join_requests(
    db: &ServerDb,
    user_id: &str,
) -> ServerResult<GetJoinRequestsResponse> {
    let since = now_unix() - crate::db::JOIN_REQUEST_TTL_SECONDS;
    let rows = db
        .list_incoming_join_requests(user_id, since)
        .await
        .map_err(internal_error)?;
    let mut requests = Vec::with_capacity(rows.len());
    for (request_id, from_id, created_at) in rows {
        if let Some(user) = db.get_user(&from_id).await.map_err(internal_error)? {
            requests.push(JoinRequest {
                request_id,
                from_user: Some(as_seen_by_others(user)),
                created_at,
            });
        }
    }
    Ok(GetJoinRequestsResponse { requests })
}
