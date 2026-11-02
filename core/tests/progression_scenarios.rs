//! Progression scenarios: scripted lifters driven through the real core,
//! the way the app drives it, and what the planning rules told them each
//! session. The record is a snapshot (testdata/progression_scenarios.json)
//! that the progression explorer page is built from, so a change to the
//! rules shows up as a reviewable diff of what lifters are told.
//!
//! ```text
//! cargo test -p schlift-core --test progression_scenarios                      # compare
//! UPDATE_SCENARIOS=1 cargo test -p schlift-core --test progression_scenarios   # rewrite
//! make progression-explorer                # rewrite + build .tmp/progression-explorer.html
//! ```
//!
//! Nothing here decides a weight: every plan comes from `Call::start_workout`
//! and every max from the progress view. The lifter only chooses what it
//! does with what it is given (reps per set, a lowered weight, stopping),
//! with a fixed clock and fixed event ids, so a run is the same every time.
//!
//! The audit runs on every session and writes its flags into the snapshot,
//! where the page shows them at the top of each scenario. A **violation**
//! fails the test: a planned weight below the last one with no miss, time
//! off, override, lowered weight or extra sets behind it; a max that rises
//! after a missed set or falls after every rep was hit; reps outside the
//! class's range or sets outside 2–5 (an override's own excepted); an
//! estimate over the budget with sets above the 2-set floor. A **warning**
//! is the rules doing what they say with a result a lifter would find odd:
//! the weight dropping because the budget gave more sets than last time, or
//! the max held three sessions running although every rep was hit. **Info**
//! is context: the card asking for more time than the budget, or an
//! estimate five minutes or more off the clock. The snapshot comparison
//! catches any change in either.

use std::collections::HashMap;

use schlift_core::account::{Account, CoreError};
use schlift_core::api::{Call, View};
use schlift_core::exercise_catalog::{
    exercise_display_name, lift_class, progression_increment_lb, snap_weight_lb, LiftClass,
};
use schlift_core::pb::workout_mutation::Mutation;
use schlift_core::pb::*;
use schlift_core::plan::{is_bodyweight, reps_covered, Planner, MAX_SETS, MIN_SETS};
use schlift_core::weight_units::{pounds_to_kg, AppWeightUnit};

const DAY: i64 = 24 * 3600;
/// Monday 5 January 2026, 07:00 UTC: the first session of every scenario.
const T0: i64 = 1_767_596_400;
/// How long the lifter takes to lift one set.
const LIFT_SECONDS: i64 = 40;
const SNAPSHOT: &str = "../testdata/progression_scenarios.json";
const UPDATE_ENV: &str = "UPDATE_SCENARIOS";
/// Held this many sessions in a row with every rep hit is a stall.
const STALL_SESSIONS: usize = 3;

const A: [Exercise; 4] = [
    Exercise::Squat,
    Exercise::BarbellRow,
    Exercise::BenchPress,
    Exercise::LateralRaise,
];
const B: [Exercise; 4] = [
    Exercise::Squat,
    Exercise::OverheadPress,
    Exercise::Deadlift,
    Exercise::PullUp,
];

// ── The phone, minus storage ──

struct App {
    account: Account,
    log: Vec<Event>,
    prefix: String,
    calls: usize,
}

impl App {
    fn new(prefix: &str) -> Self {
        Self {
            account: Account::default(),
            log: Vec::new(),
            prefix: prefix.to_string(),
            calls: 0,
        }
    }

    /// One call at `now`, with the next fixed event id; its events land in
    /// the log.
    fn call<R>(&mut self, now: i64, f: impl FnOnce(&mut Call) -> Result<R, CoreError>) -> R {
        self.calls += 1;
        let id = format!("{}-{:05}", self.prefix, self.calls);
        let mut call = Call::new(&mut self.account, now, id);
        let out = f(&mut call).expect("the core accepts the call");
        self.log.append(&mut call.events);
        out
    }

    fn view(&self, now: i64) -> View<'_> {
        View::new(&self.account, now)
    }

    fn workout(&self, now: i64, id: &str) -> GetWorkoutResponse {
        self.view(now)
            .get_workout(GetWorkoutRequest {
                workout_id: id.to_string(),
            })
            .expect("the workout exists")
    }

    fn unit(&self) -> AppWeightUnit {
        self.account.unit()
    }
}

// ── The scripts ──

/// What the lifter does in one session beyond lifting what it is given.
#[derive(Clone, Default)]
struct Session {
    template_b: bool,
    budget: i32,
    /// Days since the previous session (0 = the usual Mon/Wed/Fri spacing).
    gap_days: i64,
    note: String,
    /// Lifts removed before any set (the lifter skips them today).
    skip: Vec<Exercise>,
    /// Each lift's last working set done this many reps short.
    short: Vec<(Exercise, i32)>,
    /// Before this working set, the lifter lowers the weight by this
    /// fraction (snapped loadable) and does the rest at it.
    lower: Option<(Exercise, usize, f32)>,
    /// After this working set the lift is removed.
    remove_after: Option<(Exercise, usize)>,
    /// After this working set the workout is ended.
    end_after: Option<(Exercise, usize)>,
    /// Overrides set in the template editor before the session.
    overrides: Vec<SetOverrideRequest>,
}

struct Scenario {
    id: &'static str,
    title: &'static str,
    description: &'static str,
    unit: WeightUnit,
    strength: f32,
    /// The lifter's true one-rep max per lift as a multiple of the starting
    /// weight the slider gave (or the catalog opener); it decides only how
    /// far up the calibration ramp the lifter gets.
    strength_factor: fn(Exercise) -> f32,
    /// The lifter's rest after a working set, as a multiple of what the
    /// app asks for.
    rest_factor: f32,
    sessions: Vec<Session>,
    /// Templates previewed at these budgets on Home after the last session.
    preview_budgets: Vec<i32>,
    preview_library: Vec<&'static str>,
}

fn alternating(n: usize, f: impl Fn(usize, &mut Session)) -> Vec<Session> {
    (0..n)
        .map(|i| {
            let mut s = Session {
                template_b: i % 2 == 1,
                budget: 60,
                ..Default::default()
            };
            f(i, &mut s);
            s
        })
        .collect()
}

/// About as strong as the slider said; the lateral raise (no slider
/// weight, a 20 lb opener) good for 30.
fn even(ex: Exercise) -> f32 {
    if ex == Exercise::LateralRaise {
        1.5
    } else {
        1.0
    }
}

fn short_all_last(s: &mut Session) {
    let lifts = if s.template_b { B } else { A };
    s.short = lifts.iter().map(|ex| (*ex, 2)).collect();
}

fn scenarios() -> Vec<Scenario> {
    vec![
        Scenario {
            id: "beginner",
            title: "Beginner, every rep",
            description: "Slider at 25%. StrongLifts A/B with a lateral raise and pull-ups, \
                          three days a week, every rep of every set done.",
            unit: WeightUnit::Lb,
            strength: 0.25,
            strength_factor: even,
            rest_factor: 1.0,
            sessions: alternating(18, |_, _| {}),
            preview_budgets: vec![],
            preview_library: vec![],
        },
        Scenario {
            id: "intermediate_misses",
            title: "Misses every third session",
            description: "Slider at 55%. Every third session the last set of every lift \
                          comes up two reps short; everything else is hit.",
            unit: WeightUnit::Lb,
            strength: 0.55,
            strength_factor: even,
            rest_factor: 1.0,
            sessions: alternating(18, |i, s| {
                if i % 3 == 2 {
                    short_all_last(s);
                    s.note = "last set of every lift two reps short".into();
                }
            }),
            preview_budgets: vec![],
            preview_library: vec![],
        },
        Scenario {
            id: "time_off",
            title: "Four weeks off, then seven",
            description: "Slider at 40%, every rep hit. Six sessions, four weeks off, six \
                          sessions (deadlift skipped throughout: a sore back), seven weeks \
                          off, six more.",
            unit: WeightUnit::Lb,
            strength: 0.4,
            strength_factor: even,
            rest_factor: 1.0,
            sessions: alternating(18, |i, s| {
                if i == 6 {
                    s.gap_days = 28 + 2;
                    s.note = "back after four weeks off".into();
                }
                if i == 12 {
                    s.gap_days = 49 + 2;
                    s.note = "back after seven weeks off".into();
                }
                if (6..12).contains(&i) && s.template_b {
                    s.skip = vec![Exercise::Deadlift];
                    s.note = if s.note.is_empty() {
                        "deadlift skipped".into()
                    } else {
                        format!("{}; deadlift skipped", s.note)
                    };
                }
            }),
            preview_budgets: vec![],
            preview_library: vec![],
        },
        Scenario {
            id: "first_time",
            title: "First time: the ramp",
            description: "Slider at 50%, fresh account. The ramp opens at 60% of each \
                          starting weight. Squat is far stronger than the slider said \
                          (all six rungs), bench weaker (misses early), the rest near it.",
            unit: WeightUnit::Lb,
            strength: 0.5,
            strength_factor: |ex| match ex {
                Exercise::Squat => 1.6,
                Exercise::BenchPress => 0.8,
                Exercise::LateralRaise => 1.5,
                _ => 1.0,
            },
            rest_factor: 1.0,
            sessions: alternating(8, |_, _| {}),
            preview_budgets: vec![],
            preview_library: vec![],
        },
        Scenario {
            id: "override",
            title: "Override mid-way",
            description: "Slider at 40%, every rep hit. Before session 7 the lifter sets \
                          bench to 135 × 8 in the template editor; before session 9, \
                          lateral raise to 25 × 12 for 4 sets. Progression carries on \
                          from each.",
            unit: WeightUnit::Lb,
            strength: 0.4,
            strength_factor: even,
            rest_factor: 1.0,
            sessions: alternating(16, |i, s| {
                if i == 6 {
                    s.overrides = vec![SetOverrideRequest {
                        exercise: Exercise::BenchPress as i32,
                        weight: 135.0,
                        reps: 8,
                        sets: None,
                    }];
                    s.note = "override: bench 135 × 8".into();
                }
                if i == 8 {
                    s.overrides = vec![SetOverrideRequest {
                        exercise: Exercise::LateralRaise as i32,
                        weight: 25.0,
                        reps: 12,
                        sets: Some(4),
                    }];
                    s.note = "override: lateral raise 25 × 12, 4 sets".into();
                }
            }),
            preview_budgets: vec![],
            preview_library: vec![],
        },
        Scenario {
            id: "cooked",
            title: "Cooked: lowers the weight",
            description: "Slider at 50%. On sessions 5, 9 and 13 the lifter is cooked: \
                          after two squat sets they lower the weight 15% and hit every \
                          rep of the rest. The max should hold.",
            unit: WeightUnit::Lb,
            strength: 0.5,
            strength_factor: even,
            rest_factor: 1.0,
            sessions: alternating(16, |i, s| {
                if [4, 8, 12].contains(&i) {
                    s.lower = Some((Exercise::Squat, 3, 0.15));
                    s.note = "squat lowered 15% after set 2".into();
                }
            }),
            preview_budgets: vec![],
            preview_library: vec![],
        },
        Scenario {
            id: "stops_early",
            title: "Stops early",
            description: "Slider at 40%. Session 4 ends after one working set of the \
                          second lift; session 7 removes bench after its first set; \
                          session 12 ends after squat. Everything done is hit.",
            unit: WeightUnit::Lb,
            strength: 0.4,
            strength_factor: even,
            rest_factor: 1.0,
            sessions: alternating(16, |i, s| match i {
                3 => {
                    s.end_after = Some((Exercise::OverheadPress, 1));
                    s.note = "ended after one OHP set".into();
                }
                6 => {
                    s.remove_after = Some((Exercise::BenchPress, 1));
                    s.note = "bench removed after one set".into();
                }
                11 => {
                    s.end_after = Some((Exercise::Squat, 99));
                    s.note = "ended after squat".into();
                }
                _ => {}
            }),
            preview_budgets: vec![],
            preview_library: vec![],
        },
        Scenario {
            id: "budgets",
            title: "Budgets: 30 to 90 minutes",
            description: "Slider at 40%, every rep hit, the budget cycling 30, 45, 60, \
                          90 minutes. Afterwards Home previews each template (and the \
                          five-lift Full Body) at every budget.",
            unit: WeightUnit::Lb,
            strength: 0.4,
            strength_factor: even,
            rest_factor: 1.0,
            sessions: alternating(16, |i, s| {
                s.budget = [30, 45, 60, 90][i % 4];
            }),
            preview_budgets: vec![20, 30, 45, 60, 90],
            preview_library: vec!["full_body"],
        },
        Scenario {
            id: "long_rests",
            title: "Learned timings: long rests",
            description: "Slider at 40%, every rep hit, but the lifter rests twice what \
                          the app asks between working sets. Once ten rests of a class \
                          are on record, the plan uses the lifter's own and fits fewer \
                          sets into the hour.",
            unit: WeightUnit::Lb,
            strength: 0.4,
            strength_factor: even,
            rest_factor: 2.0,
            sessions: alternating(14, |_, _| {}),
            preview_budgets: vec![],
            preview_library: vec![],
        },
        Scenario {
            id: "kilograms",
            title: "Kilograms",
            description: "A kilogram user, slider at 35%. Every fourth session the last \
                          set of every lift is two reps short.",
            unit: WeightUnit::Kg,
            strength: 0.35,
            strength_factor: even,
            rest_factor: 1.0,
            sessions: alternating(16, |i, s| {
                if i % 4 == 3 {
                    short_all_last(s);
                    s.note = "last set of every lift two reps short".into();
                }
            }),
            preview_budgets: vec![],
            preview_library: vec![],
        },
    ]
}

// ── JSON, written by hand: stable key order, rounded numbers ──

enum J {
    Null,
    Bool(bool),
    Int(i64),
    Num(f64),
    Str(String),
    Arr(Vec<J>),
    Obj(Vec<(&'static str, J)>),
}

fn num(x: f32) -> J {
    J::Num((x as f64 * 10.0).round() / 10.0)
}

fn s(x: impl Into<String>) -> J {
    J::Str(x.into())
}

impl J {
    fn flat(&self) -> bool {
        match self {
            J::Arr(v) => v.iter().all(J::scalar),
            J::Obj(v) => v.iter().all(|(_, j)| j.scalar()),
            _ => true,
        }
    }

    fn scalar(&self) -> bool {
        !matches!(self, J::Arr(_) | J::Obj(_))
    }

    fn write(&self, out: &mut String, indent: usize) {
        match self {
            J::Null => out.push_str("null"),
            J::Bool(b) => out.push_str(if *b { "true" } else { "false" }),
            J::Int(i) => out.push_str(&i.to_string()),
            J::Num(x) => {
                let x = if *x == 0.0 { 0.0 } else { *x };
                out.push_str(&format!("{x}"));
            }
            J::Str(text) => {
                out.push('"');
                for c in text.chars() {
                    match c {
                        '"' => out.push_str("\\\""),
                        '\\' => out.push_str("\\\\"),
                        '\n' => out.push_str("\\n"),
                        c => out.push(c),
                    }
                }
                out.push('"');
            }
            J::Arr(v) if v.is_empty() => out.push_str("[]"),
            J::Obj(v) if v.is_empty() => out.push_str("{}"),
            J::Arr(v) => self.write_items(out, indent, '[', ']', v.iter().map(|j| (None, j))),
            J::Obj(v) => {
                self.write_items(out, indent, '{', '}', v.iter().map(|(k, j)| (Some(*k), j)))
            }
        }
    }

    fn write_items<'a>(
        &self,
        out: &mut String,
        indent: usize,
        open: char,
        close: char,
        items: impl Iterator<Item = (Option<&'a str>, &'a J)>,
    ) {
        let flat = self.flat();
        out.push(open);
        for (n, (key, value)) in items.enumerate() {
            if n > 0 {
                out.push(',');
                if flat {
                    out.push(' ');
                }
            }
            if !flat {
                out.push('\n');
                out.push_str(&"  ".repeat(indent + 1));
            }
            if let Some(key) = key {
                J::Str(key.to_string()).write(out, 0);
                out.push_str(": ");
            }
            value.write(out, indent + 1);
        }
        if !flat {
            out.push('\n');
            out.push_str(&"  ".repeat(indent));
        }
        out.push(close);
    }
}

// ── Running a scenario ──

fn name(ex: Exercise) -> String {
    ex.as_str_name()
        .strip_prefix("EXERCISE_")
        .unwrap_or(ex.as_str_name())
        .to_string()
}

fn class_name(ex: Exercise) -> &'static str {
    match lift_class(ex) {
        LiftClass::Heavy => "heavy",
        LiftClass::Standard => "standard",
        LiftClass::Bodyweight => "bodyweight",
    }
}

fn reason_kind(kind: i32) -> PlanReasonKind {
    PlanReasonKind::try_from(kind).unwrap_or(PlanReasonKind::Unspecified)
}

fn reason_name(kind: i32) -> String {
    let k = reason_kind(kind);
    k.as_str_name()
        .strip_prefix("PLAN_REASON_KIND_")
        .unwrap_or(k.as_str_name())
        .to_string()
}

fn cause_name(cause: i32) -> String {
    let c = WeightChangeCause::try_from(cause).unwrap_or(WeightChangeCause::Unspecified);
    c.as_str_name()
        .strip_prefix("WEIGHT_CHANGE_CAUSE_")
        .unwrap_or(c.as_str_name())
        .to_string()
}

fn date(t: i64) -> String {
    // Civil date from days since the epoch (Howard Hinnant's algorithm).
    let z = t.div_euclid(DAY) + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = yoe + era * 400 + i64::from(m <= 2);
    format!("{y:04}-{m:02}-{d:02}")
}

/// How bad a flag is. A violation breaks a rule the plan states and fails
/// the test; a warning is the rules doing what they say with a result a
/// lifter would find odd, shown at the top of the scenario; info is
/// context (the card asking for more time).
#[derive(Clone, Copy, PartialEq)]
enum Severity {
    Violation,
    Warning,
    Info,
}

impl Severity {
    fn name(self) -> &'static str {
        match self {
            Severity::Violation => "violation",
            Severity::Warning => "warning",
            Severity::Info => "info",
        }
    }
}

/// What one flag says.
struct Flag {
    severity: Severity,
    kind: &'static str,
    session: usize,
    exercise: Option<Exercise>,
    detail: String,
}

impl Flag {
    fn json(&self) -> J {
        J::Obj(vec![
            ("severity", s(self.severity.name())),
            ("kind", s(self.kind)),
            ("session", J::Int(self.session as i64)),
            ("exercise", self.exercise.map_or(J::Null, |e| s(name(e)))),
            ("detail", s(self.detail.clone())),
        ])
    }
}

/// One session as it ran, for the record.
#[derive(Clone, Copy)]
struct Ran<'a> {
    n: usize,
    script: &'a Session,
    start: i64,
    end: i64,
    state: &'a GetWorkoutResponse,
    progress: &'a GetExerciseProgressResponse,
}

/// What the lifter last did on a lift, for the audit.
#[derive(Clone, Default)]
struct LastDone {
    weight: Option<f32>,
    lowered: bool,
    /// Working sets done.
    sets: i32,
}

struct Runner<'a> {
    sc: &'a Scenario,
    app: App,
    templates: [String; 2],
    starting: std::collections::BTreeMap<i32, f32>,
    /// Proposed set id → "session n, set k" for reasons that name a set.
    set_labels: HashMap<String, String>,
    workout_sessions: HashMap<String, usize>,
    last: HashMap<i32, LastDone>,
    /// Sessions in a row each lift was held with every rep hit.
    held: HashMap<i32, usize>,
    flags: Vec<Flag>,
}

impl<'a> Runner<'a> {
    fn new(sc: &'a Scenario) -> Self {
        let mut app = App::new(sc.id);
        app.call(T0 - DAY, |c| {
            c.complete_onboarding(CompleteOnboardingRequest {
                unit: sc.unit as i32,
                library_ids: vec!["stronglifts_a".into(), "stronglifts_b".into()],
                strength: Some(sc.strength),
                ..Default::default()
            })
        });
        let starting = app.account.starting_weights.clone();
        let mut templates = [String::new(), String::new()];
        for (slot, (library_id, lifts)) in [("stronglifts_a", A), ("stronglifts_b", B)]
            .into_iter()
            .enumerate()
        {
            let mut t = app
                .account
                .templates
                .iter()
                .find(|t| t.library_id == library_id)
                .expect("onboarding copied it")
                .clone();
            t.exercises = lifts.iter().map(|e| *e as i32).collect();
            templates[slot] = t.id.clone();
            app.call(T0 - DAY + 60, |c| {
                c.save_template(SaveTemplateRequest {
                    template: Some(t),
                    ..Default::default()
                })
            });
        }
        Self {
            sc,
            app,
            templates,
            starting,
            set_labels: HashMap::new(),
            workout_sessions: HashMap::new(),
            last: HashMap::new(),
            held: HashMap::new(),
            flags: Vec::new(),
        }
    }

    fn unit(&self) -> AppWeightUnit {
        self.app.unit()
    }

    /// A weight in the user's unit, rounded for the page.
    fn w(&self, lb: f32) -> J {
        match self.unit() {
            AppWeightUnit::Lb => num(lb),
            AppWeightUnit::Kg => num(pounds_to_kg(lb)),
        }
    }

    /// A max: a weight, or reps for a bodyweight lift.
    fn m(&self, ex: Exercise, max: f32) -> J {
        if is_bodyweight(ex) {
            num(max)
        } else {
            self.w(max)
        }
    }

    fn shown(&self, ex: Exercise, max: f32) -> String {
        match self.m(ex, max) {
            J::Num(x) if is_bodyweight(ex) => format!("{x} reps"),
            J::Num(x) => format!("{x} {}", self.unit_name()),
            _ => String::new(),
        }
    }

    fn unit_name(&self) -> &'static str {
        match self.unit() {
            AppWeightUnit::Lb => "lb",
            AppWeightUnit::Kg => "kg",
        }
    }

    /// The reps the lifter manages on a calibration rung: what its true max
    /// allows at the weight (Epley), at most the rung's five, at least one.
    fn rung_reps(&self, ex: Exercise, weight: f32, target: i32) -> i32 {
        let base =
            self.starting.get(&(ex as i32)).copied().unwrap_or_else(|| {
                schlift_core::exercise_catalog::starting_weight_lb(ex, self.unit())
            });
        let true_max = base * (self.sc.strength_factor)(ex);
        let reps = (30.0 * (true_max / weight - 1.0) + 1e-3).floor() as i32;
        reps.clamp(1, target)
    }

    fn mutate(&mut self, now: i64, m: Mutation) {
        self.app.call(now, |c| {
            c.append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![WorkoutMutation {
                    event_id: String::new(),
                    client_created_at: now,
                    mutation: Some(m),
                }],
            })
        });
    }

    fn run(mut self) -> J {
        let mut t = T0;
        let mut sessions_json = Vec::new();
        for (i, session) in self.sc.sessions.clone().iter().enumerate() {
            let n = i + 1;
            if i > 0 {
                let usual = [3, 2, 2][i % 3]; // Mon → Wed → Fri → Mon
                let days = if session.gap_days > 0 {
                    session.gap_days
                } else {
                    usual
                };
                t = (t - (t - T0).rem_euclid(DAY)) + days * DAY;
            }
            for o in &session.overrides {
                let o = *o;
                self.app.call(t - 3600, |c| c.set_override(o));
            }
            sessions_json.push(self.session(n, session, t));
        }
        let previews = self.previews(t + DAY);
        let replayed = Account::fold(&self.app.log);
        assert!(
            replayed == self.app.account,
            "{}: replaying the log rebuilds the account",
            self.sc.id
        );
        let lifts: Vec<J> = {
            let mut all: Vec<Exercise> = A.to_vec();
            all.extend(B.iter().filter(|e| !A.contains(e)));
            all.into_iter()
                .map(|ex| {
                    let r = schlift_core::exercise_catalog::rules(ex);
                    J::Obj(vec![
                        ("exercise", s(name(ex))),
                        ("name", s(exercise_display_name(ex))),
                        ("class", s(class_name(ex))),
                        ("rep_low", J::Int(r.rep_low as i64)),
                        ("rep_high", J::Int(r.rep_high as i64)),
                        ("bodyweight", J::Bool(is_bodyweight(ex))),
                        (
                            "starting_weight",
                            self.starting
                                .get(&(ex as i32))
                                .map_or(J::Null, |w| self.w(*w)),
                        ),
                    ])
                })
                .collect()
        };
        J::Obj(vec![
            ("id", s(self.sc.id)),
            ("title", s(self.sc.title)),
            ("description", s(self.sc.description)),
            ("unit", s(self.unit_name())),
            ("strength", num(self.sc.strength * 100.0)),
            ("rest_factor", num(self.sc.rest_factor)),
            ("lifts", J::Arr(lifts)),
            ("flags", J::Arr(self.flags.iter().map(Flag::json).collect())),
            ("sessions", J::Arr(sessions_json)),
            ("previews", previews),
        ])
    }

    fn session(&mut self, n: usize, script: &Session, start: i64) -> J {
        let template_id = self.templates[script.template_b as usize].clone();
        let costs = Planner::new(&self.app.account, start).costs().clone();
        let started = self.app.call(start, |c| {
            c.start_workout(StartWorkoutRequest {
                template_id,
                budget_minutes: script.budget,
                started_at: start,
                ..Default::default()
            })
        });
        let id = started.id.clone();
        self.workout_sessions.insert(id.clone(), n);
        let decisions: Vec<ExerciseDecision> = started
            .exercise_logs
            .iter()
            .filter_map(|l| l.decision.clone())
            .collect();
        let mut t = start + 60;
        for ex in &script.skip {
            let ex = *ex;
            self.app.call(t, |c| {
                c.remove_exercise(RemoveExerciseRequest {
                    workout_id: id.clone(),
                    exercise: ex as i32,
                })
            });
        }
        let mut lowered: Option<Exercise> = None;
        let mut ended = false;
        loop {
            let state = self.app.workout(t, &id);
            let Some(next) = state.next_up_set.clone() else {
                break;
            };
            let ex = Exercise::try_from(next.exercise).unwrap_or(Exercise::Unspecified);
            let decision = decisions.iter().find(|d| d.exercise == next.exercise);
            let working = !next.warmup && !next.calibration;
            let done_working = state
                .completed_sets
                .iter()
                .filter(|c| {
                    state.proposed_sets.iter().any(|p| {
                        p.id == c.proposed_set_id
                            && p.exercise == next.exercise
                            && !p.warmup
                            && !p.calibration
                    })
                })
                .count();
            let set_no = done_working + 1;
            let of = decision.map_or(0, |d| d.sets as usize);
            if working {
                if let Some((lex, from, fraction)) = script.lower {
                    if lex == ex && set_no == from && lowered != Some(ex) {
                        let to =
                            snap_weight_lb(ex, next.target_weight * (1.0 - fraction), self.unit());
                        let workout_id = id.clone();
                        self.app.call(t, |c| {
                            c.adjust_exercise_weight(AdjustExerciseWeightRequest {
                                workout_id,
                                exercise: ex as i32,
                                working_weight: to,
                                target_reps: 0,
                            })
                        });
                        lowered = Some(ex);
                        continue;
                    }
                }
            }
            let reps = if next.calibration {
                self.rung_reps(ex, next.target_weight, next.target_reps)
            } else if working {
                let short = script
                    .short
                    .iter()
                    .filter(|(sex, _)| *sex == ex && set_no == of)
                    .map(|(_, k)| *k)
                    .sum::<i32>();
                (next.target_reps - short).max(0)
            } else {
                next.target_reps
            };
            self.mutate(
                t,
                Mutation::StartSet(StartSetRequest {
                    workout_id: id.clone(),
                    proposed_set_id: next.id.clone(),
                    started_at: t,
                }),
            );
            t += LIFT_SECONDS;
            let done = self.app.call(t, |c| {
                c.complete_set(CompleteSetRequest {
                    workout_id: id.clone(),
                    proposed_set_id: next.id.clone(),
                    actual_reps: reps,
                    actual_weight: next.target_weight,
                    completed_at: t,
                })
            });
            let rest_until = done.completed_set.map_or(t, |c| c.rest_until);
            let asked = rest_until - t;
            let rest = if working {
                (asked as f32 * self.sc.rest_factor).round() as i64
            } else {
                asked
            };
            if working {
                if script
                    .end_after
                    .is_some_and(|(e, k)| e == ex && (k == set_no || (k == 99 && set_no == of)))
                {
                    t += 60;
                    let workout_id = id.clone();
                    self.app.call(t, |c| {
                        c.end_workout(EndWorkoutRequest {
                            workout_id,
                            ended_at: t,
                        })
                    });
                    ended = true;
                    break;
                }
                if script.remove_after == Some((ex, set_no)) {
                    let workout_id = id.clone();
                    self.app.call(t + 10, |c| {
                        c.remove_exercise(RemoveExerciseRequest {
                            workout_id,
                            exercise: ex as i32,
                        })
                    });
                }
            }
            t += rest.max(0);
        }
        if !ended {
            let workout_id = id.clone();
            self.app.call(t, |c| {
                c.end_workout(EndWorkoutRequest {
                    workout_id,
                    ended_at: t,
                })
            });
        }
        let state = self.app.workout(t, &id);
        let progress = self.app.view(t).get_exercise_progress();
        let ran = Ran {
            n,
            script,
            start,
            end: t,
            state: &state,
            progress: &progress,
        };
        self.record_session(&ran, &decisions, &costs)
    }

    fn record_session(
        &mut self,
        ran: &Ran,
        decisions: &[ExerciseDecision],
        costs: &schlift_core::plan::Costs,
    ) -> J {
        let Ran {
            n,
            script,
            start,
            end,
            ..
        } = *ran;
        let budget = decisions.first().map_or(0, |d| d.budget_minutes);
        let estimated: i32 = decisions.iter().map(|d| d.estimated_seconds).sum();
        let mut lifts = Vec::new();
        for d in decisions {
            let ex = Exercise::try_from(d.exercise).unwrap_or(Exercise::Unspecified);
            lifts.push(self.record_lift(ran, ex, d));
        }
        // The workout: over the budget only matters when the budget gave
        // sets above the floor; at the floor the card says how long it needs.
        let needs = (estimated as f32 / 60.0).ceil() as i32;
        let over = estimated > budget * 60;
        // The estimate against the clock, on a session run as planned.
        let actual = (end - start) as f32 / 60.0;
        let planned = estimated as f32 / 60.0;
        let as_planned = script.skip.is_empty()
            && script.end_after.is_none()
            && script.remove_after.is_none()
            && decisions.iter().all(|d| !d.calibration);
        if as_planned && (actual - planned).abs() >= 5.0 && (actual - planned).abs() >= 0.1 * actual
        {
            self.flags.push(Flag {
                severity: Severity::Info,
                kind: "estimate_off",
                session: n,
                exercise: None,
                detail: format!(
                    "estimated {planned:.1} min, took {actual:.1} min with the lifter resting \
                     as recorded"
                ),
            });
        }
        if over {
            let above_floor = decisions.iter().any(|d| {
                d.sets > MIN_SETS && !self.app.account.overrides.contains_key(&d.exercise)
            });
            self.flags.push(Flag {
                severity: if above_floor {
                    Severity::Violation
                } else {
                    Severity::Info
                },
                kind: if above_floor {
                    "over_budget"
                } else {
                    "needs_more_time"
                },
                session: n,
                exercise: None,
                detail: format!(
                    "estimated {:.1} min against a {budget} min budget{}",
                    estimated as f32 / 60.0,
                    if above_floor {
                        " with sets above the 2-set floor"
                    } else {
                        ": the card says \"needs N min\""
                    }
                ),
            });
        }
        J::Obj(vec![
            ("n", J::Int(n as i64)),
            ("date", s(date(start))),
            ("day", J::Int((start - T0).div_euclid(DAY))),
            ("template", s(if script.template_b { "B" } else { "A" })),
            ("note", s(script.note.clone())),
            ("budget_minutes", J::Int(budget as i64)),
            ("estimated_minutes", num(estimated as f32 / 60.0)),
            (
                "needs_minutes",
                if over { J::Int(needs as i64) } else { J::Null },
            ),
            ("actual_minutes", num((end - start) as f32 / 60.0)),
            (
                "sets",
                J::Arr(decisions.iter().map(|d| J::Int(d.sets as i64)).collect()),
            ),
            (
                "costs",
                J::Obj(vec![
                    ("set_seconds", num(costs.set_seconds)),
                    ("rest_heavy", num(costs.rest_seconds[0])),
                    ("rest_standard", num(costs.rest_seconds[1])),
                    ("rest_bodyweight", num(costs.rest_seconds[2])),
                    ("warmup_seconds", num(costs.warmup_seconds)),
                    ("between_seconds", num(costs.between_seconds)),
                ]),
            ),
            ("lifts", J::Arr(lifts)),
        ])
    }

    fn reason_json(&self, ex: Exercise, r: &PlanReason) -> J {
        let kind = reason_kind(r.kind);
        let versus = matches!(
            kind,
            PlanReasonKind::WeightUp
                | PlanReasonKind::WeightDown
                | PlanReasonKind::RepsUp
                | PlanReasonKind::RepsDown
                | PlanReasonKind::SameAsLast
        );
        // Against last time: weights, or for a bodyweight lift its reps.
        let (before, after) = if versus && is_bodyweight(ex) {
            (r.reps_before as f32, r.reps_after as f32)
        } else {
            (r.before, r.after)
        };
        let value = |x: f32| match kind {
            PlanReasonKind::SetsFromTime => num(x),
            _ if versus && !is_bodyweight(ex) => self.w(x),
            _ => self.m(ex, x),
        };
        let mut detail = Vec::new();
        if versus {
            let cause = PlanChangeCause::try_from(r.cause).unwrap_or(PlanChangeCause::Unspecified);
            detail.push(format!(
                "{}; {}×{} last time, {}×{} now",
                cause
                    .as_str_name()
                    .strip_prefix("PLAN_CHANGE_CAUSE_")
                    .unwrap_or_default(),
                r.sets_before,
                r.reps_before,
                r.sets_after,
                r.reps_after
            ));
            if r.days_off > 0 {
                detail.push(format!("{} days off", r.days_off));
            }
        }
        match kind {
            PlanReasonKind::TimeOff => detail.push(format!("{} days off", r.days_off)),
            PlanReasonKind::SetsFromTime => detail.push(format!(
                "{} min; {} at {} hard sets this week",
                r.budget_minutes,
                MuscleGroup::try_from(r.muscle)
                    .map(|m| schlift_core::exercise_catalog::muscle_label(m).to_string())
                    .unwrap_or_default(),
                (r.weekly_sets * 10.0).round() / 10.0
            )),
            PlanReasonKind::FirstTime if is_bodyweight(ex) => {
                detail.push("bottom of the range".into())
            }
            PlanReasonKind::FirstTime => detail.push(format!(
                "ramp from {} (starting weight {})",
                self.shown(ex, r.after),
                if r.before > 0.0 {
                    self.shown(ex, r.before)
                } else {
                    "none".into()
                }
            )),
            PlanReasonKind::UserSet => detail.push(format!("set {}", date(r.at))),
            _ => {}
        }
        if let Some(n) = self.workout_sessions.get(&r.workout_id) {
            detail.push(format!("from session {n}"));
        }
        if let Some(label) = self.set_labels.get(&r.set_id) {
            detail.push(format!("shown by {label}"));
        }
        J::Obj(vec![
            ("kind", s(reason_name(r.kind))),
            ("before", value(before)),
            ("after", value(after)),
            ("detail", s(detail.join("; "))),
        ])
    }

    fn record_lift(&mut self, ran: &Ran, ex: Exercise, d: &ExerciseDecision) -> J {
        let Ran {
            n,
            script,
            start,
            state,
            progress,
            ..
        } = *ran;
        let bodyweight = is_bodyweight(ex);
        let kinds: Vec<PlanReasonKind> = d.reasons.iter().map(|r| reason_kind(r.kind)).collect();
        let overridden = kinds.contains(&PlanReasonKind::UserSet)
            && self.app.account.overrides.contains_key(&d.exercise);
        let fixed_sets = self
            .app
            .account
            .overrides
            .get(&d.exercise)
            .and_then(|o| o.sets)
            .is_some();

        // What was done, in order.
        let by_id: HashMap<&str, &ProposedSet> = state
            .proposed_sets
            .iter()
            .map(|p| (p.id.as_str(), p))
            .collect();
        let mut done: Vec<(&CompletedSet, &ProposedSet)> = state
            .completed_sets
            .iter()
            .filter_map(|c| by_id.get(c.proposed_set_id.as_str()).map(|p| (c, *p)))
            .filter(|(_, p)| p.exercise == d.exercise)
            .collect();
        done.sort_by_key(|(c, _)| c.ended_at);
        let (mut warm, mut rung, mut work) = (0, 0, 0);
        let mut sets_json = Vec::new();
        let mut missed = false;
        let mut working_weights = Vec::new();
        for (c, p) in &done {
            let (kind, k) = if p.warmup {
                warm += 1;
                ("warmup", warm)
            } else if p.calibration {
                rung += 1;
                ("rung", rung)
            } else {
                work += 1;
                working_weights.push(c.actual_weight);
                ("work", work)
            };
            let hit = c.actual_reps >= p.target_reps;
            if kind == "work" {
                missed |= !hit;
                // Working sets after a ramp: their reps are the plan's too.
                if d.calibration
                    && !bodyweight
                    && !(d.rep_low..=d.rep_high).contains(&p.target_reps)
                    && !overridden
                {
                    self.flags.push(Flag {
                        severity: Severity::Violation,
                        kind: "reps_out_of_range",
                        session: n,
                        exercise: Some(ex),
                        detail: format!(
                            "after the ramp: {} reps, outside {}–{}",
                            p.target_reps, d.rep_low, d.rep_high
                        ),
                    });
                }
            }
            if kind != "warmup" {
                let label = if kind == "rung" {
                    format!("session {n} rung {k}")
                } else {
                    format!("session {n} set {k}")
                };
                self.set_labels.insert(p.id.clone(), label);
            }
            if kind == "warmup" {
                continue;
            }
            sets_json.push(J::Obj(vec![
                ("kind", s(kind)),
                ("n", J::Int(k)),
                ("target_reps", J::Int(p.target_reps as i64)),
                ("target_weight", self.w(p.target_weight)),
                ("reps", J::Int(c.actual_reps as i64)),
                ("weight", self.w(c.actual_weight)),
                ("hit", J::Bool(hit)),
            ]));
        }
        let removed = script.skip.contains(&ex);
        let undone = (d.sets as i64 - work).max(0);

        let changes: Vec<&WeightChange> = state
            .exercise_logs
            .iter()
            .find(|l| {
                l.decision
                    .as_ref()
                    .is_some_and(|x| x.exercise == d.exercise)
            })
            .map(|l| l.changes.iter().collect())
            .unwrap_or_default();
        let user_lowered = changes
            .iter()
            .any(|c| c.cause == WeightChangeCause::UserAdjust as i32 && c.after < c.before);
        let changes_json: Vec<J> = changes
            .iter()
            .map(|c| {
                J::Obj(vec![
                    ("cause", s(cause_name(c.cause))),
                    ("before", self.w(c.before)),
                    ("after", self.w(c.after)),
                    ("minute", J::Int((c.at - start).div_euclid(60))),
                ])
            })
            .collect();

        let point = progress
            .exercises
            .iter()
            .find(|p| p.exercise == d.exercise)
            .and_then(|p| {
                p.points.iter().find(|pt| {
                    pt.workout_id == state.workout.as_ref().map_or("", |w| w.id.as_str())
                })
            })
            .cloned();
        let max_after = point.as_ref().map(|p| p.estimated_max).filter(|m| *m > 0.0);
        let workout_id = state
            .workout
            .as_ref()
            .map_or(String::new(), |w| w.id.clone());
        let end = state.workout.as_ref().map_or(start, |w| w.end_time);
        let outcome = self
            .app
            .view(end)
            .exercise_plan(ex, 0)
            .decision
            .and_then(|next| next.reasons.first().cloned())
            .filter(|r| r.workout_id == workout_id);

        // ── The audit ──
        let mut found: Vec<(Severity, &'static str, String)> = Vec::new();
        // Reps past the top are the rule only while the next weight step
        // is out of reach at the bottom of the range (a big dumbbell jump).
        let step_out_of_reach = d.reps > d.rep_high && {
            let up = snap_weight_lb(
                ex,
                d.weight + progression_increment_lb(ex, self.unit()),
                self.unit(),
            );
            reps_covered(d.max, up, d.sets, false) < d.rep_low
        };
        if !d.calibration
            && !(d.rep_low..=d.rep_high).contains(&d.reps)
            && !overridden
            && !step_out_of_reach
        {
            found.push((
                Severity::Violation,
                "reps_out_of_range",
                format!(
                    "{} reps planned, outside {}–{}",
                    d.reps, d.rep_low, d.rep_high
                ),
            ));
        }
        if !(MIN_SETS..=MAX_SETS).contains(&d.sets) && !fixed_sets {
            found.push((
                Severity::Violation,
                "sets_out_of_range",
                format!("{} sets planned, outside {MIN_SETS}–{MAX_SETS}", d.sets),
            ));
        }
        let prev = self.last.get(&d.exercise).cloned().unwrap_or_default();
        if let Some(before) = prev.weight.filter(|_| !bodyweight && !d.calibration) {
            let excused = kinds.iter().any(|k| {
                matches!(
                    k,
                    PlanReasonKind::MaxFromMiss | PlanReasonKind::TimeOff | PlanReasonKind::UserSet
                )
            }) || prev.lowered;
            if d.weight + 1e-3 < before && !excused {
                let why = d
                    .reasons
                    .first()
                    .map(|r| reason_name(r.kind))
                    .unwrap_or_default();
                // More sets than last time: the max covers fewer reps across
                // them (half a rep of fatigue a set), and short of the bottom
                // of the range the plan steps down. The rules as written,
                // but a lifter sees the bar get lighter after a good day.
                let more_sets = d.sets > prev.sets;
                found.push((
                    if more_sets {
                        Severity::Warning
                    } else {
                        Severity::Violation
                    },
                    "weight_down",
                    format!(
                        "planned {} × {} after lifting {} × {} last time, with no miss, time \
                         off, override or lowered weight behind it (reason: {why}){}",
                        d.sets,
                        self.shown(ex, d.weight),
                        prev.sets,
                        self.shown(ex, before),
                        if more_sets {
                            "; more sets than last time, so the max covers fewer reps \
                             at the old weight"
                        } else {
                            ""
                        }
                    ),
                ));
            }
        }
        if let (Some(after), true) = (max_after, d.max > 0.0) {
            let stopped = outcome
                .as_ref()
                .is_some_and(|r| reason_kind(r.kind) == PlanReasonKind::Held)
                && (undone > 0 || removed);
            if missed && !stopped && after > d.max + 0.05 {
                found.push((
                    Severity::Violation,
                    "max_up_after_miss",
                    format!(
                        "a set was missed, yet the max went {} → {}",
                        self.shown(ex, d.max),
                        self.shown(ex, after)
                    ),
                ));
            }
            if !missed && work > 0 && undone == 0 && !removed && after + 0.05 < d.max {
                found.push((
                    Severity::Violation,
                    "max_down_after_hit",
                    format!(
                        "every rep hit, yet the max went {} → {}",
                        self.shown(ex, d.max),
                        self.shown(ex, after)
                    ),
                ));
            }
        }
        self.flags
            .extend(found.into_iter().map(|(severity, kind, detail)| Flag {
                severity,
                kind,
                session: n,
                exercise: Some(ex),
                detail,
            }));
        // Held with every rep done and nothing lowered: the max did not move
        // although the lifter did all they were asked. Three in a row is a
        // stall (a light lift capped at the top of its range whose next
        // weight step is not covered, or a lift climbing back one step a
        // session from a lowered weight).
        let held_clean = outcome
            .as_ref()
            .is_some_and(|r| reason_kind(r.kind) == PlanReasonKind::Held)
            && !missed
            && work > 0
            && undone == 0
            && !removed
            && !user_lowered;
        let streak = self.held.entry(d.exercise).or_default();
        *streak = if held_clean { *streak + 1 } else { 0 };
        if *streak == STALL_SESSIONS {
            self.flags.push(Flag {
                severity: Severity::Warning,
                kind: "stalled",
                session: n,
                exercise: Some(ex),
                detail: format!(
                    "{STALL_SESSIONS} sessions in a row of every rep hit, yet the max held at \
                     {} (this time {} × {} for {} sets): what the sets show never passes \
                     the max, so the plan cannot move it",
                    self.shown(ex, d.max),
                    self.shown(ex, d.weight),
                    d.reps,
                    d.sets
                ),
            });
        }
        if let Some(last) = working_weights.last() {
            self.last.insert(
                d.exercise,
                LastDone {
                    weight: Some(*last),
                    lowered: user_lowered,
                    sets: work as i32,
                },
            );
        }

        J::Obj(vec![
            ("exercise", s(name(ex))),
            (
                "decision",
                J::Obj(vec![
                    ("sets", J::Int(d.sets as i64)),
                    ("reps", J::Int(d.reps as i64)),
                    ("weight", self.w(d.weight)),
                    ("rest_seconds", J::Int(d.rest_seconds as i64)),
                    ("warmups", J::Bool(d.warmups)),
                    ("calibration", J::Bool(d.calibration)),
                    ("max", self.m(ex, d.max)),
                    ("estimated_seconds", J::Int(d.estimated_seconds as i64)),
                    (
                        "reasons",
                        J::Arr(d.reasons.iter().map(|r| self.reason_json(ex, r)).collect()),
                    ),
                ]),
            ),
            ("removed", J::Bool(removed)),
            ("undone", J::Int(undone)),
            ("warmups_done", J::Int(warm)),
            ("done", J::Arr(sets_json)),
            ("changes", J::Arr(changes_json)),
            (
                "outcome",
                outcome
                    .as_ref()
                    .map_or(J::Null, |r| self.reason_json(ex, r)),
            ),
            ("max_after", max_after.map_or(J::Null, |m| self.m(ex, m))),
            (
                "top_weight",
                point.as_ref().map_or(J::Null, |p| self.w(p.top_weight)),
            ),
        ])
    }

    /// Home's preview of every template at each budget.
    fn previews(&mut self, now: i64) -> J {
        if self.sc.preview_budgets.is_empty() {
            return J::Arr(Vec::new());
        }
        let ids: Vec<String> = self
            .sc
            .preview_library
            .iter()
            .map(|s| s.to_string())
            .collect();
        if !ids.is_empty() {
            self.app.call(now - 600, |c| {
                c.add_library_templates(AddLibraryTemplatesRequest {
                    library_ids: ids,
                    entries: vec![],
                })
            });
        }
        let mut rows = Vec::new();
        for budget in self.sc.preview_budgets.clone() {
            let home = self.app.view(now).home(budget);
            for t in &home.templates {
                let Some(plan) = home.template_plans.iter().find(|p| p.template_id == t.id) else {
                    continue;
                };
                let decisions: Vec<&ExerciseDecision> = plan
                    .plans
                    .iter()
                    .filter_map(|p| p.decision.as_ref())
                    .collect();
                let over = plan.estimated_seconds > budget * 60;
                if over && decisions.iter().any(|d| d.sets > MIN_SETS) {
                    self.flags.push(Flag {
                        severity: Severity::Violation,
                        kind: "over_budget",
                        session: 0,
                        exercise: None,
                        detail: format!(
                            "Home preview of {} at {budget} min: estimated {:.1} min with \
                             sets above the floor",
                            t.name,
                            plan.estimated_seconds as f32 / 60.0
                        ),
                    });
                }
                // The longest it gets bounds the estimate, and a budget at
                // or past it plans exactly that.
                let capped = budget * 60 >= plan.max_seconds;
                if plan.estimated_seconds > plan.max_seconds
                    || (capped && plan.estimated_seconds != plan.max_seconds)
                {
                    self.flags.push(Flag {
                        severity: Severity::Violation,
                        kind: "longest_off",
                        session: 0,
                        exercise: None,
                        detail: format!(
                            "Home preview of {} at {budget} min: estimated {:.1} min, the \
                             longest it gets {:.1} min",
                            t.name,
                            plan.estimated_seconds as f32 / 60.0,
                            plan.max_seconds as f32 / 60.0
                        ),
                    });
                }
                rows.push(J::Obj(vec![
                    ("template", s(t.name.clone())),
                    ("budget_minutes", J::Int(budget as i64)),
                    (
                        "estimated_minutes",
                        num(plan.estimated_seconds as f32 / 60.0),
                    ),
                    ("max_minutes", num(plan.max_seconds as f32 / 60.0)),
                    ("capped", J::Bool(capped)),
                    (
                        "needs_minutes",
                        if over {
                            J::Int((plan.estimated_seconds as f32 / 60.0).ceil() as i64)
                        } else {
                            J::Null
                        },
                    ),
                    (
                        "lifts",
                        J::Arr(
                            decisions
                                .iter()
                                .map(|d| {
                                    let ex = Exercise::try_from(d.exercise)
                                        .unwrap_or(Exercise::Unspecified);
                                    J::Obj(vec![
                                        ("exercise", s(name(ex))),
                                        ("sets", J::Int(d.sets as i64)),
                                        ("reps", J::Int(d.reps as i64)),
                                        ("weight", self.w(d.weight)),
                                        ("estimated_seconds", J::Int(d.estimated_seconds as i64)),
                                    ])
                                })
                                .collect(),
                        ),
                    ),
                ]));
            }
        }
        J::Arr(rows)
    }
}

#[test]
fn progression_scenarios() {
    let mut out = Vec::new();
    let mut warnings = Vec::new();
    for sc in scenarios() {
        let runner = Runner::new(&sc);
        let json = runner_run(runner, &mut warnings);
        out.push(json);
    }
    let doc = J::Obj(vec![
        (
            "generated_by",
            s("core/tests/progression_scenarios.rs (UPDATE_SCENARIOS=1 cargo test -p schlift-core --test progression_scenarios)"),
        ),
        ("scenarios", J::Arr(out)),
        ("rotation", rotation().json()),
    ]);
    let mut text = String::new();
    doc.write(&mut text, 0);
    text.push('\n');

    let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join(SNAPSHOT);
    if std::env::var_os(UPDATE_ENV).is_some() {
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(&path, &text).unwrap();
    } else {
        let committed = std::fs::read_to_string(&path).unwrap_or_else(|_| {
            panic!(
                "testdata/progression_scenarios.json is missing: write it with \
                 `{UPDATE_ENV}=1 cargo test -p schlift-core --test progression_scenarios`"
            )
        });
        if committed != text {
            let line = committed
                .lines()
                .zip(text.lines())
                .position(|(a, b)| a != b)
                .unwrap_or_else(|| committed.lines().count().min(text.lines().count()));
            panic!(
                "the rules changed what lifters are told: testdata/progression_scenarios.json \
                 differs from this run (first at line {}). Regenerate with \
                 `{UPDATE_ENV}=1 cargo test -p schlift-core --test progression_scenarios` \
                 (or `make progression-explorer`) and review the diff.",
                line + 1
            );
        }
    }
    assert!(
        warnings.is_empty(),
        "audit violations on the real rules:\n{}",
        warnings.join("\n")
    );
}

fn runner_run(runner: Runner, warnings: &mut Vec<String>) -> J {
    let id = runner.sc.id;
    let json = runner.run();
    if let J::Obj(fields) = &json {
        if let Some((_, J::Arr(flags))) = fields.iter().find(|(k, _)| *k == "flags") {
            for f in flags {
                let mut line = String::new();
                f.write(&mut line, 0);
                if line.contains("\"violation\"") {
                    warnings.push(format!("{id}: {line}"));
                }
            }
        }
    }
    json
}

// ── Rotation: a lifter who does what Home suggests ──

/// The rotation: what onboarding picks.
const ROTATION: [&str; 5] = [
    "full_body",
    "upper",
    "lower",
    "stronglifts_a",
    "stronglifts_b",
];
/// Training days, Monday = 0: four a week with one- and two-day gaps.
const ROTATION_DAYS: [i64; 4] = [0, 2, 3, 5];
const ROTATION_WEEKS: i64 = 3;
/// 17:30 UTC: after work.
const ROTATION_HOUR: i64 = 10 * 3600 + 1800;
/// Full Body (every big muscle in one template) may take at most this
/// share of the picks.
const BROAD_SHARE: f32 = 0.4;

/// One rotation template as Home saw it on a training day.
struct Candidate {
    id: String,
    name: String,
    /// Σ deficit of its recovered primary muscles below the band.
    score: f32,
    behind: Vec<MuscleGroup>,
    /// Days since it was last started (None = never).
    last_days: Option<f32>,
    /// Its first lift's muscle still recovering: (muscle, hours left).
    first_recovering: Option<(MuscleGroup, i32)>,
}

/// One training day: what Home suggested, why, and what the others had.
struct RotationDay {
    n: usize,
    at: i64,
    picked: String,
    reason: SuggestionReason,
    candidates: Vec<Candidate>,
    working_sets: usize,
    minutes: f32,
}

struct RotationRun {
    days: Vec<RotationDay>,
    check: RotationCheck,
    names: HashMap<String, String>,
    flags: Vec<Flag>,
}

fn muscle(m: i32) -> String {
    let m = MuscleGroup::try_from(m).unwrap_or(MuscleGroup::Unspecified);
    schlift_core::exercise_catalog::muscle_label(m).to_string()
}

/// Onboard with the five, then every training day for three weeks start
/// the suggested template at 60 minutes and do every set as planned.
fn rotation() -> RotationRun {
    use schlift_core::recovery::per_muscle_recovery;
    use schlift_core::volume::{muscle_volume_7d, suggest_template};

    let mut app = App::new("rotation");
    app.call(T0 - DAY, |c| {
        c.complete_onboarding(CompleteOnboardingRequest {
            unit: WeightUnit::Lb as i32,
            library_ids: ROTATION.iter().map(|s| s.to_string()).collect(),
            strength: Some(0.3),
            ..Default::default()
        })
    });
    let starting = app.account.starting_weights.clone();
    let names: HashMap<String, String> = app
        .account
        .templates
        .iter()
        .map(|t| (t.id.clone(), t.name.clone()))
        .collect();
    let mut last_started: HashMap<String, i64> = HashMap::new();
    let mut days = Vec::new();
    for week in 0..ROTATION_WEEKS {
        for day in ROTATION_DAYS {
            let at = T0 - 7 * 3600 + (week * 7 + day) * DAY + ROTATION_HOUR;
            let home = app.view(at).home(60);
            let picked = home.suggested_template_id.clone();
            assert!(!picked.is_empty(), "a suggestion every day");

            // Each rotation template on its own: what it would score.
            let history = app.account.workouts.clone();
            let volume = muscle_volume_7d(&history, at);
            let recovery = per_muscle_recovery(&history, at);
            let candidates = home
                .templates
                .iter()
                .filter(|t| t.in_rotation)
                .map(|t| {
                    let alone = suggest_template(
                        std::slice::from_ref(t),
                        &volume,
                        &recovery,
                        at,
                        &last_started,
                    )
                    .expect("a template in rotation is suggested alone");
                    let behind: Vec<MuscleGroup> = alone
                        .reason
                        .behind
                        .iter()
                        .filter_map(|m| MuscleGroup::try_from(m.muscle).ok())
                        .collect();
                    Candidate {
                        id: t.id.clone(),
                        name: t.name.clone(),
                        score: alone
                            .reason
                            .behind
                            .iter()
                            .map(|m| m.target as f32 - m.sets_7d)
                            .sum(),
                        behind,
                        last_days: last_started
                            .get(&t.id)
                            .map(|s| (at - s) as f32 / DAY as f32),
                        first_recovering: alone.reason.first_lift_recovering.map(|r| {
                            (
                                MuscleGroup::try_from(r.muscle).unwrap_or(MuscleGroup::Unspecified),
                                r.hours_remaining,
                            )
                        }),
                    }
                })
                .collect();

            let started = app.call(at, |c| {
                c.start_workout(StartWorkoutRequest {
                    template_id: picked.clone(),
                    budget_minutes: 60,
                    started_at: at,
                    ..Default::default()
                })
            });
            last_started.insert(picked.clone(), at);
            let (end, working_sets) = lift_everything(&mut app, &started.id, at, &starting);
            days.push(RotationDay {
                n: days.len() + 1,
                at,
                picked,
                reason: home.suggestion_reason.clone().unwrap_or_default(),
                candidates,
                working_sets,
                minutes: (end - at) as f32 / 60.0,
            });
        }
    }
    let end = days.last().map_or(T0, |d| d.at) + DAY;
    let check = app
        .view(end)
        .home(60)
        .rotation_check
        .expect("home has the check");
    assert!(
        Account::fold(&app.log) == app.account,
        "rotation: replaying the log rebuilds the account"
    );
    let mut run = RotationRun {
        days,
        check,
        names,
        flags: Vec::new(),
    };
    run.audit();
    run
}

/// Every set the workout plans, at its target (a calibration rung at what
/// a lifter as strong as the slider said manages), resting as asked.
fn lift_everything(
    app: &mut App,
    id: &str,
    start: i64,
    starting: &std::collections::BTreeMap<i32, f32>,
) -> (i64, usize) {
    let unit = app.unit();
    let mut t = start + 60;
    let mut working = 0;
    loop {
        let state = app.workout(t, id);
        let Some(next) = state.next_up_set.clone() else {
            break;
        };
        let ex = Exercise::try_from(next.exercise).unwrap_or(Exercise::Unspecified);
        let reps = if next.calibration {
            let base = starting
                .get(&(ex as i32))
                .copied()
                .unwrap_or_else(|| schlift_core::exercise_catalog::starting_weight_lb(ex, unit));
            ((30.0 * (base / next.target_weight - 1.0) + 1e-3).floor() as i32)
                .clamp(1, next.target_reps)
        } else {
            next.target_reps
        };
        if !next.warmup && !next.calibration {
            working += 1;
        }
        app.call(t, |c| {
            c.append_workout_mutations(AppendWorkoutMutationsRequest {
                mutations: vec![WorkoutMutation {
                    event_id: String::new(),
                    client_created_at: t,
                    mutation: Some(Mutation::StartSet(StartSetRequest {
                        workout_id: id.to_string(),
                        proposed_set_id: next.id.clone(),
                        started_at: t,
                    })),
                }],
            })
        });
        t += LIFT_SECONDS;
        let done = app.call(t, |c| {
            c.complete_set(CompleteSetRequest {
                workout_id: id.to_string(),
                proposed_set_id: next.id.clone(),
                actual_reps: reps,
                actual_weight: next.target_weight,
                completed_at: t,
            })
        });
        t = done.completed_set.map_or(t, |c| c.rest_until.max(t));
    }
    app.call(t, |c| {
        c.end_workout(EndWorkoutRequest {
            workout_id: id.to_string(),
            ended_at: t,
        })
    });
    (t, working)
}

impl RotationRun {
    fn name(&self, id: &str) -> String {
        self.names.get(id).cloned().unwrap_or_default()
    }

    /// Violations: the same template two training days running while
    /// another had recovered muscles behind; a template picked while its
    /// first lift's muscle recovered, with another ready; Full Body over its
    /// share. Info: a fallback day, a rotation template never picked (the
    /// rotation check's overlap warning covers a template inside another).
    fn audit(&mut self) {
        let mut flags = Vec::new();
        for day in &self.days {
            let picked = day.candidates.iter().find(|c| c.id == day.picked);
            if let Some((m, hours)) = picked.and_then(|c| c.first_recovering) {
                if day.reason.first_lift_recovering.is_none() {
                    flags.push(Flag {
                        severity: Severity::Violation,
                        kind: "first_lift_recovering",
                        session: day.n,
                        exercise: None,
                        detail: format!(
                            "{} opens on {} with {hours}h of recovery left",
                            self.name(&day.picked),
                            muscle(m as i32)
                        ),
                    });
                }
            }
        }
        for pair in self.days.windows(2) {
            let (before, day) = (&pair[0], &pair[1]);
            if before.picked != day.picked {
                continue;
            }
            let other: Vec<&Candidate> = day
                .candidates
                .iter()
                .filter(|c| c.id != day.picked && c.score > 0.0 && c.first_recovering.is_none())
                .collect();
            if !other.is_empty() {
                flags.push(Flag {
                    severity: Severity::Violation,
                    kind: "repeat",
                    session: day.n,
                    exercise: None,
                    detail: format!(
                        "{} again, while {} had recovered muscles behind",
                        self.name(&day.picked),
                        other
                            .iter()
                            .map(|c| c.name.clone())
                            .collect::<Vec<_>>()
                            .join(", ")
                    ),
                });
            }
        }
        for id in self.names.keys() {
            if !self.days.iter().any(|d| &d.picked == id) {
                flags.push(Flag {
                    severity: Severity::Info,
                    kind: "never_picked",
                    session: 0,
                    exercise: None,
                    detail: format!("{} was never suggested", self.name(id)),
                });
            }
        }
        let broad = self
            .days
            .iter()
            .filter(|d| self.name(&d.picked) == "Full Body")
            .count();
        if broad as f32 > BROAD_SHARE * self.days.len() as f32 {
            flags.push(Flag {
                severity: Severity::Violation,
                kind: "broad_dominates",
                session: 0,
                exercise: None,
                detail: format!("Full Body took {broad} of {} days", self.days.len()),
            });
        }
        for day in &self.days {
            if day.reason.fallback {
                flags.push(Flag {
                    severity: Severity::Info,
                    kind: "fallback",
                    session: day.n,
                    exercise: None,
                    detail: "nothing recovered and behind: the least recent template".into(),
                });
            }
        }
        flags.sort_by(|a, b| a.session.cmp(&b.session).then(a.detail.cmp(&b.detail)));
        self.flags = flags;
    }

    fn json(&self) -> J {
        let weekday = |t: i64| {
            ["Thu", "Fri", "Sat", "Sun", "Mon", "Tue", "Wed"]
                [t.div_euclid(DAY).rem_euclid(7) as usize]
        };
        let days = self
            .days
            .iter()
            .map(|d| {
                J::Obj(vec![
                    ("n", J::Int(d.n as i64)),
                    ("date", s(date(d.at))),
                    ("weekday", s(weekday(d.at))),
                    ("template", s(self.name(&d.picked))),
                    ("fallback", J::Bool(d.reason.fallback)),
                    (
                        "first_lift_recovering",
                        d.reason
                            .first_lift_recovering
                            .as_ref()
                            .map_or(J::Null, |r| {
                                J::Obj(vec![
                                    ("muscle", s(muscle(r.muscle))),
                                    ("hours", J::Int(r.hours_remaining as i64)),
                                ])
                            }),
                    ),
                    (
                        "behind",
                        J::Arr(
                            d.reason
                                .behind
                                .iter()
                                .map(|m| {
                                    J::Obj(vec![
                                        ("muscle", s(muscle(m.muscle))),
                                        ("sets", num(m.sets_7d)),
                                        ("target", J::Int(m.target as i64)),
                                    ])
                                })
                                .collect(),
                        ),
                    ),
                    (
                        "recovering",
                        J::Arr(
                            d.reason
                                .recovering
                                .iter()
                                .map(|r| {
                                    J::Obj(vec![
                                        ("muscle", s(muscle(r.muscle))),
                                        ("hours", J::Int(r.hours_remaining as i64)),
                                    ])
                                })
                                .collect(),
                        ),
                    ),
                    (
                        "candidates",
                        J::Arr(
                            d.candidates
                                .iter()
                                .map(|c| {
                                    J::Obj(vec![
                                        ("template", s(c.name.clone())),
                                        ("score", num(c.score)),
                                        (
                                            "behind",
                                            J::Arr(
                                                c.behind
                                                    .iter()
                                                    .map(|m| s(muscle(*m as i32)))
                                                    .collect(),
                                            ),
                                        ),
                                        ("last_days", c.last_days.map_or(J::Null, num)),
                                        (
                                            "first_recovering",
                                            c.first_recovering.map_or(J::Null, |(m, h)| {
                                                J::Obj(vec![
                                                    ("muscle", s(muscle(m as i32))),
                                                    ("hours", J::Int(h as i64)),
                                                ])
                                            }),
                                        ),
                                    ])
                                })
                                .collect(),
                        ),
                    ),
                    ("working_sets", J::Int(d.working_sets as i64)),
                    ("minutes", num(d.minutes)),
                ])
            })
            .collect();
        let check = J::Obj(vec![
            (
                "volume",
                J::Arr(
                    self.check
                        .volume
                        .iter()
                        .map(|v| {
                            J::Obj(vec![
                                ("muscle", s(muscle(v.muscle))),
                                ("sets", num(v.completed_sets_7d)),
                            ])
                        })
                        .collect(),
                ),
            ),
            (
                "warnings",
                J::Arr(
                    self.check
                        .warnings
                        .iter()
                        .map(|w| {
                            let kind = RotationWarningKind::try_from(w.kind)
                                .unwrap_or(RotationWarningKind::Unspecified);
                            J::Obj(vec![
                                (
                                    "kind",
                                    s(kind
                                        .as_str_name()
                                        .strip_prefix("ROTATION_WARNING_KIND_")
                                        .unwrap_or_default()),
                                ),
                                (
                                    "muscles",
                                    J::Arr(w.muscles.iter().map(|m| s(muscle(*m))).collect()),
                                ),
                                (
                                    "templates",
                                    J::Arr(
                                        w.template_ids.iter().map(|t| s(self.name(t))).collect(),
                                    ),
                                ),
                                ("shared", J::Int(w.shared as i64)),
                                ("of", J::Int(w.of as i64)),
                            ])
                        })
                        .collect(),
                ),
            ),
        ]);
        J::Obj(vec![
            ("title", s("Rotation: following the suggestion")),
            (
                "description",
                s(
                    "Onboarded with Full Body, Upper, Lower and StrongLifts A and B in \
                   rotation; trains Mon, Wed, Thu and Sat at 17:30 for three weeks, \
                   starting whatever Home suggests at 60 minutes and doing every set.",
                ),
            ),
            ("flags", J::Arr(self.flags.iter().map(Flag::json).collect())),
            ("days", J::Arr(days)),
            ("check", check),
        ])
    }
}

/// Following the suggestion turns the rotation over: no template twice
/// running while another had recovered muscles behind, none opening on a
/// muscle still recovering while another was ready, and Full Body no more
/// than 40% of days.
#[test]
fn the_rotation_turns_over() {
    let run = rotation();
    let picks: Vec<String> = run
        .days
        .iter()
        .map(|d| format!("{} {}", date(d.at), run.name(&d.picked)))
        .collect();
    let violations: Vec<String> = run
        .flags
        .iter()
        .filter(|f| f.severity == Severity::Violation)
        .map(|f| format!("{}: {}", f.kind, f.detail))
        .collect();
    assert!(violations.is_empty(), "{violations:#?}\npicks: {picks:#?}");
    assert_eq!(run.days.len(), 12);
}
