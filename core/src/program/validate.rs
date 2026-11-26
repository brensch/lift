//! Checking a program before it is set: its shape (every field there, no
//! field it doesn't have), every number in range, every name resolving,
//! every formula parsing and giving a sane answer on a spread of
//! histories. Each problem names where it is (`progressions.squat_lp.reps`).
//! A program with an error is refused; warnings are only said.

use std::collections::{BTreeMap, BTreeSet};

use serde_json::Value;

use super::formula::{self, Evaluator, Scope, VARIABLES};
use super::*;

#[derive(Clone, Debug, PartialEq)]
pub struct Problem {
    pub path: String,
    pub message: String,
    pub error: bool,
}

impl Problem {
    fn error(path: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            path: path.into(),
            message: message.into(),
            error: true,
        }
    }

    fn warning(path: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            path: path.into(),
            message: message.into(),
            error: false,
        }
    }
}

/// The most a program holds: past these it is not a program anyone
/// trains from, and folding it on every device would cost.
pub const MAX_EXERCISES: usize = 500;
pub const MAX_WORKOUTS: usize = 100;
pub const MAX_PROGRESSIONS: usize = 200;
pub const MAX_JSON_BYTES: usize = 512 * 1024;

/// A draft as JSON: parsed, then checked. The program comes back when it
/// parsed, whatever else is wrong with it.
pub fn validate(json: &str) -> (Option<Program>, Vec<Problem>) {
    if json.len() > MAX_JSON_BYTES {
        return (
            None,
            vec![Problem::error(
                "",
                format!("over {} KB", MAX_JSON_BYTES / 1024),
            )],
        );
    }
    let value: Value = match serde_json::from_str(json) {
        Ok(v) => v,
        Err(e) => return (None, vec![Problem::error("", format!("not JSON: {e}"))]),
    };
    let program: Program = match serde_json::from_value(value.clone()) {
        Ok(p) => p,
        Err(e) => return (None, vec![Problem::error("", e.to_string())]),
    };
    let mut problems = Vec::new();
    let written = serde_json::to_value(&program).expect("a program serialises");
    unknown_fields(&value, &written, "", &mut problems);
    problems.extend(check(&program));
    name_paths(&program, &mut problems);
    (Some(program), problems)
}

/// Exercises and workouts named in a path by key and id, not position:
/// `exercises[zercher_squat].class`, `workouts[upper_a].exercises`, the
/// paths an assistant's edits use, so a problem points at the edit that
/// fixes it. A position stays where the key or id is missing, malformed or
/// used twice, since then it is the only way to say which one.
pub fn name_paths(p: &Program, problems: &mut [Problem]) {
    let names = |list: &str| -> Vec<Option<String>> {
        let all: Vec<&str> = match list {
            "exercises" => p.exercises.iter().map(|e| e.key.as_str()).collect(),
            _ => p.workouts.iter().map(|w| w.id.as_str()).collect(),
        };
        all.iter()
            .map(|n| {
                (is_path_name(n) && all.iter().filter(|m| *m == n).count() == 1)
                    .then(|| n.to_string())
            })
            .collect()
    };
    let lists = [
        ("exercises", names("exercises")),
        ("workouts", names("workouts")),
    ];
    for problem in problems.iter_mut() {
        for (list, named) in &lists {
            let Some(rest) = problem
                .path
                .strip_prefix(list)
                .and_then(|r| r.strip_prefix('['))
            else {
                continue;
            };
            let Some((index, tail)) = rest.split_once(']') else {
                continue;
            };
            if let Some(Some(name)) = index.parse::<usize>().ok().and_then(|i| named.get(i)) {
                problem.path = format!("{list}[{name}]{tail}");
            }
        }
    }
}

/// A key or id that can stand in a path: no brackets, dots or spaces, and
/// not all digits (which would read as a position).
pub fn is_path_name(name: &str) -> bool {
    !name.is_empty()
        && !name.chars().all(|c| c.is_ascii_digit())
        && !name
            .chars()
            .any(|c| matches!(c, '[' | ']' | '.') || c.is_whitespace())
}

/// Keys in what was given that the program doesn't have: a typo, or a
/// field from another schema, which would otherwise be dropped silently.
fn unknown_fields(given: &Value, read: &Value, path: &str, out: &mut Vec<Problem>) {
    match (given, read) {
        (Value::Object(g), Value::Object(r)) => {
            for (key, value) in g {
                let at = join(path, key);
                match r.get(key) {
                    Some(inner) => unknown_fields(value, inner, &at, out),
                    None => out.push(Problem::error(at, "not a field of a program")),
                }
            }
        }
        (Value::Array(g), Value::Array(r)) => {
            for (i, (a, b)) in g.iter().zip(r).enumerate() {
                unknown_fields(a, b, &format!("{path}[{i}]"), out);
            }
        }
        _ => {}
    }
}

fn join(path: &str, key: &str) -> String {
    if path.is_empty() {
        key.to_string()
    } else {
        format!("{path}.{key}")
    }
}

struct Checker {
    out: Vec<Problem>,
}

impl Checker {
    fn err(&mut self, path: impl Into<String>, message: impl Into<String>) {
        self.out.push(Problem::error(path, message));
    }

    fn warn(&mut self, path: impl Into<String>, message: impl Into<String>) {
        self.out.push(Problem::warning(path, message));
    }

    fn int(&mut self, path: &str, v: i64, lo: i64, hi: i64) {
        if !(lo..=hi).contains(&v) {
            self.err(path, format!("{v} is outside {lo}..={hi}"));
        }
    }

    fn num(&mut self, path: &str, v: f32, lo: f32, hi: f32) {
        if !v.is_finite() || v < lo || v > hi {
            self.err(path, format!("{v} is outside {lo}..={hi}"));
        }
    }

    /// Over `lo` (not equal), at most `hi`.
    fn above(&mut self, path: &str, v: f32, lo: f32, hi: f32) {
        if !v.is_finite() || v <= lo || v > hi {
            self.err(path, format!("{v} must be over {lo} and at most {hi}"));
        }
    }
}

/// Every check on a parsed program, paths by name ([`name_paths`]).
pub fn check(p: &Program) -> Vec<Problem> {
    let mut out = check_positions(p);
    name_paths(p, &mut out);
    out
}

fn check_positions(p: &Program) -> Vec<Problem> {
    let mut c = Checker { out: Vec::new() };
    if p.schema != SCHEMA {
        c.err("schema", format!("must be {SCHEMA:?}"));
    }
    if p.name.trim().is_empty() {
        c.warn("name", "a program with a name is easier to tell apart");
    }
    check_classes(p, &mut c);
    check_progressions(p, &mut c);
    check_schemes(p, &mut c);
    check_exercises(p, &mut c);
    check_workouts(p, &mut c);
    check_numbers(p, &mut c);
    c.out
}

fn check_classes(p: &Program, c: &mut Checker) {
    if p.classes.is_empty() {
        c.err("classes", "a program needs at least one class");
    }
    for (name, class) in &p.classes {
        let at = format!("classes.{name}");
        if !valid_key(name) {
            c.err(&at, "a name is lowercase letters, digits and underscores");
        }
        c.int(&format!("{at}.rep_low"), class.rep_low.into(), 1, 100);
        c.int(&format!("{at}.rep_high"), class.rep_high.into(), 1, 100);
        if class.rep_high < class.rep_low {
            c.err(format!("{at}.rep_high"), "under rep_low");
        }
        c.int(
            &format!("{at}.rest_seconds"),
            class.rest_seconds.into(),
            0,
            1800,
        );
        if !p.progressions.contains_key(&class.progression) {
            c.err(
                format!("{at}.progression"),
                format!("no progression {:?}", class.progression),
            );
        }
        if !scheme_known(p, &class.scheme) {
            c.err(
                format!("{at}.scheme"),
                format!("no scheme {:?}", class.scheme),
            );
        }
    }
}

fn check_exercises(p: &Program, c: &mut Checker) {
    if p.exercises.is_empty() {
        c.err("exercises", "a program needs exercises");
    }
    if p.exercises.len() > MAX_EXERCISES {
        c.err("exercises", format!("more than {MAX_EXERCISES}"));
    }
    let mut keys = BTreeSet::new();
    for (i, e) in p.exercises.iter().enumerate() {
        let at = format!("exercises[{i}]");
        if !valid_key(&e.key) {
            c.err(
                format!("{at}.key"),
                format!(
                    "{:?}: lowercase letters, digits and underscores, starting with a letter, at most 48",
                    e.key
                ),
            );
        }
        if !keys.insert(e.key.as_str()) {
            c.err(format!("{at}.key"), format!("{:?} is named twice", e.key));
        }
        if e.name.trim().is_empty() || e.name.chars().count() > 60 {
            c.err(format!("{at}.name"), "1 to 60 characters");
        }
        if e.short_name.trim().is_empty() || e.short_name.chars().count() > 12 {
            c.err(format!("{at}.short_name"), "1 to 12 characters");
        }
        if e.description.chars().count() > 500 {
            c.err(format!("{at}.description"), "at most 500 characters");
        }
        if e.muscles.is_empty() {
            c.err(format!("{at}.muscles"), "it trains at least one muscle");
        }
        let distinct: BTreeSet<_> = e.muscles.iter().collect();
        if distinct.len() != e.muscles.len() {
            c.err(format!("{at}.muscles"), "a muscle is named twice");
        }
        if !p.classes.contains_key(&e.class) {
            c.err(format!("{at}.class"), format!("no class {:?}", e.class));
        }
        if let Some(name) = &e.progression {
            if !p.progressions.contains_key(name) {
                c.err(
                    format!("{at}.progression"),
                    format!("no progression {name:?}"),
                );
            }
        }
        check_params(p, e, &at, c);
        if let Some(name) = &e.scheme {
            if !scheme_known(p, name) {
                c.err(format!("{at}.scheme"), format!("no scheme {name:?}"));
            }
        }
        if e.tempo.chars().count() > 20 {
            c.err(format!("{at}.tempo"), "at most 20 characters");
        }
    }
}

/// A scheme a class or an exercise may name: one the program defines, or
/// `straight`, which needn't be written.
fn scheme_known(p: &Program, name: &str) -> bool {
    name == STRAIGHT || p.schemes.contains_key(name)
}

/// Each scheme lays out sets a person can do: a main set first (a drop or
/// a mini follows one), at most one `rest` step and only for main sets,
/// numbers in range, and not more sets than a lift takes.
fn check_schemes(p: &Program, c: &mut Checker) {
    if p.schemes.len() > 50 {
        c.err("schemes", "at most 50");
    }
    for (name, scheme) in &p.schemes {
        let at = format!("schemes.{name}");
        if !valid_key(name) {
            c.err(&at, "a name is lowercase letters, digits and underscores");
        }
        if scheme.steps.is_empty() || scheme.steps.len() > 20 {
            c.err(format!("{at}.steps"), "1 to 20 steps");
        }
        // `straight` is identical sets by name: anything else is another
        // scheme and needs its own.
        if name == STRAIGHT
            && !matches!(
                scheme.steps.as_slice(),
                [step] if step.role == Role::Working
                    && step.count.is_rest()
                    && step.reps.is_none()
                    && step.fraction == 1.0
                    && !step.amrap
                    && step.rir.is_none()
                    && step.rest_seconds.is_none()
                    && step.every_seconds.is_none()
                    && step.on_miss.is_none()
            )
        {
            c.err(
                &at,
                "straight is the rule's sets, identical: give a different shape its own name",
            );
        }
        if scheme.steps.first().is_some_and(|s| !s.role.is_main()) {
            c.err(
                format!("{at}.steps[0].role"),
                "the first step is a main set (working, top or backoff): a drop or a mini follows one",
            );
        }
        let mut rests = 0;
        let mut numbered = 0;
        for (i, step) in scheme.steps.iter().enumerate() {
            let s = format!("{at}.steps[{i}]");
            match &step.count {
                StepCount::Sets(n) => {
                    c.int(&format!("{s}.count"), (*n).into(), 0, 20);
                    numbered += (*n).max(0);
                }
                StepCount::Word(w) if w == "rest" => {
                    rests += 1;
                    if !step.role.is_main() {
                        c.err(
                            format!("{s}.count"),
                            "only a main step (working, top or backoff) takes the rest of the sets",
                        );
                    }
                }
                StepCount::Word(w) => {
                    c.err(
                        format!("{s}.count"),
                        format!("{w:?}: a number of sets, or \"rest\""),
                    );
                }
            }
            if let Some(r) = step.reps {
                c.int(&format!("{s}.reps"), r.into(), 1, 600);
            }
            if step.role == Role::Drop {
                c.above(&format!("{s}.fraction"), step.fraction, 0.0, 0.99);
            } else {
                c.above(&format!("{s}.fraction"), step.fraction, 0.0, 1.5);
            }
            if let Some(r) = step.rir {
                c.int(&format!("{s}.rir"), r.into(), 0, 5);
            }
            if let Some(r) = step.rest_seconds {
                c.int(&format!("{s}.rest_seconds"), r.into(), 0, 1800);
            }
            if let Some(e) = step.every_seconds {
                c.int(&format!("{s}.every_seconds"), e.into(), 10, 600);
            }
            if let Some(m) = &step.on_miss {
                let at = format!("{s}.on_miss");
                if let Some(r) = m.rest_seconds {
                    c.int(&format!("{at}.rest_seconds"), r.into(), 0, 1800);
                }
                if let Some(f) = m.fraction {
                    c.above(&format!("{at}.fraction"), f, 0.0, 0.99);
                }
                if m.rest_seconds.is_none() && m.fraction.is_none() && !m.stop {
                    c.err(&at, "says nothing: give rest_seconds, fraction or stop");
                }
                if m.stop && m.fraction.is_some() {
                    c.err(
                        &at,
                        "stop drops the sets still to do: a fraction has nothing left to lighten",
                    );
                }
            }
            if step.amrap && !step.role.is_main() {
                c.err(
                    format!("{s}.amrap"),
                    "a drop or a mini already goes as far as it can",
                );
            }
        }
        if rests > 1 {
            c.err(
                format!("{at}.steps"),
                "at most one step takes the rest of the sets",
            );
        }
        if numbered > 30 {
            c.err(format!("{at}.steps"), "more than 30 sets");
        }
    }
}

/// A lift's `params` name numbers its rule has, and the rule they make is
/// as sound as any written out.
fn check_params(p: &Program, e: &ExerciseDef, at: &str, c: &mut Checker) {
    if e.params.is_empty() {
        return;
    }
    if e.params.len() > 20 {
        c.err(format!("{at}.params"), "at most 20");
    }
    let Some(rule) = p.progressions.get(p.progression_name(&e.key)) else {
        return; // named above
    };
    match tune(rule, &e.params) {
        Err((name, message)) => c.err(format!("{at}.params.{name}"), message),
        Ok(tuned) => check_progression(&format!("{at}.params"), &tuned, c),
    }
}

fn check_workouts(p: &Program, c: &mut Checker) {
    if p.workouts.len() > MAX_WORKOUTS {
        c.err("workouts", format!("more than {MAX_WORKOUTS}"));
    }
    let mut ids = BTreeSet::new();
    for (i, w) in p.workouts.iter().enumerate() {
        let at = format!("workouts[{i}]");
        if w.id.is_empty() || w.id.len() > 64 || w.id.chars().any(char::is_whitespace) {
            c.err(format!("{at}.id"), "1 to 64 characters, no spaces");
        }
        if !ids.insert(w.id.as_str()) {
            c.err(format!("{at}.id"), format!("{:?} is used twice", w.id));
        }
        if w.name.trim().is_empty() || w.name.chars().count() > 60 {
            c.err(format!("{at}.name"), "1 to 60 characters");
        }
        if w.exercises.is_empty() {
            c.err(format!("{at}.exercises"), "a workout needs an exercise");
        }
        if w.exercises.len() > 30 {
            c.err(format!("{at}.exercises"), "at most 30");
        }
        let mut seen = BTreeSet::new();
        for (j, key) in w.exercises.iter().enumerate() {
            if !p.knows(key) {
                c.err(
                    format!("{at}.exercises[{j}]"),
                    format!("no exercise {key:?}"),
                );
            }
            if !seen.insert(key) {
                c.err(
                    format!("{at}.exercises[{j}]"),
                    format!("{key:?} is in it twice: a workout has each lift once"),
                );
            }
        }
        if w.notes.chars().count() > 1000 {
            c.err(format!("{at}.notes"), "at most 1000 characters");
        }
        let mut grouped = BTreeSet::new();
        for (g, group) in w.groups.iter().enumerate() {
            let at = format!("{at}.groups[{g}]");
            if group.exercises.len() < 2 || group.exercises.len() > 8 {
                c.err(format!("{at}.exercises"), "2 to 8 lifts");
            }
            for (j, key) in group.exercises.iter().enumerate() {
                if !w.exercises.contains(key) {
                    c.err(
                        format!("{at}.exercises[{j}]"),
                        format!("{key:?} isn't one of the workout's exercises"),
                    );
                }
                if !grouped.insert(key) {
                    c.err(
                        format!("{at}.exercises[{j}]"),
                        format!("{key:?} is in two groups (or twice in one)"),
                    );
                }
            }
            if let Some(r) = group.rest_seconds {
                c.int(&format!("{at}.rest_seconds"), r.into(), 0, 1800);
            }
        }
        if w.groups.len() > 10 {
            c.err(format!("{at}.groups"), "at most 10");
        }
    }
    if !p.workouts.is_empty() && !p.workouts.iter().any(|w| w.rotation) {
        c.warn(
            "workouts",
            "nothing is in rotation, so Home suggests nothing",
        );
    }
}

fn check_progressions(p: &Program, c: &mut Checker) {
    if p.progressions.len() > MAX_PROGRESSIONS {
        c.err("progressions", format!("more than {MAX_PROGRESSIONS}"));
    }
    for (name, rule) in &p.progressions {
        let at = format!("progressions.{name}");
        if !valid_key(name) {
            c.err(&at, "a name is lowercase letters, digits and underscores");
        }
        check_progression(&at, rule, c);
    }
}

/// One rule's numbers in range and its formula sound, named from `at`: a
/// rule in `progressions`, or one as a lift's `params` tune it.
fn check_progression(at: &str, rule: &Progression, c: &mut Checker) {
    let sets = |c: &mut Checker, sets: i32| c.int(&format!("{at}.sets"), sets.into(), 1, 20);
    let reps = |c: &mut Checker, path: &str, reps: i32| {
        c.int(&format!("{at}.{path}"), reps.into(), 1, 100)
    };
    match rule {
        Progression::EstimatedMax => {}
        Progression::Fixed {
            sets: s,
            reps: r,
            weight_lb,
        } => {
            sets(c, *s);
            reps(c, "reps", *r);
            c.num(&format!("{at}.weight_lb"), *weight_lb, 0.0, 2000.0);
        }
        Progression::Linear {
            sets: s,
            reps: r,
            increment_lb,
            deload_after_fails,
            deload_factor,
        } => {
            if let Some(s) = s {
                sets(c, *s);
            }
            reps(c, "reps", *r);
            c.num(&format!("{at}.increment_lb"), *increment_lb, 0.0, 100.0);
            c.int(
                &format!("{at}.deload_after_fails"),
                (*deload_after_fails).into(),
                0,
                20,
            );
            c.above(&format!("{at}.deload_factor"), *deload_factor, 0.0, 1.0);
        }
        Progression::Double {
            sets: s,
            rep_low,
            rep_high,
            increment_lb,
            rep_step,
        } => {
            if let Some(s) = s {
                sets(c, *s);
            }
            reps(c, "rep_low", *rep_low);
            reps(c, "rep_high", *rep_high);
            if rep_high < rep_low {
                c.err(format!("{at}.rep_high"), "under rep_low");
            }
            c.num(&format!("{at}.increment_lb"), *increment_lb, 0.0, 100.0);
            c.int(&format!("{at}.rep_step"), (*rep_step).into(), 1, 60);
        }
        Progression::Cycle { steps } => {
            if steps.is_empty() || steps.len() > 52 {
                c.err(format!("{at}.steps"), "1 to 52 steps");
            }
            for (i, step) in steps.iter().enumerate() {
                let s = format!("{at}.steps[{i}]");
                c.int(&format!("{s}.sets"), step.sets.into(), 1, 20);
                c.int(&format!("{s}.reps"), step.reps.into(), 1, 100);
                c.above(&format!("{s}.fraction"), step.fraction, 0.0, 1.5);
            }
        }
        Progression::Formula(f) => check_formula(at, f, c),
    }
}

/// A formula: every expression parses and reads only names it has, and on
/// each sample history gives numbers a plan can be made from.
fn check_formula(at: &str, f: &Formula, c: &mut Checker) {
    if f.note.chars().count() > 300 {
        c.err(format!("{at}.note"), "at most 300 characters");
    }
    let sample = Sample::default();
    let evaluator = match Evaluator::new(&f.lets, &sample) {
        Ok(e) => e,
        Err(e) => {
            c.err(format!("{at}.let"), e);
            return;
        }
    };
    let mut parsed = Vec::new();
    for (field, src) in formula_fields(f) {
        match formula::parse(src) {
            Ok(e) => {
                let unknown = evaluator.unknown_names(&e);
                if unknown.is_empty() {
                    parsed.push((field, e));
                } else {
                    c.err(
                        format!("{at}.{field}"),
                        format!(
                            "no variable {}: the variables are {}",
                            unknown.join(", "),
                            VARIABLES
                                .iter()
                                .map(|(v, _)| *v)
                                .collect::<Vec<_>>()
                                .join(", ")
                        ),
                    );
                }
            }
            Err(e) => c.err(format!("{at}.{field}"), e),
        }
    }
    for (name, e) in evaluator.lets() {
        let unknown = evaluator.unknown_names(e);
        if !unknown.is_empty() {
            c.err(
                format!("{at}.let.{name}"),
                format!("no variable {}", unknown.join(", ")),
            );
            return;
        }
    }
    if c.out.iter().any(|p| p.error && p.path.starts_with(at)) {
        return;
    }
    for sample in Sample::all() {
        let Ok(evaluator) = Evaluator::new(&f.lets, &sample) else {
            return;
        };
        for (field, e) in &parsed {
            match evaluator.eval(e) {
                Ok(v) => {
                    let (lo, hi) = match *field {
                        "sets" => (1.0, 20.0),
                        "reps" => (1.0, 100.0),
                        "weight" => (0.0, 2000.0),
                        _ => (0.0, 1800.0),
                    };
                    if v < lo || v > hi {
                        c.err(
                            format!("{at}.{field}"),
                            format!("{v} on {}: outside {lo}..={hi}", sample.label),
                        );
                        return;
                    }
                }
                Err(e) => {
                    c.err(format!("{at}.{field}"), format!("{e} on {}", sample.label));
                    return;
                }
            }
        }
    }
}

fn formula_fields(f: &Formula) -> Vec<(&'static str, &str)> {
    let mut out = vec![("reps", f.reps.as_str()), ("weight", f.weight.as_str())];
    if let Some(s) = &f.sets {
        out.push(("sets", s));
    }
    if let Some(r) = &f.rest_seconds {
        out.push(("rest_seconds", r));
    }
    out
}

/// A history a formula is tried on before it is accepted.
struct Sample {
    label: &'static str,
    vars: BTreeMap<&'static str, f64>,
}

impl Default for Sample {
    fn default() -> Self {
        Sample::all().remove(1)
    }
}

impl Sample {
    fn all() -> Vec<Sample> {
        let base = |label, pairs: &[(&'static str, f64)]| {
            let mut vars: BTreeMap<&'static str, f64> =
                VARIABLES.iter().map(|(name, _)| (*name, 0.0)).collect();
            vars.insert("step", 5.0);
            vars.insert("rep_low", 5.0);
            vars.insert("rep_high", 8.0);
            for (k, v) in pairs {
                vars.insert(k, *v);
            }
            Sample { label, vars }
        };
        let done = [
            ("has_last", 1.0),
            ("last.weight", 135.0),
            ("last.reps", 5.0),
            ("last.sets", 3.0),
            ("last.best_reps", 5.0),
            ("sessions", 6.0),
            ("days_off", 2.0),
            ("max", 160.0),
            ("start", 95.0),
        ];
        let with = |label, extra: &[(&'static str, f64)]| {
            let mut pairs = done.to_vec();
            pairs.extend_from_slice(extra);
            base(label, &pairs)
        };
        vec![
            base("a lift never done", &[]),
            with(
                "a session with every rep hit",
                &[("last.hit", 1.0), ("hits_in_row", 3.0)],
            ),
            with(
                "a session with a rep missed",
                &[
                    ("last.missed", 1.0),
                    ("fails_in_row", 1.0),
                    ("last.best_reps", 4.0),
                ],
            ),
            with(
                "three misses in a row",
                &[
                    ("last.missed", 1.0),
                    ("fails_in_row", 3.0),
                    ("last.best_reps", 3.0),
                ],
            ),
            with("a session stopped early", &[("last.stopped_early", 1.0)]),
            with("six weeks off", &[("last.hit", 1.0), ("days_off", 45.0)]),
            with(
                "a heavy lifter in kilograms",
                &[
                    ("last.hit", 1.0),
                    ("kg", 1.0),
                    ("last.weight", 440.0),
                    ("max", 500.0),
                    ("step", 5.51),
                    ("sessions", 120.0),
                ],
            ),
            with(
                "a bodyweight lift",
                &[
                    ("bodyweight", 1.0),
                    ("last.weight", 0.0),
                    ("max", 14.0),
                    ("step", 0.0),
                    ("last.reps", 10.0),
                    ("last.hit", 1.0),
                    ("rep_low", 5.0),
                    ("rep_high", 15.0),
                ],
            ),
        ]
    }
}

impl Scope for Sample {
    fn var(&self, name: &str) -> Option<f64> {
        self.vars.get(name).copied()
    }
    fn snap(&self, weight_lb: f64) -> f64 {
        (weight_lb / 5.0).round().max(0.0) * 5.0
    }
}

fn check_numbers(p: &Program, c: &mut Checker) {
    c.int("transition_seconds", p.transition_seconds.into(), 0, 300);
    c.num("volume.partial_credit", p.volume.partial_credit, 0.0, 1.0);
    let e = &p.estimate;
    c.above("estimate.divisor", e.divisor, 0.0, 1000.0);
    c.num("estimate.reserve_when_hit", e.reserve_when_hit, 0.0, 10.0);
    c.num("estimate.fatigue_per_set", e.fatigue_per_set, 0.0, 10.0);
    for (i, t) in p.time_off.iter().enumerate() {
        c.int(&format!("time_off[{i}].days"), t.days, 1, 3650);
        c.above(&format!("time_off[{i}].factor"), t.factor, 0.0, 1.0);
    }
    let s = &p.sets;
    c.int("sets.per_lift", s.per_lift.into(), 1, 20);
    c.int("sets.override_sets", s.override_sets.into(), 1, 20);
    let k = &p.costs;
    c.above("costs.set_seconds", k.set_seconds, 0.0, 3600.0);
    c.num("costs.warmup_seconds", k.warmup_seconds, 0.0, 3600.0);
    c.num("costs.between_seconds", k.between_seconds, 0.0, 3600.0);
    c.int("costs.learn_window_days", k.learn_window_days, 1, 365);
    c.int("costs.learn_samples", k.learn_samples as i64, 1, 1000);
    c.num(
        "costs.learn_min_set_seconds",
        k.learn_min_set_seconds,
        0.0,
        600.0,
    );
    c.num(
        "costs.learn_min_gap_seconds",
        k.learn_min_gap_seconds,
        0.0,
        600.0,
    );
    let w = &p.warmups;
    if w.ladder.len() > 10 {
        c.err("warmups.ladder", "at most 10 steps");
    }
    let mut last = 0.0;
    for (i, step) in w.ladder.iter().enumerate() {
        c.above(
            &format!("warmups.ladder[{i}].fraction"),
            step.fraction,
            0.0,
            0.99,
        );
        if step.fraction <= last {
            c.err(
                format!("warmups.ladder[{i}].fraction"),
                "each step heavier than the one before",
            );
        }
        last = step.fraction;
        c.int(
            &format!("warmups.ladder[{i}].reps"),
            step.reps.into(),
            1,
            30,
        );
    }
    c.int("warmups.rest_seconds", w.rest_seconds.into(), 0, 600);
    let r = &p.calibration;
    c.int("calibration.reps", r.reps.into(), 1, 30);
    c.int("calibration.rest_seconds", r.rest_seconds.into(), 0, 900);
    c.above("calibration.start_fraction", r.start_fraction, 0.0, 1.0);
    c.above("calibration.rung_factor", r.rung_factor, 1.0, 2.0);
    c.int("calibration.max_rungs", r.max_rungs as i64, 1, 12);
    c.int(
        "calibration.too_heavy_reps",
        r.too_heavy_reps.into(),
        0,
        r.reps.into(),
    );
    c.above("calibration.step_down", r.step_down, 0.0, 0.99);
    c.above(
        "calibration.max_jump_fraction",
        r.max_jump_fraction,
        0.0,
        10.0,
    );
    c.num(
        "calibration.reserve_zero_to_one",
        r.reserve_zero_to_one,
        0.0,
        20.0,
    );
    c.num(
        "calibration.reserve_two_to_four",
        r.reserve_two_to_four,
        0.0,
        20.0,
    );
    c.num(
        "calibration.reserve_five_plus",
        r.reserve_five_plus,
        0.0,
        20.0,
    );
    let v = &p.volume;
    c.int("volume.window_days", v.window_days, 1, 28);
    c.int("volume.target_low", v.target_low.into(), 0, 100);
    c.int("volume.target_high", v.target_high.into(), 0, 100);
    if v.target_high < v.target_low {
        c.err("volume.target_high", "under target_low");
    }
    c.num("volume.secondary_credit", v.secondary_credit, 0.0, 1.0);
    c.above("volume.tie_fraction", v.tie_fraction, 0.0, 1.0);
    for (muscle, band) in &v.targets {
        let at = format!("volume.targets.{}", muscle_name(*muscle));
        c.int(&format!("{at}.low"), band.low.into(), 0, 100);
        c.int(&format!("{at}.high"), band.high.into(), 0, 100);
        if band.high < band.low {
            c.err(format!("{at}.high"), "under low");
        }
    }
    for (day, id) in &p.schedule {
        let at = format!("schedule.{}", weekday_name(*day));
        if p.workout(id).is_none() {
            c.err(at, format!("{id:?} is not one of the workouts"));
        }
    }
    match p.next {
        Next::Schedule if p.schedule.is_empty() => c.err(
            "next",
            "schedule picks by `schedule`, which names no days: give it some, e.g. {\"mon\": \"upper_a\"}",
        ),
        Next::Volume | Next::Sequence if !p.schedule.is_empty() => c.warn(
            "schedule",
            "only `next: schedule` reads it; Home ignores it otherwise",
        ),
        _ => {}
    }
    for (muscle, hours) in &p.recovery.hours {
        c.int(
            &format!("recovery.hours.{}", muscle_name(*muscle)),
            *hours,
            0,
            240,
        );
    }
    c.int("recovery.default_hours", p.recovery.default_hours, 0, 240);
    c.above(
        "rotation_check.sets_per_lift",
        p.rotation_check.sets_per_lift,
        0.0,
        20.0,
    );
    c.above(
        "rotation_check.overlap_fraction",
        p.rotation_check.overlap_fraction,
        0.0,
        1.0,
    );
    c.int(
        "end_of_exercise_rest_seconds",
        p.end_of_exercise_rest_seconds,
        0,
        600,
    );
    let eq = &p.equipment;
    for (name, loading, loaded) in [
        ("barbell", &eq.barbell, true),
        ("dumbbell", &eq.dumbbell, true),
        ("machine", &eq.machine, true),
        ("cable", &eq.cable, true),
        ("bodyweight", &eq.bodyweight, false),
    ] {
        let at = format!("equipment.{name}");
        for (unit, step) in [("lb", loading.step.lb), ("kg", loading.step.kg)] {
            if loaded {
                c.above(&format!("{at}.step.{unit}"), step, 0.0, 100.0);
            } else {
                c.num(&format!("{at}.step.{unit}"), step, 0.0, 100.0);
            }
        }
        if let Some(opener) = loading.opener {
            c.num(&format!("{at}.opener.lb"), opener.lb, 0.0, 1000.0);
            c.num(&format!("{at}.opener.kg"), opener.kg, 0.0, 500.0);
        }
    }
    let plates = &eq.plates;
    c.above("equipment.plates.bar.lb", plates.bar.lb, 0.0, 200.0);
    c.above("equipment.plates.bar.kg", plates.bar.kg, 0.0, 100.0);
    for (unit, list) in [("lb", &plates.lb), ("kg", &plates.kg)] {
        let at = format!("equipment.plates.{unit}");
        if list.is_empty() || list.len() > 15 {
            c.err(&at, "1 to 15 plates");
        }
        for (i, plate) in list.iter().enumerate() {
            c.above(&format!("{at}[{i}]"), *plate, 0.0, 100.0);
            if i > 0 && *plate >= list[i - 1] {
                c.err(format!("{at}[{i}]"), "plates go heaviest first, each once");
            }
        }
    }
}

fn weekday_name(d: Weekday) -> String {
    serde_json::to_value(d)
        .ok()
        .and_then(|v| v.as_str().map(str::to_string))
        .unwrap_or_default()
}

fn muscle_name(m: Muscle) -> String {
    serde_json::to_value(m)
        .ok()
        .and_then(|v| v.as_str().map(str::to_string))
        .unwrap_or_default()
}

/// A key or a name: lowercase letters, digits and underscores, starting
/// with a letter, at most 48.
pub fn valid_key(key: &str) -> bool {
    let mut chars = key.chars();
    chars.next().is_some_and(|c| c.is_ascii_lowercase())
        && chars.all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_')
        && key.len() <= 48
}

/// The checks that need the account: a program may not drop an exercise
/// the account has done, set by hand or starts from, and the workouts it
/// keeps keep their ids. `used` is every exercise the account names.
pub fn validate_for_account(p: &Program, used: &BTreeSet<String>) -> Vec<Problem> {
    let mut out = Vec::new();
    for key in used {
        if !p.knows(key) {
            out.push(Problem::error(
                "exercises",
                format!(
                    "{key:?} has history in this account, so it must stay (rename it, or leave it out of the workouts)"
                ),
            ));
        }
    }
    out
}
