//! Accounts, kept by the ledger (`db/ledger`): a device's events are held
//! in memory until the account is written (its workout ends, it goes
//! quiet), which is when its devices hear them back placed; a read folds
//! the account's snapshot and what's held, for that read.

use schlift_core::account::Account;
use schlift_core::events::Event;

use super::*;

impl ServerDb {
    /// Look at a user's account as it is now (without heart rate, which the
    /// server never reads): events pushed and not yet written included.
    pub async fn read_account<R: Send + 'static, F: FnOnce(&Account) -> R + Send + 'static>(
        &self,
        user_id: &str,
        read: F,
    ) -> DbResult<R> {
        self.ledger.read_account(user_id, read).await
    }

    /// The last seq written for the user.
    pub async fn head(&self, user_id: &str) -> DbResult<i64> {
        self.ledger.head(user_id).await
    }

    /// The last seq written for the user, and the id of the event there.
    pub async fn last_written(&self, user_id: &str) -> DbResult<(i64, String)> {
        self.ledger.last(user_id).await
    }

    /// Up to `limit` of the user's written events after `after_seq`, from
    /// the files: an app from before snapshots catches up with these.
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

    /// The account as written (`schlift_core::snapshot`), its seq and the id
    /// of the event there: what a device that needs the account whole is
    /// sent.
    pub async fn snapshot_now(&self, user_id: &str) -> DbResult<(Vec<u8>, i64, String)> {
        self.ledger.snapshot_now(user_id).await
    }

    /// Of a device's pending events, those already written (it was away
    /// when they were acked).
    pub async fn written_among(&self, user_id: &str, ids: &[String]) -> DbResult<Vec<String>> {
        self.ledger.written_among(user_id, ids).await
    }

    /// A workout of the user's as their session partners see it: its shared
    /// events from its start, written (while on show) or held, in order.
    pub async fn workout_events(&self, user_id: &str, workout_id: &str) -> DbResult<Vec<Event>> {
        self.ledger.workout_events(user_id, workout_id).await
    }

    /// A workout's heart rate, by its id.
    pub async fn workout_heart_rate(
        &self,
        user_id: &str,
        workout_id: &str,
    ) -> DbResult<Option<ledger::files::Beats>> {
        self.ledger.heart_rate(user_id, workout_id).await
    }

    /// A device's events: those the account doesn't hold (by id; a device
    /// resends until it hears back; with `check_written`, a stream's first
    /// push, also against what was written while it was away). They go to
    /// the user's session partners now, and are written with the account,
    /// when its devices hear them back placed. What they say of the user's
    /// session workout is followed.
    pub async fn buffer_events(
        &self,
        user_id: &str,
        events: Vec<Event>,
        check_written: bool,
    ) -> DbResult<usize> {
        let taken = self.ledger.buffer(user_id, events, check_written).await?;
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
    /// a seed): written now, and returned placed.
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

    /// Write every account holding events now (tests).
    #[cfg(test)]
    pub async fn flush(&self) -> DbResult<()> {
        self.ledger.flush().await
    }

    /// What a stopping server writes: what is due, then the WAL into the
    /// database.
    pub async fn shut_down(&self) -> DbResult<()> {
        self.ledger.shut_down().await?;
        sqlx::query("PRAGMA wal_checkpoint(TRUNCATE)")
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }
}
