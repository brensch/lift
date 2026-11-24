//! A snapshot is only a shortcut: an account restored from a snapshot taken
//! partway through a history, with the rest of the history folded on, must
//! be exactly the account folded from all of it, with heart rate and
//! without (the server's). Checked on the golden histories (twelve weeks of
//! training, and one of every kind of fact) at many cuts, the server reads
//! each account that way (`src/db/accounts.rs`).

use std::path::{Path, PathBuf};

use schlift_core::account::Account;
use schlift_core::events::Event;
use schlift_core::snapshot::{restore, snapshot};

fn history(name: &str) -> Vec<Event> {
    let path: PathBuf = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("tests/testdata")
        .join(name);
    let packed = std::fs::read(&path).unwrap_or_else(|e| panic!("{}: {e}", path.display()));
    serde_json::from_slice(&zstd::decode_all(packed.as_slice()).unwrap()).unwrap()
}

fn fold(events: &[Event], with_heart_rate: bool) -> Account {
    if with_heart_rate {
        Account::fold(events)
    } else {
        Account::fold_without_heart_rate(events)
    }
}

/// Restored at every `every`th cut (and the first and last), then caught up.
fn catches_up(events: &[Event], every: usize) {
    for with_heart_rate in [true, false] {
        let whole = fold(events, with_heart_rate);
        let cuts = (0..=events.len()).filter(|n| n % every == 0 || *n == events.len());
        for cut in cuts {
            let mut account = restore(&snapshot(&fold(&events[..cut], with_heart_rate)))
                .unwrap_or_else(|e| panic!("snapshot after {cut} events doesn't read: {e}"));
            for event in &events[cut..] {
                account.replay(event);
            }
            assert!(
                account == whole,
                "restored after {cut} of {} events (heart rate {with_heart_rate}), \
                 caught up, it isn't the account folded whole",
                events.len()
            );
        }
    }
}

#[test]
fn a_snapshot_caught_up_is_the_whole_fold_of_weeks_of_training() {
    let events = history("golden_events.json.zst");
    assert!(events.len() > 500, "the history is weeks of training");
    catches_up(&events, 97);
}

#[test]
fn a_snapshot_caught_up_is_the_whole_fold_of_every_kind_of_fact() {
    catches_up(&history("golden_every_fact_events.json.zst"), 1);
}

#[test]
fn a_snapshot_reads_back_as_the_account() {
    let events = history("golden_events.json.zst");
    let account = Account::fold_without_heart_rate(&events);
    let written = snapshot(&account);
    assert!(restore(&written).unwrap() == account);
    // Each program once, not once per workout: no more than the account
    // was ever set, and the built-in one.
    let json: serde_json::Value =
        serde_json::from_slice(&zstd::decode_all(written.as_slice()).unwrap()).unwrap();
    let written_programs = json["programs"].as_array().unwrap().len();
    assert!(account.workouts.len() > 10);
    assert!(
        written_programs <= account.programs.len() + 1,
        "{written_programs} programs written for {} set",
        account.programs.len()
    );
}

#[test]
fn a_damaged_snapshot_is_an_error_not_an_account() {
    let written = snapshot(&Account::fold(&history("golden_every_fact_events.json.zst")));
    assert!(restore(&written[..written.len() / 2]).is_err());
    assert!(restore(b"not a snapshot").is_err());
}
