//! Per-exercise metadata that isn't tied to any regime: how a move is loaded,
//! what a sensible first prescription looks like, and how much weight to add
//! when you clear it.
//!
//! The regimes only know about the five barbell lifts they program. Everything
//! else — the accessory you added mid-workout, the machine you like — needs the
//! same three answers so it can progress too, which is what this table provides.
//! `crate::exercise_progress` turns it into an actual progression.

use crate::weight_units::{
    bar_weight, kg_to_pounds, round_to_unit_increment, snap_loadable_lb, AppWeightUnit,
};
use schlift::workout::v1::{Exercise, ExerciseCategory};

/// How a move is loaded. Decides the plate/stack granularity you can actually
/// add, the weight you start at with no history, and whether "add weight" is
/// even the right progression (it isn't for bodyweight work).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum LoadStyle {
    Barbell,
    Dumbbell,
    Machine,
    Cable,
    /// Loaded by your own mass. Progress by reps, not plates — these hold their
    /// weight (usually 0) unless you've been adding a belt, in which case the
    /// recorded weight progresses like any other.
    Bodyweight,
}

/// Every exercise in the enum. Scanned rather than hand-listed so a new exercise
/// is picked up without a second place to update; the upper bound is generous
/// slack over the current catalogue.
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
        | E::RussianTwist => Dumbbell,

        // ── Machine (pin/plate stacks) ──
        E::MachineChestPress
        | E::PecDeck
        | E::LegPress
        | E::LegExtension
        | E::LegCurl
        | E::HackSquat
        | E::CalfRaise
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

/// The rep target to offer for an exercise you've never done. Heavy barbell
/// compounds default to fives; other compounds to eights; isolation to tens.
pub fn default_reps(ex: Exercise) -> i32 {
    match (category(ex), load_style(ex)) {
        (ExerciseCategory::Compound, LoadStyle::Barbell) => 5,
        (ExerciseCategory::Compound, _) => 8,
        _ => 10,
    }
}

pub fn default_sets(_ex: Exercise) -> i32 {
    3
}

/// The weight to prefill for an exercise with no history. The empty bar for
/// barbell work, a conservative stack/dumbbell otherwise, and nothing at all for
/// bodyweight moves — where a prefilled number would be a lie.
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

/// How much to add after a session where you hit every prescribed set. Sized to
/// the smallest jump the equipment actually allows: a pair of the smallest
/// plates on a bar, one notch on a stack, the next dumbbell up.
pub fn progression_increment_lb(ex: Exercise, unit: AppWeightUnit) -> f32 {
    let in_unit = |lb: f32, kg: f32| match unit {
        AppWeightUnit::Lb => lb,
        AppWeightUnit::Kg => kg_to_pounds(kg),
    };
    match load_style(ex) {
        // Bodyweight work progresses by reps; adding phantom pounds to a push-up
        // would be nonsense.
        LoadStyle::Bodyweight => 0.0,
        LoadStyle::Dumbbell => in_unit(5.0, 2.0),
        _ => in_unit(5.0, 2.5),
    }
}

/// Round a computed weight to something you can load for this exercise: real
/// plate maths for barbells, the equipment's step size for everything else.
pub fn snap_weight_lb(ex: Exercise, weight_lb: f32, unit: AppWeightUnit) -> f32 {
    if weight_lb <= 0.0 {
        return 0.0;
    }
    match load_style(ex) {
        LoadStyle::Barbell => snap_loadable_lb(weight_lb, unit),
        LoadStyle::Bodyweight => weight_lb,
        LoadStyle::Dumbbell => round_to_unit_increment(weight_lb, unit, 5.0, 2.0),
        _ => round_to_unit_increment(weight_lb, unit, 5.0, 2.5),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Every exercise must be classified — a `_ =>` fallback in `load_style`
    /// would quietly file a new barbell lift as bodyweight and stop it
    /// progressing, so the match is exhaustive and this pins the scan that
    /// feeds it.
    #[test]
    fn the_catalogue_covers_every_exercise() {
        let all = all_exercises();
        assert!(all.len() >= 76, "expected the full catalogue, got {}", all.len());
        assert!(all.contains(&Exercise::Squat));
        assert!(all.contains(&Exercise::HipAdduction), "the last enum member");
        assert!(!all.contains(&Exercise::Unspecified));
    }

    #[test]
    fn barbell_work_starts_at_the_empty_bar() {
        assert_eq!(
            starting_weight_lb(Exercise::Squat, AppWeightUnit::Lb),
            45.0
        );
        // 20 kg expressed in pounds — the client converts back for display.
        let kg_bar = starting_weight_lb(Exercise::Squat, AppWeightUnit::Kg);
        assert!((crate::weight_units::pounds_to_kg(kg_bar) - 20.0).abs() < 0.01);
    }

    #[test]
    fn bodyweight_moves_dont_get_a_prefilled_weight_or_an_increment() {
        assert_eq!(starting_weight_lb(Exercise::PushUp, AppWeightUnit::Lb), 0.0);
        assert_eq!(
            progression_increment_lb(Exercise::PullUp, AppWeightUnit::Lb),
            0.0
        );
    }

    #[test]
    fn snapping_keeps_barbell_weights_loadable() {
        // 137 lb isn't loadable on a 45 lb bar; it snaps to a real load.
        let snapped = snap_weight_lb(Exercise::Squat, 137.0, AppWeightUnit::Lb);
        assert_eq!(snapped, snap_loadable_lb(137.0, AppWeightUnit::Lb));
        // Dumbbells come in 5 lb steps.
        assert_eq!(
            snap_weight_lb(Exercise::LateralRaise, 22.0, AppWeightUnit::Lb),
            20.0
        );
    }
}
