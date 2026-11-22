use super::*;

fn default_json() -> serde_json::Value {
    serde_json::from_str(DEFAULT_JSON).unwrap()
}

fn problems_of(value: &serde_json::Value) -> Vec<Problem> {
    validate(&value.to_string()).1
}

fn errors(problems: &[Problem]) -> Vec<String> {
    problems
        .iter()
        .filter(|p| p.error)
        .map(|p| format!("{}: {}", p.path, p.message))
        .collect()
}

/// The built-in program is a program like any other: it reads, checks out
/// with no error, and writes back as it reads.
#[test]
fn the_builtin_program_is_valid_and_round_trips() {
    let (program, problems) = validate(DEFAULT_JSON);
    assert_eq!(errors(&problems), Vec::<String>::new());
    let program = program.unwrap();
    assert_eq!(program, *Program::builtin());
    let again = Program::parse(&program.to_json()).unwrap();
    assert_eq!(again, program);
    assert!(program.exercises.len() >= 76);
    assert!(program.workouts.is_empty(), "onboarding gives the workouts");
}

/// A field the program doesn't have is named, not dropped silently.
#[test]
fn an_unknown_field_is_an_error() {
    let mut v = default_json();
    v["volume"]["target_lo"] = 8.into();
    v["exercises"][0]["colour"] = "red".into();
    let errs = errors(&problems_of(&v));
    assert!(
        errs.iter().any(|e| e.starts_with("volume.target_lo")),
        "{errs:?}"
    );
    assert!(
        errs.iter().any(|e| e.starts_with("exercises[0].colour")),
        "{errs:?}"
    );
}

#[test]
fn names_resolve_and_numbers_are_in_range() {
    let mut v = default_json();
    v["exercises"][0]["class"] = "nope".into();
    v["classes"]["heavy"]["rep_high"] = 2.into();
    v["sets"]["max"] = 1.into();
    v["equipment"]["plates"]["lb"] = serde_json::json!([45.0, 45.0]);
    v["workouts"] = serde_json::json!([
        {"id": "a", "name": "A", "exercises": ["squat", "squat", "nope"], "rotation": true, "notes": "", "from_library": ""}
    ]);
    let errs = errors(&problems_of(&v));
    for path in [
        "exercises[0].class",
        "classes.heavy.rep_high",
        "sets.max",
        "equipment.plates.lb[1]",
        "workouts[0].exercises[1]",
        "workouts[0].exercises[2]",
    ] {
        assert!(errs.iter().any(|e| e.starts_with(path)), "{path}: {errs:?}");
    }
}

/// A custom exercise is just another entry: a new key, its muscles and
/// how it loads.
#[test]
fn a_custom_exercise_checks_out() {
    let mut v = default_json();
    v["exercises"]
        .as_array_mut()
        .unwrap()
        .push(serde_json::json!({
            "key": "zercher_squat", "name": "Zercher Squat", "short_name": "Zercher",
            "equipment": "barbell", "muscles": ["quads", "glutes", "core"],
            "class": "heavy", "progression": null,
            "description": "The bar in the crooks of the elbows."
        }));
    assert_eq!(errors(&problems_of(&v)), Vec::<String>::new());
    let mut dup = v.clone();
    dup["exercises"][0]["key"] = "zercher_squat".into();
    assert!(errors(&problems_of(&dup))
        .iter()
        .any(|e| e.contains("named twice")));
    let mut bad = v.clone();
    bad["exercises"][0]["key"] = "Zercher Squat".into();
    assert!(errors(&problems_of(&bad))
        .iter()
        .any(|e| e.starts_with("exercises[0].key")));
}

/// A formula is parsed, its names checked and its results tried on a
/// spread of histories before it is accepted.
#[test]
fn formulas_are_checked_before_they_are_set() {
    let with = |reps: &str, weight: &str| {
        let mut v = default_json();
        v["progressions"]["mine"] = serde_json::json!({
            "kind": "formula", "let": {"top": "10"}, "sets": null,
            "reps": reps, "weight": weight, "rest_seconds": null, "note": ""
        });
        errors(&problems_of(&v))
    };
    assert_eq!(
        with("min(last.reps + 1, top)", "last.weight"),
        Vec::<String>::new()
    );
    let errs = with("last.repz + 1", "last.weight");
    assert!(
        errs.iter().any(|e| e.contains("no variable last.repz")),
        "{errs:?}"
    );
    let errs = with("5", "last.weight / last.reps");
    assert!(errs.iter().any(|e| e.contains("never done")), "{errs:?}");
    let errs = with("last.reps - 20", "last.weight");
    assert!(errs.iter().any(|e| e.contains("outside")), "{errs:?}");
    let errs = with("5 +", "last.weight");
    assert!(
        errs.iter().any(|e| e.starts_with("progressions.mine.reps")),
        "{errs:?}"
    );
}

/// An exercise the account has history for must stay.
#[test]
fn a_program_keeps_what_the_account_used() {
    let p = Program::builtin();
    let used: std::collections::BTreeSet<String> =
        ["squat".to_string(), "zercher_squat".to_string()].into();
    let problems = validate_for_account(&p, &used);
    assert_eq!(problems.len(), 1);
    assert!(problems[0].message.contains("zercher_squat"));
}

/// The guide describes the document: every field, kind, variable and
/// function is in it, so an assistant reading it can write any of them.
#[test]
fn the_guide_covers_the_document() {
    let v = default_json();
    let mut missing = Vec::new();
    for key in v.as_object().unwrap().keys() {
        if !GUIDE.contains(&format!("`{key}`")) {
            missing.push(key.clone());
        }
    }
    for kind in [
        "estimated_max",
        "fixed",
        "linear",
        "double",
        "cycle",
        "formula",
    ] {
        if !GUIDE.contains(&format!("`{kind}`")) {
            missing.push(kind.to_string());
        }
    }
    for (name, _) in formula::VARIABLES {
        if !GUIDE.contains(&format!("`{name}`")) {
            missing.push(name.to_string());
        }
    }
    for (name, _, _) in formula::FUNCTIONS {
        if !GUIDE.contains(&format!("`{name}(")) {
            missing.push(format!("{name}("));
        }
    }
    for section in [
        "estimate",
        "sets",
        "costs",
        "warmups",
        "calibration",
        "volume",
        "recovery",
        "rotation_check",
        "equipment",
    ] {
        for field in v[section].as_object().unwrap().keys() {
            if !GUIDE.contains(&format!("`{field}`")) {
                missing.push(format!("{section}.{field}"));
            }
        }
    }
    assert!(missing.is_empty(), "the guide doesn't mention {missing:?}");
}
