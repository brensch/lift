//! The rotation check: what one pass through the rotation trains, what
//! is wrong with it, and what each workout outside it would add.
//!
//! A pass is each rotation template once. Every lift counts three working
//! sets, the same for every user and every week, so the check describes
//! the rotation's shape and not this week's history or time budget; sets
//! are counted the way Home counts the week (primary 1.0, secondary 0.5).

use std::collections::HashMap;

use crate::exercise_catalog::{muscles, ALL_MUSCLES};
use crate::pb::{
    Exercise, LibraryTemplate, MuscleGroup, MuscleVolume, RotationAddition, RotationCheck,
    RotationWarning, RotationWarningKind, WorkoutTemplate,
};
use crate::volume::{primary_muscles, VOLUME_TARGET_HIGH, VOLUME_TARGET_LOW};

/// Working sets each lift counts in a pass.
pub const SETS_PER_LIFT: f32 = 3.0;
/// Two templates sharing more than this fraction of the smaller one's
/// lifts overlap.
pub const OVERLAP_FRACTION: f32 = 0.7;

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

/// The check over the templates in rotation, in the order given. The
/// templates out of rotation, and the [library] entries given (the ones the
/// user does not have), are each an addition when a lift of theirs trains
/// first a muscle the pass trains none of.
pub fn rotation_check(templates: &[WorkoutTemplate], library: &[LibraryTemplate]) -> RotationCheck {
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
    let untrained: Vec<MuscleGroup> = ALL_MUSCLES
        .iter()
        .copied()
        .filter(|m| sets.get(m).copied().unwrap_or(0.0) <= 0.0)
        .collect();

    let added = |exercises: &[i32]| -> Vec<i32> {
        let primary = primary_muscles(exercises);
        untrained
            .iter()
            .filter(|m| primary.contains(m))
            .map(|m| *m as i32)
            .collect()
    };
    let backups = templates
        .iter()
        .filter(|t| !t.in_rotation)
        .map(|t| RotationAddition {
            template_id: t.id.clone(),
            muscles: added(&t.exercises),
            ..Default::default()
        });
    let entries = library.iter().map(|e| RotationAddition {
        library_id: e.id.clone(),
        muscles: added(&e.exercises),
        ..Default::default()
    });
    let additions: Vec<RotationAddition> = backups
        .chain(entries)
        .filter(|a| !a.muscles.is_empty())
        .collect();

    let mut warnings = Vec::new();
    if rotation.is_empty() {
        return RotationCheck {
            volume,
            warnings,
            additions,
        };
    }

    if !untrained.is_empty() {
        warnings.push(RotationWarning {
            kind: RotationWarningKind::Gap as i32,
            muscles: untrained.iter().map(|m| *m as i32).collect(),
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

    RotationCheck {
        volume,
        warnings,
        additions,
    }
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

    /// The check with no library entries offered.
    fn pass(templates: &[WorkoutTemplate]) -> RotationCheck {
        rotation_check(templates, &[])
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
        let check = pass(&[
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

    /// Nothing trains calves or core: one gap naming both.
    #[test]
    fn a_gap_names_every_untrained_muscle() {
        let check = pass(&[
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

    /// A backup or a library entry adds the muscles its lifts train first
    /// that the pass trains none of, in Home's order; one adding
    /// nothing is not listed, and a lift training a missing muscle only
    /// second adds nothing.
    #[test]
    fn additions_name_the_muscles_the_pass_misses() {
        let mut backup = template("calves", &[Exercise::CalfRaise, Exercise::Squat]);
        backup.in_rotation = false;
        let mut covered = template("more", &[Exercise::BenchPress]);
        covered.in_rotation = false;
        let library = [
            LibraryTemplate {
                id: "core_and_calves".into(),
                exercises: vec![Exercise::Crunch as i32, Exercise::CalfRaise as i32],
                ..Default::default()
            },
            LibraryTemplate {
                id: "push".into(),
                exercises: vec![Exercise::BenchPress as i32],
                ..Default::default()
            },
        ];
        let rotation = [
            template("a", &[Exercise::BenchPress, Exercise::Squat]),
            template("b", &[Exercise::BarbellRow, Exercise::RomanianDeadlift]),
            backup,
            covered,
        ];
        let got: Vec<(String, String, Vec<i32>)> = rotation_check(&rotation, &library)
            .additions
            .into_iter()
            .map(|a| (a.template_id, a.library_id, a.muscles))
            .collect();
        assert_eq!(
            got,
            vec![
                (
                    "calves".to_string(),
                    String::new(),
                    vec![MuscleGroup::Calves as i32]
                ),
                (
                    String::new(),
                    "core_and_calves".to_string(),
                    vec![MuscleGroup::Calves as i32, MuscleGroup::Core as i32]
                ),
            ]
        );

        // With nothing in rotation every muscle is missing: a backup adds
        // all its lifts train first.
        let mut alone = template("legs", &[Exercise::Squat, Exercise::CalfRaise]);
        alone.in_rotation = false;
        let additions = pass(&[alone]).additions;
        assert_eq!(additions.len(), 1);
        assert_eq!(
            additions[0].muscles,
            vec![MuscleGroup::Quads as i32, MuscleGroup::Calves as i32]
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
        let check = pass(&[big.clone(), near]);
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
        assert!(!kinds(&pass(&[big, apart])).contains(&RotationWarningKind::Overlap));
    }
}
