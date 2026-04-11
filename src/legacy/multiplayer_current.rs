use std::sync::Arc;

use tonic::Status;

use crate::db::CentralDb;
use crate::progress::{compute_participant_progress, compute_session_next_up};
use crate::state::AppState;
use schlift::workout::v1::{
    ParticipantStatus, ProposedSet, SessionStatus, SessionSubscriptionEvent, User,
};

pub fn build_participant_status_from_state(state: &AppState, user_id: &str) -> ParticipantStatus {
    let user = state
        .users
        .get(user_id)
        .map(|u| u.clone())
        .unwrap_or_else(|| User {
            id: user_id.to_string(),
            name: String::new(),
            created_at: 0,
        });

    if let Some(w) = state.workouts.get(user_id) {
        participant_status_from_active(&user, &w)
    } else {
        ParticipantStatus {
            user: Some(user),
            active_workout_id: String::new(),
            ..Default::default()
        }
    }
}

pub fn participant_status_from_active(
    user: &User,
    active: &crate::state::ActiveWorkout,
) -> ParticipantStatus {
    let proposed_sets: Vec<ProposedSet> = active
        .proposed_sets
        .iter()
        .filter(|set| !set.cancelled)
        .cloned()
        .collect();
    let progress = compute_participant_progress(&proposed_sets, &active.completed_sets);
    ParticipantStatus {
        user: Some(user.clone()),
        active_workout_id: active.workout.id.clone(),
        active_workout: Some(active.workout.clone()),
        exercise_groups: active.exercise_groups.clone(),
        proposed_sets,
        completed_sets: active.completed_sets.clone(),
        next_up_set: progress.next_up_set,
        rest_until: progress.rest_until,
        has_active_set: progress.has_active_set,
    }
}

fn current_lifting_user_id(participants: &[ParticipantStatus]) -> String {
    participants
        .iter()
        .filter_map(|participant| {
            if !participant.has_active_set {
                return None;
            }
            let started_at = participant
                .completed_sets
                .iter()
                .filter(|set| set.ended_at == 0)
                .map(|set| set.started_at)
                .max()
                .unwrap_or(0);
            let user_id = participant
                .user
                .as_ref()
                .map(|u| u.id.clone())
                .unwrap_or_default();
            Some((started_at, user_id))
        })
        .max_by_key(|(started_at, _)| *started_at)
        .map(|(_, user_id)| user_id)
        .unwrap_or_default()
}

fn build_session_status(session_id: &str, participants: Vec<ParticipantStatus>) -> SessionStatus {
    let now_unix = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0);
    let next_up = compute_session_next_up(&participants, now_unix);
    let currently_lifting_user_id = current_lifting_user_id(&participants);

    SessionStatus {
        session_id: session_id.to_string(),
        participants,
        next_up_user_id: next_up
            .as_ref()
            .map(|n| n.user_id.clone())
            .unwrap_or_default(),
        next_up_set: next_up.as_ref().map(|n| n.next_up_set.clone()),
        next_up_rest_until: next_up.as_ref().map(|n| n.rest_until).unwrap_or(0),
        currently_lifting_user_id,
    }
}

pub fn load_current_session_snapshot_from_state(
    state: &AppState,
    session_id: &str,
) -> Option<(i64, SessionStatus)> {
    let members = state.sessions.get(session_id)?;
    if members.is_empty() {
        return None;
    }

    let mut user_ids: Vec<String> = members.iter().cloned().collect();
    user_ids.sort();
    drop(members);

    let participants = user_ids
        .iter()
        .map(|user_id| build_participant_status_from_state(state, user_id))
        .collect();

    Some((
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs() as i64)
            .unwrap_or(0),
        build_session_status(session_id, participants),
    ))
}

pub async fn load_current_session_snapshot(
    central_db: &CentralDb,
    _state: &AppState,
    session_id: &str,
) -> Result<Option<(i64, SessionStatus)>, Status> {
    let persisted_rows = central_db
        .get_current_session_participants(session_id)
        .await
        .map_err(|e| Status::internal(e.to_string()))?;
    if persisted_rows.is_empty() {
        return Ok(None);
    }
    let participants: Vec<ParticipantStatus> =
        persisted_rows.into_iter().map(|row| row.status).collect();

    let version = central_db
        .get_latest_session_event_version(session_id)
        .await
        .map_err(|e| Status::internal(e.to_string()))?;

    Ok(Some((
        version,
        build_session_status(session_id, participants),
    )))
}

pub fn publish_current_session_snapshot_from_state(
    state: &Arc<AppState>,
    session_id: &str,
) -> Result<(), Status> {
    if let Some((version, session_status)) =
        load_current_session_snapshot_from_state(state, session_id)
    {
        state.publish_session_event(SessionSubscriptionEvent {
            session_id: session_id.to_string(),
            version,
            session_status: Some(session_status),
        });
    }
    Ok(())
}

pub async fn publish_current_session_snapshot(
    central_db: &CentralDb,
    state: &Arc<AppState>,
    session_id: &str,
) -> Result<(), Status> {
    if let Some((version, session_status)) =
        load_current_session_snapshot(central_db, state, session_id).await?
    {
        state.publish_session_event(SessionSubscriptionEvent {
            session_id: session_id.to_string(),
            version,
            session_status: Some(session_status),
        });
    }
    Ok(())
}

pub async fn sync_and_publish_user_session_state(
    central_db: &CentralDb,
    state: &Arc<AppState>,
    user_id: &str,
    event_kind: &str,
) -> Result<(), Status> {
    if !state.users.contains_key(user_id) {
        if let Ok(Some(user)) = central_db.get_user(user_id).await {
            state.users.insert(user_id.to_string(), user);
        }
    }

    let session_id = state
        .user_sessions
        .get(user_id)
        .map(|v| v.clone())
        .or(central_db
            .get_current_session_id_for_user(user_id)
            .await
            .map_err(|e| Status::internal(e.to_string()))?);

    let Some(session_id) = session_id else {
        return Ok(());
    };

    let status = build_participant_status_from_state(state, user_id);
    central_db
        .upsert_session_participant_current(&session_id, user_id, &status, event_kind)
        .await
        .map_err(|e| Status::internal(e.to_string()))?;
    publish_current_session_snapshot(central_db, state, &session_id).await
}

pub async fn remove_and_publish_user_session_state(
    central_db: &CentralDb,
    state: &Arc<AppState>,
    session_id: &str,
    user_id: &str,
    event_kind: &str,
) -> Result<(), Status> {
    central_db
        .remove_session_participant_current(session_id, user_id, event_kind)
        .await
        .map_err(|e| Status::internal(e.to_string()))?;
    publish_current_session_snapshot(central_db, state, session_id).await
}
