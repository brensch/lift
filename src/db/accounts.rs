//! Accounts as event logs, kept by the ledger (`db/ledger`): pushes are
//! buffered in memory and stored with the next flush, which is when the
//! devices hear them back; reads answer from each account held folded.

use schlift_core::account::Account;
use schlift_core::events::Event;

use super::*;

impl ServerDb {
    /// Look at a user's account as it is now (without heart rate, which the
    /// server never reads): pushed events not yet stored included. The fold
    /// runs on the blocking pool.
    pub async fn read_account<R: Send + 'static, F: FnOnce(&Account) -> R + Send + 'static>(
        &self,
        user_id: &str,
        read: F,
    ) -> DbResult<R> {
        self.ledger.read_account(user_id, read).await
    }

    /// The last seq stored for the user.
    pub async fn head(&self, user_id: &str) -> DbResult<i64> {
        self.ledger.head(user_id).await
    }

    /// Up to `limit` of the user's stored events after `after_seq`, in order.
    pub async fn events_after(
        &self,
        user_id: &str,
        after_seq: i64,
        limit: i64,
    ) -> DbResult<Vec<Event>> {
        self.ledger
            .events_after(
                user_id,
                after_seq,
                limit.clamp(0, i64::from(u32::MAX)) as usize,
            )
            .await
    }

    /// The account folded as of its last stored event, written down
    /// (`schlift_core::snapshot`), and that event's seq: what a device that
    /// needs the account whole is sent.
    pub async fn snapshot_now(&self, user_id: &str) -> DbResult<(Vec<u8>, i64)> {
        self.ledger.snapshot_now(user_id).await
    }

    /// The id of the user's stored event at `seq`, if there is one.
    pub async fn id_at(&self, user_id: &str, seq: i64) -> DbResult<Option<String>> {
        self.ledger.id_at(user_id, seq).await
    }

    /// The ids of the user's stored events after `after_seq`.
    pub async fn ids_after(
        &self,
        user_id: &str,
        after_seq: i64,
    ) -> DbResult<std::collections::HashSet<String>> {
        self.ledger.ids_after(user_id, after_seq).await
    }

    /// A workout of the user's as their session partners see it: its shared
    /// events from its start, stored or not, in order. Empty if it isn't one
    /// of their latest.
    pub async fn workout_events(&self, user_id: &str, workout_id: &str) -> DbResult<Vec<Event>> {
        self.ledger.workout_events(user_id, workout_id).await
    }

    /// A device's events, into the buffer: those the account doesn't hold
    /// (by id; a device resends until it hears back). They go to the user's
    /// session partners now, and are stored with the next flush, when the
    /// user's devices hear them back with their places. What they say of
    /// the user's session workout is followed.
    pub async fn buffer_events(&self, user_id: &str, events: Vec<Event>) -> DbResult<usize> {
        let taken = self.ledger.buffer(user_id, events).await?;
        if taken.is_empty() {
            return Ok(0);
        }
        let live: Vec<Event> = taken.iter().map(|e| (**e).clone()).collect();
        self.notify(
            Topic::User(user_id.to_string()),
            Change::Live(live.as_slice().into()),
        );
        self.follow_session(user_id, &live).await?;
        Ok(live.len())
    }

    /// Events no phone holds (an assistant's write, a friend's suggestion,
    /// a seed): stored now, not with the next flush, and returned placed.
    pub async fn push_events(&self, user_id: &str, events: Vec<Event>) -> DbResult<Vec<Event>> {
        let placed = self.ledger.push_now(user_id, events).await?;
        if !placed.is_empty() {
            let live: Vec<Event> = placed
                .iter()
                .map(|e| Event {
                    seq: 0,
                    ..e.clone()
                })
                .collect();
            self.notify(
                Topic::User(user_id.to_string()),
                Change::Live(live.as_slice().into()),
            );
            self.follow_session(user_id, &placed).await?;
        }
        Ok(placed)
    }

    /// Store everything buffered now.
    pub async fn flush(&self) -> DbResult<()> {
        self.ledger.flush().await
    }
}
