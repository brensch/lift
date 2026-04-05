use chrono::Utc;
use lift::workout::v1::{GetProposedWorkoutScheduleResponse, RegimeType};

use crate::db::CentralDb;
use crate::program_state::{parse_state_payload, pending_update_to_proto};
use crate::regimes::{build_exercise_statuses, build_session_readiness, get_regime};
use crate::weight_units::{annotate_state_with_weight_unit, get_user_weight_unit, AppWeightUnit};

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
        let now = if now == 0 {
            Utc::now().timestamp()
        } else {
            now
        };

        // ── 1. Load latest program state ─────────────────────────────────────
        let state_record = self.central_db.get_latest_program_state(user_id).await?;
        let (regime_type, state) = match state_record {
            Some(ref rec) => {
                let rt = RegimeType::try_from(rec.regime_type).unwrap_or(RegimeType::Linear5x5);
                let st = parse_state_payload(&rec.state_payload_json);
                (rt, st)
            }
            None => {
                // User hasn't completed onboarding — use default state
                let regime = get_regime(RegimeType::Linear5x5);
                (RegimeType::Linear5x5, regime.default_state())
            }
        };
        let regime = get_regime(regime_type);
        let weight_unit = get_user_weight_unit(&self.central_db, user_id)
            .await
            .unwrap_or(AppWeightUnit::Lb);
        let state = annotate_state_with_weight_unit(&state, weight_unit);

        // ── 2. Load exercise history ──────────────────────────────────────────
        let (all_history, all_max_weights) = self
            .central_db
            .get_all_exercise_history(user_id, 100)
            .await?;

        // ── 3. Get last session end time ──────────────────────────────────────
        let last_session_at = self
            .central_db
            .get_last_workout_end_time(user_id)
            .await?
            .unwrap_or(0);

        // ── 4. Compute proposal from state ────────────────────────────────────
        let propose_result = regime.propose_from_state(&state, last_session_at, now);

        // ── 5. Check for pending state updates (may block workout start) ──────
        let pending_defs = regime.pending_updates_for_state(&state, last_session_at, now);
        let can_start_workout = pending_defs.is_empty();
        let pending_state_updates = pending_defs
            .into_iter()
            .map(pending_update_to_proto)
            .collect();

        // ── 6. Session readiness banner ───────────────────────────────────────
        let recovery_secs = regime.recovery_seconds_for_state(&state);
        let days_per_week = regime.default_days_per_week();
        let session_readiness = build_session_readiness(
            last_session_at,
            recovery_secs,
            &propose_result.regime_context.regime_display_name,
            days_per_week,
            now,
        );

        // ── 7. ExerciseStatus list (for exercise browser) ─────────────────────
        let exercise_statuses = build_exercise_statuses(&all_history, &all_max_weights, now);

        Ok(GetProposedWorkoutScheduleResponse {
            exercise_statuses,
            active_workout_id: String::new(), // filled in by service handler
            proposed_groups: propose_result.proposed_groups,
            regime_context: Some(propose_result.regime_context),
            session_readiness: Some(session_readiness),
            suggested_workout_name: propose_result.suggested_workout_name,
            pending_state_updates,
            can_start_workout,
        })
    }
}

#[cfg(test)]
#[path = "scheduler_tests.rs"]
mod tests;
