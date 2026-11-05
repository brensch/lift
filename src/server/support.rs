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

/// The caller's session token, as sent.
pub(super) fn session_token<T>(request: &Request<T>) -> Option<&str> {
    request
        .metadata()
        .get("x-session-token")
        .and_then(|v| v.to_str().ok())
}

pub(super) async fn authed_user_id<T>(request: &Request<T>, db: &ServerDb) -> ServerResult<String> {
    check_app_version(request)?;
    let token = session_token(request).ok_or_else(|| {
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
/// handler calls it at the top. Being an admin is on the user's row
/// (`users.admin_since`), so a re-registered username never inherits it.
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

/// Answer a read from the user's account, through the core.
pub(super) async fn read_api<R: Send + 'static>(
    db: &ServerDb,
    user_id: &str,
    read: impl FnOnce(View) -> R + Send + 'static,
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

/// A user as someone else sees them: their body weight is theirs alone.
pub(super) fn as_seen_by_others(mut user: User) -> User {
    user.body_weight_kg = 0.0;
    user
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
