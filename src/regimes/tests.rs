/// Regime progression tests.
///
/// Most tests are data-driven: each JSON file in src/regimes/fixtures/ describes a complete
/// progression through a regime. Each step has:
///   - "note":          human-readable description of what's happening
///   - "expect":        per-exercise proposals (weight/sets/reps) from calculate_exercise_progression
///   - "expect_groups": whole-workout group proposals from build_proposed_groups (checks name + tags)
///   - "done":          what the user actually did — becomes history for the next step
///
/// "exercises" in config tells the runner which exercises to include when building group proposals.
///
/// To add a new regime test: drop a JSON file in src/regimes/fixtures/ and add one line below.
use std::collections::HashMap;

use lift::workout::v1::{Exercise, ExerciseStatus, RegimeType, UserWorkoutConfig};

use super::{get_regime, SessionHistory, WorkoutRegime, EXERCISE_CONFIGS};

// ─── Fixture data structures ─────────────────────────────────────────────────

#[derive(serde::Deserialize)]
struct Fixture {
    regime: String,
    #[allow(dead_code)]
    description: String,
    #[serde(default)]
    config: FixtureConfig,
    steps: Vec<FixtureStep>,
}

#[derive(serde::Deserialize, Default)]
struct FixtureConfig {
    #[serde(default = "default_days")]
    days_per_week: i32,
    /// All exercises active in this workout — used to build group proposals.
    /// Required when any step has expect_groups.
    #[serde(default)]
    exercises: Vec<String>,
    #[serde(default)]
    one_rep_maxes: HashMap<String, f32>,
}

fn default_days() -> i32 { 3 }

#[derive(serde::Deserialize)]
struct FixtureStep {
    #[serde(default)]
    note: String,
    /// Per-exercise proposal checks (weight / sets / reps / amrap).
    #[serde(default)]
    expect: Vec<ExpectedProposal>,
    /// Whole-workout group checks (name + tags must/must-not contain).
    #[serde(default)]
    expect_groups: Vec<ExpectedGroup>,
    #[serde(default)]
    done: Vec<SessionDone>,
}

#[derive(serde::Deserialize)]
struct ExpectedProposal {
    exercise: String,
    weight: f32,
    sets: i32,
    reps: i32,
    /// If present, also verifies ExerciseTypeConfig.last_set_amrap via build_proposed_groups.
    amrap: Option<bool>,
}

#[derive(serde::Deserialize)]
struct ExpectedGroup {
    /// Exact group name as returned by build_proposed_groups.
    name: String,
    /// All of these tags must be present on the group.
    #[serde(default)]
    tags: Vec<String>,
    /// None of these tags may be present on the group.
    #[serde(default)]
    not_tags: Vec<String>,
}

#[derive(serde::Deserialize)]
struct SessionDone {
    exercise: String,
    weight: f32,
    #[serde(default = "default_true")]
    success: bool,
    #[serde(default)]
    last_set_reps: i32,
}

fn default_true() -> bool { true }

// ─── Helpers ─────────────────────────────────────────────────────────────────

fn parse_exercise(name: &str) -> Exercise {
    match name {
        "Squat"               => Exercise::Squat,
        "BenchPress"          => Exercise::BenchPress,
        "Deadlift"            => Exercise::Deadlift,
        "OverheadPress"       => Exercise::OverheadPress,
        "BarbellRow"          => Exercise::BarbellRow,
        "HipThrust"           => Exercise::HipThrust,
        "BulgarianSplitSquat" => Exercise::BulgarianSplitSquat,
        "RomanianDeadlift"    => Exercise::RomanianDeadlift,
        "GluteBridge"         => Exercise::GluteBridge,
        "Lunge"               => Exercise::Lunge,
        "LegCurl"             => Exercise::LegCurl,
        _ => panic!("Unknown exercise: {name}"),
    }
}

fn parse_regime_type(name: &str) -> RegimeType {
    match name {
        "linear5x5" | "linear_5x5" => RegimeType::Linear5x5,
        "gzclp"                    => RegimeType::Gzclp,
        "wendler531" | "wendler_531" => RegimeType::Wendler531,
        _ => panic!("Unknown regime: {name}"),
    }
}

// ─── Core runner ─────────────────────────────────────────────────────────────

fn run_fixture(filename: &str) {
    let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("src/regimes/fixtures")
        .join(filename);

    let content = std::fs::read_to_string(&path)
        .unwrap_or_else(|e| panic!("Cannot read {filename}: {e}"));
    let fixture: Fixture = serde_json::from_str(&content)
        .unwrap_or_else(|e| panic!("Cannot parse {filename}: {e}"));

    let regime_type = parse_regime_type(&fixture.regime);
    let regime = get_regime(regime_type);

    // Parse the fixture's exercise list once — used to build group proposals.
    let fixture_exercises: Vec<Exercise> = fixture.config.exercises.iter()
        .map(|n| parse_exercise(n))
        .collect();

    let mut history: HashMap<i32, Vec<SessionHistory>> = HashMap::new();
    let mut config = UserWorkoutConfig {
        regime_type: regime_type as i32,
        days_per_week: fixture.config.days_per_week,
        one_rep_maxes: fixture.config.one_rep_maxes.iter()
            .map(|(k, v)| (parse_exercise(k) as i32, *v))
            .collect(),
        regime_state_json: "{}".to_string(),
    };

    // Timestamps: newest session is 1 day ago, oldest is N days ago.
    // Keeps all sessions within 14 days (safe for linear deload check) for ≤13-step fixtures.
    let now = chrono::Utc::now().timestamp();
    let total_steps = fixture.steps.len();

    for (step_idx, step) in fixture.steps.iter().enumerate() {
        config.regime_state_json = regime.compute_updated_state(&config, &history);

        // ── Per-exercise proposal checks ──────────────────────────────────────
        for expected in &step.expect {
            let exercise = parse_exercise(&expected.exercise);
            let ex_cfg = EXERCISE_CONFIGS.iter()
                .find(|c| c.exercise == exercise)
                .unwrap_or_else(|| panic!("{filename}: no config for {}", expected.exercise));

            let ex_history = history.get(&(exercise as i32)).map(|v| v.as_slice()).unwrap_or(&[]);
            let max_weight = ex_history.iter().map(|h| h.weight).fold(0.0_f32, f32::max);

            let proposal = regime.calculate_exercise_progression(
                exercise, ex_cfg, ex_history, max_weight, &config,
            );

            assert_eq!(
                proposal.weight, expected.weight,
                "{filename} step {step_idx} ({}) — {} weight: expected {}, got {}",
                step.note, expected.exercise, expected.weight, proposal.weight
            );
            assert_eq!(
                proposal.sets, expected.sets,
                "{filename} step {step_idx} ({}) — {} sets: expected {}, got {}",
                step.note, expected.exercise, expected.sets, proposal.sets
            );
            assert_eq!(
                proposal.reps, expected.reps,
                "{filename} step {step_idx} ({}) — {} reps: expected {}, got {}",
                step.note, expected.exercise, expected.reps, proposal.reps
            );

            // AMRAP check via build_proposed_groups (single-exercise status)
            if let Some(expected_amrap) = expected.amrap {
                let status = ExerciseStatus {
                    exercise: exercise as i32,
                    target_weight: proposal.weight,
                    explanation: proposal.explanation.clone(),
                    last_performed_at: 0,
                    weight_history: vec![],
                    muscle_groups: vec![],
                    default_sets: proposal.sets,
                    default_reps: proposal.reps,
                    recovered: true,
                    always_include: false,
                    category: ex_cfg.category as i32,
                };
                let groups = regime.build_proposed_groups(&[status], &config);
                if let Some(group) = groups.iter()
                    .find(|g| g.exercise_configs.iter().any(|c| c.exercise == exercise as i32))
                {
                    let ec = group.exercise_configs.iter()
                        .find(|c| c.exercise == exercise as i32)
                        .unwrap();
                    assert_eq!(
                        ec.last_set_amrap, expected_amrap,
                        "{filename} step {step_idx} ({}) — {} amrap: expected {expected_amrap}, got {}",
                        step.note, expected.exercise, ec.last_set_amrap
                    );
                }
                // T3 paired groups won't appear with a single status — AMRAP check skipped.
            }
        }

        // ── Whole-workout group checks ────────────────────────────────────────
        if !step.expect_groups.is_empty() {
            assert!(
                !fixture_exercises.is_empty(),
                "{filename}: expect_groups requires 'exercises' list in config"
            );

            // Build a realistic ExerciseStatus for every exercise in the fixture.
            let statuses: Vec<ExerciseStatus> = fixture_exercises.iter().map(|&exercise| {
                let ex_cfg = EXERCISE_CONFIGS.iter()
                    .find(|c| c.exercise == exercise)
                    .unwrap();
                let ex_history = history.get(&(exercise as i32)).map(|v| v.as_slice()).unwrap_or(&[]);
                let max_weight = ex_history.iter().map(|h| h.weight).fold(0.0_f32, f32::max);
                let proposal = regime.calculate_exercise_progression(
                    exercise, ex_cfg, ex_history, max_weight, &config,
                );
                ExerciseStatus {
                    exercise: exercise as i32,
                    target_weight: proposal.weight,
                    explanation: proposal.explanation,
                    last_performed_at: ex_history.first().map(|h| h.timestamp).unwrap_or(0),
                    weight_history: ex_history.iter().rev().map(|h| h.weight).collect(),
                    muscle_groups: ex_cfg.muscle_groups.iter().map(|mg| *mg as i32).collect(),
                    default_sets: proposal.sets,
                    default_reps: proposal.reps,
                    recovered: true,
                    always_include: ex_cfg.always_include,
                    category: ex_cfg.category as i32,
                }
            }).collect();

            let groups = regime.build_proposed_groups(&statuses, &config);

            for expected_group in &step.expect_groups {
                let group = groups.iter().find(|g| g.name == expected_group.name)
                    .unwrap_or_else(|| {
                        let names: Vec<&str> = groups.iter().map(|g| g.name.as_str()).collect();
                        panic!(
                            "{filename} step {step_idx} ({}) — group {:?} not found. Got: {names:?}",
                            step.note, expected_group.name
                        )
                    });

                for tag in &expected_group.tags {
                    assert!(
                        group.tags.contains(tag),
                        "{filename} step {step_idx} ({}) — group {:?} missing tag {:?}. Got tags: {:?}",
                        step.note, expected_group.name, tag, group.tags
                    );
                }
                for tag in &expected_group.not_tags {
                    assert!(
                        !group.tags.contains(tag),
                        "{filename} step {step_idx} ({}) — group {:?} should NOT have tag {:?}. Got tags: {:?}",
                        step.note, expected_group.name, tag, group.tags
                    );
                }
            }
        }

        // ── Add done entries to history (insert newest-first) ─────────────────
        let timestamp = now - (total_steps - step_idx) as i64 * 86400;
        for done in &step.done {
            let exercise = parse_exercise(&done.exercise);
            history.entry(exercise as i32)
                .or_default()
                .insert(0, SessionHistory {
                    weight: done.weight,
                    success: done.success,
                    timestamp,
                    last_set_reps: done.last_set_reps,
                });
        }
    }
}

// ─── Fixture tests — one line per file ───────────────────────────────────────

// Single-exercise progression fixtures
#[test]
fn fixture_linear_5x5_bench()          { run_fixture("linear_5x5_bench.json"); }
#[test]
fn fixture_linear_5x5_deadlift()       { run_fixture("linear_5x5_deadlift.json"); }
#[test]
fn fixture_gzclp_t1_squat_stages()     { run_fixture("gzclp_t1_squat_stages.json"); }
#[test]
fn fixture_gzclp_t2_bench_stages()     { run_fixture("gzclp_t2_bench_stages.json"); }
#[test]
fn fixture_gzclp_t3_hip_thrust()       { run_fixture("gzclp_t3_hip_thrust.json"); }
#[test]
fn fixture_wendler_531_full_cycle()    { run_fixture("wendler_531_full_cycle.json"); }

// Full-workout fixtures (multiple exercises + group rotation/pairing)
#[test]
fn fixture_gzclp_full_workout()        { run_fixture("gzclp_full_workout.json"); }
#[test]
fn fixture_wendler_all_lifts()         { run_fixture("wendler_all_lifts.json"); }

// ─── Edge-case unit tests (timestamp-sensitive or hard to express in JSON) ───

/// Linear deload when there's been a long break — needs explicit timestamp control.
#[test]
fn linear_long_break_triggers_deload() {
    use super::linear_5x5::calculate_linear_progression;
    let h = vec![SessionHistory {
        weight: 100.0,
        success: true,
        timestamp: chrono::Utc::now().timestamp() - 20 * 86400,
        last_set_reps: 5,
    }];
    let (w, _) = calculate_linear_progression(Exercise::BenchPress as i32, 45.0, &h, 100.0);
    assert!(w < 100.0, "expected deload after 20-day break, got {w}");
}

/// Longer break should deload more aggressively than a shorter break.
#[test]
fn linear_longer_break_deloads_more() {
    use super::linear_5x5::calculate_linear_progression;
    let now = chrono::Utc::now().timestamp();
    let h_short = vec![SessionHistory { weight: 100.0, success: true, timestamp: now - 20 * 86400, last_set_reps: 5 }];
    let h_long  = vec![SessionHistory { weight: 100.0, success: true, timestamp: now - 35 * 86400, last_set_reps: 5 }];
    let (w_short, _) = calculate_linear_progression(Exercise::BenchPress as i32, 45.0, &h_short, 100.0);
    let (w_long, _)  = calculate_linear_progression(Exercise::BenchPress as i32, 45.0, &h_long,  100.0);
    assert!(w_long <= w_short, "longer break should deload more or equal: {w_long} vs {w_short}");
}

/// Wendler advances weeks and cycles correctly over 2 full cycles (24 sessions).
#[test]
fn wendler_state_advances_over_two_cycles() {
    use super::wendler_531::{Wendler531Regime, WendlerState};

    let squat_ex = Exercise::Squat as i32;
    let now = chrono::Utc::now().timestamp();

    for total_sessions in 0usize..=24 {
        let expected_cycle = (total_sessions / 12) as u32 + 1;
        let expected_week  = ((total_sessions % 12) / 3) as u8 + 1;

        let mut hmap: HashMap<i32, Vec<SessionHistory>> = HashMap::new();
        hmap.insert(squat_ex, (0..total_sessions)
            .map(|i| SessionHistory {
                weight: 135.0,
                success: true,
                timestamp: now - (total_sessions - i) as i64 * 3 * 86400,
                last_set_reps: 5,
            })
            .collect());

        let config = UserWorkoutConfig {
            regime_type: RegimeType::Wendler531 as i32,
            days_per_week: 4,
            one_rep_maxes: HashMap::new(),
            regime_state_json: "{}".to_string(),
        };
        let state_json = Wendler531Regime.compute_updated_state(&config, &hmap);
        let state = WendlerState::from_json(&state_json);

        assert_eq!(state.week,  expected_week.clamp(1, 4), "at {total_sessions} sessions: week");
        assert_eq!(state.cycle, expected_cycle,             "at {total_sessions} sessions: cycle");
    }
}

/// Wendler with no 1RM set should return an explanation pointing to settings.
#[test]
fn wendler_no_1rm_shows_setup_prompt() {
    use super::wendler_531::Wendler531Regime;
    let config = UserWorkoutConfig {
        regime_type: RegimeType::Wendler531 as i32,
        days_per_week: 4,
        one_rep_maxes: HashMap::new(),
        regime_state_json: r#"{"week":1,"cycle":1}"#.to_string(),
    };
    let squat_cfg = EXERCISE_CONFIGS.iter().find(|c| c.exercise == Exercise::Squat).unwrap();
    let p = Wendler531Regime.calculate_exercise_progression(Exercise::Squat, squat_cfg, &[], 0.0, &config);
    assert!(
        p.explanation.contains("1RM") || p.explanation.contains("Settings") || p.explanation.contains("max"),
        "should explain 1RM needs configuring, got: {}", p.explanation
    );
}
