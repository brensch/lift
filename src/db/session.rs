use super::*;
use std::collections::HashMap;
use std::sync::Mutex;

use schlift_core::session::SHOWN_FOR_SECONDS;

/// How long a request to join stays answerable.
pub const JOIN_REQUEST_TTL_SECONDS: i64 = 120;

/// Requests to join someone. They are answerable for two minutes, so they
/// live in memory: a restart drops at most a question someone asks again.
#[derive(Default)]
pub(super) struct JoinRequests(Mutex<HashMap<String, JoinRequest>>);

struct JoinRequest {
    from: String,
    to: String,
    created_at: i64,
}

impl JoinRequests {
    fn lock(&self) -> std::sync::MutexGuard<'_, HashMap<String, JoinRequest>> {
        self.0.lock().expect("join requests lock")
    }
}

impl ServerDb {
    // ── Invite tokens ──

    /// The user's invite token: every user has one from sign-up.
    pub async fn get_invite_token(&self, user_id: &str) -> DbResult<Option<String>> {
        let token = sqlx::query_scalar("SELECT invite_token FROM users WHERE id = ?")
            .bind(user_id)
            .fetch_optional(&self.read_pool)
            .await?;
        Ok(token)
    }

    pub async fn lookup_user_by_invite_token(
        &self,
        invite_token: &str,
    ) -> DbResult<Option<String>> {
        let user_id = sqlx::query_scalar("SELECT id FROM users WHERE invite_token = ?")
            .bind(invite_token)
            .fetch_optional(&self.read_pool)
            .await?;
        Ok(user_id)
    }

    // ── Sessions ──

    /// Put the user in `session_id`. A session they were in before is left,
    /// and they're off show there.
    pub async fn join_session(&self, session_id: &str, user_id: &str) -> DbResult<()> {
        let now = now_unix();
        let mut tx = self.write_pool.begin().await?;
        let left: Option<String> = sqlx::query_scalar(
            "UPDATE session_members SET left_at = ?, ended_at = 0
             WHERE user_id = ? AND left_at = 0 AND session_id != ?
             RETURNING session_id",
        )
        .bind(now)
        .bind(user_id)
        .bind(session_id)
        .fetch_optional(&mut *tx)
        .await?;
        sqlx::query(
            "INSERT INTO session_members (session_id, user_id, joined_at, left_at)
             VALUES (?, ?, ?, 0)
             ON CONFLICT (session_id, user_id) DO UPDATE SET left_at = 0, ended_at = 0",
        )
        .bind(session_id)
        .bind(user_id)
        .bind(now)
        .execute(&mut *tx)
        .await?;
        tx.commit().await?;
        if let Some(left) = left {
            self.notify(Topic::Session(left), Change::Session);
        }
        self.notify(Topic::User(user_id.to_string()), Change::Membership);
        self.notify(Topic::Session(session_id.to_string()), Change::Session);
        Ok(())
    }

    /// The user's workout ended: they're out of the session, their final
    /// state on show to the others a while (`SHOWN_FOR_SECONDS`).
    pub async fn end_session(&self, session_id: &str, user_id: &str) -> DbResult<()> {
        self.stamp_left(session_id, user_id, "left_at = ?1, ended_at = ?1")
            .await
    }

    /// The user left the session: out of it and off show at once.
    pub async fn leave_session(&self, session_id: &str, user_id: &str) -> DbResult<()> {
        self.stamp_left(session_id, user_id, "left_at = ?1").await
    }

    async fn stamp_left(&self, session_id: &str, user_id: &str, set: &str) -> DbResult<()> {
        sqlx::query(&format!(
            "UPDATE session_members SET {set}
             WHERE session_id = ?2 AND user_id = ?3 AND left_at = 0"
        ))
        .bind(now_unix())
        .bind(session_id)
        .bind(user_id)
        .execute(&self.write_pool)
        .await?;
        self.notify(Topic::User(user_id.to_string()), Change::Membership);
        self.notify(Topic::Session(session_id.to_string()), Change::Session);
        Ok(())
    }

    /// The session the user is in and has done something in (joined it, or
    /// recorded anything) within `SHOWN_FOR_SECONDS`. Someone who joined and
    /// never started, or walked off without ending, drops out on their own.
    pub async fn get_user_current_session(&self, user_id: &str) -> DbResult<Option<String>> {
        let session = sqlx::query_scalar(
            "SELECT m.session_id FROM session_members m
             WHERE m.user_id = ?1 AND m.left_at = 0
               AND MAX(m.joined_at, COALESCE(
                     (SELECT e.event ->> '$.at' FROM account_events e
                      WHERE e.user_id = ?1 ORDER BY e.seq DESC LIMIT 1), 0)) > ?2",
        )
        .bind(user_id)
        .bind(now_unix() - SHOWN_FOR_SECONDS)
        .fetch_optional(&self.read_pool)
        .await?;
        Ok(session)
    }

    /// The session the user is in, idle or not: what leaving has to clean up.
    pub async fn get_user_session_pointer(&self, user_id: &str) -> DbResult<Option<String>> {
        let session = sqlx::query_scalar(
            "SELECT session_id FROM session_members WHERE user_id = ? AND left_at = 0",
        )
        .bind(user_id)
        .fetch_optional(&self.read_pool)
        .await?;
        Ok(session)
    }

    /// Who is on show in a session, first to join first: (user, joined_at,
    /// ended_at). Those in it, and those whose workout ended it for them
    /// within `SHOWN_FOR_SECONDS`. Whether each has gone idle, their phones
    /// work out from what they last recorded.
    pub async fn session_roster(&self, session_id: &str) -> DbResult<Vec<(String, i64, i64)>> {
        let rows = sqlx::query(
            "SELECT user_id, joined_at, ended_at FROM session_members
             WHERE session_id = ? AND (left_at = 0 OR ended_at > ?)
             ORDER BY joined_at",
        )
        .bind(session_id)
        .bind(now_unix() - SHOWN_FOR_SECONDS)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| (r.get("user_id"), r.get("joined_at"), r.get("ended_at")))
            .collect())
    }

    /// When the member left the session; 0 while they're in it.
    #[cfg(test)]
    pub async fn session_member_left_at(&self, session_id: &str, user_id: &str) -> DbResult<i64> {
        let left = sqlx::query_scalar(
            "SELECT left_at FROM session_members WHERE session_id = ? AND user_id = ?",
        )
        .bind(session_id)
        .bind(user_id)
        .fetch_one(&self.read_pool)
        .await?;
        Ok(left)
    }

    /// Something about a session's members changed that isn't their
    /// membership (a profile): its streams send it again.
    pub fn session_changed(&self, session_id: &str) {
        self.notify(Topic::Session(session_id.to_string()), Change::Session);
    }

    /// Push a member's joining [seconds] into the past: idle tests.
    #[cfg(test)]
    pub async fn age_session_member(&self, user_id: &str, seconds: i64) -> DbResult<()> {
        sqlx::query("UPDATE session_members SET joined_at = joined_at - ? WHERE user_id = ?")
            .bind(seconds)
            .bind(user_id)
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }

    // ── Who trained together ──

    /// Every session the user has been in, mapped to the others who were in
    /// it, first to join first.
    pub async fn list_session_partner_ids(
        &self,
        user_id: &str,
    ) -> DbResult<HashMap<String, Vec<String>>> {
        let rows = sqlx::query(
            "SELECT m1.session_id, m2.user_id AS partner_id
             FROM session_members m1
             LEFT JOIN session_members m2
               ON m2.session_id = m1.session_id AND m2.user_id != m1.user_id
             WHERE m1.user_id = ?
             ORDER BY m2.joined_at ASC",
        )
        .bind(user_id)
        .fetch_all(&self.read_pool)
        .await?;
        let mut sessions: HashMap<String, Vec<String>> = HashMap::new();
        for row in rows {
            let partners = sessions.entry(row.get("session_id")).or_default();
            if let Some(partner_id) = row.get::<Option<String>, _>("partner_id") {
                partners.push(partner_id);
            }
        }
        Ok(sessions)
    }

    /// Everyone the user has shared a session with: (partner_id, sessions
    /// together, when they last started one together). Most recent first.
    pub async fn list_training_partners(&self, user_id: &str) -> DbResult<Vec<(String, i64, i64)>> {
        let rows = sqlx::query(
            "SELECT m2.user_id AS partner_id,
                    COUNT(DISTINCT m1.session_id) AS sessions_together,
                    MAX(m1.joined_at) AS last_trained_at
             FROM session_members m1
             JOIN session_members m2
               ON m2.session_id = m1.session_id AND m2.user_id != m1.user_id
             WHERE m1.user_id = ?
             GROUP BY m2.user_id
             ORDER BY last_trained_at DESC",
        )
        .bind(user_id)
        .fetch_all(&self.read_pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| {
                (
                    r.get("partner_id"),
                    r.get("sessions_together"),
                    r.get("last_trained_at"),
                )
            })
            .collect())
    }

    /// Whether two users have ever shared a session (used to gate partner re-pair).
    pub async fn have_trained_together(&self, a: &str, b: &str) -> DbResult<bool> {
        let together: bool = sqlx::query_scalar(
            "SELECT COUNT(*) > 0 FROM session_members m1
             JOIN session_members m2 ON m2.session_id = m1.session_id
             WHERE m1.user_id = ? AND m2.user_id = ?",
        )
        .bind(a)
        .bind(b)
        .fetch_one(&self.read_pool)
        .await?;
        Ok(together)
    }

    // ── Join requests (request / approve to train together) ──

    /// A request from `from` to `to`, replacing any earlier one in that
    /// direction (one live ask per direction).
    pub async fn create_join_request(
        &self,
        request_id: &str,
        from: &str,
        to: &str,
    ) -> DbResult<()> {
        let now = now_unix();
        let mut requests = self.join_requests.lock();
        // An earlier ask in this direction is replaced; expired ones go.
        requests.retain(|_, r| {
            !(r.from == from && r.to == to) && r.created_at >= now - JOIN_REQUEST_TTL_SECONDS
        });
        requests.insert(
            request_id.to_string(),
            JoinRequest {
                from: from.to_string(),
                to: to.to_string(),
                created_at: now,
            },
        );
        drop(requests);
        self.notify(Topic::User(to.to_string()), Change::JoinRequests);
        Ok(())
    }

    /// Requests to `to` made at or after `since` (unix seconds):
    /// (request_id, from, created_at), most recent first.
    pub async fn list_incoming_join_requests(
        &self,
        to: &str,
        since: i64,
    ) -> DbResult<Vec<(String, String, i64)>> {
        let mut out: Vec<(String, String, i64)> = self
            .join_requests
            .lock()
            .iter()
            .filter(|(_, r)| r.to == to && r.created_at >= since)
            .map(|(id, r)| (id.clone(), r.from.clone(), r.created_at))
            .collect();
        out.sort_by_key(|(_, _, created_at)| std::cmp::Reverse(*created_at));
        Ok(out)
    }

    /// A request's (from, to), if it was made at or after `since`.
    pub async fn get_join_request(
        &self,
        request_id: &str,
        since: i64,
    ) -> DbResult<Option<(String, String)>> {
        Ok(self
            .join_requests
            .lock()
            .get(request_id)
            .filter(|r| r.created_at >= since)
            .map(|r| (r.from.clone(), r.to.clone())))
    }

    pub async fn delete_join_request(&self, request_id: &str) -> DbResult<()> {
        let removed = self.join_requests.lock().remove(request_id);
        if let Some(request) = removed {
            self.notify(Topic::User(request.to), Change::JoinRequests);
        }
        Ok(())
    }

    /// Requests a deleted account made or was asked.
    pub(super) fn forget_join_requests(&self, user_id: &str) {
        self.join_requests
            .lock()
            .retain(|_, r| r.from != user_id && r.to != user_id);
    }

    /// Push a join request's creation [seconds] into the past: expiry tests.
    #[cfg(test)]
    pub async fn age_join_request(&self, request_id: &str, seconds: i64) -> DbResult<()> {
        if let Some(request) = self.join_requests.lock().get_mut(request_id) {
            request.created_at -= seconds;
        }
        Ok(())
    }
}
