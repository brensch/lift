//! A realistic account as stored — twelve weeks of a seeded lifter's
//! training, every event — must keep folding to the same account. The
//! history (`testdata/golden_events.json.zst`) was recorded once, by an
//! earlier core, and is never rewritten to suit a change; what it folds to,
//! read as the app reads it (`testdata/golden_views.json`), is compared in
//! full. A change that moves those views changes every stored account: if
//! that is intended, `GOLDEN=views` rewrites the views to review in the diff.
//! `GOLDEN=history` records a new history, for a new kind of fact.

use std::path::{Path, PathBuf};

use schlift_core::account::Account;
use schlift_core::api::View;
use schlift_core::events::Event;
use schlift_core::pb::GetHomeRequest;
use schlift_native::store::Store;
use schlift_testkit::{history, onboard, Lifter, BUDGET_MINUTES};
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
