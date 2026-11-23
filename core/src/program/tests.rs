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
        errs.iter()
            .any(|e| e.starts_with("exercises[squat].colour")),
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
        "exercises[squat].class",
        "classes.heavy.rep_high",
        "sets.max",
        "equipment.plates.lb[1]",
        "workouts[a].exercises[1]",
        "workouts[a].exercises[2]",
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

mod edits {
    use super::super::edit::{self, EditError};
    use super::*;
    use serde_json::json;

    /// The built-in program with two workouts, as an account would have.
    fn program() -> Program {
        let mut v = default_json();
        v["workouts"] = json!([
            {"id": "a", "name": "A", "exercises": ["squat", "bench_press"], "rotation": true, "notes": "", "from_library": ""},
            {"id": "b", "name": "B", "exercises": ["deadlift"], "rotation": true, "notes": "", "from_library": ""}
        ]);
        serde_json::from_value(v).unwrap()
    }

    fn apply(edits: serde_json::Value) -> Result<Program, EditError> {
        let doc = edit::apply(&program(), edits.as_array().unwrap())?;
        Ok(serde_json::from_value(doc).unwrap())
    }

    fn fails(edits: serde_json::Value) -> EditError {
        edit::apply(&program(), edits.as_array().unwrap()).unwrap_err()
    }

    #[test]
    fn set_reaches_fields_maps_and_named_items() {
        let p = apply(json!([
            {"set": "name", "value": "Size"},
            {"set": "classes.heavy.rest_seconds", "value": 150},
            {"set": "workouts[a].rotation", "value": false},
            {"set": "exercises[squat].progression", "value": "squat_lp"},
            {"set": "progressions.squat_lp", "value": {
                "kind": "linear", "reps": 5, "increment_lb": 5, "deload_after_fails": 3, "deload_factor": 0.9}},
            {"set": "time_off[0].days", "value": 50}
        ]))
        .unwrap();
        assert_eq!(p.name, "Size");
        assert_eq!(p.classes["heavy"].rest_seconds, 150);
        assert!(!p.workout("a").unwrap().rotation);
        assert_eq!(
            p.exercise("squat").unwrap().progression.as_deref(),
            Some("squat_lp")
        );
        assert!(p.progressions.contains_key("squat_lp"));
        assert_eq!(p.time_off[0].days, 50);
        assert_eq!(errors(&check(&p)), Vec::<String>::new());
    }

    /// A new workout or exercise takes its name from the path and its
    /// optional fields from their defaults.
    #[test]
    fn set_adds_a_named_item_with_defaults() {
        let p = apply(json!([
            {"set": "workouts[upper_a]", "value": {"name": "Upper A", "exercises": ["bench_press", "barbell_row"]}},
            {"set": "exercises[zercher_squat]", "value": {
                "name": "Zercher Squat", "equipment": "barbell", "muscles": ["quads", "glutes"], "class": "heavy"}}
        ]))
        .unwrap();
        let w = p.workouts.last().unwrap();
        assert_eq!(
            (w.id.as_str(), w.rotation, w.notes.as_str()),
            ("upper_a", true, "")
        );
        let e = p.exercises.last().unwrap();
        assert_eq!(
            (e.key.as_str(), e.short_name.as_str()),
            ("zercher_squat", "Zercher Squa")
        );
        assert_eq!(errors(&check(&p)), Vec::<String>::new());
    }

    #[test]
    fn remove_and_move() {
        let p = apply(json!([
            {"set": "workouts[c]", "value": {"name": "C", "exercises": ["squat"]}},
            {"move": "workouts[c]", "before": "workouts[a]"},
            {"remove": "workouts[b]"},
            {"remove": "recovery.hours.chest"}
        ]))
        .unwrap();
        let ids: Vec<&str> = p.workouts.iter().map(|w| w.id.as_str()).collect();
        assert_eq!(ids, ["c", "a"]);
        assert!(!p.recovery.hours.contains_key(&Muscle::Chest));
        let p = apply(json!([{"move": "workouts[a]", "before": null}])).unwrap();
        let ids: Vec<&str> = p.workouts.iter().map(|w| w.id.as_str()).collect();
        assert_eq!(ids, ["b", "a"]);
    }

    /// One edit that can't apply stops them all, and says which and why.
    #[test]
    fn a_bad_edit_names_itself() {
        let e = fails(json!([
            {"set": "name", "value": "fine"},
            {"set": "workouts[nope].rotation", "value": false}
        ]));
        assert_eq!((e.index, e.path.as_str()), (1, "workouts[nope].rotation"));
        assert!(e.message.contains("none named \"nope\""), "{}", e.message);
        assert!(fails(json!([{"remove": "exercises[squat]"}]))
            .message
            .contains("built-in"));
        assert!(fails(json!([{"set": "x", "value": 1, "remove": "y"}]))
            .message
            .contains("exactly one"));
        assert!(fails(json!([{"set": "name"}]))
            .message
            .contains("needs a value"));
        assert!(fails(json!([{"set": "time_off[9]", "value": {}}]))
            .message
            .contains("the list has"));
        assert!(fails(json!([{"set": "workouts[a]", "value": {"id": "z"}}]))
            .message
            .contains("rename"));
        assert!(fails(json!([])).message.contains("no edits"));
    }

    /// What an edit gets wrong in the program, not the path, is the
    /// validator's, at the path the edit used.
    #[test]
    fn the_result_is_checked_at_the_edits_paths() {
        let p =
            apply(json!([{"set": "workouts[a].exercises", "value": ["squat", "nope"]}])).unwrap();
        let errs = errors(&check(&p));
        assert!(
            errs.iter()
                .any(|e| e.starts_with("workouts[a].exercises[1]")),
            "{errs:?}"
        );
    }

    /// The built-in exercises leave the assistant's view and come back on
    /// the way in; a changed one stays in view, and wins on the way back.
    #[test]
    fn compact_and_complete_round_trip() {
        let builtin = Program::builtin().exercises.len();
        let (doc, left_out) = edit::compact(&program());
        assert_eq!(left_out, builtin);
        assert_eq!(doc["exercises"], json!([]));
        let back: Program = serde_json::from_value(edit::complete(doc)).unwrap();
        assert_eq!(back, program());

        let changed = apply(json!([
            {"set": "exercises[squat].class", "value": "standard"},
            {"set": "exercises[zercher_squat]", "value": {
                "name": "Zercher Squat", "equipment": "barbell", "muscles": ["quads"], "class": "heavy"}}
        ]))
        .unwrap();
        let (doc, left_out) = edit::compact(&changed);
        assert_eq!(left_out, builtin - 1);
        let keys: Vec<&str> = doc["exercises"]
            .as_array()
            .unwrap()
            .iter()
            .map(|e| e["key"].as_str().unwrap())
            .collect();
        assert_eq!(keys, ["squat", "zercher_squat"]);
        let back: Program = serde_json::from_value(edit::complete(doc)).unwrap();
        assert_eq!(back, changed);
        assert!(
            doc_size(&edit::compact(&program()).0) * 4
                < doc_size(&serde_json::to_value(program()).unwrap())
        );
    }

    fn doc_size(v: &serde_json::Value) -> usize {
        v.to_string().len()
    }

    /// The guide's editing example is real: it applies to a program with
    /// workouts `a` and `b`, and the result checks out.
    #[test]
    fn the_guides_editing_example_applies() {
        let section = &GUIDE[GUIDE.find("## Editing").unwrap()..];
        let block = &section[section.find("```json").unwrap() + 7..];
        let example: serde_json::Value =
            serde_json::from_str(&block[..block.find("```").unwrap()]).unwrap();
        let p = apply(example).unwrap();
        assert_eq!(errors(&check(&p)), Vec::<String>::new());
        let ids: Vec<&str> = p.workouts.iter().map(|w| w.id.as_str()).collect();
        assert_eq!(ids, ["upper_a", "a"]);
    }

    #[test]
    fn part_reads_one_path() {
        assert_eq!(
            edit::part(&program(), "workouts[b].exercises").unwrap(),
            json!(["deadlift"])
        );
        assert!(edit::part(&program(), "classes.nope").is_err());
    }
}

/// One rule, several lifts: a lift's `params` set its own values for the
/// rule's numbers, and are checked against the rule it follows.
mod params {
    use super::*;
    use serde_json::json;

    fn with(edits: serde_json::Value) -> serde_json::Value {
        let mut v = default_json();
        v["progressions"]["steps"] = json!({
            "kind": "formula", "let": { "jump_lb": "5" }, "sets": "3", "reps": "8",
            "weight": "if(has_last and last.hit, last.weight + jump_lb, if(has_last, last.weight, start))",
            "rest_seconds": null, "note": "A step a session." });
        v["progressions"]["lp"] = json!({
            "kind": "linear", "sets": 3, "reps": 5, "increment_lb": 5,
            "deload_after_fails": 3, "deload_factor": 0.9 });
        for (key, value) in edits.as_object().unwrap() {
            let e = v["exercises"]
                .as_array_mut()
                .unwrap()
                .iter_mut()
                .find(|e| e["key"] == key.as_str())
                .unwrap();
            for (field, x) in value.as_object().unwrap() {
                e[field] = x.clone();
            }
        }
        v
    }

    #[test]
    fn a_lift_tunes_the_rule_it_follows() {
        let v = with(json!({
            "squat": { "progression": "steps", "params": { "jump_lb": 10 } },
            "bench_press": { "progression": "steps" },
            "deadlift": { "progression": "lp", "params": { "increment_lb": 10, "reps": 3 } }
        }));
        let (program, problems) = validate(&v.to_string());
        assert_eq!(errors(&problems), Vec::<String>::new());
        let p = program.unwrap();
        let Progression::Formula(squat) = &*p.progression_of("squat") else {
            panic!()
        };
        let Progression::Formula(bench) = &*p.progression_of("bench_press") else {
            panic!()
        };
        assert_eq!(
            (
                squat.lets["jump_lb"].as_str(),
                bench.lets["jump_lb"].as_str()
            ),
            ("10", "5")
        );
        assert!(matches!(
            &*p.progression_of("deadlift"),
            Progression::Linear { increment_lb, reps: 3, .. } if *increment_lb == 10.0
        ));
        // The shared rule itself is untouched.
        assert!(matches!(
            &p.progressions["lp"],
            Progression::Linear { reps: 5, .. }
        ));
    }

    #[test]
    fn params_that_dont_fit_are_named() {
        let cases = [
            (
                json!({ "squat": { "progression": "steps", "params": { "jmp": 10 } } }),
                "exercises[squat].params.jmp",
                "no `let` named",
            ),
            (
                json!({ "squat": { "progression": "lp", "params": { "reps": 2.5 } } }),
                "exercises[squat].params.reps",
                "whole number",
            ),
            (
                json!({ "squat": { "progression": "lp", "params": { "increment_lb": 500 } } }),
                "exercises[squat].params.increment_lb",
                "outside",
            ),
            (
                json!({ "squat": { "progression": "lp", "params": { "note": 1 } } }),
                "exercises[squat].params.note",
                "has no",
            ),
            (
                json!({ "squat": { "params": { "jump_lb": 1 } } }),
                "exercises[squat].params.jump_lb",
                "no numbers",
            ),
        ];
        for (edit, path, says) in cases {
            let errs = errors(&problems_of(&with(edit)));
            assert!(
                errs.iter().any(|e| e.starts_with(path) && e.contains(says)),
                "{path}: {errs:?}"
            );
        }
    }

    /// A formula a lift tunes is tried on the sample histories like any
    /// other: a step that makes it give nonsense is caught.
    #[test]
    fn a_tuned_formula_is_tried_on_the_samples() {
        let v =
            with(json!({ "squat": { "progression": "steps", "params": { "jump_lb": -5000 } } }));
        let errs = errors(&problems_of(&v));
        assert!(
            errs.iter()
                .any(|e| e.starts_with("exercises[squat].params")),
            "{errs:?}"
        );
    }

    /// A program from before params reads as it did.
    #[test]
    fn stored_programs_without_params_read() {
        let p = Program::parse(DEFAULT_JSON).unwrap();
        assert!(p.exercises.iter().all(|e| e.params.is_empty()));
    }
}
