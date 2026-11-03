//! A session partner as the caller's phone shows them, folded from the
//! events of their workout (the Sync stream's PartnerEvents): never from
//! anything a server computed, and never kept.

use crate::account::Account;
use crate::api::View;
use crate::events::{Event, Fact};
use crate::pb::ParticipantStatus;

/// How long a partner stays on show after their workout ends, and how long
/// they can go without recording anything before they're off show (walked
/// off without ending, or joined and never started).
pub const SHOWN_FOR_SECONDS: i64 = 3 * 3600;

/// Whether a fact goes to the owner's session partners: what happens in a
/// workout, but not its heart rate, and nothing else of the account.
pub fn shared_with_partners(fact: &Fact) -> bool {
    match fact {
        Fact::WorkoutStarted(_) => true,
        Fact::HeartRateRecorded(_) => false,
        fact => fact.workout_id().is_some(),
    }
}

/// Where a partner is up to: the workout under way, or else the last one to
/// end since they joined, as their own phone shows it. A partner on show
/// with no such workout has an empty status (the caller adds who they are);
/// None once they're off show. `events` are what came from their account,
/// in order; `joined_at` and `ended_at` are from the session.
pub fn partner_status(
    events: &[Event],
    joined_at: i64,
    ended_at: i64,
    now: i64,
) -> Option<ParticipantStatus> {
    let last_seen = events.last().map_or(joined_at, |e| e.at.max(joined_at));
    let gone = |since: i64| since > 0 && now - since > SHOWN_FOR_SECONDS;
    if gone(ended_at) || gone(last_seen) {
        return None;
    }
    let account = Account::fold_without_heart_rate(events);
    let id = match account.active_workout() {
        Some(active) => Some(active.workout.id.clone()),
        None => account
            .workouts
            .iter()
            .filter(|r| r.workout.end_time >= joined_at)
            .max_by_key(|r| r.workout.end_time)
            .map(|r| r.workout.id.clone()),
    };
    let Some(workout) = id.and_then(|id| View::new(&account, now).workout_response(&id).ok())
    else {
        return Some(ParticipantStatus::default());
    };
    Some(ParticipantStatus {
        user: None,
        active_workout_id: workout
            .workout
            .as_ref()
            .map(|w| w.id.clone())
            .unwrap_or_default(),
        active_workout: workout.workout,
        proposed_sets: workout.proposed_sets,
        completed_sets: workout.completed_sets,
        next_up_set: workout.next_up_set,
        state_snapshot: workout.state_snapshot,
        passed_warmup_ids: workout.passed_warmup_ids,
        first_time_set_ids: workout.first_time_set_ids,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::Call;
    use crate::pb::{
        workout_mutation::Mutation, AppendWorkoutMutationsRequest, CompleteOnboardingRequest,
        CompleteSetRequest, EndWorkoutRequest, StartSetRequest, StartWorkoutRequest, WeightUnit,
        WorkoutMutation,
    };

    const NOW: i64 = 1_800_000_000;

    /// An onboarded account in `unit` that started its first template and
    /// did one set, and every event it recorded.
    fn training(unit: WeightUnit) -> (Account, String, Vec<Event>) {
        let mut account = Account::default();
        let mut events = Vec::new();
        let mut call = Call::new(&mut account, NOW - 600, "onboard");
        call.complete_onboarding(CompleteOnboardingRequest {
            unit: unit as i32,
            strength: Some(0.3),
            ..Default::default()
        })
        .unwrap();
        events.append(&mut call.events);
        let template_id = account.templates[0].id.clone();
        let mut call = Call::new(&mut account, NOW - 300, "start");
        let started = call
            .start_workout(StartWorkoutRequest {
                template_id,
                ..Default::default()
            })
            .unwrap();
        let set = started.next_up_set.clone().unwrap();
        for mutation in [
            Mutation::StartSet(StartSetRequest {
                workout_id: started.id.clone(),
                proposed_set_id: set.id.clone(),
                started_at: NOW - 200,
            }),
            Mutation::CompleteSet(CompleteSetRequest {
                workout_id: started.id.clone(),
                proposed_set_id: set.id.clone(),
                actual_reps: set.target_reps,
                actual_weight: set.target_weight,
                completed_at: NOW - 160,
            }),
        ] {
            call.append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![WorkoutMutation {
                    mutation: Some(mutation),
                }],
            })
            .unwrap();
        }
        events.append(&mut call.events);
        (account, started.id, events)
    }

    fn shared(events: &[Event]) -> Vec<Event> {
        events
            .iter()
            .filter(|e| shared_with_partners(&e.fact))
            .cloned()
            .collect()
    }

    #[test]
    fn a_partner_sees_the_workout_as_its_owner_does() {
        for unit in [WeightUnit::Lb, WeightUnit::Kg] {
            let (account, id, events) = training(unit);
            let own = View::new(&account, NOW).workout_response(&id).unwrap();
            let seen = partner_status(&shared(&events), NOW - 400, 0, NOW).unwrap();
            assert_eq!(seen.active_workout_id, id);
            assert_eq!(seen.active_workout, own.workout, "{unit:?}");
            assert_eq!(seen.proposed_sets, own.proposed_sets, "{unit:?}");
            assert_eq!(seen.completed_sets, own.completed_sets);
            assert_eq!(seen.next_up_set, own.next_up_set);
            assert_eq!(seen.state_snapshot, own.state_snapshot);
            assert_eq!(seen.active_workout.unwrap().name, account.templates[0].name);
        }
    }

    #[test]
    fn only_the_workout_is_shared() {
        let (_, _, events) = training(WeightUnit::Kg);
        let names: Vec<String> = shared(&events)
            .iter()
            .map(|e| serde_json::to_value(&e.fact).unwrap())
            .map(|v| v.as_object().unwrap().keys().next().unwrap().clone())
            .collect();
        assert_eq!(names, ["WorkoutStarted", "SetStarted", "SetCompleted"]);
    }

    #[test]
    fn a_partner_goes_off_show() {
        let (mut account, id, mut events) = training(WeightUnit::Lb);
        let mut call = Call::new(&mut account, NOW - 100, "end");
        call.end_workout(EndWorkoutRequest {
            workout_id: id.clone(),
            ended_at: NOW - 100,
        })
        .unwrap();
        events.append(&mut call.events);
        let events = shared(&events);
        // A finished workout stays on show a while, ended.
        let seen = partner_status(&events, NOW - 400, NOW - 100, NOW).unwrap();
        assert_eq!(seen.active_workout_id, id);
        assert_ne!(seen.active_workout.unwrap().end_time, 0);
        let later = NOW - 100 + SHOWN_FOR_SECONDS + 1;
        assert_eq!(partner_status(&events, NOW - 400, NOW - 100, later), None);
        // Joined after it ended: on show, but with nothing to show.
        let fresh = partner_status(&events, NOW - 50, 0, NOW).unwrap();
        assert!(fresh.active_workout.is_none());
        // Joined and never did anything: off show once idle.
        let idle = NOW + SHOWN_FOR_SECONDS + 1;
        assert_eq!(partner_status(&[], NOW, 0, idle), None);
    }
}
