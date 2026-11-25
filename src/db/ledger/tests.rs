//! The ledger against what it promises: a workout's events are held until
//! it ends and then written, with the snapshot, once; every read is the
//! fold of every event, written or held; nothing in normal running reads
//! the event files; after a restart the phones' resends are placed once;
//! memory past its budget is written early; heart rate is stored typed and
//! fetched by workout; compaction changes the files and nothing else.

use super::*;
use crate::db::ServerDb;
use schlift_core::api::Call;
use schlift_core::pb::{
    workout_mutation, AppendWorkoutMutationsRequest, CompleteSetRequest, EndWorkoutRequest,
    StartWorkoutRequest, WorkoutHeartRatePoint, WorkoutMutation,
};
use uuid::Uuid;

fn dir() -> PathBuf {
    std::env::temp_dir().join(format!("lift-ledger-test-{}", Uuid::new_v4()))
}

/// Holding a workout until it ends (a long abandon time), writing as soon
/// as it does.
fn holding() -> Timing {
    Timing {
        batch_every: Duration::from_millis(10),
        abandoned: Duration::from_secs(3600),
        quiet: Duration::from_millis(30),
        memory_budget: 1 << 30,
    }
}

async fn open(dir: &Path, timing: Timing) -> ServerDb {
    let db = ServerDb::new_with_timing(dir, timing).await.unwrap();
    if db.get_user("u").await.unwrap().is_none() {
        db.create_user_with_id("u", "u").await.unwrap();
    }
    db
}

/// A phone: its account, and what it recorded.
struct Phone {
    account: Account,
}

impl Phone {
    fn new() -> Self {
        Self {
            account: Account::default(),
        }
    }

    fn write(&mut self, now: i64, f: impl FnOnce(&mut Call)) -> Vec<Event> {
        let mut call = Call::new(&mut self.account, now, Uuid::new_v4().to_string());
        f(&mut call);
        std::mem::take(&mut call.events)
    }

    /// A workout: its start, `sets` sets done, then (with `end`) its heart
    /// rate and its end. The events, in order.
    fn workout(&mut self, now: i64, sets: usize, end: bool) -> Vec<Event> {
        let mut workout_id = String::new();
        let mut events = self.write(now, |call| {
            let started = call
                .start_workout(StartWorkoutRequest {
                    exercises: vec!["pull_up".to_string()],
                    ..Default::default()
                })
                .unwrap();
            workout_id = started.id;
        });
        for n in 0..sets {
            let set = self
                .account
                .workout(&workout_id)
                .unwrap()
                .proposed_sets
                .get(n)
                .cloned();
            let Some(set) = set else { break };
            let at = now + 60 * (n as i64 + 1);
            events.extend(self.write(at, |call| {
                call.append_workout_mutations(AppendWorkoutMutationsRequest {
                    mutations: vec![WorkoutMutation {
                        mutation: Some(workout_mutation::Mutation::CompleteSet(
                            CompleteSetRequest {
                                workout_id: workout_id.clone(),
                                proposed_set_id: set.id.clone(),
                                actual_reps: 8,
                                actual_weight: 0.0,
                                completed_at: at,
                            },
                        )),
                    }],
                })
                .unwrap();
            }));
        }
        if end {
            let samples: Vec<WorkoutHeartRatePoint> = (0..300)
                .map(|n| WorkoutHeartRatePoint {
                    sampled_at: now * 1000 + n * 2000,
                    bpm: 110.0 + (n % 30) as f32,
                })
                .collect();
            let id = workout_id.clone();
            events.extend(self.write(now + 900, |call| {
                call.record_heart_rate(&id, &samples).unwrap();
            }));
            events.extend(self.write(now + 900, |call| {
                call.end_workout(EndWorkoutRequest {
                    workout_id: workout_id.clone(),
                    ended_at: now + 900,
                })
                .unwrap();
            }));
        }
        events
    }
}

fn without_heart_rate(account: &Account) -> Account {
    let mut account = account.clone();
    account.without_heart_rate = true;
    for w in &mut account.workouts {
        std::sync::Arc::make_mut(w).heart_rate.clear();
    }
    account
}

/// Until written to `head`, within a second.
async fn written(db: &ServerDb, head: i64) {
    for _ in 0..200 {
        if db.head("u").await.unwrap() >= head {
            return;
        }
        tokio::time::sleep(Duration::from_millis(5)).await;
    }
    panic!("not written to {head}: {}", db.head("u").await.unwrap());
}

#[tokio::test]
async fn a_workout_is_held_until_it_ends_then_written_once_with_its_snapshot() {
    let dir = dir();
    let db = open(&dir, holding()).await;
    let mut phone = Phone::new();
    let now = now_unix() - 3600;
    let events = phone.workout(now, 3, true);
    let (during, end) = events.split_at(events.len() - 2);
    db.buffer_events("u", during.to_vec(), true).await.unwrap();
    tokio::time::sleep(Duration::from_millis(100)).await;
    assert_eq!(
        db.head("u").await.unwrap(),
        0,
        "held while the workout runs"
    );
    // A read mid-set has every set done so far.
    let read = db.read_account("u", Clone::clone).await.unwrap();
    assert_eq!(read, Account::fold_without_heart_rate(during));
    // The end: written, each event once, in order, with its snapshot.
    db.buffer_events("u", end.to_vec(), false).await.unwrap();
    written(&db, events.len() as i64).await;
    let stored = db.events_after("u", 0, i64::MAX).await.unwrap();
    assert_eq!(
        stored.iter().map(|e| e.id.clone()).collect::<Vec<_>>(),
        events.iter().map(|e| e.id.clone()).collect::<Vec<_>>()
    );
    assert_eq!(stored.last().unwrap().seq, events.len() as i64);
    let (snapshot, seq, last_id) = db.snapshot_now("u").await.unwrap();
    assert_eq!(seq, events.len() as i64);
    assert_eq!(last_id, events.last().unwrap().id);
    let (account, _) = schlift_core::snapshot::restore(&snapshot).unwrap();
    assert_eq!(account, Account::fold_without_heart_rate(&events));
    assert_eq!(without_heart_rate(&phone.account), account);
}

/// After a restart the server holds the snapshots only; the phone sends
/// what it holds unacked again, and it is placed once.
#[tokio::test]
async fn after_a_restart_the_phones_resend_and_each_event_is_placed_once() {
    let dir = dir();
    let db = open(&dir, holding()).await;
    let mut phone = Phone::new();
    let now = now_unix() - 7200;
    let first = phone.workout(now, 2, true);
    db.buffer_events("u", first.clone(), true).await.unwrap();
    written(&db, first.len() as i64).await;
    let second = phone.workout(now + 3600, 2, false);
    db.buffer_events("u", second.clone(), false).await.unwrap();
    db.ledger.stop_writing();
    drop(db);
    let db = open(&dir, holding()).await;
    assert_eq!(
        db.head("u").await.unwrap(),
        first.len() as i64,
        "the held workout is gone"
    );
    // The phone resends everything it holds unacked: the second workout, and
    // (it lost the first's ack) the first again.
    let resend: Vec<Event> = first.iter().chain(&second).cloned().collect();
    let ids: Vec<String> = resend.iter().map(|e| e.id.clone()).collect();
    let written_before = db.written_among("u", &ids).await.unwrap();
    assert_eq!(
        written_before.len(),
        first.len(),
        "the first is known written"
    );
    let fresh: Vec<Event> = resend
        .into_iter()
        .filter(|e| !written_before.contains(&e.id))
        .collect();
    db.buffer_events("u", fresh, true).await.unwrap();
    db.flush().await.unwrap();
    let stored = db.events_after("u", 0, i64::MAX).await.unwrap();
    let unique: HashSet<&str> = stored.iter().map(|e| e.id.as_str()).collect();
    assert_eq!(unique.len(), stored.len(), "each once");
    assert_eq!(stored.len(), first.len() + second.len());
    let read = db.read_account("u", Clone::clone).await.unwrap();
    assert_eq!(read, without_heart_rate(&phone.account));
}

/// Nothing a phone or an assistant does reads the event files: they are
/// moved away, and every read, open and write still works.
#[tokio::test]
async fn normal_running_never_reads_the_event_files() {
    let dir = dir();
    let db = open(&dir, holding()).await;
    let mut phone = Phone::new();
    let now = now_unix() - 7200;
    let first = phone.workout(now, 2, true);
    db.buffer_events("u", first.clone(), true).await.unwrap();
    written(&db, first.len() as i64).await;
    drop(db);
    std::fs::rename(dir.join("events"), dir.join("events-away")).unwrap();
    std::fs::create_dir_all(dir.join("events")).unwrap();
    let db = open(&dir, holding()).await;
    let second = phone.workout(now + 3600, 2, true);
    db.buffer_events("u", second.clone(), true).await.unwrap();
    let all = first.len() + second.len();
    written(&db, all as i64).await;
    let read = db.read_account("u", Clone::clone).await.unwrap();
    assert_eq!(read, without_heart_rate(&phone.account));
    let (snapshot, seq, _) = db.snapshot_now("u").await.unwrap();
    assert_eq!(seq, all as i64);
    assert_eq!(schlift_core::snapshot::restore(&snapshot).unwrap().0, read);
}

#[tokio::test]
async fn past_the_memory_budget_workouts_are_written_early() {
    let dir = dir();
    let db = open(
        &dir,
        Timing {
            memory_budget: 4_096,
            ..holding()
        },
    )
    .await;
    let mut phone = Phone::new();
    let events = phone.workout(now_unix() - 600, 4, false);
    db.buffer_events("u", events.clone(), true).await.unwrap();
    // The workout runs on, but memory is short: written (and acked) now.
    written(&db, events.len() as i64).await;
    assert!(db.ledger.held.load(Ordering::Relaxed) < 4_096);
}

#[tokio::test]
async fn heart_rate_is_stored_typed_and_fetched_by_workout() {
    let dir = dir();
    let db = open(&dir, holding()).await;
    let mut phone = Phone::new();
    let events = phone.workout(now_unix() - 3600, 1, true);
    let workout = events[0].id.clone();
    db.buffer_events("u", events.clone(), true).await.unwrap();
    written(&db, events.len() as i64).await;
    let beats = db.workout_heart_rate("u", &workout).await.unwrap().unwrap();
    let recorded = phone.account.workout(&workout).unwrap().heart_rate.clone();
    assert!(!recorded.is_empty());
    assert_eq!(
        beats.t_ms,
        recorded.iter().map(|s| s.sampled_at).collect::<Vec<_>>()
    );
    assert_eq!(
        beats.bpm,
        recorded.iter().map(|s| s.bpm as u16).collect::<Vec<_>>()
    );
    assert!(db
        .workout_heart_rate("u", "no such workout")
        .await
        .unwrap()
        .is_none());
}

/// A release that changes the rules: the snapshot is by other ones, and
/// the account is folded again from the files, once.
#[tokio::test]
async fn a_snapshot_by_other_rules_is_folded_again_from_the_files() {
    let dir = dir();
    let db = open(&dir, holding()).await;
    let mut phone = Phone::new();
    let events = phone.workout(now_unix() - 3600, 2, true);
    db.buffer_events("u", events.clone(), true).await.unwrap();
    written(&db, events.len() as i64).await;
    drop(db);
    let pool = sqlx::SqlitePool::connect(&format!("sqlite://{}/server.sqlite", dir.display()))
        .await
        .unwrap();
    sqlx::query("UPDATE account_snapshots SET fold = 'an older core'")
        .execute(&pool)
        .await
        .unwrap();
    pool.close().await;
    let db = open(&dir, holding()).await;
    let read = db.read_account("u", Clone::clone).await.unwrap();
    assert_eq!(read, Account::fold_without_heart_rate(&events));
    // The next write folds onto it and stamps it by these rules.
    let more = phone.workout(now_unix() - 600, 1, true);
    db.buffer_events("u", more.clone(), true).await.unwrap();
    written(&db, (events.len() + more.len()) as i64).await;
    let (snapshot, _, _) = db.snapshot_now("u").await.unwrap();
    assert!(schlift_core::snapshot::restore(&snapshot).is_ok());
}

#[tokio::test]
async fn a_refold_on_open_saves_the_snapshot_under_the_new_fold() {
    // A fold change (any deploy bumps schlift_core::FOLD) leaves every snapshot
    // stale. The first open re-folds from the files; it must then save that so
    // the next open reads the snapshot, not the files, again.
    let dir = dir();
    let db = open(&dir, holding()).await;
    let mut phone = Phone::new();
    let events = phone.workout(now_unix() - 3600, 2, true);
    db.buffer_events("u", events.clone(), true).await.unwrap();
    written(&db, events.len() as i64).await;
    let pool = sqlx::SqlitePool::connect(&format!("sqlite://{}/server.sqlite", dir.display()))
        .await
        .unwrap();
    sqlx::query("UPDATE account_snapshots SET fold = 'an older core'")
        .execute(&pool)
        .await
        .unwrap();
    // The open re-folds the stale snapshot and writes it back with this fold.
    let (state, _, _) = db.snapshot_now("u").await.unwrap();
    assert_eq!(
        schlift_core::snapshot::restore(&state).unwrap().0,
        Account::fold_without_heart_rate(&events),
    );
    let saved: String =
        sqlx::query_scalar("SELECT fold FROM account_snapshots WHERE user_id = 'u'")
            .fetch_one(&pool)
            .await
            .unwrap();
    assert_eq!(
        saved,
        schlift_core::FOLD,
        "the re-fold was saved under the current fold, so the next open won't read the files"
    );
    pool.close().await;
}

#[tokio::test]
async fn a_push_to_an_account_that_isnt_there_fails() {
    let db = open(&dir(), holding()).await;
    let mut phone = Phone::new();
    let events = phone.workout(now_unix() - 600, 1, true);
    assert!(db.push_events("nobody", events.clone()).await.is_err());
    db.push_events("u", events[..2].to_vec()).await.unwrap();
    db.delete_user_account_and_data("u").await.unwrap();
    assert!(db
        .buffer_events("u", events[2..].to_vec(), true)
        .await
        .is_err());
}

/// An old database's events move into the files, each account with its
/// snapshot, and the table goes.
#[tokio::test]
async fn events_move_in_from_sqlite_with_their_snapshots() {
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
    let mut phone = Phone::new();
    let events = phone.workout(now_unix() - 3600, 3, true);
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
    let db = open(&dir, holding()).await;
    assert_eq!(db.head("u").await.unwrap(), events.len() as i64);
    assert_eq!(
        db.read_account("u", Clone::clone).await.unwrap(),
        Account::fold_without_heart_rate(&events)
    );
    assert_eq!(
        db.events_after("u", 0, i64::MAX).await.unwrap().len(),
        events.len()
    );
    // Its heart rate, by workout, as written since.
    let workout = events[0].id.clone();
    let beats = db.workout_heart_rate("u", &workout).await.unwrap().unwrap();
    assert_eq!(
        beats.t_ms,
        phone
            .account
            .workout(&workout)
            .unwrap()
            .heart_rate
            .iter()
            .map(|s| s.sampled_at)
            .collect::<Vec<_>>()
    );
    let table: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM sqlite_master WHERE name = 'account_events'")
            .fetch_one(&db.read_pool)
            .await
            .unwrap();
    assert_eq!(table, 0);
}

/// Compaction merges closed hours' and days' batch files into one: the
/// same events, the index on the new file, the old files gone, heart rate
/// still fetched by workout.
#[tokio::test]
async fn compaction_changes_the_files_and_nothing_else() {
    let dir = dir();
    let db = open(&dir, holding()).await;
    let mut phone = Phone::new();
    let mut all = Vec::new();
    let mut workouts = Vec::new();
    for n in 0..4 {
        let events = phone.workout(now_unix() - 4 * 3600 + n * 1000, 1, true);
        workouts.push(events[0].id.clone());
        all.extend(events.clone());
        db.buffer_events("u", events, true).await.unwrap();
        written(&db, all.len() as i64).await;
    }
    let before = files::list(&db.ledger.events_dir()).unwrap();
    assert!(before.len() >= 4, "a batch file each: {before:?}");
    // Two days on: every hour and the day are closed.
    compact::compact(&db.ledger, now_ms() + 2 * 86_400_000)
        .await
        .unwrap();
    tokio::time::sleep(Duration::from_millis(50)).await;
    let after = files::list(&db.ledger.events_dir()).unwrap();
    assert_eq!(after.len(), 1, "{after:?}");
    assert!(after[0].contains("/d-"), "{after:?}");
    let stored = db.events_after("u", 0, i64::MAX).await.unwrap();
    assert_eq!(
        stored.iter().map(|e| e.id.clone()).collect::<Vec<_>>(),
        all.iter().map(|e| e.id.clone()).collect::<Vec<_>>()
    );
    let indexed: Vec<String> = sqlx::query_scalar("SELECT DISTINCT file FROM event_files")
        .fetch_all(&db.read_pool)
        .await
        .unwrap();
    assert_eq!(indexed, after);
    for workout in &workouts {
        assert!(db.workout_heart_rate("u", workout).await.unwrap().is_some());
    }
    assert_eq!(files::list(&db.ledger.beats_dir()).unwrap().len(), 1);
    // Done again, nothing changes.
    compact::compact(&db.ledger, now_ms() + 2 * 86_400_000)
        .await
        .unwrap();
    assert_eq!(files::list(&db.ledger.events_dir()).unwrap(), after);
}

/// Deleting an account leaves it unreadable at once (its index and snapshot
/// cascade away); compaction then erases its rows from the shared files,
/// while another account in the same files is untouched.
#[tokio::test]
async fn a_deleted_accounts_rows_leave_the_files_on_compaction() {
    let dir = dir();
    let db = open(&dir, holding()).await;
    db.create_user_with_id("v", "v").await.unwrap();
    let mut up = Phone::new();
    let mut vp = Phone::new();
    let mut u_all = Vec::new();
    let mut v_all = Vec::new();
    for n in 0..3 {
        let ue = up.workout(now_unix() - 4 * 3600 + n * 1000, 1, true);
        u_all.extend(ue.clone());
        db.buffer_events("u", ue, true).await.unwrap();
        let ve = vp.workout(now_unix() - 4 * 3600 + n * 1000, 1, true);
        v_all.extend(ve.clone());
        db.buffer_events("v", ve, true).await.unwrap();
    }
    db.flush().await.unwrap();
    // Both accounts' rows share the batch files.
    assert!(!db.events_after("u", 0, i64::MAX).await.unwrap().is_empty());

    db.delete_user_account_and_data("u").await.unwrap();
    // Unreadable at once: no index, nothing to read.
    assert!(db.events_after("u", 0, i64::MAX).await.unwrap().is_empty());
    let tombstoned: i64 =
        sqlx::query_scalar("SELECT count(*) FROM purged_accounts WHERE user_id = 'u'")
            .fetch_one(&db.read_pool)
            .await
            .unwrap();
    assert_eq!(tombstoned, 1);

    // Two days on so the hours and day close: the merge drops u's rows, and
    // the purge pass sweeps any file it missed.
    compact::compact(&db.ledger, now_ms() + 2 * 86_400_000)
        .await
        .unwrap();
    tokio::time::sleep(Duration::from_millis(50)).await;

    // u is gone from every events file; v is whole.
    for file in files::list(&db.ledger.events_dir()).unwrap() {
        let path = db.ledger.events_dir().join(&file);
        let u_rows = files::read_rows(&path, Some("u")).unwrap();
        assert!(
            u_rows.is_empty(),
            "u still in {file}: {} rows",
            u_rows.len()
        );
    }
    assert_eq!(
        db.events_after("v", 0, i64::MAX)
            .await
            .unwrap()
            .iter()
            .map(|e| e.id.clone())
            .collect::<Vec<_>>(),
        v_all.iter().map(|e| e.id.clone()).collect::<Vec<_>>()
    );
    // u's heart rate is gone from the files too.
    for file in files::list(&db.ledger.beats_dir()).unwrap() {
        let path = db.ledger.beats_dir().join(&file);
        assert!(files::read_all_beats(&path, Some("u")).unwrap().is_empty());
    }
    // The worklist drained, and with it the tombstone (nothing left to scrub).
    let pending: i64 = sqlx::query_scalar("SELECT count(*) FROM purge_files")
        .fetch_one(&db.read_pool)
        .await
        .unwrap();
    assert_eq!(pending, 0, "every captured file was rewritten");
    let tombstones: i64 = sqlx::query_scalar("SELECT count(*) FROM purged_accounts")
        .fetch_one(&db.read_pool)
        .await
        .unwrap();
    assert_eq!(
        tombstones, 0,
        "the tombstone is dropped once scrubbing is done"
    );
}

/// A workout whose start was written before the rest (a server stopped
/// mid-workout writes what it holds): after the restart its sets are still
/// held for its end, not written one by one as other writes are.
#[tokio::test]
async fn a_workout_started_before_a_restart_is_still_held_until_it_ends() {
    let dir = dir();
    let db = open(&dir, holding()).await;
    let mut phone = Phone::new();
    let events = phone.workout(now_unix() - 3600, 3, true);
    let (start, rest) = events.split_at(3);
    db.buffer_events("u", start.to_vec(), true).await.unwrap();
    db.flush().await.unwrap();
    drop(db);
    let db = open(&dir, holding()).await;
    let head = db.head("u").await.unwrap();
    assert_eq!(head, 3);
    let (during, end) = rest.split_at(rest.len() - 2);
    db.buffer_events("u", during.to_vec(), true).await.unwrap();
    // Well past the quiet time other writes wait.
    tokio::time::sleep(Duration::from_millis(200)).await;
    assert_eq!(db.head("u").await.unwrap(), head, "held for the end");
    db.buffer_events("u", end.to_vec(), false).await.unwrap();
    written(&db, events.len() as i64).await;
}

/// A file no index names (a write that died before it committed, or a
/// merge's input already merged) is set aside at start and never read: the
/// events in it are read once, from the file the index names.
#[tokio::test]
async fn a_file_no_index_names_is_set_aside_at_start() {
    let dir = dir();
    let db = open(&dir, holding()).await;
    let mut phone = Phone::new();
    let events = phone.workout(now_unix() - 3600, 2, true);
    db.buffer_events("u", events.clone(), true).await.unwrap();
    written(&db, events.len() as i64).await;
    let written_files = files::list(&db.ledger.events_dir()).unwrap();
    drop(db);
    let events_dir = dir.join("events");
    let copy = written_files[0].replace("/b-", "/b-9");
    std::fs::copy(events_dir.join(&written_files[0]), events_dir.join(&copy)).unwrap();
    std::fs::write(events_dir.join("half.parquet.tmp"), b"half").unwrap();
    let db = open(&dir, holding()).await;
    assert_eq!(files::list(&events_dir).unwrap(), written_files);
    assert!(events_dir.join(files::ORPHANED).join(&copy).exists());
    assert!(!events_dir.join("half.parquet.tmp").exists());
    assert_eq!(
        db.events_after("u", 0, i64::MAX).await.unwrap().len(),
        events.len()
    );
}

/// An account whose snapshot row is gone (lost, or from a build that
/// deleted them) still has its head and its account, from the files: a
/// phone that opens is never sent it empty.
#[tokio::test]
async fn an_account_without_its_snapshot_is_folded_from_the_files() {
    let dir = dir();
    let db = open(&dir, holding()).await;
    let mut phone = Phone::new();
    let events = phone.workout(now_unix() - 3600, 2, true);
    db.buffer_events("u", events.clone(), true).await.unwrap();
    written(&db, events.len() as i64).await;
    drop(db);
    let pool = sqlx::SqlitePool::connect(&format!("sqlite://{}/server.sqlite", dir.display()))
        .await
        .unwrap();
    sqlx::query("DELETE FROM account_snapshots")
        .execute(&pool)
        .await
        .unwrap();
    pool.close().await;
    let db = open(&dir, holding()).await;
    assert_eq!(db.head("u").await.unwrap(), events.len() as i64);
    let (snapshot, seq, _) = db.snapshot_now("u").await.unwrap();
    assert_eq!(seq, events.len() as i64);
    let (account, _) = schlift_core::snapshot::restore(&snapshot).unwrap();
    assert_eq!(account, Account::fold_without_heart_rate(&events));
}

#[tokio::test]
async fn an_account_that_cant_be_written_doesnt_stop_the_others() {
    let dir = dir();
    let db = open(&dir, holding()).await;
    db.create_user_with_id("v", "v").await.unwrap();
    let (mut mine, mut theirs) = (Phone::new(), Phone::new());
    let first = mine.workout(now_unix() - 7200, 1, true);
    db.buffer_events("u", first.clone(), true).await.unwrap();
    written(&db, first.len() as i64).await;
    drop(db);
    // u's snapshot no longer reads, by these rules.
    let pool = sqlx::SqlitePool::connect(&format!("sqlite://{}/server.sqlite", dir.display()))
        .await
        .unwrap();
    sqlx::query("UPDATE account_snapshots SET state = x'00' WHERE user_id = 'u'")
        .execute(&pool)
        .await
        .unwrap();
    pool.close().await;
    let db = open(&dir, holding()).await;
    // Both end a workout in the same batch: v's is written, u's is held.
    let more = mine.workout(now_unix() - 3600, 1, true);
    let other = theirs.workout(now_unix() - 3600, 1, true);
    db.buffer_events("u", more, true).await.unwrap();
    db.buffer_events("v", other.clone(), true).await.unwrap();
    for _ in 0..200 {
        if db.head("v").await.unwrap() >= other.len() as i64 {
            break;
        }
        tokio::time::sleep(Duration::from_millis(5)).await;
    }
    assert_eq!(db.head("v").await.unwrap(), other.len() as i64);
    assert_eq!(db.head("u").await.unwrap(), first.len() as i64);
}

#[tokio::test]
async fn a_push_planning_more_sets_than_any_workout_holds_is_refused() {
    let dir = dir();
    let db = open(&dir, holding()).await;
    let mut phone = Phone::new();
    let mut events = phone.workout(now_unix() - 600, 0, false);
    let workout_id = events[0].id.clone();
    // Twenty-one adjusts of a hundred sets: past what's held at once.
    for n in 0..21 {
        let mut adjust = events[0].clone();
        adjust.id = format!("adjust-{n}");
        adjust.fact = Fact::ExerciseAdjusted(schlift_core::events::ExerciseAdjusted {
            workout_id: workout_id.clone(),
            exercise: "pull_up".to_string(),
            sets: 100,
            ..Default::default()
        });
        events.push(adjust);
    }
    let refused = db.buffer_events("u", events, true).await.unwrap_err();
    assert!(refused.downcast_ref::<Refused>().is_some(), "{refused}");
}
