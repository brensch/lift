use super::*;
use crate::db::{AccountRow, Approval, Recovery, MAX_STATS_WINDOW_DAYS};
use futures_util::StreamExt;
use std::collections::{BTreeMap, HashMap, HashSet};

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
/// The most workouts one training answer lists; the counts cover them all.
const MAX_WORKOUTS_LISTED: usize = 500;
/// The workouts shown of the account a recovery asks for.
const RECENT_WORKOUTS_SHOWN: usize = 8;
/// Accounts folded at once for a training answer.
const FOLDS_AT_ONCE: usize = 8;

/// The look-back window asked for, in days: 30 unless said, a year at most.
fn window_days(days: i32) -> i32 {
    match days {
        d if d <= 0 => 30,
        d => (d as i64).min(MAX_STATS_WINDOW_DAYS) as i32,
    }
}

/// An account's training, folded from its events for one answer.
#[derive(Default)]
struct Training {
    /// Finished workouts, newest first.
    workouts: Vec<WorkoutWithSummary>,
    lifting_now: bool,
}

/// Everyone's accounts and training as the admin page shows them.
fn training_stats(
    accounts: Vec<(AccountRow, Training)>,
    together: &HashSet<String>,
    days: i32,
    since: i64,
) -> GetTrainingStatsResponse {
    let mut response = GetTrainingStatsResponse {
        days,
        ..Default::default()
    };
    // Per UTC day: workouts started, and who started them.
    let mut daily: BTreeMap<i64, (i64, HashSet<String>)> = BTreeMap::new();
    // Per exercise: sets, volume, and who did it.
    let mut exercises: HashMap<i32, (i64, f64, HashSet<String>)> = HashMap::new();

    for (row, training) in accounts {
        let mut user = AdminUser {
            username: row.username.clone(),
            created_at: row.created_at,
            last_seen_ms: row.last_seen_ms,
            platform: row.platform,
            app_version: row.app_version,
            passkeys: row.passkeys,
            logins: row.logins,
            events: row.events,
            is_admin: row.is_admin,
            lifting_now: training.lifting_now,
            ..Default::default()
        };
        for entry in &training.workouts {
            let (Some(workout), Some(summary)) = (&entry.workout, &entry.summary) else {
                continue;
            };
            user.workouts += 1;
            user.volume_lb += summary.total_volume as f64;
            user.last_workout_at = user.last_workout_at.max(workout.start_time);
            response.workouts_total += 1;
            if workout.start_time < since {
                continue;
            }
            user.workouts_in_window += 1;
            response.workouts_in_window += 1;
            response.volume_lb_in_window += summary.total_volume as f64;
            let day = daily
                .entry(workout.start_time.div_euclid(86_400))
                .or_default();
            day.0 += 1;
            day.1.insert(row.user_id.clone());
            for exercise in &summary.exercises {
                let used = exercises.entry(exercise.exercise).or_default();
                used.0 += exercise.total_sets as i64;
                used.1 += exercise.total_volume as f64;
                used.2.insert(row.user_id.clone());
            }
            response.workouts.push(AdminWorkout {
                username: row.username.clone(),
                name: workout.name.clone(),
                start_time: workout.start_time,
                duration_seconds: summary.duration_seconds,
                volume_lb: summary.total_volume as f64,
                sets: summary.exercises.iter().map(|e| e.total_sets).sum(),
                exercises: summary.exercises.len() as i32,
                together: together.contains(&workout.id),
            });
        }
        if user.workouts_in_window > 0 {
            response.lifters_in_window += 1;
        }
        response.users.push(user);
    }

    response.users.sort_by(|a, b| {
        (b.last_seen_ms, b.created_at)
            .cmp(&(a.last_seen_ms, a.created_at))
            .then_with(|| a.username.cmp(&b.username))
    });
    response.workouts.sort_by(|a, b| {
        b.start_time
            .cmp(&a.start_time)
            .then_with(|| a.username.cmp(&b.username))
    });
    response.workouts.truncate(MAX_WORKOUTS_LISTED);
    response.daily = daily
        .into_iter()
        .map(|(epoch_day, (workouts, lifters))| TrainingDay {
            epoch_day,
            workouts,
            lifters: lifters.len() as i64,
        })
        .collect();
    response.exercises = exercises
        .into_iter()
        .map(|(exercise, (sets, volume_lb, lifters))| ExerciseUse {
            exercise,
            sets,
            lifters: lifters.len() as i64,
            volume_lb,
        })
        .collect();
    response.exercises.sort_by(|a, b| {
        b.sets
            .cmp(&a.sets)
            .then_with(|| a.exercise.cmp(&b.exercise))
    });
    response
}

/// A request to get into an account, as an admin is shown it: never its code.
fn recovery_request(recovery: Recovery) -> RecoveryRequest {
    RecoveryRequest {
        no_account: recovery.user_id.is_none(),
        request_id: recovery.request_id,
        username: recovery.username,
        created_at: recovery.created_at,
        platform: recovery.platform,
        created_ip: recovery.created_ip,
        passkeys: recovery.passkeys,
        logins: recovery.logins,
        last_seen_ms: recovery.last_seen_ms,
        status: recovery.status,
        decided_at: recovery.decided_at,
    }
}

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

        let days = window_days(req.days);
        let since = now_unix() - days as i64 * 86_400;
        let since_ms = since * 1000;

        // A trail link can outlive its user (a deleted account): an unknown
        // name is an empty trail, not a failed page.
        let trail_user = match req.trail_username.trim() {
            "" => None,
            username => self
                .db
                .get_user_by_name(username)
                .await
                .map_err(internal_error)?,
        };
        let trail = match trail_user {
            Some(user) => self
                .db
                .user_trail(&user.id, TRAIL_LIMIT)
                .await
                .map_err(internal_error)?,
            None => Vec::new(),
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
            active_users: self
                .db
                .active_users(since_ms)
                .await
                .map_err(internal_error)?,
            total_users: self.db.total_users().await.map_err(internal_error)?,
            new_users,
        }))
    }

    /// Everyone's accounts and finished workouts. The server keeps no
    /// folded account: each is folded from its events here, for this
    /// answer, and dropped.
    async fn get_training_stats(
        &self,
        request: Request<GetTrainingStatsRequest>,
    ) -> Result<Response<GetTrainingStatsResponse>, Status> {
        let admin_id = authed_admin_id(&request, &self.db).await?;
        let days = window_days(request.into_inner().days);
        info!(rpc = "GetTrainingStats", %admin_id, days, "request");
        let now = now_unix();

        let rows = self.db.account_rows().await.map_err(internal_error)?;
        let together = self
            .db
            .workouts_done_together()
            .await
            .map_err(internal_error)?;
        let accounts: Vec<(AccountRow, Training)> = futures_util::stream::iter(rows)
            .map(|row| async move {
                let folded = self
                    .db
                    .read_account(&row.user_id, move |account| Training {
                        workouts: View::new(account, now).list_workout_summaries().workouts,
                        lifting_now: account.active_workout().is_some(),
                    })
                    .await;
                // One account that won't fold is shown without its
                // training, not the page without everyone's.
                let training = folded.unwrap_or_else(|error| {
                    tracing::warn!(user_id = %row.user_id, %error, "account did not fold for stats");
                    Training::default()
                });
                (row, training)
            })
            .buffered(FOLDS_AT_ONCE)
            .collect()
            .await;

        Ok(Response::new(training_stats(
            accounts,
            &together,
            days,
            now - days as i64 * 86_400,
        )))
    }

    async fn list_recoveries(
        &self,
        request: Request<ListRecoveriesRequest>,
    ) -> Result<Response<ListRecoveriesResponse>, Status> {
        let admin_id = authed_admin_id(&request, &self.db).await?;
        info!(rpc = "ListRecoveries", %admin_id, "request");
        let recoveries = self
            .db
            .list_recoveries()
            .await
            .map_err(internal_error)?
            .into_iter()
            .map(recovery_request)
            .collect();
        Ok(Response::new(ListRecoveriesResponse { recoveries }))
    }

    /// The waiting request a code belongs to, with the account it asks
    /// for laid out: what its owner would know and a stranger would not,
    /// for the admin to ask about before approving.
    async fn get_recovery(
        &self,
        request: Request<GetRecoveryRequest>,
    ) -> Result<Response<GetRecoveryResponse>, Status> {
        let admin_id = authed_admin_id(&request, &self.db).await?;
        let code = request.into_inner().code;
        let nothing = || Status::not_found("No waiting request has that code.");
        let recovery = self
            .db
            .recovery_by_code(&code)
            .await
            .map_err(internal_error)?
            .ok_or_else(nothing)?;
        info!(rpc = "GetRecovery", %admin_id, username = %recovery.username, "request");
        // For a username nobody holds there is no account to read: the
        // admin is shown the request, to say the name is wrong.
        let Some(user_id) = recovery.user_id.clone() else {
            return Ok(Response::new(GetRecoveryResponse {
                recovery: Some(recovery_request(recovery)),
                account: None,
            }));
        };
        let user = self
            .db
            .get_user(&user_id)
            .await
            .map_err(internal_error)?
            .ok_or_else(nothing)?;
        let row = self
            .db
            .account_row(&user_id)
            .await
            .map_err(internal_error)?
            .ok_or_else(nothing)?;

        let now = now_unix();
        let (training, templates) = self
            .db
            .read_account(&user_id, move |account| {
                let training = Training {
                    workouts: View::new(account, now).list_workout_summaries().workouts,
                    lifting_now: account.active_workout().is_some(),
                };
                let templates = account.templates.iter().map(|t| t.name.clone()).collect();
                (training, templates)
            })
            .await
            .map_err(internal_error)?;
        let together = self
            .db
            .workouts_done_together()
            .await
            .map_err(internal_error)?;
        // The one account's training, all of it: the window is all time.
        let mut stats = training_stats(vec![(row, training)], &together, 0, 0);
        stats.workouts.truncate(RECENT_WORKOUTS_SHOWN);

        let mut partners = Vec::new();
        for (partner_id, sessions_together, last_trained_at) in self
            .db
            .list_training_partners(&user_id)
            .await
            .map_err(internal_error)?
        {
            if let Some(partner) = self
                .db
                .get_user(&partner_id)
                .await
                .map_err(internal_error)?
            {
                partners.push(AdminPartner {
                    username: partner.name,
                    sessions_together: sessions_together as i32,
                    last_trained_at,
                });
            }
        }
        partners.sort_by_key(|a| std::cmp::Reverse(a.sessions_together));

        let passkeys = self
            .db
            .list_passkey_metadata(&user_id)
            .await
            .map_err(internal_error)?
            .into_iter()
            .map(|(_, created_at, json, created_ip)| {
                let value: serde_json::Value =
                    serde_json::from_str(&json).unwrap_or(serde_json::Value::Null);
                let strings = |key: &str| -> Vec<String> {
                    value
                        .get(key)
                        .and_then(|t| t.as_array())
                        .map(|items| {
                            items
                                .iter()
                                .filter_map(|item| item.as_str().map(str::to_string))
                                .collect()
                        })
                        .unwrap_or_default()
                };
                AdminPasskey {
                    name: value
                        .get("cred_name")
                        .and_then(|n| n.as_str())
                        .unwrap_or_default()
                        .to_string(),
                    created_at,
                    created_ip: created_ip.unwrap_or_default(),
                    transports: strings("transports"),
                }
            })
            .collect();

        Ok(Response::new(GetRecoveryResponse {
            account: Some(RecoveryAccount {
                user: stats.users.pop(),
                emoji: user.profile_emoji,
                color_hex: user.profile_color_hex,
                body_weight_kg: user.body_weight_kg as f64,
                last_active_at: self
                    .db
                    .last_login_use(&user_id)
                    .await
                    .map_err(internal_error)?,
                passkeys,
                partners,
                templates,
                recent_workouts: stats.workouts,
                lifts: stats.exercises,
            }),
            recovery: Some(recovery_request(recovery)),
        }))
    }

    /// Approve the request whose code the admin was sent, or refuse one.
    /// Approving is by code and nothing else: the list an admin reads never
    /// shows codes, so the request approved is the one whose maker got
    /// their code to the admin.
    async fn decide_recovery(
        &self,
        request: Request<DecideRecoveryRequest>,
    ) -> Result<Response<DecideRecoveryResponse>, Status> {
        use decide_recovery_request::Request as Decision;
        let admin_id = authed_admin_id(&request, &self.db).await?;
        let req = request.into_inner();
        let recovery = match req.request {
            Some(Decision::ApproveCode(code)) => {
                match self
                    .db
                    .approve_recovery(&code, req.remove_other_passkeys)
                    .await
                    .map_err(internal_error)?
                {
                    Approval::Approved(recovery) => recovery,
                    Approval::NoSuchCode => {
                        info!(rpc = "DecideRecovery", %admin_id, "no waiting request has the code");
                        return Err(Status::not_found("No waiting request has that code."));
                    }
                    Approval::NoSuchAccount => {
                        return Err(Status::failed_precondition(
                            "Nobody has that username: there is no account to let them into.",
                        ));
                    }
                    Approval::AlreadyRegistered => {
                        return Err(Status::already_exists(
                            "That passkey has been registered since.",
                        ));
                    }
                }
            }
            Some(Decision::DenyRequestId(request_id)) => self
                .db
                .deny_recovery(&request_id, None)
                .await
                .map_err(internal_error)?
                .ok_or_else(|| Status::not_found("That request is not waiting."))?,
            None => return Err(Status::invalid_argument("approve a code or deny a request")),
        };
        info!(
            rpc = "DecideRecovery",
            %admin_id,
            username = %recovery.username,
            request_id = %recovery.request_id,
            status = %recovery.status,
            removed_other_passkeys = req.remove_other_passkeys,
            "decided"
        );
        Ok(Response::new(DecideRecoveryResponse {
            recovery: Some(recovery_request(recovery)),
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
        assert_eq!(stats.active_users, 1, "the admin opened nothing");
    }

    /// The user list stops at 200; the active-user count does not.
    #[tokio::test]
    async fn active_users_count_past_the_listed_users() {
        let db = temp_db().await;
        let (_, admin_token) = db
            .get_or_create_user_with_auth_session("boss")
            .await
            .unwrap();
        db.grant_admin("boss").await.unwrap();
        let now_ms = now_unix() * 1000;
        for n in 0..201 {
            let (user, _) = db
                .get_or_create_user_with_auth_session(&format!("lifter{n}"))
                .await
                .unwrap();
            db.record_page_views(&user.id, "android", "1.0.0", &[view(1, "/", now_ms)])
                .await
                .unwrap();
        }

        let stats = ServerAdminService { db }
            .get_stats(authed(GetStatsRequest::default(), &admin_token))
            .await
            .unwrap()
            .into_inner();

        assert_eq!(stats.users.len(), 200);
        assert_eq!(stats.active_users, 201);
    }

    /// A linked trail can name an account that has since been deleted: the
    /// stats still come back, with an empty trail.
    #[tokio::test]
    async fn a_trail_for_a_deleted_user_is_empty_not_an_error() {
        let db = temp_db().await;
        let (_, admin_token) = db
            .get_or_create_user_with_auth_session("boss")
            .await
            .unwrap();
        db.grant_admin("boss").await.unwrap();
        let (gone, _) = db
            .get_or_create_user_with_auth_session("lifter")
            .await
            .unwrap();
        db.delete_user_account_and_data(&gone.id).await.unwrap();

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

        assert!(stats.trail.is_empty());
        assert_eq!(stats.total_users, 1);
    }

    fn account(user_id: &str, last_seen_ms: i64) -> AccountRow {
        AccountRow {
            user_id: user_id.to_string(),
            username: user_id.to_string(),
            created_at: 0,
            is_admin: false,
            passkeys: 1,
            logins: 1,
            last_seen_ms,
            platform: "ios".to_string(),
            app_version: "1.0.0".to_string(),
            events: 10,
        }
    }

    fn workout(id: &str, start_time: i64, sets: i32, volume: f32) -> WorkoutWithSummary {
        WorkoutWithSummary {
            workout: Some(Workout {
                id: id.to_string(),
                name: "Legs".to_string(),
                start_time,
                end_time: start_time + 3_600,
                ..Default::default()
            }),
            summary: Some(WorkoutSummary {
                total_volume: volume,
                duration_seconds: 3_600,
                exercises: vec![ExerciseSummary {
                    exercise: Exercise::Squat as i32,
                    total_sets: sets,
                    total_volume: volume,
                    ..Default::default()
                }],
                ..Default::default()
            }),
        }
    }

    #[test]
    fn training_is_counted_per_user_day_and_exercise_inside_the_window() {
        let day = 86_400;
        let since = 100 * day;
        let ann = Training {
            // Newest first, as the core lists them: two inside the window
            // on one day, one before it.
            workouts: vec![
                workout("a3", 101 * day + 7_200, 3, 300.0),
                workout("a2", 101 * day, 2, 200.0),
                workout("a1", 50 * day, 5, 500.0),
            ],
            lifting_now: true,
        };
        let ben = Training {
            workouts: vec![workout("b1", 102 * day, 4, 400.0)],
            lifting_now: false,
        };
        let together = HashSet::from(["a2".to_string()]);
        let stats = training_stats(
            vec![
                (account("ann", 5), ann),
                (account("ben", 9), ben),
                (account("cat", 0), Training::default()),
            ],
            &together,
            30,
            since,
        );

        // Most recently seen first; someone who never trained is still listed.
        let names: Vec<&str> = stats.users.iter().map(|u| u.username.as_str()).collect();
        assert_eq!(names, ["ben", "ann", "cat"]);
        let ann = &stats.users[1];
        assert_eq!((ann.workouts, ann.workouts_in_window), (3, 2));
        assert_eq!(ann.volume_lb, 1_000.0);
        assert_eq!(ann.last_workout_at, 101 * day + 7_200);
        assert!(ann.lifting_now);

        assert_eq!(stats.workouts_total, 4);
        assert_eq!(stats.workouts_in_window, 3);
        assert_eq!(stats.lifters_in_window, 2);
        assert_eq!(stats.volume_lb_in_window, 900.0);
        let listed: Vec<(&str, bool)> = stats
            .workouts
            .iter()
            .map(|w| (w.username.as_str(), w.together))
            .collect();
        assert_eq!(listed, [("ben", false), ("ann", false), ("ann", true)]);
        assert_eq!(stats.workouts[0].sets, 4);
        let days: Vec<(i64, i64, i64)> = stats
            .daily
            .iter()
            .map(|d| (d.epoch_day, d.workouts, d.lifters))
            .collect();
        assert_eq!(days, [(101, 2, 1), (102, 1, 1)]);
        assert_eq!(stats.exercises.len(), 1);
        assert_eq!(stats.exercises[0].sets, 9);
        assert_eq!(stats.exercises[0].lifters, 2);
    }

    /// The admin pages are for admins; and they read an account's training
    /// out of its events.
    #[tokio::test]
    async fn only_an_admin_reads_everyones_training_and_decides_recoveries() {
        use schlift_core::account::Account;
        use schlift_core::api::Call;

        let db = temp_db().await;
        let (_, admin_token) = db
            .get_or_create_user_with_auth_session("boss")
            .await
            .unwrap();
        db.grant_admin("boss").await.unwrap();
        let (lifter, lifter_token) = db
            .get_or_create_user_with_auth_session("lifter")
            .await
            .unwrap();

        // A workout started and ended on the lifter's phone, then synced.
        let now = now_unix();
        let mut phone = Account::default();
        let mut events = Vec::new();
        let mut write = |at: i64, f: &mut dyn FnMut(&mut Call)| {
            let mut call = Call::new(&mut phone, at, Uuid::new_v4().to_string());
            f(&mut call);
            events.append(&mut call.events);
        };
        let mut workout_id = String::new();
        write(now - 3_600, &mut |call| {
            let started = call
                .start_workout(StartWorkoutRequest {
                    exercises: vec![Exercise::PullUp as i32],
                    ..Default::default()
                })
                .unwrap();
            workout_id = started.id;
        });
        write(now - 60, &mut |call| {
            call.end_workout(EndWorkoutRequest {
                workout_id: workout_id.clone(),
                ..Default::default()
            })
            .unwrap();
        });
        db.push_events(&lifter.id, events).await.unwrap();

        let admin = ServerAdminService { db: db.clone() };
        let refused = admin
            .get_training_stats(authed(GetTrainingStatsRequest::default(), &lifter_token))
            .await;
        assert_eq!(refused.unwrap_err().code(), tonic::Code::PermissionDenied);
        let refused = admin
            .list_recoveries(authed(ListRecoveriesRequest {}, &lifter_token))
            .await;
        assert_eq!(refused.unwrap_err().code(), tonic::Code::PermissionDenied);
        let refused = admin
            .decide_recovery(authed(DecideRecoveryRequest::default(), &lifter_token))
            .await;
        assert_eq!(refused.unwrap_err().code(), tonic::Code::PermissionDenied);

        let stats = admin
            .get_training_stats(authed(GetTrainingStatsRequest::default(), &admin_token))
            .await
            .unwrap()
            .into_inner();
        assert_eq!(stats.days, 30);
        assert_eq!(stats.users.len(), 2);
        let listed = stats.users.iter().find(|u| u.username == "lifter").unwrap();
        assert_eq!(listed.workouts, 1);
        assert_eq!(listed.logins, 1);
        assert!(listed.events > 0);
        assert!(!listed.lifting_now);
        assert_eq!(stats.workouts.len(), 1);
        assert_eq!(stats.workouts[0].username, "lifter");

        // A request is listed without its code, approved by it, and
        // refused by its id.
        let (code, _) = db
            .store_recovery(crate::db::Held::of(
                "r1",
                Some(&lifter.id),
                "lifter",
                "cred-1",
            ))
            .await
            .unwrap()
            .unwrap();
        db.store_recovery(crate::db::Held::of(
            "r2",
            Some(&lifter.id),
            "lifter",
            "cred-2",
        ))
        .await
        .unwrap()
        .unwrap();
        let listed = admin
            .list_recoveries(authed(ListRecoveriesRequest {}, &admin_token))
            .await
            .unwrap()
            .into_inner()
            .recoveries;
        assert_eq!(listed.len(), 2);
        assert!(listed.iter().all(|r| r.status == "pending"));

        // The code opens the account it asks for, to question its maker on.
        let look = |code: &str, token: &str| {
            admin.get_recovery(authed(
                GetRecoveryRequest {
                    code: code.to_string(),
                },
                token,
            ))
        };
        let refused = look(&code, &lifter_token).await;
        assert_eq!(refused.unwrap_err().code(), tonic::Code::PermissionDenied);
        let unknown = look("NOPE-NOPE", &admin_token).await;
        assert_eq!(unknown.unwrap_err().code(), tonic::Code::NotFound);
        let opened = look(&code.to_lowercase(), &admin_token)
            .await
            .unwrap()
            .into_inner();
        assert_eq!(opened.recovery.unwrap().request_id, "r1");
        let account = opened.account.unwrap();
        let user = account.user.unwrap();
        assert_eq!(user.username, "lifter");
        assert_eq!(user.workouts, 1);
        assert_eq!(account.recent_workouts.len(), 1);
        assert!(!account.emoji.is_empty());
        assert!(account.last_active_at > 0, "the lifter is signed in");

        use decide_recovery_request::Request as Decision;
        let decide = |request: Decision| {
            admin.decide_recovery(authed(
                DecideRecoveryRequest {
                    request: Some(request),
                    remove_other_passkeys: false,
                },
                &admin_token,
            ))
        };
        let wrong = decide(Decision::ApproveCode("NOPE-NOPE".to_string())).await;
        assert_eq!(wrong.unwrap_err().code(), tonic::Code::NotFound);
        let approved = decide(Decision::ApproveCode(code.to_lowercase()))
            .await
            .unwrap()
            .into_inner()
            .recovery
            .unwrap();
        assert_eq!(approved.status, "approved");
        assert_eq!(approved.username, "lifter");
        assert!(db.credential_registered("cred-1").await.unwrap());
        let denied = decide(Decision::DenyRequestId("r2".to_string()))
            .await
            .unwrap()
            .into_inner()
            .recovery
            .unwrap();
        assert_eq!(denied.status, "denied");
        assert!(!db.credential_registered("cred-2").await.unwrap());
        let again = decide(Decision::DenyRequestId("r2".to_string())).await;
        assert_eq!(again.unwrap_err().code(), tonic::Code::NotFound);
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
