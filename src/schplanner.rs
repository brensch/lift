use std::collections::HashMap;

use crate::regimes::progression_slot_key;
use schlift::workout::v1::{
    CompletedSet, Exercise, ExerciseGroup, ProgressionRule, ProposedExerciseGroup, ProposedSet,
    Workout,
};

#[cfg(test)]
use crate::program_state::StatePayload;
#[cfg(test)]
use crate::regimes::WorkoutRegime;

#[allow(dead_code)]
#[derive(Clone, Debug)]
pub struct SchplannerWorkoutRecord {
    pub workout: Workout,
    pub exercise_groups: Vec<ExerciseGroup>,
    pub proposed_sets: Vec<ProposedSet>,
    pub completed_sets: Vec<CompletedSet>,
}

#[allow(dead_code)]
#[derive(Clone, Debug)]
pub struct SchplannerSlotOutcome {
    pub slot_key: String,
    pub exercise: Exercise,
    pub tier: String,
    pub rule: ProgressionRule,
    pub planned_sets: usize,
    pub completed_sets: usize,
    pub successful_sets: usize,
    pub last_completed_actual_weight: Option<f32>,
    pub last_successful_actual_weight: Option<f32>,
    pub top_set_target_reps: i32,
    pub top_set_actual_reps: i32,
    pub amrap_success_threshold: i32,
    pub workout_ended: bool,
}

impl SchplannerSlotOutcome {
    pub fn all_sets_hit_target(&self) -> bool {
        // Judged against the *prescribed* set count: you must successfully complete at
        // least as many working sets as the program asked for. Extra (user-added) sets
        // don't hurt; cancelling prescribed sets to shrink the denominator doesn't help.
        self.planned_sets > 0 && self.successful_sets >= self.planned_sets
    }

    pub fn top_set_hit_threshold(&self) -> bool {
        self.top_set_actual_reps > 0 && self.top_set_actual_reps >= self.amrap_threshold()
    }

    pub fn amrap_threshold(&self) -> i32 {
        self.amrap_success_threshold.max(self.top_set_target_reps)
    }
}

#[cfg(test)]
#[derive(Clone, Debug, Default)]
pub struct SchplannerDerivation {
    pub effective_state: StatePayload,
    pub last_session_at: i64,
}

#[derive(Clone, Debug, Default)]
pub struct SchplannerWindowSlotSummary {
    pub completed_sets: i32,
    pub last_trained_at: i64,
}

#[derive(Clone, Debug, Default)]
pub struct SchplannerWindowSummary {
    pub completed_sessions: i32,
    pub completed_sets: i32,
    pub slots: HashMap<String, SchplannerWindowSlotSummary>,
}

#[derive(Clone, Debug, Default)]
pub struct ProposedSlotTarget {
    pub slot_key: String,
    pub exercise: Exercise,
    pub tier: String,
    pub set_count: i32,
}

#[allow(dead_code)]
#[derive(Clone, Debug, Default)]
pub struct SchplannerTimingStats {
    pub sample_count: usize,
    pub mean_secs: f32,
    pub stddev_secs: f32,
    pub min_secs: i64,
    pub max_secs: i64,
}

#[allow(dead_code)]
#[derive(Clone, Debug, Default)]
pub struct SchplannerRecentExerciseInsights {
    pub exercise: Exercise,
    pub last_completed_at: i64,
    pub last_workout_id: String,
    pub recent_completed_sets: usize,
    pub recent_sessions: usize,
    pub last_actual_reps: i32,
    pub last_target_reps: i32,
    pub last_weight: f32,
    pub last_hit_target: bool,
    pub last_was_amrap: bool,
    pub set_durations: SchplannerTimingStats,
    pub rests: SchplannerTimingStats,
}

#[allow(dead_code)]
impl SchplannerRecentExerciseInsights {
    pub fn last_set_duration_secs(&self) -> i64 {
        self.set_durations.max_secs
    }

    pub fn avg_set_duration_secs(&self) -> f32 {
        self.set_durations.mean_secs
    }

    pub fn avg_rest_secs(&self) -> f32 {
        self.rests.mean_secs
    }
}

#[allow(dead_code)]
#[derive(Clone, Debug, Default)]
pub struct SchplannerRecentSlotInsights {
    pub slot_key: String,
    pub exercise: Exercise,
    pub last_completed_at: i64,
    pub recent_completed_sets: usize,
    pub recent_sessions: usize,
    pub last_actual_reps: i32,
    pub last_target_reps: i32,
    pub last_weight: f32,
    pub last_hit_target: bool,
    pub last_was_amrap: bool,
    pub set_durations: SchplannerTimingStats,
    pub rests: SchplannerTimingStats,
}

#[allow(dead_code)]
#[derive(Clone, Debug, Default)]
pub struct SchplannerInsights {
    pub exercise_insights: HashMap<Exercise, SchplannerRecentExerciseInsights>,
    pub slot_insights: HashMap<String, SchplannerRecentSlotInsights>,
}

#[allow(dead_code)]
impl SchplannerInsights {
    pub fn for_exercise(&self, exercise: Exercise) -> Option<&SchplannerRecentExerciseInsights> {
        self.exercise_insights.get(&exercise)
    }

    pub fn for_slot(&self, slot_key: &str) -> Option<&SchplannerRecentSlotInsights> {
        self.slot_insights.get(slot_key)
    }
}

#[cfg(test)]
pub fn derive_state(
    regime: &dyn WorkoutRegime,
    base_state: &StatePayload,
    history: &[SchplannerWorkoutRecord],
) -> SchplannerDerivation {
    let mut effective_state = base_state.clone();
    let mut last_session_at = 0i64;

    let mut history_sorted = history.to_vec();
    history_sorted.sort_by(|a, b| {
        a.workout
            .start_time
            .cmp(&b.workout.start_time)
            .then_with(|| a.workout.id.cmp(&b.workout.id))
    });

    for workout in &history_sorted {
        last_session_at = last_session_at.max(if workout.workout.end_time > 0 {
            workout.workout.end_time
        } else {
            workout.workout.start_time
        });

        if workout.workout.end_time > 0 {
            let prescribed = prescribed_slots_from_workout(workout);
            let slot_outcomes = summarize_slot_outcomes(workout, &prescribed);
            regime.transition_state_on_workout_completed(
                &mut effective_state,
                workout,
                &slot_outcomes,
            );
        }
    }

    SchplannerDerivation {
        effective_state,
        last_session_at,
    }
}

pub fn summarize_history_window(
    history: &[SchplannerWorkoutRecord],
    window_start: i64,
    window_end: i64,
) -> SchplannerWindowSummary {
    let mut summary = SchplannerWindowSummary::default();

    for workout in history {
        let session_at = if workout.workout.end_time > 0 {
            workout.workout.end_time
        } else {
            workout.workout.start_time
        };
        if session_at < window_start || session_at > window_end {
            continue;
        }
        summary.completed_sessions += 1;

        let completed_by_proposed = workout
            .completed_sets
            .iter()
            .filter(|set| set.ended_at > 0)
            .map(|set| (set.proposed_set_id.as_str(), set))
            .collect::<HashMap<_, _>>();

        for set in workout
            .proposed_sets
            .iter()
            .filter(|set| !set.warmup && !set.cancelled)
        {
            let Some(hint) = set.progression_hint.as_ref() else {
                continue;
            };
            if !hint.counts_toward_program || !completed_by_proposed.contains_key(set.id.as_str()) {
                continue;
            }
            summary.completed_sets += 1;
            let entry = summary
                .slots
                .entry(hint.slot_key.clone())
                .or_insert_with(|| SchplannerWindowSlotSummary {
                    completed_sets: 0,
                    last_trained_at: 0,
                });
            entry.completed_sets += 1;
            entry.last_trained_at = entry.last_trained_at.max(session_at);
        }
    }

    for workout in history {
        let session_at = if workout.workout.end_time > 0 {
            workout.workout.end_time
        } else {
            workout.workout.start_time
        };
        let completed_by_proposed = workout
            .completed_sets
            .iter()
            .filter(|set| set.ended_at > 0)
            .map(|set| set.proposed_set_id.as_str())
            .collect::<Vec<_>>();
        if completed_by_proposed.is_empty() {
            continue;
        }
        for set in workout
            .proposed_sets
            .iter()
            .filter(|set| !set.warmup && !set.cancelled)
        {
            let Some(hint) = set.progression_hint.as_ref() else {
                continue;
            };
            if !hint.counts_toward_program || !completed_by_proposed.contains(&set.id.as_str()) {
                continue;
            }
            let entry = summary
                .slots
                .entry(hint.slot_key.clone())
                .or_insert_with(|| SchplannerWindowSlotSummary {
                    completed_sets: 0,
                    last_trained_at: 0,
                });
            entry.last_trained_at = entry.last_trained_at.max(session_at);
        }
    }

    summary
}

pub fn summarize_proposed_slot_targets(
    groups: &[ProposedExerciseGroup],
) -> HashMap<String, ProposedSlotTarget> {
    let mut targets = HashMap::new();
    for group in groups {
        for config in &group.exercise_configs {
            for set in config.working_sets.iter().filter(|set| {
                set.progression_hint
                    .as_ref()
                    .map(|hint| hint.counts_toward_program)
                    .unwrap_or(false)
            }) {
                let Some(hint) = set.progression_hint.as_ref() else {
                    continue;
                };
                let entry =
                    targets
                        .entry(hint.slot_key.clone())
                        .or_insert_with(|| ProposedSlotTarget {
                            slot_key: hint.slot_key.clone(),
                            exercise: Exercise::try_from(config.exercise)
                                .unwrap_or(Exercise::Unspecified),
                            tier: hint.tier.clone(),
                            set_count: 0,
                        });
                entry.set_count += 1;
            }
        }
    }
    targets
}

#[derive(Clone, Debug)]
struct CompletedWorkingSetSample {
    workout_id: String,
    completed_at: i64,
    duration_secs: Option<i64>,
    rest_secs: Option<i64>,
    actual_reps: i32,
    target_reps: i32,
    actual_weight: f32,
    hit_target: bool,
    is_amrap: bool,
}

#[derive(Default)]
struct TimingStatsAccumulator {
    values: Vec<i64>,
}

impl TimingStatsAccumulator {
    fn push(&mut self, value: Option<i64>) {
        if let Some(value) = value.filter(|value| *value >= 0) {
            self.values.push(value);
        }
    }

    fn build_from_last(&self, last_value: Option<i64>) -> SchplannerTimingStats {
        let sample_count = self.values.len();
        if sample_count == 0 {
            return SchplannerTimingStats::default();
        }
        let sum = self.values.iter().map(|value| *value as f64).sum::<f64>();
        let mean = sum / sample_count as f64;
        let variance = self
            .values
            .iter()
            .map(|value| {
                let delta = *value as f64 - mean;
                delta * delta
            })
            .sum::<f64>()
            / sample_count as f64;
        let min_secs = *self.values.iter().min().unwrap_or(&0);
        let fallback_max = *self.values.iter().max().unwrap_or(&0);
        SchplannerTimingStats {
            sample_count,
            mean_secs: mean as f32,
            stddev_secs: variance.sqrt() as f32,
            min_secs,
            max_secs: last_value.unwrap_or(fallback_max),
        }
    }
}

fn build_recent_exercise_insight(
    exercise: Exercise,
    samples: &[CompletedWorkingSetSample],
) -> SchplannerRecentExerciseInsights {
    let mut duration_stats = TimingStatsAccumulator::default();
    let mut rest_stats = TimingStatsAccumulator::default();
    let mut sessions = std::collections::HashSet::new();
    for sample in samples {
        duration_stats.push(sample.duration_secs);
        rest_stats.push(sample.rest_secs);
        sessions.insert(sample.workout_id.as_str());
    }
    let last = samples.last().expect("samples should be non-empty");
    SchplannerRecentExerciseInsights {
        exercise,
        last_completed_at: last.completed_at,
        last_workout_id: last.workout_id.clone(),
        recent_completed_sets: samples.len(),
        recent_sessions: sessions.len(),
        last_actual_reps: last.actual_reps,
        last_target_reps: last.target_reps,
        last_weight: last.actual_weight,
        last_hit_target: last.hit_target,
        last_was_amrap: last.is_amrap,
        set_durations: duration_stats.build_from_last(last.duration_secs),
        rests: rest_stats.build_from_last(last.rest_secs),
    }
}

fn build_recent_slot_insight(
    slot_key: &str,
    exercise: Exercise,
    samples: &[CompletedWorkingSetSample],
) -> SchplannerRecentSlotInsights {
    let mut duration_stats = TimingStatsAccumulator::default();
    let mut rest_stats = TimingStatsAccumulator::default();
    let mut sessions = std::collections::HashSet::new();
    for sample in samples {
        duration_stats.push(sample.duration_secs);
        rest_stats.push(sample.rest_secs);
        sessions.insert(sample.workout_id.as_str());
    }
    let last = samples.last().expect("samples should be non-empty");
    SchplannerRecentSlotInsights {
        slot_key: slot_key.to_string(),
        exercise,
        last_completed_at: last.completed_at,
        recent_completed_sets: samples.len(),
        recent_sessions: sessions.len(),
        last_actual_reps: last.actual_reps,
        last_target_reps: last.target_reps,
        last_weight: last.actual_weight,
        last_hit_target: last.hit_target,
        last_was_amrap: last.is_amrap,
        set_durations: duration_stats.build_from_last(last.duration_secs),
        rests: rest_stats.build_from_last(last.rest_secs),
    }
}

pub fn summarize_recent_insights(history: &[SchplannerWorkoutRecord]) -> SchplannerInsights {
    let mut history_sorted = history.to_vec();
    history_sorted.sort_by(|a, b| {
        a.workout
            .start_time
            .cmp(&b.workout.start_time)
            .then_with(|| a.workout.id.cmp(&b.workout.id))
    });

    let mut exercise_samples = HashMap::<Exercise, Vec<CompletedWorkingSetSample>>::new();
    let mut slot_samples = HashMap::<String, (Exercise, Vec<CompletedWorkingSetSample>)>::new();

    for workout in &history_sorted {
        let proposed_by_id = workout
            .proposed_sets
            .iter()
            .map(|set| (set.id.as_str(), set))
            .collect::<HashMap<_, _>>();
        let mut completed = workout
            .completed_sets
            .iter()
            .filter(|set| set.ended_at > 0)
            .collect::<Vec<_>>();
        completed.sort_by_key(|set| set.ended_at);

        for completed_set in completed {
            let Some(proposed_set) = proposed_by_id.get(completed_set.proposed_set_id.as_str())
            else {
                continue;
            };
            if proposed_set.warmup || proposed_set.cancelled {
                continue;
            }
            let sample = CompletedWorkingSetSample {
                workout_id: workout.workout.id.clone(),
                completed_at: completed_set.ended_at,
                duration_secs: (completed_set.started_at > 0
                    && completed_set.ended_at >= completed_set.started_at)
                    .then_some(completed_set.ended_at - completed_set.started_at),
                rest_secs: (completed_set.rest_until > completed_set.ended_at)
                    .then_some(completed_set.rest_until - completed_set.ended_at),
                actual_reps: completed_set.actual_reps,
                target_reps: proposed_set.target_reps,
                actual_weight: completed_set.actual_weight,
                hit_target: completed_set.actual_reps >= proposed_set.target_reps,
                is_amrap: proposed_set.is_amrap,
            };
            exercise_samples
                .entry(proposed_set.exercise())
                .or_default()
                .push(sample.clone());
            if let Some(hint) = proposed_set.progression_hint.as_ref() {
                slot_samples
                    .entry(hint.slot_key.clone())
                    .or_insert_with(|| (proposed_set.exercise(), Vec::new()))
                    .1
                    .push(sample);
            }
        }
    }

    let exercise_insights = exercise_samples
        .into_iter()
        .map(|(exercise, samples)| {
            (
                exercise,
                build_recent_exercise_insight(exercise, samples.as_slice()),
            )
        })
        .collect();
    let slot_insights = slot_samples
        .into_iter()
        .map(|(slot_key, (exercise, samples))| {
            (
                slot_key.clone(),
                build_recent_slot_insight(&slot_key, exercise, samples.as_slice()),
            )
        })
        .collect();

    SchplannerInsights {
        exercise_insights,
        slot_insights,
    }
}

/// The program's intent for a single tracked slot in one session: identity
/// (`slot_key`/`exercise`/`tier`), how to judge it (`rule`/`amrap_success_threshold`/
/// `target_reps`), and how much was asked for (`set_count`).
///
/// This is deliberately decoupled from the individual proposed/completed sets, so
/// progression no longer depends on per-set hints surviving the round-trip through
/// an editable workout. Reconciliation matches completed work to slots by exercise.
#[derive(Clone, Debug)]
pub struct PrescribedSlot {
    pub exercise: Exercise,
    pub tier: String,
    pub rule: ProgressionRule,
    pub amrap_success_threshold: i32,
    pub set_count: usize,
    pub target_reps: i32,
}

/// Authoritative source (production): derive the prescribed slots from a freshly
/// generated proposal. Independent of whatever the user did to their workout plan.
pub fn prescribed_slots_from_groups(
    groups: &[ProposedExerciseGroup],
) -> HashMap<String, PrescribedSlot> {
    let mut slots: HashMap<String, PrescribedSlot> = HashMap::new();
    for group in groups {
        for config in &group.exercise_configs {
            for ws in &config.working_sets {
                let Some(hint) = ws.progression_hint.as_ref() else {
                    continue;
                };
                if !hint.counts_toward_program {
                    continue;
                }
                let entry = slots.entry(hint.slot_key.clone()).or_insert_with(|| {
                    PrescribedSlot {
                        exercise: Exercise::try_from(config.exercise)
                            .unwrap_or(Exercise::Unspecified),
                        tier: hint.tier.clone(),
                        rule: ProgressionRule::try_from(hint.rule)
                            .unwrap_or(ProgressionRule::None),
                        amrap_success_threshold: hint.amrap_success_threshold,
                        set_count: 0,
                        target_reps: ws.target_reps,
                    }
                });
                entry.set_count += 1;
            }
        }
    }
    slots
}

/// Test-only source: derive prescribed slots from a workout's own proposed-set
/// hints (the scheduler stamped them at proposal time). Used by the replay path
/// `derive_state`, which only exists in tests.
#[cfg(test)]
pub fn prescribed_slots_from_workout(
    workout: &SchplannerWorkoutRecord,
) -> HashMap<String, PrescribedSlot> {
    let mut slots: HashMap<String, PrescribedSlot> = HashMap::new();
    for set in workout
        .proposed_sets
        .iter()
        .filter(|set| !set.warmup && !set.cancelled)
    {
        let Some(hint) = set.progression_hint.as_ref() else {
            continue;
        };
        if !hint.counts_toward_program {
            continue;
        }
        let entry = slots
            .entry(hint.slot_key.clone())
            .or_insert_with(|| PrescribedSlot {
                exercise: set.exercise(),
                tier: hint.tier.clone(),
                rule: ProgressionRule::try_from(hint.rule).unwrap_or(ProgressionRule::None),
                amrap_success_threshold: hint.amrap_success_threshold,
                set_count: 0,
                target_reps: set.target_reps,
            });
        entry.set_count += 1;
    }
    slots
}

/// Reconcile what the user actually did against the program's prescription.
///
/// Completed working sets are matched to a prescribed slot **by exercise** (so a
/// deleted-and-re-added group, an edited weight, or a stripped hint all still
/// resolve to the right slot). Exercises that aren't part of the prescription this
/// session (accessories, optional lifts the user didn't intend as program work) are
/// ignored — they neither progress nor stall. Judging uses the prescribed rep
/// target and set count, not whatever the editable sets happen to say.
pub fn summarize_slot_outcomes(
    workout: &SchplannerWorkoutRecord,
    prescribed: &HashMap<String, PrescribedSlot>,
) -> HashMap<String, SchplannerSlotOutcome> {
    let proposed_by_id = workout
        .proposed_sets
        .iter()
        .map(|set| (set.id.as_str(), set))
        .collect::<HashMap<_, _>>();

    // Group completed working sets by slot (keyed by exercise).
    let mut by_slot: HashMap<String, Vec<(&ProposedSet, &CompletedSet)>> = HashMap::new();
    for completed in workout.completed_sets.iter().filter(|set| set.ended_at > 0) {
        let Some(proposed) = proposed_by_id.get(completed.proposed_set_id.as_str()) else {
            continue;
        };
        if proposed.warmup || proposed.cancelled {
            continue;
        }
        let slot_key = progression_slot_key(proposed.exercise());
        if !prescribed.contains_key(&slot_key) {
            continue;
        }
        by_slot
            .entry(slot_key)
            .or_default()
            .push((proposed, completed));
    }

    let mut outcomes = HashMap::new();
    for (slot_key, mut sets) in by_slot {
        sets.sort_by_key(|(proposed, _)| proposed.workout_order);
        let slot = &prescribed[&slot_key];
        let target_reps = slot.target_reps;

        let completed_sets = sets.len();
        let successful_sets = sets
            .iter()
            .filter(|(_, c)| c.actual_reps >= target_reps)
            .count();
        // Progression follows the *last set you actually did* — the most recently completed
        // set by wall-clock (ended_at), not its position in the list. This is robust to a
        // mid-workout weight edit reordering the sets: whatever you finished last wins.
        let last_completed_actual_weight = sets
            .iter()
            .max_by_key(|(_, c)| c.ended_at)
            .map(|(_, c)| c.actual_weight);
        let last_successful_actual_weight = sets
            .iter()
            .filter(|(_, c)| c.actual_reps >= target_reps)
            .max_by_key(|(_, c)| c.ended_at)
            .map(|(_, c)| c.actual_weight);
        let top_set_actual_reps = sets.last().map(|(_, c)| c.actual_reps).unwrap_or(0);

        outcomes.insert(
            slot_key.clone(),
            SchplannerSlotOutcome {
                slot_key,
                exercise: slot.exercise,
                tier: slot.tier.clone(),
                rule: slot.rule,
                planned_sets: slot.set_count,
                completed_sets,
                successful_sets,
                last_completed_actual_weight,
                last_successful_actual_weight,
                top_set_target_reps: target_reps,
                top_set_actual_reps,
                amrap_success_threshold: slot.amrap_success_threshold,
                workout_ended: workout.workout.end_time > 0,
            },
        );
    }

    outcomes
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::program_state::{get_f32_or, get_int_or, get_str_or};
    use crate::regimes::{get_regime, progression_hint_for_set};
    use schlift::workout::v1::{ExerciseTypeConfig, RegimeType, WorkingSetSpec};

    fn linear_workout(success: bool) -> SchplannerWorkoutRecord {
        let workout = Workout {
            id: "w1".to_string(),
            name: "5x5".to_string(),
            start_time: 100,
            end_time: 200,
            session_id: String::new(),
        };
        let group = ExerciseGroup {
            id: "g1".to_string(),
            workout_id: workout.id.clone(),
            name: "Squat".to_string(),
            sets: 5,
            interleave_warmups: false,
            workout_order: 0,
            exercise_configs: vec![ExerciseTypeConfig {
                exercise: Exercise::Squat as i32,
                start_weight: 135.0,
                end_weight: 135.0,
                reps: 5,
                include_warmup: false,
                rest_config: None,
                last_set_amrap: false,
                working_sets: (0..5)
                    .map(|_| WorkingSetSpec {
                        target_weight: 135.0,
                        target_reps: 5,
                        is_amrap: false,
                        instruction: String::new(),
                        progression_hint: Some(progression_hint_for_set(
                            Exercise::Squat,
                            "MAIN",
                            ProgressionRule::AllSetsMatchTarget,
                            0,
                            true,
                        )),
                    })
                    .collect(),
            }],
            rest_config: None,
            instruction: String::new(),
            prescribed_by_regime: true,
        };
        let proposed_sets = (0..5)
            .map(|idx| ProposedSet {
                id: format!("p{idx}"),
                workout_id: workout.id.clone(),
                workout_order: idx,
                exercise: Exercise::Squat as i32,
                target_reps: 5,
                target_weight: 135.0,
                warmup: false,
                exercise_group_id: group.id.clone(),
                rest_after_success: 180,
                rest_after_failure: 300,
                cancelled: false,
                is_amrap: false,
                instruction: String::new(),
                progression_hint: Some(progression_hint_for_set(
                    Exercise::Squat,
                    "MAIN",
                    ProgressionRule::AllSetsMatchTarget,
                    0,
                    true,
                )),
            })
            .collect::<Vec<_>>();
        let completed_sets = proposed_sets
            .iter()
            .map(|set| CompletedSet {
                id: format!("c{}", set.id),
                workout_id: workout.id.clone(),
                proposed_set_id: set.id.clone(),
                actual_reps: if success { 5 } else { 4 },
                actual_weight: 135.0,
                started_at: 120,
                ended_at: 150,
                rest_until: 0,
            })
            .collect::<Vec<_>>();

        SchplannerWorkoutRecord {
            workout,
            exercise_groups: vec![group],
            proposed_sets,
            completed_sets,
        }
    }

    #[test]
    fn summarize_recent_insights_tracks_last_set_and_timing() {
        let mut workout = linear_workout(true);
        for (idx, set) in workout.completed_sets.iter_mut().enumerate() {
            set.started_at = 100 + idx as i64 * 70;
            set.ended_at = set.started_at + 20 + idx as i64 * 5;
            set.rest_until = set.ended_at + 90 + idx as i64 * 10;
        }
        let insights = summarize_recent_insights(&[workout]);
        let squat = insights.for_exercise(Exercise::Squat).unwrap();
        assert_eq!(squat.last_actual_reps, 5);
        assert_eq!(squat.last_target_reps, 5);
        assert!(squat.last_hit_target);
        assert_eq!(squat.set_durations.sample_count, 5);
        assert_eq!(squat.set_durations.max_secs, 40);
        assert_eq!(squat.rests.sample_count, 5);
        assert_eq!(squat.rests.max_secs, 130);
    }

    /// The prescription half of a fabricated workout; what the lifter did comes
    /// in via `actual_reps` / `ended` so tests read as "prescription, outcome".
    struct SingleGroupSpec<'a> {
        exercise: Exercise,
        tier: &'a str,
        rule: ProgressionRule,
        weight: f32,
        reps: i32,
        set_count: i32,
        amrap_threshold: i32,
    }

    fn single_group_workout(
        workout_id: &str,
        spec: SingleGroupSpec<'_>,
        actual_reps: Vec<i32>,
        ended: bool,
    ) -> SchplannerWorkoutRecord {
        let SingleGroupSpec {
            exercise,
            tier,
            rule,
            weight,
            reps,
            set_count,
            amrap_threshold,
        } = spec;
        let workout = Workout {
            id: workout_id.to_string(),
            name: workout_id.to_string(),
            start_time: 100,
            end_time: if ended { 200 } else { 0 },
            session_id: String::new(),
        };
        let group = ExerciseGroup {
            id: format!("{workout_id}-g1"),
            workout_id: workout.id.clone(),
            name: exercise.as_str_name().to_string(),
            sets: set_count,
            interleave_warmups: false,
            workout_order: 0,
            exercise_configs: vec![],
            rest_config: None,
            instruction: String::new(),
            prescribed_by_regime: true,
        };
        let proposed_sets = (0..set_count)
            .map(|idx| ProposedSet {
                id: format!("{workout_id}-p{idx}"),
                workout_id: workout.id.clone(),
                workout_order: idx,
                exercise: exercise as i32,
                target_reps: reps,
                target_weight: weight,
                warmup: false,
                exercise_group_id: group.id.clone(),
                rest_after_success: 180,
                rest_after_failure: 300,
                cancelled: false,
                is_amrap: idx == set_count - 1 && rule == ProgressionRule::TopSetAmrap,
                instruction: String::new(),
                progression_hint: Some(progression_hint_for_set(
                    exercise,
                    tier,
                    rule,
                    amrap_threshold,
                    true,
                )),
            })
            .collect::<Vec<_>>();
        let completed_sets = actual_reps
            .into_iter()
            .enumerate()
            .map(|(idx, actual)| CompletedSet {
                id: format!("{workout_id}-c{idx}"),
                workout_id: workout.id.clone(),
                proposed_set_id: proposed_sets[idx].id.clone(),
                actual_reps: actual,
                actual_weight: weight,
                started_at: 120 + idx as i64,
                ended_at: if ended { 150 + idx as i64 } else { 0 },
                rest_until: 0,
            })
            .collect::<Vec<_>>();
        SchplannerWorkoutRecord {
            workout,
            exercise_groups: vec![group],
            proposed_sets,
            completed_sets,
        }
    }

    #[test]
    fn linear_replay_advances_variant_and_weight_after_success() {
        let regime = get_regime(RegimeType::Linear5x5);
        let base = regime.default_state();
        let derived = derive_state(regime.as_ref(), &base, &[linear_workout(true)]);

        assert_eq!(
            get_str_or(&derived.effective_state, "next_workout_variant", "A"),
            "B"
        );
        assert_eq!(
            get_f32_or(&derived.effective_state, "squat_weight", 0.0),
            140.0
        );
        assert_eq!(
            get_int_or(&derived.effective_state, "squat_stall_count", -1),
            0
        );
    }

    #[test]
    fn linear_replay_uses_actual_lifted_weight_for_progression() {
        let regime = get_regime(RegimeType::Linear5x5);
        let mut base = regime.default_state();
        crate::program_state::set_f32(&mut base, "squat_weight", 45.0);
        let mut workout = linear_workout(true);
        for set in &mut workout.completed_sets {
            set.actual_weight = 185.0;
        }

        let derived = derive_state(regime.as_ref(), &base, &[workout]);

        assert_eq!(
            get_f32_or(&derived.effective_state, "squat_weight", 0.0),
            190.0
        );
    }

    #[test]
    fn linear_progression_uses_last_completed_weight_by_time() {
        // The set finished *last by wall-clock* (ended_at) drives progression, even if a
        // heavier set was done earlier and even if list order disagrees. Here the most
        // recently completed set is 175 (-> 180); an earlier 185 set must NOT win.
        let regime = get_regime(RegimeType::Linear5x5);
        let mut base = regime.default_state();
        crate::program_state::set_f32(&mut base, "squat_weight", 175.0);
        let mut workout = linear_workout(true);
        // (weight, ended_at) per set; linear_workout(true) records 5 reps so all succeed.
        let plan = [
            (175.0, 100),
            (175.0, 200), // most recently completed -> this is the one that should win
            (175.0, 120),
            (175.0, 130),
            (185.0, 110), // heavier, but completed earlier and last in list order
        ];
        for (set, (w, ended)) in workout.completed_sets.iter_mut().zip(plan) {
            set.actual_weight = w;
            set.ended_at = ended;
        }

        let derived = derive_state(regime.as_ref(), &base, &[workout]);

        assert_eq!(
            get_f32_or(&derived.effective_state, "squat_weight", 0.0),
            180.0,
            "should progress from the last-completed set (175 -> 180), not the heavier earlier 185"
        );
    }

    #[test]
    fn edited_workout_without_hints_still_progresses_by_exercise() {
        // Reproduces the original bug: the user edited the squat group mid-workout
        // (bumping the weight), which strips progression hints off the proposed sets.
        // Progression must still happen — driven by the program-state prescription and
        // matched to completed work by exercise, not by surviving per-set hints.
        let regime = get_regime(RegimeType::Linear5x5);
        let mut base = regime.default_state();
        crate::program_state::set_f32(&mut base, "squat_weight", 175.0);

        // Prescription is derived from the proposal generated off program state.
        let insights = summarize_recent_insights(&[]);
        let proposal = regime.propose_from_state(&base, 0, 1, &insights);
        let prescribed = prescribed_slots_from_groups(&proposal.proposed_groups);
        let squat_slot = progression_slot_key(Exercise::Squat);
        assert!(prescribed.contains_key(&squat_slot));

        // A completed workout whose proposed sets carry NO progression hints (as if the
        // group was edited / regenerated), squat done for 5×5 at a heavier 185.
        let workout = Workout {
            id: "edited".to_string(),
            name: "Workout A".to_string(),
            start_time: 100,
            end_time: 200,
            session_id: String::new(),
        };
        let group = ExerciseGroup {
            id: "g1".to_string(),
            workout_id: workout.id.clone(),
            name: "Squat".to_string(),
            sets: 5,
            interleave_warmups: false,
            workout_order: 0,
            exercise_configs: vec![],
            rest_config: None,
            instruction: String::new(),
            prescribed_by_regime: false,
        };
        let proposed_sets = (0..5)
            .map(|idx| ProposedSet {
                id: format!("p{idx}"),
                workout_id: workout.id.clone(),
                workout_order: idx,
                exercise: Exercise::Squat as i32,
                target_reps: 5,
                target_weight: 185.0,
                warmup: false,
                exercise_group_id: group.id.clone(),
                rest_after_success: 180,
                rest_after_failure: 300,
                cancelled: false,
                is_amrap: false,
                instruction: String::new(),
                progression_hint: None, // stripped by editing the group
            })
            .collect::<Vec<_>>();
        let completed_sets = proposed_sets
            .iter()
            .map(|set| CompletedSet {
                id: format!("c{}", set.id),
                workout_id: workout.id.clone(),
                proposed_set_id: set.id.clone(),
                actual_reps: 5,
                actual_weight: 185.0,
                started_at: 120,
                ended_at: 150,
                rest_until: 0,
            })
            .collect::<Vec<_>>();
        let record = SchplannerWorkoutRecord {
            workout,
            exercise_groups: vec![group],
            proposed_sets,
            completed_sets,
        };

        let slot_outcomes = summarize_slot_outcomes(&record, &prescribed);
        assert!(
            slot_outcomes.contains_key(&squat_slot),
            "squat must reconcile by exercise even without hints"
        );

        let mut state = base.clone();
        regime.transition_state_on_workout_completed(&mut state, &record, &slot_outcomes);
        assert_eq!(
            get_f32_or(&state, "squat_weight", 0.0),
            190.0,
            "next squat weight should increment from the 185 actually lifted"
        );
    }

    #[test]
    fn linear_replay_tracks_stall_after_failure() {
        let regime = get_regime(RegimeType::Linear5x5);
        let base = regime.default_state();
        let derived = derive_state(regime.as_ref(), &base, &[linear_workout(false)]);

        assert_eq!(
            get_f32_or(&derived.effective_state, "squat_weight", 0.0),
            135.0
        );
        assert_eq!(
            get_int_or(&derived.effective_state, "squat_stall_count", -1),
            1
        );
    }

    #[test]
    fn gzclp_replay_moves_t1_stage_after_failure() {
        let regime = get_regime(RegimeType::Gzclp);
        let base = regime.default_state();
        let workout = single_group_workout(
            "g-t1-fail",
            SingleGroupSpec {
                exercise: Exercise::Squat,
                tier: "T1",
                rule: ProgressionRule::AllSetsMatchTarget,
                weight: 135.0,
                reps: 3,
                set_count: 5,
                amrap_threshold: 0,
            },
            vec![3, 3, 3, 3, 2],
            true,
        );
        let derived = derive_state(regime.as_ref(), &base, &[workout]);
        assert_eq!(
            get_str_or(&derived.effective_state, "squat_t1_stage", ""),
            "stage_2_6x2"
        );
        assert_eq!(
            get_int_or(&derived.effective_state, "next_session_index", -1),
            1
        );
    }

    #[test]
    fn gzclp_replay_adds_t3_weight_after_25_rep_amrap() {
        let regime = get_regime(RegimeType::Gzclp);
        let base = regime.default_state();
        let workout = single_group_workout(
            "g-t3-pass",
            SingleGroupSpec {
                exercise: Exercise::HipThrust,
                tier: "T3",
                rule: ProgressionRule::TopSetAmrap,
                weight: 45.0,
                reps: 15,
                set_count: 3,
                amrap_threshold: 25,
            },
            vec![15, 15, 25],
            true,
        );
        let derived = derive_state(regime.as_ref(), &base, &[workout]);
        assert_eq!(
            get_f32_or(&derived.effective_state, "hip_thrust_t3_weight", 0.0),
            50.0
        );
    }

    #[test]
    fn wendler_replay_bumps_training_maxes_after_completed_cycle() {
        let regime = get_regime(RegimeType::Wendler531);
        let mut base = regime.default_state();
        crate::program_state::set_str(&mut base, "schedule_variant", "four_day");
        crate::program_state::set_int(&mut base, "cycle", 1);
        crate::program_state::set_int(&mut base, "week", 4);
        crate::program_state::set_int(&mut base, "session_in_week", 3);
        crate::program_state::set_f32(&mut base, "squat_tm", 200.0);
        crate::program_state::set_f32(&mut base, "bench_press_tm", 150.0);
        crate::program_state::set_f32(&mut base, "deadlift_tm", 250.0);
        crate::program_state::set_f32(&mut base, "overhead_press_tm", 100.0);

        let workout = single_group_workout(
            "w-cycle-end",
            SingleGroupSpec {
                exercise: Exercise::OverheadPress,
                tier: "MAIN",
                rule: ProgressionRule::None,
                weight: 60.0,
                reps: 5,
                set_count: 3,
                amrap_threshold: 0,
            },
            vec![5, 5, 5],
            true,
        );
        let derived = derive_state(regime.as_ref(), &base, &[workout]);
        assert_eq!(get_int_or(&derived.effective_state, "cycle", 0), 2);
        assert_eq!(get_int_or(&derived.effective_state, "week", 0), 1);
        assert_eq!(
            get_int_or(&derived.effective_state, "session_in_week", -1),
            0
        );
        assert_eq!(get_f32_or(&derived.effective_state, "squat_tm", 0.0), 210.0);
        assert_eq!(
            get_f32_or(&derived.effective_state, "deadlift_tm", 0.0),
            260.0
        );
        assert_eq!(
            get_f32_or(&derived.effective_state, "bench_press_tm", 0.0),
            155.0
        );
        assert_eq!(
            get_f32_or(&derived.effective_state, "overhead_press_tm", 0.0),
            105.0
        );
    }
}
