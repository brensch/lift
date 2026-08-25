use super::*;

pub(super) fn internal_error(error: impl std::fmt::Display) -> Status {
    Status::internal(error.to_string())
}

/// The version gate. When `MIN_APP_VERSION` is set (e.g. "1.2.0"), any
/// authed call from an app that sends an older `x-app-version` is rejected
/// with FAILED_PRECONDITION and the sentinel message `app_update_required`,
/// which the app renders as an update prompt. A missing header passes —
/// old apps that predate the header are the ones the gate cannot help, and
/// the deploy order (ship the header first, set the env second) handles
/// them.
#[allow(clippy::result_large_err)] // Status is what every handler returns
fn check_app_version<T>(request: &Request<T>) -> Result<(), Status> {
    let Ok(min) = std::env::var("MIN_APP_VERSION") else {
        return Ok(());
    };
    let Some(version) = request
        .metadata()
        .get("x-app-version")
        .and_then(|v| v.to_str().ok())
    else {
        return Ok(());
    };
    if version_below(version, &min) {
        tracing::warn!(rpc_auth = "app_too_old", %version, %min, "rejected old app");
        return Err(Status::failed_precondition("app_update_required"));
    }
    Ok(())
}

/// Dotted-numeric comparison: "1.9.2" < "1.10.0". Unparseable parts read
/// as 0, so a garbage header never locks anyone out.
fn version_below(version: &str, min: &str) -> bool {
    let parse = |s: &str| -> Vec<u64> {
        s.split('.')
            .map(|part| part.trim().parse::<u64>().unwrap_or(0))
            .collect()
    };
    let (v, m) = (parse(version), parse(min));
    for i in 0..v.len().max(m.len()) {
        let a = v.get(i).copied().unwrap_or(0);
        let b = m.get(i).copied().unwrap_or(0);
        if a != b {
            return a < b;
        }
    }
    false
}

pub(super) async fn authed_user_id<T>(
    request: &Request<T>,
    db: &ServerDb,
) -> Result<String, Status> {
    check_app_version(request)?;
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
            proposed_sets: Vec::new(),
            completed_sets: Vec::new(),
            next_up_set: None,
            rest_until: 0,
            has_active_set: false,
        }
    }
}

/// Write an updated participant snapshot for `user_id` into session `session_id`.
/// If `workout_id` is provided, the snapshot reflects that specific workout (used after
/// StartSet/CompleteSet/EndWorkout where the caller already knows the workout). Otherwise
/// the caller's active workout (if any) is used.
pub(super) async fn refresh_participant_for_user(
    db: &ServerDb,
    user_id: &str,
    session_id: &str,
    workout_id: Option<&str>,
) -> Result<(), Status> {
    let user = db
        .get_user(user_id)
        .await
        .map_err(internal_error)?
        .ok_or_else(|| Status::not_found("User not found"))?;
    let resolved_workout_id = match workout_id {
        Some(id) => Some(id.to_string()),
        None => db
            .get_active_workout_id(user_id)
            .await
            .map_err(internal_error)?,
    };
    let active = if let Some(id) = resolved_workout_id.as_deref() {
        db.load_workout_full(user_id, id)
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

#[cfg(test)]
mod version_gate_tests {
    use super::version_below;

    #[test]
    fn dotted_numeric_comparison() {
        assert!(version_below("1.9.2", "1.10.0"));
        assert!(version_below("0.9", "1.0.0"));
        assert!(!version_below("1.10.0", "1.10.0"));
        assert!(!version_below("2.0", "1.10.0"));
        // Garbage never locks anyone out below a real minimum of 0.
        assert!(!version_below("abc", "0.0.0"));
    }
}
