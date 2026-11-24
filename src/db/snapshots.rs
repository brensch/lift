//! Snapshots of accounts: each folded as of some event (`account_snapshots`),
//! so a read folds only what came after (`ServerDb::read_account`). A year
//! of training is thousands of events, and every read of it (the website,
//! an assistant's every tool) folded all of them; caught up from a snapshot
//! it folds the few since.
//!
//! None of it is the truth: the events are. A snapshot is taken from what a
//! read folded, so it is exactly what folding the log gives
//! (`testkit/tests/snapshot.rs`), and only this build's are used: each is
//! stamped with the rules that folded it (`SCHLIFT_FOLD`, a hash of the
//! core, see build.rs), so after a release that changes them every account
//! is folded whole once more. A migration step clears them all
//! (`db/migrate.rs`). Any row can be deleted at any time.
//!
//! They are written behind the reads, never with a push: placing events
//! stays a plain append. A read that folded `REFOLD_AFTER` events or more
//! past its snapshot writes a new one after answering, and a sweep folds
//! forward, now and then, the accounts that took that many since.

use std::collections::HashMap;
use std::sync::Mutex;
use std::time::Duration;

use schlift_core::account::Account;
use schlift_core::events::{Event, Fact};

use super::*;

/// The rules this build folds by: snapshots of any other are not caught up.
pub const FOLD: &str = env!("SCHLIFT_FOLD");

/// Events folded past a snapshot before it is taken again: about a workout.
pub(super) const REFOLD_AFTER: usize = 64;

/// How often the sweep looks for accounts that have moved on.
const SWEEP_EVERY: Duration = Duration::from_secs(60);

/// Per account, the events stored since it was last folded forward (heart
/// rate aside), so the sweep knows whose snapshot is behind without reading
/// the log. Lost on restart, which only means a read folds more first.
#[derive(Default)]
pub struct Lag {
    behind: Mutex<HashMap<String, usize>>,
}

impl Lag {
    pub(super) fn pushed(&self, user_id: &str, events: &[Event]) {
        let folded = events
            .iter()
            .filter(|e| !matches!(e.fact, Fact::HeartRateRecorded(_)))
            .count();
        if folded == 0 {
            return;
        }
        let mut behind = self.behind.lock().unwrap_or_else(|e| e.into_inner());
        *behind.entry(user_id.to_string()).or_default() += folded;
    }

    /// The accounts at least `REFOLD_AFTER` behind, no longer counted.
    fn take_behind(&self) -> Vec<String> {
        let mut behind = self.behind.lock().unwrap_or_else(|e| e.into_inner());
        let due: Vec<String> = behind
            .iter()
            .filter(|(_, n)| **n >= REFOLD_AFTER)
            .map(|(user, _)| user.clone())
            .collect();
        for user in &due {
            behind.remove(user);
        }
        due
    }

    fn folded(&self, user_id: &str) {
        let mut behind = self.behind.lock().unwrap_or_else(|e| e.into_inner());
        behind.remove(user_id);
    }
}

impl ServerDb {
    /// The user's snapshot, if this build folded it: the last event it
    /// holds, and it, written down.
    pub(super) async fn saved_snapshot(&self, user_id: &str) -> DbResult<Option<(i64, Vec<u8>)>> {
        Ok(sqlx::query_as(
            "SELECT seq, state FROM account_snapshots WHERE user_id = ? AND fold = ?",
        )
        .bind(user_id)
        .bind(FOLD)
        .fetch_optional(&self.read_pool)
        .await?)
    }

    /// Write the account down as folded up to `seq`, behind the caller:
    /// written on the blocking pool, stored by the write connection when it
    /// is free. Kept only if newer than the one there, or folded by other
    /// rules; dropped if the account is deleted meanwhile.
    pub(super) fn save_snapshot(&self, user_id: &str, seq: i64, account: Account) {
        let db = self.clone();
        let user_id = user_id.to_string();
        let runtime = tokio::runtime::Handle::current();
        runtime.spawn(async move {
            let written = tokio::task::spawn_blocking(move || {
                schlift_core::snapshot::snapshot(&account)
            })
            .await;
            let Ok(state) = written else { return };
            let saved = sqlx::query(
                "INSERT INTO account_snapshots (user_id, seq, fold, state, updated_at)
                 VALUES (?, ?, ?, ?, ?)
                 ON CONFLICT (user_id) DO UPDATE SET
                     seq = excluded.seq, fold = excluded.fold,
                     state = excluded.state, updated_at = excluded.updated_at
                 WHERE excluded.seq > account_snapshots.seq
                    OR excluded.fold != account_snapshots.fold",
            )
            .bind(&user_id)
            .bind(seq)
            .bind(FOLD)
            .bind(state)
            .bind(now_unix())
            .execute(&db.write_pool)
            .await;
            match saved {
                Ok(_) => db.snapshots.folded(&user_id),
                Err(error) => tracing::debug!(%user_id, %error, "snapshot not kept"),
            }
        });
    }

    /// Throw the user's snapshot away: the next read folds the whole log.
    pub(super) async fn forget_snapshot(&self, user_id: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM account_snapshots WHERE user_id = ?")
            .bind(user_id)
            .execute(&self.write_pool)
            .await?;
        Ok(())
    }

    /// Fold forward, in the background: first every account with no
    /// snapshot of this build's (after a release, or on the first start),
    /// then, each minute, those that have moved on since. One at a time, so
    /// it never takes more than a core from the reads and pushes it is
    /// there to spare.
    pub fn sweep_snapshots(&self) {
        let db = self.clone();
        tokio::spawn(async move {
            match db.accounts_without_snapshot().await {
                Ok(users) => {
                    for user in users {
                        db.fold_forward(&user).await;
                    }
                }
                Err(error) => tracing::warn!(%error, "listing accounts to snapshot"),
            }
            let mut every = tokio::time::interval(SWEEP_EVERY);
            loop {
                every.tick().await;
                for user in db.snapshots.take_behind() {
                    db.fold_forward(&user).await;
                }
            }
        });
    }

    async fn fold_forward(&self, user_id: &str) {
        if let Err(error) = self.read_account(user_id, |_| ()).await {
            tracing::warn!(%user_id, %error, "folding forward for a snapshot");
        }
    }

    /// Accounts with events and no snapshot this build folded.
    async fn accounts_without_snapshot(&self) -> DbResult<Vec<String>> {
        Ok(sqlx::query_scalar(
            "SELECT u.id FROM users u
             WHERE EXISTS (SELECT 1 FROM account_events e WHERE e.user_id = u.id)
               AND NOT EXISTS (SELECT 1 FROM account_snapshots s
                               WHERE s.user_id = u.id AND s.fold = ?)",
        )
        .bind(FOLD)
        .fetch_all(&self.read_pool)
        .await?)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;
    use uuid::Uuid;

    /// Twelve weeks of a lifter's training, as phones record it
    /// (testkit's golden history).
    fn training() -> Vec<Event> {
        let path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("testkit/tests/testdata/golden_events.json.zst");
        schlift_core::sync::unpack(&std::fs::read(path).unwrap()).unwrap()
    }

    async fn db_with(users: &[&str]) -> ServerDb {
        let dir = std::env::temp_dir().join(format!("lift-snapshot-test-{}", Uuid::new_v4()));
        let db = ServerDb::new_in_dir(&dir).await.unwrap();
        for user in users {
            db.create_user_with_id(user, user).await.unwrap();
        }
        db
    }

    /// The account folded from everything held, as before snapshots.
    async fn whole(db: &ServerDb, user: &str) -> Account {
        Account::fold_without_heart_rate(&db.events_after(user, 0, i64::MAX).await.unwrap())
    }

    async fn snapshot_row(db: &ServerDb, user: &str) -> Option<(i64, String)> {
        sqlx::query_as("SELECT seq, fold FROM account_snapshots WHERE user_id = ?")
            .bind(user)
            .fetch_optional(&db.read_pool)
            .await
            .unwrap()
    }

    /// Snapshots are written behind the reads: wait for one at `seq`.
    async fn snapshot_at(db: &ServerDb, user: &str, seq: i64) {
        for _ in 0..200 {
            if snapshot_row(db, user).await == Some((seq, FOLD.to_string())) {
                return;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
        panic!(
            "no snapshot at {seq}: {:?}",
            snapshot_row(db, user).await
        );
    }

    async fn last_folded_seq(db: &ServerDb, user: &str) -> i64 {
        sqlx::query_scalar(
            "SELECT MAX(seq) FROM account_events
             WHERE user_id = ? AND event -> '$.HeartRateRecorded' IS NULL",
        )
        .bind(user)
        .fetch_one(&db.read_pool)
        .await
        .unwrap()
    }

    #[tokio::test]
    async fn every_read_is_the_whole_fold_as_snapshots_come_and_go() {
        let db = db_with(&["u"]).await;
        let events = training();
        let mut pushed = 0;
        for chunk in events.chunks(37) {
            db.push_events("u", chunk.to_vec()).await.unwrap();
            pushed += chunk.len();
            let read = db.read_account("u", Clone::clone).await.unwrap();
            assert!(read == whole(&db, "u").await, "after {pushed} events");
        }
        // The first read snapshotted; later ones did again once they had
        // folded enough past it.
        let row = snapshot_row(&db, "u").await;
        assert!(row.is_some_and(|(seq, _)| seq > 0));
        let seq = last_folded_seq(&db, "u").await;
        // One folded by other rules is folded again from the whole log, and
        // replaced.
        sqlx::query("UPDATE account_snapshots SET fold = 'other rules'")
            .execute(&db.write_pool)
            .await
            .unwrap();
        let read = db.read_account("u", Clone::clone).await.unwrap();
        assert!(read == whole(&db, "u").await, "a snapshot by other rules is not used");
        snapshot_at(&db, "u", seq).await;
    }

    #[tokio::test]
    async fn a_damaged_snapshot_is_thrown_away_and_the_log_folded() {
        let db = db_with(&["u"]).await;
        let events = training();
        db.push_events("u", events[..300].to_vec()).await.unwrap();
        db.read_account("u", |_| ()).await.unwrap();
        snapshot_at(&db, "u", last_folded_seq(&db, "u").await).await;
        sqlx::query("UPDATE account_snapshots SET state = x'28b52ffd00'")
            .execute(&db.write_pool)
            .await
            .unwrap();
        db.push_events("u", events[300..].to_vec()).await.unwrap();
        let read = db.read_account("u", Clone::clone).await.unwrap();
        assert!(read == whole(&db, "u").await);
        snapshot_at(&db, "u", last_folded_seq(&db, "u").await).await;
        let read = db.read_account("u", Clone::clone).await.unwrap();
        assert!(read == whole(&db, "u").await, "and the new one reads");
    }

    #[tokio::test]
    async fn the_sweep_snapshots_accounts_that_have_none() {
        let db = db_with(&["u", "empty"]).await;
        db.push_events("u", training()).await.unwrap();
        db.sweep_snapshots();
        snapshot_at(&db, "u", last_folded_seq(&db, "u").await).await;
        assert_eq!(snapshot_row(&db, "empty").await, None, "nothing to fold");
    }

    #[tokio::test]
    async fn pushes_at_once_are_each_placed_in_order_once_and_one_failing_fails_alone() {
        let db = db_with(&["a", "b"]).await;
        let events = training();
        let mut pushing = tokio::task::JoinSet::new();
        for (n, chunk) in events.chunks(5).enumerate() {
            let user = if n % 2 == 0 { "a" } else { "b" };
            for _ in 0..2 {
                // Each sent twice, as a phone resends until it hears back.
                let (db, chunk) = (db.clone(), chunk.to_vec());
                pushing.spawn(async move { (user, db.push_events(user, chunk).await.is_ok()) });
            }
            if n % 50 == 0 {
                let db = db.clone();
                let chunk = chunk.to_vec();
                pushing.spawn(async move { ("ghost", db.push_events("ghost", chunk).await.is_ok()) });
            }
        }
        while let Some(done) = pushing.join_next().await {
            let (user, ok) = done.unwrap();
            assert_eq!(ok, user != "ghost", "{user}");
        }
        let mut held = 0;
        for user in ["a", "b"] {
            let log = db.events_after(user, 0, i64::MAX).await.unwrap();
            let seqs: Vec<i64> = log.iter().map(|e| e.seq).collect();
            assert_eq!(seqs, (1..=log.len() as i64).collect::<Vec<_>>(), "{user}'s places");
            let ids: std::collections::HashSet<&str> = log.iter().map(|e| e.id.as_str()).collect();
            assert_eq!(ids.len(), log.len(), "{user}'s events once each");
            held += log.len();
        }
        assert_eq!(held, events.len());
    }
}
