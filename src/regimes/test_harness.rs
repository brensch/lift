/// Test harness for workout regime state machines.
///
/// Runs JSON scenario files end-to-end against the real scheduler + DB logic.
/// Each scenario describes a series of workouts with expected weights/reps/sets.
use std::collections::HashMap;
use std::env;

use chrono::DateTime;
use lift::workout::v1::{
    CompletedSet, ExerciseGroup, ProposedSet, RegimeType, UserWorkoutConfig, UserSetting,
    user_setting, Workout,
};
use prost::Message;
use serde::{Deserialize, Serialize};
use serde_json::json;
use uuid::Uuid;

use crate::db::CentralDb;
use crate::scheduler::Scheduler;
use crate::service_workout::{generate_sets_for_group, materialize_group_working_sets};

// ─── JSON scenario schema ──────────────────────────────────────────────────────

#[derive(Debug, Deserialize)]
struct Scenario {
    description: String,
    regime_config: RegimeConfig,
    workouts: Vec<WorkoutStep>,
}

#[derive(Debug, Deserialize)]
struct RegimeConfig {
    regime_type: String,
    days_per_week: i32,
    one_rep_maxes: HashMap<String, f32>,
}

#[derive(Debug, Deserialize)]
struct WorkoutStep {
    #[serde(default)]
    note: String,
    #[serde(default)]
    assert_recommended_plan_matches_sets: bool,
    get_proposed: Option<GetProposedStep>,
    start: StartStep,
    sets: Vec<SetStep>,
    end: EndStep,
}

#[derive(Debug, Deserialize)]
struct GetProposedStep {
    at: String, // ISO 8601 timestamp
    expect: Option<ProposedExpect>,
}

#[derive(Debug, Deserialize)]
struct ProposedExpect {
    suggested_name: Option<String>,
    is_ready: Option<bool>,
    #[serde(default = "default_true")]
    exact_groups: bool,
    #[serde(default)]
    exact_group_order: bool,
    #[serde(default)]
    groups: Vec<GroupExpect>,
}

#[derive(Debug, Deserialize, Serialize)]
struct GroupExpect {
    name: String,
    sets: i32,
    reps: i32,
    weight: f32,
    #[serde(default)]
    interleave_warmups: Option<bool>,
    #[serde(default)]
    prescribed_by_regime: Option<bool>,
    #[serde(default)]
    tags: Vec<String>,
    #[serde(default)]
    rest_after_success: Option<i32>,
    #[serde(default)]
    rest_after_failure: Option<i32>,
    #[serde(default)]
    exercise_configs: Vec<ExerciseConfigExpect>,
}

#[derive(Debug, Deserialize, Serialize)]
struct ExerciseConfigExpect {
    exercise: String,
    start_weight: f32,
    end_weight: f32,
    reps: i32,
    include_warmup: bool,
    last_set_amrap: bool,
    #[serde(default)]
    working_sets: Vec<WorkingSetExpect>,
}

#[derive(Debug, Deserialize, Serialize)]
struct WorkingSetExpect {
    weight: f32,
    reps: i32,
    is_amrap: bool,
}

fn default_true() -> bool {
    true
}

#[derive(Debug, Deserialize)]
struct StartStep {
    at: String,
}

#[derive(Debug, Deserialize)]
struct SetStep {
    #[serde(default)]
    note: String,
    exercise: String,    // "squat", "bench_press", etc.
    #[serde(rename = "warmup", default)]
    _warmup: bool,
    target_reps: i32,
    target_weight: f32,
    start_at: String,
    end_at: String,
    actual_reps: i32,
    expect_next: Option<NextExpect>,
}

#[derive(Debug, Deserialize)]
struct NextExpect {
    exercise: String,
    reps: i32,
    weight: f32,
}

#[derive(Debug, Deserialize)]
struct EndStep {
    at: String,
}

// ─── Exercise name mapping ─────────────────────────────────────────────────────

fn exercise_name_to_int(name: &str) -> i32 {
    match name.to_lowercase().replace(' ', "_").as_str() {
        "squat" => lift::workout::v1::Exercise::Squat as i32,
        "bench_press" => lift::workout::v1::Exercise::BenchPress as i32,
        "deadlift" => lift::workout::v1::Exercise::Deadlift as i32,
        "overhead_press" | "ohp" => lift::workout::v1::Exercise::OverheadPress as i32,
        "barbell_row" => lift::workout::v1::Exercise::BarbellRow as i32,
        "hip_thrust" => lift::workout::v1::Exercise::HipThrust as i32,
        "bulgarian_split_squat" => lift::workout::v1::Exercise::BulgarianSplitSquat as i32,
        "romanian_deadlift" | "rdl" => lift::workout::v1::Exercise::RomanianDeadlift as i32,
        "glute_bridge" => lift::workout::v1::Exercise::GluteBridge as i32,
        "lunge" => lift::workout::v1::Exercise::Lunge as i32,
        "leg_curl" => lift::workout::v1::Exercise::LegCurl as i32,
        _ => 0,
    }
}

fn exercise_int_to_name(ex: i32) -> &'static str {
    match ex {
        1 => "squat",
        2 => "bench_press",
        3 => "deadlift",
        4 => "overhead_press",
        5 => "barbell_row",
        6 => "hip_thrust",
        7 => "bulgarian_split_squat",
        8 => "romanian_deadlift",
        9 => "glute_bridge",
        10 => "lunge",
        11 => "leg_curl",
        _ => "unknown",
    }
}

fn regime_type_from_str(s: &str) -> RegimeType {
    match s.to_lowercase().as_str() {
        "gzclp" => RegimeType::Gzclp,
        "wendler_531_4day" | "wendler531_4day" => RegimeType::Wendler5314day,
        "wendler_531_3day" | "wendler531_3day" => RegimeType::Wendler5313day,
        _ => RegimeType::Linear5x5,
    }
}

fn parse_ts(s: &str) -> i64 {
    DateTime::parse_from_rfc3339(s)
        .unwrap_or_else(|e| panic!("Failed to parse timestamp '{}': {}", s, e))
        .timestamp()
}

fn exercise_int_to_name_owned(ex: i32) -> String {
    exercise_int_to_name(ex).to_string()
}

fn assert_f32_close(actual: f32, expected: f32, msg: &str) {
    assert!(
        (actual - expected).abs() < 1.0,
        "{}: expected {}, got {}",
        msg,
        expected,
        actual
    );
}

fn maybe_dump_proposed_snapshot(workout_idx: usize, step_desc: &str, resp: &lift::workout::v1::GetProposedWorkoutScheduleResponse) {
    if env::var("LIFT_SNAPSHOT_PROPOSED").ok().as_deref() != Some("1") {
        return;
    }

    let groups: Vec<serde_json::Value> = resp
        .proposed_groups
        .iter()
        .map(|g| {
            let first_cfg = g.exercise_configs.first();
            let first_weight = first_cfg
                .and_then(|cfg| cfg.working_sets.first().map(|ws| ws.target_weight))
                .or_else(|| first_cfg.map(|cfg| cfg.start_weight))
                .unwrap_or(0.0);
            let first_reps = first_cfg
                .and_then(|cfg| cfg.working_sets.first().map(|ws| ws.target_reps))
                .or_else(|| first_cfg.map(|cfg| cfg.reps))
                .unwrap_or(0);
            let rc = g.rest_config.as_ref();
            json!({
                "name": g.name,
                "sets": g.sets,
                "reps": first_reps,
                "weight": first_weight,
                "interleave_warmups": g.interleave_warmups,
                "prescribed_by_regime": g.prescribed_by_regime,
                "tags": g.tags,
                "rest_after_success": rc.map(|r| r.rest_after_success),
                "rest_after_failure": rc.map(|r| r.rest_after_failure),
                "exercise_configs": g.exercise_configs.iter().map(|cfg| {
                    json!({
                        "exercise": exercise_int_to_name_owned(cfg.exercise),
                        "start_weight": cfg.start_weight,
                        "end_weight": cfg.end_weight,
                        "reps": cfg.reps,
                        "include_warmup": cfg.include_warmup,
                        "last_set_amrap": cfg.last_set_amrap,
                        "working_sets": cfg.working_sets.iter().map(|ws| {
                            json!({
                                "weight": ws.target_weight,
                                "reps": ws.target_reps,
                                "is_amrap": ws.is_amrap
                            })
                        }).collect::<Vec<_>>()
                    })
                }).collect::<Vec<_>>()
            })
        })
        .collect();

    let payload = json!({
        "workout_index": workout_idx + 1,
        "step_desc": step_desc,
        "expect": {
            "suggested_name": resp.suggested_workout_name,
            "is_ready": resp.session_readiness.as_ref().map(|sr| sr.is_ready).unwrap_or(false),
            "exact_groups": true,
            "exact_group_order": true,
            "groups": groups
        }
    });

    eprintln!("__PROPOSED_EXPECT__ {}", payload);
}

fn assert_proposed_working_sets_match_scenario(
    step_desc: &str,
    proposed_sets: &[ProposedSet],
    included_group_ids: &std::collections::HashSet<String>,
    scenario_sets: &[SetStep],
) {
    let mut planned_working_sets: Vec<&ProposedSet> = proposed_sets
        .iter()
        .filter(|p| {
            !p.warmup && !p.cancelled && included_group_ids.contains(&p.exercise_group_id)
        })
        .collect();
    planned_working_sets.sort_by_key(|p| p.workout_order);

    assert_eq!(
        planned_working_sets.len(),
        scenario_sets.len(),
        "{}: Scenario set list must exactly match proposed working sets. proposed={} scenario={}\nPlanned: {:?}\nScenario: {:?}",
        step_desc,
        planned_working_sets.len(),
        scenario_sets.len(),
        planned_working_sets
            .iter()
            .map(|p| format!("{} {}x{}", exercise_int_to_name(p.exercise), p.target_weight, p.target_reps))
            .collect::<Vec<_>>(),
        scenario_sets
            .iter()
            .map(|s| format!("{} {}x{}", s.exercise, s.target_weight, s.target_reps))
            .collect::<Vec<_>>()
    );

    for (idx, (planned, expected)) in planned_working_sets.iter().zip(scenario_sets.iter()).enumerate() {
        let planned_ex = exercise_int_to_name(planned.exercise);
        let expected_ex = expected.exercise.to_lowercase().replace(' ', "_");
        assert_eq!(
            planned_ex, expected_ex,
            "{}: Proposed set #{} exercise mismatch: expected '{}' got '{}'",
            step_desc, idx + 1, expected_ex, planned_ex
        );

        if expected.target_reps > 0 {
            assert_eq!(
                planned.target_reps, expected.target_reps,
                "{}: Proposed set #{} reps mismatch for '{}': expected {} got {}",
                step_desc, idx + 1, expected_ex, expected.target_reps, planned.target_reps
            );
        }

        if expected.target_weight > 0.0 {
            assert!(
                (planned.target_weight - expected.target_weight).abs() < 1.0,
                "{}: Proposed set #{} weight mismatch for '{}': expected {} got {}",
                step_desc, idx + 1, expected_ex, expected.target_weight, planned.target_weight
            );
        }
    }
}

// ─── Active workout state ─────────────────────────────────────────────────────

struct ActiveState {
    _workout: Workout,
    _exercise_groups: Vec<ExerciseGroup>,
    proposed_sets: Vec<ProposedSet>,
    completed_sets: Vec<CompletedSet>,
}

// ─── Main run function ────────────────────────────────────────────────────────

pub async fn run_scenario(json: &str) {
    let scenario: Scenario =
        serde_json::from_str(json).expect("Failed to parse scenario JSON");

    // Create in-memory DB
    let db = CentralDb::new_in_memory()
        .await
        .expect("Failed to create in-memory DB");

    // Create test user
    let user = db.create_user("test_user").await.expect("Failed to create user");
    let user_id = user.id.clone();

    // Build and store UserWorkoutConfig
    let regime_type = regime_type_from_str(&scenario.regime_config.regime_type);
    let one_rep_maxes: HashMap<i32, f32> = scenario
        .regime_config
        .one_rep_maxes
        .iter()
        .map(|(name, &weight)| (exercise_name_to_int(name), weight))
        .filter(|(k, _)| *k != 0)
        .collect();

    let workout_config = UserWorkoutConfig {
        regime_type: regime_type as i32,
        days_per_week: scenario.regime_config.days_per_week,
        one_rep_maxes,
        regime_state_json: "{}".to_string(),
    };

    let setting = UserSetting {
        setting: Some(user_setting::Setting::WorkoutConfig(workout_config)),
    };
    let blob = setting.encode_to_vec();
    db.insert_user_setting(&user_id, "workout_config", &blob)
        .await
        .expect("Failed to insert workout config");

    // Flush to ensure config is persisted before first get_proposed
    db.flush_writes().await.expect("Failed to flush initial config");

    let scheduler = Scheduler::new(db.clone());

    // ── Run each workout step ───────────────────────────────────────────────
    for (workout_idx, workout_step) in scenario.workouts.iter().enumerate() {
        let step_desc = if workout_step.note.is_empty() {
            format!("Workout #{}", workout_idx + 1)
        } else {
            format!("Workout #{}: {}", workout_idx + 1, workout_step.note)
        };

        // ── get_proposed ────────────────────────────────────────────────────
        let proposed_response = if let Some(gp) = &workout_step.get_proposed {
            let at_time = parse_ts(&gp.at);
            let resp = scheduler
                .get_proposed_schedule(&user_id, at_time)
                .await
                .unwrap_or_else(|e| panic!("{}: get_proposed_schedule failed: {}", step_desc, e));

            // Validate expectations
            if let Some(expect) = &gp.expect {
                if let Some(expected_ready) = expect.is_ready {
                    let ready = resp
                        .session_readiness
                        .as_ref()
                        .map(|sr| sr.is_ready)
                        .unwrap_or(false);
                    assert_eq!(
                        ready, expected_ready,
                        "{}: session_readiness.is_ready mismatch",
                        step_desc
                    );
                }

                if let Some(expected_name) = &expect.suggested_name {
                    assert_eq!(
                        resp.suggested_workout_name, *expected_name,
                        "{}: suggested_workout_name mismatch",
                        step_desc
                    );
                }

                if expect.exact_groups && !expect.groups.is_empty() {
                    assert_eq!(
                        resp.proposed_groups.len(),
                        expect.groups.len(),
                        "{}: proposed group count mismatch (exact_groups=true)",
                        step_desc
                    );
                    if expect.exact_group_order {
                        let actual_names: Vec<&str> = resp
                            .proposed_groups
                            .iter()
                            .map(|g| g.name.as_str())
                            .collect();
                        let expected_names: Vec<&str> =
                            expect.groups.iter().map(|g| g.name.as_str()).collect();
                        assert_eq!(
                            actual_names, expected_names,
                            "{}: proposed group order mismatch",
                            step_desc
                        );
                    }
                }

                for group_expect in &expect.groups {
                    let group = resp
                        .proposed_groups
                        .iter()
                        .find(|g| g.name == group_expect.name)
                        .unwrap_or_else(|| {
                            panic!(
                                "{}: Expected group '{}' not found in proposed groups: {:?}",
                                step_desc,
                                group_expect.name,
                                resp.proposed_groups.iter().map(|g| &g.name).collect::<Vec<_>>()
                            )
                        });

                    assert_eq!(
                        group.sets, group_expect.sets,
                        "{}: Group '{}' sets mismatch",
                        step_desc, group_expect.name
                    );

                    if let Some(expected) = group_expect.interleave_warmups {
                        assert_eq!(
                            group.interleave_warmups, expected,
                            "{}: Group '{}' interleave_warmups mismatch",
                            step_desc, group_expect.name
                        );
                    }
                    if let Some(expected) = group_expect.prescribed_by_regime {
                        assert_eq!(
                            group.prescribed_by_regime, expected,
                            "{}: Group '{}' prescribed_by_regime mismatch",
                            step_desc, group_expect.name
                        );
                    }
                    if !group_expect.tags.is_empty() {
                        assert_eq!(
                            group.tags, group_expect.tags,
                            "{}: Group '{}' tags mismatch",
                            step_desc, group_expect.name
                        );
                    }
                    if group_expect.rest_after_success.is_some() || group_expect.rest_after_failure.is_some() {
                        let actual_rc = group.rest_config.as_ref().unwrap_or_else(|| {
                            panic!(
                                "{}: Group '{}' expected rest_config but none present",
                                step_desc, group_expect.name
                            )
                        });
                        if let Some(expected) = group_expect.rest_after_success {
                            assert_eq!(
                                actual_rc.rest_after_success, expected,
                                "{}: Group '{}' rest_after_success mismatch",
                                step_desc, group_expect.name
                            );
                        }
                        if let Some(expected) = group_expect.rest_after_failure {
                            assert_eq!(
                                actual_rc.rest_after_failure, expected,
                                "{}: Group '{}' rest_after_failure mismatch",
                                step_desc, group_expect.name
                            );
                        }
                    }

                    if !group_expect.exercise_configs.is_empty() {
                        assert_eq!(
                            group.exercise_configs.len(),
                            group_expect.exercise_configs.len(),
                            "{}: Group '{}' exercise_configs count mismatch",
                            step_desc, group_expect.name
                        );

                        for (cfg_idx, (cfg, cfg_expect)) in group
                            .exercise_configs
                            .iter()
                            .zip(group_expect.exercise_configs.iter())
                            .enumerate()
                        {
                            let actual_ex = exercise_int_to_name(cfg.exercise);
                            let expected_ex =
                                cfg_expect.exercise.to_lowercase().replace(' ', "_");
                            assert_eq!(
                                actual_ex, expected_ex,
                                "{}: Group '{}' cfg #{} exercise mismatch",
                                step_desc, group_expect.name, cfg_idx + 1
                            );
                            assert_f32_close(
                                cfg.start_weight,
                                cfg_expect.start_weight,
                                &format!(
                                    "{}: Group '{}' cfg #{} start_weight mismatch",
                                    step_desc, group_expect.name, cfg_idx + 1
                                ),
                            );
                            assert_f32_close(
                                cfg.end_weight,
                                cfg_expect.end_weight,
                                &format!(
                                    "{}: Group '{}' cfg #{} end_weight mismatch",
                                    step_desc, group_expect.name, cfg_idx + 1
                                ),
                            );
                            assert_eq!(
                                cfg.reps, cfg_expect.reps,
                                "{}: Group '{}' cfg #{} reps mismatch",
                                step_desc, group_expect.name, cfg_idx + 1
                            );
                            assert_eq!(
                                cfg.include_warmup, cfg_expect.include_warmup,
                                "{}: Group '{}' cfg #{} include_warmup mismatch",
                                step_desc, group_expect.name, cfg_idx + 1
                            );
                            assert_eq!(
                                cfg.last_set_amrap, cfg_expect.last_set_amrap,
                                "{}: Group '{}' cfg #{} last_set_amrap mismatch",
                                step_desc, group_expect.name, cfg_idx + 1
                            );

                            if !cfg_expect.working_sets.is_empty() {
                                assert_eq!(
                                    cfg.working_sets.len(),
                                    cfg_expect.working_sets.len(),
                                    "{}: Group '{}' cfg #{} working_sets count mismatch",
                                    step_desc, group_expect.name, cfg_idx + 1
                                );
                                for (ws_idx, (ws, ws_expect)) in cfg
                                    .working_sets
                                    .iter()
                                    .zip(cfg_expect.working_sets.iter())
                                    .enumerate()
                                {
                                    assert_f32_close(
                                        ws.target_weight,
                                        ws_expect.weight,
                                        &format!(
                                            "{}: Group '{}' cfg #{} ws #{} weight mismatch",
                                            step_desc, group_expect.name, cfg_idx + 1, ws_idx + 1
                                        ),
                                    );
                                    assert_eq!(
                                        ws.target_reps, ws_expect.reps,
                                        "{}: Group '{}' cfg #{} ws #{} reps mismatch",
                                        step_desc, group_expect.name, cfg_idx + 1, ws_idx + 1
                                    );
                                    assert_eq!(
                                        ws.is_amrap, ws_expect.is_amrap,
                                        "{}: Group '{}' cfg #{} ws #{} is_amrap mismatch",
                                        step_desc, group_expect.name, cfg_idx + 1, ws_idx + 1
                                    );
                                }
                            }
                        }
                    }

                    if let Some(cfg) = group.exercise_configs.first() {
                        // For single-weight groups, start_weight == end_weight.
                        // For Wendler, working_sets has the actual weights.
                        let weight = if !cfg.working_sets.is_empty() {
                            cfg.working_sets[0].target_weight
                        } else {
                            cfg.start_weight
                        };
                        assert!(
                            (weight - group_expect.weight).abs() < 1.0,
                            "{}: Group '{}' weight mismatch: expected {}, got {}",
                            step_desc, group_expect.name, group_expect.weight, weight
                        );

                        let reps = if !cfg.working_sets.is_empty() {
                            cfg.working_sets[0].target_reps
                        } else {
                            cfg.reps
                        };
                        assert_eq!(
                            reps, group_expect.reps,
                            "{}: Group '{}' reps mismatch",
                            step_desc, group_expect.name
                        );
                    }
                }
            }

            maybe_dump_proposed_snapshot(workout_idx, &step_desc, &resp);
            Some(resp)
        } else {
            let start_at = parse_ts(&workout_step.start.at);
            Some(
                scheduler
                    .get_proposed_schedule(&user_id, start_at)
                    .await
                    .unwrap_or_else(|e| panic!("{}: get_proposed_schedule failed: {}", step_desc, e)),
            )
        };

        // ── Start workout ───────────────────────────────────────────────────
        let start_time = parse_ts(&workout_step.start.at);
        let workout_id = Uuid::new_v4().to_string();
        let session_id = Uuid::new_v4().to_string();

        let proposed_response = proposed_response.unwrap();

        // Convert ProposedExerciseGroups → ExerciseGroups
        let exercise_groups: Vec<ExerciseGroup> = proposed_response
            .proposed_groups
            .iter()
            .enumerate()
            .map(|(idx, pg)| {
                let mut eg = ExerciseGroup {
                    id: Uuid::new_v4().to_string(),
                    workout_id: workout_id.clone(),
                    name: pg.name.clone(),
                    sets: pg.sets,
                    interleave_warmups: pg.interleave_warmups,
                    workout_order: idx as i32,
                    exercise_configs: pg.exercise_configs.clone(),
                    rest_config: pg.rest_config.clone(),
                    instruction: pg.explanation.clone(),
                    prescribed_by_regime: pg.prescribed_by_regime,
                };
                materialize_group_working_sets(&mut eg);
                eg
            })
            .collect();

        // Generate proposed sets for each group
        let mut all_proposed_sets: Vec<ProposedSet> = Vec::new();
        let mut set_order = 0i32;
        for g in &exercise_groups {
            let generated = generate_sets_for_group(&workout_id, g, set_order);
            set_order += generated.len() as i32;
            all_proposed_sets.extend(generated);
        }

        // Create workout record in DB
        let workout = Workout {
            id: workout_id.clone(),
            name: proposed_response.suggested_workout_name.clone(),
            start_time,
            end_time: 0,
            session_id: session_id.clone(),
        };

        db.create_workout_record(&user_id, &workout)
            .await
            .expect("Failed to create workout record");

        for g in &exercise_groups {
            let sets: Vec<ProposedSet> = all_proposed_sets
                .iter()
                .filter(|s| s.exercise_group_id == g.id)
                .cloned()
                .collect();
            db.insert_exercise_group_with_sets(&user_id, g, &sets)
                .await
                .expect("Failed to insert exercise group with sets");
        }

        let mut active = ActiveState {
            _workout: workout,
            _exercise_groups: exercise_groups,
            proposed_sets: all_proposed_sets,
            completed_sets: Vec::new(),
        };

        // Ensure scenario enumerates the full recommended working plan in order.
        let recommended_group_ids: std::collections::HashSet<String> = proposed_response
            .proposed_groups
            .iter()
            .enumerate()
            .filter(|(_, pg)| pg.tags.iter().any(|t| t == "recommended"))
            .map(|(idx, _)| active._exercise_groups[idx].id.clone())
            .collect();
        if workout_step.assert_recommended_plan_matches_sets {
            assert_proposed_working_sets_match_scenario(
                &step_desc,
                &active.proposed_sets,
                &recommended_group_ids,
                &workout_step.sets,
            );
        }

        // ── Auto-complete all warmup sets at once before doing working sets ──
        // We complete all warmups at a fixed offset after start_time
        let mut fake_warmup_time = start_time + 30;
        let warmup_ids: Vec<String> = active
            .proposed_sets
            .iter()
            .filter(|p| p.warmup && !p.cancelled)
            .map(|p| p.id.clone())
            .collect();
        for ps_id in warmup_ids {
            let ps = active
                .proposed_sets
                .iter()
                .find(|p| p.id == ps_id)
                .unwrap()
                .clone();
            let cs = CompletedSet {
                id: Uuid::new_v4().to_string(),
                workout_id: workout_id.clone(),
                proposed_set_id: ps.id.clone(),
                actual_reps: ps.target_reps,
                actual_weight: ps.target_weight,
                started_at: fake_warmup_time,
                ended_at: fake_warmup_time + 30,
                rest_until: fake_warmup_time + 40,
            };
            fake_warmup_time += 60;
            db.upsert_completed_set(&user_id, &cs)
                .await
                .expect("Failed to upsert warmup completed set");
            active.completed_sets.push(cs);
        }

        // ── Process working sets listed in scenario ─────────────────────────
        for set_step in &workout_step.sets {
            let set_desc = if set_step.note.is_empty() {
                format!("{} / {} set", step_desc, set_step.exercise)
            } else {
                format!("{} / {}", step_desc, set_step.note)
            };

            let ex_int = exercise_name_to_int(&set_step.exercise);
            let started_at = parse_ts(&set_step.start_at);
            let ended_at = parse_ts(&set_step.end_at);

            // Find the matching uncompleted working proposed set
            let completed_ps_ids: std::collections::HashSet<String> = active
                .completed_sets
                .iter()
                .map(|c| c.proposed_set_id.clone())
                .collect();

            let ps = active
                .proposed_sets
                .iter()
                .filter(|p| {
                    !p.warmup
                        && !p.cancelled
                        && p.exercise == ex_int
                        && !completed_ps_ids.contains(&p.id)
                        && (set_step.target_weight <= 0.0
                            || (p.target_weight - set_step.target_weight).abs() < 1.0)
                        && (set_step.target_reps <= 0
                            || p.target_reps == set_step.target_reps)
                })
                .min_by_key(|p| p.workout_order)
                .unwrap_or_else(|| {
                    panic!(
                        "{}: Could not find uncompleted working proposed set for exercise='{}' weight={} reps={}.\nAvailable uncompleted sets: {:?}",
                        set_desc,
                        set_step.exercise,
                        set_step.target_weight,
                        set_step.target_reps,
                        active.proposed_sets.iter()
                            .filter(|p| !p.warmup && !p.cancelled && !completed_ps_ids.contains(&p.id))
                            .map(|p| format!("ex={} w={} r={} order={}", exercise_int_to_name(p.exercise), p.target_weight, p.target_reps, p.workout_order))
                            .collect::<Vec<_>>()
                    )
                })
                .clone();

            // Complete the set
            let ps_target_reps = ps.target_reps;
            let ps_rest_s = ps.rest_after_success as i64;
            let ps_rest_f = ps.rest_after_failure as i64;
            let rest_secs = if set_step.actual_reps >= ps_target_reps {
                ps_rest_s
            } else {
                ps_rest_f
            };
            let rest_until = ended_at + rest_secs;

            let cs = CompletedSet {
                id: Uuid::new_v4().to_string(),
                workout_id: workout_id.clone(),
                proposed_set_id: ps.id.clone(),
                actual_reps: set_step.actual_reps,
                actual_weight: ps.target_weight,
                started_at,
                ended_at,
                rest_until,
            };
            db.upsert_completed_set(&user_id, &cs)
                .await
                .unwrap_or_else(|e| panic!("{}: Failed to upsert completed set: {}", set_desc, e));
            active.completed_sets.push(cs);

            // Validate expect_next
            if let Some(next) = &set_step.expect_next {
                let completed_ids_now: std::collections::HashSet<String> = active
                    .completed_sets
                    .iter()
                    .map(|c| c.proposed_set_id.clone())
                    .collect();

                let next_ex_int = exercise_name_to_int(&next.exercise);
                let next_ps = active
                    .proposed_sets
                    .iter()
                    .filter(|p| {
                        !p.warmup
                            && !p.cancelled
                            && p.exercise == next_ex_int
                            && !completed_ids_now.contains(&p.id)
                    })
                    .min_by_key(|p| p.workout_order);

                match next_ps {
                    Some(np) => {
                        assert!(
                            (np.target_weight - next.weight).abs() < 1.0,
                            "{}: expect_next weight mismatch: expected {} got {}",
                            set_desc, next.weight, np.target_weight
                        );
                        assert_eq!(
                            np.target_reps, next.reps,
                            "{}: expect_next reps mismatch: expected {} got {}",
                            set_desc, next.reps, np.target_reps
                        );
                    }
                    None => {
                        panic!(
                            "{}: expect_next specified '{}' but no uncompleted working set found",
                            set_desc, next.exercise
                        );
                    }
                }
            }
        }

        // ── End workout ─────────────────────────────────────────────────────
        let end_time = parse_ts(&workout_step.end.at);
        db.update_workout_end_time(&user_id, &workout_id, end_time)
            .await
            .unwrap_or_else(|e| panic!("{}: Failed to update workout end time: {}", step_desc, e));

        // Flush writes to ensure DB is consistent before next get_proposed_schedule
        db.flush_writes()
            .await
            .unwrap_or_else(|e| panic!("{}: Failed to flush writes: {}", step_desc, e));

        eprintln!("  [OK] {}", step_desc);
    }

    eprintln!("Scenario '{}' passed ({} workouts).", scenario.description, scenario.workouts.len());
}

// ─── Test entry points ─────────────────────────────────────────────────────────

#[cfg(test)]
#[path = "test_harness_tests.rs"]
mod tests;
