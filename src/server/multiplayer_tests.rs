//! Tests for the multiplayer service's session roster + training-together history,
//! run against a real `ServerDb` on a temp directory through the real RPC handlers.

use super::*;

#[cfg(test)]
mod session_history_tests {
    use super::*;

    fn authed<T>(token: &str, msg: T) -> Request<T> {
        let mut req = Request::new(msg);
        req.metadata_mut()
            .insert("x-session-token", token.parse().unwrap());
        req
    }

    async fn setup() -> ServerMultiplayerService {
        let dir = std::env::temp_dir().join(format!("lift-mp-test-{}", Uuid::new_v4()));
        let db = ServerDb::new_in_dir(&dir).await.unwrap();
        ServerMultiplayerService { db }
    }

    async fn user(svc: &ServerMultiplayerService, name: &str) -> (String, String) {
        let (u, token) = svc
            .db
            .get_or_create_user_with_auth_session(name)
            .await
            .unwrap();
        (u.id, token)
    }

    fn has_participant(status: &SessionStatus, user_id: &str) -> bool {
        status
            .participants
            .iter()
            .any(|p| p.user.as_ref().map(|u| u.id.as_str()) == Some(user_id))
    }

    /// Leaving prunes the departed member from the LIVE view (the stale-peer bug),
    /// but the durable roster still records that they trained together.
    #[tokio::test]
    async fn leave_prunes_live_view_but_keeps_history() {
        let svc = setup().await;
        let (alice_id, alice_tok) = user(&svc, "alice").await;
        let (bob_id, bob_tok) = user(&svc, "bob").await;
        let alice_invite = svc.db.get_invite_token(&alice_id).await.unwrap().unwrap();

        svc.join_via_invite(authed(
            &bob_tok,
            JoinViaInviteRequest {
                invite_token: alice_invite,
            },
        ))
        .await
        .unwrap();

        // Alice sees Bob live.
        let sess = svc
            .get_current_session(authed(&alice_tok, GetCurrentSessionRequest {}))
            .await
            .unwrap()
            .into_inner();
        assert!(
            has_participant(sess.session_status.as_ref().unwrap(), &bob_id),
            "alice should see bob in the live session"
        );

        // Bob leaves.
        svc.leave_current_session(authed(&bob_tok, LeaveCurrentSessionRequest {}))
            .await
            .unwrap();

        // Live view no longer shows Bob.
        let sess2 = svc
            .get_current_session(authed(&alice_tok, GetCurrentSessionRequest {}))
            .await
            .unwrap()
            .into_inner();
        if let Some(status) = sess2.session_status {
            assert!(
                !has_participant(&status, &bob_id),
                "bob must be pruned from the live view after leaving"
            );
        }

        // Historical roster survives leaving: GetSessionParticipants (which backs a
        // past workout's "friends worked out with") still lists both, even though
        // the live cache was pruned.
        let shared_session = svc
            .db
            .list_shared_sessions(&alice_id, &bob_id)
            .await
            .unwrap()[0]
            .0
            .clone();
        let roster = svc
            .get_session_participants(authed(
                &alice_tok,
                GetSessionParticipantsRequest {
                    session_id: shared_session,
                },
            ))
            .await
            .unwrap()
            .into_inner()
            .participants;
        let roster_ids: Vec<_> = roster
            .iter()
            .filter_map(|p| p.user.as_ref().map(|u| u.id.clone()))
            .collect();
        assert!(roster_ids.contains(&alice_id));
        assert!(roster_ids.contains(&bob_id));

        // History still records the pairing.
        let partners = svc
            .get_training_partners(authed(&alice_tok, GetTrainingPartnersRequest {}))
            .await
            .unwrap()
            .into_inner()
            .partners;
        assert_eq!(partners.len(), 1, "alice should have one training partner");
        assert_eq!(partners[0].user.as_ref().unwrap().id, bob_id);
        assert_eq!(partners[0].sessions_together, 1);
        assert!(partners[0].last_trained_at > 0);

        // And it's symmetric.
        let bob_partners = svc
            .get_training_partners(authed(&bob_tok, GetTrainingPartnersRequest {}))
            .await
            .unwrap()
            .into_inner()
            .partners;
        assert_eq!(bob_partners.len(), 1);
        assert_eq!(bob_partners[0].user.as_ref().unwrap().id, alice_id);
    }

    /// GetSharedSessions lists the sessions two users were both in.
    #[tokio::test]
    async fn shared_sessions_lists_the_pairing() {
        let svc = setup().await;
        let (alice_id, alice_tok) = user(&svc, "alice").await;
        let (bob_id, bob_tok) = user(&svc, "bob").await;
        let alice_invite = svc.db.get_invite_token(&alice_id).await.unwrap().unwrap();
        svc.join_via_invite(authed(
            &bob_tok,
            JoinViaInviteRequest {
                invite_token: alice_invite,
            },
        ))
        .await
        .unwrap();

        let shared = svc
            .get_shared_sessions(authed(
                &alice_tok,
                GetSharedSessionsRequest {
                    partner_user_id: bob_id.clone(),
                },
            ))
            .await
            .unwrap()
            .into_inner()
            .sessions;
        assert_eq!(shared.len(), 1, "alice and bob share exactly one session");
        // Neither logged a workout in this test, so both flags are false.
        assert!(!shared[0].caller_worked_out);
        assert!(!shared[0].partner_worked_out);
    }

    /// Request → approve: gated on a prior pairing; the recipient sees the request
    /// and approving lands both in a session.
    #[tokio::test]
    async fn request_then_approve_pairs_both() {
        let svc = setup().await;
        let (alice_id, alice_tok) = user(&svc, "alice").await;
        let (bob_id, bob_tok) = user(&svc, "bob").await;

        // Stranger gate: Alice can't ping Bob before they've ever trained.
        let err = svc
            .request_join_partner(authed(
                &alice_tok,
                RequestJoinPartnerRequest {
                    partner_user_id: bob_id.clone(),
                },
            ))
            .await
            .unwrap_err();
        assert_eq!(err.code(), tonic::Code::FailedPrecondition);

        // Alice + Bob train together (via QR), then both leave.
        let alice_invite = svc.db.get_invite_token(&alice_id).await.unwrap().unwrap();
        svc.join_via_invite(authed(
            &bob_tok,
            JoinViaInviteRequest {
                invite_token: alice_invite,
            },
        ))
        .await
        .unwrap();
        svc.leave_current_session(authed(&bob_tok, LeaveCurrentSessionRequest {}))
            .await
            .unwrap();
        svc.leave_current_session(authed(&alice_tok, LeaveCurrentSessionRequest {}))
            .await
            .unwrap();

        // Alice asks Bob to train. Bob sees the pending request.
        let request_id = svc
            .request_join_partner(authed(
                &alice_tok,
                RequestJoinPartnerRequest {
                    partner_user_id: bob_id.clone(),
                },
            ))
            .await
            .unwrap()
            .into_inner()
            .request_id;
        let incoming = svc
            .get_join_requests(authed(&bob_tok, GetJoinRequestsRequest {}))
            .await
            .unwrap()
            .into_inner()
            .requests;
        assert_eq!(incoming.len(), 1);
        assert_eq!(incoming[0].request_id, request_id);
        assert_eq!(incoming[0].from_user.as_ref().unwrap().id, alice_id);
        // Alice (the requester) should not see her own outgoing request as incoming.
        assert!(svc
            .get_join_requests(authed(&alice_tok, GetJoinRequestsRequest {}))
            .await
            .unwrap()
            .into_inner()
            .requests
            .is_empty());

        // Only Bob may answer it.
        assert_eq!(
            svc.respond_join_request(authed(
                &alice_tok,
                RespondJoinRequestRequest {
                    request_id: request_id.clone(),
                    accept: true,
                },
            ))
            .await
            .unwrap_err()
            .code(),
            tonic::Code::PermissionDenied
        );

        // Bob approves → both land in the same session, and the request is consumed.
        let session_id = svc
            .respond_join_request(authed(
                &bob_tok,
                RespondJoinRequestRequest {
                    request_id: request_id.clone(),
                    accept: true,
                },
            ))
            .await
            .unwrap()
            .into_inner()
            .session_id;
        assert!(!session_id.is_empty());
        assert_eq!(
            svc.db.get_user_current_session(&alice_id).await.unwrap(),
            Some(session_id.clone())
        );
        assert_eq!(
            svc.db.get_user_current_session(&bob_id).await.unwrap(),
            Some(session_id)
        );
        assert!(svc
            .get_join_requests(authed(&bob_tok, GetJoinRequestsRequest {}))
            .await
            .unwrap()
            .into_inner()
            .requests
            .is_empty());
    }

    /// Declining a request consumes it without pairing anyone.
    #[tokio::test]
    async fn decline_request_does_not_pair() {
        let svc = setup().await;
        let (alice_id, alice_tok) = user(&svc, "alice").await;
        let (bob_id, bob_tok) = user(&svc, "bob").await;
        let alice_invite = svc.db.get_invite_token(&alice_id).await.unwrap().unwrap();
        svc.join_via_invite(authed(
            &bob_tok,
            JoinViaInviteRequest {
                invite_token: alice_invite,
            },
        ))
        .await
        .unwrap();
        svc.leave_current_session(authed(&bob_tok, LeaveCurrentSessionRequest {}))
            .await
            .unwrap();
        svc.leave_current_session(authed(&alice_tok, LeaveCurrentSessionRequest {}))
            .await
            .unwrap();

        let request_id = svc
            .request_join_partner(authed(
                &alice_tok,
                RequestJoinPartnerRequest {
                    partner_user_id: bob_id.clone(),
                },
            ))
            .await
            .unwrap()
            .into_inner()
            .request_id;
        let resp = svc
            .respond_join_request(authed(
                &bob_tok,
                RespondJoinRequestRequest {
                    request_id,
                    accept: false,
                },
            ))
            .await
            .unwrap()
            .into_inner();
        assert!(resp.session_id.is_empty());
        assert!(svc.db.get_user_current_session(&alice_id).await.unwrap().is_none());
        assert!(svc.db.get_user_current_session(&bob_id).await.unwrap().is_none());
    }

    /// Two people joining the same inviter's link at the same time must both land
    /// in the one session — not race into separate sessions that leave the inviter
    /// with only one of them.
    #[tokio::test]
    async fn two_people_joining_one_inviter_land_in_the_same_session() {
        let svc = setup().await;
        let (alice_id, alice_tok) = user(&svc, "alice").await;
        let (bob_id, bob_tok) = user(&svc, "bob").await;
        let (carol_id, carol_tok) = user(&svc, "carol").await;
        let invite = svc.db.get_invite_token(&alice_id).await.unwrap().unwrap();

        // Bob and Carol both accept Alice's invite concurrently.
        let (r1, r2) = tokio::join!(
            svc.join_via_invite(authed(
                &bob_tok,
                JoinViaInviteRequest { invite_token: invite.clone() },
            )),
            svc.join_via_invite(authed(
                &carol_tok,
                JoinViaInviteRequest { invite_token: invite.clone() },
            )),
        );
        r1.unwrap();
        r2.unwrap();

        // Alice sees both of them in her single session.
        let sess = svc
            .get_current_session(authed(&alice_tok, GetCurrentSessionRequest {}))
            .await
            .unwrap()
            .into_inner();
        let status = sess.session_status.as_ref().unwrap();
        assert!(has_participant(status, &bob_id), "alice should see bob");
        assert!(has_participant(status, &carol_id), "alice should see carol");

        // And all three share one session id.
        let a = svc.db.get_user_current_session(&alice_id).await.unwrap();
        let b = svc.db.get_user_current_session(&bob_id).await.unwrap();
        let c = svc.db.get_user_current_session(&carol_id).await.unwrap();
        assert!(a.is_some() && a == b && b == c, "all three in one session: {a:?} {b:?} {c:?}");
    }

    /// Asking several people via the request/accept flow gathers them all into the
    /// asker's session — the bug was each accept pulling the asker into a fresh 1:1
    /// and abandoning the previous person.
    #[tokio::test]
    async fn asking_two_partners_gathers_them_into_the_askers_session() {
        let svc = setup().await;
        let (alice_id, alice_tok) = user(&svc, "alice").await;
        let (bob_id, bob_tok) = user(&svc, "bob").await;
        let (carol_id, carol_tok) = user(&svc, "carol").await;
        let alice_invite = svc.db.get_invite_token(&alice_id).await.unwrap().unwrap();

        // Alice trains with each once (clears the stranger gate), then all go solo.
        for tok in [&bob_tok, &carol_tok] {
            svc.join_via_invite(authed(
                tok,
                JoinViaInviteRequest { invite_token: alice_invite.clone() },
            ))
            .await
            .unwrap();
            svc.leave_current_session(authed(tok, LeaveCurrentSessionRequest {}))
                .await
                .unwrap();
        }
        svc.leave_current_session(authed(&alice_tok, LeaveCurrentSessionRequest {}))
            .await
            .unwrap();

        // Alice asks both; both accept.
        for (id, tok) in [(&bob_id, &bob_tok), (&carol_id, &carol_tok)] {
            let req = svc
                .request_join_partner(authed(
                    &alice_tok,
                    RequestJoinPartnerRequest { partner_user_id: id.clone() },
                ))
                .await
                .unwrap()
                .into_inner()
                .request_id;
            svc.respond_join_request(authed(
                tok,
                RespondJoinRequestRequest { request_id: req, accept: true },
            ))
            .await
            .unwrap();
        }

        // All three share Alice's one session, and Alice sees both.
        let a = svc.db.get_user_current_session(&alice_id).await.unwrap();
        let b = svc.db.get_user_current_session(&bob_id).await.unwrap();
        let c = svc.db.get_user_current_session(&carol_id).await.unwrap();
        assert!(a.is_some() && a == b && b == c, "all three in one session: {a:?} {b:?} {c:?}");

        let sess = svc
            .get_current_session(authed(&alice_tok, GetCurrentSessionRequest {}))
            .await
            .unwrap()
            .into_inner();
        let status = sess.session_status.as_ref().unwrap();
        assert!(has_participant(status, &bob_id), "alice should see bob");
        assert!(has_participant(status, &carol_id), "alice should see carol");
    }
}
