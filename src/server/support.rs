use super::*;

/// Error for the hand-written helpers behind the RPC handlers.
///
/// tonic's `Status` is 176 bytes, so `Result<T, Status>` carries that on
/// every Ok path (clippy's `result_large_err`). Helpers return this boxed
/// form instead; `?` converts either way, so a helper can raise a `Status`
/// and a handler can propagate a `ServerError` unchanged.
#[derive(Debug)]
pub(super) struct ServerError(Box<Status>);

pub(super) type ServerResult<T> = Result<T, ServerError>;

impl From<Status> for ServerError {
    fn from(status: Status) -> Self {
        Self(Box::new(status))
    }
}

impl From<ServerError> for Status {
    fn from(error: ServerError) -> Self {
        *error.0
    }
}

pub(super) fn internal_error(error: impl std::fmt::Display) -> ServerError {
    Status::internal(error.to_string()).into()
}

/// The version gate. When `MIN_APP_VERSION` is set (e.g. "1.2.0"), any
/// authed call from an app that sends an older `x-app-version` is rejected
/// with FAILED_PRECONDITION and the sentinel message `app_update_required`,
/// which the app renders as an update prompt. A missing header passes —
/// old apps that predate the header are the ones the gate cannot help, and
/// the deploy order (ship the header first, set the env second) handles
/// them.
fn check_app_version<T>(request: &Request<T>) -> ServerResult<()> {
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
        return Err(Status::failed_precondition("app_update_required").into());
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

pub(super) async fn authed_user_id<T>(request: &Request<T>, db: &ServerDb) -> ServerResult<String> {
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
            Status::unauthenticated("Invalid session token").into()
        })
}

/// The admin gate. Like `authed_user_id` this is not middleware: every admin
/// handler calls it at the top. Admins are stored by user id (see the
/// `admins` table), so a re-registered username never inherits the grant.
pub(super) async fn authed_admin_id<T>(
    request: &Request<T>,
    db: &ServerDb,
) -> ServerResult<String> {
    let user_id = authed_user_id(request, db).await?;
    if !db.is_admin(&user_id).await.map_err(internal_error)? {
        tracing::warn!(rpc_auth = "not_admin", %user_id, "admin call from a non-admin");
        return Err(Status::permission_denied("admin only").into());
    }
    Ok(user_id)
}

/// (platform, app_version) as the client describes itself. Analytics labels
/// only — never trusted for anything. Bounded and restricted to a tame
/// charset because the auth RPCs store them from unauthenticated callers.
pub(super) fn client_labels<T>(request: &Request<T>) -> (String, String) {
    let header = |name: &str| -> String {
        request
            .metadata()
            .get(name)
            .and_then(|v| v.to_str().ok())
            .unwrap_or("")
            .chars()
            .filter(|c| c.is_ascii_alphanumeric() || matches!(c, '.' | '-' | '_' | '+'))
            .take(32)
            .collect()
    };
    let mut platform = header("x-platform");
    if platform.is_empty() && request.metadata().get("x-grpc-web").is_some() {
        platform = "web".to_string();
    }
    (platform, header("x-app-version"))
}

pub(super) fn build_participant_status(
    user: User,
    workout_resp: Option<&GetWorkoutResponse>,
) -> ParticipantStatus {
    if let Some(resp) = workout_resp {
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
            state_snapshot: resp.state_snapshot.clone(),
        }
    } else {
        ParticipantStatus {
            user: Some(user),
            active_workout_id: String::new(),
            active_workout: None,
            proposed_sets: Vec::new(),
            completed_sets: Vec::new(),
            next_up_set: None,
            state_snapshot: None,
        }
    }
}

/// Answer a read from the user's account, through the core.
pub(super) async fn read_api<R>(
    db: &ServerDb,
    user_id: &str,
    read: impl FnOnce(View) -> R,
) -> ServerResult<R> {
    db.read_account(user_id, |account| read(View::new(account, now_unix())))
        .await
        .map_err(internal_error)
}

pub(super) fn core_status(error: CoreError) -> Status {
    match error {
        CoreError::InvalidArgument(m) => Status::invalid_argument(m),
        CoreError::NotFound(m) => Status::not_found(m),
        CoreError::FailedPrecondition(m) => Status::failed_precondition(m),
    }
}

/// Where a user is up to, as their session partners see it: the workout under
/// way (or, with `workout_id`, that one — a just-finished workout stays on
/// show), from their synced account.
pub(super) async fn participant_status(
    db: &ServerDb,
    user_id: &str,
    workout_id: Option<&str>,
) -> ServerResult<ParticipantStatus> {
    let user = db
        .get_user(user_id)
        .await
        .map_err(internal_error)?
        .ok_or_else(|| Status::not_found("User not found"))?;
    let now = now_unix();
    let workout = db
        .read_account(user_id, |account| {
            let record = match workout_id {
                Some(id) => account.workout(id),
                None => account.active_workout(),
            };
            record.map(|r| get_workout_response_from_active(r, now))
        })
        .await
        .map_err(internal_error)?;
    Ok(build_participant_status(user, workout.as_ref()))
}

/// Write an updated participant snapshot for `user_id` into session `session_id`.
pub(super) async fn refresh_participant_for_user(
    db: &ServerDb,
    user_id: &str,
    session_id: &str,
    workout_id: Option<&str>,
) -> ServerResult<()> {
    let participant = participant_status(db, user_id, workout_id).await?;
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
