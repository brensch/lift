use std::collections::HashSet;

use lift::workout::v1::{CompletedSet, ParticipantStatus, ProposedSet};

#[derive(Clone, Debug, PartialEq)]
pub struct ParticipantProgress {
    pub next_up_set: Option<ProposedSet>,
    pub rest_until: i64,
    pub has_active_set: bool,
}

#[derive(Clone, Debug, PartialEq)]
pub struct SessionNextUp {
    pub user_id: String,
    pub next_up_set: ProposedSet,
    pub rest_until: i64,
}

pub fn compute_next_up_set(
    proposed_sets: &[ProposedSet],
    completed_sets: &[CompletedSet],
) -> Option<ProposedSet> {
    let completed_ids: HashSet<&str> = completed_sets
        .iter()
        .filter(|set| set.ended_at != 0)
        .map(|set| set.proposed_set_id.as_str())
        .collect();

    let mut sorted = proposed_sets.to_vec();
    sorted.retain(|set| !set.cancelled);
    sorted.sort_by_key(|set| set.workout_order);
    sorted
        .into_iter()
        .find(|set| !completed_ids.contains(set.id.as_str()))
}

pub fn compute_latest_rest_until(completed_sets: &[CompletedSet]) -> i64 {
    completed_sets
        .iter()
        .filter(|set| set.ended_at != 0 && set.rest_until != 0)
        .max_by_key(|set| set.ended_at)
        .map(|set| set.rest_until)
        .unwrap_or(0)
}

pub fn compute_participant_progress(
    proposed_sets: &[ProposedSet],
    completed_sets: &[CompletedSet],
) -> ParticipantProgress {
    ParticipantProgress {
        next_up_set: compute_next_up_set(proposed_sets, completed_sets),
        rest_until: compute_latest_rest_until(completed_sets),
        has_active_set: completed_sets.iter().any(|set| set.ended_at == 0),
    }
}

pub fn compute_session_next_up(
    participants: &[ParticipantStatus],
    now_unix: i64,
) -> Option<SessionNextUp> {
    #[derive(Clone)]
    struct Candidate {
        user_id: String,
        next_up_set: ProposedSet,
        rest_until: i64,
        is_resting: bool,
        score: i64,
    }

    let mut candidates: Vec<Candidate> = participants
        .iter()
        .filter_map(|participant| {
            let user_id = participant
                .user
                .as_ref()
                .map(|u| u.id.clone())
                .unwrap_or_default();
            if user_id.is_empty() {
                return None;
            }

            let computed = compute_participant_progress(
                &participant.proposed_sets,
                &participant.completed_sets,
            );
            let has_active_set = participant.has_active_set || computed.has_active_set;
            if has_active_set {
                return None;
            }

            let next_up_set = participant.next_up_set.clone().or(computed.next_up_set)?;
            let rest_until = if participant.rest_until != 0 {
                participant.rest_until
            } else {
                computed.rest_until
            };
            let is_resting = rest_until > now_unix;
            let score = if is_resting {
                rest_until - now_unix
            } else {
                now_unix - rest_until
            };

            Some(Candidate {
                user_id,
                next_up_set,
                rest_until,
                is_resting,
                score,
            })
        })
        .collect();

    if candidates.is_empty() {
        return None;
    }

    candidates.sort_by(|a, b| {
        if !a.is_resting && b.is_resting {
            return std::cmp::Ordering::Less;
        }
        if a.is_resting && !b.is_resting {
            return std::cmp::Ordering::Greater;
        }
        if !a.is_resting && !b.is_resting {
            return b.score.cmp(&a.score).then(a.user_id.cmp(&b.user_id));
        }
        a.score.cmp(&b.score).then(a.user_id.cmp(&b.user_id))
    });

    let top = &candidates[0];
    Some(SessionNextUp {
        user_id: top.user_id.clone(),
        next_up_set: top.next_up_set.clone(),
        rest_until: top.rest_until,
    })
}

#[cfg(test)]
mod tests {
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
}
