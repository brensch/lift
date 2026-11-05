//! Accounts as event logs. Each user's history lives in `account_events`, in
//! the server's order, and nothing else of it is kept: a read folds it from
//! there, and a push places events after the head without folding anything.

use std::collections::HashSet;

use schlift_core::account::Account;
use schlift_core::events::{Event, Fact};
use schlift_core::session::shared_with_partners;

/// How far back a partner's latest workout is looked for: more events than
/// any one workout records.
const WORKOUT_REACH: i64 = 2_000;

use super::*;

/// What a push did.
#[derive(Default)]
pub struct Pushed {
    /// The events it added, each with its place.
    pub stored: Vec<Event>,
    /// A workout ended in it.
    pub ended_workout: bool,
    /// A workout was thrown away in it.
    pub discarded_workout: bool,
}

impl ServerDb {
    /// Look at a user's account, folded from its history (without heart
    /// rate, which the server never reads).
    pub async fn read_account<R>(
        &self,
        user_id: &str,
        read: impl FnOnce(&Account) -> R,
    ) -> DbResult<R> {
        // Heart-rate rows are most of a log and change nothing in a fold
        // without heart rate, so they are not read (or parsed) at all.
        let rows: Vec<String> = sqlx::query_scalar(
            "SELECT event FROM account_events
             WHERE user_id = ? AND event -> '$.HeartRateRecorded' IS NULL ORDER BY seq",
        )
        .bind(user_id)
        .fetch_all(&self.read_pool)
        .await?;
        let events = rows
            .iter()
            .map(|json| serde_json::from_str(json))
            .collect::<Result<Vec<Event>, _>>()?;
        Ok(read(&Account::fold_without_heart_rate(&events)))
    }

    /// The last seq the server holds for the user.
    pub async fn head(&self, user_id: &str) -> DbResult<i64> {
        let head: i64 = sqlx::query_scalar(
            "SELECT COALESCE(MAX(seq), 0) FROM account_events WHERE user_id = ?",
        )
        .bind(user_id)
        .fetch_one(&self.read_pool)
        .await?;
        Ok(head)
    }

    /// Up to `limit` of the user's events after `after_seq`, in order.
    pub async fn events_after(
        &self,
        user_id: &str,
        after_seq: i64,
        limit: i64,
    ) -> DbResult<Vec<Event>> {
        let rows: Vec<String> = sqlx::query_scalar(
            "SELECT event FROM account_events WHERE user_id = ? AND seq > ? ORDER BY seq LIMIT ?",
        )
        .bind(user_id)
        .bind(after_seq)
        .bind(limit)
        .fetch_all(&self.read_pool)
        .await?;
        rows.iter()
            .map(|json| Ok(serde_json::from_str(json)?))
            .collect()
    }

    /// The user's latest workout as their session partners see it: its
    /// events from its start, only those shared with partners, in order.
    /// Empty if they have none within the last `WORKOUT_REACH` events.
    pub async fn latest_workout_events(&self, user_id: &str) -> DbResult<Vec<Event>> {
        let rows: Vec<String> = sqlx::query_scalar(
            "SELECT event FROM account_events WHERE user_id = ? ORDER BY seq DESC LIMIT ?",
        )
        .bind(user_id)
        .bind(WORKOUT_REACH)
        .fetch_all(&self.read_pool)
        .await?;
        let mut workout = Vec::new();
        for json in rows {
            let event: Event = serde_json::from_str(&json)?;
            let started = matches!(event.fact, Fact::WorkoutStarted(_));
            if shared_with_partners(&event.fact) {
                workout.push(event);
            }
            if started {
                let id = workout.last().map(|e| e.id.clone()).unwrap_or_default();
                workout.retain(|e| e.id == id || e.fact.workout_id() == Some(id.as_str()));
                workout.reverse();
                return Ok(workout);
            }
        }
        Ok(Vec::new())
    }

    /// Give a device's events their places after the head and append them.
    /// One the server already holds (by id: a device resends until it hears
    /// back) is skipped. All in one transaction on the one write connection,
    /// so pushes are placed one at a time, each after the last; one racing
    /// the account's deletion fails on the foreign key.
    pub async fn push_events(&self, user_id: &str, events: Vec<Event>) -> DbResult<Pushed> {
        let mut tx = self.write_pool.begin().await?;
        let ids: Vec<&str> = events.iter().map(|e| e.id.as_str()).collect();
        let held: HashSet<String> = sqlx::query_scalar(
            "SELECT id FROM account_events
             WHERE user_id = ? AND id IN (SELECT value FROM json_each(?))",
        )
        .bind(user_id)
        .bind(serde_json::to_string(&ids)?)
        .fetch_all(&mut *tx)
        .await?
        .into_iter()
        .collect();
        let mut head: i64 = sqlx::query_scalar(
            "SELECT COALESCE(MAX(seq), 0) FROM account_events WHERE user_id = ?",
        )
        .bind(user_id)
        .fetch_one(&mut *tx)
        .await?;
        let mut pushed = Pushed::default();
        // Ids stored by this push: one sent twice in it is stored once.
        let mut seen: HashSet<String> = HashSet::new();
        for mut event in events {
            if held.contains(&event.id) || !seen.insert(event.id.clone()) {
                continue;
            }
            head += 1;
            event.seq = head;
            sqlx::query("INSERT INTO account_events (user_id, seq, id, event) VALUES (?, ?, ?, ?)")
                .bind(user_id)
                .bind(event.seq)
                .bind(&event.id)
                .bind(serde_json::to_string(&event)?)
                .execute(&mut *tx)
                .await?;
            pushed.ended_workout |= matches!(event.fact, Fact::WorkoutEnded(_));
            pushed.discarded_workout |= matches!(event.fact, Fact::WorkoutDiscarded(_));
            pushed.stored.push(event);
        }
        if pushed.stored.is_empty() {
            return Ok(pushed);
        }
        tx.commit().await?;
        self.notify(
            Topic::User(user_id.to_string()),
            Change::Account(pushed.stored.as_slice().into()),
        );
        Ok(pushed)
    }
}
