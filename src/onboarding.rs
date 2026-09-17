//! Starting weights for the main lifts, from bodyweight and experience.
//! Seeds the trackers at onboarding; the catalog opener covers a user who
//! skips the questions.

use crate::exercise_catalog::{snap_weight_lb, starting_weight_lb};
use crate::weight_units::{kg_to_pounds, AppWeightUnit};
use schlift::workout::v1::{Exercise, ExperienceLevel, Gender};

fn experience_multiplier(level: ExperienceLevel) -> f32 {
    match level {
        ExperienceLevel::Cute => 0.40,
        ExperienceLevel::Beginner => 0.85,
        ExperienceLevel::Expert => 1.15,
        // Intermediate (and unspecified) is the baseline.
        _ => 1.0,
    }
}

/// Relative-to-bodyweight strength differs by sex, more in the upper body
/// than the lower — population strength-standard tables put women at
/// roughly 60% of men's upper-body lifts and 75% of lower-body lifts at
/// the same bodyweight. Unspecified splits the difference, so skipping
/// the question never seeds a barbell someone can't lift.
fn gender_multiplier(gender: Gender, ex: Exercise) -> f32 {
    let upper = matches!(
        ex,
        Exercise::BenchPress | Exercise::OverheadPress | Exercise::BarbellRow
    );
    match gender {
        Gender::Male => 1.0,
        Gender::Female => {
            if upper {
                0.60
            } else {
                0.75
            }
        }
        _ => {
            if upper {
                0.80
            } else {
                0.88
            }
        }
    }
}

/// (exercise, fraction of bodyweight) for a sane first working weight.
const RATIOS: [(Exercise, f32); 5] = [
    (Exercise::Squat, 0.95),
    (Exercise::BenchPress, 0.70),
    (Exercise::BarbellRow, 0.75),
    (Exercise::OverheadPress, 0.50),
    (Exercise::Deadlift, 1.15),
];

/// Tracker seeds for the main lifts, in pounds, snapped loadable in the
/// user's unit. With no bodyweight (skipped), each lift opens at the
/// catalog default — the empty bar.
pub fn starting_tracker_weights(
    bodyweight_kg: f32,
    experience: ExperienceLevel,
    gender: Gender,
    unit: AppWeightUnit,
) -> Vec<(Exercise, f32)> {
    let multiplier = experience_multiplier(experience);
    RATIOS
        .iter()
        .map(|(exercise, ratio)| {
            let weight = if bodyweight_kg > 0.0 {
                let raw = kg_to_pounds(bodyweight_kg)
                    * ratio
                    * multiplier
                    * gender_multiplier(gender, *exercise);
                // Never below the empty bar — these are barbell lifts.
                snap_weight_lb(*exercise, raw, unit)
                    .max(starting_weight_lb(*exercise, unit))
            } else {
                starting_weight_lb(*exercise, unit)
            };
            (*exercise, weight)
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn scales_by_bodyweight_and_experience() {
        // 100 kg lifter, intermediate: squat ≈ bodyweight × 0.95, loadable.
        let weights = starting_tracker_weights(
            100.0,
            ExperienceLevel::Intermediate,
            Gender::Male,
            AppWeightUnit::Lb,
        );
        let squat = weights
            .iter()
            .find(|(ex, _)| *ex == Exercise::Squat)
            .unwrap()
            .1;
        let raw = kg_to_pounds(100.0) * 0.95;
        assert!((squat - raw).abs() <= 5.0, "snapped near the ratio: {squat}");

        let cute = starting_tracker_weights(
            100.0,
            ExperienceLevel::Cute,
            Gender::Male,
            AppWeightUnit::Lb,
        );
        let cute_squat = cute
            .iter()
            .find(|(ex, _)| *ex == Exercise::Squat)
            .unwrap()
            .1;
        assert!(cute_squat < squat, "a new lifter starts lighter");
    }

    #[test]
    fn skipping_bodyweight_opens_at_the_bar() {
        let weights = starting_tracker_weights(
            0.0,
            ExperienceLevel::Unspecified,
            Gender::Unspecified,
            AppWeightUnit::Lb,
        );
        assert!(weights.iter().all(|(_, w)| *w == 45.0));
        assert_eq!(weights.len(), 5);
    }

    #[test]
    fn gender_scales_upper_body_harder_than_lower() {
        let female = starting_tracker_weights(
            80.0,
            ExperienceLevel::Intermediate,
            Gender::Female,
            AppWeightUnit::Lb,
        );
        let male = starting_tracker_weights(
            80.0,
            ExperienceLevel::Intermediate,
            Gender::Male,
            AppWeightUnit::Lb,
        );
        let get = |list: &[(Exercise, f32)], ex: Exercise| {
            list.iter().find(|(e, _)| *e == ex).unwrap().1
        };
        assert!(get(&female, Exercise::BenchPress) < get(&male, Exercise::BenchPress));
        assert!(get(&female, Exercise::Squat) < get(&male, Exercise::Squat));
        // Upper body scales down further than lower body.
        let bench_ratio =
            get(&female, Exercise::BenchPress) / get(&male, Exercise::BenchPress);
        let squat_ratio = get(&female, Exercise::Squat) / get(&male, Exercise::Squat);
        assert!(bench_ratio < squat_ratio);
    }

    #[test]
    fn a_light_lifter_never_seeds_below_the_bar() {
        // 40 kg × 0.5 OHP ratio × 0.4 cute ≈ 17.6 lb — below the bar.
        let weights = starting_tracker_weights(
            40.0,
            ExperienceLevel::Cute,
            Gender::Female,
            AppWeightUnit::Lb,
        );
        assert!(weights.iter().all(|(_, w)| *w >= 45.0));
    }
}
