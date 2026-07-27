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

    /// JoinPartnerSession is gated on a prior pairing and joins the partner's
    /// current session for a one-tap re-pair.
    #[tokio::test]
    async fn join_partner_session_gates_then_rejoins() {
        let svc = setup().await;
        let (alice_id, alice_tok) = user(&svc, "alice").await;
        let (bob_id, bob_tok) = user(&svc, "bob").await;
        let (carol_id, carol_tok) = user(&svc, "carol").await;

        // Carol has never trained with Bob → cannot one-tap join him.
        let err = svc
            .join_partner_session(authed(
                &carol_tok,
                JoinPartnerSessionRequest {
                    partner_user_id: bob_id.clone(),
                },
            ))
            .await
            .unwrap_err();
        assert_eq!(err.code(), tonic::Code::FailedPrecondition);

        // Alice + Bob train together, then both leave (establishing the relationship).
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

        // Bob is not in any session now → re-pair fails cleanly.
        let err2 = svc
            .join_partner_session(authed(
                &alice_tok,
                JoinPartnerSessionRequest {
                    partner_user_id: bob_id.clone(),
                },
            ))
            .await
            .unwrap_err();
        assert_eq!(err2.code(), tonic::Code::FailedPrecondition);

        // Bob starts a fresh session (pairs with Carol).
        let carol_invite = svc.db.get_invite_token(&carol_id).await.unwrap().unwrap();
        svc.join_via_invite(authed(
            &bob_tok,
            JoinViaInviteRequest {
                invite_token: carol_invite,
            },
        ))
        .await
        .unwrap();
        let bob_session = svc
            .db
            .get_user_current_session(&bob_id)
            .await
            .unwrap()
            .unwrap();

        // Alice (a prior partner) one-tap joins Bob's current session.
        let resp = svc
            .join_partner_session(authed(
                &alice_tok,
                JoinPartnerSessionRequest {
                    partner_user_id: bob_id.clone(),
                },
            ))
            .await
            .unwrap()
            .into_inner();
        assert_eq!(resp.session_id, bob_session);
        assert_eq!(
            svc.db
                .get_user_current_session(&alice_id)
                .await
                .unwrap()
                .unwrap(),
            bob_session
        );
        // Carol didn't need to know Alice — Alice joined Bob's live session.
        let _ = carol_id;
    }
}
