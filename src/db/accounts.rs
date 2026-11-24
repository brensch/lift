//! Accounts as event logs. Each user's history lives in `account_events`, in
//! the server's order, and that is the truth of it: a read folds it from
//! there (from a snapshot of it, `db/snapshots.rs`, when there is one), and
//! a push places events after the head without folding anything.

use schlift_core::account::Account;
use schlift_core::events::{Event, Fact};
use schlift_core::session::shared_with_partners;
use std::collections::{HashMap, HashSet};
use tokio::sync::{mpsc, oneshot};

/// How far back a partner's latest workout is looked for: more events than
/// any one workout records.
const WORKOUT_REACH: i64 = 2_000;

use super::*;

/// A read: answered, or not yet, its snapshot not reading (and the read
/// handed back, to be made again from the whole log).
enum Folded<R, F> {
    Read(R),
    Unreadable(String, F),
}

/// What a push did.
#[derive(Default)]
pub struct Pushed {
    /// The events it added, each with its place.
    pub stored: Vec<Event>,
}

impl ServerDb {
    /// Look at a user's account (without heart rate, which the server never
    /// reads): its snapshot, if this build folded it, with the events since
    /// folded on (`db/snapshots.rs`); with none, its whole history. One that
    /// had to fold many is snapshotted again, after answering. The fold and
    /// the read run on the blocking pool: a large account takes a while to
    /// fold, and the runtime's few workers also serve every stream.
    pub async fn read_account<R: Send + 'static, F: FnOnce(&Account) -> R + Send + 'static>(
        &self,
        user_id: &str,
        read: F,
    ) -> DbResult<R> {
        match self.read_account_from(user_id, true, read).await? {
            Folded::Read(answer) => Ok(answer),
            Folded::Unreadable(error, read) => {
                tracing::warn!(%user_id, %error, "snapshot didn't read; folding whole");
                self.forget_snapshot(user_id).await?;
                match self.read_account_from(user_id, false, read).await? {
                    Folded::Read(answer) => Ok(answer),
                    Folded::Unreadable(error, _) => Err(error.into()),
                }
            }
        }
    }

    async fn read_account_from<R: Send + 'static, F: FnOnce(&Account) -> R + Send + 'static>(
        &self,
        user_id: &str,
        use_snapshot: bool,
        read: F,
    ) -> DbResult<Folded<R, F>> {
        let saved = if use_snapshot {
            self.saved_snapshot(user_id).await?
        } else {
            None
        };
        let after = saved.as_ref().map_or(0, |(seq, _)| *seq);
        // Heart-rate rows are most of a log and change nothing in a fold
        // without heart rate, so they are not read (or parsed) at all.
        let rows: Vec<(i64, String)> = sqlx::query_as(
            "SELECT seq, event FROM account_events
             WHERE user_id = ? AND seq > ? AND event -> '$.HeartRateRecorded' IS NULL
             ORDER BY seq",
        )
        .bind(user_id)
        .bind(after)
        .fetch_all(&self.read_pool)
        .await?;
        let db = self.clone();
        let user = user_id.to_string();
        tokio::task::spawn_blocking(move || -> DbResult<_> {
            let had_snapshot = saved.is_some();
            let mut account = match saved {
                Some((_, state)) => match schlift_core::snapshot::restore(&state) {
                    Ok(account) => account,
                    // Only the events after it were read: the whole log
                    // is needed, so the read is made again without it.
                    Err(error) => return Ok(Folded::Unreadable(error, read)),
                },
                None => Account::fold_without_heart_rate([]),
            };
            for (_, json) in &rows {
                account.replay(&serde_json::from_str::<Event>(json)?);
            }
            let answer = read(&account);
            if let Some((seq, _)) = rows.last() {
                if !had_snapshot || rows.len() >= snapshots::REFOLD_AFTER {
                    db.save_snapshot(&user, *seq, account);
                }
            }
            Ok(Folded::Read(answer))
        })
        .await?
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

    /// A workout of the user's as their session partners see it: its events
    /// from its start, only those shared with partners, in order. Empty if
    /// it did not start within the last `WORKOUT_REACH` events (heart rate
    /// aside).
    pub async fn workout_events(&self, user_id: &str, workout_id: &str) -> DbResult<Vec<Event>> {
        let rows: Vec<String> = sqlx::query_scalar(
            "SELECT event FROM account_events
             WHERE user_id = ? AND event -> '$.HeartRateRecorded' IS NULL
             ORDER BY seq DESC LIMIT ?",
        )
        .bind(user_id)
        .bind(WORKOUT_REACH)
        .fetch_all(&self.read_pool)
        .await?;
        let mut workout = Vec::new();
        for json in rows {
            let event: Event = serde_json::from_str(&json)?;
            if !shared_with_partners(&event.fact) {
                continue;
            }
            let started = matches!(event.fact, Fact::WorkoutStarted(_)) && event.id == workout_id;
            workout.push(event);
            if started {
                workout.retain(|e| e.workout_id() == Some(workout_id));
                workout.reverse();
                return Ok(workout);
            }
        }
        Ok(Vec::new())
    }

    /// Give a device's events their places after the head and append them.
    /// One the server already holds (by id: a device resends until it hears
    /// back) is skipped. Pushes are placed one at a time, each after the
    /// last, by the one writer (`writer`), which stores the pushes waiting
    /// together in one transaction; one racing the account's deletion fails
    /// on the foreign key, alone. What they say of the user's session
    /// workout is followed once they're stored.
    pub async fn push_events(&self, user_id: &str, events: Vec<Event>) -> DbResult<Pushed> {
        let (done, placed) = oneshot::channel();
        self.pushes
            .send(Push {
                user_id: user_id.to_string(),
                events,
                done,
            })
            .await
            .map_err(|_| "the writer has stopped")?;
        let stored = placed.await.map_err(|_| "the writer has stopped")??;
        let pushed = Pushed { stored };
        if pushed.stored.is_empty() {
            return Ok(pushed);
        }
        self.follow_session(user_id, &pushed.stored).await?;
        Ok(pushed)
    }
}

/// A push waiting for the writer, and where its events go once placed.
pub(super) struct Push {
    user_id: String,
    events: Vec<Event>,
    done: oneshot::Sender<DbResult<Vec<Event>>>,
}

/// The most pushes stored in one transaction.
const PUSHES_PER_WRITE: usize = 256;

/// Pushes waiting for the writer before a pusher waits to hand it one.
pub(super) const PUSHES_WAITING: usize = 4096;

/// The one writer of events. Each push held the write connection for a
/// handful of round trips to SQLite, one after another, so at about a
/// thousand pushes a second they queued however many cores were idle (see
/// docs/testing/load.md). Now every push waiting is placed in one
/// transaction of four statements, so a busy second costs a few
/// transactions, not a thousand.
pub(super) async fn writer(
    pool: Pool<Sqlite>,
    changes: std::sync::Arc<changes::Changes>,
    snapshots: std::sync::Arc<snapshots::Lag>,
    mut pushes: mpsc::Receiver<Push>,
) {
    while let Some(first) = pushes.recv().await {
        let mut batch = vec![first];
        while batch.len() < PUSHES_PER_WRITE {
            match pushes.try_recv() {
                Ok(push) => batch.push(push),
                Err(_) => break,
            }
        }
        let placed = match place(&pool, &batch).await {
            Ok(placed) => placed.into_iter().map(Ok).collect(),
            // One push failing (its account deleted meanwhile) fails the
            // transaction: each is tried alone, so only it fails.
            Err(_) if batch.len() > 1 => {
                let mut placed = Vec::with_capacity(batch.len());
                for push in &batch {
                    placed.push(
                        place(&pool, std::slice::from_ref(push))
                            .await
                            .map(|mut one| one.pop().unwrap_or_default()),
                    );
                }
                placed
            }
            Err(error) => vec![Err(error)],
        };
        for (push, stored) in batch.into_iter().zip(placed) {
            if let Ok(stored) = &stored {
                if !stored.is_empty() {
                    snapshots.pushed(&push.user_id, stored);
                    changes.notify(
                        Topic::User(push.user_id.clone()),
                        Change::Account(stored.as_slice().into()),
                    );
                }
            }
            // The pusher may have hung up; its events are stored all the same.
            let _ = push.done.send(stored);
        }
    }
}

/// Place and store `pushes`, in order, in one transaction: each push's
/// events after its account's head (and after the pushes before it in the
/// batch), those already held skipped. The events each push added.
async fn place(pool: &Pool<Sqlite>, pushes: &[Push]) -> DbResult<Vec<Vec<Event>>> {
    let mut tx = pool.begin().await?;
    let users: Vec<&str> = {
        let mut users: Vec<&str> = pushes.iter().map(|p| p.user_id.as_str()).collect();
        users.sort_unstable();
        users.dedup();
        users
    };
    let wanted: Vec<(&str, &str)> = pushes
        .iter()
        .flat_map(|p| p.events.iter().map(|e| (p.user_id.as_str(), e.id.as_str())))
        .collect();
    let held: Vec<(String, String)> = sqlx::query_as(
        "SELECT e.user_id, e.id FROM json_each(?) j
         JOIN account_events e ON e.user_id = j.value ->> 0 AND e.id = j.value ->> 1",
    )
    .bind(serde_json::to_string(&wanted)?)
    .fetch_all(&mut *tx)
    .await?;
    let heads: Vec<(String, i64)> = sqlx::query_as(
        "SELECT j.value,
                (SELECT COALESCE(MAX(seq), 0) FROM account_events WHERE user_id = j.value)
         FROM json_each(?) j",
    )
    .bind(serde_json::to_string(&users)?)
    .fetch_all(&mut *tx)
    .await?;
    let mut heads: HashMap<String, i64> = heads.into_iter().collect();
    // Held already, or earlier in this batch: skipped. A set, so the largest
    // push is not checked against itself event by event.
    let mut placed: HashSet<(String, String)> = held.into_iter().collect();
    let mut rows: Vec<(String, i64, String, String)> = Vec::new();
    let mut stored = Vec::with_capacity(pushes.len());
    for push in pushes {
        let head = heads.entry(push.user_id.clone()).or_insert(0);
        let mut added = Vec::new();
        for event in &push.events {
            if !placed.insert((push.user_id.clone(), event.id.clone())) {
                continue;
            }
            *head += 1;
            let mut event = event.clone();
            event.seq = *head;
            rows.push((
                push.user_id.clone(),
                event.seq,
                event.id.clone(),
                serde_json::to_string(&event)?,
            ));
            added.push(event);
        }
        stored.push(added);
    }
    if rows.is_empty() {
        return Ok(stored);
    }
    sqlx::query(
        "INSERT INTO account_events (user_id, seq, id, event)
         SELECT value ->> 0, value ->> 1, value ->> 2, value ->> 3 FROM json_each(?)",
    )
    .bind(serde_json::to_string(&rows)?)
    .execute(&mut *tx)
    .await?;
    tx.commit().await?;
    Ok(stored)
}
