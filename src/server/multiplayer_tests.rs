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

    fn has_member(session: &Session, user_id: &str) -> bool {
        session
            .members
            .iter()
            .any(|m| m.user.as_ref().map(|u| u.id.as_str()) == Some(user_id))
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
        let sess = current_session(&svc.db, &alice_id).await.unwrap();
        assert!(
            has_member(&sess, &bob_id),
            "alice should see bob in the live session"
        );

        // Bob leaves.
        svc.leave_current_session(authed(&bob_tok, LeaveCurrentSessionRequest {}))
            .await
            .unwrap();

        // Live view no longer shows Bob.
        let sess2 = current_session(&svc.db, &alice_id).await.unwrap();
        assert!(
            !has_member(&sess2, &bob_id),
            "bob must be pruned from the live view after leaving"
        );

        // Historical roster survives leaving: GetSessionRosters (which backs a
        // past workout's "friends worked out with") still lists bob, even though
        // the live cache was pruned.
        let shared_session = sess.session_id.clone();
        let (_, carol_tok) = user(&svc, "carol").await;
        let outsider = svc
            .get_session_rosters(authed(
                &carol_tok,
                GetSessionRostersRequest {
                    session_ids: vec![shared_session.clone()],
                },
            ))
            .await
            .unwrap()
            .into_inner()
            .rosters;
        assert!(
            outsider.is_empty(),
            "someone who was not in the session must not see its roster"
        );
        let rosters = svc
            .get_session_rosters(authed(
                &alice_tok,
                GetSessionRostersRequest {
                    session_ids: vec![shared_session.clone(), "no-such-session".into()],
                },
            ))
            .await
            .unwrap()
            .into_inner()
            .rosters;
        assert_eq!(rosters.len(), 1, "only the session alice was in");
        assert_eq!(rosters[0].session_id, shared_session);
        let partner_ids: Vec<_> = rosters[0].partners.iter().map(|u| u.id.clone()).collect();
        assert_eq!(partner_ids, vec![bob_id.clone()], "everyone but alice");

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

    /// A member who does nothing for SHOWN_FOR_SECONDS is out on their own:
    /// they're no longer in a group. (The others' phones stop showing them,
    /// from what they last recorded: schlift_core::session.)
    #[tokio::test]
    async fn an_idle_member_drops_out() {
        let svc = setup().await;
        let (alice_id, _) = user(&svc, "alice").await;
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

        svc.db
            .age_session_member(&bob_id, schlift_core::session::SHOWN_FOR_SECONDS + 1)
            .await
            .unwrap();

        let alice_view = current_session(&svc.db, &alice_id).await.unwrap();
        assert!(
            has_member(&alice_view, &bob_id),
            "alice's roster still lists bob: her phone stops showing him"
        );
        let bob_view = current_session(&svc.db, &bob_id).await.unwrap();
        assert!(bob_view.session_id.is_empty(), "bob is in no group");
    }

    /// An idle member who then leaves still has their leave stamped on the
    /// group's roster, and their stale pointer is cleared.
    #[tokio::test]
    async fn an_idle_members_leave_is_stamped() {
        let svc = setup().await;
        let (alice_id, _) = user(&svc, "alice").await;
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
        let session_id = svc
            .db
            .get_user_session_pointer(&bob_id)
            .await
            .unwrap()
            .unwrap();
        svc.db
            .age_session_member(&bob_id, schlift_core::session::SHOWN_FOR_SECONDS + 1)
            .await
            .unwrap();

        svc.leave_current_session(authed(&bob_tok, LeaveCurrentSessionRequest {}))
            .await
            .unwrap();
        assert!(svc
            .db
            .get_user_session_pointer(&bob_id)
            .await
            .unwrap()
            .is_none());
        assert!(
            svc.db
                .session_member_left_at(&session_id, &bob_id)
                .await
                .unwrap()
                > 0,
            "bob's leave is on the roster"
        );
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
        assert!(svc
            .db
            .get_user_current_session(&alice_id)
            .await
            .unwrap()
            .is_none());
        assert!(svc
            .db
            .get_user_current_session(&bob_id)
            .await
            .unwrap()
            .is_none());
    }

    /// A request past its TTL can no longer be accepted, so it pulls no one
    /// into a session.
    #[tokio::test]
    async fn expired_request_cannot_be_accepted() {
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
        svc.db
            .age_join_request(&request_id, crate::db::JOIN_REQUEST_TTL_SECONDS + 1)
            .await
            .unwrap();
        assert_eq!(
            svc.respond_join_request(authed(
                &bob_tok,
                RespondJoinRequestRequest {
                    request_id,
                    accept: true,
                },
            ))
            .await
            .unwrap_err()
            .code(),
            tonic::Code::NotFound
        );
        assert!(svc
            .db
            .get_user_current_session(&alice_id)
            .await
            .unwrap()
            .is_none());
    }

    /// Two people joining the same inviter's link at the same time must both land
    /// in the one session — not race into separate sessions that leave the inviter
    /// with only one of them.
    #[tokio::test]
    async fn two_people_joining_one_inviter_land_in_the_same_session() {
        let svc = setup().await;
        let (alice_id, _) = user(&svc, "alice").await;
        let (bob_id, bob_tok) = user(&svc, "bob").await;
        let (carol_id, carol_tok) = user(&svc, "carol").await;
        let invite = svc.db.get_invite_token(&alice_id).await.unwrap().unwrap();

        // Bob and Carol both accept Alice's invite concurrently.
        let (r1, r2) = tokio::join!(
            svc.join_via_invite(authed(
                &bob_tok,
                JoinViaInviteRequest {
                    invite_token: invite.clone()
                },
            )),
            svc.join_via_invite(authed(
                &carol_tok,
                JoinViaInviteRequest {
                    invite_token: invite.clone()
                },
            )),
        );
        r1.unwrap();
        r2.unwrap();

        // Alice sees both of them in her single session.
        let sess = current_session(&svc.db, &alice_id).await.unwrap();
        assert!(has_member(&sess, &bob_id), "alice should see bob");
        assert!(has_member(&sess, &carol_id), "alice should see carol");

        // And all three share one session id.
        let a = svc.db.get_user_current_session(&alice_id).await.unwrap();
        let b = svc.db.get_user_current_session(&bob_id).await.unwrap();
        let c = svc.db.get_user_current_session(&carol_id).await.unwrap();
        assert!(
            a.is_some() && a == b && b == c,
            "all three in one session: {a:?} {b:?} {c:?}"
        );
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
                JoinViaInviteRequest {
                    invite_token: alice_invite.clone(),
                },
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
                    RequestJoinPartnerRequest {
                        partner_user_id: id.clone(),
                    },
                ))
                .await
                .unwrap()
                .into_inner()
                .request_id;
            svc.respond_join_request(authed(
                tok,
                RespondJoinRequestRequest {
                    request_id: req,
                    accept: true,
                },
            ))
            .await
            .unwrap();
        }

        // All three share Alice's one session, and Alice sees both.
        let a = svc.db.get_user_current_session(&alice_id).await.unwrap();
        let b = svc.db.get_user_current_session(&bob_id).await.unwrap();
        let c = svc.db.get_user_current_session(&carol_id).await.unwrap();
        assert!(
            a.is_some() && a == b && b == c,
            "all three in one session: {a:?} {b:?} {c:?}"
        );

        let sess = current_session(&svc.db, &alice_id).await.unwrap();
        assert!(has_member(&sess, &bob_id), "alice should see bob");
        assert!(has_member(&sess, &carol_id), "alice should see carol");
    }

    /// Someone's body weight is theirs alone: partners see them without it.
    #[tokio::test]
    async fn partners_do_not_see_body_weight() {
        let svc = setup().await;
        let (alice_id, _) = user(&svc, "alice").await;
        let (bob_id, bob_tok) = user(&svc, "bob").await;
        svc.db
            .update_user_profile(&alice_id, "", "", 82.5)
            .await
            .unwrap();
        let alice_invite = svc.db.get_invite_token(&alice_id).await.unwrap().unwrap();
        svc.join_via_invite(authed(
            &bob_tok,
            JoinViaInviteRequest {
                invite_token: alice_invite,
            },
        ))
        .await
        .unwrap();

        let sess = current_session(&svc.db, &bob_id).await.unwrap();
        let alice = sess
            .members
            .iter()
            .filter_map(|m| m.user.as_ref())
            .find(|u| u.id == alice_id)
            .expect("bob sees alice");
        assert_eq!(alice.body_weight_kg, 0.0);

        let partners = svc
            .get_training_partners(authed(&bob_tok, GetTrainingPartnersRequest {}))
            .await
            .unwrap()
            .into_inner()
            .partners;
        assert_eq!(partners[0].user.as_ref().unwrap().body_weight_kg, 0.0);

        let rosters = svc
            .get_session_rosters(authed(
                &bob_tok,
                GetSessionRostersRequest {
                    session_ids: vec![sess.session_id],
                },
            ))
            .await
            .unwrap()
            .into_inner()
            .rosters;
        assert_eq!(rosters[0].partners[0].body_weight_kg, 0.0);

        let own = svc
            .db
            .get_user(&alice_id)
            .await
            .unwrap()
            .unwrap()
            .body_weight_kg;
        assert_eq!(own, 82.5, "alice's own record keeps it");
    }

    /// Coming back to a session left long ago counts as joining it now:
    /// the rejoiner is in it, not dropped as idle from their first join.
    #[tokio::test]
    async fn rejoining_a_session_left_long_ago_puts_you_back_in_it() {
        let svc = setup().await;
        let (alice_id, _) = user(&svc, "alice").await;
        let (bob_id, bob_tok) = user(&svc, "bob").await;
        let alice_invite = svc.db.get_invite_token(&alice_id).await.unwrap().unwrap();
        let join = || {
            svc.join_via_invite(authed(
                &bob_tok,
                JoinViaInviteRequest {
                    invite_token: alice_invite.clone(),
                },
            ))
        };
        let first = join().await.unwrap().into_inner().session_id;
        let session_id = svc
            .db
            .get_user_session_pointer(&bob_id)
            .await
            .unwrap()
            .unwrap();
        svc.db.end_session(&session_id, &bob_id).await.unwrap();
        svc.db
            .age_session_member(&bob_id, schlift_core::session::SHOWN_FOR_SECONDS + 1)
            .await
            .unwrap();

        // Alice trained on in it: Bob scans her again and is back in it.
        let again = join().await.unwrap().into_inner().session_id;
        assert_eq!(again, first, "the same session");
        let bob_view = current_session(&svc.db, &bob_id).await.unwrap();
        assert_eq!(bob_view.session_id, first, "bob is in it");
        let alice_view = current_session(&svc.db, &alice_id).await.unwrap();
        let bob = alice_view
            .members
            .iter()
            .find(|m| m.user.as_ref().is_some_and(|u| u.id == bob_id))
            .expect("alice sees bob");
        assert_eq!(bob.ended_at, 0, "his old workout is not his status");
        assert!(bob.joined_at > now_unix() - 60, "joined now");
    }
}
