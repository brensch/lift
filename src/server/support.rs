use super::*;

pub(super) fn internal_error(error: impl std::fmt::Display) -> Status {
    Status::internal(error.to_string())
}

pub(super) async fn authed_user_id<T>(
    request: &Request<T>,
    db: &ServerDb,
) -> Result<String, Status> {
    let token = request
        .metadata()
        .get("x-session-token")
        .and_then(|v| v.to_str().ok())
        .ok_or_else(|| {
            tracing::warn!(rpc_auth = "missing_token", "auth failed: no session token");
            Status::unauthenticated("Missing session token")
        })?;
    db.validate_auth_session(token)
        .await
        .map_err(internal_error)?
        .ok_or_else(|| {
            tracing::warn!(
                rpc_auth = "invalid_token",
                "auth failed: invalid session token"
            );
            Status::unauthenticated("Invalid session token")
        })
}

pub(super) fn setting_type_key(setting: &UserSetting) -> Option<&'static str> {
    match &setting.setting {
        Some(user_setting::Setting::PlateColors(_)) => Some("plate_colors"),
        Some(user_setting::Setting::WeightUnit(_)) => Some("weight_unit"),
        None => None,
    }
}

pub(super) fn build_participant_status(
    user: User,
    workout_resp: Option<&GetWorkoutResponse>,
) -> ParticipantStatus {
    if let Some(resp) = workout_resp {
        let rest_until = resp
            .state_snapshot
            .as_ref()
            .map(|s| s.rest_until)
            .unwrap_or(0);
        let has_active_set = resp.completed_sets.iter().any(|set| set.ended_at == 0);
        ParticipantStatus {
            user: Some(user),
            active_workout_id: resp
                .workout
                .as_ref()
                .map(|w| w.id.clone())
                .unwrap_or_default(),
            active_workout: resp.workout.clone(),
            exercise_groups: resp.exercise_groups.clone(),
            proposed_sets: resp.proposed_sets.clone(),
            completed_sets: resp.completed_sets.clone(),
            next_up_set: resp.next_up_set.clone(),
            rest_until,
            has_active_set,
        }
    } else {
        ParticipantStatus {
            user: Some(user),
            active_workout_id: String::new(),
            active_workout: None,
            exercise_groups: Vec::new(),
            proposed_sets: Vec::new(),
            completed_sets: Vec::new(),
            next_up_set: None,
            rest_until: 0,
            has_active_set: false,
        }
    }
}

pub(super) async fn refresh_participant_for_user(
    db: &ServerDb,
    user_id: &str,
    session_id: &str,
) -> Result<(), Status> {
    let user = db
        .get_user(user_id)
        .await
        .map_err(internal_error)?
        .ok_or_else(|| Status::not_found("User not found"))?;
    let active = if let Some((workout_id, _)) = db
        .get_active_workout_id(user_id)
        .await
        .map_err(internal_error)?
    {
        db.load_workout_full(user_id, &workout_id)
            .await
            .map_err(internal_error)?
    } else {
        None
    };
    let participant = build_participant_status(user, active.as_ref());
    db.upsert_session_participant(session_id, user_id, &participant)
        .await
        .map_err(internal_error)
}
