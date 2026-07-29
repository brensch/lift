#[cfg(test)]
mod tests {
    use crate::program_state::{set_f32, set_int, set_str, FieldVal, ProposeResult, StatePayload};
    use crate::regimes::get_regime;
    use crate::schplanner::{derive_state, SchplannerInsights, SchplannerWorkoutRecord};
    use crate::workout::generate_sets_for_group;
    use chrono::{DateTime, Utc};
    use schlift::workout::v1::{
        Exercise, ExerciseGroup, ProposedExerciseGroup, RegimeType, Workout,
    };
    use serde::Deserialize;
    use serde_json::{json, Value};
    use std::fs;
    use uuid::Uuid;

    const SNAPSHOT_PREFIX: &str = "__PROPOSED_EXPECT__ ";

    #[derive(Deserialize)]
    #[allow(dead_code)]
    struct Scenario {
        description: Option<String>,
        regime_config: ScenarioRegimeConfig,
        workouts: Vec<ScenarioWorkout>,
    }

    #[derive(Deserialize)]
    struct ScenarioRegimeConfig {
        regime_type: String,
        #[serde(default)]
        one_rep_maxes: std::collections::HashMap<String, f32>,
        #[serde(default)]
        initial_state: serde_json::Map<String, Value>,
    }

    #[derive(Deserialize)]
    struct ScenarioWorkout {
        note: Option<String>,
        #[serde(default)]
        get_proposed: Option<ScenarioCheckpoint>,
        #[serde(default)]
        start: Option<ScenarioAt>,
        #[serde(default)]
        sets: Vec<ScenarioSet>,
        #[serde(default)]
        end: Option<ScenarioAt>,
        #[serde(default)]
        assert_recommended_plan_matches_sets: bool,
    }

    #[derive(Deserialize)]
    struct ScenarioCheckpoint {
        at: String,
        #[serde(default)]
        expect: Option<Value>,
    }

    #[derive(Deserialize)]
    struct ScenarioAt {
        at: String,
    }

    #[derive(Deserialize)]
    struct ScenarioSet {
        exercise: String,
        target_reps: i32,
        target_weight: f32,
        actual_reps: i32,
    }

    fn parse_ts(ts: &str) -> i64 {
        DateTime::parse_from_rfc3339(ts)
            .unwrap()
            .with_timezone(&Utc)
            .timestamp()
    }

    fn load_scenario(path: &str) -> Scenario {
        serde_json::from_str(&fs::read_to_string(path).unwrap()).unwrap()
    }

    fn scenario_regime_and_state(cfg: &ScenarioRegimeConfig) -> (RegimeType, StatePayload) {
        let (regime_type, maybe_variant) = match cfg.regime_type.as_str() {
            "linear_5x5" => (RegimeType::Linear5x5, None),
            "gzclp" => (RegimeType::Gzclp, None),
            "wendler_531_4day" => (RegimeType::Wendler531, Some("four_day")),
            "wendler_531_3day" => (RegimeType::Wendler531, Some("three_day")),
            "wendler_531" => (RegimeType::Wendler531, None),
            other => panic!("unsupported scenario regime_type: {other}"),
        };
        let regime = get_regime(regime_type);
        let mut state = regime.default_state();
        if let Some(variant) = maybe_variant {
            set_str(&mut state, "schedule_variant", variant);
        }
        for (key, value) in &cfg.initial_state {
            apply_value(&mut state, key, value);
        }
        if regime_type == RegimeType::Wendler531 && !cfg.one_rep_maxes.is_empty() {
            for (exercise, orm) in &cfg.one_rep_maxes {
                match exercise.as_str() {
                    "squat" => set_f32(&mut state, "squat_tm", orm * 0.9),
                    "bench_press" => set_f32(&mut state, "bench_press_tm", orm * 0.9),
                    "deadlift" => set_f32(&mut state, "deadlift_tm", orm * 0.9),
                    "overhead_press" => set_f32(&mut state, "overhead_press_tm", orm * 0.9),
                    _ => {}
                }
            }
        }
        (regime_type, state)
    }

    fn apply_value(state: &mut StatePayload, key: &str, value: &Value) {
        match value {
            Value::String(v) => set_str(state, key, v),
            Value::Number(v) if v.is_i64() => set_int(state, key, v.as_i64().unwrap()),
            Value::Number(v) if v.is_u64() => set_int(state, key, v.as_u64().unwrap() as i64),
            Value::Number(v) => set_f32(state, key, v.as_f64().unwrap() as f32),
            Value::Bool(v) => {
                state.insert(key.to_string(), FieldVal::Bool(*v));
            }
            _ => {}
        }
    }

    fn normalize_proposal(proposal: &ProposeResult) -> Value {
        json!({
            "exact_group_order": true,
            "exact_groups": true,
            "groups": proposal.proposed_groups.iter().map(normalize_group).collect::<Vec<_>>(),
            "is_ready": true,
            "suggested_name": proposal.suggested_workout_name,
        })
    }

    fn normalize_group(group: &ProposedExerciseGroup) -> Value {
        let primary = group.exercise_configs.first();
        json!({
            "name": group.name,
            "sets": group.sets,
            "reps": primary.map(|cfg| cfg.reps).unwrap_or_default(),
            "weight": primary.map(|cfg| cfg.start_weight).unwrap_or_default(),
            "tags": group.tags,
            "prescribed_by_regime": group.prescribed_by_regime,
            "interleave_warmups": group.interleave_warmups,
            "rest_after_success": group.rest_config.as_ref().map(|r| r.rest_after_success).unwrap_or_default(),
            "rest_after_failure": group.rest_config.as_ref().map(|r| r.rest_after_failure).unwrap_or_default(),
            "exercise_configs": group.exercise_configs.iter().map(|cfg| {
                json!({
                    "exercise": cfg.exercise().as_str_name().trim_start_matches("EXERCISE_").to_ascii_lowercase(),
                    "start_weight": cfg.start_weight,
                    "end_weight": cfg.end_weight,
                    "reps": cfg.reps,
                    "include_warmup": cfg.include_warmup,
                    "last_set_amrap": cfg.last_set_amrap,
                    "working_sets": cfg.working_sets.iter().map(|set| {
                        json!({
                            "weight": set.target_weight,
                            "reps": set.target_reps,
                            "is_amrap": set.is_amrap,
                        })
                    }).collect::<Vec<_>>(),
                })
            }).collect::<Vec<_>>(),
        })
    }

    fn make_group(idx: usize, group: &ProposedExerciseGroup, workout_id: &str) -> ExerciseGroup {
        ExerciseGroup {
            id: Uuid::new_v4().to_string(),
            workout_id: workout_id.to_string(),
            name: group.name.clone(),
            sets: group.sets,
            interleave_warmups: group.interleave_warmups,
            workout_order: idx as i32,
            exercise_configs: group.exercise_configs.clone(),
            rest_config: group.rest_config,
            instruction: String::new(),
            prescribed_by_regime: group.prescribed_by_regime,
            materialized_sets: Vec::new(),
        }
    }

    fn parse_exercise(name: &str) -> Exercise {
        match name {
            "squat" => Exercise::Squat,
            "bench_press" => Exercise::BenchPress,
            "deadlift" => Exercise::Deadlift,
            "overhead_press" => Exercise::OverheadPress,
            "barbell_row" => Exercise::BarbellRow,
            "hip_thrust" => Exercise::HipThrust,
            "bulgarian_split_squat" => Exercise::BulgarianSplitSquat,
            "romanian_deadlift" => Exercise::RomanianDeadlift,
            "glute_bridge" => Exercise::GluteBridge,
            "lunge" => Exercise::Lunge,
            "leg_curl" => Exercise::LegCurl,
            other => panic!("unsupported exercise {other}"),
        }
    }

    fn build_workout_record(
        idx: usize,
        workout: &ScenarioWorkout,
        proposal: &ProposeResult,
    ) -> SchplannerWorkoutRecord {
        let workout_id = format!("scenario-workout-{idx}");
        let start_time = parse_ts(&workout.start.as_ref().expect("start required").at);
        let end_time = parse_ts(&workout.end.as_ref().expect("end required").at);
        let groups = proposal
            .proposed_groups
            .iter()
            .filter(|group| group.tags.iter().any(|tag| tag == "recommended"))
            .enumerate()
            .map(|(group_idx, group)| make_group(group_idx, group, &workout_id))
            .collect::<Vec<_>>();
        let mut proposed_sets = Vec::new();
        let mut order = 0;
        for group in &groups {
            let generated = generate_sets_for_group(
                &workout_id,
                group,
                order,
                crate::weight_units::AppWeightUnit::Lb,
            );
            order += generated.len() as i32;
            proposed_sets.extend(generated);
        }

        let working_proposed = proposed_sets
            .iter()
            .filter(|set| !set.warmup && !set.cancelled)
            .cloned()
            .collect::<Vec<_>>();
        assert_eq!(
            working_proposed.len(),
            workout.sets.len(),
            "scenario set count mismatch for workout {} {:?}",
            idx,
            workout.note
        );

        let mut completed_sets = Vec::new();
        for (set_idx, (expected, proposed)) in
            workout.sets.iter().zip(working_proposed.iter()).enumerate()
        {
            assert_eq!(proposed.exercise(), parse_exercise(&expected.exercise));
            assert_eq!(proposed.target_reps, expected.target_reps);
            assert!(
                (proposed.target_weight - expected.target_weight).abs() < 0.01,
                "weight mismatch at workout {} set {}: expected {}, got {}",
                idx,
                set_idx,
                expected.target_weight,
                proposed.target_weight
            );
            completed_sets.push(schlift::workout::v1::CompletedSet {
                id: format!("{workout_id}-c{set_idx}"),
                workout_id: workout_id.clone(),
                proposed_set_id: proposed.id.clone(),
                actual_reps: expected.actual_reps,
                actual_weight: proposed.target_weight,
                started_at: start_time + set_idx as i64,
                ended_at: start_time + set_idx as i64 + 1,
                rest_until: 0,
            });
        }

        SchplannerWorkoutRecord {
            workout: Workout {
                id: workout_id,
                name: workout
                    .note
                    .clone()
                    .unwrap_or_else(|| "Workout".to_string()),
                start_time,
                end_time,
                session_id: String::new(),
            },
            exercise_groups: groups,
            proposed_sets,
            completed_sets,
        }
    }

    fn run_scenario(path: &str) {
        let scenario = load_scenario(path);
        let (regime_type, base_state) = scenario_regime_and_state(&scenario.regime_config);
        let regime = get_regime(regime_type);
        let mut history = Vec::new();

        for (idx, workout) in scenario.workouts.iter().enumerate() {
            if let Some(checkpoint) = &workout.get_proposed {
                let derivation = derive_state(regime.as_ref(), &base_state, &history);
                let proposal = regime.propose_from_state(
                    &derivation.effective_state,
                    derivation.last_session_at,
                    parse_ts(&checkpoint.at),
                    &SchplannerInsights::default(),
                );
                let expect = normalize_proposal(&proposal);
                if std::env::var("LIFT_SNAPSHOT_PROPOSED").ok().as_deref() == Some("1") {
                    println!("{SNAPSHOT_PREFIX}{}", json!({ "expect": expect }));
                } else if let Some(existing) = &checkpoint.expect {
                    assert_eq!(
                        existing, &expect,
                        "checkpoint mismatch in {} workout {} {:?}",
                        path, idx, workout.note
                    );
                }
                if workout.assert_recommended_plan_matches_sets {
                    let _ = build_workout_record(idx, workout, &proposal);
                }
            }

            if workout.start.is_some() {
                let derivation = derive_state(regime.as_ref(), &base_state, &history);
                let proposal = regime.propose_from_state(
                    &derivation.effective_state,
                    derivation.last_session_at,
                    parse_ts(&workout.start.as_ref().unwrap().at),
                    &SchplannerInsights::default(),
                );
                history.push(build_workout_record(idx, workout, &proposal));
            }
        }
    }

    #[test]
    fn test_linear_5x5_progression() {
        run_scenario("src/regimes/scenarios/linear_5x5.json");
    }

    #[test]
    fn test_gzclp_progression() {
        run_scenario("src/regimes/scenarios/gzclp.json");
    }

    #[test]
    fn test_wendler_531_4day_progression() {
        run_scenario("src/regimes/scenarios/wendler_531.json");
    }

    #[test]
    fn test_wendler_531_3day_progression() {
        run_scenario("src/regimes/scenarios/wendler_531_3day.json");
    }
}
