    use super::*;
    use lift::workout::v1::{ParticipantStatus, User};

    fn proposed(id: &str, order: i32, group_id: &str, weight: f32) -> ProposedSet {
        ProposedSet {
            id: id.to_string(),
            workout_id: "w1".to_string(),
            workout_order: order,
            exercise: 1,
            target_reps: 5,
            target_weight: weight,
            warmup: false,
            exercise_group_id: group_id.to_string(),
            rest_after_success: 90,
            rest_after_failure: 180,
            cancelled: false,
            is_amrap: false,
            instruction: String::new(),
        }
    }

    fn completed(id: &str, proposed_set_id: &str, ended_at: i64, rest_until: i64) -> CompletedSet {
        CompletedSet {
            id: id.to_string(),
            workout_id: "w1".to_string(),
            proposed_set_id: proposed_set_id.to_string(),
            actual_reps: 5,
            actual_weight: 100.0,
            started_at: ended_at.saturating_sub(30),
            ended_at,
            rest_until,
        }
    }

    fn participant(
        user_id: &str,
        proposed_sets: Vec<ProposedSet>,
        completed_sets: Vec<CompletedSet>,
    ) -> ParticipantStatus {
        ParticipantStatus {
            user: Some(User {
                id: user_id.to_string(),
                name: user_id.to_string(),
                created_at: 0,
            }),
            active_workout_id: "w1".to_string(),
            active_workout: None,
            exercise_groups: vec![],
            proposed_sets,
            completed_sets,
            next_up_set: None,
            rest_until: 0,
            has_active_set: false,
        }
    }

    #[test]
    fn next_up_set_handles_mid_workout_weight_change_state() {
        let proposed_sets = vec![
            proposed("old-0", 0, "g1", 100.0),
            proposed("new-1", 1, "g1", 130.0),
            proposed("new-2", 2, "g1", 140.0),
            proposed("g2-0", 3, "g2", 185.0),
        ];
        let completed_sets = vec![completed("c1", "old-0", 100, 150)];

        let next =
            compute_next_up_set(&proposed_sets, &completed_sets).expect("next set should exist");
        assert_eq!(next.id, "new-1");
        assert_eq!(next.exercise_group_id, "g1");
        assert_eq!(next.target_weight, 130.0);
    }

    #[test]
    fn session_next_up_skips_active_lifter_and_prefers_ready_lifter() {
        let p1 = participant(
            "u1",
            vec![proposed("u1-s1", 0, "g1", 100.0)],
            vec![completed("a1", "u1-s1", 0, 0)],
        );
        let p2 = participant(
            "u2",
            vec![proposed("u2-s1", 0, "g1", 120.0)],
            vec![completed("u2-c1", "done", 90, 95)],
        );
        let p3 = participant(
            "u3",
            vec![proposed("u3-s1", 0, "g1", 140.0)],
            vec![completed("u3-c1", "done", 95, 120)],
        );

        let next =
            compute_session_next_up(&[p1, p2, p3], 100).expect("session next up should exist");
        assert_eq!(next.user_id, "u2");
        assert_eq!(next.next_up_set.id, "u2-s1");
    }
