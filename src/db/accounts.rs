//! Accounts as event logs. Each user's log lives in `account_events`; the
//! fold of it (`Account`) is kept in memory once read. Pushed events are
//! stored, folded, and projected into the workout tables in one go.

use std::collections::{BTreeSet, HashMap};
use std::sync::Arc;
use std::time::Instant;

use schlift::workout::v1::{event, workout_mutation::Mutation, Event, WorkoutMutation};
use schlift_core::account::{event_workout_ids, Account};
use schlift_core::history::WorkoutRecord;
use tokio::sync::Mutex;

use super::*;

/// Accounts folded in memory, by user, with when each was last used. One
/// lock per account: pushes to one account are serialised, different
/// accounts don't wait on each other. Bounded: past `CACHED_ACCOUNTS` the
/// least recently used is dropped, and refolded from its log if it's needed
/// again — the people training right now stay, everyone else costs nothing.
#[derive(Default)]
pub(super) struct AccountCache(Mutex<HashMap<String, Cached>>);

/// One folded account and when it was last used.
type Cached = (Arc<Mutex<Account>>, Instant);

const CACHED_ACCOUNTS: usize = 256;

/// A device pushed a log that disagrees with the one the server holds: two
/// devices recorded the same account. Nothing is merged.
#[derive(Debug)]
pub struct Diverged;

impl std::fmt::Display for Diverged {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("account_diverged")
    }
}

impl std::error::Error for Diverged {}

/// What a push did.
pub struct Pushed {
    /// The last seq the server now holds.
    pub head: i64,
    /// Some event was new.
    pub changed: bool,
    /// The workout that ended in this push, if one did.
    pub ended_workout: Option<String>,
}

impl ServerDb {
    async fn account_lock(&self, user_id: &str) -> DbResult<Arc<Mutex<Account>>> {
        let mut cache = self.accounts.0.lock().await;
        if let Some((account, used)) = cache.get_mut(user_id) {
            *used = Instant::now();
            return Ok(account.clone());
        }
        let events = self.events_after(user_id, 0).await?;
        let account = Arc::new(Mutex::new(Account::fold(&events)));
        if cache.len() >= CACHED_ACCOUNTS {
            let oldest = cache
                .iter()
                .min_by_key(|(_, (_, used))| *used)
                .map(|(id, _)| id.clone());
            if let Some(oldest) = oldest {
                cache.remove(&oldest);
            }
        }
        cache.insert(user_id.to_string(), (account.clone(), Instant::now()));
        Ok(account)
    }

    /// Look at a user's account.
    pub async fn read_account<R>(
        &self,
        user_id: &str,
        read: impl FnOnce(&Account) -> R,
    ) -> DbResult<R> {
        let lock = self.account_lock(user_id).await?;
        let account = lock.lock().await;
        Ok(read(&account))
    }

    /// The user's events after `after_seq`, in order.
    pub async fn events_after(&self, user_id: &str, after_seq: i64) -> DbResult<Vec<Event>> {
        let rows: Vec<Vec<u8>> = sqlx::query_scalar(
            "SELECT event_blob FROM account_events WHERE user_id = ? AND seq > ? ORDER BY seq",
        )
        .bind(user_id)
        .bind(after_seq)
        .fetch_all(&self.read_pool)
        .await?;
        rows.iter()
            .map(|blob| Ok(Event::decode(blob.as_slice())?))
            .collect()
    }

    /// Append the device's events. Ones already held are skipped; the rest
    /// must carry on from the head without a gap (anything after a gap is
    /// left for the device to resend from the head it's told). Each is
    /// folded in — one that doesn't apply still takes its place, exactly as
    /// it did on the phone — and the workouts they touch are projected.
    pub async fn push_events(&self, user_id: &str, events: Vec<Event>) -> DbResult<Pushed> {
        let lock = self.account_lock(user_id).await?;
        let mut account = lock.lock().await;
        let mut new = Vec::new();
        let mut head = account.seq;
        if let Some(first) = events.first().filter(|e| e.seq <= head) {
            // The device and the server must agree on what they both hold.
            let held: Option<Vec<u8>> = sqlx::query_scalar(
                "SELECT event_blob FROM account_events WHERE user_id = ? AND seq = ?",
            )
            .bind(user_id)
            .bind(first.seq)
            .fetch_optional(&self.read_pool)
            .await?;
            let held = held
                .map(|blob| Event::decode(blob.as_slice()))
                .transpose()?;
            if held.map(|e| e.id) != Some(first.id.clone()) {
                return Err(Box::new(Diverged));
            }
        }
        for event in events {
            if event.seq == head + 1 {
                head = event.seq;
                new.push(event);
            } else if event.seq > head + 1 {
                break;
            }
        }
        if new.is_empty() {
            return Ok(Pushed {
                head,
                changed: false,
                ended_workout: None,
            });
        }

        let mut touched = BTreeSet::new();
        let mut ended_workout = None;
        for event in &new {
            if let Some(error) = account.replay(event) {
                tracing::warn!(%user_id, seq = event.seq, %error, "event did not apply");
            }
            touched.extend(event_workout_ids(event));
            if let Some(event::Kind::Workout(WorkoutMutation {
                mutation: Some(Mutation::EndWorkout(end)),
                ..
            })) = &event.kind
            {
                ended_workout = Some(end.workout_id.clone());
            }
        }

        let records: Vec<&WorkoutRecord> = touched
            .iter()
            .filter_map(|id| account.workout(id))
            .collect();
        if let Err(error) = self.store_events(user_id, &new, &records).await {
            // The fold ran ahead of the store: forget it, and the next read
            // refolds from what was actually written.
            drop(account);
            self.accounts.0.lock().await.remove(user_id);
            return Err(error);
        }
        Ok(Pushed {
            head,
            changed: true,
            ended_workout,
        })
    }

    /// Store new events and rewrite the projections of the workouts they
    /// touched, in one transaction.
    async fn store_events(
        &self,
        user_id: &str,
        events: &[Event],
        workouts: &[&WorkoutRecord],
    ) -> DbResult<()> {
        let session_id = self.get_user_current_session(user_id).await?;
        let mut tx = self.write_pool.begin().await?;
        for event in events {
            sqlx::query("INSERT INTO account_events (user_id, seq, event_blob) VALUES (?, ?, ?)")
                .bind(user_id)
                .bind(event.seq)
                .bind(event.encode_to_vec())
                .execute(&mut *tx)
                .await?;
        }
        for record in workouts {
            let workout = &record.workout;
            // The session is the server's to know: a workout keeps the one
            // it was first seen in (or was joined to since).
            let existing: Option<String> =
                sqlx::query_scalar("SELECT session_id FROM workouts WHERE id = ? AND user_id = ?")
                    .bind(&workout.id)
                    .bind(user_id)
                    .fetch_optional(&mut *tx)
                    .await?;
            let session = existing.unwrap_or_else(|| {
                if workout.end_time > 0 {
                    String::new()
                } else {
                    session_id.clone().unwrap_or_default()
                }
            });
            for table in [
                "DELETE FROM workouts WHERE id = ? AND user_id = ?",
                "DELETE FROM proposed_sets WHERE workout_id = ? AND user_id = ?",
                "DELETE FROM completed_sets WHERE workout_id = ? AND user_id = ?",
                "DELETE FROM workout_heart_rate_samples WHERE workout_id = ? AND user_id = ?",
            ] {
                sqlx::query(table)
                    .bind(&workout.id)
                    .bind(user_id)
                    .execute(&mut *tx)
                    .await?;
            }
            sqlx::query(
                "INSERT INTO workouts (id, user_id, name, start_time, end_time, session_id,
                 template_id, lifting_set_id, lifting_started_at)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            )
            .bind(&workout.id)
            .bind(user_id)
            .bind(&workout.name)
            .bind(workout.start_time)
            .bind(workout.end_time)
            .bind(&session)
            .bind(&workout.template_id)
            .bind(&workout.lifting_set_id)
            .bind(workout.lifting_started_at)
            .execute(&mut *tx)
            .await?;
            for set in &record.proposed_sets {
                sqlx::query(
                    "INSERT INTO proposed_sets (id, user_id, workout_id, workout_order, exercise,
                     target_reps, target_weight, warmup, cancelled, rest_after_success,
                     rest_after_failure, calibration, skipped)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                )
                .bind(&set.id)
                .bind(user_id)
                .bind(&set.workout_id)
                .bind(set.workout_order)
                .bind(set.exercise)
                .bind(set.target_reps)
                .bind(set.target_weight as f64)
                .bind(set.warmup)
                .bind(set.cancelled)
                .bind(set.rest_after_success)
                .bind(set.rest_after_failure)
                .bind(set.calibration)
                .bind(set.skipped)
                .execute(&mut *tx)
                .await?;
            }
            for set in &record.completed_sets {
                sqlx::query(
                    "INSERT INTO completed_sets (id, user_id, workout_id, proposed_set_id,
                     actual_reps, actual_weight, ended_at, rest_until, effort, started_at)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                )
                .bind(&set.id)
                .bind(user_id)
                .bind(&set.workout_id)
                .bind(&set.proposed_set_id)
                .bind(set.actual_reps)
                .bind(set.actual_weight as f64)
                .bind(set.ended_at)
                .bind(set.rest_until)
                .bind(set.effort)
                .bind(set.started_at)
                .execute(&mut *tx)
                .await?;
            }
            for (n, sample) in record.heart_rate.iter().enumerate() {
                sqlx::query(
                    "INSERT INTO workout_heart_rate_samples
                     (id, user_id, workout_id, sampled_at, bpm, availability)
                     VALUES (?, ?, ?, ?, ?, ?)",
                )
                .bind(format!("{}:{n}", workout.id))
                .bind(user_id)
                .bind(&workout.id)
                .bind(sample.sampled_at)
                .bind(sample.bpm as f64)
                .bind(sample.availability)
                .execute(&mut *tx)
                .await?;
            }
        }
        tx.commit().await?;
        Ok(())
    }

    /// Forget a user's account (after deleting their data).
    pub(super) async fn forget_account(&self, user_id: &str) {
        self.accounts.0.lock().await.remove(user_id);
    }
}
