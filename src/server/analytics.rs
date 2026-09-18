use super::*;
use crate::db::ANALYTICS_RETENTION_DAYS;

// ── Analytics Service ──

const MAX_VIEWS_PER_BATCH: usize = 200;
const MAX_PAGE_LEN: usize = 96;
const MAX_SESSION_ID_LEN: usize = 64;
const MAX_DURATION_MS: i64 = 6 * 3600 * 1000;
/// Views whose client clock is further off than this are dropped rather than
/// filed under a day they did not happen on.
const MAX_CLOCK_SKEW_MS: i64 = 86_400 * 1000;
const MAX_VIEW_AGE_MS: i64 = 30 * 86_400 * 1000;
const TRAIL_LIMIT: i64 = 500;

fn is_slug(value: &str, max_len: usize) -> bool {
    !value.is_empty()
        && value.len() <= max_len
        && value
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, '/' | '-' | '_' | ':' | '.'))
}

/// Keeps the views worth storing: a slug for a page, a sane clock, a bounded
/// duration. Anything else is dropped silently — this is telemetry, and a bad
/// row should never turn into a client-visible error.
fn sanitize_views(views: Vec<PageView>, now_ms: i64) -> Vec<PageView> {
    views
        .into_iter()
        .take(MAX_VIEWS_PER_BATCH)
        .filter(|v| {
            is_slug(&v.page, MAX_PAGE_LEN) && is_slug(&v.app_session_id, MAX_SESSION_ID_LEN)
        })
        .filter(|v| {
            v.seq >= 0
                && v.entered_at_ms <= now_ms + MAX_CLOCK_SKEW_MS
                && v.entered_at_ms >= now_ms - MAX_VIEW_AGE_MS
        })
        .map(|mut v| {
            v.duration_ms = v.duration_ms.clamp(0, MAX_DURATION_MS);
            v
        })
        .collect()
}

#[derive(Clone)]
pub struct ServerAnalyticsService {
    pub db: ServerDb,
}

#[tonic::async_trait]
impl AnalyticsService for ServerAnalyticsService {
    async fn record_page_views(
        &self,
        request: Request<RecordPageViewsRequest>,
    ) -> Result<Response<RecordPageViewsResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let (platform, app_version) = client_labels(&request);
        let req = request.into_inner();
        info!(rpc = "RecordPageViews", %user_id, views = req.views.len(), "request");

        let views = sanitize_views(req.views, now_unix() * 1000);
        let accepted = self
            .db
            .record_page_views(&user_id, &platform, &app_version, &views)
            .await
            .map_err(internal_error)?;
        Ok(Response::new(RecordPageViewsResponse {
            accepted: accepted as i32,
        }))
    }
}

// ── Admin Service ──

#[derive(Clone)]
pub struct ServerAdminService {
    pub db: ServerDb,
}

#[tonic::async_trait]
impl AdminService for ServerAdminService {
    async fn get_admin_status(
        &self,
        request: Request<GetAdminStatusRequest>,
    ) -> Result<Response<GetAdminStatusResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let is_admin = self.db.is_admin(&user_id).await.map_err(internal_error)?;
        Ok(Response::new(GetAdminStatusResponse { is_admin }))
    }

    async fn get_stats(
        &self,
        request: Request<GetStatsRequest>,
    ) -> Result<Response<GetStatsResponse>, Status> {
        let admin_id = authed_admin_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "GetStats", %admin_id, days = req.days, "request");

        let days = match req.days {
            d if d <= 0 => 30,
            d => (d as i64).min(ANALYTICS_RETENTION_DAYS) as i32,
        };
        let since = now_unix() - days as i64 * 86_400;
        let since_ms = since * 1000;

        let trail = match req.trail_username.trim() {
            "" => Vec::new(),
            username => {
                let user = self
                    .db
                    .get_user_by_name(username)
                    .await
                    .map_err(internal_error)?
                    .ok_or_else(|| Status::not_found("User not found"))?;
                self.db
                    .user_trail(&user.id, TRAIL_LIMIT)
                    .await
                    .map_err(internal_error)?
            }
        };

        let auth_attempts = self
            .db
            .auth_attempt_stats(since)
            .await
            .map_err(internal_error)?;
        let new_users = auth_attempts
            .iter()
            .filter(|a| a.kind == "register" && a.outcome == "ok")
            .map(|a| a.count)
            .sum();

        Ok(Response::new(GetStatsResponse {
            days,
            pages: self.db.page_stats(since_ms).await.map_err(internal_error)?,
            daily: self
                .db
                .daily_stats(since_ms)
                .await
                .map_err(internal_error)?,
            auth_attempts,
            users: self
                .db
                .user_activity(since_ms)
                .await
                .map_err(internal_error)?,
            trail,
            total_users: self.db.total_users().await.map_err(internal_error)?,
            new_users,
        }))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    async fn temp_db() -> ServerDb {
        let dir = std::env::temp_dir().join(format!("lift-analytics-test-{}", Uuid::new_v4()));
        ServerDb::new_in_dir(&dir).await.unwrap()
    }

    fn authed<T>(message: T, token: &str) -> Request<T> {
        let mut request = Request::new(message);
        request
            .metadata_mut()
            .insert("x-session-token", token.parse().unwrap());
        request
    }

    fn view(seq: i32, page: &str, now_ms: i64) -> PageView {
        PageView {
            app_session_id: "session-1".to_string(),
            seq,
            page: page.to_string(),
            entered_at_ms: now_ms - 1000,
            duration_ms: 1500,
        }
    }

    #[test]
    fn sanitize_drops_junk_and_clamps_durations() {
        let now_ms = 1_800_000_000_000;
        let mut absurd = view(2, "/settings", now_ms);
        absurd.duration_ms = i64::MAX;
        let mut ancient = view(3, "/settings", now_ms);
        ancient.entered_at_ms = 5;
        let mut future = view(4, "/settings", now_ms);
        future.entered_at_ms = now_ms + 2 * MAX_CLOCK_SKEW_MS;

        let kept = sanitize_views(
            vec![
                view(1, "/exercise/:ex", now_ms),
                absurd,
                ancient,
                future,
                view(5, "not a slug; DROP TABLE", now_ms),
                view(6, &"x".repeat(MAX_PAGE_LEN + 1), now_ms),
                view(-1, "/settings", now_ms),
            ],
            now_ms,
        );

        assert_eq!(kept.iter().map(|v| v.seq).collect::<Vec<_>>(), vec![1, 2]);
        assert_eq!(kept[1].duration_ms, MAX_DURATION_MS);
    }

    #[test]
    fn sanitize_caps_the_batch() {
        let now_ms = 1_800_000_000_000;
        let views = (0..MAX_VIEWS_PER_BATCH as i32 + 50)
            .map(|seq| view(seq, "/", now_ms))
            .collect();
        assert_eq!(sanitize_views(views, now_ms).len(), MAX_VIEWS_PER_BATCH);
    }

    #[tokio::test]
    async fn page_views_require_a_session() {
        let service = ServerAnalyticsService {
            db: temp_db().await,
        };
        let err = service
            .record_page_views(Request::new(RecordPageViewsRequest::default()))
            .await
            .unwrap_err();
        assert_eq!(err.code(), tonic::Code::Unauthenticated);
    }

    #[tokio::test]
    async fn a_retried_batch_is_not_double_counted() {
        let db = temp_db().await;
        let (_, token) = db
            .get_or_create_user_with_auth_session("lifter")
            .await
            .unwrap();
        let service = ServerAnalyticsService { db: db.clone() };
        let now_ms = now_unix() * 1000;
        let batch = RecordPageViewsRequest {
            views: vec![view(1, "/", now_ms), view(2, "/settings", now_ms)],
        };

        let first = service
            .record_page_views(authed(batch.clone(), &token))
            .await
            .unwrap()
            .into_inner();
        let retry = service
            .record_page_views(authed(batch, &token))
            .await
            .unwrap()
            .into_inner();

        assert_eq!(first.accepted, 2);
        assert_eq!(retry.accepted, 0);
    }

    /// The gate that matters: a signed-in user who is not an admin must not be
    /// able to read anyone's trail.
    #[tokio::test]
    async fn stats_are_denied_to_non_admins() {
        let db = temp_db().await;
        let (_, token) = db
            .get_or_create_user_with_auth_session("lifter")
            .await
            .unwrap();
        let service = ServerAdminService { db };

        let err = service
            .get_stats(authed(GetStatsRequest::default(), &token))
            .await
            .unwrap_err();
        assert_eq!(err.code(), tonic::Code::PermissionDenied);

        let status = service
            .get_admin_status(authed(GetAdminStatusRequest::default(), &token))
            .await
            .unwrap()
            .into_inner();
        assert!(!status.is_admin);
    }

    #[tokio::test]
    async fn stats_are_denied_without_a_session() {
        let service = ServerAdminService {
            db: temp_db().await,
        };
        let err = service
            .get_stats(Request::new(GetStatsRequest::default()))
            .await
            .unwrap_err();
        assert_eq!(err.code(), tonic::Code::Unauthenticated);
    }

    #[tokio::test]
    async fn an_admin_sees_pages_and_a_trail() {
        let db = temp_db().await;
        let (_, admin_token) = db
            .get_or_create_user_with_auth_session("boss")
            .await
            .unwrap();
        let (_, user_token) = db
            .get_or_create_user_with_auth_session("lifter")
            .await
            .unwrap();
        assert!(db.grant_admin("Boss").await.unwrap().is_some());

        let now_ms = now_unix() * 1000;
        ServerAnalyticsService { db: db.clone() }
            .record_page_views(authed(
                RecordPageViewsRequest {
                    views: vec![
                        view(1, "/", now_ms),
                        view(2, "/settings", now_ms),
                        view(3, "/settings", now_ms),
                    ],
                },
                &user_token,
            ))
            .await
            .unwrap();

        let stats = ServerAdminService { db }
            .get_stats(authed(
                GetStatsRequest {
                    days: 7,
                    trail_username: "lifter".to_string(),
                },
                &admin_token,
            ))
            .await
            .unwrap()
            .into_inner();

        assert_eq!(stats.pages[0].page, "/settings");
        assert_eq!(stats.pages[0].views, 2);
        assert_eq!(stats.pages[0].unique_users, 1);
        assert_eq!(stats.trail.len(), 3);
        assert_eq!(stats.users[0].username, "lifter");
        assert_eq!(stats.total_users, 2);
    }

    /// Admin is keyed by user id, so it can neither be granted to a name
    /// nobody holds yet nor survive the account that held it.
    #[tokio::test]
    async fn admin_follows_the_account_not_the_name() {
        let db = temp_db().await;
        assert!(db.grant_admin("ghost").await.unwrap().is_none());

        let (original, _) = db
            .get_or_create_user_with_auth_session("boss")
            .await
            .unwrap();
        db.grant_admin("boss").await.unwrap();
        assert!(db.is_admin(&original.id).await.unwrap());

        db.delete_user_account_and_data(&original.id).await.unwrap();
        let (squatter, _) = db
            .get_or_create_user_with_auth_session("boss")
            .await
            .unwrap();

        assert_ne!(squatter.id, original.id);
        assert!(!db.is_admin(&squatter.id).await.unwrap());
        assert!(db.list_admins().await.unwrap().is_empty());
    }
}
