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
keep the output short) to see what it prescribes, then set_program with the same edits and a one-line note to the person. \
Any set type is a program's: schemes lay out a lift's sets (top sets and back-offs, \
pyramids, AMRAP, drops, myo-reps, clusters, EMOM, effort targets) and a workout's \
groups make supersets and circuits; see the guide's `schemes`. Weights are always \
pounds. When you are done, send_feedback: one line on what was easy or hard about \
these tools.";

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

fn edits_property() -> Value {
    json!({
        "description": "Changes to the current program, applied in order, all or none. Each is {\"set\": path, \"value\": v}, {\"remove\": path} or {\"move\": path, \"before\": path-or-null}. A path is dot-separated, with exercises by key and workouts by id: classes.heavy.rest_seconds, workouts[upper_a].exercises, exercises[squat].progression, progressions.squat_lp, time_off[0].days. Setting a named item that doesn't exist adds it. See read_guide's Editing section",
        "type": "array",
        "items": { "type": "object" },
        "maxItems": schlift_core::program::edit::MAX_EDITS
    })
}

/// Every tool, as `tools/list` gives them.
pub fn list() -> Vec<Value> {
    vec![
        json!({
            "name": "read_guide",
            "title": "Read the program guide",
            "description": "What a Schlift program is and every field in it: exercises, workouts, classes, progressions (estimated_max, fixed, linear, double, cycle, formula), the formula language and every planner number. Read it before writing a program.",
            "inputSchema": schema(json!({}), &[]),
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
            "description": "Finished workouts, newest first: each lift's plan and every set's target and what was done.",
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
            "description": "Every problem with a draft (edits to the current program, or a whole document), each with its path (workouts[upper_a].exercises[2]). A draft with an error can't be set; warnings are advice. simulate_program and set_program check too, so this is only needed on its own.",
            "inputSchema": schema(json!({ "edits": edits_property(), "program": program_property() }), &[]),
            "annotations": { "readOnlyHint": true },
        }),
        json!({
            "name": "simulate_program",
            "title": "Run a draft program",
            "description": "What a draft (edits to the current program, a whole document, or with neither the current program) prescribes, without setting it: its past workouts planned again as of just before each, beside what was planned and done; and the next sessions, each done as `effort` says, through the app's own rules (warmups, the calibration ramp, the time budget). Its problems too.",
            "inputSchema": schema(json!({
                "edits": edits_property(),
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
                "summary": { "type": "boolean", "description": "Per lift, one short line a session (plan, what was planned then, what was done) instead of every field" }
            }), &[]),
            "annotations": { "readOnlyHint": true },
        }),
        json!({
            "name": "set_program",
            "title": "Set the program",
            "description": "Make a draft the person's program (edits to the current program, or a whole document): it plans every workout from the next one on (none already done changes) and reaches their phone at once. Refused, with its problems, if it has an error. Earlier programs stay in their history.",
            "inputSchema": schema(json!({
                "edits": edits_property(),
                "program": program_property(),
                "note": { "type": "string", "maxLength": 300, "description": "One line, to the person, on why" }
            }), &["note"]),
            "annotations": { "readOnlyHint": false, "destructiveHint": false, "idempotentHint": false },
        }),
        json!({
            "name": "list_exercises",
            "title": "Find exercises",
            "description": "Exercises the program can use, built-in and its own: key, name, equipment, muscles (primary first), class, own progression, whether built in, and which workouts use it. Filter by muscle, equipment, a name fragment or keys.",
            "inputSchema": schema(json!({
                "muscle": { "type": "string", "enum": ["chest", "back", "shoulders", "biceps", "triceps", "quads", "hamstrings", "glutes", "calves", "core"], "description": "Trains this muscle" },
                "primary_only": { "type": "boolean", "description": "With muscle: only lifts where it is the primary mover" },
                "equipment": { "type": "string", "enum": ["barbell", "dumbbell", "machine", "cable", "bodyweight"] },
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
    json!({
        "content": [{ "type": "text", "text": serde_json::to_string_pretty(value).unwrap_or_default() }],
        "structuredContent": value,
    })
}

/// The draft a write tool was given, as a whole document: `edits` applied
/// to the current program, or a `program` with any built-in exercises it
/// leaves out put back. With neither, "" (the current program, where a
/// tool allows that). Also how many edits applied.
fn draft(account: &Account, arguments: &Value) -> Result<(String, usize), Failure> {
    match (arguments.get("edits"), arguments.get("program")) {
        (Some(_), Some(_)) => Err(Failure::Tool(
            "send edits or a whole program, not both".into(),
        )),
        (Some(Value::Array(edits)), None) => {
            let doc = edit::apply(&account.program, edits).map_err(|e| {
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
    match name {
        "read_guide" => Ok(json!({ "content": [{ "type": "text", "text": GUIDE }] })),
        "get_program" => {
            let (got, (program, note)) = mcp
                .db
                .read_account(user_id, move |a| {
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
                .read_account(user_id, move |a| {
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
            let profile = mcp
                .db
                .read_account(user_id, move |a| profile(a, now))
                .await?;
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
                .read_account(user_id, move |a| {
                    history(a, exercise.as_deref(), since, limit)
                })
                .await?;
            Ok(text(&history))
        }
        "validate_program" => {
            let args = arguments.clone();
            let (checked, applied) = mcp
                .db
                .read_account(user_id, move |a| -> Result<_, Failure> {
                    let (program_json, applied) = draft(a, &args)?;
                    if program_json.is_empty() {
                        return Err(Failure::Tool("send edits or a program to check".into()));
                    }
                    let checked = View::new(a, now)
                        .validate_program(ValidateProgramRequest { program_json })?;
                    Ok((checked, applied))
                })
                .await??;
            Ok(text(&json!({
                "ok": !checked.problems.iter().any(|p| p.error),
                "applied": applied,
                "problems": problems(&checked.problems),
            })))
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
            let args = arguments.clone();
            let (run, applied) = mcp
                .db
                .read_account(user_id, move |a| -> Result<_, Failure> {
                    let (program_json, applied) = draft(a, &args)?;
                    request.program_json = program_json;
                    Ok((View::new(a, now).simulate_program(request)?, applied))
                })
                .await??;
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
            if arguments
                .get("summary")
                .and_then(Value::as_bool)
                .unwrap_or(false)
            {
                return Ok(text(&json!({
                    "applied": applied,
                    "lifts": summary(&run.workouts, &shown),
                    "problems": problems(&run.problems),
                })));
            }
            let workouts: Vec<Value> = run
                .workouts
                .iter()
                .map(|w| {
                    json!({
                        "date": date(w.at),
                        "past": w.past,
                        "workout": w.name,
                        "lifts": w.lifts.iter().filter(|l| shown(&l.exercise)).map(|l| json!({
                            "exercise": l.exercise,
                            "plan": l.decision.as_ref().map(plan),
                            "planned_then": l.recorded.as_ref().map(|d| json!({ "sets": d.sets, "reps": d.reps, "weight_lb": round(d.weight) })),
                            "done": { "weight_lb": round(l.done_weight), "reps": l.done_reps, "every_rep": l.hit },
                        })).collect::<Vec<_>>(),
                    })
                })
                .collect();
            Ok(text(&json!({
                "applied": applied,
                "workouts": workouts,
                "problems": problems(&run.problems),
            })))
        }
        "set_program" => {
            let mut account = mcp.db.read_account(user_id, Clone::clone).await?;
            let (program_json, applied) = draft(&account, arguments)?;
            if program_json.is_empty() {
                return Err(Failure::Tool("send edits or a program to set".into()));
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
                .read_account(user_id, move |a| {
                    progress(a, now, exercise.as_deref(), since)
                })
                .await?;
            Ok(text(&progress))
        }
        "list_exercises" => {
            let args = arguments.clone();
            let found = mcp
                .db
                .read_account(user_id, move |a| exercises(&a.program, &args))
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
                .read_account(user_id, move |a| edit::part(&a.program, &path))
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
        _ => Err(Failure::Unknown),
    }
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
        .filter(|(_, v)| get("equipment").is_none_or(|eq| v["equipment"] == eq))
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
            json!({
                "key": e.key,
                "name": e.name,
                "equipment": v["equipment"],
                "muscles": v["muscles"],
                "class": e.class,
                "progression": e.progression,
                "params": e.params,
                "scheme": e.scheme,
                "measure": v["measure"],
                "per_side": e.per_side,
                "tempo": e.tempo,
                "built_in": builtin.contains(&e.key),
                "in_workouts": program.workouts.iter().filter(|w| w.exercises.contains(&e.key)).map(|w| w.id.clone()).collect::<Vec<_>>(),
            })
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
fn history(account: &Account, exercise: Option<&str>, since: Option<i64>, limit: usize) -> Value {
    let view = View::new(account, 0);
    let workouts: Vec<Value> = view
        .finished()
        .into_iter()
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
            json!({
                "id": r.workout.id,
                "date": date(r.workout.start_time),
                "name": r.workout.name,
                "minutes": (r.workout.end_time - r.workout.start_time) / 60,
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

/// A simulation per lift: one line a session and where it starts and ends,
/// for `simulate_program`'s `summary`.
fn summary(
    workouts: &[schlift_core::pb::SimulatedWorkout],
    shown: &dyn Fn(&str) -> bool,
) -> Vec<Value> {
    let mut lifts: Vec<(String, Vec<String>, Vec<String>)> = Vec::new();
    for w in workouts {
        for l in w.lifts.iter().filter(|l| shown(&l.exercise)) {
            let Some(d) = l.decision.as_ref() else {
                continue;
            };
            let mut planned = scheme(d.sets, d.reps, d.weight);
            if !d.scheme.is_empty() && d.scheme != "straight" {
                planned.push_str(&format!(" ({})", d.scheme));
            }
            let mut line = format!(
                "{} {}{planned}",
                date(w.at),
                if w.past { "(past) " } else { "" }
            );
            if let Some(then) = l.recorded.as_ref() {
                let then = scheme(then.sets, then.reps, then.weight);
                if then != planned {
                    line.push_str(&format!(" · was {then}"));
                }
            }
            line.push_str(&format!(
                " · did {} @ {} {}",
                l.done_reps,
                round(l.done_weight),
                if l.hit { "hit" } else { "short" }
            ));
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
            json!({
                "exercise": exercise,
                "from": plans.first(),
                "to": plans.last(),
                "sessions": sessions,
            })
        })
        .collect()
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
