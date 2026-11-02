//! Starting weights for the main lifts, from the setup slider. Onboarding
//! records them; a lift never done calibrates from 60% of its own.

use crate::exercise_catalog::snap_weight_lb;
use crate::pb::Exercise;
use crate::weight_units::AppWeightUnit;

/// The setup slider's range per lift, in pounds: chick (0) is the bar
/// (a little under for bench), gorilla (1) is truly huge. Linear between,
/// snapped loadable in the user's unit.
pub const STRENGTH_RANGE_LB: [(Exercise, f32, f32); 5] = [
    (Exercise::Squat, 45.0, 315.0),
    (Exercise::BenchPress, 35.0, 225.0),
    (Exercise::BarbellRow, 45.0, 245.0),
    (Exercise::OverheadPress, 45.0, 165.0),
    (Exercise::Deadlift, 45.0, 385.0),
];

/// The main lifts' starting weights at `strength` (0..1 on the slider).
pub fn starting_weights_for_strength(strength: f32, unit: AppWeightUnit) -> Vec<(Exercise, f32)> {
    let s = strength.clamp(0.0, 1.0);
    STRENGTH_RANGE_LB
        .iter()
        .map(|(exercise, lo, hi)| {
            (
                *exercise,
                snap_weight_lb(*exercise, lo + (hi - lo) * s, unit),
            )
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The slider's weights at its middle and both ends.
    #[test]
    fn slider_weights_at_the_marks() {
        let w = starting_weights_for_strength(0.5, AppWeightUnit::Lb);
        let get = |ex: Exercise| w.iter().find(|(e, _)| *e == ex).unwrap().1;
        assert_eq!(get(Exercise::Squat), 180.0);
        assert_eq!(get(Exercise::BenchPress), 130.0);
        assert_eq!(get(Exercise::Deadlift), 215.0);
        assert_eq!(get(Exercise::OverheadPress), 105.0);
        assert_eq!(get(Exercise::BarbellRow), 145.0);
        let chick = starting_weights_for_strength(0.0, AppWeightUnit::Lb);
        let gorilla = starting_weights_for_strength(1.0, AppWeightUnit::Lb);
        let at =
            |v: &Vec<(Exercise, f32)>, ex: Exercise| v.iter().find(|(e, _)| *e == ex).unwrap().1;
        assert_eq!(at(&chick, Exercise::Squat), 45.0);
        assert_eq!(
            at(&chick, Exercise::BenchPress),
            45.0,
            "never under the empty bar"
        );
        assert_eq!(at(&gorilla, Exercise::Squat), 315.0);
        assert_eq!(at(&gorilla, Exercise::BenchPress), 225.0);
        // Kilograms snap to the 2.5 kg grid: 180 lb -> 82.5 kg.
        let kg = starting_weights_for_strength(0.5, AppWeightUnit::Kg);
        let squat_kg = crate::weight_units::pounds_to_kg(at(&kg, Exercise::Squat));
        assert!((squat_kg - 82.5).abs() < 0.01, "{squat_kg}");
    }
}
