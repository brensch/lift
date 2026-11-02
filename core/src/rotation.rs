//! The rotation check: what one pass through the rotation trains, and
//! what is wrong with it.
//!
//! A pass is each rotation template once. Every lift counts three working
//! sets, the same for every user and every week, so the check describes
//! the rotation's shape and not this week's history or time budget; sets
//! are counted the way Home counts the week (primary 1.0, secondary 0.5).

use std::collections::HashMap;

use crate::exercise_catalog::{muscles, ALL_MUSCLES};
use crate::pb::{
    Exercise, MuscleGroup, MuscleVolume, RotationCheck, RotationWarning, RotationWarningKind,
    WorkoutTemplate,
};
use crate::volume::{VOLUME_TARGET_HIGH, VOLUME_TARGET_LOW};

/// Working sets each lift counts in a pass.
pub const SETS_PER_LIFT: f32 = 3.0;
/// Two templates sharing more than this fraction of the smaller one's
/// lifts overlap.
pub const OVERLAP_FRACTION: f32 = 0.7;
/// The most-trained muscle at this many times the least-trained trained
/// one is lopsided.
pub const LOPSIDED_RATIO: f32 = 3.0;
/// Fewer templates than this in rotation is too few to rotate.
pub const MIN_ROTATION: usize = 2;

const SECONDARY_WEIGHT: f32 = 0.5;

/// A template's valid lifts, each once.
fn lifts(template: &WorkoutTemplate) -> Vec<Exercise> {
    let mut out = Vec::new();
    for ex in template
        .exercises
        .iter()
        .filter_map(|e| Exercise::try_from(*e).ok())
    {
        if ex != Exercise::Unspecified && !out.contains(&ex) {
            out.push(ex);
        }
    }
    out
}

/// The check over the templates in rotation (the rest are ignored), in
/// the order given.
pub fn rotation_check(templates: &[WorkoutTemplate]) -> RotationCheck {
    let rotation: Vec<&WorkoutTemplate> = templates.iter().filter(|t| t.in_rotation).collect();

    let mut sets: HashMap<MuscleGroup, f32> = HashMap::new();
    for template in &rotation {
        for ex in lifts(template) {
            for (idx, muscle) in muscles(ex).iter().enumerate() {
                let credit = if idx == 0 { 1.0 } else { SECONDARY_WEIGHT };
                *sets.entry(*muscle).or_insert(0.0) += credit * SETS_PER_LIFT;
            }
        }
    }
    let volume: Vec<MuscleVolume> = ALL_MUSCLES
        .iter()
        .map(|muscle| MuscleVolume {
            muscle: *muscle as i32,
            completed_sets_7d: sets.get(muscle).copied().unwrap_or(0.0),
            target_low: VOLUME_TARGET_LOW,
            target_high: VOLUME_TARGET_HIGH,
        })
        .collect();

    let mut warnings = Vec::new();
    if rotation.len() < MIN_ROTATION {
        warnings.push(RotationWarning {
            kind: RotationWarningKind::TooFew as i32,
            ..Default::default()
        });
    }
    if rotation.is_empty() {
        return RotationCheck { volume, warnings };
    }

    let untrained: Vec<i32> = volume
        .iter()
        .filter(|v| v.completed_sets_7d <= 0.0)
        .map(|v| v.muscle)
        .collect();
    if !untrained.is_empty() {
        warnings.push(RotationWarning {
            kind: RotationWarningKind::Gap as i32,
            muscles: untrained,
            ..Default::default()
        });
    }

    for (i, a) in rotation.iter().enumerate() {
        let a_lifts = lifts(a);
        for b in &rotation[i + 1..] {
            let b_lifts = lifts(b);
            let of = a_lifts.len().min(b_lifts.len());
            let shared = a_lifts.iter().filter(|ex| b_lifts.contains(ex)).count();
            if of > 0 && shared as f32 > OVERLAP_FRACTION * of as f32 {
                warnings.push(RotationWarning {
                    kind: RotationWarningKind::Overlap as i32,
                    template_ids: vec![a.id.clone(), b.id.clone()],
                    shared: shared as i32,
                    of: of as i32,
                    ..Default::default()
                });
            }
        }
    }

    // ALL_MUSCLES order breaks ties: the first most-trained, the first
    // least-trained.
    let trained: Vec<&MuscleVolume> = volume
        .iter()
        .filter(|v| v.completed_sets_7d > 0.0)
        .collect();
    let most = trained.iter().copied().reduce(|a, b| {
        if b.completed_sets_7d > a.completed_sets_7d {
            b
        } else {
            a
        }
    });
    let least = trained.iter().copied().reduce(|a, b| {
        if b.completed_sets_7d < a.completed_sets_7d {
            b
        } else {
            a
        }
    });
    if let (Some(most), Some(least)) = (most, least) {
        if most.completed_sets_7d >= LOPSIDED_RATIO * least.completed_sets_7d {
            warnings.push(RotationWarning {
                kind: RotationWarningKind::Lopsided as i32,
                muscles: vec![most.muscle, least.muscle],
                ..Default::default()
            });
        }
    }

    RotationCheck { volume, warnings }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn template(id: &str, exercises: &[Exercise]) -> WorkoutTemplate {
        WorkoutTemplate {
            id: id.to_string(),
            name: id.to_string(),
            exercises: exercises.iter().map(|e| *e as i32).collect(),
            in_rotation: true,
            ..Default::default()
        }
    }

    fn kinds(check: &RotationCheck) -> Vec<RotationWarningKind> {
        check
            .warnings
            .iter()
            .map(|w| RotationWarningKind::try_from(w.kind).unwrap())
            .collect()
    }

    fn sets(check: &RotationCheck, muscle: MuscleGroup) -> f32 {
        check
            .volume
            .iter()
            .find(|v| v.muscle == muscle as i32)
            .unwrap()
            .completed_sets_7d
    }

    /// Upper/lower covering everything evenly enough: no warnings, and
    /// sets per lift are three, half for a secondary.
    #[test]
    fn a_sound_rotation_has_no_warnings() {
        let check = rotation_check(&[
            template(
                "upper",
                &[
                    Exercise::BenchPress,
                    Exercise::BarbellRow,
                    Exercise::OverheadPress,
                    Exercise::BarbellCurl,
                    Exercise::SkullCrusher,
                ],
            ),
            template(
                "lower",
                &[
                    Exercise::Squat,
                    Exercise::RomanianDeadlift,
                    Exercise::HipThrust,
                    Exercise::CalfRaise,
                    Exercise::Crunch,
                ],
            ),
        ]);
        assert_eq!(kinds(&check), vec![], "{:?}", check.volume);
        assert_eq!(check.volume.len(), 10);
        // Bench (primary) 3; row's secondary 1.5 + curl 3.
        assert_eq!(sets(&check, MuscleGroup::Chest), 3.0);
        assert_eq!(sets(&check, MuscleGroup::Biceps), 4.5);
    }

    #[test]
    fn too_few_templates() {
        let one = template("legs", &[Exercise::Squat]);
        assert!(kinds(&rotation_check(std::slice::from_ref(&one)))
            .contains(&RotationWarningKind::TooFew));
        let none = rotation_check(&[]);
        assert_eq!(kinds(&none), vec![RotationWarningKind::TooFew]);
        // Favourites do not count.
        let mut favourite = template("arms", &[Exercise::BarbellCurl]);
        favourite.in_rotation = false;
        assert!(kinds(&rotation_check(&[one, favourite])).contains(&RotationWarningKind::TooFew));
    }

    /// Nothing trains calves or core: one gap naming both.
    #[test]
    fn a_gap_names_every_untrained_muscle() {
        let check = rotation_check(&[
            template(
                "a",
                &[
                    Exercise::BenchPress,
                    Exercise::BarbellRow,
                    Exercise::Squat,
                    Exercise::RomanianDeadlift,
                ],
            ),
            template(
                "b",
                &[
                    Exercise::OverheadPress,
                    Exercise::PullUp,
                    Exercise::Deadlift,
                    Exercise::BarbellCurl,
                    Exercise::SkullCrusher,
                ],
            ),
        ]);
        let gap = check
            .warnings
            .iter()
            .find(|w| w.kind == RotationWarningKind::Gap as i32)
            .expect("a gap");
        assert_eq!(
            gap.muscles,
            vec![MuscleGroup::Calves as i32, MuscleGroup::Core as i32]
        );
    }

    /// Overlap is over 70% of the smaller template's lifts: 3 of 4 is,
    /// 2 of 3 is not.
    #[test]
    fn overlap_is_measured_against_the_smaller_template() {
        let big = template(
            "big",
            &[
                Exercise::Squat,
                Exercise::BenchPress,
                Exercise::BarbellRow,
                Exercise::OverheadPress,
                Exercise::BarbellCurl,
            ],
        );
        let near = template(
            "near",
            &[
                Exercise::Squat,
                Exercise::BenchPress,
                Exercise::BarbellRow,
                Exercise::CalfRaise,
            ],
        );
        let check = rotation_check(&[big.clone(), near]);
        let overlap = check
            .warnings
            .iter()
            .find(|w| w.kind == RotationWarningKind::Overlap as i32)
            .expect("an overlap");
        assert_eq!(overlap.template_ids, vec!["big", "near"]);
        assert_eq!((overlap.shared, overlap.of), (3, 4));

        let apart = template(
            "apart",
            &[Exercise::Squat, Exercise::BenchPress, Exercise::CalfRaise],
        );
        assert!(!kinds(&rotation_check(&[big, apart])).contains(&RotationWarningKind::Overlap));
    }

    /// Quads three times over against triceps from a secondary only.
    #[test]
    fn lopsided_names_the_most_and_least_trained() {
        let check = rotation_check(&[
            template("a", &[Exercise::Squat, Exercise::LegPress]),
            template("b", &[Exercise::LegExtension, Exercise::BenchPress]),
        ]);
        let lopsided = check
            .warnings
            .iter()
            .find(|w| w.kind == RotationWarningKind::Lopsided as i32)
            .expect("lopsided");
        // Quads 9; triceps and shoulders 1.5 (bench's secondaries).
        assert_eq!(
            lopsided.muscles,
            vec![MuscleGroup::Quads as i32, MuscleGroup::Shoulders as i32]
        );
    }
}
