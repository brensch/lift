//! Accounts as event logs. Each user's log lives in `account_events`; the
//! fold of it (`Account`) is kept in memory once read. Pushed events are
//! stored, folded, and projected into the workout tables in one go.

use std::collections::{BTreeSet, HashMap};
use std::sync::Arc;
use std::time::Instant;

use schlift::workout::v1::{event, workout_mutation::Mutation, Event, WorkoutMutation};
use schlift_core::account::{event_workout_ids, Account};
use schlift_core::history::WorkoutRecord;
use schlift_core::projection::{heart_rate_statements, workout_statements, Statement, Value};
use tokio::sync::Mutex;

use super::*;

/// Accounts folded in memory, by user, with when each was last used. One
/// lock per account: pushes to one account are serialised, different
/// accounts don't wait on each other, nor on one being read in from its log.
/// Bounded: past `CACHED_ACCOUNTS` the least recently used is dropped, and
/// refolded from its log if it's needed again — the people training right
/// now stay, everyone else costs nothing.
#[derive(Default)]
pub(super) struct AccountCache(Mutex<HashMap<String, Cached>>);

/// One account, `None` if reading it in from its log failed, and when it
/// was last used.
type Cached = (Slot, Instant);
type Slot = Arc<Mutex<Option<Account>>>;

const CACHED_ACCOUNTS: usize = 256;

/// The account's log could not be read in (the request that tried was told
/// why); this request is refused too, and the next one tries again.
const NOT_LOADED: &str = "account did not load";

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
    /// Some new event was more than heart rate: what session partners see
    /// may have moved on.
    pub progressed: bool,
    /// The workout that ended in this push, if one did.
    pub ended_workout: Option<String>,
}

/// A start or an add naming lifts with no decisions recorded: the shape of
/// a log made before workouts were planned at the start.
fn undecided(event: &Event) -> bool {
    match &event.kind {
        Some(event::Kind::StartWorkout(req)) => {
            !req.exercises.is_empty() && req.decisions.is_empty()
        }
        Some(event::Kind::Workout(WorkoutMutation {
            mutation: Some(Mutation::AddExercises(req)),
            ..
        })) => !req.exercises.is_empty() && req.decisions.is_empty(),
        _ => false,
    }
}

impl ServerDb {
    /// The user's account slot. On a miss the slot is cached first and
    /// filled after, under its own lock, so the read and fold of one log
    /// holds up only that account.
    async fn account_lock(&self, user_id: &str) -> DbResult<Slot> {
        let mut cache = self.accounts.0.lock().await;
        if let Some((account, used)) = cache.get_mut(user_id) {
            *used = Instant::now();
            return Ok(account.clone());
        }
        let slot: Slot = Arc::default();
        let mut loading = slot.clone().lock_owned().await;
        if cache.len() >= CACHED_ACCOUNTS {
            let oldest = cache
                .iter()
                .min_by_key(|(_, (_, used))| *used)
                .map(|(id, _)| id.clone());
            if let Some(oldest) = oldest {
                cache.remove(&oldest);
            }
        }
        cache.insert(user_id.to_string(), (slot.clone(), Instant::now()));
        drop(cache);
        match self.events_after(user_id, 0).await {
            Ok(events) => {
                *loading = Some(Account::fold(&events));
                Ok(slot)
            }
            Err(error) => {
                // Left empty, so anyone already waiting on it is refused, and
                // dropped, so the next request reads the log again.
                self.forget_slot(user_id, &slot).await;
                Err(error)
            }
        }
    }

    /// Drop the user's cached account, if it is still this one.
    async fn forget_slot(&self, user_id: &str, slot: &Slot) {
        let mut cache = self.accounts.0.lock().await;
        if cache
            .get(user_id)
            .is_some_and(|(cached, _)| Arc::ptr_eq(cached, slot))
        {
            cache.remove(user_id);
        }
    }

    /// Look at a user's account.
    pub async fn read_account<R>(
        &self,
        user_id: &str,
        read: impl FnOnce(&Account) -> R,
    ) -> DbResult<R> {
        let lock = self.account_lock(user_id).await?;
        let account = lock.lock().await;
        let account = account.as_ref().ok_or(NOT_LOADED)?;
        Ok(read(account))
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
        let mut guard = lock.lock().await;
        let account = guard.as_mut().ok_or(NOT_LOADED)?;
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
                progressed: false,
                ended_workout: None,
            });
        }

        let mut touched = BTreeSet::new();
        let mut ended_workout = None;
        for event in &new {
            if let Some(error) = account.replay(event) {
                if undecided(event) {
                    // A log from before plans were recorded: this account's
                    // log was rewritten since, so the phone's disagrees.
                    // Nothing is stored: the slot is emptied, so anyone
                    // waiting on it is refused, and the next request refolds
                    // from what is.
                    *guard = None;
                    drop(guard);
                    self.forget_slot(user_id, &lock).await;
                    return Err(Box::new(Diverged));
                }
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
        let heart_rate = heart_rate_statements(user_id, account, &new);
        if let Err(error) = self.store_events(user_id, &new, &records, heart_rate).await {
            // The fold ran ahead of the store: the slot is emptied, so anyone
            // waiting on it is refused, and the next request refolds from what
            // was actually written.
            *guard = None;
            drop(guard);
            self.forget_slot(user_id, &lock).await;
            return Err(error);
        }
        Ok(Pushed {
            head,
            progressed: new
                .iter()
                .any(|event| !matches!(event.kind, Some(event::Kind::HeartRate(_)))),
            ended_workout,
        })
    }

    /// Store new events, rewrite the projections of the workouts they
    /// touched and add the heart-rate rows they bring, in one transaction.
    async fn store_events(
        &self,
        user_id: &str,
        events: &[Event],
        workouts: &[&WorkoutRecord],
        heart_rate: Vec<Statement>,
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
            // The phone records the session once it hears of it; until then
            // a workout keeps the one it was first seen in (or was joined to
            // since).
            let existing: Option<String> =
                sqlx::query_scalar("SELECT session_id FROM workouts WHERE id = ? AND user_id = ?")
                    .bind(&workout.id)
                    .bind(user_id)
                    .fetch_optional(&mut *tx)
                    .await?;
            let session = if workout.session_id.is_empty() {
                existing.unwrap_or_else(|| {
                    if workout.end_time > 0 {
                        String::new()
                    } else {
                        session_id.clone().unwrap_or_default()
                    }
                })
            } else {
                workout.session_id.clone()
            };
            for statement in workout_statements(user_id, record, &session) {
                execute(statement, &mut tx).await?;
            }
        }
        for statement in heart_rate {
            execute(statement, &mut tx).await?;
        }
        tx.commit().await?;
        Ok(())
    }

    /// Forget a user's account (after deleting their data).
    pub(super) async fn forget_account(&self, user_id: &str) {
        self.accounts.0.lock().await.remove(user_id);
    }
}

/// Run one projection statement in `tx`.
async fn execute(
    statement: Statement,
    tx: &mut sqlx::Transaction<'_, sqlx::Sqlite>,
) -> DbResult<()> {
    let mut query = sqlx::query(statement.sql);
    for value in statement.params {
        query = match value {
            Value::Int(v) => query.bind(v),
            Value::Real(v) => query.bind(v),
            Value::Text(v) => query.bind(v),
            Value::Blob(v) => query.bind(v),
        };
    }
    query.execute(&mut **tx).await?;
    Ok(())
}
