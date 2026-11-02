//! Per-exercise metadata: what a movement is (equipment, role, muscles)
//! and what its class gives it (rep range, rest, warmups), with the opener
//! weight and the progression step.
//!
//! This is the single source of truth. The plan, the volume model,
//! recovery, the picker's equipment filter and the progression step all
//! read from here — there is no second classification anywhere.

use crate::pb::{EquipmentKind, Exercise, ExerciseCategory, MuscleGroup};
use crate::weight_units::{
    bar_weight, kg_to_pounds, round_to_unit_increment, snap_loadable_lb, AppWeightUnit,
};

/// How a move is loaded. Decides the smallest step you can actually add,
/// the opener with no history, and whether "add weight" is even the right
/// progression (it is not for bodyweight work).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum LoadStyle {
    Barbell,
    Dumbbell,
    Machine,
    Cable,
    /// Loaded by your own mass. Progresses by reps, not plates.
    Bodyweight,
}

impl LoadStyle {
    pub fn to_proto(self) -> EquipmentKind {
        match self {
            LoadStyle::Barbell => EquipmentKind::Barbell,
            LoadStyle::Dumbbell => EquipmentKind::Dumbbell,
            LoadStyle::Machine => EquipmentKind::Machine,
            LoadStyle::Cable => EquipmentKind::Cable,
            LoadStyle::Bodyweight => EquipmentKind::Bodyweight,
        }
    }
}

/// Every exercise in the enum. Scanned rather than hand-listed so a new
/// exercise is picked up without a second place to update; the upper bound
/// is generous slack over the current catalogue.
pub fn all_exercises() -> Vec<Exercise> {
    (1..256)
        .filter_map(|value| Exercise::try_from(value).ok())
        .filter(|ex| *ex != Exercise::Unspecified)
        .collect()
}

pub fn load_style(ex: Exercise) -> LoadStyle {
    use Exercise as E;
    use LoadStyle::*;
    match ex {
        // ── Barbell ──
        E::Squat
        | E::BenchPress
        | E::Deadlift
        | E::OverheadPress
        | E::BarbellRow
        | E::HipThrust
        | E::RomanianDeadlift
        | E::GluteBridge
        | E::InclineBenchPress
        | E::PendlayRow
        | E::TBarRow
        | E::Shrug
        | E::UprightRow
        | E::BarbellCurl
        | E::PreacherCurl
        | E::SkullCrusher
        | E::CloseGripBenchPress
        | E::FrontSquat
        | E::GoodMorning
        | E::SumoDeadlift => Barbell,

        // ── Dumbbell ──
        // CalfRaise is here on purpose: a standing calf raise is
        // dumbbell-loaded, and calves must be reachable without machines.
        E::DumbbellBenchPress
        | E::InclineDumbbellPress
        | E::DumbbellFly
        | E::DumbbellRow
        | E::DumbbellShoulderPress
        | E::ArnoldPress
        | E::LateralRaise
        | E::FrontRaise
        | E::RearDeltFly
        | E::DumbbellCurl
        | E::HammerCurl
        | E::ConcentrationCurl
        | E::OverheadTricepExtension
        | E::TricepKickback
        | E::BulgarianSplitSquat
        | E::Lunge
        | E::WalkingLunge
        | E::StepUp
        | E::GobletSquat
        | E::CurtsyLunge
        | E::SumoSquat
        | E::CalfRaise
        | E::RussianTwist => Dumbbell,

        // ── Machine (pin/plate stacks) ──
        E::MachineChestPress
        | E::PecDeck
        | E::LegPress
        | E::LegExtension
        | E::LegCurl
        | E::HackSquat
        | E::SeatedCalfRaise
        | E::HipAbduction
        | E::HipAdduction => Machine,

        // ── Cable ──
        E::CableFly
        | E::LatPulldown
        | E::SeatedCableRow
        | E::FacePull
        | E::CableCurl
        | E::TricepPushdown
        | E::CablePullThrough
        | E::CableCrunch
        | E::GluteKickback => Cable,

        // ── Bodyweight (and belt-loadable bodyweight) ──
        E::PushUp
        | E::ChestDip
        | E::TricepDip
        | E::PullUp
        | E::ChinUp
        | E::BackExtension
        | E::NordicCurl
        | E::FrogPump
        | E::SingleLegHipThrust
        | E::Plank
        | E::HangingLegRaise
        | E::AbWheelRollout
        | E::SitUp
        | E::Crunch
        | E::MountainClimber => Bodyweight,

        E::Unspecified => Bodyweight,
    }
}

/// The muscles a move trains, primary mover first. The volume model
/// counts the primary at 1.0 and each secondary at 0.5; recovery uses
/// "trained at all". One mapping, ten muscles, no other taxonomy.
pub fn muscles(ex: Exercise) -> &'static [MuscleGroup] {
    use Exercise as E;
    use MuscleGroup::*;
    match ex {
        E::Squat => &[Quads, Glutes],
        E::BenchPress => &[Chest, Triceps, Shoulders],
        E::Deadlift => &[Back, Hamstrings, Glutes],
        E::OverheadPress => &[Shoulders, Triceps],
        E::BarbellRow => &[Back, Biceps],
        E::HipThrust => &[Glutes, Hamstrings],
        E::BulgarianSplitSquat => &[Quads, Glutes],
        E::RomanianDeadlift => &[Hamstrings, Glutes],
        E::GluteBridge => &[Glutes],
        E::Lunge => &[Quads, Glutes],
        E::LegCurl => &[Hamstrings],
        E::InclineBenchPress => &[Chest, Shoulders, Triceps],
        E::DumbbellBenchPress => &[Chest, Triceps],
        E::InclineDumbbellPress => &[Chest, Shoulders, Triceps],
        E::DumbbellFly => &[Chest],
        E::CableFly => &[Chest],
        E::PushUp => &[Chest, Triceps],
        E::ChestDip => &[Chest, Triceps],
        E::MachineChestPress => &[Chest, Triceps],
        E::PecDeck => &[Chest],
        E::PullUp => &[Back, Biceps],
        E::ChinUp => &[Back, Biceps],
        E::LatPulldown => &[Back, Biceps],
        E::SeatedCableRow => &[Back, Biceps],
        E::DumbbellRow => &[Back, Biceps],
        E::TBarRow => &[Back, Biceps],
        E::PendlayRow => &[Back, Biceps],
        E::FacePull => &[Shoulders, Back],
        E::Shrug => &[Back],
        E::BackExtension => &[Back, Glutes, Hamstrings],
        E::DumbbellShoulderPress => &[Shoulders, Triceps],
        E::ArnoldPress => &[Shoulders, Triceps],
        E::LateralRaise => &[Shoulders],
        E::FrontRaise => &[Shoulders],
        E::RearDeltFly => &[Shoulders],
        E::UprightRow => &[Shoulders, Back],
        E::BarbellCurl => &[Biceps],
        E::DumbbellCurl => &[Biceps],
        E::HammerCurl => &[Biceps],
        E::PreacherCurl => &[Biceps],
        E::ConcentrationCurl => &[Biceps],
        E::CableCurl => &[Biceps],
        E::TricepPushdown => &[Triceps],
        E::OverheadTricepExtension => &[Triceps],
        E::SkullCrusher => &[Triceps],
        E::CloseGripBenchPress => &[Triceps, Chest],
        E::TricepDip => &[Triceps, Chest],
        E::TricepKickback => &[Triceps],
        E::FrontSquat => &[Quads, Glutes, Core],
        E::LegPress => &[Quads, Glutes],
        E::LegExtension => &[Quads],
        E::HackSquat => &[Quads, Glutes],
        E::GobletSquat => &[Quads, Glutes],
        E::WalkingLunge => &[Quads, Glutes],
        E::StepUp => &[Quads, Glutes],
        E::CalfRaise => &[Calves],
        E::SeatedCalfRaise => &[Calves],
        E::NordicCurl => &[Hamstrings],
        E::GoodMorning => &[Hamstrings, Glutes, Back],
        E::GluteKickback => &[Glutes],
        E::SumoDeadlift => &[Glutes, Hamstrings, Back],
        E::SumoSquat => &[Glutes, Quads],
        E::CurtsyLunge => &[Glutes, Quads],
        E::FrogPump => &[Glutes],
        E::SingleLegHipThrust => &[Glutes, Hamstrings],
        E::CablePullThrough => &[Glutes, Hamstrings],
        E::HipAbduction => &[Glutes],
        E::HipAdduction => &[Quads],
        E::Plank => &[Core],
        E::HangingLegRaise => &[Core],
        E::CableCrunch => &[Core],
        E::RussianTwist => &[Core],
        E::AbWheelRollout => &[Core],
        E::SitUp => &[Core],
        E::Crunch => &[Core],
        E::MountainClimber => &[Core],
        E::Unspecified => &[],
    }
}

pub fn primary_muscle(ex: Exercise) -> MuscleGroup {
    muscles(ex)
        .first()
        .copied()
        .unwrap_or(MuscleGroup::Unspecified)
}

/// The ten muscles, in display order.
pub const ALL_MUSCLES: [MuscleGroup; 10] = [
    MuscleGroup::Chest,
    MuscleGroup::Back,
    MuscleGroup::Shoulders,
    MuscleGroup::Biceps,
    MuscleGroup::Triceps,
    MuscleGroup::Quads,
    MuscleGroup::Hamstrings,
    MuscleGroup::Glutes,
    MuscleGroup::Calves,
    MuscleGroup::Core,
];

pub fn muscle_key(muscle: MuscleGroup) -> &'static str {
    match muscle {
        MuscleGroup::Chest => "chest",
        MuscleGroup::Back => "back",
        MuscleGroup::Shoulders => "shoulders",
        MuscleGroup::Biceps => "biceps",
        MuscleGroup::Triceps => "triceps",
        MuscleGroup::Quads => "quads",
        MuscleGroup::Hamstrings => "hamstrings",
        MuscleGroup::Glutes => "glutes",
        MuscleGroup::Calves => "calves",
        MuscleGroup::Core => "core",
        MuscleGroup::Unspecified => "unspecified",
    }
}

pub fn muscle_label(muscle: MuscleGroup) -> &'static str {
    match muscle {
        MuscleGroup::Chest => "Chest",
        MuscleGroup::Back => "Back",
        MuscleGroup::Shoulders => "Shoulders",
        MuscleGroup::Biceps => "Biceps",
        MuscleGroup::Triceps => "Triceps",
        MuscleGroup::Quads => "Quads",
        MuscleGroup::Hamstrings => "Hamstrings",
        MuscleGroup::Glutes => "Glutes",
        MuscleGroup::Calves => "Calves",
        MuscleGroup::Core => "Core",
        MuscleGroup::Unspecified => "Unspecified",
    }
}

pub fn category(ex: Exercise) -> ExerciseCategory {
    use Exercise as E;
    match ex {
        E::Squat
        | E::BenchPress
        | E::Deadlift
        | E::OverheadPress
        | E::BarbellRow
        | E::HipThrust
        | E::BulgarianSplitSquat
        | E::RomanianDeadlift
        | E::GluteBridge
        | E::Lunge
        | E::InclineBenchPress
        | E::DumbbellBenchPress
        | E::InclineDumbbellPress
        | E::PushUp
        | E::ChestDip
        | E::MachineChestPress
        | E::PullUp
        | E::ChinUp
        | E::LatPulldown
        | E::SeatedCableRow
        | E::DumbbellRow
        | E::TBarRow
        | E::PendlayRow
        | E::DumbbellShoulderPress
        | E::ArnoldPress
        | E::CloseGripBenchPress
        | E::TricepDip
        | E::FrontSquat
        | E::LegPress
        | E::HackSquat
        | E::GobletSquat
        | E::WalkingLunge
        | E::StepUp
        | E::GoodMorning
        | E::SumoDeadlift
        | E::SumoSquat
        | E::CurtsyLunge
        | E::SingleLegHipThrust
        | E::CablePullThrough => ExerciseCategory::Compound,
        _ => ExerciseCategory::Auxiliary,
    }
}

/// The three classes every lift falls in. The class sets the rep range,
/// the rest and the warmups; the sets come from the workout's budget
/// (`plan::sets_for_lifts`).
///
/// | Class | Lifts | Reps | Rest | Warmups |
/// |---|---|---|---|---|
/// | Heavy | barbell compounds | 5–8 | 3:00 | 40/55/70/85% ladder |
/// | Standard | every other loaded lift | 8–12 | 2:00 | none |
/// | Bodyweight | bodyweight lifts and core | 5–15 | 1:30 | none |
///
/// 1RM strength favours heavy loads, and 5–8 reps is heavy (roughly 75–85%
/// of a max); growth is alike from about 6 to 30 reps taken near failure
/// (Schoenfeld et al. 2017; Lopez et al. 2021). Longer rest beats short on
/// the big lifts (Schoenfeld et al. 2016).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum LiftClass {
    Heavy,
    Standard,
    Bodyweight,
}

pub fn lift_class(ex: Exercise) -> LiftClass {
    if load_style(ex) == LoadStyle::Bodyweight || primary_muscle(ex) == MuscleGroup::Core {
        LiftClass::Bodyweight
    } else if load_style(ex) == LoadStyle::Barbell && category(ex) == ExerciseCategory::Compound {
        LiftClass::Heavy
    } else {
        LiftClass::Standard
    }
}

/// What a lift's class gives it: the rep range, the rest after a set and
/// whether a warmup ladder leads into the working sets.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ClassRules {
    pub rep_low: i32,
    pub rep_high: i32,
    pub rest_seconds: i32,
    pub warmups: bool,
}

pub fn class_rules(class: LiftClass) -> ClassRules {
    match class {
        LiftClass::Heavy => ClassRules {
            rep_low: 5,
            rep_high: 8,
            rest_seconds: 180,
            warmups: true,
        },
        LiftClass::Standard => ClassRules {
            rep_low: 8,
            rep_high: 12,
            rest_seconds: 120,
            warmups: false,
        },
        LiftClass::Bodyweight => ClassRules {
            rep_low: 5,
            rep_high: 15,
            rest_seconds: 90,
            warmups: false,
        },
    }
}

/// The rules of the lift's class.
pub fn rules(ex: Exercise) -> ClassRules {
    class_rules(lift_class(ex))
}

/// The weight to prefill for an exercise with no history. The empty bar
/// for barbell work, a conservative stack/dumbbell otherwise, and nothing
/// at all for bodyweight moves — where a prefilled number would be a lie.
pub fn starting_weight_lb(ex: Exercise, unit: AppWeightUnit) -> f32 {
    let in_unit = |lb: f32, kg: f32| match unit {
        AppWeightUnit::Lb => lb,
        AppWeightUnit::Kg => kg_to_pounds(kg),
    };
    match load_style(ex) {
        LoadStyle::Barbell => in_unit(bar_weight(AppWeightUnit::Lb), bar_weight(AppWeightUnit::Kg)),
        LoadStyle::Dumbbell => in_unit(20.0, 10.0),
        LoadStyle::Machine => in_unit(40.0, 20.0),
        LoadStyle::Cable => in_unit(20.0, 10.0),
        LoadStyle::Bodyweight => 0.0,
    }
}

/// How much to add when the rep range tops out. Sized to the smallest
/// jump the equipment actually allows: a pair of the smallest plates on a
/// bar, one notch on a stack, the next dumbbell up. Load moves rarely
/// under double progression, so small is correct.
pub fn progression_increment_lb(ex: Exercise, unit: AppWeightUnit) -> f32 {
    let in_unit = |lb: f32, kg: f32| match unit {
        AppWeightUnit::Lb => lb,
        AppWeightUnit::Kg => kg_to_pounds(kg),
    };
    match load_style(ex) {
        // Bodyweight work progresses by reps; adding phantom pounds to a
        // push-up would be nonsense.
        LoadStyle::Bodyweight => 0.0,
        LoadStyle::Dumbbell => in_unit(5.0, 2.0),
        _ => in_unit(5.0, 2.5),
    }
}

/// Round a computed weight to something you can load for this exercise:
/// real plate maths for barbells (never under the empty bar), the
/// equipment's step size for the rest.
pub fn snap_weight_lb(ex: Exercise, weight_lb: f32, unit: AppWeightUnit) -> f32 {
    if weight_lb <= 0.0 {
        return 0.0;
    }
    match load_style(ex) {
        LoadStyle::Barbell => snap_loadable_lb(weight_lb, unit).max(starting_weight_lb(ex, unit)),
        LoadStyle::Bodyweight => weight_lb,
        LoadStyle::Dumbbell => round_to_unit_increment(weight_lb, unit, 5.0, 2.0),
        _ => round_to_unit_increment(weight_lb, unit, 5.0, 2.5),
    }
}

/// The heaviest weight at or under `weight_lb` you can load for this
/// exercise (never under the empty bar or one step).
pub fn snap_down_weight_lb(ex: Exercise, weight_lb: f32, unit: AppWeightUnit) -> f32 {
    let step = progression_increment_lb(ex, unit);
    let snapped = snap_weight_lb(ex, weight_lb, unit);
    if step <= 0.0 {
        return snapped;
    }
    let down = if snapped <= weight_lb + 1e-3 {
        snapped
    } else {
        snap_weight_lb(ex, snapped - step, unit)
    };
    down.max(snap_weight_lb(ex, step, unit))
}

/// Human name for an exercise, derived from the enum name — e.g.
/// `EXERCISE_INCLINE_BENCH_PRESS` → `Incline Bench Press`. A few common
/// lifts get their colloquial short forms.
pub fn exercise_display_name(exercise: Exercise) -> String {
    match exercise {
        Exercise::OverheadPress => "OHP".to_string(),
        Exercise::RomanianDeadlift => "RDL".to_string(),
        Exercise::BulgarianSplitSquat => "BSS".to_string(),
        other => prettify_exercise_name(other.as_str_name()),
    }
}

fn prettify_exercise_name(str_name: &str) -> String {
    let trimmed = str_name.strip_prefix("EXERCISE_").unwrap_or(str_name);
    if trimmed.is_empty() {
        return "Unknown".to_string();
    }
    trimmed
        .split('_')
        .map(|word| {
            let mut chars = word.chars();
            match chars.next() {
                Some(first) => {
                    first.to_uppercase().collect::<String>() + &chars.as_str().to_lowercase()
                }
                None => String::new(),
            }
        })
        .collect::<Vec<_>>()
        .join(" ")
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Every exercise must be classified — a `_ =>` fallback in
    /// `load_style` or `muscles` would quietly misfile a new lift, so the
    /// matches are exhaustive and this pins the scan that feeds them.
    #[test]
    fn the_catalogue_covers_every_exercise() {
        let all = all_exercises();
        assert!(
            all.len() >= 76,
            "expected the full catalogue, got {}",
            all.len()
        );
        for ex in &all {
            assert!(!muscles(*ex).is_empty(), "{ex:?} has no muscle mapping");
            let p = rules(*ex);
            assert!(p.rep_low > 0 && p.rep_high >= p.rep_low, "{ex:?}: {p:?}");
            assert!(p.rest_seconds > 0);
        }
    }

    /// The primary mover comes first — the volume model counts it at 1.0
    /// and everything after at 0.5, so order is load-bearing.
    #[test]
    fn primary_muscles_are_sane() {
        assert_eq!(primary_muscle(Exercise::Squat), MuscleGroup::Quads);
        assert_eq!(primary_muscle(Exercise::BenchPress), MuscleGroup::Chest);
        assert_eq!(
            primary_muscle(Exercise::RomanianDeadlift),
            MuscleGroup::Hamstrings
        );
        assert_eq!(primary_muscle(Exercise::BarbellCurl), MuscleGroup::Biceps);
        assert_eq!(primary_muscle(Exercise::CalfRaise), MuscleGroup::Calves);
        assert_eq!(primary_muscle(Exercise::Plank), MuscleGroup::Core);
    }

    /// Calves must be reachable without machines: a standing calf raise
    /// is dumbbell-loaded.
    #[test]
    fn calf_raise_is_dumbbell() {
        assert_eq!(load_style(Exercise::CalfRaise), LoadStyle::Dumbbell);
    }

    /// The class table, pinned: only the barbell compounds are heavy and
    /// warm up; core lifts are in the bodyweight class whatever loads them.
    #[test]
    fn rules_follow_the_class() {
        let heavy = ClassRules {
            rep_low: 5,
            rep_high: 8,
            rest_seconds: 180,
            warmups: true,
        };
        for ex in [
            Exercise::Squat,
            Exercise::BenchPress,
            Exercise::Deadlift,
            Exercise::OverheadPress,
            Exercise::BarbellRow,
        ] {
            assert_eq!(rules(ex), heavy, "{ex:?}");
        }
        let standard = rules(Exercise::LateralRaise);
        assert_eq!(
            (standard.rep_low, standard.rep_high, standard.rest_seconds),
            (8, 12, 120)
        );
        assert!(!standard.warmups);
        assert_eq!(lift_class(Exercise::BarbellCurl), LiftClass::Standard);
        assert_eq!(lift_class(Exercise::DumbbellRow), LiftClass::Standard);
        for ex in [Exercise::PullUp, Exercise::Crunch, Exercise::CableCrunch] {
            let p = rules(ex);
            assert_eq!(
                (p.rep_low, p.rep_high, p.rest_seconds),
                (5, 15, 90),
                "{ex:?}"
            );
            assert!(!p.warmups);
        }
    }

    #[test]
    fn barbell_work_starts_at_the_empty_bar() {
        assert_eq!(starting_weight_lb(Exercise::Squat, AppWeightUnit::Lb), 45.0);
        let kg_bar = starting_weight_lb(Exercise::Squat, AppWeightUnit::Kg);
        assert!((crate::weight_units::pounds_to_kg(kg_bar) - 20.0).abs() < 0.01);
    }

    #[test]
    fn bodyweight_moves_have_no_weight_and_no_increment() {
        assert_eq!(starting_weight_lb(Exercise::PushUp, AppWeightUnit::Lb), 0.0);
        assert_eq!(
            progression_increment_lb(Exercise::PullUp, AppWeightUnit::Lb),
            0.0
        );
    }

    #[test]
    fn snapping_keeps_weights_loadable() {
        let snapped = snap_weight_lb(Exercise::Squat, 137.0, AppWeightUnit::Lb);
        assert_eq!(snapped, snap_loadable_lb(137.0, AppWeightUnit::Lb));
        assert_eq!(
            snap_weight_lb(Exercise::LateralRaise, 22.0, AppWeightUnit::Lb),
            20.0
        );
        assert_eq!(
            snap_weight_lb(Exercise::Squat, 40.5, AppWeightUnit::Lb),
            45.0,
            "a barbell never goes under the empty bar"
        );
    }

    #[test]
    fn snapping_down_never_goes_over() {
        let lb = AppWeightUnit::Lb;
        assert_eq!(snap_down_weight_lb(Exercise::Squat, 189.7, lb), 185.0);
        assert_eq!(snap_down_weight_lb(Exercise::Squat, 190.0, lb), 190.0);
        assert_eq!(snap_down_weight_lb(Exercise::Squat, 30.0, lb), 45.0);
        assert_eq!(snap_down_weight_lb(Exercise::LateralRaise, 24.0, lb), 20.0);
        assert_eq!(snap_down_weight_lb(Exercise::LateralRaise, 2.0, lb), 5.0);
        let kg = AppWeightUnit::Kg;
        let down = snap_down_weight_lb(Exercise::Squat, 100.0, kg);
        assert!(down <= 100.0 + 1e-3 && down > 94.0, "{down}");
    }
}
