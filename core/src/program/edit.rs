//! Changing a program by edits instead of rewriting it: what an assistant
//! sends over MCP (see `docs/plans/mcp-edits.md`). An edit names a path,
//! the validator's path syntax, with exercises and workouts by key and id:
//!
//! - `{ "set": "classes.heavy.rest_seconds", "value": 150 }`
//! - `{ "remove": "workouts[b]" }`
//! - `{ "move": "workouts[upper_b]", "before": "workouts[lower_a]" }`
//!
//! The edits apply in order to a copy of the program; one that can't apply
//! stops them all and says which. The result is a whole document, checked
//! and recorded as any other: nothing about edits reaches the log.
//!
//! The built-in exercises are the same in every program, so an assistant
//! is shown only the ones a program adds or changes ([`compact`]) and a
//! document sent without them gets them back ([`complete`]).

use std::collections::BTreeSet;

use serde_json::Value;

use super::{ExerciseDef, Program};

/// The most edits one call applies.
pub const MAX_EDITS: usize = 200;

/// Why the edit at `index` (from 0) couldn't apply.
#[derive(Clone, Debug, PartialEq)]
pub struct EditError {
    pub index: usize,
    pub path: String,
    pub message: String,
}

#[derive(Clone, Debug, PartialEq)]
enum Seg {
    Field(String),
    /// The item of a list of objects whose `key` (exercises) or `id`
    /// (workouts) is this.
    Named(String),
    Index(usize),
}

fn parse_path(path: &str) -> Result<Vec<Seg>, String> {
    if path.trim().is_empty() {
        return Err("the path is empty".into());
    }
    let mut segs = Vec::new();
    for part in path.split('.') {
        let (field, mut rest) = match part.find('[') {
            Some(i) => (&part[..i], &part[i..]),
            None => (part, ""),
        };
        if field.is_empty() && segs.is_empty() {
            return Err(format!(
                "{path:?} starts with a bracket; name the list first"
            ));
        }
        if !field.is_empty() {
            segs.push(Seg::Field(field.to_string()));
        } else if rest.is_empty() {
            return Err(format!("{path:?} has an empty part"));
        }
        while !rest.is_empty() {
            let Some(inner) = rest.strip_prefix('[') else {
                return Err(format!("{path:?}: text after a ]"));
            };
            let Some((name, after)) = inner.split_once(']') else {
                return Err(format!("{path:?}: a [ without its ]"));
            };
            if name.is_empty() {
                return Err(format!("{path:?}: empty brackets"));
            }
            segs.push(match name.parse::<usize>() {
                Ok(i) => Seg::Index(i),
                Err(_) => Seg::Named(name.to_string()),
            });
            rest = after;
        }
    }
    Ok(segs)
}

/// The field naming an item of a list: exercises by `key`, workouts (and
/// anything else) by `id`.
fn name_field(list: &[Value]) -> &'static str {
    if list.iter().any(|v| v.get("key").is_some()) {
        "key"
    } else {
        "id"
    }
}

fn find_named(list: &[Value], name: &str) -> Option<usize> {
    let field = name_field(list);
    list.iter()
        .position(|v| v.get(field).and_then(Value::as_str) == Some(name))
}

fn describe(segs: &[Seg]) -> String {
    let mut out = String::new();
    for s in segs {
        match s {
            Seg::Field(f) => {
                if !out.is_empty() {
                    out.push('.');
                }
                out.push_str(f);
            }
            Seg::Named(n) => out.push_str(&format!("[{n}]")),
            Seg::Index(i) => out.push_str(&format!("[{i}]")),
        }
    }
    out
}

/// The value at `segs`, for changing.
fn walk<'a>(mut at: &'a mut Value, segs: &[Seg]) -> Result<&'a mut Value, String> {
    for (i, seg) in segs.iter().enumerate() {
        let here = describe(&segs[..=i]);
        at = match (seg, at) {
            (Seg::Field(f), Value::Object(map)) => map
                .get_mut(f)
                .ok_or_else(|| format!("{here}: there is no such field"))?,
            (Seg::Named(n), Value::Array(list)) => {
                let i = find_named(list, n)
                    .ok_or_else(|| format!("{here}: there is none named {n:?}"))?;
                &mut list[i]
            }
            (Seg::Index(i), Value::Array(list)) => {
                let len = list.len();
                list.get_mut(*i)
                    .ok_or_else(|| format!("{here}: the list has {len}"))?
            }
            (Seg::Field(_), _) => return Err(format!("{here}: not an object")),
            (_, _) => return Err(format!("{here}: not a list")),
        };
    }
    Ok(at)
}

/// A new exercise or workout's optional fields, filled in.
fn with_defaults(list_name: Option<&str>, mut value: Value) -> Value {
    let Value::Object(map) = &mut value else {
        return value;
    };
    match list_name {
        Some("workouts") => {
            map.entry("rotation").or_insert(Value::Bool(true));
            map.entry("notes")
                .or_insert_with(|| Value::String(String::new()));
            map.entry("from_library")
                .or_insert_with(|| Value::String(String::new()));
        }
        Some("exercises") => {
            let short: String = map
                .get("name")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .chars()
                .take(12)
                .collect::<String>()
                .trim()
                .to_string();
            map.entry("short_name").or_insert(Value::String(short));
            map.entry("progression").or_insert(Value::Null);
            map.entry("description")
                .or_insert_with(|| Value::String(String::new()));
        }
        _ => {}
    }
    value
}

fn set(doc: &mut Value, segs: &[Seg], value: Value) -> Result<(), String> {
    let (last, parent_segs) = segs.split_last().expect("a path has a segment");
    let list_name = match parent_segs.last() {
        Some(Seg::Field(f)) => Some(f.as_str()),
        _ => None,
    };
    let parent = walk(doc, parent_segs)?;
    let here = describe(segs);
    match (last, parent) {
        (Seg::Field(f), Value::Object(map)) => {
            map.insert(f.clone(), value);
        }
        (Seg::Named(n), Value::Array(list)) => {
            let field = if list_name == Some("exercises") {
                "key"
            } else if list_name == Some("workouts") {
                "id"
            } else {
                name_field(list)
            };
            let Value::Object(mut item) = value else {
                return Err(format!("{here}: the value is an object"));
            };
            match item.get(field).and_then(Value::as_str) {
                Some(given) if given != n => {
                    return Err(format!(
                        "{here}: the value's {field} is {given:?}; to rename, remove it and set the new one"
                    ))
                }
                _ => {
                    item.insert(field.to_string(), Value::String(n.clone()));
                }
            }
            let item = Value::Object(item);
            match find_named(list, n) {
                Some(i) => list[i] = item,
                None => list.push(with_defaults(list_name, item)),
            }
        }
        (Seg::Index(i), Value::Array(list)) => {
            if *i < list.len() {
                list[*i] = value;
            } else if *i == list.len() {
                list.push(value);
            } else {
                return Err(format!(
                    "{here}: the list has {}; set [{}] to add one at the end",
                    list.len(),
                    list.len()
                ));
            }
        }
        (Seg::Field(_), _) => return Err(format!("{here}: its parent is not an object")),
        (_, _) => return Err(format!("{here}: its parent is not a list")),
    }
    Ok(())
}

fn remove(doc: &mut Value, segs: &[Seg], builtin: &BTreeSet<String>) -> Result<(), String> {
    let (last, parent_segs) = segs.split_last().expect("a path has a segment");
    let in_exercises = parent_segs == [Seg::Field("exercises".into())];
    let parent = walk(doc, parent_segs)?;
    let here = describe(segs);
    match (last, parent) {
        (Seg::Field(f), Value::Object(map)) => {
            map.remove(f)
                .ok_or_else(|| format!("{here}: there is no such field"))?;
        }
        (Seg::Named(n), Value::Array(list)) => {
            if in_exercises && builtin.contains(n) {
                return Err(format!(
                    "{here}: a built-in exercise can't be removed; leave it out of the workouts instead"
                ));
            }
            let i =
                find_named(list, n).ok_or_else(|| format!("{here}: there is none named {n:?}"))?;
            list.remove(i);
        }
        (Seg::Index(i), Value::Array(list)) => {
            if *i >= list.len() {
                return Err(format!("{here}: the list has {}", list.len()));
            }
            // The same guard as removing by name: a built-in exercise can't be
            // removed by its index either.
            if in_exercises {
                let key = list[*i].get(name_field(list)).and_then(Value::as_str);
                if let Some(key) = key {
                    if builtin.contains(key) {
                        return Err(format!(
                            "{here}: a built-in exercise ({key:?}) can't be removed; leave it out of the workouts instead"
                        ));
                    }
                }
            }
            list.remove(*i);
        }
        (Seg::Field(_), _) => return Err(format!("{here}: its parent is not an object")),
        (_, _) => return Err(format!("{here}: its parent is not a list")),
    }
    Ok(())
}

fn moved(doc: &mut Value, segs: &[Seg], before: Option<&[Seg]>) -> Result<(), String> {
    let here = describe(segs);
    let (Some(Seg::Named(n)), parent_segs) = (segs.last(), &segs[..segs.len() - 1]) else {
        return Err(format!(
            "{here}: move names an item, like workouts[upper_a]"
        ));
    };
    if let Some(b) = before {
        if b.len() != segs.len() || b[..b.len() - 1] != *parent_segs {
            return Err(format!(
                "{here}: before is an item of the same list, like {}[name]",
                describe(parent_segs)
            ));
        }
    }
    let Value::Array(list) = walk(doc, parent_segs)? else {
        return Err(format!("{here}: its parent is not a list"));
    };
    let from = find_named(list, n).ok_or_else(|| format!("{here}: there is none named {n:?}"))?;
    let item = list.remove(from);
    let to = match before.and_then(|b| b.last()) {
        None => list.len(),
        Some(Seg::Named(m)) if m == n => {
            list.insert(from, item);
            return Ok(());
        }
        Some(Seg::Named(m)) => match find_named(list, m) {
            Some(i) => i,
            None => {
                list.insert(from, item);
                return Err(format!("{here}: there is none named {m:?} to go before"));
            }
        },
        Some(_) => {
            list.insert(from, item);
            return Err(format!(
                "{here}: before names an item, like workouts[lower_a]"
            ));
        }
    };
    list.insert(to, item);
    Ok(())
}

fn apply_one(
    doc: &mut Value,
    edit: &Value,
    builtin: &BTreeSet<String>,
) -> Result<(), (String, String)> {
    let Value::Object(e) = edit else {
        return Err((
            String::new(),
            "an edit is an object: set, remove or move".into(),
        ));
    };
    let path_of = |key: &str| e.get(key).and_then(Value::as_str);
    let ops: Vec<&str> = ["set", "remove", "move"]
        .into_iter()
        .filter(|k| e.contains_key(*k))
        .collect();
    let [op] = ops[..] else {
        return Err((
            String::new(),
            "an edit has exactly one of set, remove or move".into(),
        ));
    };
    let path =
        path_of(op).ok_or_else(|| (String::new(), format!("{op} is a path, as a string")))?;
    let fail = |m: String| (path.to_string(), m);
    let segs = parse_path(path).map_err(fail)?;
    let allowed: &[&str] = match op {
        "set" => &["set", "value"],
        "remove" => &["remove"],
        _ => &["move", "before"],
    };
    if let Some(extra) = e.keys().find(|k| !allowed.contains(&k.as_str())) {
        return Err(fail(format!("{op} doesn't take {extra:?}")));
    }
    match op {
        "set" => {
            let value = e
                .get("value")
                .cloned()
                .ok_or_else(|| fail("set needs a value".into()))?;
            set(doc, &segs, value).map_err(fail)
        }
        "remove" => remove(doc, &segs, builtin).map_err(fail),
        _ => {
            let before = match e.get("before") {
                None | Some(Value::Null) => None,
                Some(Value::String(b)) => Some(parse_path(b).map_err(fail)?),
                Some(_) => return Err(fail("before is a path, or null for the end".into())),
            };
            moved(doc, &segs, before.as_deref()).map_err(fail)
        }
    }
}

/// `edits` applied in order to `current`, as a whole document; nothing is
/// changed if one of them can't apply.
pub fn apply(current: &Program, edits: &[Value]) -> Result<Value, EditError> {
    if edits.is_empty() {
        return Err(EditError {
            index: 0,
            path: String::new(),
            message: "no edits".into(),
        });
    }
    if edits.len() > MAX_EDITS {
        return Err(EditError {
            index: MAX_EDITS,
            path: String::new(),
            message: format!("at most {MAX_EDITS} edits at once"),
        });
    }
    let builtin = builtin_keys();
    let mut doc = serde_json::to_value(current).expect("a program serialises");
    for (index, edit) in edits.iter().enumerate() {
        apply_one(&mut doc, edit, &builtin).map_err(|(path, message)| EditError {
            index,
            path,
            message,
        })?;
    }
    Ok(doc)
}

fn builtin_exercises() -> Vec<ExerciseDef> {
    Program::builtin().exercises.clone()
}

/// Every built-in exercise's key.
pub fn builtin_keys() -> BTreeSet<String> {
    builtin_exercises().into_iter().map(|e| e.key).collect()
}

/// `program` as an assistant is shown it: without the built-in exercises
/// it leaves as they are. Returns the document and how many it left out.
pub fn compact(program: &Program) -> (Value, usize) {
    let builtin = builtin_exercises();
    let mut doc = serde_json::to_value(program).expect("a program serialises");
    let mut left_out = 0;
    if let Some(Value::Array(list)) = doc.get_mut("exercises") {
        list.retain(|v| {
            let same = serde_json::from_value::<ExerciseDef>(v.clone())
                .ok()
                .is_some_and(|e| builtin.contains(&e));
            left_out += usize::from(same);
            !same
        });
    }
    (doc, left_out)
}

/// A document with every built-in exercise it leaves out put back: the
/// built-ins in their order (the document's version of one where it has
/// it), then the document's own. A document that isn't an object, or
/// whose `exercises` isn't a list, is left for the validator to name.
pub fn complete(mut doc: Value) -> Value {
    let Some(Value::Array(given)) = doc.get_mut("exercises").map(std::mem::take) else {
        if let Value::Object(map) = &mut doc {
            if !map.contains_key("exercises") {
                map.insert(
                    "exercises".into(),
                    Value::Array(
                        builtin_exercises()
                            .iter()
                            .map(|e| serde_json::to_value(e).expect("serialises"))
                            .collect(),
                    ),
                );
            }
        }
        return doc;
    };
    let key_of = |v: &Value| v.get("key").and_then(Value::as_str).map(str::to_string);
    let mut out: Vec<Value> = Vec::new();
    let mut used = BTreeSet::new();
    for b in builtin_exercises() {
        match given
            .iter()
            .find(|v| key_of(v).as_deref() == Some(b.key.as_str()))
        {
            Some(v) => out.push(v.clone()),
            None => out.push(serde_json::to_value(&b).expect("serialises")),
        }
        used.insert(b.key);
    }
    out.extend(
        given
            .into_iter()
            .filter(|v| key_of(v).is_none_or(|k| !used.contains(&k))),
    );
    if let Value::Object(map) = &mut doc {
        map.insert("exercises".into(), Value::Array(out));
    }
    doc
}

/// One part of a program by path (`classes`, `workouts[upper_a]`).
pub fn part(program: &Program, path: &str) -> Result<Value, String> {
    let mut doc = serde_json::to_value(program).expect("a program serialises");
    let segs = parse_path(path)?;
    walk(&mut doc, &segs).map(|v| v.clone())
}

/// The edits that suggest `from`'s workout `workout_id` to someone whose
/// program is `to`: the workout as `new_id` (in the rotation, its groups
/// with it), and whatever of `from`'s it needs that `to` lacks: each of its
/// exercises `to` doesn't know, and their own progression and scheme. What
/// `to` already has is never touched. None when `from` has no such workout.
pub fn workout_suggestion(
    from: &Program,
    to: &Program,
    workout_id: &str,
    new_id: &str,
) -> Option<Vec<Value>> {
    let workout = from.workout(workout_id)?;
    let mut edits = Vec::new();
    for key in &workout.exercises {
        if to.knows(key) {
            continue;
        }
        let Some(def) = from.exercise(key) else {
            continue;
        };
        if let Some(name) = &def.progression {
            if let (false, Some(rule)) = (
                to.progressions.contains_key(name),
                from.progressions.get(name),
            ) {
                edits.push(
                    serde_json::json!({ "set": format!("progressions.{name}"), "value": rule }),
                );
            }
        }
        if let Some(name) = &def.scheme {
            if let (false, Some(scheme)) = (to.schemes.contains_key(name), from.schemes.get(name)) {
                edits
                    .push(serde_json::json!({ "set": format!("schemes.{name}"), "value": scheme }));
            }
        }
        edits.push(serde_json::json!({ "set": format!("exercises[{key}]"), "value": def }));
    }
    edits.push(serde_json::json!({
        "set": format!("workouts[{new_id}]"),
        "value": {
            "name": workout.name,
            "exercises": workout.exercises,
            "rotation": true,
            "notes": workout.notes,
            "from_library": workout.from_library,
            "groups": workout.groups,
        }
    }));
    Some(edits)
}
