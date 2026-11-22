//! The rotation check: what one pass through the rotation trains, what
//! is wrong with it, and what each workout outside it would add.
//!
//! A pass is each rotation workout once. Every lift counts the program's
//! `rotation_check.sets_per_lift` working sets, the same for every week,
//! so the check describes the rotation's shape and not this week's history
//! or time budget; sets are counted the way Home counts the week.

use std::collections::BTreeMap;

use crate::pb::{
    LibraryTemplate, RotationAddition, RotationCheck, RotationWarning, RotationWarningKind,
};
use crate::program::{Muscle, Program, WorkoutDef};
use crate::volume::{primary_muscles, volume_rows};

/// A workout's lifts the program knows, each once.
fn lifts<'a>(program: &Program, workout: &'a WorkoutDef) -> Vec<&'a str> {
    let mut out: Vec<&str> = Vec::new();
    for ex in &workout.exercises {
        if program.knows(ex) && !out.contains(&ex.as_str()) {
            out.push(ex);
        }
    }
    out
}

/// The check over the program's workouts in rotation, in order. The
/// workouts out of rotation, and the [library] entries given (the ones the
/// user does not have), are each an addition when a lift of theirs trains
/// first a muscle the pass trains none of.
pub fn rotation_check(program: &Program, library: &[LibraryTemplate]) -> RotationCheck {
    let rotation: Vec<&WorkoutDef> = program.workouts.iter().filter(|t| t.rotation).collect();
    let per_lift = program.rotation_check.sets_per_lift;

    let mut sets: BTreeMap<Muscle, f32> = BTreeMap::new();
    for workout in &rotation {
        for ex in lifts(program, workout) {
            for (muscle, credit) in program.credit(ex) {
                *sets.entry(muscle).or_insert(0.0) += credit * per_lift;
            }
        }
    }
    let volume = volume_rows(program, &sets);
    let untrained: Vec<Muscle> = Muscle::ALL
        .iter()
        .copied()
        .filter(|m| sets.get(m).copied().unwrap_or(0.0) <= 0.0)
        .collect();

    let added = |exercises: &[String]| -> Vec<i32> {
        let primary = primary_muscles(program, exercises);
        untrained
            .iter()
            .filter(|m| primary.contains(m))
            .map(|m| m.to_proto() as i32)
            .collect()
    };
    let reserves = program
        .workouts
        .iter()
        .filter(|t| !t.rotation)
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
    let additions: Vec<RotationAddition> = reserves
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
            muscles: untrained.iter().map(|m| m.to_proto() as i32).collect(),
            ..Default::default()
        });
    }

    let overlap = program.rotation_check.overlap_fraction;
    for (i, a) in rotation.iter().enumerate() {
        let a_lifts = lifts(program, a);
        for b in &rotation[i + 1..] {
            let b_lifts = lifts(program, b);
            let of = a_lifts.len().min(b_lifts.len());
            let shared = a_lifts.iter().filter(|ex| b_lifts.contains(ex)).count();
            if of > 0 && shared as f32 > overlap * of as f32 {
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
    use crate::pb::MuscleGroup;

    fn template(id: &str, exercises: &[&str]) -> WorkoutDef {
        WorkoutDef {
            id: id.to_string(),
            name: id.to_string(),
            exercises: exercises.iter().map(|e| e.to_string()).collect(),
            rotation: true,
            notes: String::new(),
            from_library: String::new(),
        }
    }

    fn check(templates: &[WorkoutDef], library: &[LibraryTemplate]) -> RotationCheck {
        rotation_check(
            &Program::builtin().with_workouts(templates.to_vec()),
            library,
        )
    }

    /// The check with no library entries offered.
    fn pass(templates: &[WorkoutDef]) -> RotationCheck {
        check(templates, &[])
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
                    "bench_press",
                    "barbell_row",
                    "overhead_press",
                    "barbell_curl",
                    "skull_crusher",
                ],
            ),
            template(
                "lower",
                &[
                    "squat",
                    "romanian_deadlift",
                    "hip_thrust",
                    "calf_raise",
                    "crunch",
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
                &["bench_press", "barbell_row", "squat", "romanian_deadlift"],
            ),
            template(
                "b",
                &[
                    "overhead_press",
                    "pull_up",
                    "deadlift",
                    "barbell_curl",
                    "skull_crusher",
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

    /// A reserve or a library entry adds the muscles its lifts train first
    /// that the pass trains none of, in Home's order; one adding
    /// nothing is not listed, and a lift training a missing muscle only
    /// second adds nothing.
    #[test]
    fn additions_name_the_muscles_the_pass_misses() {
        let mut reserve = template("calves", &["calf_raise", "squat"]);
        reserve.rotation = false;
        let mut covered = template("more", &["bench_press"]);
        covered.rotation = false;
        let library = [
            LibraryTemplate {
                id: "core_and_calves".into(),
                exercises: vec!["crunch".to_string(), "calf_raise".to_string()],
                ..Default::default()
            },
            LibraryTemplate {
                id: "push".into(),
                exercises: vec!["bench_press".to_string()],
                ..Default::default()
            },
        ];
        let rotation = [
            template("a", &["bench_press", "squat"]),
            template("b", &["barbell_row", "romanian_deadlift"]),
            reserve,
            covered,
        ];
        let got: Vec<(String, String, Vec<i32>)> = check(&rotation, &library)
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

        // With nothing in rotation every muscle is missing: a reserve adds
        // all its lifts train first.
        let mut alone = template("legs", &["squat", "calf_raise"]);
        alone.rotation = false;
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
                "squat",
                "bench_press",
                "barbell_row",
                "overhead_press",
                "barbell_curl",
            ],
        );
        let near = template(
            "near",
            &["squat", "bench_press", "barbell_row", "calf_raise"],
        );
        let check = pass(&[big.clone(), near]);
        let overlap = check
            .warnings
            .iter()
            .find(|w| w.kind == RotationWarningKind::Overlap as i32)
            .expect("an overlap");
        assert_eq!(overlap.template_ids, vec!["big", "near"]);
        assert_eq!((overlap.shared, overlap.of), (3, 4));

        let apart = template("apart", &["squat", "bench_press", "calf_raise"]);
        assert!(!kinds(&pass(&[big, apart])).contains(&RotationWarningKind::Overlap));
    }
}
