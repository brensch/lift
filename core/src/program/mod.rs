//! The program: every rule that decides what a lift is given, as one JSON
//! document the account holds (`docs/plans/programs-as-config.md`).
//!
//! The exercises (what each one is, how it loads, what it trains), the
//! workouts (the templates, and which are the rotation), the classes, the
//! progressions (how a lift moves from session to session) and every number
//! the planner reads — the estimate, time off, the time budget's costs, the
//! warmup ladder, the calibration ramp, weekly volume, recovery, the
//! rotation check, the equipment's steps and plates — are read from here.
//! None of it is a constant in the code.
//!
//! The built-in rules are `programs/default.json`, compiled in. A program
//! is set by a `ProgramSet` event and is the latest word until the next. A
//! workout records the program it was planned under, so its sets fold the
//! same whatever is set after it.
//!
//! [GUIDE] (`programs/GUIDE.md`) describes the document for whoever writes
//! one; [validate] checks a draft and names the path of each problem.

use std::borrow::Cow;
use std::collections::BTreeMap;
use std::fmt;
use std::ops::Deref;
use std::sync::{Arc, OnceLock};

use serde::{Deserialize, Serialize};

use crate::pb::{EquipmentKind, MuscleGroup};
use crate::weight_units::AppWeightUnit;

pub mod edit;
pub mod formula;
mod loading;
mod validate;

pub use validate::{check, valid_key, validate, validate_for_account, Problem};

/// The schema every program names.
pub const SCHEMA: &str = "schlift.program/v1";

/// The built-in program, as JSON.
pub const DEFAULT_JSON: &str = include_str!("../../programs/default.json");

/// What a program is and how to write one, for an assistant.
pub const GUIDE: &str = include_str!("../../programs/GUIDE.md");

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Program {
    pub schema: String,
    pub name: String,
    /// Free text: who it is for and why it is the way it is.
    pub notes: String,
    /// In the order the picker shows them.
    pub exercises: Vec<ExerciseDef>,
    /// The templates, in the user's order.
    pub workouts: Vec<WorkoutDef>,
    /// How Home picks the next workout from the rotation. Volume in a
    /// program from before it existed.
    #[serde(default)]
    pub next: Next,
    /// For `next: schedule`, the workout (by id) each day of the week is
    /// for; a day not named is a rest day.
    #[serde(default)]
    pub schedule: BTreeMap<Weekday, String>,
    /// By name; every exercise is in one.
    pub classes: BTreeMap<String, Class>,
    /// By name; a class or an exercise names the one it follows.
    pub progressions: BTreeMap<String, Progression>,
    /// By name; a class or an exercise names the one its sets are laid out
    /// by. `straight` needn't be written.
    #[serde(default)]
    pub schemes: BTreeMap<String, Scheme>,
    pub estimate: Estimate,
    /// The max cut for time away. The largest `days` reached applies.
    pub time_off: Vec<TimeOff>,
    pub sets: Sets,
    pub costs: CostDefaults,
    pub warmups: Warmups,
    pub calibration: Calibration,
    pub volume: Volume,
    pub recovery: Recovery,
    pub rotation_check: RotationCheck,
    /// The rest after an exercise's last set: the next thing is another lift.
    pub end_of_exercise_rest_seconds: i64,
    /// The rest between two lifts of a group within a round.
    #[serde(default = "transition")]
    pub transition_seconds: i32,
    pub equipment: Equipment,
}

fn transition() -> i32 {
    15
}

/// One exercise: what it is, how it loads and what it trains.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct ExerciseDef {
    /// Lowercase letters, digits and underscores: how everything names it.
    /// Recorded on every set, so it never changes meaning.
    pub key: String,
    pub name: String,
    pub short_name: String,
    pub equipment: EquipmentStyle,
    /// Primary mover first: it counts 1.0 a set, the rest
    /// `volume.secondary_credit`.
    pub muscles: Vec<Muscle>,
    pub class: String,
    /// This lift's own progression, over its class's.
    pub progression: Option<String>,
    /// A plain description, for a lift the app has no picture of.
    pub description: String,
    /// This lift's own values for numbers of the rule it follows (see
    /// [`tune`]): one rule for several lifts that differ in a number, like
    /// a bigger step for legs. None in a program from before it existed.
    #[serde(default)]
    pub params: BTreeMap<String, f64>,
    /// What its number counts: reps, or seconds (a plank), or metres (a
    /// carry). Reps in a program from before it existed.
    #[serde(default)]
    pub measure: Measure,
    /// The number is for each side.
    #[serde(default)]
    pub per_side: bool,
    /// A cue shown with its sets ("3-1-1"), or "".
    #[serde(default)]
    pub tempo: String,
    /// Its own scheme, over its class's.
    #[serde(default)]
    pub scheme: Option<String>,
}

/// What a lift's number counts.
#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Eq, Default)]
#[serde(rename_all = "snake_case")]
pub enum Measure {
    #[default]
    Reps,
    Seconds,
    Metres,
}

impl Measure {
    pub fn to_proto(self) -> crate::pb::Measure {
        match self {
            Measure::Reps => crate::pb::Measure::Unspecified,
            Measure::Seconds => crate::pb::Measure::Seconds,
            Measure::Metres => crate::pb::Measure::Metres,
        }
    }
}

/// How a lift's sets are laid out from what its rule decides (sets, reps,
/// weight): a few steps, each some sets of one role. See the guide's
/// `schemes`.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Scheme {
    pub steps: Vec<Step>,
}

/// One step of a scheme.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Step {
    pub role: Role,
    /// A number of sets, or `"rest"`: the rule's sets less the numbered
    /// main steps'.
    pub count: StepCount,
    /// The number for each set; none: the rule's.
    #[serde(default)]
    pub reps: Option<i32>,
    /// Of the working weight; for a drop, of the set before it.
    #[serde(default = "one")]
    pub fraction: f32,
    #[serde(default)]
    pub amrap: bool,
    /// Reps left in the tank to aim for: the set asks after it.
    #[serde(default)]
    pub rir: Option<i32>,
    /// After each set; none: the class's rest (a drop's: none).
    #[serde(default)]
    pub rest_seconds: Option<i32>,
    /// EMOM: the next set starts this long after this one started.
    #[serde(default)]
    pub every_seconds: Option<i32>,
    /// What missing one of its sets changes for the rest of the lift.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub on_miss: Option<OnMiss>,
}

/// What a set missed (logged short of its target) changes for the rest of
/// its lift that workout; put back to every rep, it's taken back.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Default)]
pub struct OnMiss {
    /// The rest after the missed set, over the step's.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub rest_seconds: Option<i32>,
    /// The lift's sets still to do, at this share of their weight.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub fraction: Option<f32>,
    /// The lift's sets still to do are dropped.
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub stop: bool,
}

fn one() -> f32 {
    1.0
}

/// A set's role in its lift.
#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum Role {
    Working,
    Top,
    Backoff,
    Drop,
    Mini,
}

impl Role {
    /// Working, top and back-off sets: what the rule's sets count, and what
    /// says whether the session was hit.
    pub fn is_main(self) -> bool {
        matches!(self, Role::Working | Role::Top | Role::Backoff)
    }

    pub fn to_proto(self) -> crate::pb::SetRole {
        match self {
            Role::Working => crate::pb::SetRole::Unspecified,
            Role::Top => crate::pb::SetRole::Top,
            Role::Backoff => crate::pb::SetRole::Backoff,
            Role::Drop => crate::pb::SetRole::Drop,
            Role::Mini => crate::pb::SetRole::Mini,
        }
    }
}

/// A step's count: a number, or the word `rest`.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(untagged)]
pub enum StepCount {
    Sets(i32),
    Word(String),
}

impl StepCount {
    pub fn is_rest(&self) -> bool {
        matches!(self, StepCount::Word(w) if w == "rest")
    }
}

/// A group of a workout's lifts whose sets alternate: a superset (two) or
/// a circuit (more).
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct GroupDef {
    pub exercises: Vec<String>,
    /// After a round; none: the last lift's own rest.
    #[serde(default)]
    pub rest_seconds: Option<i32>,
}

/// One of the program's workouts: an ordered list of exercises.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct WorkoutDef {
    /// Stable: a finished workout names the one it came from.
    pub id: String,
    pub name: String,
    pub exercises: Vec<String>,
    /// In the rotation the suggestion picks from; otherwise a reserve.
    pub rotation: bool,
    pub notes: String,
    /// The library entry it was copied from, or empty.
    pub from_library: String,
    /// Lifts whose sets alternate (supersets, circuits). None in a program
    /// from before it existed.
    #[serde(default)]
    pub groups: Vec<GroupDef>,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Class {
    pub rep_low: i32,
    pub rep_high: i32,
    pub rest_seconds: i32,
    pub warmups: bool,
    pub progression: String,
    /// The name of its lifts' scheme; `straight` in a program from before
    /// schemes.
    #[serde(default = "straight")]
    pub scheme: String,
}

fn one_step() -> i32 {
    1
}

/// The scheme every lift had before schemes: the rule's sets, identical.
pub const STRAIGHT: &str = "straight";

fn straight() -> String {
    STRAIGHT.to_string()
}

/// How a lift moves from one session to the next. See the guide.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum Progression {
    /// The walk: an estimated max from every session, the class's rep
    /// range, sets from the time budget.
    EstimatedMax,
    /// The same sets, reps and weight every time.
    Fixed {
        sets: i32,
        reps: i32,
        weight_lb: f32,
    },
    /// The same reps; heavier by `increment_lb` (0: the equipment's step)
    /// after a session with every rep hit; after `deload_after_fails`
    /// sessions in a row with a rep missed (0: never), `deload_factor` of
    /// the weight.
    Linear {
        sets: Option<i32>,
        reps: i32,
        increment_lb: f32,
        deload_after_fails: i32,
        deload_factor: f32,
    },
    /// Reps climb by one a session (every rep hit) from `rep_low` to
    /// `rep_high`; past the top, heavier by `increment_lb` (0: the
    /// equipment's step) and back to `rep_low`.
    Double {
        sets: Option<i32>,
        rep_low: i32,
        rep_high: i32,
        increment_lb: f32,
        /// How many reps (or seconds, or metres) a session climbs by.
        #[serde(default = "one_step")]
        rep_step: i32,
    },
    /// One step a session, round and round: sets × reps at a fraction of
    /// the estimated max.
    Cycle { steps: Vec<CycleStep> },
    /// The program's own expressions.
    Formula(Formula),
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct CycleStep {
    pub sets: i32,
    pub reps: i32,
    pub fraction: f32,
}

/// A progression written as expressions (`formula.rs`).
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Formula {
    /// Names the other expressions can use, in any order (no cycles).
    #[serde(rename = "let")]
    pub lets: BTreeMap<String, String>,
    /// None: the time budget gives the sets.
    pub sets: Option<String>,
    pub reps: String,
    /// Pounds; snapped to what loads.
    pub weight: String,
    /// None: the class's rest.
    pub rest_seconds: Option<String>,
    /// Shown beside the plan.
    pub note: String,
}

/// The numbers of a rule a lift's `params` may set: a formula's `let`
/// names, or these fields of the other kinds that have them. The ones
/// that count are whole numbers.
const TUNABLE: [&str; 9] = [
    "sets",
    "rep_step",
    "reps",
    "rep_low",
    "rep_high",
    "deload_after_fails",
    "increment_lb",
    "deload_factor",
    "weight_lb",
];
const WHOLE: [&str; 6] = [
    "sets",
    "reps",
    "rep_low",
    "rep_high",
    "deload_after_fails",
    "rep_step",
];

/// `rule` with a lift's own values for its numbers: for a formula, each
/// name replaces the `let` of that name; for fixed, linear and double, the
/// field. An error names the param and why it doesn't fit.
pub fn tune(
    rule: &Progression,
    params: &BTreeMap<String, f64>,
) -> Result<Progression, (String, String)> {
    for (name, value) in params {
        if !value.is_finite() {
            return Err((name.clone(), "a number".into()));
        }
    }
    match rule {
        Progression::EstimatedMax | Progression::Cycle { .. } => match params.keys().next() {
            Some(name) => Err((
                name.clone(),
                format!("a {} rule has no numbers a lift can set", rule.kind()),
            )),
            None => Ok(rule.clone()),
        },
        Progression::Formula(f) => {
            let mut f = f.clone();
            for (name, value) in params {
                let Some(expr) = f.lets.get_mut(name) else {
                    let lets: Vec<&str> = f.lets.keys().map(String::as_str).collect();
                    return Err((
                        name.clone(),
                        format!("the formula has no `let` named {name:?} (it has {lets:?})"),
                    ));
                };
                *expr = if value.fract() == 0.0 && value.abs() < 1e15 {
                    format!("{}", *value as i64)
                } else {
                    format!("{value}")
                };
            }
            Ok(Progression::Formula(f))
        }
        _ => {
            let mut doc = serde_json::to_value(rule).expect("a rule serialises");
            let fields = doc.as_object_mut().expect("a rule is an object");
            for (name, value) in params {
                if !TUNABLE.contains(&name.as_str()) || !fields.contains_key(name) {
                    let has: Vec<&str> = fields
                        .keys()
                        .filter(|k| TUNABLE.contains(&k.as_str()))
                        .map(String::as_str)
                        .collect();
                    return Err((
                        name.clone(),
                        format!("a {} rule has no {name:?} (it has {has:?})", rule.kind()),
                    ));
                }
                let number = if WHOLE.contains(&name.as_str()) {
                    if value.fract() != 0.0 {
                        return Err((name.clone(), "a whole number".into()));
                    }
                    serde_json::Value::from(*value as i64)
                } else {
                    serde_json::Value::from(*value)
                };
                fields.insert(name.clone(), number);
            }
            serde_json::from_value(doc).map_err(|e| {
                let name = params.keys().next().cloned().unwrap_or_default();
                (name, e.to_string())
            })
        }
    }
}

impl Progression {
    pub fn kind(&self) -> &'static str {
        match self {
            Progression::EstimatedMax => "estimated_max",
            Progression::Fixed { .. } => "fixed",
            Progression::Linear { .. } => "linear",
            Progression::Double { .. } => "double",
            Progression::Cycle { .. } => "cycle",
            Progression::Formula(_) => "formula",
        }
    }

    /// Whether a lift never done finds its max with the calibration ramp
    /// first: every rule but `fixed`, which knows its weight.
    pub fn ramps(&self) -> bool {
        !matches!(self, Progression::Fixed { .. })
    }
}

/// The Epley estimate the walk reads every set with:
/// `max = weight × (1 + (reps + reserve + fatigue × (set − 1)) / divisor)`.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Estimate {
    pub divisor: f32,
    /// Reps in reserve a set that hit its target is counted with.
    pub reserve_when_hit: f32,
    /// Reps of fatigue counted for each set before this one.
    pub fatigue_per_set: f32,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct TimeOff {
    pub days: i64,
    pub factor: f32,
}

/// How many working sets a lift gets from the time budget.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Sets {
    /// The working sets of a lift whose rule names none. 3 in a program
    /// from before it existed (which handed them out by a time budget).
    #[serde(default = "three")]
    pub per_lift: i32,
    /// An override that names no sets is held for this many.
    pub override_sets: i32,
    /// No longer read: the time budget these sized sets by is gone. Kept
    /// so stored programs read back as they were written.
    #[serde(default = "sixty")]
    pub default_budget_minutes: i32,
    #[serde(default = "two")]
    pub min: i32,
    #[serde(default = "five")]
    pub max: i32,
}

fn three() -> i32 {
    3
}

fn sixty() -> i32 {
    60
}

fn two() -> i32 {
    2
}

fn five() -> i32 {
    5
}

/// What a workout's parts cost until the user's own timings are learned.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct CostDefaults {
    pub set_seconds: f32,
    pub warmup_seconds: f32,
    pub between_seconds: f32,
    pub learn_window_days: i64,
    pub learn_samples: usize,
    pub learn_min_set_seconds: f32,
    pub learn_min_gap_seconds: f32,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Warmups {
    /// Fractions of the working weight, lightest first.
    pub ladder: Vec<WarmupStep>,
    pub rest_seconds: i32,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct WarmupStep {
    pub fraction: f32,
    pub reps: i32,
}

/// The ramp a loaded lift never done finds its max with.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Calibration {
    pub reps: i32,
    pub rest_seconds: i32,
    /// The first rung, as a fraction of the starting weight.
    pub start_fraction: f32,
    /// Each rung climbs by at least this factor (and one equipment step).
    pub rung_factor: f32,
    pub max_rungs: usize,
    /// A rung with fewer reps was too heavy to say anything.
    pub too_heavy_reps: i32,
    /// A too-heavy rung's next rung is this fraction of it.
    pub step_down: f32,
    /// A typed jump is at most this many times the rung.
    pub max_jump_fraction: f32,
    /// The reps in reserve each answer to "how many more?" counts.
    pub reserve_zero_to_one: f32,
    pub reserve_two_to_four: f32,
    pub reserve_five_plus: f32,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Volume {
    pub window_days: i64,
    pub target_low: i32,
    pub target_high: i32,
    /// A working set counts this much for each muscle after the first.
    pub secondary_credit: f32,
    /// A template within this fraction of the best score is tied with it.
    pub tie_fraction: f32,
    /// What a drop or mini set counts toward a muscle's week, of a set.
    #[serde(default = "half")]
    pub partial_credit: f32,
    /// A muscle's own band, over `target_low`–`target_high`.
    #[serde(default)]
    pub targets: BTreeMap<Muscle, Band>,
}

fn half() -> f32 {
    0.5
}

impl Volume {
    /// `muscle`'s weekly band: its own target, or the program's.
    pub fn band(&self, muscle: Muscle) -> (i32, i32) {
        self.targets
            .get(&muscle)
            .map_or((self.target_low, self.target_high), |b| (b.low, b.high))
    }
}

/// One muscle's own weekly band, in sets.
#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Eq)]
pub struct Band {
    pub low: i32,
    pub high: i32,
}

/// How Home picks the next workout from the rotation.
#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Eq, Default)]
#[serde(rename_all = "snake_case")]
pub enum Next {
    /// The workout whose rested muscles are furthest behind the week's
    /// targets.
    #[default]
    Volume,
    /// The rotation in its order: the one after the last one started.
    Sequence,
    /// By day of the week, from `schedule`.
    Schedule,
}

/// A day of the week, in the person's own time.
#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
#[serde(rename_all = "snake_case")]
pub enum Weekday {
    Mon,
    Tue,
    Wed,
    Thu,
    Fri,
    Sat,
    Sun,
}

impl Weekday {
    pub const ALL: [Weekday; 7] = [
        Weekday::Mon,
        Weekday::Tue,
        Weekday::Wed,
        Weekday::Thu,
        Weekday::Fri,
        Weekday::Sat,
        Weekday::Sun,
    ];

    /// Monday 0 to Sunday 6.
    pub fn index(self) -> usize {
        self as usize
    }

    /// The day `unix` seconds falls on, `utc_offset` seconds east of UTC.
    pub fn of(unix: i64, utc_offset: i64) -> Weekday {
        // 1 January 1970 was a Thursday.
        let day = (unix + utc_offset).div_euclid(86_400);
        Weekday::ALL[(day + 3).rem_euclid(7) as usize]
    }
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Recovery {
    /// Hours per muscle; one not named takes `default_hours`.
    pub hours: BTreeMap<Muscle, i64>,
    pub default_hours: i64,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct RotationCheck {
    pub sets_per_lift: f32,
    pub overlap_fraction: f32,
}

/// Per kind of equipment, what a lift never done opens at and the step its
/// weights snap to and climb by; and the bar and plates barbells load.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Equipment {
    pub barbell: Loading,
    pub dumbbell: Loading,
    pub machine: Loading,
    pub cable: Loading,
    pub bodyweight: Loading,
    pub plates: Plates,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Loading {
    /// None: the empty bar.
    pub opener: Option<PerUnit>,
    pub step: PerUnit,
}

/// The bar and the plates on hand, each in its unit's own scale.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Plates {
    pub bar: PerUnit,
    /// Heaviest first.
    pub lb: Vec<f32>,
    pub kg: Vec<f32>,
}

impl Plates {
    pub fn bar(&self, unit: AppWeightUnit) -> f32 {
        self.bar.get(unit)
    }

    pub fn plates(&self, unit: AppWeightUnit) -> &[f32] {
        match unit {
            AppWeightUnit::Lb => &self.lb,
            AppWeightUnit::Kg => &self.kg,
        }
    }
}

#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq)]
pub struct PerUnit {
    pub lb: f32,
    pub kg: f32,
}

impl PerUnit {
    pub fn get(&self, unit: AppWeightUnit) -> f32 {
        match unit {
            AppWeightUnit::Lb => self.lb,
            AppWeightUnit::Kg => self.kg,
        }
    }
}

#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
#[serde(rename_all = "snake_case")]
pub enum EquipmentStyle {
    Barbell,
    Dumbbell,
    Machine,
    Cable,
    Bodyweight,
}

impl EquipmentStyle {
    pub fn to_proto(self) -> EquipmentKind {
        match self {
            EquipmentStyle::Barbell => EquipmentKind::Barbell,
            EquipmentStyle::Dumbbell => EquipmentKind::Dumbbell,
            EquipmentStyle::Machine => EquipmentKind::Machine,
            EquipmentStyle::Cable => EquipmentKind::Cable,
            EquipmentStyle::Bodyweight => EquipmentKind::Bodyweight,
        }
    }
}

/// The ten muscles every count is kept in.
#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
#[serde(rename_all = "snake_case")]
pub enum Muscle {
    Chest,
    Back,
    Shoulders,
    Biceps,
    Triceps,
    Quads,
    Hamstrings,
    Glutes,
    Calves,
    Core,
}

impl Muscle {
    /// In display order.
    pub const ALL: [Muscle; 10] = [
        Muscle::Chest,
        Muscle::Back,
        Muscle::Shoulders,
        Muscle::Biceps,
        Muscle::Triceps,
        Muscle::Quads,
        Muscle::Hamstrings,
        Muscle::Glutes,
        Muscle::Calves,
        Muscle::Core,
    ];

    pub fn to_proto(self) -> MuscleGroup {
        match self {
            Muscle::Chest => MuscleGroup::Chest,
            Muscle::Back => MuscleGroup::Back,
            Muscle::Shoulders => MuscleGroup::Shoulders,
            Muscle::Biceps => MuscleGroup::Biceps,
            Muscle::Triceps => MuscleGroup::Triceps,
            Muscle::Quads => MuscleGroup::Quads,
            Muscle::Hamstrings => MuscleGroup::Hamstrings,
            Muscle::Glutes => MuscleGroup::Glutes,
            Muscle::Calves => MuscleGroup::Calves,
            Muscle::Core => MuscleGroup::Core,
        }
    }

    pub fn from_proto(muscle: MuscleGroup) -> Option<Self> {
        Muscle::ALL.into_iter().find(|m| m.to_proto() == muscle)
    }
}

/// What laying a workout's sets out reads from the program it was planned
/// under: the estimate (a ramp settles by it), the warmup ladder, the
/// calibration ramp, the rest after an exercise's last set, the equipment,
/// and the workout's own exercises. A start records it, so the workout
/// folds the same anywhere — on a session partner's phone, or after any
/// program set since — from its own events alone.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
pub struct Rules {
    pub estimate: Estimate,
    pub warmups: Warmups,
    pub calibration: Calibration,
    pub end_of_exercise_rest_seconds: i64,
    pub equipment: Equipment,
    pub exercises: Vec<ExerciseDef>,
}

impl Rules {
    /// A program that lays out by these rules: the built-in one with them
    /// in place.
    pub fn program(&self) -> Program {
        Program {
            estimate: self.estimate.clone(),
            warmups: self.warmups.clone(),
            calibration: self.calibration.clone(),
            end_of_exercise_rest_seconds: self.end_of_exercise_rest_seconds,
            equipment: self.equipment.clone(),
            exercises: self.exercises.clone(),
            workouts: Vec::new(),
            ..(*Program::builtin()).clone()
        }
    }
}

/// What an exercise the program doesn't define reads as: a session
/// partner's own lift, folded on this phone. It loads like a machine and
/// trains nothing, so it counts for no muscle.
static UNKNOWN: OnceLock<ExerciseDef> = OnceLock::new();

fn unknown_exercise() -> &'static ExerciseDef {
    UNKNOWN.get_or_init(|| ExerciseDef {
        key: String::new(),
        name: String::new(),
        short_name: String::new(),
        equipment: EquipmentStyle::Machine,
        muscles: Vec::new(),
        class: String::new(),
        progression: None,
        description: String::new(),
        params: BTreeMap::new(),
        measure: Measure::Reps,
        per_side: false,
        tempo: String::new(),
        scheme: None,
    })
}

impl Program {
    /// The built-in program: the rules, no workouts.
    pub fn builtin() -> ProgramRef {
        static BUILTIN: OnceLock<ProgramRef> = OnceLock::new();
        BUILTIN
            .get_or_init(|| {
                ProgramRef(Arc::new(
                    serde_json::from_str(DEFAULT_JSON).expect("the default program reads"),
                ))
            })
            .clone()
    }

    /// A document as JSON, read: the shape only (see [validate]).
    pub fn parse(json: &str) -> Result<Program, serde_json::Error> {
        serde_json::from_str(json)
    }

    /// The exercise named `key`.
    pub fn exercise(&self, key: &str) -> Option<&ExerciseDef> {
        self.exercises.iter().find(|e| e.key == key)
    }

    /// The exercise named `key`, or what an unknown one reads as.
    pub fn exercise_or_unknown(&self, key: &str) -> &ExerciseDef {
        self.exercise(key).unwrap_or_else(|| unknown_exercise())
    }

    /// Whether this plans by the built-in rules: everything but the
    /// workouts as the built-in program has it, its exercises included,
    /// and any it adds on no progression of their own (what reset leaves).
    pub fn uses_builtin_rules(&self) -> bool {
        let builtin = Program::builtin();
        // Schemes count by what's used, not what's written: a scheme no
        // class names plans nothing, and `straight` is identical sets
        // whether written out or not.
        let rules = |p: &Program| Program {
            workouts: Vec::new(),
            exercises: Vec::new(),
            schemes: BTreeMap::new(),
            ..p.clone()
        };
        let used =
            |p: &Program, name: &str| (name != STRAIGHT).then(|| p.schemes.get(name).cloned());
        rules(self) == rules(&builtin)
            && self
                .classes
                .values()
                .all(|c| used(self, &c.scheme) == used(&builtin, &c.scheme))
            && builtin
                .exercises
                .iter()
                .all(|e| self.exercise(&e.key) == Some(e))
            && self
                .exercises
                .iter()
                .all(|e| builtin.knows(&e.key) || e.progression.is_none())
    }

    pub fn knows(&self, key: &str) -> bool {
        self.exercise(key).is_some()
    }

    pub fn workout(&self, id: &str) -> Option<&WorkoutDef> {
        self.workouts.iter().find(|w| w.id == id)
    }

    pub fn loading(&self, style: EquipmentStyle) -> &Loading {
        match style {
            EquipmentStyle::Barbell => &self.equipment.barbell,
            EquipmentStyle::Dumbbell => &self.equipment.dumbbell,
            EquipmentStyle::Machine => &self.equipment.machine,
            EquipmentStyle::Cable => &self.equipment.cable,
            EquipmentStyle::Bodyweight => &self.equipment.bodyweight,
        }
    }

    /// The class an exercise is in. Validation makes every one resolve; an
    /// exercise the program doesn't know reads as the first class.
    pub fn class_of(&self, key: &str) -> &Class {
        self.exercise(key)
            .and_then(|e| self.classes.get(&e.class))
            .or_else(|| self.classes.values().next())
            .expect("a program has a class")
    }

    /// The name of the progression an exercise follows: its own, or its
    /// class's.
    pub fn progression_name(&self, key: &str) -> &str {
        self.exercise(key)
            .and_then(|e| e.progression.as_deref())
            .unwrap_or(&self.class_of(key).progression)
    }

    /// The progression an exercise follows, with the exercise's own
    /// `params` in it ([`tune`]). One the program doesn't define, or
    /// params that don't fit it (validation refuses both), read as the
    /// rule as written or the estimated max.
    pub fn progression_of(&self, key: &str) -> Cow<'_, Progression> {
        const ESTIMATED_MAX: Progression = Progression::EstimatedMax;
        let rule = self
            .progressions
            .get(self.progression_name(key))
            .unwrap_or(&ESTIMATED_MAX);
        match self.exercise(key).map(|e| &e.params) {
            Some(params) if !params.is_empty() => {
                tune(rule, params).map_or(Cow::Borrowed(rule), Cow::Owned)
            }
            _ => Cow::Borrowed(rule),
        }
    }

    /// The name of the scheme an exercise's sets are laid out by: its own,
    /// or its class's.
    pub fn scheme_name(&self, key: &str) -> &str {
        self.exercise(key)
            .and_then(|e| e.scheme.as_deref())
            .unwrap_or(&self.class_of(key).scheme)
    }

    /// The scheme an exercise's sets are laid out by. `straight` (identical
    /// sets, written out or not), or one the program doesn't define
    /// (validation refuses that), is None: the rule's sets as they are.
    pub fn scheme_of(&self, key: &str) -> Option<&Scheme> {
        match self.scheme_name(key) {
            STRAIGHT => None,
            name => self.schemes.get(name),
        }
    }

    /// The hours a muscle takes to recover.
    pub fn recovery_hours(&self, muscle: Muscle) -> i64 {
        self.recovery
            .hours
            .get(&muscle)
            .copied()
            .unwrap_or(self.recovery.default_hours)
    }

    /// The document, as stored and as an assistant reads it.
    pub fn to_json(&self) -> String {
        serde_json::to_string_pretty(self).expect("a program serialises")
    }

    /// The rules laying out a workout of `exercises` reads.
    pub fn rules_for(&self, exercises: &[String]) -> Rules {
        Rules {
            estimate: self.estimate.clone(),
            warmups: self.warmups.clone(),
            calibration: self.calibration.clone(),
            end_of_exercise_rest_seconds: self.end_of_exercise_rest_seconds,
            equipment: self.equipment.clone(),
            exercises: self.definitions(exercises),
        }
    }

    /// The definitions of `exercises` the program has, in their order.
    pub fn definitions(&self, exercises: &[String]) -> Vec<ExerciseDef> {
        exercises
            .iter()
            .filter_map(|key| self.exercise(key).cloned())
            .collect()
    }

    /// The same program, knowing `more` exercises too (any it has already
    /// keep theirs).
    pub fn with_exercises(&self, more: &[ExerciseDef]) -> Program {
        let mut out = self.clone();
        for def in more {
            if !out.knows(&def.key) {
                out.exercises.push(def.clone());
            }
        }
        out
    }

    /// The same rules with these workouts.
    pub fn with_workouts(&self, workouts: Vec<WorkoutDef>) -> Program {
        Program {
            workouts,
            ..self.clone()
        }
    }
}

/// A program shared by the account and the workouts planned under it.
/// Cheap to clone; equal when the documents are; written as the document.
#[derive(Clone)]
pub struct ProgramRef(pub Arc<Program>);

impl Serialize for ProgramRef {
    fn serialize<S: serde::Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        self.0.serialize(serializer)
    }
}

impl<'de> Deserialize<'de> for ProgramRef {
    fn deserialize<D: serde::Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        Program::deserialize(deserializer).map(ProgramRef::new)
    }
}

impl ProgramRef {
    pub fn new(program: Program) -> Self {
        Self(Arc::new(program))
    }
}

impl Default for ProgramRef {
    fn default() -> Self {
        Program::builtin()
    }
}

impl Deref for ProgramRef {
    type Target = Program;
    fn deref(&self) -> &Program {
        &self.0
    }
}

impl PartialEq for ProgramRef {
    fn eq(&self, other: &Self) -> bool {
        Arc::ptr_eq(&self.0, &other.0) || *self.0 == *other.0
    }
}

impl fmt::Debug for ProgramRef {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Program({:?})", self.0.name)
    }
}

#[cfg(test)]
mod tests;
