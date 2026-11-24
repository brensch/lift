//! A workout's heart rate, packed: what a phone sends reads back as the
//! readings it recorded, an event stored before packing still reads, and a
//! packed series is a fraction of the arrays' size.

use schlift_core::events::{Event, Fact, HeartRateRecorded};
use schlift_core::pb::WorkoutHeartRatePoint;

fn readings(count: usize) -> Vec<WorkoutHeartRatePoint> {
    (0..count)
        .map(|n| WorkoutHeartRatePoint {
            sampled_at: 1_790_000_000_000 + n as i64 * 2_000 + (n as i64 % 7) * 13,
            bpm: 100.0 + ((n as f32) / 30.0).sin() * 40.0,
        })
        .collect()
}

#[test]
fn packed_heart_rate_reads_back_as_recorded() {
    let samples = readings(1_800);
    let recorded = HeartRateRecorded::new("w", &samples);
    assert!(recorded.gaps_ms.is_empty() && recorded.bpm.is_empty());
    let back = recorded.samples().unwrap();
    assert_eq!(back.len(), samples.len());
    for (b, s) in back.iter().zip(&samples) {
        assert_eq!(b.sampled_at, s.sampled_at);
        assert_eq!(b.bpm, s.bpm.round());
    }
    assert_eq!(recorded.len(), 1_800);
    // Through an event, as stored and sent.
    let event = Event {
        seq: 3,
        id: "e".into(),
        at: 1,
        fact: Fact::HeartRateRecorded(recorded.clone()),
    };
    let json = serde_json::to_string(&event).unwrap();
    let read: Event = serde_json::from_str(&json).unwrap();
    assert_eq!(read, event);
    // Far smaller than the arrays it replaces.
    let unpacked = HeartRateRecorded {
        packed: String::new(),
        gaps_ms: recorded.readings().unwrap().0,
        bpm: recorded.readings().unwrap().1,
        ..recorded.clone()
    };
    let arrays = serde_json::to_string(&unpacked).unwrap().len();
    assert!(
        recorded.packed.len() * 3 < arrays,
        "packed {} bytes, arrays {arrays}",
        recorded.packed.len()
    );
}

#[test]
fn heart_rate_stored_as_arrays_still_reads() {
    let json = r#"{"workout_id":"w","start_ms":1000,"gaps_ms":[2000,2000],"bpm":[100,110,120]}"#;
    let recorded: HeartRateRecorded = serde_json::from_str(json).unwrap();
    let samples = recorded.samples().unwrap();
    assert_eq!(
        samples.iter().map(|s| s.sampled_at).collect::<Vec<_>>(),
        [1000, 3000, 5000]
    );
    assert_eq!(recorded.len(), 3);
}

#[test]
fn a_damaged_packed_series_reads_as_nothing() {
    let recorded = HeartRateRecorded {
        packed: "not base64 at all!".into(),
        ..Default::default()
    };
    assert!(recorded.samples().is_none());
    assert_eq!(recorded.len(), 0);
}
