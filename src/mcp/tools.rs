//! What an assistant can do over MCP: read the guide, the program, the
//! person's history and where each lift stands; check and run a draft
//! program; set one. Reads fold the account as the website does (the
//! core's `View`); the write is the core's `Call`, recorded by the server
//! and streamed to the person's phones like any event they made.

use serde_json::{json, Value};

use super::Mcp;
use crate::db::MAX_FEEDBACK_CHARS;
use schlift_core::account::Account;
use schlift_core::api::{Call, View};
use schlift_core::pb::{
    ExerciseDecision, GetProgramVersionRequest, MuscleGroup, PlanReasonKind, SetProgramRequest,
    SimulateProgramRequest, SimulatedEffort, ValidateProgramRequest,
};
use schlift_core::plan::Planner;
use schlift_core::program::{edit, Program, GUIDE};

/// Told to the assistant when it connects.
pub const INSTRUCTIONS: &str = "Schlift records a person's strength training. \
Their program — one JSON document — decides every workout the app plans: the \
exercises, the workouts, how each lift progresses, and every number the planner \
uses. Read the guide (read_guide) first: its Editing section is how to change a \
program. Look with get_profile, get_progress, get_program and get_history \
(list_exercises and list_library find exercises and ready-made workouts). Change it with `edits` — \
small named changes like {\"set\": \"classes.heavy.rest_seconds\", \"value\": 150} — \
not by rewriting the document; when lifts differ only in a number, give one rule \
and set each lift's `params`. simulate_program with the edits (lifts and summary \
keep the output short; maxes, your estimate of each new lift's one-rep max, make new \
lifts' first sessions realistic) to see what it prescribes. It returns a `draft` id: simulate that draft with only further edits to try more, then set_program with the draft and a one-line note to the person. \
Any set type is a program's: schemes lay out a lift's sets (top sets and back-offs, \
pyramids, AMRAP, drops, myo-reps, clusters, EMOM, effort targets) and a workout's \
groups make supersets and circuits; see the guide's `schemes`. Weights are always \
pounds. When you are done, send_feedback: one line on what was easy or hard about \
these tools.";

/// Drafts that simulate_program and validate_program checked, so a later
/// call names one (`draft`) instead of sending its edits again: an
/// assistant writes far slower than it reads. Only while the server runs,
/// like everything nobody needs after a restart; a draft gone is sent
/// again. Each is for one assistant's person and one account, and for
/// the program it was made from: once that changes, it is refused.
#[derive(Default)]
pub struct Drafts(std::sync::Mutex<std::collections::HashMap<String, Vec<Saved>>>);

pub struct Saved {
    id: String,
    /// [`base_of`] the program it was made from.
    base: String,
    doc: String,
    at: std::time::Instant,
}

/// Drafts kept per person and account, newest first.
const DRAFTS_KEPT: usize = 8;
/// How long a draft is kept.
const DRAFT_TTL: std::time::Duration = std::time::Duration::from_secs(2 * 3600);
/// People with drafts at once; past it the store starts over.
const DRAFT_ACCOUNTS: usize = 10_000;

impl Drafts {
    /// Keeps `doc`, made from a program whose [`base_of`] is `base`, and
    /// gives its id.
    fn keep(&self, key: &str, base: String, doc: String) -> String {
        use sha2::{Digest, Sha256};
        let digest = Sha256::digest(format!("{base}\n{doc}").as_bytes());
        let id: String = digest.iter().take(5).map(|b| format!("{b:02x}")).collect();
        let mut all = self
            .0
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        if all.len() >= DRAFT_ACCOUNTS && !all.contains_key(key) {
            all.clear();
        }
        let kept = all.entry(key.to_string()).or_default();
        kept.retain(|d| d.id != id && d.at.elapsed() < DRAFT_TTL);
        kept.insert(
            0,
            Saved {
                id: id.clone(),
                base,
                doc,
                at: std::time::Instant::now(),
            },
        );
        kept.truncate(DRAFTS_KEPT);
        id
    }

    /// The draft `id` (its base and document), if it is still kept.
    fn get(&self, key: &str, id: &str) -> Option<(String, String)> {
        let all = self
            .0
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        all.get(key)?
            .iter()
            .find(|d| d.id == id && d.at.elapsed() < DRAFT_TTL)
            .map(|d| (d.base.clone(), d.doc.clone()))
    }
}

/// What a draft was made from: a digest of the program as it stood.
fn base_of(program: &Program) -> String {
    use sha2::{Digest, Sha256};
    let json = serde_json::to_string(program).unwrap_or_default();
    Sha256::digest(json.as_bytes())
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect()
}

pub enum Failure {
    Unknown,
    /// Shown to the assistant as the tool's error.
    Tool(String),
    Server(String),
}

impl<E: std::fmt::Display> From<E> for Failure {
    fn from(error: E) -> Self {
        Failure::Server(error.to_string())
    }
}

fn schema(properties: Value, required: &[&str]) -> Value {
    json!({ "type": "object", "properties": properties, "required": required })
}

fn program_property() -> Value {
    json!({
        "description": "A whole program document, for a full rewrite (an object, or its JSON as a string). Built-in exercises it leaves out are added back. Usually send `edits` instead",
        "type": ["object", "string"]
    })
}

fn draft_property() -> Value {
    json!({
        "description": "A draft simulate_program or validate_program returned (its `draft`), instead of sending its edits again. With `edits` too, they apply on top of it",
        "type": "string"
    })
}

fn edits_property() -> Value {
    json!({
        "description": "Changes to the current program, applied in order, all or none. Each is {\"set\": path, \"value\": v}, {\"remove\": path} or {\"move\": path, \"before\": path-or-null}. A path is dot-separated, with exercises by key and workouts by id: classes.heavy.rest_seconds, workouts[upper_a].exercises, exercises[squat].progression, progressions.squat_lp, time_off[0].days. Setting a named item that doesn't exist adds it. See read_guide's Editing section",
        "type": "array",
        "items": { "type": "object" },
        "maxItems": schlift_core::program::edit::MAX_EDITS
    })
}

/// The tools that read or try a program and may be for someone who lets
/// the assistant's person suggest to them (`person`).
const FOR_A_PERSON: &[&str] = &[
    "get_program",
    "get_earlier_program",
    "get_profile",
    "get_history",
    "get_progress",
    "validate_program",
    "simulate_program",
    "list_exercises",
    "get_program_part",
];

/// Every tool, as `tools/list` gives them.
pub fn list() -> Vec<Value> {
    let mut tools = tools();
    for tool in &mut tools {
        if FOR_A_PERSON.contains(&tool["name"].as_str().unwrap_or_default()) {
            tool["inputSchema"]["properties"]["person"] = json!({
                "type": "string",
                "description": "Someone else's, who lets your person suggest changes to their workouts (list_people): their name or id. Without it, your person's own"
            });
        }
    }
    tools
}

fn tools() -> Vec<Value> {
    vec![
        json!({
            "name": "read_guide",
            "title": "Read the program guide",
            "description": "What a Schlift program is and every field in it: exercises, workouts, classes, progressions (estimated_max, fixed, linear, double, cycle, formula), schemes, the formula language and every planner number. Read it whole (about 7,000 tokens) before writing a program; later, `section` gives one part.",
            "inputSchema": schema(json!({
                "section": { "type": "string", "description": "One part, by its heading: editing, exercises, workouts, classes, progressions, formula, schemes, sets, calibration, equipment, example (any heading works; an unknown one lists them)" }
            }), &[]),
            "annotations": { "readOnlyHint": true },
        }),
        json!({
            "name": "get_program",
            "title": "Get the program",
            "description": "The person's current program, who set it and why, and the programs set before it. Built-in exercises the program leaves as they are aren't shown (list_exercises finds them); any key can be used in workouts.",
            "inputSchema": schema(json!({}), &[]),
            "annotations": { "readOnlyHint": true },
        }),
        json!({
            "name": "get_earlier_program",
            "title": "Get an earlier program",
            "description": "One of the programs set before the current one (an id from get_program's `earlier`): its document, who set it and why. To go back to it, set it again with set_program, keeping today's workouts.",
            "inputSchema": schema(json!({
                "id": { "type": "string", "description": "The earlier program's id" }
            }), &["id"]),
            "annotations": { "readOnlyHint": true },
        }),
        json!({
            "name": "get_profile",
            "title": "Get where they stand",
            "description": "Their unit, starting weights and hand-set weights; this week's hard sets per muscle and what is still recovering; and for every lift they have done: sessions, when last, the estimated max, and what the program plans for it next.",
            "inputSchema": schema(json!({}), &[]),
            "annotations": { "readOnlyHint": true },
        }),
        json!({
            "name": "get_history",
            "title": "Get workout history",
            "description": "Workouts, newest first: the one under way (under_way, up to the set just done), then finished ones; each lift's plan and every set's target and what was done.",
            "inputSchema": schema(json!({
                "exercise": { "type": "string", "description": "Only workouts with this exercise key, and only its sets" },
                "since_days": { "type": "integer", "minimum": 1, "description": "Only the last this many days" },
                "limit": { "type": "integer", "minimum": 1, "maximum": 200, "description": "At most this many workouts (default 20)" }
            }), &[]),
            "annotations": { "readOnlyHint": true },
        }),
        json!({
            "name": "get_progress",
            "title": "Get progress over time",
            "description": "Each lift's finished sessions, oldest first: date, top working set, sets, volume and the estimated max after it (a rep max for bodyweight lifts). The numbers the app's progress screen draws.",
            "inputSchema": schema(json!({
                "exercise": { "type": "string", "description": "Only this exercise key" },
                "since_days": { "type": "integer", "minimum": 1, "description": "Only the last this many days" }
            }), &[]),
            "annotations": { "readOnlyHint": true },
        }),
        json!({
            "name": "validate_program",
            "title": "Check a draft program",
            "description": "Every problem with a draft (edits to the current program, or a whole document), each with its path (workouts[upper_a].exercises[2]). A draft with an error can't be set; warnings are advice. A clean one comes back with a `draft` id. simulate_program and set_program check too, so this is only needed on its own.",
            "inputSchema": schema(json!({ "edits": edits_property(), "draft": draft_property(), "program": program_property() }), &[]),
            "annotations": { "readOnlyHint": true },
        }),
        json!({
            "name": "simulate_program",
            "title": "Run a draft program",
            "description": "What a draft (edits to the current program, a whole document, or with neither the current program) prescribes, without setting it: its past workouts planned again as of just before each, beside what was planned and done; and the next sessions, each done as `effort` says, through the app's own rules (warmups, the calibration ramp, the time budget), with how long each took. Its problems too. Use summary: true and lifts to keep it short; give maxes for lifts never done. A clean run comes back with a `draft` id: set_program takes it, and further simulate_program calls take it with more edits on top.",
            "inputSchema": schema(json!({
                "edits": edits_property(),
                "draft": draft_property(),
                "program": program_property(),
                "sessions": { "type": "integer", "minimum": 0, "maximum": 60, "description": "Workouts forward from now (default 6)" },
                "every_days": { "type": "integer", "minimum": 1, "maximum": 14, "description": "Days between them (default 2)" },
                "effort": { "type": "string", "enum": ["all_hit", "last_set_short", "all_short", "miss_every"], "description": "How each forward session goes (default all_hit)" },
                "miss_every": { "type": "integer", "minimum": 1, "description": "With miss_every: every this many sessions, the last set one rep short" },
                "template_id": { "type": "string", "description": "Do this workout every time; otherwise the rotation's suggestion" },
                "exercises": { "type": "array", "items": { "type": "string" }, "description": "Instead of a workout, these exercise keys in this order every time. With no workout to pick, the lifts of their last workout are used" },
                "budget_minutes": { "type": "integer", "minimum": 5, "maximum": 300 },
                "history": { "type": "integer", "minimum": 0, "maximum": 60, "description": "Past workouts to plan again (default 6)" },
                "lifts": { "type": "array", "items": { "type": "string" }, "description": "Show only these exercise keys (the workouts still run whole)" },
                "summary": { "type": "boolean", "description": "Per lift, one short line a session (plan, the max it planned from, what was planned then, what was done set by set; a new lift's ramp rungs) and each workout's minutes, instead of every field" },
                "maxes": { "type": "object", "additionalProperties": { "type": "number", "exclusiveMinimum": 0 }, "description": "Lifts never done ramp up on their first session; the simulated lifter otherwise settles at an arbitrary weight. Give its estimated one-rep max (lb; reps for a bodyweight lift) per exercise key, e.g. {\"incline_dumbbell_press\": 70}, and the ramp settles where it would for someone that strong (as far as the program's ramp can climb). Bodyweight lifts don't ramp. Give them on each call" }
            }), &[]),
            "annotations": { "readOnlyHint": true },
        }),
        json!({
            "name": "set_program",
            "title": "Set the program",
            "description": "Make a draft the person's program (the `draft` id simulate_program gave, edits to the current program, or a whole document): it plans every workout from the next one on (none already done changes) and reaches their phone at once. Refused, with its problems, if it has an error. Earlier programs stay in their history.",
            "inputSchema": schema(json!({
                "edits": edits_property(),
                "draft": draft_property(),
                "program": program_property(),
                "note": { "type": "string", "maxLength": 300, "description": "One line, to the person, on why" }
            }), &["note"]),
            "annotations": { "readOnlyHint": false, "destructiveHint": false, "idempotentHint": false },
        }),
        json!({
            "name": "list_exercises",
            "title": "Find exercises",
            "description": "Exercises the program can use, built-in and its own: key, name, equipment, muscles (primary first), class, whether built in, which workouts use it, and any progression, params, scheme, measure, per_side or tempo it sets (left out when it doesn't). Filter by muscle, equipment (one or several), a name fragment or keys.",
            "inputSchema": schema(json!({
                "muscle": { "type": "string", "enum": ["chest", "back", "shoulders", "biceps", "triceps", "quads", "hamstrings", "glutes", "calves", "core"], "description": "Trains this muscle" },
                "primary_only": { "type": "boolean", "description": "With muscle: only lifts where it is the primary mover" },
                "equipment": {
                    "description": "Uses this equipment, or any of these (a home gym without cables or machines: [\"barbell\", \"dumbbell\", \"bodyweight\"])",
                    "anyOf": [
                        { "type": "string", "enum": ["barbell", "dumbbell", "machine", "cable", "bodyweight"] },
                        { "type": "array", "items": { "type": "string", "enum": ["barbell", "dumbbell", "machine", "cable", "bodyweight"] } }
                    ]
                },
                "query": { "type": "string", "description": "Name contains this (any case)" },
                "keys": { "type": "array", "items": { "type": "string" }, "description": "Exactly these keys" },
                "limit": { "type": "integer", "minimum": 1, "maximum": 100, "description": "At most this many (default 30)" }
            }), &[]),
            "annotations": { "readOnlyHint": true },
        }),
        json!({
            "name": "list_library",
            "title": "Ready-made workouts",
            "description": "Schlift's workout library: workouts (id, name, group, blurb, exercise keys) and plans (a named rotation of them). To use one, add it with an edit: {\"set\": \"workouts[<new id>]\", \"value\": {\"name\": ..., \"exercises\": [...], \"from_library\": \"<library id>\"}}.",
            "inputSchema": schema(json!({}), &[]),
            "annotations": { "readOnlyHint": true },
        }),
        json!({
            "name": "get_program_part",
            "title": "Get part of the program",
            "description": "One path of the current program, when only that is needed: classes, progressions, workouts, workouts[upper_a], sets, equipment.barbell.",
            "inputSchema": schema(json!({
                "path": { "type": "string", "description": "As in edits: classes.heavy, workouts[a].exercises" }
            }), &["path"]),
            "annotations": { "readOnlyHint": true },
        }),
        json!({
            "name": "list_people",
            "title": "People you can suggest to",
            "description": "The friends who let your person suggest changes to their workouts: name and id. Pass one as `person` to read their training and try a change, then suggest_change.",
            "inputSchema": schema(json!({}), &[]),
            "annotations": { "readOnlyHint": true },
        }),
        json!({
            "name": "suggest_change",
            "title": "Suggest a change to someone's program",
            "description": "Send edits (as set_program takes them) to someone who lets your person suggest: they see it as a suggestion from your person, with your note, and accept or decline it. Nothing changes for them until they accept. Try it first with simulate_program and the same `person`.",
            "inputSchema": schema(json!({
                "person": { "type": "string", "description": "Their name or id (list_people)" },
                "edits": edits_property(),
                "note": { "type": "string", "maxLength": 300, "description": "One line, to them, on why" },
                "title": { "type": "string", "maxLength": 60, "description": "What to call it in their list: the workout's name, or the change's" }
            }), &["person", "edits", "note"]),
            "annotations": { "readOnlyHint": false, "destructiveHint": false, "idempotentHint": false },
        }),
        json!({
            "name": "send_feedback",
            "title": "Say how the tools went",
            "description": "One line (at most 144 characters) on what was easy, hard or missing in these tools, for the people who make them. About the tools, never about the person. Send one when a task is done.",
            "inputSchema": schema(json!({
                "text": { "type": "string", "minLength": 1, "maxLength": 144 },
                "tool": { "type": "string", "description": "The tool it is mostly about, if one" }
            }), &["text"]),
            "annotations": { "readOnlyHint": false, "destructiveHint": false, "idempotentHint": false },
        }),
    ]
}

fn text(value: &Value) -> Value {
    let mut value = value.clone();
    tidy_numbers(&mut value);
    json!({
        "content": [{ "type": "text", "text": value.to_string() }],
        "structuredContent": value,
    })
}

/// A program's numbers are f32: shown as f64 they read 1.100000023841858.
/// Each fraction is written as the f32 it is (1.1), which reads back to
/// the same f32, so a value copied into an edit means what it did.
fn tidy_numbers(value: &mut Value) {
    match value {
        Value::Number(n) if n.is_f64() => {
            if let Some(x) = n.as_f64() {
                if x.fract() != 0.0 && x.abs() < 1e7 {
                    let short: f64 = (x as f32).to_string().parse().unwrap_or(x);
                    if let Some(tidy) = serde_json::Number::from_f64(short) {
                        *n = tidy;
                    }
                }
            }
        }
        Value::Array(items) => items.iter_mut().for_each(tidy_numbers),
        Value::Object(fields) => fields.values_mut().for_each(tidy_numbers),
        _ => {}
    }
}

/// The draft a write tool was given, as a whole document: `edits` applied
/// to the current program (or on top of a kept `draft`), a kept `draft`
/// as it is, or a `program` with any built-in exercises it leaves out put
/// back. With none, "" (the current program, where a tool allows that).
/// Also how many edits applied.
fn draft(
    account: &Account,
    arguments: &Value,
    drafts: &Drafts,
    key: &str,
) -> Result<(String, usize), Failure> {
    let named = match arguments.get("draft") {
        None | Some(Value::Null) => None,
        Some(Value::String(id)) if !id.trim().is_empty() => Some(id.trim()),
        Some(_) => {
            return Err(Failure::Tool(
                "draft is the id a simulate_program gave".into(),
            ))
        }
    };
    let edits = arguments.get("edits");
    if named.is_some() && arguments.get("program").is_some() {
        return Err(Failure::Tool(
            "send a draft (with edits on top, if any) or a whole program, not both".into(),
        ));
    }
    let base: Option<Program> = match named {
        None => None,
        Some(id) => {
            let Some((made_from, doc)) = drafts.get(key, id) else {
                return Err(Failure::Tool(format!(
                    "no draft {id:?}: drafts last two hours, while the server runs. Send the edits again"
                )));
            };
            if made_from != base_of(&account.program) {
                return Err(Failure::Tool(format!(
                    "the program changed since draft {id:?} was made (in the app, or by another assistant). get_program, then send the edits again"
                )));
            }
            if edits.is_none() {
                return Ok((doc, 0));
            }
            Some(Program::parse(&doc).map_err(|e| Failure::Server(e.to_string()))?)
        }
    };
    let current = base.as_ref().unwrap_or(&account.program);
    match (edits, arguments.get("program")) {
        (Some(_), Some(_)) => Err(Failure::Tool(
            "send edits or a whole program, not both".into(),
        )),
        (Some(Value::Array(edits)), None) => {
            let doc = edit::apply(current, edits).map_err(|e| {
                Failure::Tool(
                    serde_json::to_string_pretty(&json!({
                        "applied": 0,
                        "changed": "nothing: edits apply all or none",
                        "failed_edit": e.index,
                        "path": e.path,
                        "problem": e.message,
                    }))
                    .unwrap_or_default(),
                )
            })?;
            Ok((doc.to_string(), edits.len()))
        }
        (Some(_), None) => Err(Failure::Tool("edits is a list of edits".into())),
        (None, Some(Value::String(s))) => {
            let doc: Value = serde_json::from_str(s)
                .map_err(|e| Failure::Tool(format!("program is not JSON: {e}")))?;
            Ok((edit::complete(doc).to_string(), 0))
        }
        (None, Some(v @ Value::Object(_))) => Ok((edit::complete(v.clone()).to_string(), 0)),
        (None, Some(_)) => Err(Failure::Tool(
            "program is an object, or its JSON as a string".into(),
        )),
        (None, None) => Ok((String::new(), 0)),
    }
}

/// A program as an assistant sees it ([`edit::compact`]), with a word on
/// what was left out.
fn shown(program: &Program) -> (Value, Value) {
    let (doc, left_out) = edit::compact(program);
    let note = json!(format!(
        "{left_out} built-in exercises, unchanged, aren't shown; list_exercises finds them, and any key can go in a workout"
    ));
    (doc, note)
}

fn int(arguments: &Value, name: &str, default: i64, lo: i64, hi: i64) -> i32 {
    arguments
        .get(name)
        .and_then(Value::as_i64)
        .unwrap_or(default)
        .clamp(lo, hi) as i32
}

fn muscle_name(m: i32) -> String {
    MuscleGroup::try_from(m)
        .map(|m| {
            m.as_str_name()
                .trim_start_matches("MUSCLE_GROUP_")
                .to_lowercase()
        })
        .unwrap_or_default()
}

/// A day as `2026-11-22` (UTC).
fn date(unix: i64) -> String {
    // Days to civil date (Howard Hinnant's algorithm).
    let z = unix.div_euclid(86_400) + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let day = doy - (153 * mp + 2) / 5 + 1;
    let month = if mp < 10 { mp + 3 } else { mp - 9 };
    let year = yoe + era * 400 + i64::from(month <= 2);
    format!("{year:04}-{month:02}-{day:02}")
}

fn round(x: f32) -> f64 {
    (f64::from(x) * 10.0).round() / 10.0
}

/// A planned set in a few characters: `top 5 @ 100%`, `drop @ 64%`,
/// `working 8+ @ 90% rir 2`, `working 5 every 60s`.
fn planned_set(p: &schlift_core::pb::PlannedSet, lift_reps: i32) -> String {
    let role = match schlift_core::pb::SetRole::try_from(p.role) {
        Ok(schlift_core::pb::SetRole::Unspecified) | Err(_) => "working".to_string(),
        Ok(r) => r
            .as_str_name()
            .trim_start_matches("SET_ROLE_")
            .to_lowercase(),
    };
    let reps = if p.reps > 0 { p.reps } else { lift_reps };
    let mut out = format!(
        "{role} {reps}{} @ {}%",
        if p.amrap { "+" } else { "" },
        (if p.fraction > 0.0 { p.fraction } else { 1.0 } * 100.0).round()
    );
    if let Some(rir) = p.rir {
        out.push_str(&format!(" rir {rir}"));
    }
    if p.every_seconds > 0 {
        out.push_str(&format!(" every {}s", p.every_seconds));
    }
    out
}

fn plan(d: &ExerciseDecision) -> Value {
    let measure = match schlift_core::pb::Measure::try_from(d.measure) {
        Ok(schlift_core::pb::Measure::Seconds) => "seconds",
        Ok(schlift_core::pb::Measure::Metres) => "metres",
        _ => "reps",
    };
    json!({
        "sets": d.sets,
        "reps": d.reps,
        "measure": measure,
        "per_side": d.per_side,
        "tempo": d.tempo,
        "scheme": if d.scheme.is_empty() { "straight" } else { d.scheme.as_str() },
        "sets_one_by_one": d.scheme_sets.iter().map(|p| planned_set(p, d.reps)).collect::<Vec<_>>(),
        "group": d.group,
        "weight_lb": round(d.weight),
        "rest_seconds": d.rest_seconds,
        "warmups": d.warmups,
        "calibration_ramp": d.calibration,
        "progression": d.progression,
        "kind": d.progression_kind,
        "estimated_max": round(d.max),
        "why": d.reasons.iter().map(|r| {
            let kind = PlanReasonKind::try_from(r.kind)
                .map(|k| k.as_str_name().trim_start_matches("PLAN_REASON_KIND_").to_lowercase())
                .unwrap_or_default();
            if r.text.is_empty() { kind } else { format!("{kind}: {}", r.text) }
        }).collect::<Vec<_>>(),
    })
}

pub async fn call(
    mcp: &Mcp,
    user_id: &str,
    client_name: &str,
    name: &str,
    arguments: &Value,
) -> Result<Value, Failure> {
    let now = crate::time::now_unix();
    // Whose account a reading tool reads: the person's own, or someone who
    // lets them suggest, checked on every call.
    let person = arguments
        .get("person")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|p| !p.is_empty());
    let whose =
        match person {
            Some(p) if FOR_A_PERSON.contains(&name) => resolve_person(mcp, user_id, p).await?.0,
            Some(_) if name == "set_program" => return Err(Failure::Tool(
                "set_program changes your person's own program; for someone else's, suggest_change"
                    .into(),
            )),
            _ => user_id.to_string(),
        };
    let whose = whose.as_str();
    // Drafts are this assistant's person's, for this account.
    let draft_key = format!("{user_id}>{whose}");
    match name {
        "read_guide" => {
            let text = match arguments.get("section").and_then(Value::as_str) {
                Some(section) if !section.trim().is_empty() => guide_section(section),
                _ => GUIDE.to_string(),
            };
            Ok(json!({ "content": [{ "type": "text", "text": text }] }))
        }
        "get_program" => {
            let (got, (program, note)) = mcp
                .db
                .read_account(whose, move |a| {
                    (View::new(a, now).get_program(), shown(&a.program))
                })
                .await?;
            let summary = |s: &schlift_core::pb::ProgramSummary| json!({ "id": s.id, "name": s.name, "author": s.author, "note": s.note, "set_on": if s.set_at > 0 { date(s.set_at) } else { String::new() } });
            Ok(text(&json!({
                "current": got.summary.as_ref().map(summary),
                "earlier": got.history.iter().map(summary).collect::<Vec<_>>(),
                "exercises_note": note,
                "program": program,
            })))
        }
        "get_earlier_program" => {
            let id = arguments
                .get("id")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_string();
            let got = mcp
                .db
                .read_account(whose, move |a| {
                    View::new(a, now).get_program_version(GetProgramVersionRequest { id })
                })
                .await?
                .map_err(|_| Failure::Tool("No earlier program has that id".into()))?;
            let s = got.summary.unwrap_or_default();
            let (program, note) = match Program::parse(&got.program_json) {
                Ok(p) => shown(&p),
                Err(_) => (
                    serde_json::from_str(&got.program_json).unwrap_or(Value::Null),
                    Value::Null,
                ),
            };
            Ok(text(&json!({
                "id": s.id,
                "name": s.name,
                "author": s.author,
                "note": s.note,
                "set_on": date(s.set_at),
                "exercises_note": note,
                "program": program,
            })))
        }
        "get_profile" => {
            let profile = mcp.db.read_account(whose, move |a| profile(a, now)).await?;
            Ok(text(&profile))
        }
        "get_history" => {
            let exercise = arguments
                .get("exercise")
                .and_then(Value::as_str)
                .map(str::to_string);
            let since = arguments
                .get("since_days")
                .and_then(Value::as_i64)
                .map(|d| now - d.clamp(1, 3650) * 86_400);
            let limit = int(arguments, "limit", 20, 1, 200) as usize;
            let history = mcp
                .db
                .read_account(whose, move |a| {
                    history(a, exercise.as_deref(), since, limit, now)
                })
                .await?;
            Ok(text(&history))
        }
        "validate_program" => {
            let args = arguments.clone();
            let drafts = mcp.drafts.clone();
            let key = draft_key.clone();
            let (checked, applied, id) = mcp
                .db
                .read_account(whose, move |a| -> Result<_, Failure> {
                    let (program_json, applied) = draft(a, &args, &drafts, &key)?;
                    if program_json.is_empty() {
                        return Err(Failure::Tool("send edits or a program to check".into()));
                    }
                    let checked = View::new(a, now).validate_program(ValidateProgramRequest {
                        program_json: program_json.clone(),
                    })?;
                    let id = (!checked.problems.iter().any(|p| p.error))
                        .then(|| drafts.keep(&key, base_of(&a.program), program_json));
                    Ok((checked, applied, id))
                })
                .await??;
            let mut out = json!({
                "ok": !checked.problems.iter().any(|p| p.error),
                "applied": applied,
                "problems": problems(&checked.problems),
            });
            if let Some(id) = id {
                out["draft"] = json!(id);
            }
            Ok(text(&out))
        }
        "simulate_program" => {
            let effort = match arguments.get("effort").and_then(Value::as_str) {
                None | Some("all_hit") => SimulatedEffort::AllHit,
                Some("last_set_short") => SimulatedEffort::LastSetShort,
                Some("all_short") => SimulatedEffort::AllShort,
                Some("miss_every") => SimulatedEffort::MissEvery,
                Some(other) => return Err(Failure::Tool(format!("no effort {other:?}"))),
            };
            let mut request = SimulateProgramRequest {
                program_json: String::new(),
                sessions: int(arguments, "sessions", 6, 0, 60),
                every_days: int(arguments, "every_days", 2, 1, 14),
                effort: effort as i32,
                miss_every: int(arguments, "miss_every", 3, 1, 60),
                template_id: arguments
                    .get("template_id")
                    .and_then(Value::as_str)
                    .unwrap_or_default()
                    .to_string(),
                budget_minutes: int(arguments, "budget_minutes", 0, 0, 300),
                history: int(arguments, "history", 6, 0, 60),
                exercises: strings(arguments, "exercises").unwrap_or_default(),
            };
            let maxes = maxes(arguments)?;
            let maxes_given: Vec<String> = maxes.keys().cloned().collect();
            let args = arguments.clone();
            let drafts = mcp.drafts.clone();
            let key = draft_key.clone();
            let ((run, details), applied, id) = mcp
                .db
                .read_account(whose, move |a| -> Result<_, Failure> {
                    let (program_json, applied) = draft(a, &args, &drafts, &key)?;
                    request.program_json = program_json;
                    let run = schlift_core::simulate::simulate_detailed(a, now, &request, &maxes);
                    let id = (!request.program_json.is_empty()
                        && !run.0.problems.iter().any(|p| p.error))
                    .then(|| drafts.keep(&key, base_of(&a.program), request.program_json.clone()));
                    Ok((run, applied, id))
                })
                .await??;
            // The forward workouts are the last ones, in order.
            let first_forward = run.workouts.len() - details.len();
            let detail = |i: usize| i.checked_sub(first_forward).and_then(|i| details.get(i));
            if run.problems.iter().any(|p| p.error) {
                return Err(Failure::Tool(
                    serde_json::to_string_pretty(&json!({
                        "applied": applied,
                        "problems": problems(&run.problems),
                    }))
                    .unwrap_or_default(),
                ));
            }
            let only: Option<Vec<String>> = strings(arguments, "lifts");
            let shown = |key: &str| only.as_ref().is_none_or(|o| o.iter().any(|k| k == key));
            let notes = run_notes(&run.workouts, &details, &maxes_given);
            if arguments
                .get("summary")
                .and_then(Value::as_bool)
                .unwrap_or(false)
            {
                let ramped = details
                    .iter()
                    .flat_map(|d| &d.lifts)
                    .any(|l| !l.ramp.is_empty() && !maxes_given.contains(&l.exercise));
                let mut out = json!({
                    "applied": applied,
                    "draft": id,
                    "workouts": run.workouts.iter().enumerate().filter_map(|(i, w)| detail(i).map(|d| {
                        let mut line = format!("{} {} · {} min", date(w.at), w.name, d.minutes);
                        let budget = budget_of(w);
                        if budget > 0 && d.minutes > budget {
                            line.push_str(&format!(" (over its {budget}-min budget)"));
                        }
                        line
                    })).collect::<Vec<_>>(),
                    "lifts": summary(&run.workouts, &details, &shown),
                    "problems": problems(&run.problems),
                });
                if !notes.is_empty() {
                    out["notes"] = json!(notes);
                }
                if ramped {
                    out["ramp_note"] = json!(RAMP_NOTE);
                }
                return Ok(text(&out));
            }
            let workouts: Vec<Value> = run
                .workouts
                .iter()
                .enumerate()
                .map(|(i, w)| {
                    json!({
                        "date": date(w.at),
                        "past": w.past,
                        "workout": w.name,
                        "minutes": detail(i).map(|d| d.minutes),
                        "lifts": w.lifts.iter().filter(|l| shown(&l.exercise)).map(|l| json!({
                            "exercise": l.exercise,
                            "plan": l.decision.as_ref().map(plan),
                            "planned_then": l.recorded.as_ref().map(|d| json!({ "sets": d.sets, "reps": d.reps, "weight_lb": round(d.weight) })),
                            "done": { "weight_lb": round(l.done_weight), "reps": l.done_reps, "every_rep": l.hit },
                            "done_sets": detail(i).and_then(|d| d.lifts.iter().find(|x| x.exercise == l.exercise)).map(|x| json!({
                                "ramp": x.ramp.iter().map(|(w, r)| format!("{r} @ {}", round(*w))).collect::<Vec<_>>(),
                                "working": sets_done(&x.working),
                            })),
                        })).collect::<Vec<_>>(),
                    })
                })
                .collect();
            let mut out = json!({
                "applied": applied,
                "draft": id,
                "workouts": workouts,
                "problems": problems(&run.problems),
            });
            if !notes.is_empty() {
                out["notes"] = json!(notes);
            }
            Ok(text(&out))
        }
        "set_program" => {
            let mut account = mcp.db.read_account(user_id, Clone::clone).await?;
            let (program_json, applied) = draft(&account, arguments, &mcp.drafts, &draft_key)?;
            if program_json.is_empty() {
                return Err(Failure::Tool(
                    "send a draft, edits or a program to set".into(),
                ));
            }
            let note = arguments
                .get("note")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_string();
            let author = format!("mcp:{client_name}");
            let mut call = Call::new(&mut account, now, uuid::Uuid::new_v4().to_string());
            let response = call.set_program(SetProgramRequest {
                program_json,
                note,
                author,
            })?;
            let events = std::mem::take(&mut call.events);
            let Some(summary) = response.summary else {
                return Err(Failure::Tool(
                    serde_json::to_string_pretty(&json!({
                        "set": false,
                        "applied": applied,
                        "problems": problems(&response.problems),
                    }))
                    .unwrap_or_default(),
                ));
            };
            mcp.db.push_events(user_id, events).await?;
            tracing::info!(%user_id, client = client_name, program = %summary.name, "an assistant set a program");
            Ok(text(&json!({
                "set": true,
                "applied": applied,
                "program": { "id": summary.id, "name": summary.name, "note": summary.note },
                "problems": problems(&response.problems),
            })))
        }
        "get_progress" => {
            let exercise = arguments
                .get("exercise")
                .and_then(Value::as_str)
                .map(str::to_string);
            let since = arguments
                .get("since_days")
                .and_then(Value::as_i64)
                .map(|d| now - d.clamp(1, 3650) * 86_400)
                .unwrap_or(0);
            let progress = mcp
                .db
                .read_account(whose, move |a| progress(a, now, exercise.as_deref(), since))
                .await?;
            Ok(text(&progress))
        }
        "list_exercises" => {
            let args = arguments.clone();
            let found = mcp
                .db
                .read_account(whose, move |a| exercises(&a.program, &args))
                .await?;
            Ok(text(&found))
        }
        "list_library" => Ok(text(&library())),
        "get_program_part" => {
            let path = arguments
                .get("path")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_string();
            let part = mcp
                .db
                .read_account(whose, move |a| edit::part(&a.program, &path))
                .await?
                .map_err(Failure::Tool)?;
            Ok(text(&json!({ "value": part })))
        }
        "send_feedback" => {
            let feedback = arguments
                .get("text")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .trim();
            let length = feedback.chars().count();
            if length == 0 || length > MAX_FEEDBACK_CHARS {
                return Err(Failure::Tool(format!(
                    "text is 1 to {MAX_FEEDBACK_CHARS} characters; this is {length}"
                )));
            }
            let tool: String = arguments
                .get("tool")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .trim()
                .chars()
                .take(40)
                .collect();
            mcp.db
                .record_assistant_feedback(user_id, client_name, &tool, feedback)
                .await?;
            Ok(text(
                &json!({ "thanks": "Noted. It goes to the people who make these tools." }),
            ))
        }
        "list_people" => {
            let mut people = Vec::new();
            for id in mcp.db.owners_for(user_id).await? {
                if let Some(user) = mcp.db.get_user(&id).await? {
                    people.push(json!({ "name": user.name, "id": user.id }));
                }
            }
            Ok(text(&json!({ "people": people })))
        }
        "suggest_change" => {
            let person = person.ok_or_else(|| Failure::Tool("person is required".into()))?;
            let (owner, owner_name) = resolve_person(mcp, user_id, person).await?;
            let edits = match arguments.get("edits") {
                Some(Value::Array(edits)) if !edits.is_empty() => edits.clone(),
                _ => return Err(Failure::Tool("edits is a list of edits".into())),
            };
            let note = arguments
                .get("note")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_string();
            let me = mcp
                .db
                .get_user(user_id)
                .await?
                .map(|u| u.name)
                .unwrap_or_default();
            let mut account = mcp.db.read_account(&owner, Clone::clone).await?;
            // One workout set: a workout suggestion, named for it.
            let workouts: Vec<&str> = edits
                .iter()
                .filter_map(|e| e.get("set").and_then(Value::as_str))
                .filter(|p| p.starts_with("workouts["))
                .collect();
            let kind = if workouts.len() == edits.len() && !workouts.is_empty() {
                "workout"
            } else {
                "program"
            };
            let title = arguments
                .get("title")
                .and_then(Value::as_str)
                .map(str::to_string)
                .unwrap_or_else(|| account.program.name.clone());
            let mut call = Call::new(&mut account, now, uuid::Uuid::new_v4().to_string());
            call.suggest_program(schlift_core::events::ProgramSuggested {
                edits,
                note,
                kind: kind.into(),
                title,
                from: format!("person:{user_id}"),
                from_name: format!("{me} (via {client_name})"),
            })
            .map_err(|e| Failure::Tool(format!("not suggested: {e}")))?;
            let events = std::mem::take(&mut call.events);
            mcp.db.push_events(&owner, events).await?;
            tracing::info!(%user_id, %owner, client = client_name, "an assistant suggested a change");
            Ok(text(&json!({
                "suggested": true,
                "to": owner_name,
                "next": "They see it as a suggestion and accept or decline it; nothing changes for them until they do."
            })))
        }
        _ => Err(Failure::Unknown),
    }
}

/// Someone who lets `user_id` suggest to them, by name (any case) or id:
/// their id and name. Anyone else is refused.
async fn resolve_person(
    mcp: &Mcp,
    user_id: &str,
    person: &str,
) -> Result<(String, String), Failure> {
    for id in mcp.db.owners_for(user_id).await? {
        if let Some(user) = mcp.db.get_user(&id).await? {
            if user.id == person || user.name.eq_ignore_ascii_case(person) {
                return Ok((user.id, user.name));
            }
        }
    }
    Err(Failure::Tool(format!(
        "{person:?} hasn't let your person suggest changes to their workouts; list_people shows who has"
    )))
}

/// The exercises `list_exercises` finds, filtered as `arguments` say.
fn exercises(program: &Program, arguments: &Value) -> Value {
    let builtin = edit::builtin_keys();
    let get = |name: &str| arguments.get(name).and_then(Value::as_str);
    let query = get("query").map(str::to_lowercase);
    let keys: Option<Vec<&str>> = arguments
        .get("keys")
        .and_then(Value::as_array)
        .map(|k| k.iter().filter_map(Value::as_str).collect());
    let primary_only = arguments
        .get("primary_only")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    let limit = int(arguments, "limit", 30, 1, 100) as usize;
    let equipment: Option<Vec<String>> = match arguments.get("equipment") {
        Some(Value::String(one)) => Some(vec![one.clone()]),
        Some(Value::Array(_)) => strings(arguments, "equipment"),
        _ => None,
    };
    let matching: Vec<Value> = program
        .exercises
        .iter()
        .map(|e| (e, serde_json::to_value(e).unwrap_or(Value::Null)))
        .filter(|(e, _)| keys.as_ref().is_none_or(|k| k.contains(&e.key.as_str())))
        .filter(|(e, _)| {
            query.as_ref().is_none_or(|q| {
                e.name.to_lowercase().contains(q.as_str()) || e.key.contains(q.as_str())
            })
        })
        .filter(|(_, v)| {
            equipment
                .as_ref()
                .is_none_or(|eq| eq.iter().any(|e| v["equipment"] == *e))
        })
        .filter(|(_, v)| {
            get("muscle").is_none_or(|m| {
                let muscles = v["muscles"].as_array().cloned().unwrap_or_default();
                if primary_only {
                    muscles.first().is_some_and(|f| f == m)
                } else {
                    muscles.iter().any(|f| f == m)
                }
            })
        })
        .map(|(e, v)| {
            let mut out = json!({
                "key": e.key,
                "name": e.name,
                "equipment": v["equipment"],
                "muscles": v["muscles"],
                "class": e.class,
                "built_in": builtin.contains(&e.key),
            });
            // Only what the lift sets: the rest is its class's, or the default.
            let workouts: Vec<String> = program
                .workouts
                .iter()
                .filter(|w| w.exercises.contains(&e.key))
                .map(|w| w.id.clone())
                .collect();
            if !workouts.is_empty() {
                out["in_workouts"] = json!(workouts);
            }
            if let Some(progression) = &e.progression {
                out["progression"] = json!(progression);
            }
            if !e.params.is_empty() {
                out["params"] = json!(e.params);
            }
            if let Some(scheme) = &e.scheme {
                out["scheme"] = json!(scheme);
            }
            if v["measure"] != "reps" {
                out["measure"] = v["measure"].clone();
            }
            if e.per_side {
                out["per_side"] = json!(true);
            }
            if !e.tempo.is_empty() {
                out["tempo"] = json!(e.tempo);
            }
            out
        })
        .collect();
    let total = matching.len();
    json!({
        "found": total,
        "shown": total.min(limit),
        "exercises": matching.into_iter().take(limit).collect::<Vec<_>>(),
    })
}

/// The workout library and its plans, as `list_library` gives them.
fn library() -> Value {
    json!({
        "workouts": schlift_core::template_library::library().iter().map(|t| json!({
            "library_id": t.id, "name": t.name, "group": t.group_label, "blurb": t.blurb, "exercises": t.exercises,
        })).collect::<Vec<_>>(),
        "plans": schlift_core::template_library::plans().iter().map(|p| json!({
            "id": p.id, "name": p.name, "blurb": p.blurb, "workouts": p.library_ids,
        })).collect::<Vec<_>>(),
    })
}

fn problems(problems: &[schlift_core::pb::ProgramProblem]) -> Vec<Value> {
    problems
        .iter()
        .map(|p| json!({ "path": p.path, "message": p.message, "error": p.error }))
        .collect()
}

/// Where the person stands, for an assistant.
fn profile(account: &Account, now: i64) -> Value {
    let view = View::new(account, now);
    let home = view.home(0);
    let planner = Planner::new(account, now);
    let program = &account.program;
    let unit = match account.unit() {
        schlift_core::weight_units::AppWeightUnit::Kg => "kg",
        schlift_core::weight_units::AppWeightUnit::Lb => "lb",
    };
    let lifts: Vec<Value> = home
        .plans
        .iter()
        .filter(|p| p.last_performed_at > 0)
        .filter_map(|p| {
            let d = p.decision.as_ref()?;
            let walk = planner.walk(&d.exercise);
            Some(json!({
                "exercise": d.exercise,
                "name": program.exercise(&d.exercise).map(|e| e.name.clone()).unwrap_or_default(),
                "sessions": walk.points.len(),
                "last_done": date(p.last_performed_at),
                "estimated_max": walk.max.map(round),
                "last": walk.last.as_ref().map(|l| json!({ "weight_lb": round(l.weight), "reps": l.reps, "sets": l.sets })),
                "next": plan(d),
                "set_by_hand": p.overridden,
            }))
        })
        .collect();
    json!({
        "unit": unit,
        "weights_are": "pounds, whatever the unit",
        "program": home.program.as_ref().map(|s| json!({ "name": s.name, "author": s.author, "note": s.note })),
        "workouts": home.templates.iter().map(|t| json!({
            "id": t.id, "name": t.name, "exercises": t.exercises, "rotation": t.in_rotation,
        })).collect::<Vec<_>>(),
        "suggested_next": home.suggested_template_id,
        "finished_workouts": view.finished().len(),
        "starting_weights_lb": account.starting_weights,
        "set_by_hand": account.overrides.iter().map(|(k, o)| json!({
            "exercise": k, "weight_lb": round(o.weight), "reps": o.reps, "sets": o.sets, "on": date(o.at),
        })).collect::<Vec<_>>(),
        "this_week": home.volume.iter().map(|v| json!({
            "muscle": muscle_name(v.muscle), "hard_sets": round(v.completed_sets_7d), "target": [v.target_low, v.target_high],
        })).collect::<Vec<_>>(),
        "recovering": home.recovery.iter().filter(|r| !r.recovered).map(|r| json!({
            "muscle": muscle_name(r.muscle), "hours_left": r.hours_remaining,
        })).collect::<Vec<_>>(),
        "lifts": lifts,
    })
}

/// Finished workouts, newest first.
fn history(
    account: &Account,
    exercise: Option<&str>,
    since: Option<i64>,
    limit: usize,
    now: i64,
) -> Value {
    let view = View::new(account, 0);
    // The workout under way first, as far as it has got: the set just done
    // is in it (the server folds what the phone sent a moment ago).
    let workouts: Vec<Value> = account
        .active_workout()
        .into_iter()
        .chain(view.finished())
        .filter(|r| since.is_none_or(|s| r.workout.start_time >= s))
        .filter(|r| exercise.is_none_or(|e| r.proposed_sets.iter().any(|s| s.exercise == e)))
        .take(limit)
        .map(|r| {
            let mut keys: Vec<&str> = Vec::new();
            for s in &r.proposed_sets {
                if !keys.contains(&s.exercise.as_str()) && exercise.is_none_or(|e| e == s.exercise) {
                    keys.push(&s.exercise);
                }
            }
            let under_way = r.workout.end_time == 0;
            let end = if under_way { now } else { r.workout.end_time };
            json!({
                "id": r.workout.id,
                "date": date(r.workout.start_time),
                "name": r.workout.name,
                "under_way": under_way,
                "minutes": (end - r.workout.start_time) / 60,
                "workout_id": r.workout.template_id,
                "lifts": keys.iter().map(|key| {
                    let planned = r.decision(key);
                    let sets: Vec<Value> = r.proposed_sets.iter()
                        .filter(|s| s.exercise == *key && !s.cancelled)
                        .map(|s| {
                            let done = r.completed_sets.iter().find(|c| c.proposed_set_id == s.id && c.ended_at > 0);
                            json!({
                                "kind": if s.calibration { "ramp" } else if s.warmup { "warmup" } else { "working" },
                                "target": format!("{} × {}", s.target_reps, round(s.target_weight)),
                                "done": done.map(|c| format!("{} × {}", c.actual_reps, round(c.actual_weight))),
                            })
                        })
                        .collect();
                    json!({ "exercise": key, "plan": planned.map(plan), "sets": sets })
                }).collect::<Vec<_>>(),
            })
        })
        .collect();
    json!({ "weights_are": "pounds", "workouts": workouts })
}

/// A list of strings argument, or None when it isn't given.
fn strings(arguments: &Value, name: &str) -> Option<Vec<String>> {
    arguments.get(name).and_then(Value::as_array).map(|a| {
        a.iter()
            .filter_map(Value::as_str)
            .map(str::to_string)
            .collect()
    })
}

/// `3×8 @ 135`: sets, reps and weight in a few characters.
fn scheme(sets: i32, reps: i32, weight: f32) -> String {
    format!("{sets}×{reps} @ {}", round(weight))
}

/// Told with a summary whose new lifts ramped with no `maxes`.
const RAMP_NOTE: &str = "Lifts marked `ramp` were never done: their first session ramps up to find a working weight. With no `maxes` for them the simulated lifter is a stand-in (two rungs in full, the third one rep short), so the weights after the ramp say nothing about this person. Give `maxes` (estimated one-rep max, lb) to see where they'd settle, or judge only the ramp and the progression after it.";

/// Sets as done, runs of the same weight and reps together:
/// `1×5 @ 185, 3×8 @ 155`.
fn sets_done(sets: &[(f32, i32)]) -> String {
    let mut runs: Vec<(i32, f32, i32)> = Vec::new();
    for &(weight, reps) in sets {
        match runs.last_mut() {
            Some((n, w, r)) if *w == weight && *r == reps => *n += 1,
            _ => runs.push((1, weight, reps)),
        }
    }
    runs.iter()
        .map(|(n, w, r)| scheme(*n, *r, *w))
        .collect::<Vec<_>>()
        .join(", ")
}

/// A simulation per lift: one line a session and where it starts and ends,
/// for `simulate_program`'s `summary`. A forward session says each set as
/// done; a new lift's first one, its ramp.
fn summary(
    workouts: &[schlift_core::pb::SimulatedWorkout],
    details: &[schlift_core::simulate::ForwardDetail],
    shown: &dyn Fn(&str) -> bool,
) -> Vec<Value> {
    let mut lifts: Vec<(String, Vec<String>, Vec<String>)> = Vec::new();
    // A lift whose number isn't reps, and what it counts.
    let mut measures: Vec<(String, &str)> = Vec::new();
    for (i, w) in workouts.iter().enumerate() {
        for l in w.lifts.iter().filter(|l| shown(&l.exercise)) {
            let Some(d) = l.decision.as_ref() else {
                continue;
            };
            match schlift_core::pb::Measure::try_from(d.measure) {
                Ok(schlift_core::pb::Measure::Seconds) => {
                    measures.push((l.exercise.clone(), "seconds"))
                }
                Ok(schlift_core::pb::Measure::Metres) => {
                    measures.push((l.exercise.clone(), "metres"))
                }
                _ => {}
            }
            let done = i
                .checked_sub(workouts.len() - details.len())
                .and_then(|i| details.get(i))
                .and_then(|f| f.lifts.iter().find(|x| x.exercise == l.exercise));
            let mut planned = if d.calibration {
                "ramp".to_string()
            } else {
                scheme(d.sets, d.reps, d.weight)
            };
            if !d.scheme.is_empty() && d.scheme != "straight" {
                planned.push_str(&format!(" ({})", d.scheme));
            }
            let mut line = format!(
                "{} {}{planned}",
                date(w.at),
                if w.past { "(past) " } else { "" }
            );
            if d.max > 0.0 && !d.calibration {
                line.push_str(&format!(" · max {}", round(d.max)));
            }
            if let Some(then) = l.recorded.as_ref() {
                let then = scheme(then.sets, then.reps, then.weight);
                if then != planned {
                    line.push_str(&format!(" · was {then}"));
                }
            }
            match done {
                Some(x) => {
                    if !x.ramp.is_empty() {
                        let rungs: Vec<String> = x
                            .ramp
                            .iter()
                            .map(|(w, r)| format!("{r} @ {}", round(*w)))
                            .collect();
                        line.push_str(&format!(" {} → settled", rungs.join(", ")));
                    } else {
                        line.push_str(" · did");
                    }
                    line.push_str(&format!(
                        " {} {}",
                        sets_done(&x.working),
                        if l.hit { "hit" } else { "short" }
                    ));
                }
                None => line.push_str(&format!(
                    " · did {} @ {} {}",
                    l.done_reps,
                    round(l.done_weight),
                    if l.hit { "hit" } else { "short" }
                )),
            }
            match lifts.iter_mut().find(|(k, _, _)| *k == l.exercise) {
                Some((_, lines, plans)) => {
                    lines.push(line);
                    plans.push(planned);
                }
                None => lifts.push((l.exercise.clone(), vec![line], vec![planned])),
            }
        }
    }
    lifts
        .into_iter()
        .map(|(exercise, sessions, plans)| {
            let mut out = json!({
                "exercise": exercise,
                "from": plans.first(),
                "to": plans.last(),
                "sessions": sessions,
            });
            if let Some((_, measure)) = measures.iter().find(|(k, _)| *k == exercise) {
                out["counts"] = json!(measure);
            }
            out
        })
        .collect()
}

/// The time budget a simulated workout planned to: its lifts'.
fn budget_of(workout: &schlift_core::pb::SimulatedWorkout) -> i32 {
    workout
        .lifts
        .iter()
        .filter_map(|l| l.decision.as_ref())
        .map(|d| d.budget_minutes)
        .max()
        .unwrap_or(0)
}

/// What a forward run should tell an assistant beyond its numbers: maxes
/// it gave that nothing used, ramps that ran out of rungs before the max
/// it gave, and workouts that ran past their budget.
fn run_notes(
    workouts: &[schlift_core::pb::SimulatedWorkout],
    details: &[schlift_core::simulate::ForwardDetail],
    maxes_given: &[String],
) -> Vec<String> {
    let mut notes = Vec::new();
    let lifts: Vec<&schlift_core::simulate::LiftDone> =
        details.iter().flat_map(|d| &d.lifts).collect();
    let unused: Vec<&str> = maxes_given
        .iter()
        .filter(|k| {
            !lifts
                .iter()
                .any(|l| l.exercise == **k && !l.ramp.is_empty())
        })
        .map(String::as_str)
        .collect();
    if !unused.is_empty() {
        notes.push(format!(
            "maxes not used for {}: only a lift never done ramps (a bodyweight lift doesn't; it starts at the bottom of its range), and only in a workout the run did",
            unused.join(", ")
        ));
    }
    let mut capped: Vec<&str> = lifts
        .iter()
        .filter(|l| l.ramp_capped && maxes_given.contains(&l.exercise))
        .map(|l| l.exercise.as_str())
        .collect();
    capped.dedup();
    if !capped.is_empty() {
        notes.push(format!(
            "{}: the ramp ran out of rungs (calibration.max_rungs) before the max you gave, and settled where it stopped. The app does the same for this person unless they type a bigger jump on a rung; calibration.rung_factor and max_rungs change it for every new lift",
            capped.join(", ")
        ));
    }
    let first_forward = workouts.len() - details.len();
    let over = workouts[first_forward..]
        .iter()
        .zip(details)
        .filter(|(w, d)| budget_of(w) > 0 && d.minutes > budget_of(w))
        .count();
    if over > 0 {
        notes.push(format!(
            "{over} workout(s) ran past their time budget: a new lift's ramp, warmups and rests all take time; sets.max, fewer lifts or less rest shorten it"
        ));
    }
    notes
}

/// `simulate_program`'s `maxes`: exercise key to a max over 0.
fn maxes(arguments: &Value) -> Result<std::collections::HashMap<String, f32>, Failure> {
    let Some(given) = arguments.get("maxes") else {
        return Ok(Default::default());
    };
    let Some(given) = given.as_object() else {
        return Err(Failure::Tool(
            "maxes is an object: {\"exercise_key\": one-rep max in lb}".into(),
        ));
    };
    given
        .iter()
        .map(|(key, max)| match max.as_f64() {
            Some(m) if m > 0.0 && m < 5000.0 => Ok((key.clone(), m as f32)),
            _ => Err(Failure::Tool(format!(
                "maxes.{key}: a one-rep max in lb (reps for a bodyweight lift), over 0"
            ))),
        })
        .collect()
}

/// One part of the guide: the heading that matches `name` (any case,
/// backticks ignored; a word of it is enough) down to the next heading as
/// high. An unknown name lists the headings.
fn guide_section(name: &str) -> String {
    let want = name.trim().trim_matches('`').to_lowercase();
    let headings: Vec<(usize, usize, String)> = GUIDE
        .lines()
        .enumerate()
        .filter_map(|(i, line)| {
            let level = line.chars().take_while(|c| *c == '#').count();
            (level > 1 && line[level..].starts_with(' ')).then(|| {
                (
                    i,
                    level,
                    line[level..].trim().replace('`', "").to_lowercase(),
                )
            })
        })
        .collect();
    let found = headings
        .iter()
        .find(|(_, _, h)| *h == want)
        .or_else(|| {
            headings
                .iter()
                .find(|(_, _, h)| h.split_whitespace().any(|w| w == want))
        })
        .or_else(|| headings.iter().find(|(_, _, h)| h.contains(&want)));
    let Some(&(start, level, _)) = found else {
        let names: Vec<&str> = headings.iter().map(|(_, _, h)| h.as_str()).collect();
        return format!("No section {name:?}. Sections: {}", names.join(", "));
    };
    let end = headings
        .iter()
        .find(|(i, l, _)| *i > start && *l <= level)
        .map_or(usize::MAX, |(i, _, _)| *i);
    GUIDE
        .lines()
        .enumerate()
        .filter(|(i, _)| *i >= start && *i < end)
        .map(|(_, l)| l)
        .collect::<Vec<_>>()
        .join("\n")
}

/// Each lift's sessions over time, for `get_progress`.
fn progress(account: &Account, now: i64, exercise: Option<&str>, since: i64) -> Value {
    let all = View::new(account, now).get_exercise_progress();
    let lifts: Vec<Value> = all
        .exercises
        .iter()
        .filter(|e| exercise.is_none_or(|k| k == e.exercise))
        .filter_map(|e| {
            let points: Vec<Value> = e
                .points
                .iter()
                .filter(|p| p.date >= since)
                .map(|p| {
                    json!({
                        "date": date(p.date),
                        "top_set": format!("{} × {}", p.top_reps, round(p.top_weight)),
                        "sets": p.sets,
                        "volume_lb": round(p.volume),
                        "estimated_max": round(p.estimated_max),
                    })
                })
                .collect();
            (!points.is_empty()).then(|| {
                json!({
                    "exercise": e.exercise,
                    "name": e.name,
                    "bodyweight": e.bodyweight,
                    "max_is": if e.bodyweight { "reps" } else { "pounds" },
                    "sessions": points,
                })
            })
        })
        .collect();
    json!({ "workouts": all.workout_count, "lifts": lifts })
}
