//! What happened to an account: the facts the core decided when it recorded
//! them, in the order the server gave them. This is what is stored, on the
//! phone and the server, and what sync carries — never the requests that led
//! to it, which are free to change with the app.
//!
//! An event is JSON: `{"seq":12,"id":"…","at":1793680431,"SetCompleted":{…}}`.
//! Fields are only ever added (each payload takes its defaults for one an
//! older event lacks); one that is renamed or removed would stop the stored
//! events reading, which `tests/stored_events.rs` guards. Changing what an
//! existing fact means changes every stored account.

use crate::pb::{
    ExerciseDecision, ExerciseWeight, ImportedWorkout, LibraryTemplate, UserSetting,
    WorkoutHeartRatePoint, WorkoutTemplate,
};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Event {
    /// Its place in the account's history, given by the server; 0 while it
    /// is still only on the device that recorded it.
    #[serde(default)]
    pub seq: i64,
    /// Unique. Ids of what the event creates derive from it.
    pub id: String,
    /// Unix seconds, on the recording device's clock.
    pub at: i64,
    #[serde(flatten)]
    pub fact: Fact,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub enum Fact {
    WorkoutStarted(WorkoutStarted),
    SetStarted(SetStarted),
    SetCompleted(SetCompleted),
    SetEdited(SetEdited),
    SetUndone(SetUndone),
    RungAnswered(RungAnswered),
    WarmupsSkipped(WarmupsSkipped),
    ExercisesAdded(ExercisesAdded),
    ExerciseAdjusted(ExerciseAdjusted),
    ExerciseRemoved(ExerciseRemoved),
    ExercisesReordered(ExercisesReordered),
    SessionSet(SessionSet),
    WorkoutEnded(WorkoutEnded),
    HeartRateRecorded(HeartRateRecorded),
    TemplateSaved(TemplateSaved),
    TemplateDeleted(TemplateDeleted),
    TemplatesReordered(TemplatesReordered),
    LibraryTemplatesAdded(LibraryTemplatesAdded),
    Onboarded(Onboarded),
    SettingUpdated(SettingUpdated),
    HistoryImported(HistoryImported),
    OverrideSet(OverrideSet),
}

impl Fact {
    /// The workout a fact about one names.
    pub fn workout_id(&self) -> Option<&str> {
        Some(match self {
            Fact::SetStarted(f) => &f.workout_id,
            Fact::SetCompleted(f) => &f.workout_id,
            Fact::SetEdited(f) => &f.workout_id,
            Fact::SetUndone(f) => &f.workout_id,
            Fact::RungAnswered(f) => &f.workout_id,
            Fact::WarmupsSkipped(f) => &f.workout_id,
            Fact::ExercisesAdded(f) => &f.workout_id,
            Fact::ExerciseAdjusted(f) => &f.workout_id,
            Fact::ExerciseRemoved(f) => &f.workout_id,
            Fact::ExercisesReordered(f) => &f.workout_id,
            Fact::SessionSet(f) => &f.workout_id,
            Fact::WorkoutEnded(f) => &f.workout_id,
            Fact::HeartRateRecorded(f) => &f.workout_id,
            _ => return None,
        })
    }
}

// Exercises are `crate::pb::Exercise` values and units `crate::pb::WeightUnit`
// values, as numbers. Times are unix seconds unless named otherwise.

/// A workout began, its id the event's: each lift's decision, planned when
/// it started and in its budget. Everything it needs to fold is in its own
/// events — its name and unit too — so a session partner's phone folds it
/// from those alone.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct WorkoutStarted {
    /// The template's name then, or "Workout" without one.
    pub name: String,
    /// The unit it was planned in (`crate::pb::WeightUnit`).
    pub unit: i32,
    pub started_at: i64,
    pub template_id: String,
    pub exercises: Vec<i32>,
    pub budget_minutes: i32,
    pub decisions: Vec<ExerciseDecision>,
}

/// A set was begun: the lift is under way.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct SetStarted {
    pub workout_id: String,
    pub proposed_set_id: String,
    pub started_at: i64,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct SetCompleted {
    pub workout_id: String,
    pub proposed_set_id: String,
    pub actual_reps: i32,
    pub actual_weight: f32,
    pub completed_at: i64,
}

/// A done set's reps or weight corrected.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct SetEdited {
    pub workout_id: String,
    pub completed_set_id: String,
    pub actual_reps: i32,
    pub actual_weight: f32,
}

/// A done set taken back.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct SetUndone {
    pub workout_id: String,
    pub completed_set_id: String,
}

/// The ramp's question after a full rung: how many more reps were left
/// (`crate::pb::RepsLeft`), or a jump in pounds to take instead.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct RungAnswered {
    pub workout_id: String,
    pub proposed_set_id: String,
    pub reps_left: i32,
    pub jump_lb: f32,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct WarmupsSkipped {
    pub workout_id: String,
    pub exercise: i32,
}

/// Lifts added to a workout under way, each planned when added.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct ExercisesAdded {
    pub workout_id: String,
    pub exercises: Vec<i32>,
    pub decisions: Vec<ExerciseDecision>,
}

/// A lift's weight (pounds) and reps changed by hand mid-workout.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct ExerciseAdjusted {
    pub workout_id: String,
    pub exercise: i32,
    pub working_weight: f32,
    pub target_reps: i32,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct ExerciseRemoved {
    pub workout_id: String,
    pub exercise: i32,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct ExercisesReordered {
    pub workout_id: String,
    pub exercises: Vec<i32>,
}

/// The multiplayer session a workout was trained in.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct SessionSet {
    pub workout_id: String,
    pub session_id: String,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct WorkoutEnded {
    pub workout_id: String,
    pub ended_at: i64,
}

/// A finished workout's heart rate, whole: every reading, in time order,
/// replacing any recorded before. Compact, as it is most of what an account
/// holds: the first reading's time (unix ms), the gap to each one after it
/// (ms), and every reading's bpm, whole.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct HeartRateRecorded {
    pub workout_id: String,
    pub start_ms: i64,
    pub gaps_ms: Vec<u32>,
    pub bpm: Vec<u16>,
}

impl HeartRateRecorded {
    /// The readings as recorded: sorted, one per time, bpm rounded.
    pub fn new(workout_id: &str, samples: &[WorkoutHeartRatePoint]) -> Self {
        let mut samples = samples.to_vec();
        samples.sort_by_key(|s| s.sampled_at);
        samples.dedup_by_key(|s| s.sampled_at);
        let start_ms = samples.first().map_or(0, |s| s.sampled_at);
        Self {
            workout_id: workout_id.to_string(),
            start_ms,
            gaps_ms: samples
                .windows(2)
                .map(|w| u32::try_from(w[1].sampled_at - w[0].sampled_at).unwrap_or(u32::MAX))
                .collect(),
            bpm: samples
                .iter()
                .map(|s| s.bpm.round().clamp(0.0, f32::from(u16::MAX)) as u16)
                .collect(),
        }
    }

    /// The readings again, or None when the gaps don't match the bpms.
    pub fn samples(&self) -> Option<Vec<WorkoutHeartRatePoint>> {
        if self.gaps_ms.len() + 1 != self.bpm.len() && !self.bpm.is_empty() {
            return None;
        }
        let mut at = self.start_ms;
        let gaps = std::iter::once(0).chain(self.gaps_ms.iter().copied());
        Some(
            gaps.zip(&self.bpm)
                .map(|(gap, &bpm)| {
                    at += i64::from(gap);
                    WorkoutHeartRatePoint {
                        sampled_at: at,
                        bpm: f32::from(bpm),
                    }
                })
                .collect(),
        )
    }
}

/// A template made or changed; `unlink` makes a library one the user's own
/// even when nothing about it changed.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct TemplateSaved {
    pub template: WorkoutTemplate,
    pub unlink: bool,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct TemplateDeleted {
    pub template_id: String,
}

/// The templates in this order; with `rotation_count`, the first that many
/// are the rotation and the rest reserves.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct TemplatesReordered {
    pub template_ids: Vec<String>,
    pub rotation_count: Option<i32>,
}

/// Library templates copied into the user's list, as they were then.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct LibraryTemplatesAdded {
    pub entries: Vec<LibraryTemplate>,
    pub in_rotation: bool,
}

/// Sign-up's choices: the unit, the library templates that are the
/// rotation (as they were then), and a starting weight per lift.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct Onboarded {
    pub unit: i32,
    pub library_entries: Vec<LibraryTemplate>,
    pub strength: Option<f32>,
    pub starting_weights: Vec<ExerciseWeight>,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct SettingUpdated {
    pub setting: UserSetting,
}

/// Finished workouts brought in from elsewhere, whole.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct HistoryImported {
    pub workouts: Vec<ImportedWorkout>,
    pub starting_weights: Vec<ExerciseWeight>,
}

/// The user's own weight (pounds) and reps for a lift, and maybe its sets,
/// replacing any before; reps of 0 removes it.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct OverrideSet {
    pub exercise: i32,
    pub weight: f32,
    pub reps: i32,
    pub sets: Option<i32>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn heart_rate_keeps_every_reading_in_order() {
        let point = |sampled_at, bpm| WorkoutHeartRatePoint { sampled_at, bpm };
        let recorded = HeartRateRecorded::new(
            "w",
            &[
                point(3_000, 121.4),
                point(1_000, 98.0),
                point(3_000, 121.4),
                point(1_500, 175.6),
            ],
        );
        assert_eq!(recorded.start_ms, 1_000);
        assert_eq!(recorded.gaps_ms, vec![500, 1_500]);
        assert_eq!(recorded.bpm, vec![98, 176, 121]);
        assert_eq!(
            recorded.samples().unwrap(),
            vec![point(1_000, 98.0), point(1_500, 176.0), point(3_000, 121.0)]
        );
        let broken = HeartRateRecorded {
            gaps_ms: vec![1],
            ..recorded
        };
        assert_eq!(broken.samples(), None);
    }
}
