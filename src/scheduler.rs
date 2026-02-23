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
        now: i64,
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
        let regime_type =
            RegimeType::try_from(workout_config.regime_type).unwrap_or(RegimeType::Linear5x5);
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
        let now = if now == 0 { Utc::now().timestamp() } else { now };
        let recovery_seconds = MUSCLE_RECOVERY_HOURS * 3600;
        let mut muscle_group_last_worked: std::collections::HashMap<i32, i64> =
            std::collections::HashMap::new();
        for config in EXERCISE_CONFIGS {
            let ex_int = config.exercise as i32;
            let last_performed = all_history
                .get(&ex_int)
                .and_then(|h| h.first())
                .map(|h| h.timestamp)
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

            let last_perf = history.first().map(|h| h.timestamp).unwrap_or(0);
            let weight_history: Vec<f32> = history.iter().rev().map(|h| h.weight).collect();

            let proposal = regime.calculate_exercise_progression(
                config.exercise,
                config,
                history,
                max_weight,
                &workout_config,
                now,
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
        let mut proposed_groups = regime.build_proposed_groups(&exercise_statuses, &workout_config);
        for group in &mut proposed_groups {
            group.prescribed_by_regime = true;
        }

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
            now,
        );

        let suggested_workout_name = regime.suggested_workout_name(&workout_config);

        Ok(GetProposedWorkoutScheduleResponse {
            exercise_statuses,
            active_workout_id: String::new(), // filled in by service handler
            proposed_groups,
            regime_context: Some(regime_context),
            session_readiness: Some(session_readiness),
            suggested_workout_name,
        })
    }
}

#[cfg(test)]
#[path = "scheduler_tests.rs"]
mod tests;
