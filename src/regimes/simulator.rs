//! Deterministic regime simulator.
//!
//! Runs a regime forward through a scripted series of sessions using the same
//! calls the production path makes:
//!
//! ```text
//! apply_temporal_adjustments_for_proposal   (layoff deload)
//!   -> propose_from_state                   (what to lift)
//!   -> prescribed_slots_from_groups         (what counts)
//!   -> transition_state_on_workout_completed (what happens next)
//! ```
//!
//! This is what generates `testdata/regime_timelines.json`, which is both a
//! regression fixture and the reference the browser-based regime explorer is
//! checked against. Keeping one simulator for both means the explorer cannot
//! quietly disagree with the app.

use std::collections::HashMap;

use crate::program_state::StatePayload;
use crate::regimes::{fake_completed_workout, get_regime, WorkoutRegime};
use crate::schplanner::{
    prescribed_slots_from_groups, SchplannerInsights, SchplannerSlotOutcome,
};
use schlift::workout::v1::RegimeType;

/// What the lifter did in one session.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SessionResult {
    /// Every prescribed working set hit its target reps.
    HitEverything,
    /// Completed every set but fell short on reps — a stall.
    MissedReps,
}

/// One scripted session: how long after the previous one, and how it went.
#[derive(Clone, Copy, Debug)]
pub struct ScriptedSession {
    pub days_after_previous: i64,
    pub result: SessionResult,
}

impl ScriptedSession {
    pub fn hit(days_after_previous: i64) -> Self {
        Self {
            days_after_previous,
            result: SessionResult::HitEverything,
        }
    }

    pub fn missed(days_after_previous: i64) -> Self {
        Self {
            days_after_previous,
            result: SessionResult::MissedReps,
        }
    }
}

/// A run of identical prescribed working sets, e.g. `5 x 5 @ 135`. Collapsing
/// repeats keeps the generated fixture readable and an order of magnitude
/// smaller than listing every set.
#[derive(Clone, Debug, PartialEq, serde::Serialize)]
pub struct SimulatedSet {
    pub weight: f32,
    pub reps: i32,
    pub count: i32,
    pub is_amrap: bool,
}

#[derive(Clone, Debug, serde::Serialize)]
pub struct SimulatedExercise {
    pub exercise: String,
    pub tier: String,
    pub sets: Vec<SimulatedSet>,
}

#[derive(Clone, Debug, serde::Serialize)]
pub struct SimulatedSession {
    /// Days since the start of the simulation.
    pub day: i64,
    pub days_since_previous: i64,
    pub workout_name: String,
    /// True when the gap triggered a layoff deload.
    pub deloaded: bool,
    pub result: String,
    pub exercises: Vec<SimulatedExercise>,
    /// Weights that changed as a result of this session. The first session
    /// carries the full starting state; later ones carry only the deltas, which
    /// keeps the fixture small and makes a diff show exactly what a session did.
    pub weight_changes: HashMap<String, f32>,
}

const DAY: i64 = 24 * 3600;
const START_TS: i64 = 1_700_000_000;

fn weight_fields(state: &StatePayload) -> HashMap<String, f32> {
    state
        .iter()
        .filter_map(|(k, v)| match v {
            crate::program_state::FieldVal::Float(f) => Some((k.clone(), *f as f32)),
            _ => None,
        })
        .collect()
}

/// Build the outcome for each prescribed slot, given how the session went.
fn outcomes_for(
    regime: &dyn WorkoutRegime,
    state: &StatePayload,
    last_session_at: i64,
    now: i64,
    result: SessionResult,
) -> (
    Vec<SimulatedExercise>,
    String,
    HashMap<String, SchplannerSlotOutcome>,
) {
    let proposal = regime.propose_from_state(
        state,
        last_session_at,
        now,
        &SchplannerInsights::default(),
    );
    let prescribed = prescribed_slots_from_groups(&proposal.proposed_groups);

    // The weight actually lifted per slot: whatever the proposal asked for.
    let mut slot_weight: HashMap<String, f32> = HashMap::new();
    let mut exercises = Vec::new();
    for group in &proposal.proposed_groups {
        for config in &group.exercise_configs {
            let mut sets: Vec<SimulatedSet> = Vec::new();
            let mut tier = String::new();
            for ws in &config.working_sets {
                let entry = SimulatedSet {
                    weight: ws.target_weight,
                    reps: ws.target_reps,
                    count: 1,
                    is_amrap: ws.is_amrap,
                };
                match sets.last_mut() {
                    Some(last)
                        if last.weight == entry.weight
                            && last.reps == entry.reps
                            && last.is_amrap == entry.is_amrap =>
                    {
                        last.count += 1;
                    }
                    _ => sets.push(entry),
                }
                if let Some(hint) = ws.progression_hint.as_ref() {
                    tier = hint.tier.clone();
                    slot_weight.insert(hint.slot_key.clone(), ws.target_weight);
                }
            }
            if sets.is_empty() {
                continue;
            }
            exercises.push(SimulatedExercise {
                exercise: crate::regimes::exercise_display_name(
                    schlift::workout::v1::Exercise::try_from(config.exercise)
                        .unwrap_or(schlift::workout::v1::Exercise::Unspecified),
                ),
                tier,
                sets,
            });
        }
    }

    let mut outcomes = HashMap::new();
    for (slot_key, slot) in &prescribed {
        let weight = slot_weight.get(slot_key).copied().unwrap_or(0.0);
        let hit = result == SessionResult::HitEverything;
        // On a miss, fall one set short of the target and one rep short on top.
        let successful = if hit { slot.set_count } else { 0 };
        let top_reps = if hit {
            slot.target_reps.max(slot.amrap_success_threshold)
        } else {
            (slot.target_reps - 2).max(1)
        };

        outcomes.insert(
            slot_key.clone(),
            SchplannerSlotOutcome {
                slot_key: slot_key.clone(),
                exercise: slot.exercise,
                tier: slot.tier.clone(),
                rule: slot.rule,
                planned_sets: slot.set_count,
                completed_sets: slot.set_count,
                successful_sets: successful,
                last_completed_actual_weight: Some(weight),
                last_successful_actual_weight: if hit { Some(weight) } else { None },
                top_set_target_reps: slot.target_reps,
                top_set_actual_reps: top_reps,
                amrap_success_threshold: slot.amrap_success_threshold,
                workout_ended: true,
            },
        );
    }

    (exercises, proposal.suggested_workout_name, outcomes)
}

/// Run `script` against `regime_type`, starting from `initial_state`.
pub fn simulate(
    regime_type: RegimeType,
    initial_state: StatePayload,
    script: &[ScriptedSession],
) -> Vec<SimulatedSession> {
    let regime = get_regime(regime_type);
    let mut state = initial_state;
    let mut last_session_at = 0i64;
    let mut now = START_TS;
    let mut day = 0i64;
    let mut out = Vec::new();
    let mut previous_weights: Option<HashMap<String, f32>> = None;

    for session in script {
        if last_session_at != 0 {
            now += session.days_after_previous * DAY;
            day += session.days_after_previous;
        }

        // Mirror production: the layoff deload is applied to the state the
        // proposal is built from, and the same adjusted state is what the
        // session's result is reconciled against.
        let adjusted =
            regime.apply_temporal_adjustments_for_proposal(&state, last_session_at, now);
        let deloaded = weight_fields(&adjusted) != weight_fields(&state);

        let (exercises, workout_name, outcomes) =
            outcomes_for(regime.as_ref(), &adjusted, last_session_at, now, session.result);

        let mut next = adjusted;
        regime.transition_state_on_workout_completed(
            &mut next,
            &fake_completed_workout(now),
            &outcomes,
        );

        out.push(SimulatedSession {
            day,
            days_since_previous: if last_session_at == 0 {
                0
            } else {
                session.days_after_previous
            },
            workout_name,
            deloaded,
            result: match session.result {
                SessionResult::HitEverything => "hit".to_string(),
                SessionResult::MissedReps => "missed".to_string(),
            },
            exercises,
            weight_changes: {
                let current = weight_fields(&next);
                match &previous_weights {
                    None => current.clone(),
                    Some(prev) => current
                        .iter()
                        .filter(|(k, v)| prev.get(*k).is_none_or(|p| p != *v))
                        .map(|(k, v)| (k.clone(), *v))
                        .collect(),
                }
            },
        });
        previous_weights = Some(weight_fields(&next));

        state = next;
        last_session_at = now;
    }

    out
}
