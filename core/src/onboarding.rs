//! Starting weights for the main lifts, from the setup slider. Onboarding
//! records them; a lift never done calibrates from a fraction of its own
//! (`calibration.start_fraction`).

use crate::program::Program;
use crate::weight_units::AppWeightUnit;

/// The setup slider's range per lift, in pounds: chick (0) is the bar
/// (a little under for bench), gorilla (1) is truly huge. Linear between,
/// snapped loadable in the user's unit.
pub const STRENGTH_RANGE_LB: [(&str, f32, f32); 5] = [
    ("squat", 45.0, 315.0),
    ("bench_press", 35.0, 225.0),
    ("barbell_row", 45.0, 245.0),
    ("overhead_press", 45.0, 165.0),
    ("deadlift", 45.0, 385.0),
];

/// The main lifts' starting weights at `strength` (0..1 on the slider),
/// for those of them the program has.
pub fn starting_weights_for_strength(
    program: &Program,
    strength: f32,
    unit: AppWeightUnit,
) -> Vec<(String, f32)> {
    let s = strength.clamp(0.0, 1.0);
    STRENGTH_RANGE_LB
        .iter()
        .filter(|(exercise, _, _)| program.knows(exercise))
        .map(|(exercise, lo, hi)| {
            (
                exercise.to_string(),
                program.snap_lb(exercise, lo + (hi - lo) * s, unit),
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
        let p = Program::builtin();
        let at = |v: &Vec<(String, f32)>, ex: &str| v.iter().find(|(e, _)| e == ex).unwrap().1;
        let w = starting_weights_for_strength(&p, 0.5, AppWeightUnit::Lb);
        assert_eq!(at(&w, "squat"), 180.0);
        assert_eq!(at(&w, "bench_press"), 130.0);
        assert_eq!(at(&w, "deadlift"), 215.0);
        assert_eq!(at(&w, "overhead_press"), 105.0);
        assert_eq!(at(&w, "barbell_row"), 145.0);
        let chick = starting_weights_for_strength(&p, 0.0, AppWeightUnit::Lb);
        let gorilla = starting_weights_for_strength(&p, 1.0, AppWeightUnit::Lb);
        assert_eq!(at(&chick, "squat"), 45.0);
        assert_eq!(at(&chick, "bench_press"), 45.0, "never under the empty bar");
        assert_eq!(at(&gorilla, "squat"), 315.0);
        assert_eq!(at(&gorilla, "bench_press"), 225.0);
        // Kilograms snap to the 2.5 kg grid: 180 lb -> 82.5 kg.
        let kg = starting_weights_for_strength(&p, 0.5, AppWeightUnit::Kg);
        let squat_kg = crate::weight_units::pounds_to_kg(at(&kg, "squat"));
        assert!((squat_kg - 82.5).abs() < 0.01, "{squat_kg}");
    }
}
