//! The one-time move of an account's stored events from before programs to
//! now: run by the server over every account (`src/db/migrate.rs`), after
//! which phones pull the moved log again.
//!
//! - Exercises were enum numbers; they are the built-in program's keys.
//! - Templates were their own facts (`TemplateSaved`, `TemplateDeleted`,
//!   `TemplatesReordered`, `LibraryTemplatesAdded`, and `Onboarded`'s
//!   library entries). They are folded as they were — library coupling
//!   resolved against the library built in, which is what the person saw —
//!   and become one `ProgramSet` (the built-in rules with those workouts,
//!   author `migration`) where the first of them was.
//! - Seqs are renumbered from 1.
//!
//! The input is the stored JSON, as it was; the output, events as they are
//! now. An event that would not read even moved is dropped, as the old fold
//! dropped it.

use serde_json::{Map, Value};

use crate::events::{Event, Fact, ProgramSet};
use crate::ids::{derived_id, Ids};
use crate::program::{Program, ProgramRef, WorkoutDef};

/// Who a moved program says set it.
pub const AUTHOR: &str = "migration";

/// The exercises' enum numbers (`EXERCISE_*` in the protos before
/// programs) and the keys they became.
const ENUM_KEYS: [(i64, &str); 76] = [
    (1, "squat"),
    (2, "bench_press"),
    (3, "deadlift"),
    (4, "overhead_press"),
    (5, "barbell_row"),
    (6, "hip_thrust"),
    (7, "bulgarian_split_squat"),
    (8, "romanian_deadlift"),
    (9, "glute_bridge"),
    (10, "lunge"),
    (11, "leg_curl"),
    (12, "incline_bench_press"),
    (13, "dumbbell_bench_press"),
    (14, "incline_dumbbell_press"),
    (15, "dumbbell_fly"),
    (16, "cable_fly"),
    (17, "push_up"),
    (18, "chest_dip"),
    (19, "machine_chest_press"),
    (20, "pec_deck"),
    (21, "pull_up"),
    (22, "chin_up"),
    (23, "lat_pulldown"),
    (24, "seated_cable_row"),
    (25, "dumbbell_row"),
    (26, "t_bar_row"),
    (27, "pendlay_row"),
    (28, "face_pull"),
    (29, "shrug"),
    (30, "back_extension"),
    (31, "dumbbell_shoulder_press"),
    (32, "arnold_press"),
    (33, "lateral_raise"),
    (34, "front_raise"),
    (35, "rear_delt_fly"),
    (36, "upright_row"),
    (37, "barbell_curl"),
    (38, "dumbbell_curl"),
    (39, "hammer_curl"),
    (40, "preacher_curl"),
    (41, "concentration_curl"),
    (42, "cable_curl"),
    (43, "tricep_pushdown"),
    (44, "overhead_tricep_extension"),
    (45, "skull_crusher"),
    (46, "close_grip_bench_press"),
    (47, "tricep_dip"),
    (48, "tricep_kickback"),
    (49, "front_squat"),
    (50, "leg_press"),
    (51, "leg_extension"),
    (52, "hack_squat"),
    (53, "goblet_squat"),
    (54, "walking_lunge"),
    (55, "step_up"),
    (56, "calf_raise"),
    (57, "seated_calf_raise"),
    (58, "nordic_curl"),
    (59, "good_morning"),
    (60, "glute_kickback"),
    (61, "sumo_deadlift"),
    (62, "sumo_squat"),
    (63, "curtsy_lunge"),
    (64, "frog_pump"),
    (65, "single_leg_hip_thrust"),
    (66, "cable_pull_through"),
    (67, "hip_abduction"),
    (68, "plank"),
    (69, "hanging_leg_raise"),
    (70, "cable_crunch"),
    (71, "russian_twist"),
    (72, "ab_wheel_rollout"),
    (73, "sit_up"),
    (74, "crunch"),
    (75, "mountain_climber"),
    (76, "hip_adduction"),
];

fn key_of(n: i64) -> Option<&'static str> {
    ENUM_KEYS.iter().find(|(i, _)| *i == n).map(|(_, k)| *k)
}

/// Every `exercise` and `exercises` number in `value`, as its key; an
/// unknown number (0, unspecified) is dropped from a list and empty alone.
fn keys_for_numbers(value: &mut Value) {
    match value {
        Value::Object(map) => {
            for (field, inner) in map.iter_mut() {
                match (field.as_str(), &mut *inner) {
                    ("exercise", Value::Number(n)) => {
                        let key = n.as_i64().and_then(key_of).unwrap_or("");
                        *inner = Value::String(key.to_string());
                    }
                    ("exercises", Value::Array(items)) => {
                        let keys: Vec<Value> = items
                            .iter()
                            .filter_map(|v| match v {
                                Value::Number(n) => n.as_i64().and_then(key_of),
                                _ => None,
                            })
                            .map(|k| Value::String(k.to_string()))
                            .collect();
                        if items.iter().all(Value::is_number) {
                            *items = keys;
                        }
                    }
                    _ => keys_for_numbers(inner),
                }
            }
        }
        Value::Array(items) => items.iter_mut().for_each(keys_for_numbers),
        _ => {}
    }
}

/// A template as the old fold kept it.
#[derive(Clone, Debug)]
struct Template {
    id: String,
    name: String,
    exercises: Vec<String>,
    order: i64,
    created_at: i64,
    library_id: String,
    coupled: bool,
    in_rotation: bool,
    origin_library_id: String,
}

fn text(v: &Value, field: &str) -> String {
    v.get(field)
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string()
}

fn keys(v: &Value, field: &str) -> Vec<String> {
    v.get(field)
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(|e| e.as_str().map(str::to_string))
                .collect()
        })
        .unwrap_or_default()
}

/// The old fold's templates: one change at a time, as `Account::apply`
/// made it before programs.
#[derive(Default)]
struct Templates {
    list: Vec<Template>,
}

impl Templates {
    fn sort(&mut self) {
        self.list.sort_by_key(|t| (t.order, t.created_at));
    }

    fn get(&self, id: &str) -> Option<&Template> {
        self.list.iter().find(|t| t.id == id)
    }

    /// Create (empty id) or update, as the old `save_template` did.
    fn save(&mut self, mut t: Template, at: i64, ids: &mut Ids) -> bool {
        if t.name.trim().is_empty() || t.exercises.is_empty() {
            return false;
        }
        if t.id.is_empty() {
            t.id = ids.new_id();
            t.created_at = at;
            t.order = self.list.iter().map(|x| x.order + 1).max().unwrap_or(0);
        } else if let Some(existing) = self.get(&t.id) {
            t.created_at = existing.created_at;
            t.order = existing.order;
        } else {
            t.created_at = at;
        }
        self.list.retain(|x| x.id != t.id);
        self.list.push(t);
        self.sort();
        true
    }

    fn library_copy(entry: &Value, in_rotation: bool) -> Template {
        Template {
            id: String::new(),
            name: text(entry, "name"),
            exercises: keys(entry, "exercises"),
            order: 0,
            created_at: 0,
            library_id: text(entry, "id"),
            coupled: true,
            in_rotation,
            origin_library_id: text(entry, "id"),
        }
    }

    /// One stored template fact (exercises already keys), applied.
    fn apply(&mut self, kind: &str, body: &Value, event_id: &str, at: i64) {
        let mut ids = Ids::new(event_id);
        match kind {
            "Onboarded" => {
                if !self.list.is_empty() {
                    return;
                }
                if let Some(entries) = body.get("library_entries").and_then(Value::as_array) {
                    for entry in entries {
                        self.save(Self::library_copy(entry, true), at, &mut ids);
                    }
                }
            }
            "LibraryTemplatesAdded" => {
                let in_rotation = body
                    .get("in_rotation")
                    .and_then(Value::as_bool)
                    .unwrap_or(false);
                if let Some(entries) = body.get("entries").and_then(Value::as_array) {
                    for entry in entries {
                        let id = text(entry, "id");
                        if self.list.iter().any(|t| t.library_id == id) {
                            continue;
                        }
                        self.save(Self::library_copy(entry, in_rotation), at, &mut ids);
                    }
                }
            }
            "TemplateSaved" => {
                let saved = body.get("template").cloned().unwrap_or(Value::Null);
                let unlink = body.get("unlink").and_then(Value::as_bool).unwrap_or(false);
                let mut t = Template {
                    id: text(&saved, "id"),
                    name: text(&saved, "name"),
                    exercises: keys(&saved, "exercises"),
                    order: 0,
                    created_at: 0,
                    library_id: String::new(),
                    coupled: false,
                    in_rotation: saved
                        .get("in_rotation")
                        .and_then(Value::as_bool)
                        .unwrap_or(false),
                    origin_library_id: String::new(),
                };
                let keeps = self.get(&t.id).filter(|existing| {
                    !unlink
                        && existing.coupled
                        && existing.name == t.name
                        && existing.exercises == t.exercises
                });
                if let Some(existing) = keeps {
                    t.coupled = true;
                    t.library_id = existing.library_id.clone();
                }
                t.origin_library_id = self
                    .get(&t.id)
                    .map(|x| x.origin_library_id.clone())
                    .unwrap_or_default();
                self.save(t, at, &mut ids);
            }
            "TemplateDeleted" => {
                let id = text(body, "template_id");
                self.list.retain(|t| t.id != id);
            }
            "TemplatesReordered" => {
                let count = body.get("rotation_count").and_then(Value::as_i64);
                if count.is_some_and(|n| n < 0) {
                    return;
                }
                let order: Vec<String> = body
                    .get("template_ids")
                    .and_then(Value::as_array)
                    .map(|ids| {
                        ids.iter()
                            .filter_map(|i| i.as_str().map(str::to_string))
                            .collect()
                    })
                    .unwrap_or_default();
                for (n, id) in order.iter().enumerate() {
                    if let Some(t) = self.list.iter_mut().find(|t| &t.id == id) {
                        t.order = n as i64;
                        if let Some(count) = count {
                            t.in_rotation = (n as i64) < count;
                        }
                    }
                }
                self.sort();
            }
            _ => {}
        }
    }

    /// The templates as the person last saw them, as the program's
    /// workouts: a coupled one shows its library entry as it is now.
    fn workouts(&self, program: &Program) -> Vec<WorkoutDef> {
        let library = crate::template_library::library();
        self.list
            .iter()
            .filter_map(|t| {
                let (name, exercises) =
                    match library.iter().find(|e| t.coupled && e.id == t.library_id) {
                        Some(entry) => (entry.name.clone(), entry.exercises.clone()),
                        None => (t.name.clone(), t.exercises.clone()),
                    };
                let mut known: Vec<String> = Vec::new();
                for key in exercises {
                    if program.knows(&key) && !known.contains(&key) {
                        known.push(key);
                    }
                }
                let name = name.trim().chars().take(60).collect::<String>();
                (!known.is_empty() && !name.is_empty()).then(|| WorkoutDef {
                    id: t.id.clone(),
                    name,
                    exercises: known,
                    rotation: t.in_rotation,
                    notes: String::new(),
                    from_library: if t.origin_library_id.is_empty() {
                        t.library_id.clone()
                    } else {
                        t.origin_library_id.clone()
                    },
                    groups: Vec::new(),
                })
            })
            .collect()
    }
}

const TEMPLATE_FACTS: [&str; 4] = [
    "TemplateSaved",
    "TemplateDeleted",
    "TemplatesReordered",
    "LibraryTemplatesAdded",
];

/// An account's stored events, oldest first, moved to now.
pub fn migrate(stored: &[Value]) -> Vec<Event> {
    let builtin = Program::builtin();
    let mut templates = Templates::default();
    let mut out: Vec<Event> = Vec::new();
    // Where the program goes: just after the first event that made a
    // template, under an id derived from it.
    let mut program_at: Option<(usize, String, i64)> = None;
    for value in stored {
        let Some(object) = value.as_object() else {
            continue;
        };
        let id = object.get("id").and_then(Value::as_str).unwrap_or_default();
        let at = object.get("at").and_then(Value::as_i64).unwrap_or(0);
        let Some((kind, body)) = object
            .iter()
            .find(|(k, _)| !matches!(k.as_str(), "seq" | "id" | "at"))
        else {
            continue;
        };
        let mut body = body.clone();
        keys_for_numbers(&mut body);
        let before = templates.list.len();
        if kind == "Onboarded" || TEMPLATE_FACTS.contains(&kind.as_str()) {
            templates.apply(kind, &body, id, at);
        }
        let made_one = templates.list.len() > before || TEMPLATE_FACTS.contains(&kind.as_str());
        let first = program_at.is_none() && made_one;
        if TEMPLATE_FACTS.contains(&kind.as_str()) {
            if first {
                program_at = Some((out.len(), derived_id(id, 1000), at));
            }
            continue;
        }
        if kind == "Onboarded" {
            if let Some(map) = body.as_object_mut() {
                map.remove("library_entries");
            }
        }
        let mut moved = Map::new();
        moved.insert("seq".into(), Value::from(0));
        moved.insert("id".into(), Value::from(id));
        moved.insert("at".into(), Value::from(at));
        moved.insert(kind.clone(), body);
        if let Ok(event) = serde_json::from_value::<Event>(Value::Object(moved)) {
            if !matches!(event.fact, Fact::Unknown(_)) {
                out.push(event);
            }
        }
        if first {
            program_at = Some((out.len(), derived_id(id, 1000), at));
        }
    }
    if let Some((index, id, at)) = program_at {
        let workouts = templates.workouts(&builtin);
        let event = Event {
            seq: 0,
            id,
            at,
            fact: Fact::ProgramSet(ProgramSet {
                program: ProgramRef::new(builtin.with_workouts(workouts)),
                author: AUTHOR.to_string(),
                note: String::new(),
            }),
        };
        out.insert(index.min(out.len()), event);
    }
    for (n, event) in out.iter_mut().enumerate() {
        event.seq = n as i64 + 1;
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::account::Account;

    const BEFORE: &str = include_str!("../tests/testdata/stored_events_before_programs.json");

    fn before() -> Vec<Value> {
        serde_json::from_str(BEFORE).unwrap()
    }

    /// Every stored fact moves: the old corpus, one of every fact as an
    /// earlier core wrote it, reads and folds now with nothing lost but
    /// the template facts, which become the program.
    #[test]
    fn the_old_corpus_moves() {
        let stored = before();
        let moved = migrate(&stored);
        let kept = stored
            .iter()
            .filter(|v| {
                let kind = v
                    .as_object()
                    .unwrap()
                    .keys()
                    .find(|k| !matches!(k.as_str(), "seq" | "id" | "at"))
                    .unwrap()
                    .clone();
                !TEMPLATE_FACTS.contains(&kind.as_str())
            })
            .count();
        assert_eq!(
            moved.len(),
            kept + 1,
            "the template facts became one program"
        );
        assert!(moved.iter().enumerate().all(|(n, e)| e.seq == n as i64 + 1));
        let program = moved
            .iter()
            .find_map(|e| match &e.fact {
                Fact::ProgramSet(set) => Some(set),
                _ => None,
            })
            .expect("a program");
        assert_eq!(program.author, AUTHOR);
        assert!(crate::program::check(&program.program)
            .iter()
            .all(|p| !p.error));
        // It comes straight after onboarding, which made the first templates.
        assert!(matches!(moved[0].fact, Fact::Onboarded(_)));
        assert!(matches!(moved[1].fact, Fact::ProgramSet(_)));
        let account = Account::fold(&moved);
        assert!(!account.workouts.is_empty());
        for record in &account.workouts {
            for set in &record.proposed_sets {
                assert!(account.program.knows(&set.exercise), "{}", set.exercise);
            }
        }
        // Moving is a fixed point: moved events, stored, move to themselves.
        let stored_again: Vec<Value> = moved
            .iter()
            .map(|e| serde_json::to_value(e).unwrap())
            .collect();
        assert_eq!(migrate(&stored_again), moved);
    }

    /// Onboarding's library entries, coupled: the program's workouts are
    /// the library's of now, in rotation, ids as the old fold made them.
    #[test]
    fn coupled_templates_become_the_library_entries() {
        let stored: Vec<Value> = vec![serde_json::json!({
            "seq": 1, "id": "e1", "at": 5,
            "Onboarded": {"unit": 1, "library_entries": [
                {"id": "stronglifts_a", "name": "Old name", "exercises": [1, 5, 2]}
            ], "starting_weights": [{"exercise": 1, "weight_lb": 135.0}]}
        })];
        let moved = migrate(&stored);
        let Fact::ProgramSet(set) = &moved[1].fact else {
            panic!("{moved:?}");
        };
        let w = &set.program.workouts[0];
        assert_eq!(w.id, derived_id("e1", 0));
        assert_eq!(w.name, "StrongLifts A", "the library's name of now");
        assert_eq!(w.exercises, ["squat", "barbell_row", "bench_press"]);
        assert!(w.rotation);
        assert_eq!(w.from_library, "stronglifts_a");
        let account = Account::fold(&moved);
        assert_eq!(account.starting_weights.get("squat"), Some(&135.0));
    }
}
