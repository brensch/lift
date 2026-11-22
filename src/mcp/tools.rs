//! What an assistant can do over MCP: read the guide, the program, the
//! person's history and where each lift stands; check and run a draft
//! program; set one. Reads fold the account as the website does (the
//! core's `View`); the write is the core's `Call`, recorded by the server
//! and streamed to the person's phones like any event they made.

use serde_json::{json, Value};

use super::Mcp;
use schlift_core::account::Account;
use schlift_core::api::{Call, View};
use schlift_core::pb::{
    ExerciseDecision, GetProgramVersionRequest, MuscleGroup, PlanReasonKind, SetProgramRequest,
    SimulateProgramRequest, SimulatedEffort, ValidateProgramRequest,
};
use schlift_core::plan::Planner;
use schlift_core::program::GUIDE;

/// Told to the assistant when it connects.
pub const INSTRUCTIONS: &str = "Schlift records a person's strength training. \
Their program — one JSON document — decides every workout the app plans: the \
exercises, the workouts, how each lift progresses, and every number the planner \
uses. Read the guide (read_guide) before writing one. To change it: get_program, \
get_profile and get_history to see where they are; write the whole document; \
validate_program; simulate_program to check what it prescribes; then set_program \
with a short note saying why. Weights are always pounds.";

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
        "description": "The whole program document (an object, or its JSON as a string)",
        "type": ["object", "string"]
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
            "description": "The person's current program document, who set it and why, and the programs set before it.",
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
            "name": "validate_program",
            "title": "Check a draft program",
            "description": "Every problem with a draft, each with its path (progressions.squat_lp.reps). A draft with an error can't be set; warnings are advice.",
            "inputSchema": schema(json!({ "program": program_property() }), &["program"]),
            "annotations": { "readOnlyHint": true },
        }),
        json!({
            "name": "simulate_program",
            "title": "Run a draft program",
            "description": "What a draft (or the current program) prescribes, without setting it: its past workouts planned again as of just before each, beside what was planned and done; and the next sessions, each done as `effort` says, through the app's own rules (warmups, the calibration ramp, the time budget).",
            "inputSchema": schema(json!({
                "program": program_property(),
                "sessions": { "type": "integer", "minimum": 0, "maximum": 60, "description": "Workouts forward from now (default 6)" },
                "every_days": { "type": "integer", "minimum": 1, "maximum": 14, "description": "Days between them (default 2)" },
                "effort": { "type": "string", "enum": ["all_hit", "last_set_short", "all_short", "miss_every"], "description": "How each forward session goes (default all_hit)" },
                "miss_every": { "type": "integer", "minimum": 1, "description": "With miss_every: every this many sessions, the last set one rep short" },
                "template_id": { "type": "string", "description": "Do this workout every time; otherwise the rotation's suggestion" },
                "budget_minutes": { "type": "integer", "minimum": 5, "maximum": 300 },
                "history": { "type": "integer", "minimum": 0, "maximum": 60, "description": "Past workouts to plan again (default 6)" }
            }), &[]),
            "annotations": { "readOnlyHint": true },
        }),
        json!({
            "name": "set_program",
            "title": "Set the program",
            "description": "Make a draft the person's program: it plans every workout from the next one on (none already done changes). Refused, with its problems, if it has an error. Earlier programs stay in their history.",
            "inputSchema": schema(json!({
                "program": program_property(),
                "note": { "type": "string", "maxLength": 300, "description": "One line, to the person, on why" }
            }), &["program", "note"]),
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

fn program_json(arguments: &Value) -> Result<String, Failure> {
    match arguments.get("program") {
        Some(Value::String(s)) => Ok(s.clone()),
        Some(v @ Value::Object(_)) => Ok(v.to_string()),
        Some(_) => Err(Failure::Tool(
            "program is an object, or its JSON as a string".into(),
        )),
        None => Ok(String::new()),
    }
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

fn plan(d: &ExerciseDecision) -> Value {
    json!({
        "sets": d.sets,
        "reps": d.reps,
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
            let got = mcp
                .db
                .read_account(user_id, move |a| View::new(a, now).get_program())
                .await?;
            let program: Value = serde_json::from_str(&got.program_json).unwrap_or(Value::Null);
            let summary = |s: &schlift_core::pb::ProgramSummary| json!({ "id": s.id, "name": s.name, "author": s.author, "note": s.note, "set_on": if s.set_at > 0 { date(s.set_at) } else { String::new() } });
            Ok(text(&json!({
                "current": got.summary.as_ref().map(summary),
                "earlier": got.history.iter().map(summary).collect::<Vec<_>>(),
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
            let program: Value = serde_json::from_str(&got.program_json).unwrap_or(Value::Null);
            Ok(text(&json!({
                "id": s.id,
                "name": s.name,
                "author": s.author,
                "note": s.note,
                "set_on": date(s.set_at),
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
            let program_json = program_json(arguments)?;
            let checked = mcp
                .db
                .read_account(user_id, move |a| {
                    View::new(a, now).validate_program(ValidateProgramRequest { program_json })
                })
                .await??;
            Ok(text(&json!({
                "ok": !checked.problems.iter().any(|p| p.error),
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
            let request = SimulateProgramRequest {
                program_json: program_json(arguments)?,
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
            };
            let run = mcp
                .db
                .read_account(user_id, move |a| {
                    View::new(a, now).simulate_program(request)
                })
                .await??;
            if run.problems.iter().any(|p| p.error) {
                return Err(Failure::Tool(
                    serde_json::to_string_pretty(&json!({ "problems": problems(&run.problems) }))
                        .unwrap_or_default(),
                ));
            }
            let workouts: Vec<Value> = run
                .workouts
                .iter()
                .map(|w| {
                    json!({
                        "date": date(w.at),
                        "past": w.past,
                        "workout": w.name,
                        "lifts": w.lifts.iter().map(|l| json!({
                            "exercise": l.exercise,
                            "plan": l.decision.as_ref().map(plan),
                            "planned_then": l.recorded.as_ref().map(|d| json!({ "sets": d.sets, "reps": d.reps, "weight_lb": round(d.weight) })),
                            "done": { "weight_lb": round(l.done_weight), "reps": l.done_reps, "every_rep": l.hit },
                        })).collect::<Vec<_>>(),
                    })
                })
                .collect();
            Ok(text(
                &json!({ "workouts": workouts, "problems": problems(&run.problems) }),
            ))
        }
        "set_program" => {
            let program_json = program_json(arguments)?;
            if program_json.is_empty() {
                return Err(Failure::Tool("program is required".into()));
            }
            let note = arguments
                .get("note")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_string();
            let author = format!("mcp:{client_name}");
            let mut account = mcp.db.read_account(user_id, Clone::clone).await?;
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
                        "problems": problems(&response.problems),
                    }))
                    .unwrap_or_default(),
                ));
            };
            mcp.db.push_events(user_id, events).await?;
            tracing::info!(%user_id, client = client_name, program = %summary.name, "an assistant set a program");
            Ok(text(&json!({
                "set": true,
                "program": { "id": summary.id, "name": summary.name, "note": summary.note },
                "problems": problems(&response.problems),
            })))
        }
        _ => Err(Failure::Unknown),
    }
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
