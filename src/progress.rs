use std::collections::HashSet;

use schlift::workout::v1::{CompletedSet, ParticipantStatus, ProposedSet};

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
#[path = "progress_tests.rs"]
mod tests;
