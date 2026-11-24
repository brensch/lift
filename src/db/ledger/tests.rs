//! The ledger against what it promises: nothing acked is lost, a resend is
//! placed once, and every account read is exactly the fold of every event
//! stored, across restarts, idle accounts, rule changes and a crash between
//! a file and its index.

use super::*;
use crate::db::ServerDb;
use std::path::Path;
use uuid::Uuid;

/// Twelve weeks of a lifter's training, as phones record it.
fn training() -> Vec<Event> {
    let path =
        Path::new(env!("CARGO_MANIFEST_DIR")).join("testkit/tests/testdata/golden_events.json.zst");
    schlift_core::sync::unpack(&std::fs::read(path).unwrap()).unwrap()
}

fn dir() -> PathBuf {
    std::env::temp_dir().join(format!("lift-ledger-test-{}", Uuid::new_v4()))
}

async fn open(dir: &Path, users: &[&str]) -> ServerDb {
    let db = ServerDb::new_in_dir(dir).await.unwrap();
    for user in users {
        if db.get_user(user).await.unwrap().is_none() {
            db.create_user_with_id(user, user).await.unwrap();
        }
    }
    db
}

/// Everything stored for the account, folded from the start: what a read
/// must equal.
async fn whole(db: &ServerDb, user: &str) -> Account {
    Account::fold_without_heart_rate(&db.events_after(user, 0, i64::MAX).await.unwrap())
}

fn ids(events: &[Event]) -> Vec<String> {
    events.iter().map(|e| e.id.clone()).collect()
}

#[tokio::test]
async fn a_read_is_the_whole_fold_through_flushes_restarts_and_idling() {
    let dir = dir();
    let events = training();
    let db = open(&dir, &["u"]).await;
    for (n, chunk) in events.chunks(97).enumerate() {
        db.buffer_events("u", chunk.to_vec()).await.unwrap();
        if n % 3 == 0 {
            db.flush().await.unwrap();
        }
        // Pushed so far, stored or still buffered.
        let end = ((n + 1) * 97).min(events.len());
        let read = db.read_account("u", Clone::clone).await.unwrap();
        let now = Account::fold_without_heart_rate(&events[..end]);
        assert!(read == now, "after chunk {n}");
    }
    db.flush().await.unwrap();
    assert_eq!(db.head("u").await.unwrap(), events.len() as i64);
    assert_eq!(
        ids(&db.events_after("u", 0, i64::MAX).await.unwrap()),
        ids(&events)
    );
    let folded = whole(&db, "u").await;
    assert!(db.read_account("u", Clone::clone).await.unwrap() == folded);

    // Idle: written down and dropped from memory; read again the same.
    db.ledger.sweep_all().await;
    assert!(
        db.ledger.users.lock().unwrap().is_empty(),
        "dropped from memory"
    );
    assert!(db.read_account("u", Clone::clone).await.unwrap() == folded);

    // Restarted: the same, and the same events.
    drop(db);
    let db = open(&dir, &["u"]).await;
    assert!(db.read_account("u", Clone::clone).await.unwrap() == folded);
    assert_eq!(
        ids(&db.events_after("u", 0, i64::MAX).await.unwrap()),
        ids(&events)
    );
}

/// The phone resends what it never heard back: buffered and lost in a
/// crash, it is placed when it comes again, and once.
#[tokio::test]
async fn a_crash_before_a_flush_loses_nothing_a_phone_resends() {
    let dir = dir();
    let events = training();
    let (stored, lost) = events.split_at(300);
    let db = open(&dir, &["u"]).await;
    db.push_events("u", stored.to_vec()).await.unwrap();
    // Buffered, then the process dies before the next flush (no shutdown
    // flush: dropped).
    db.ledger.stop_flushing();
    db.buffer_events("u", lost.to_vec()).await.unwrap();
    drop(db);
    let db = open(&dir, &["u"]).await;
    assert_eq!(db.head("u").await.unwrap(), 300, "only what was stored");
    // The phone sends everything it never heard back, and some it did.
    db.push_events("u", events[250..].to_vec()).await.unwrap();
    assert_eq!(
        ids(&db.events_after("u", 0, i64::MAX).await.unwrap()),
        ids(&events)
    );
    assert!(
        db.read_account("u", Clone::clone).await.unwrap()
            == Account::fold_without_heart_rate(&events)
    );
}

#[tokio::test]
async fn a_resend_is_placed_once_however_large() {
    let dir = dir();
    let events = training();
    let db = open(&dir, &["u"]).await;
    assert_eq!(
        db.push_events("u", events.clone()).await.unwrap().len(),
        events.len()
    );
    // The whole outbox again, buffered and pushed: nothing new.
    db.buffer_events("u", events.clone()).await.unwrap();
    assert!(db
        .push_events("u", events.clone())
        .await
        .unwrap()
        .is_empty());
    db.flush().await.unwrap();
    assert_eq!(db.head("u").await.unwrap(), events.len() as i64);
    // And after a restart, from the snapshot's ids and the files.
    drop(db);
    let db = open(&dir, &["u"]).await;
    assert!(db
        .push_events("u", events[events.len() - 50..].to_vec())
        .await
        .unwrap()
        .is_empty());
    assert!(db
        .push_events("u", events.clone())
        .await
        .unwrap()
        .is_empty());
}

#[tokio::test]
async fn pushes_at_once_are_each_placed_in_order_once() {
    let db = open(&dir(), &["a", "b"]).await;
    let events = training();
    let mut pushing = tokio::task::JoinSet::new();
    for (n, chunk) in events.chunks(5).enumerate() {
        let user = if n % 2 == 0 { "a" } else { "b" };
        for _ in 0..2 {
            let (db, chunk) = (db.clone(), chunk.to_vec());
            pushing.spawn(async move { db.buffer_events(user, chunk).await.unwrap() });
        }
    }
    while pushing.join_next().await.is_some() {}
    db.flush().await.unwrap();
    let mut held = 0;
    for user in ["a", "b"] {
        let log = db.events_after(user, 0, i64::MAX).await.unwrap();
        let seqs: Vec<i64> = log.iter().map(|e| e.seq).collect();
        assert_eq!(
            seqs,
            (1..=log.len() as i64).collect::<Vec<_>>(),
            "{user}'s places"
        );
        let unique: HashSet<&str> = log.iter().map(|e| e.id.as_str()).collect();
        assert_eq!(unique.len(), log.len(), "{user}'s events once each");
        held += log.len();
    }
    assert_eq!(held, events.len());
}

/// A release that changes how accounts fold: every snapshot is by other
/// rules, so each account is folded again from its files, once.
#[tokio::test]
async fn snapshots_by_other_rules_are_folded_again() {
    let dir = dir();
    let events = training();
    let db = open(&dir, &["u"]).await;
    db.push_events("u", events.clone()).await.unwrap();
    let folded = whole(&db, "u").await;
    db.ledger.sweep_all().await;
    sqlx::query("UPDATE account_snapshots SET fold = 'an older core'")
        .execute(&db.write_pool)
        .await
        .unwrap();
    drop(db);
    let db = open(&dir, &["u"]).await;
    assert!(db.read_account("u", Clone::clone).await.unwrap() == folded);
    let fold: String = sqlx::query_scalar("SELECT fold FROM account_snapshots WHERE user_id = 'u'")
        .fetch_one(&db.read_pool)
        .await
        .unwrap();
    assert_eq!(fold, schlift_core::FOLD, "written down by these rules");
    // A damaged one is folded again too.
    db.ledger.sweep_all().await;
    sqlx::query("UPDATE account_snapshots SET state = x'28b52ffd00'")
        .execute(&db.write_pool)
        .await
        .unwrap();
    drop(db);
    let db = open(&dir, &["u"]).await;
    assert!(db.read_account("u", Clone::clone).await.unwrap() == folded);
}

/// A file written and synced, then a crash before it was indexed: the
/// next start indexes it from its contents, and a temporary file is gone.
#[tokio::test]
async fn a_file_the_index_lacks_is_indexed_on_the_next_start() {
    let dir = dir();
    let events = training();
    let db = open(&dir, &["u"]).await;
    db.push_events("u", events[..100].to_vec()).await.unwrap();
    sqlx::query("DELETE FROM event_files")
        .execute(&db.write_pool)
        .await
        .unwrap();
    drop(db);
    std::fs::write(dir.join("events/9999999999999-000000.parquet.tmp"), b"half").unwrap();
    let db = open(&dir, &["u"]).await;
    assert_eq!(db.head("u").await.unwrap(), 100);
    assert_eq!(
        ids(&db.events_after("u", 0, i64::MAX).await.unwrap()),
        ids(&events[..100])
    );
    assert!(!dir.join("events/9999999999999-000000.parquet.tmp").exists());
}

#[tokio::test]
async fn heart_rate_is_stored_and_sent_but_never_folded() {
    let dir = dir();
    let events = training();
    let beats = events.iter().filter(|e| is_heart_rate(e)).count();
    assert!(beats > 0, "the history has heart rate");
    let db = open(&dir, &["u"]).await;
    db.push_events("u", events.clone()).await.unwrap();
    let stored = db.events_after("u", 0, i64::MAX).await.unwrap();
    assert_eq!(stored.iter().filter(|e| is_heart_rate(e)).count(), beats);
    let account = db.read_account("u", Clone::clone).await.unwrap();
    assert!(account.without_heart_rate);
    assert!(account.workouts.iter().all(|w| w.heart_rate.is_empty()));
}

/// A database from before the ledger: its events move into files, read
/// back exactly, and the table is gone.
#[tokio::test]
async fn events_move_in_from_sqlite() {
    let dir = dir();
    std::fs::create_dir_all(&dir).unwrap();
    let pool = sqlx::SqlitePool::connect(&format!(
        "sqlite://{}/server.sqlite?mode=rwc",
        dir.display()
    ))
    .await
    .unwrap();
    crate::db::migrate::migrate(&pool).await.unwrap();
    sqlx::query(
        "INSERT INTO users (id, username, invite_token, created_at, emoji, color_hex)
         VALUES ('u', 'u', 'i', 0, '', '')",
    )
    .execute(&pool)
    .await
    .unwrap();
    let events = training();
    for (n, event) in events.iter().enumerate() {
        let mut event = event.clone();
        event.seq = n as i64 + 1;
        sqlx::query("INSERT INTO account_events (user_id, seq, id, event) VALUES ('u', ?, ?, ?)")
            .bind(event.seq)
            .bind(&event.id)
            .bind(serde_json::to_string(&event).unwrap())
            .execute(&pool)
            .await
            .unwrap();
    }
    pool.close().await;
    let db = ServerDb::new_in_dir(&dir).await.unwrap();
    let moved = db.events_after("u", 0, i64::MAX).await.unwrap();
    assert_eq!(ids(&moved), ids(&events));
    assert_eq!(moved.last().unwrap().seq, events.len() as i64);
    assert!(
        db.read_account("u", Clone::clone).await.unwrap()
            == Account::fold_without_heart_rate(&events)
    );
    let table: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM sqlite_master WHERE name = 'account_events'")
            .fetch_one(&db.read_pool)
            .await
            .unwrap();
    assert_eq!(table, 0, "the table is dropped");
    // Opened again, nothing moves twice.
    drop(db);
    let db = ServerDb::new_in_dir(&dir).await.unwrap();
    assert_eq!(
        ids(&db.events_after("u", 0, i64::MAX).await.unwrap()),
        ids(&events)
    );
}

/// A partner sees the workout so far from memory, the events not yet
/// stored included, and after a restart from the files.
#[tokio::test]
async fn a_workout_so_far_comes_from_memory_and_after_a_restart_from_the_files() {
    let dir = dir();
    let events = training();
    let start = events
        .iter()
        .rposition(|e| matches!(e.fact, Fact::WorkoutStarted(_)))
        .unwrap();
    let workout = events[start].id.clone();
    let db = open(&dir, &["u"]).await;
    db.push_events("u", events[..start + 3].to_vec())
        .await
        .unwrap();
    db.ledger.stop_flushing();
    db.buffer_events("u", events[start + 3..start + 6].to_vec())
        .await
        .unwrap();
    let shared: Vec<String> = events[start..start + 6]
        .iter()
        .filter(|e| shared_with_partners(&e.fact) && e.workout_id() == Some(&workout))
        .map(|e| e.id.clone())
        .collect();
    assert_eq!(
        ids(&db.workout_events("u", &workout).await.unwrap()),
        shared
    );
    db.flush().await.unwrap();
    drop(db);
    let db = open(&dir, &["u"]).await;
    assert_eq!(
        ids(&db.workout_events("u", &workout).await.unwrap()),
        shared
    );
}

#[tokio::test]
async fn a_push_to_an_account_that_isnt_there_fails() {
    let db = open(&dir(), &["u"]).await;
    let events = training();
    assert!(db
        .push_events("nobody", events[..3].to_vec())
        .await
        .is_err());
    db.push_events("u", events[..3].to_vec()).await.unwrap();
    db.delete_user_account_and_data("u").await.unwrap();
    assert!(db.buffer_events("u", events[3..6].to_vec()).await.is_err());
}
