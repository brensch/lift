//! Accounts as event logs. Each user's log lives in `account_events`, in the
//! server's order; the fold of it (`Account`) is kept in memory once read.
//! A device's pushed events are given their places, folded and appended in
//! one go.

use std::collections::HashMap;
use std::sync::Arc;
use std::time::Instant;

use schlift_core::account::Account;
use schlift_core::events::{Event, Fact};
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
type Slot = Arc<Mutex<Option<Folded>>>;

/// An account and the last seq folded into it.
pub(super) struct Folded {
    account: Account,
    head: i64,
}

const CACHED_ACCOUNTS: usize = 256;

/// The account's log could not be read in (the request that tried was told
/// why); this request is refused too, and the next one tries again.
const NOT_LOADED: &str = "account did not load";

/// What a push did.
#[derive(Default)]
pub struct Pushed {
    /// The events it added, each with its place.
    pub stored: Vec<Event>,
    /// Some new event was more than heart rate: what session partners see
    /// may have moved on.
    pub progressed: bool,
    /// A workout ended in it.
    pub ended_workout: bool,
}

impl ServerDb {
    /// The user's account slot. On a miss the slot is cached first and
    /// filled after, under its own lock, so the read and fold of one log
    /// holds up only that account.
    pub(super) async fn account_lock(&self, user_id: &str) -> DbResult<Slot> {
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
        match self.events_after(user_id, 0, i64::MAX).await {
            Ok(events) => {
                *loading = Some(Folded {
                    account: Account::fold(&events),
                    head: events.last().map_or(0, |e| e.seq),
                });
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
    pub(super) async fn forget_slot(&self, user_id: &str, slot: &Slot) {
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
        let folded = account.as_ref().ok_or(NOT_LOADED)?;
        Ok(read(&folded.account))
    }

    /// The last seq the server holds for the user. Read from the log, not
    /// the account cache, so asking keeps no account folded in memory.
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

    /// Give a device's events their places after the head and append them.
    /// One the server already holds (by id: a device resends until it hears
    /// back) is skipped. Each is folded in, and one that doesn't apply still
    /// takes its place, as it does on every device.
    pub async fn push_events(&self, user_id: &str, events: Vec<Event>) -> DbResult<Pushed> {
        let lock = self.account_lock(user_id).await?;
        let mut guard = lock.lock().await;
        let folded = guard.as_mut().ok_or(NOT_LOADED)?;
        let ids: Vec<&str> = events.iter().map(|e| e.id.as_str()).collect();
        let held: Vec<String> = sqlx::query_scalar(
            "SELECT id FROM account_events
             WHERE user_id = ? AND id IN (SELECT value FROM json_each(?))",
        )
        .bind(user_id)
        .bind(serde_json::to_string(&ids)?)
        .fetch_all(&self.read_pool)
        .await?;
        let mut head = folded.head;
        let mut pushed = Pushed::default();
        for mut event in events {
            if held.contains(&event.id) || pushed.stored.iter().any(|e| e.id == event.id) {
                continue;
            }
            head += 1;
            event.seq = head;
            if let Some(error) = folded.account.replay(&event) {
                tracing::warn!(%user_id, seq = event.seq, %error, "event did not apply");
            }
            pushed.progressed |= !matches!(event.fact, Fact::HeartRateRecorded(_));
            pushed.ended_workout |= matches!(event.fact, Fact::WorkoutEnded(_));
            pushed.stored.push(event);
        }
        if pushed.stored.is_empty() {
            return Ok(pushed);
        }
        if let Err(error) = self.store_events(user_id, &pushed.stored).await {
            // The fold ran ahead of the store: the slot is emptied, so anyone
            // waiting on it is refused, and the next request refolds from what
            // was actually written.
            *guard = None;
            drop(guard);
            self.forget_slot(user_id, &lock).await;
            return Err(error);
        }
        folded.head = head;
        drop(guard);
        self.notify(
            Topic::User(user_id.to_string()),
            Change::Account(pushed.stored.as_slice().into()),
        );
        Ok(pushed)
    }

    /// Append placed events in one transaction. The account must still exist:
    /// a push that races its deletion fails on the foreign key.
    async fn store_events(&self, user_id: &str, events: &[Event]) -> DbResult<()> {
        let mut tx = self.write_pool.begin().await?;
        for event in events {
            sqlx::query("INSERT INTO account_events (user_id, seq, id, event) VALUES (?, ?, ?, ?)")
                .bind(user_id)
                .bind(event.seq)
                .bind(&event.id)
                .bind(serde_json::to_string(event)?)
                .execute(&mut *tx)
                .await?;
        }
        tx.commit().await?;
        Ok(())
    }
}
