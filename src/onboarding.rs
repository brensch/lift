use crate::weight_units::kg_to_pounds;
use schlift::workout::v1::{ExperienceLevel, RecommendedWeight};

fn experience_multiplier(level: ExperienceLevel) -> f32 {
    match level {
        ExperienceLevel::Cute => 0.40,
        ExperienceLevel::Beginner => 0.85,
        ExperienceLevel::Expert => 1.15,
        // Intermediate (and unspecified) is the baseline.
        _ => 1.0,
    }
}

/// (program-state field key, fraction of bodyweight). Single source of truth for
/// the onboarding recommendation the app used to compute client-side.
const RATIOS: &[(&str, f32)] = &[
    ("squat_weight", 0.95),
    ("squat_t1_weight", 0.95),
    ("bench_press_weight", 0.70),
    ("bench_press_t2_weight", 0.70),
    ("barbell_row_weight", 0.75),
    ("barbell_row_t2_weight", 0.75),
    ("overhead_press_weight", 0.50),
    ("overhead_press_t2_weight", 0.50),
    ("deadlift_weight", 1.15),
    ("deadlift_t1_weight", 1.15),
    ("squat_tm", 1.10),
    ("bench_press_tm", 0.80),
    ("deadlift_tm", 1.35),
    ("overhead_press_tm", 0.55),
];

/// Recommended starting weight (lb, unclamped) for every known program field,
/// given bodyweight and experience. The client clamps to each field's schema
/// range and snaps for display.
pub fn recommended_starting_weights(
    bodyweight_kg: f32,
    experience: ExperienceLevel,
) -> Vec<RecommendedWeight> {
    let bw_lb = kg_to_pounds(bodyweight_kg);
    let mult = experience_multiplier(experience);
    RATIOS
        .iter()
        .map(|(key, ratio)| RecommendedWeight {
            field_key: key.to_string(),
            pounds: bw_lb * ratio * mult,
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn scales_by_bodyweight_and_experience() {
        // 100 kg = 220.46 lb. Squat ratio 0.95, intermediate mult 1.0.
        let w = recommended_starting_weights(100.0, ExperienceLevel::Intermediate);
        let squat = w.iter().find(|r| r.field_key == "squat_weight").unwrap();
        assert!((squat.pounds - kg_to_pounds(100.0) * 0.95).abs() < 0.01);
        // Cute lifter gets 40%.
        let cute = recommended_starting_weights(100.0, ExperienceLevel::Cute);
        let squat_cute = cute.iter().find(|r| r.field_key == "squat_weight").unwrap();
        assert!((squat_cute.pounds - squat.pounds * 0.40).abs() < 0.01);
    }
}
