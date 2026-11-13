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
//!
//! A kind of fact this version doesn't know (one a newer app recorded) is
//! kept as it came, `Fact::Unknown`, and folds as nothing: an older phone
//! carries on syncing, and folds it once it is updated.

use crate::pb::{
    ExerciseDecision, ExerciseWeight, ImportedWorkout, LibraryTemplate, UserSetting,
    WorkoutHeartRatePoint, WorkoutTemplate,
};
use serde::de::Error as _;
use serde::{Deserialize, Deserializer, Serialize, Serializer};
use serde_json::{Map, Value};

#[derive(Clone, Debug, PartialEq)]
pub struct Event {
    /// Its place in the account's history, given by the server; 0 while it
    /// is still only on the device that recorded it.
    pub seq: i64,
    /// Unique. Ids of what the event creates derive from it.
    pub id: String,
    /// Unix seconds, on the recording device's clock.
    pub at: i64,
    pub fact: Fact,
}

impl Serialize for Event {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        // Written straight from the fact (through a value, an f32 would
        // widen); an unknown one as it came.
        #[derive(Serialize)]
        struct Written<'a, F: Serialize> {
            seq: i64,
            id: &'a str,
            at: i64,
            #[serde(flatten)]
            fact: F,
        }
        match &self.fact {
            Fact::Unknown(unknown) => {
                let mut fact = Map::new();
                fact.insert(unknown.name.clone(), unknown.body.clone());
                Written {
                    seq: self.seq,
                    id: &self.id,
                    at: self.at,
                    fact,
                }
                .serialize(serializer)
            }
            fact => Written {
                seq: self.seq,
                id: &self.id,
                at: self.at,
                fact,
            }
            .serialize(serializer),
        }
    }
}

impl<'de> Deserialize<'de> for Event {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        #[derive(Deserialize)]
        struct Raw {
            #[serde(default)]
            seq: i64,
            id: String,
            at: i64,
            #[serde(flatten)]
            fact: Map<String, Value>,
        }
        let raw = Raw::deserialize(deserializer)?;
        let mut entries = raw.fact.into_iter();
        let (Some((name, body)), None) = (entries.next(), entries.next()) else {
            return Err(D::Error::custom("an event holds one fact"));
        };
        let fact = if Fact::KINDS.contains(&name.as_str()) {
            let mut one = Map::new();
            one.insert(name, body);
            serde_json::from_value(Value::Object(one)).map_err(D::Error::custom)?
        } else {
            Fact::Unknown(UnknownFact { name, body })
        };
        Ok(Event {
            seq: raw.seq,
            id: raw.id,
            at: raw.at,
            fact,
        })
    }
}

impl Event {
    /// The workout the event is about: one it starts (the event's own id)
    /// or one its fact names.
    pub fn workout_id(&self) -> Option<&str> {
        match self.fact {
            Fact::WorkoutStarted(_) => Some(&self.id),
            _ => self.fact.workout_id(),
        }
    }

    /// Whether the event, stored, reads back. One holding a non-finite
    /// number (NaN, infinity, or a JSON number past f32's range, which
    /// reads as infinity) is written as `null` and never reads again, so
    /// every read of the account would fail: it must not be recorded or
    /// stored.
    pub fn reads_back(&self) -> bool {
        serde_json::to_string(self).is_ok_and(|json| serde_json::from_str::<Event>(&json).is_ok())
    }

    /// Whether the plans it holds are ones an app could have made, by a wide
    /// margin (a workout has each lift once; an override asks for at most 20
    /// sets; no history leads past a few thousand pounds). Folding costs grow
    /// with what a plan holds, and a pushed event is folded on the server and
    /// on every partner's phone, so the server takes no more than this.
    pub fn plans_are_sane(&self) -> bool {
        let sane = |decisions: &[ExerciseDecision]| {
            decisions.len() <= 100
                && decisions
                    .iter()
                    .all(|d| d.sets <= 100 && d.weight.abs() <= 100_000.0)
        };
        match &self.fact {
            Fact::WorkoutStarted(started) => sane(&started.decisions),
            Fact::ExercisesAdded(added) => sane(&added.decisions),
            _ => true,
        }
    }
}

/// A fact of a kind this version doesn't know, as it came.
#[derive(Clone, Debug, PartialEq)]
pub struct UnknownFact {
    pub name: String,
    pub body: Value,
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
    WorkoutDiscarded(WorkoutDiscarded),
    WorkoutEndMoved(WorkoutEndMoved),
    /// Of a kind this version doesn't know: kept, folded as nothing.
    #[serde(skip)]
    Unknown(UnknownFact),
}

impl Fact {
    /// Every kind this version knows, by name.
    pub const KINDS: &'static [&'static str] = &[
        "WorkoutStarted",
        "SetStarted",
        "SetCompleted",
        "SetEdited",
        "SetUndone",
        "RungAnswered",
        "WarmupsSkipped",
        "ExercisesAdded",
        "ExerciseAdjusted",
        "ExerciseRemoved",
        "ExercisesReordered",
        "SessionSet",
        "WorkoutEnded",
        "HeartRateRecorded",
        "TemplateSaved",
        "TemplateDeleted",
        "TemplatesReordered",
        "LibraryTemplatesAdded",
        "Onboarded",
        "SettingUpdated",
        "HistoryImported",
        "OverrideSet",
        "WorkoutDiscarded",
        "WorkoutEndMoved",
    ];

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
            Fact::WorkoutDiscarded(f) => &f.workout_id,
            Fact::WorkoutEndMoved(f) => &f.workout_id,
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
    /// The workout's motivational quote, as picked at the start.
    pub motivation: String,
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
    /// The one warmup skipped; empty for every undone warmup of the exercise.
    pub proposed_set_id: String,
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
    /// How many working sets the exercise has from here on; 0 leaves them.
    pub sets: i32,
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
                    at = at.saturating_add(i64::from(gap));
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

/// A workout thrown away, under way or finished: it is gone from the
/// account, as if it never happened. Its events stay in the history.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct WorkoutDiscarded {
    pub workout_id: String,
}

/// A finished workout's end moved: a correction, for one left running long
/// after its training. Its heart rate after the new end goes with it.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
#[serde(default)]
pub struct WorkoutEndMoved {
    pub workout_id: String,
    pub ended_at: i64,
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
    fn a_fact_from_a_newer_app_is_kept_and_folds_as_nothing() {
        let json = r#"{"seq":3,"id":"e3","at":5,"SomethingNew":{"workout_id":"w","more":[1,2]}}"#;
        let event: Event = serde_json::from_str(json).unwrap();
        assert!(matches!(&event.fact, Fact::Unknown(u) if u.name == "SomethingNew"));
        assert_eq!(
            serde_json::to_value(&event).unwrap(),
            serde_json::from_str::<Value>(json).unwrap(),
            "kept as it came"
        );
        let mut account = crate::account::Account::default();
        assert!(account.replay(&event).is_some());
        assert_eq!(account, crate::account::Account::default());
        assert!(!crate::session::shared_with_partners(&event.fact));
        // A batch holding one still unpacks.
        let packed = crate::sync::pack(std::slice::from_ref(&event));
        assert_eq!(crate::sync::unpack(&packed).unwrap(), vec![event]);
        // A known kind that doesn't read is still refused.
        assert!(serde_json::from_str::<Event>(r#"{"id":"e","at":1,"SetCompleted":7}"#).is_err());
    }

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
