//! A realistic account as stored — twelve weeks of a seeded lifter's
//! training, every event — must keep folding to the same account. The
//! history (`testdata/golden_events.json.zst`) was recorded once, by an
//! earlier core, and is never rewritten to suit a change; what it folds to,
//! read as the app reads it (`testdata/golden_views.json`), is compared in
//! full. A change that moves those views changes every stored account: if
//! that is intended, `GOLDEN=views` rewrites the views to review in the diff.
//! `GOLDEN=history` records a new history, for a new kind of fact.
//!
//! A second history, `golden_every_fact_*`, holds every kind of fact and is
//! read in full (see the end of this file).

use std::path::{Path, PathBuf};

use schlift_core::account::Account;
use schlift_core::api::{Call, View};
use schlift_core::events::{Event, Fact};
use schlift_core::pb::{GetHomeRequest, GetWorkoutHeartRateRequest, GetWorkoutRequest};
use schlift_native::store::Store;
use schlift_testkit::{edits, history, onboard, Lifter, BUDGET_MINUTES};
use serde_json::{json, Value};

/// When the views are read: the day after the last workout.
const NOW: i64 = 1_790_000_000;
const SEED: u64 = 7;
const WEEKS: u32 = 12;
const PER_WEEK: u32 = 3;
const USER: &str = "6f1c1d6e-6a39-4c55-9a7e-1b8a8f3f2a01";

fn testdata(name: &str) -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("tests/testdata")
        .join(name)
}

/// The history a phone would record, placed by a server in its order.
fn record() -> Vec<Event> {
    let mut store = Store::open(Path::new(":memory:"), USER, "").unwrap();
    let begin = NOW - i64::from(WEEKS) * 7 * 86_400 - 86_400;
    onboard(&mut store, begin).unwrap();
    let mut lifter = Lifter::new(SEED);
    history(&mut store, &mut lifter, WEEKS, PER_WEEK, NOW - 86_400).unwrap();
    let mut events = store.pending().unwrap();
    for (n, event) in events.iter_mut().enumerate() {
        event.seq = n as i64 + 1;
    }
    events
}

/// The account as the app shows it: home, every workout, every lift's
/// progress, the settings.
fn views(account: &Account) -> Value {
    let view = View::new(account, NOW);
    json!({
        "home": view.get_home(GetHomeRequest { budget_minutes: BUDGET_MINUTES }).unwrap(),
        "workouts": view.list_workout_summaries(),
        "progress": view.get_exercise_progress(),
        "settings": view.get_settings(),
    })
}

#[test]
fn the_golden_history_folds_to_the_same_account() {
    let mode = std::env::var("GOLDEN").unwrap_or_default();
    let history_path = testdata("golden_events.json.zst");
    if mode == "history" {
        let json = serde_json::to_vec(&record()).unwrap();
        std::fs::write(
            &history_path,
            zstd::encode_all(json.as_slice(), 19).unwrap(),
        )
        .unwrap();
    }
    let packed = std::fs::read(&history_path).expect("testdata/golden_events.json.zst");
    let events: Vec<Event> =
        serde_json::from_slice(&zstd::decode_all(packed.as_slice()).unwrap()).unwrap();
    let account = Account::fold(&events);
    assert!(
        account.workouts.len() as u32 >= WEEKS * PER_WEEK - 1,
        "the history is training: {} workouts",
        account.workouts.len()
    );
    let seen = views(&account);
    let views_path = testdata("golden_views.json");
    if mode == "views" || mode == "history" {
        std::fs::write(
            &views_path,
            serde_json::to_string_pretty(&seen).unwrap() + "\n",
        )
        .unwrap();
    }
    let expected: Value =
        serde_json::from_str(&std::fs::read_to_string(&views_path).unwrap()).unwrap();
    // Compared through text, as stored: a value would widen each f32.
    let seen: Value = serde_json::from_str(&serde_json::to_string(&seen).unwrap()).unwrap();
    assert!(
        seen == expected,
        "the golden history folds differently: GOLDEN=views rewrites \
         testdata/golden_views.json to see how in the diff"
    );
}

#[test]
fn a_seed_trains_the_same_way() {
    let shape = |events: &[Event]| -> Vec<String> {
        events
            .iter()
            .map(|e| {
                let fact = serde_json::to_value(&e.fact).unwrap();
                format!(
                    "{} {}",
                    e.at,
                    fact.as_object().unwrap().keys().next().unwrap()
                )
            })
            .collect()
    };
    assert_eq!(shape(&record()), shape(&record()));
}

/// The second golden history: every kind of fact, so a change to how any
/// of them folds shows. Recorded once like the first (`GOLDEN=every_fact`
/// records it again), and read in full: every workout's sets, logs and
/// heart rate, and the templates as stored, as well as what the first
/// golden reads.
const EVERY_FACT_SEED: u64 = 11;

fn record_every_fact() -> Vec<Event> {
    let mut store = Store::open(Path::new(":memory:"), USER, "").unwrap();
    let begin = NOW - 30 * 86_400;
    onboard(&mut store, begin).unwrap();
    let mut lifter = Lifter::new(EVERY_FACT_SEED);
    let ended = edits(&mut store, &mut lifter, begin + 86_400).unwrap();
    let mut events = store.pending().unwrap();
    // A workout left running after its last set: its end moved earlier
    // (not an RPC, so made here as the core makes it).
    let mut account = Account::fold(&events);
    let last = account.workouts.last().unwrap().workout.clone();
    let mut call = Call::new(&mut account, ended + 3_600, "golden-end-moved");
    call.move_workout_end(&last.id, last.end_time - 60).unwrap();
    events.append(&mut call.events);
    for (n, event) in events.iter_mut().enumerate() {
        event.seq = n as i64 + 1;
    }
    events
}

/// What `views` reads, and every workout whole (its sets, logs, heart rate)
/// and the templates as stored.
fn views_full(account: &Account) -> Value {
    let view = View::new(account, NOW);
    let workouts: Vec<Value> = account
        .workouts
        .iter()
        .map(|record| {
            let id = record.workout.id.clone();
            json!({
                "workout": view.get_workout(GetWorkoutRequest { workout_id: id.clone() }).unwrap(),
                "heart_rate": view
                    .get_workout_heart_rate(GetWorkoutHeartRateRequest { workout_id: id })
                    .unwrap(),
            })
        })
        .collect();
    json!({
        "views": views(account),
        "workouts": workouts,
        "templates": account.templates,
        "starting_weights": account.starting_weights,
        "overrides": format!("{:?}", account.overrides),
    })
}

fn every_fact_events(record: bool) -> Vec<Event> {
    let path = testdata("golden_every_fact_events.json.zst");
    if record {
        let json = serde_json::to_vec(&record_every_fact()).unwrap();
        std::fs::write(&path, zstd::encode_all(json.as_slice(), 19).unwrap()).unwrap();
    }
    let packed = std::fs::read(&path).expect("testdata/golden_every_fact_events.json.zst");
    serde_json::from_slice(&zstd::decode_all(packed.as_slice()).unwrap()).unwrap()
}

/// The fact's kind, as stored.
fn kind(event: &Event) -> String {
    let fact = serde_json::to_value(&event.fact).unwrap();
    fact.as_object().unwrap().keys().next().unwrap().clone()
}

#[test]
fn the_every_fact_history_holds_every_fact() {
    // Every kind (core's stored_events.rs proves the list is complete).
    let events = every_fact_events(false);
    let kinds: Vec<String> = events.iter().map(kind).collect();
    for name in Fact::KINDS {
        assert!(
            kinds.iter().any(|k| k == name),
            "no {name} in testdata/golden_every_fact_events.json.zst"
        );
    }
    // Each folds: none is refused by the account it lands in.
    let mut account = Account::default();
    for event in &events {
        if let Some(refused) = account.replay(event) {
            panic!("{} ({}) is refused: {refused}", event.id, kind(event));
        }
    }
}

#[test]
fn the_every_fact_history_folds_to_the_same_account() {
    let mode = std::env::var("GOLDEN").unwrap_or_default();
    let account = Account::fold(&every_fact_events(mode == "every_fact"));
    let seen = views_full(&account);
    let views_path = testdata("golden_every_fact_views.json");
    if mode == "every_fact" || mode == "every_fact_views" {
        std::fs::write(
            &views_path,
            serde_json::to_string_pretty(&seen).unwrap() + "\n",
        )
        .unwrap();
    }
    let expected: Value =
        serde_json::from_str(&std::fs::read_to_string(&views_path).unwrap()).unwrap();
    let seen: Value = serde_json::from_str(&serde_json::to_string(&seen).unwrap()).unwrap();
    assert!(
        seen == expected,
        "the every-fact history folds differently: GOLDEN=every_fact_views \
         rewrites testdata/golden_every_fact_views.json to see how in the diff"
    );
}
