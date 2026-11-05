//! Events already stored, on phones and the server, must keep reading the
//! same. `testdata/stored_events.json` holds one of every fact, written by
//! an earlier core; it is only ever added to. A field renamed or removed
//! (in a fact, or in a message one holds) would be dropped on reading, and
//! fails here; a field added is fine, taking its default.

use schlift_core::events::{Event, Fact};
use serde_json::Value;

const STORED: &str = include_str!("testdata/stored_events.json");

/// Everything in `stored` is in `read`, the same: `read` may hold more.
fn holds(read: &Value, stored: &Value, path: &str) -> Result<(), String> {
    match (read, stored) {
        (Value::Object(read), Value::Object(stored)) => {
            for (key, value) in stored {
                let path = format!("{path}.{key}");
                let read = read.get(key).ok_or(format!("{path} was dropped"))?;
                holds(read, value, &path)?;
            }
            Ok(())
        }
        (Value::Array(read), Value::Array(stored)) if read.len() == stored.len() => read
            .iter()
            .zip(stored)
            .enumerate()
            .try_for_each(|(i, (read, stored))| holds(read, stored, &format!("{path}[{i}]"))),
        _ if read == stored => Ok(()),
        _ => Err(format!("{path} reads as {read}, stored as {stored}")),
    }
}

#[test]
fn stored_events_read_the_same() {
    let stored: Vec<Value> = serde_json::from_str(STORED).unwrap();
    for value in &stored {
        let event: Event = serde_json::from_value(value.clone())
            .unwrap_or_else(|e| panic!("{value} no longer reads: {e}"));
        // With every_fact_is_stored, this proves each variant is in
        // Fact::KINDS: one missing would read back as Unknown and fold as
        // nothing.
        assert!(
            !matches!(event.fact, Fact::Unknown(_)),
            "{value} reads as a kind this version doesn't know: add it to Fact::KINDS"
        );
        // Through text, as it is stored: a value would widen each f32.
        let read: Value = serde_json::from_str(&serde_json::to_string(&event).unwrap()).unwrap();
        if let Err(problem) = holds(&read, value, &event.id) {
            panic!("{problem}");
        }
    }
}

#[test]
fn every_fact_is_stored() {
    // Serde names every variant when refusing one it doesn't know.
    let refused = serde_json::from_str::<Fact>(r#"{"":null}"#)
        .unwrap_err()
        .to_string();
    let (_, names) = refused.split_once("expected one of ").unwrap();
    let stored: Vec<Value> = serde_json::from_str(STORED).unwrap();
    for name in names.split(", ") {
        let name = name.split('`').nth(1).unwrap();
        assert!(
            stored.iter().any(|event| event.get(name).is_some()),
            "no {name} in testdata/stored_events.json: add one"
        );
    }
}
