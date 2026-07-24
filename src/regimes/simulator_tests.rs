//! Generates and pins `testdata/regime_timelines.json`.
//!
//! The fixture serves two purposes: it is a regression test on the regime state
//! machines as a whole (any change to progression, stalling or deloading shows
//! up as a diff), and it is the reference the browser-based regime explorer in
//! `docs/regime-explorer.html` is validated against by
//! `scripts/check_regime_parity.mjs`.
//!
//! Regenerate with:
//!
//! ```text
//! LIFT_SNAPSHOT_TIMELINE=1 cargo test regime_timeline
//! node scripts/check_regime_parity.mjs
//! ```

use crate::program_state::set_f32;
use crate::regimes::get_regime;
use crate::regimes::simulator::{simulate, ScriptedSession, SimulatedSession};
use schlift::workout::v1::RegimeType;

fn fixture_path() -> std::path::PathBuf {
    std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("testdata/regime_timelines.json")
}

/// Every scenario the fixture covers, named so a diff says what changed.
fn scenarios() -> Vec<(&'static str, Vec<ScriptedSession>)> {
    vec![
        // A clean run: three sessions a week, everything hit.
        (
            "steady_progress",
            (0..12).map(|_| ScriptedSession::hit(2)).collect(),
        ),
        // Progress, then repeated misses — exercises the stall counter and the
        // stall-triggered deload.
        (
            "stalling_out",
            (0..5)
                .map(|_| ScriptedSession::hit(2))
                .chain((0..7).map(|_| ScriptedSession::missed(2)))
                .collect(),
        ),
        // Trains, disappears for six weeks, comes back and keeps going. This is
        // the layoff deload path.
        (
            "comeback_after_layoff",
            (0..5)
                .map(|_| ScriptedSession::hit(2))
                .chain(std::iter::once(ScriptedSession::hit(45)))
                .chain((0..6).map(|_| ScriptedSession::hit(2)))
                .collect(),
        ),
        // A shorter break that lands in the 90% band, then a longer one in 80%.
        (
            "two_layoffs",
            (0..4)
                .map(|_| ScriptedSession::hit(2))
                .chain(std::iter::once(ScriptedSession::hit(16)))
                .chain((0..4).map(|_| ScriptedSession::hit(2)))
                .chain(std::iter::once(ScriptedSession::hit(60)))
                .chain((0..4).map(|_| ScriptedSession::hit(2)))
                .collect(),
        ),
        // Realistic: mostly hitting, occasionally missing.
        (
            "occasional_misses",
            (0..12)
                .map(|i| {
                    if i % 5 == 4 {
                        ScriptedSession::missed(2)
                    } else {
                        ScriptedSession::hit(2)
                    }
                })
                .collect(),
        ),
    ]
}

/// Starting points to cover: the regime default, plus a lighter and heavier
/// lifter, so parity is checked across a range rather than one seed.
fn starting_points(regime_type: RegimeType) -> Vec<(&'static str, Vec<(&'static str, f32)>)> {
    match regime_type {
        RegimeType::Linear5x5 => vec![
            ("default", vec![]),
            (
                "intermediate",
                vec![
                    ("squat_weight", 275.0),
                    ("bench_press_weight", 205.0),
                    ("deadlift_weight", 335.0),
                    ("overhead_press_weight", 135.0),
                    ("barbell_row_weight", 185.0),
                ],
            ),
        ],
        RegimeType::Gzclp => vec![
            ("default", vec![]),
            (
                "novice",
                vec![
                    ("squat_t1_weight", 135.0),
                    ("deadlift_t1_weight", 155.0),
                    ("bench_press_t2_weight", 75.0),
                    ("overhead_press_t2_weight", 55.0),
                    ("barbell_row_t2_weight", 75.0),
                ],
            ),
        ],
        RegimeType::Unspecified => vec![("default", vec![])],
        RegimeType::Wendler531 => vec![
            ("default", vec![]),
            (
                "intermediate",
                vec![
                    ("squat_tm", 288.0),
                    ("bench_press_tm", 202.5),
                    ("deadlift_tm", 337.5),
                    ("overhead_press_tm", 130.5),
                ],
            ),
        ],
    }
}

fn build_fixture() -> serde_json::Value {
    let mut regimes = serde_json::Map::new();

    for regime_type in crate::regimes::catalog_regime_types() {
        let regime = get_regime(regime_type);
        let mut seeds = serde_json::Map::new();

        for (seed_name, overrides) in starting_points(regime_type) {
            let mut state = regime.default_state();
            for (key, value) in &overrides {
                set_f32(&mut state, key, *value);
            }

            let mut runs = serde_json::Map::new();
            for (scenario_name, script) in scenarios() {
                let timeline: Vec<SimulatedSession> =
                    simulate(regime_type, state.clone(), &script);
                runs.insert(
                    scenario_name.to_string(),
                    serde_json::to_value(&timeline).unwrap(),
                );
            }

            seeds.insert(
                seed_name.to_string(),
                serde_json::json!({
                    "initial_weights": overrides
                        .iter()
                        .map(|(k, v)| (k.to_string(), *v))
                        .collect::<std::collections::HashMap<_, _>>(),
                    "scenarios": runs,
                }),
            );
        }

        regimes.insert(
            format!("{regime_type:?}").to_lowercase(),
            serde_json::json!({
                "display_name": regime.display_name(),
                "seeds": seeds,
            }),
        );
    }

    serde_json::json!({
        "comment": "Generated by `LIFT_SNAPSHOT_TIMELINE=1 cargo test regime_timeline`. \
                    Authoritative output of the Rust regime state machines. \
                    docs/regime-explorer.html reimplements these in JS for interactivity \
                    and is checked against this file by scripts/check_regime_parity.mjs.",
        "regimes": regimes,
    })
}

#[test]
fn regime_timeline_fixture_is_current() {
    let current = build_fixture();

    if std::env::var("LIFT_SNAPSHOT_TIMELINE").ok().as_deref() == Some("1") {
        std::fs::create_dir_all(fixture_path().parent().unwrap()).unwrap();
        std::fs::write(
            fixture_path(),
            format!("{}\n", serde_json::to_string_pretty(&current).unwrap()),
        )
        .unwrap();
        return;
    }

    let raw = std::fs::read_to_string(fixture_path()).expect(
        "testdata/regime_timelines.json missing — regenerate with \
         LIFT_SNAPSHOT_TIMELINE=1 cargo test regime_timeline",
    );
    let expected: serde_json::Value = serde_json::from_str(&raw).unwrap();

    // Compare the pretty-printed forms: the fixture is written and read through
    // the same serialiser, so this is a stable textual comparison and the
    // failure output points at the first differing line.
    let expected_text = serde_json::to_string_pretty(&expected["regimes"]).unwrap();
    let current_text = serde_json::to_string_pretty(&current["regimes"]).unwrap();

    if expected_text != current_text {
        let first_diff = expected_text
            .lines()
            .zip(current_text.lines())
            .enumerate()
            .find(|(_, (a, b))| a != b)
            .map(|(i, (a, b))| format!("line {}:\n  fixture: {a}\n  code:    {b}", i + 1))
            .unwrap_or_else(|| "length differs".to_string());

        panic!(
            "Regime behaviour changed. If intended, regenerate with \
             LIFT_SNAPSHOT_TIMELINE=1 cargo test regime_timeline and re-run \
             node scripts/check_regime_parity.mjs.\n\n{first_diff}"
        );
    }
}
