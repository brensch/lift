use chrono::Utc;
use lift::workout::v1::{
    ExerciseStatus, GetProposedWorkoutScheduleResponse, RegimeType, UserWorkoutConfig,
};

use crate::db::CentralDb;
use crate::regimes::{build_session_readiness, get_regime, EXERCISE_CONFIGS};

/// Recovery time for muscle group readiness display (24h)
const MUSCLE_RECOVERY_HOURS: i64 = 24;

pub struct Scheduler {
    central_db: CentralDb,
}

impl Scheduler {
    pub fn new(central_db: CentralDb) -> Self {
        Self { central_db }
    }

    pub async fn get_proposed_schedule(
        &self,
        user_id: &str,
    ) -> Result<GetProposedWorkoutScheduleResponse, Box<dyn std::error::Error + Send + Sync>> {
        // ── 1. Load user config (regime selection + state) ────────────────────
        let mut workout_config = self
            .central_db
            .get_user_workout_config(user_id)
            .await?
            .unwrap_or_else(|| UserWorkoutConfig {
                regime_type: RegimeType::Linear5x5 as i32,
                days_per_week: 3,
                one_rep_maxes: std::collections::HashMap::new(),
                regime_state_json: "{}".to_string(),
            });

        // ── 2. Load exercise history ─────────────────────────────────────────
        let (all_history, all_max_weights) = self
            .central_db
            .get_all_exercise_history(user_id, 10)
            .await?;

        // ── 3. Get the active regime implementation ──────────────────────────
        let regime_type = RegimeType::try_from(workout_config.regime_type)
            .unwrap_or(RegimeType::Linear5x5);
        let regime = get_regime(regime_type);

        // ── 4. Compute updated state and persist if changed ──────────────────
        let new_state_json = regime.compute_updated_state(&workout_config, &all_history);
        if new_state_json != workout_config.regime_state_json {
            workout_config.regime_state_json = new_state_json;
            // Persist the updated state via the settings write path
            use lift::workout::v1::{user_setting::Setting, UserSetting};
            use prost::Message;
            let setting = UserSetting {
                setting: Some(Setting::WorkoutConfig(workout_config.clone())),
            };
            let blob = setting.encode_to_vec();
            self.central_db
                .insert_user_setting(user_id, "workout_config", &blob)
                .await?;
        }

        // ── 5. Build muscle group recovery map ───────────────────────────────
        let now = Utc::now().timestamp();
        let recovery_seconds = MUSCLE_RECOVERY_HOURS * 3600;
        let mut muscle_group_last_worked: std::collections::HashMap<i32, i64> =
            std::collections::HashMap::new();
        for config in EXERCISE_CONFIGS {
            let ex_int = config.exercise as i32;
            let last_performed = all_history
                .get(&ex_int)
                .and_then(|h| h.first())
                .map(|(_, _, date)| *date)
                .unwrap_or(0);
            if last_performed > 0 {
                for mg in config.muscle_groups {
                    let entry = muscle_group_last_worked.entry(*mg as i32).or_insert(0);
                    if last_performed > *entry {
                        *entry = last_performed;
                    }
                }
            }
        }

        // ── 6. Build ExerciseStatus list ─────────────────────────────────────
        let mut exercise_statuses = Vec::new();
        for config in EXERCISE_CONFIGS {
            let ex_int = config.exercise as i32;
            let empty = Vec::new();
            let history = all_history.get(&ex_int).unwrap_or(&empty);
            let max_weight = all_max_weights.get(&ex_int).copied().unwrap_or(0.0);

            let last_perf = history.first().map(|(_, _, t)| *t).unwrap_or(0);
            let weight_history: Vec<f32> = history.iter().rev().map(|(w, _, _)| *w).collect();

            let proposal = regime.calculate_exercise_progression(
                config.exercise,
                config,
                history,
                max_weight,
                &workout_config,
            );

            let recovered = config.muscle_groups.iter().all(|mg| {
                match muscle_group_last_worked.get(&(*mg as i32)) {
                    None => true,
                    Some(&last) => (now - last) >= recovery_seconds,
                }
            });

            exercise_statuses.push(ExerciseStatus {
                exercise: config.exercise as i32,
                target_weight: proposal.weight,
                explanation: proposal.explanation,
                last_performed_at: last_perf,
                weight_history,
                muscle_groups: config.muscle_groups.iter().map(|mg| *mg as i32).collect(),
                default_sets: proposal.sets,
                default_reps: proposal.reps,
                recovered,
                always_include: config.always_include,
                category: config.category as i32,
            });
        }

        // ── 7. Build proposed groups ─────────────────────────────────────────
        let proposed_groups = regime.build_proposed_groups(&exercise_statuses, &workout_config);

        // ── 8. Regime context (session description, coaching notes) ──────────
        let regime_context = regime.build_regime_context(&workout_config, &exercise_statuses);

        // ── 9. Session readiness ─────────────────────────────────────────────
        let last_session_at = self
            .central_db
            .get_last_workout_end_time(user_id)
            .await?
            .unwrap_or(0);
        let recovery_secs = regime.recovery_seconds(&workout_config);
        let days_per_week = if workout_config.days_per_week > 0 {
            workout_config.days_per_week
        } else {
            regime.default_days_per_week()
        };
        let session_readiness = build_session_readiness(
            last_session_at,
            recovery_secs,
            regime.display_name(),
            days_per_week,
        );

        Ok(GetProposedWorkoutScheduleResponse {
            exercise_statuses,
            active_workout_id: String::new(), // filled in by service handler
            proposed_groups,
            regime_context: Some(regime_context),
            session_readiness: Some(session_readiness),
        })
    }
}

#[cfg(test)]
mod tests {
    use crate::regimes::linear_5x5::{build_linear_proposed_groups, calculate_linear_progression};
    use lift::workout::v1::{Exercise, ExerciseCategory, ExerciseStatus};

    fn status(exercise: Exercise, last_performed_at: i64) -> ExerciseStatus {
        ExerciseStatus {
            exercise: exercise as i32,
            target_weight: 100.0,
            explanation: String::new(),
            last_performed_at,
            weight_history: vec![],
            muscle_groups: vec![],
            default_sets: 5,
            default_reps: 5,
            recovered: true,
            always_include: exercise == Exercise::Squat,
            category: ExerciseCategory::Compound as i32,
        }
    }

    #[test]
    fn proposed_groups_include_explanations() {
        let mut squat_status = status(Exercise::Squat, 1_000);
        squat_status.explanation = "Squat explanation".to_string();

        let mut bench_status = status(Exercise::BenchPress, 3_000);
        bench_status.explanation = "Bench explanation".to_string();

        let statuses = vec![squat_status, bench_status];

        let groups = build_linear_proposed_groups(&statuses);

        let squat_group = groups.iter().find(|g| g.name == "Squat").unwrap();
        assert_eq!(squat_group.explanation, "Squat explanation");

        let bench_group = groups.iter().find(|g| g.name == "Bench Press").unwrap();
        assert_eq!(bench_group.explanation, "Bench explanation");
    }

    #[test]
    fn proposed_groups_prioritize_compound_rotation_defaults() {
        let statuses = vec![
            status(Exercise::Squat, 1_000),
            status(Exercise::BenchPress, 3_000),
            status(Exercise::Deadlift, 2_000),
            status(Exercise::OverheadPress, 4_000),
            status(Exercise::BarbellRow, 1_500),
            status(Exercise::HipThrust, 0),
        ];

        let groups = build_linear_proposed_groups(&statuses);

        assert_eq!(groups[0].name, "Squat");
        assert_eq!(groups[1].name, "Barbell Row");
        assert_eq!(groups[2].name, "Deadlift");
        assert!(groups
            .iter()
            .any(|g| g.tags.contains(&"auxiliary".to_string())));
        // Top 3 (squat + 2 stalest rotation) should be tagged recommended
        assert!(groups[0].tags.contains(&"recommended".to_string()));
        assert!(groups[1].tags.contains(&"recommended".to_string()));
        assert!(groups[2].tags.contains(&"recommended".to_string()));
    }

    #[test]
    fn linear_progression_standard() {
        // Use a recent timestamp (yesterday) to avoid deload triggers
        let yesterday = chrono::Utc::now().timestamp() - 86400;
        let history = vec![(100.0f32, true, yesterday)];
        let (weight, explanation) =
            calculate_linear_progression(Exercise::BenchPress as i32, 45.0, &history, 100.0);
        assert_eq!(weight, 105.0);
        assert!(explanation.contains("105"));
    }

    #[test]
    fn linear_progression_failure_holds() {
        let yesterday = chrono::Utc::now().timestamp() - 86400;
        let history = vec![(100.0f32, false, yesterday)];
        let (weight, _) =
            calculate_linear_progression(Exercise::BenchPress as i32, 45.0, &history, 100.0);
        assert_eq!(weight, 100.0);
    }

    #[test]
    fn linear_progression_plateau_deloads() {
        let now = chrono::Utc::now().timestamp();
        let history = vec![
            (100.0f32, false, now - 3 * 86400),
            (100.0f32, false, now - 6 * 86400),
            (100.0f32, false, now - 9 * 86400),
        ];
        let (weight, _) =
            calculate_linear_progression(Exercise::BenchPress as i32, 45.0, &history, 100.0);
        assert!(weight < 100.0);
    }
}
