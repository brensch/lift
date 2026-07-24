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
