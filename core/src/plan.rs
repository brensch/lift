//! The planner: what every lift is given — its sets, reps, weight and rest
//! — read off the account's program (`crate::program`), the lift's history
//! and the time the user has. It is an interpreter: every rule and number
//! is the program's, and the same program, history, time and budget always
//! give the same decisions.
//!
//! **The walk.** Every lift has an estimated max (a rep max for bodyweight
//! lifts), worked out by walking its finished sessions in order. A set
//! shows the program's Epley estimate:
//!
//! ```text
//! shown max = weight × (1 + (reps + reserve + fatigue × (set number − 1)) / divisor)
//! ```
//!
//! with `estimate.reserve_when_hit` reps of reserve when it hit its target
//! (none when it ran short).
//!
//! | Session | The max after it |
//! |---|---|
//! | every working rep hit | the higher of the max before and what the session shows with one more rep on every set |
//! | a rep missed | the most any working set shows, never more than the max before |
//! | stopped early, or a miss rushed (started before the previous set's rest was up) | unchanged |
//!
//! Time away cuts it by the program's `time_off` table. A lift never done
//! runs the calibration ramp, whose rungs give the first max. An override
//! (weight and reps, maybe sets) is converted to the max that prescribes it
//! and is a new starting point.
//!
//! **The rule.** Each lift follows a progression of the program's (its own,
//! or its class's): `estimated_max` plans from the walked max in the class's
//! rep range; `fixed`, `linear`, `double`, `cycle` and `formula` as the
//! guide describes. A rule that names no sets leaves them to the time
//! budget: the program's minimum a lift, then one at a time up to its
//! maximum, to the lift whose primary muscle is furthest below the weekly
//! target, until the next would pass the budget.
//!
//! **Why.** A plan's reasons lead with the comparison with the lift's last
//! session — heavier, lighter, more reps, fewer, the same — and why in those
//! terms, then the rule's own steps.
//!
//! Everything here is pure. A workout's start records what it decides;
//! folding the event lays the sets out from that record and never runs it.

use std::collections::{BTreeMap, HashMap, HashSet};

use crate::account::Account;
use crate::exercise_progress::{session_outcomes, SessionOutcome, SetDone};
use crate::history::{workout_time, WorkoutRecord};
use crate::pb::{
    CompletedSet, ExerciseDecision, ExercisePlan, PlanChangeCause, PlanReason, PlanReasonKind,
    PlannedSet, ProposedSet, RepsLeft, SetRole,
};
use crate::program::formula::{Evaluator, Scope};
use crate::program::{
    Calibration, Estimate, Formula, GroupDef, Muscle, Program, Progression, Role, Scheme,
};
use crate::volume::weekly_sets;
use crate::weight_units::AppWeightUnit;

pub const DAY: i64 = 24 * 3600;

/// The weight and reps (and maybe sets) the user set by hand for a lift.
#[derive(Clone, Debug, PartialEq)]
pub struct Override {
    pub at: i64,
    pub weight: f32, // lb
    pub reps: i32,
    pub sets: Option<i32>,
}

// ── The estimate ──

impl Estimate {
    /// What one set shows (see the module docs): an estimated max, or for a
    /// bodyweight lift a rep max.
    pub fn shown_max(
        &self,
        weight: f32,
        reps: i32,
        reserve: f32,
        set_number: usize,
        bodyweight: bool,
    ) -> f32 {
        let reps =
            reps as f32 + reserve + self.fatigue_per_set * set_number.saturating_sub(1) as f32;
        if bodyweight {
            reps
        } else {
            weight * (1.0 + reps / self.divisor)
        }
    }

    /// The max that `sets` × `reps` @ `weight` takes: the last set's, with
    /// the reserve a hit counts.
    pub fn max_needed(&self, weight: f32, reps: i32, sets: i32, bodyweight: bool) -> f32 {
        self.shown_max(
            weight,
            reps,
            self.reserve_when_hit,
            sets.max(1) as usize,
            bodyweight,
        )
    }

    /// The reps in reserve the last of `sets` sets keeps.
    fn reserve(&self, sets: i32) -> f32 {
        self.reserve_when_hit + self.fatigue_per_set * (sets.max(1) - 1) as f32
    }

    /// The weight `max` takes for `sets` × `reps`: the inverse of
    /// [Estimate::max_needed].
    pub fn weight_for(&self, max: f32, reps: i32, sets: i32) -> f32 {
        max / (1.0 + (reps as f32 + self.reserve(sets)) / self.divisor)
    }

    /// The most reps the max covers at `weight` across `sets` (may be below
    /// zero when it covers none).
    pub fn reps_covered(&self, max: f32, weight: f32, sets: i32, bodyweight: bool) -> i32 {
        let reserve = self.reserve(sets);
        let reps = if bodyweight || weight <= 0.0 {
            max - reserve
        } else {
            (max / weight - 1.0) * self.divisor - reserve
        };
        (reps + 1e-3).floor() as i32
    }
}

impl Calibration {
    /// The reps in reserve a ramp rung's answer to "how many more could you
    /// have done?" counts (`RepsLeft`). None when unanswered or answered
    /// with a specific jump: a full rung then counts the usual reserve.
    pub fn answered_reserve(&self, reps_left: i32) -> Option<f32> {
        match RepsLeft::try_from(reps_left).ok()? {
            RepsLeft::ZeroToOne => Some(self.reserve_zero_to_one),
            RepsLeft::TwoToFour => Some(self.reserve_two_to_four),
            RepsLeft::FivePlus => Some(self.reserve_five_plus),
            RepsLeft::Unspecified => None,
        }
    }
}

impl Program {
    /// The max cut for `days` away: the factor of the longest `time_off`
    /// entry reached, or none.
    pub fn time_off_factor(&self, days: i64) -> f32 {
        self.time_off
            .iter()
            .filter(|t| days >= t.days)
            .max_by_key(|t| t.days)
            .map_or(1.0, |t| t.factor)
    }

    /// The weight and reps a max gives, in order:
    ///
    /// 1. the last weight, for as many reps as the max covers there;
    /// 2. past the top of the range: one step up, for as many reps as the
    ///    max covers there (capped at the top) — or, when the step covers
    ///    less than the bottom (a big jump between dumbbells), the last
    ///    weight for every rep the max covers, past the top, until the step
    ///    fits;
    /// 3. short of the bottom, or 4. no last weight: the heaviest loadable
    ///    weight the max covers at the bottom, for as many reps as it
    ///    covers.
    ///
    /// Bodyweight lifts keep their weight and take the reps.
    pub fn choose(
        &self,
        ex: &str,
        max: f32,
        last_weight: Option<f32>,
        shape: Shape,
        unit: AppWeightUnit,
    ) -> (f32, i32) {
        let Shape {
            sets,
            rep_low,
            rep_high,
        } = shape;
        let e = &self.estimate;
        if self.is_bodyweight(ex) {
            let weight = last_weight.unwrap_or(0.0);
            return (
                weight,
                e.reps_covered(max, weight, sets, true)
                    .clamp(rep_low, rep_high),
            );
        }
        if let Some(last) = last_weight.filter(|w| *w > 0.0) {
            let last = self.snap_lb(ex, last, unit);
            let reps = e.reps_covered(max, last, sets, false);
            if reps > rep_high {
                let up = self.snap_lb(ex, last + self.step_lb(ex, unit), unit);
                let up_reps = e.reps_covered(max, up, sets, false);
                return if up_reps >= rep_low {
                    (up, up_reps.min(rep_high))
                } else {
                    (last, reps)
                };
            }
            if reps >= rep_low {
                return (last, reps);
            }
        }
        let weight = self.snap_down_lb(ex, e.weight_for(max, rep_low, sets), unit);
        (
            weight,
            e.reps_covered(max, weight, sets, false)
                .clamp(rep_low, rep_high),
        )
    }
}

/// How many working sets a plan has and the rep range it works in.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Shape {
    pub sets: i32,
    pub rep_low: i32,
    pub rep_high: i32,
}

impl Shape {
    pub fn of(d: &ExerciseDecision) -> Self {
        Self {
            sets: d.sets,
            rep_low: d.rep_low,
            rep_high: d.rep_high,
        }
    }
}

// ── The walk ──

/// A lift's history, walked: where its max stands and why.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Walk {
    /// None until a session (or an override) shows one.
    pub max: Option<f32>,
    /// The heaviest working set's weight: a weight lowered part-way is a bad
    /// day, not where the next plan starts. None when the max came from a
    /// ramp alone.
    pub last_weight: Option<f32>,
    /// When the max was last set: the last session's end, or the override.
    pub last_at: i64,
    /// The override is the latest word: no session since it.
    pub from_override: bool,
    /// The step that set the max.
    pub reason: Option<PlanReason>,
    /// The max after each session, oldest first: (workout id, max).
    pub points: Vec<(String, f32)>,
    /// The last session's working numbers, which the next plan is compared
    /// with. None after an override, or when the last session was a ramp
    /// alone.
    pub last: Option<LastSession>,
}

/// What a lift's last session lifted: its heaviest working set's weight
/// and the reps it was planned for, the working sets planned, and how it
/// went.
#[derive(Clone, Debug, PartialEq)]
pub struct LastSession {
    pub weight: f32, // lb
    pub reps: i32,
    pub sets: i32,
    /// The most reps done in one working set at that weight.
    pub best_reps: i32,
    /// Hit, Missed, StoppedEarly or Rushed.
    pub outcome: PlanChangeCause,
    /// The reps done on its as-many-as-you-can set (the most, with several);
    /// 0 when it had none.
    pub amrap_reps: i32,
    /// The reps left its working sets' effort answers counted, on average
    /// (the program's calibration reserves); None when none was answered.
    pub rir: Option<f32>,
}

/// Walk a lift's finished sessions (oldest first). The override takes its
/// place among them by time and starts the walk again from its max.
pub fn walk(
    program: &Program,
    ex: &str,
    sessions: &[SessionOutcome],
    over: Option<&Override>,
) -> Walk {
    // A lift counted in seconds or metres walks like a bodyweight one: its
    // max is the most it showed of its number.
    let walker = Walker {
        program,
        bodyweight: program.is_bodyweight(ex)
            || program
                .exercise(ex)
                .is_some_and(|e| e.measure != crate::program::Measure::Reps),
    };
    let mut walk = Walk::default();
    let mut pending = over;
    for session in sessions {
        if let Some(o) = pending.filter(|o| o.at < session.at) {
            walker.apply_override(&mut walk, o);
            pending = None;
        }
        if let Some(max) = walk.max {
            let days = session.started_at.saturating_sub(walk.last_at) / DAY;
            walk.max = Some(max * program.time_off_factor(days));
        }
        walker.step(&mut walk, session);
    }
    if let Some(o) = pending {
        walker.apply_override(&mut walk, o);
    }
    walk
}

struct Walker<'a> {
    program: &'a Program,
    bodyweight: bool,
}

impl Walker<'_> {
    fn estimate(&self) -> &Estimate {
        &self.program.estimate
    }

    fn apply_override(&self, walk: &mut Walk, o: &Override) {
        let after = self.estimate().max_needed(
            o.weight,
            o.reps,
            o.sets.unwrap_or(self.program.sets.override_sets),
            self.bodyweight,
        );
        walk.reason = Some(PlanReason {
            kind: PlanReasonKind::UserSet as i32,
            before: walk.max.unwrap_or(0.0),
            after,
            at: o.at,
            ..Default::default()
        });
        walk.max = Some(after);
        walk.last_weight = Some(o.weight);
        walk.last_at = o.at;
        walk.from_override = true;
        walk.last = None;
    }

    /// The most any of `sets` shows, with `extra` reps on each, and the set.
    fn most_shown<'s>(&self, sets: &'s [SetDone], extra: i32) -> Option<(f32, &'s str)> {
        let e = self.estimate();
        sets.iter()
            .enumerate()
            .map(|(i, set)| {
                (
                    e.shown_max(
                        set.weight,
                        set.reps.saturating_add(extra),
                        // A set with an effort answer counts the reserve it
                        // said, as a rung's answer does; else the usual.
                        match self.program.calibration.answered_reserve(set.reps_left) {
                            Some(said) if set.hit => said,
                            _ if set.hit => e.reserve_when_hit,
                            _ => 0.0,
                        },
                        i + 1,
                        self.bodyweight,
                    ),
                    set.set_id.as_str(),
                )
            })
            .fold(None, |best: Option<(f32, &str)>, (shown, id)| match best {
                Some((b, _)) if b >= shown => best,
                _ => Some((shown, id)),
            })
    }

    /// What a calibration ramp found, from the rung that ended it (the
    /// reducer's `would_append`): the first rung missed with at least
    /// `too_heavy_reps` reps (a set to failure, no reserve), or else the
    /// last rung that was not too heavy, counting the reserve its answer
    /// gave (the usual reserve when unanswered). A too-heavy rung only
    /// stepped the ramp down and gives nothing — except when it is the last
    /// rung and the ramp could go no further or left nothing else: then it
    /// is read as best it can be, a set to failure with at least one rep.
    fn ramp_max<'s>(&self, rungs: &'s [SetDone]) -> Option<(f32, &'s str)> {
        let c = &self.program.calibration;
        let e = self.estimate();
        let too_heavy = |r: &SetDone| !r.hit && r.reps < c.too_heavy_reps;
        let missed = rungs.iter().find(|r| !r.hit && !too_heavy(r));
        let last = rungs.last()?;
        let last_fair = rungs.iter().rev().find(|r| !too_heavy(r));
        let (rung, reps, reserve) = match (missed, last_fair) {
            (Some(missed), _) => (missed, missed.reps, 0.0),
            (None, Some(fair)) if rungs.len() < c.max_rungs || !too_heavy(last) => (
                fair,
                fair.reps,
                c.answered_reserve(fair.reps_left)
                    .unwrap_or(e.reserve_when_hit),
            ),
            _ => (last, last.reps.max(1), 0.0),
        };
        // A rung short of its reps ran to failure: the max is no more than
        // it shows, whatever an answer on a full rung implied.
        let cap = rungs
            .iter()
            .filter(|r| !r.hit)
            .map(|r| e.shown_max(r.weight, r.reps.max(1), 0.0, 1, self.bodyweight))
            .fold(f32::INFINITY, f32::min);
        Some((
            e.shown_max(rung.weight, reps, reserve, 1, self.bodyweight)
                .min(cap),
            rung.set_id.as_str(),
        ))
    }

    fn step(&self, walk: &mut Walk, session: &SessionOutcome) {
        let ramp = if walk.max.is_none() {
            self.ramp_max(&session.rungs)
        } else {
            None
        };
        let before = walk.max.or(ramp.map(|(max, _)| max));
        let outcome = outcome(session);
        let (kind, after, set_id) = if session.excused() {
            let after = before.or(self.most_shown(&session.sets, 0).map(|(m, _)| m));
            (PlanReasonKind::Held, after, "")
        } else if session.all_hit() {
            let shown = self.most_shown(&session.sets, 1).map(|(m, _)| m);
            match (before, shown) {
                (Some(b), Some(s)) if s > b + 1e-3 => (PlanReasonKind::MaxUp, Some(s), ""),
                (Some(b), _) => (PlanReasonKind::Held, Some(b), ""),
                (None, s) => (PlanReasonKind::MaxUp, s, ""),
            }
        } else if let Some((best, id)) = self.most_shown(&session.sets, 0) {
            let after = before.map_or(best, |b| b.min(best));
            (PlanReasonKind::MaxFromMiss, Some(after), id)
        } else {
            // The ramp alone: it found the max.
            let id = ramp.map(|(_, id)| id).unwrap_or("");
            (PlanReasonKind::FirstTime, before, id)
        };
        let Some(after) = after else {
            return;
        };
        let cause = if session.excused() {
            outcome
        } else {
            PlanChangeCause::Unspecified
        };
        walk.reason = Some(PlanReason {
            kind: kind as i32,
            before: walk.max.unwrap_or(0.0),
            after,
            workout_id: session.workout_id.clone(),
            set_id: set_id.to_string(),
            at: session.at,
            cause: cause as i32,
            ..Default::default()
        });
        walk.max = Some(after);
        walk.last_weight = session.sets.iter().map(|s| s.weight).reduce(f32::max);
        walk.last_at = session.at;
        walk.from_override = false;
        walk.points.push((session.workout_id.clone(), after));
        walk.last = session
            .sets
            .iter()
            .reduce(|best, s| if s.weight > best.weight { s } else { best })
            .map(|heaviest| LastSession {
                weight: heaviest.weight,
                reps: heaviest.target,
                sets: session.planned_sets.max(session.sets.len() as i32),
                best_reps: session
                    .sets
                    .iter()
                    .filter(|s| same_weight(s.weight, heaviest.weight))
                    .map(|s| s.reps)
                    .max()
                    .unwrap_or(0),
                outcome,
                amrap_reps: session
                    .sets
                    .iter()
                    .filter(|s| s.amrap)
                    .map(|s| s.reps)
                    .max()
                    .unwrap_or(0),
                rir: {
                    let said: Vec<f32> = session
                        .sets
                        .iter()
                        .filter_map(|s| self.program.calibration.answered_reserve(s.reps_left))
                        .collect();
                    (!said.is_empty()).then(|| said.iter().sum::<f32>() / said.len() as f32)
                },
            });
    }
}

/// How a session went for its lift.
fn outcome(session: &SessionOutcome) -> PlanChangeCause {
    if session.stopped_early {
        PlanChangeCause::StoppedEarly
    } else if session.rushed {
        PlanChangeCause::Rushed
    } else if session.all_hit() {
        PlanChangeCause::Hit
    } else {
        PlanChangeCause::Missed
    }
}

/// Two weights the same, give or take a conversion's rounding.
fn same_weight(a: f32, b: f32) -> bool {
    (a - b).abs() < 0.05
}

/// Which way `weight` × `reps` moved from the last session's.
fn direction(weight: f32, reps: i32, last: &LastSession) -> PlanReasonKind {
    if same_weight(weight, last.weight) {
        match reps.cmp(&last.reps) {
            std::cmp::Ordering::Greater => PlanReasonKind::RepsUp,
            std::cmp::Ordering::Less => PlanReasonKind::RepsDown,
            std::cmp::Ordering::Equal => PlanReasonKind::SameAsLast,
        }
    } else if weight > last.weight {
        PlanReasonKind::WeightUp
    } else {
        PlanReasonKind::WeightDown
    }
}

/// The plan (`d`, with its sets) against the last session: what moved and
/// why. `kept` is what last time's number of sets would have been given:
/// when it moves another way than the plan, the sets did it. A max held
/// (stopped early, rushed) moves nothing itself: when the plan moved anyway
/// and the sets differ, the sets did it.
fn versus_last(
    d: &ExerciseDecision,
    last: &LastSession,
    kept: (f32, i32),
    days_off: Option<i64>,
) -> PlanReason {
    let kind = direction(d.weight, d.reps, last);
    let held = matches!(
        last.outcome,
        PlanChangeCause::StoppedEarly | PlanChangeCause::Rushed
    );
    let cause = if days_off.is_some() {
        PlanChangeCause::TimeOff
    } else if d.sets != last.sets
        && (direction(kept.0, kept.1, last) != kind || (held && kind != PlanReasonKind::SameAsLast))
    {
        PlanChangeCause::Sets
    } else {
        last.outcome
    };
    PlanReason {
        kind: kind as i32,
        before: last.weight,
        after: d.weight,
        cause: cause as i32,
        reps_before: last.reps,
        reps_after: d.reps,
        sets_before: last.sets,
        sets_after: d.sets,
        days_off: days_off.unwrap_or(0) as i32,
        ..Default::default()
    }
}

// ── One lift ──

/// Everything one lift's plan reads.
#[derive(Clone, Copy)]
pub struct LiftInputs<'a> {
    pub program: &'a Program,
    pub exercise: &'a str,
    pub walk: &'a Walk,
    /// Its finished sessions, oldest first.
    pub sessions: &'a [SessionOutcome],
    /// The weight a lift never done calibrates from.
    pub start: Option<f32>,
    pub over: Option<&'a Override>,
    pub now: i64,
    pub unit: AppWeightUnit,
}

/// How a run of sessions ends: in a row, to the last, with every rep hit,
/// and with a rep missed at the last session's weight. Sessions stopped
/// early or rushed, and ramps alone, neither break nor extend a run.
fn runs(sessions: &[SessionOutcome]) -> (i32, i32) {
    let judged: Vec<&SessionOutcome> = sessions
        .iter()
        .filter(|s| !s.excused() && !s.sets.is_empty())
        .collect();
    let hits = judged.iter().rev().take_while(|s| s.all_hit()).count() as i32;
    let heaviest = |s: &SessionOutcome| s.sets.iter().map(|x| x.weight).fold(0.0, f32::max);
    let last_weight = judged.last().map(|s| heaviest(s));
    let fails = judged
        .iter()
        .rev()
        .take_while(|s| !s.all_hit() && last_weight.is_some_and(|w| same_weight(heaviest(s), w)))
        .count() as i32;
    (hits, fails)
}

/// The sessions that lifted working sets: what a cycle counts its steps by.
fn working_sessions(sessions: &[SessionOutcome]) -> usize {
    sessions.iter().filter(|s| !s.sets.is_empty()).count()
}

/// The formula's variables for one lift (`program::formula::VARIABLES`).
struct LiftScope<'a> {
    inputs: &'a LiftInputs<'a>,
    vars: BTreeMap<&'static str, f64>,
}

impl<'a> LiftScope<'a> {
    fn new(inputs: &'a LiftInputs<'a>) -> Self {
        let p = inputs.program;
        let ex = inputs.exercise;
        let walk = inputs.walk;
        let class = p.class_of(ex);
        let (hits, fails) = runs(inputs.sessions);
        let last = walk.last.as_ref();
        let flag = |b: bool| if b { 1.0 } else { 0.0 };
        let days_off = if walk.last_at > 0 {
            inputs.now.saturating_sub(walk.last_at) / DAY
        } else {
            0
        };
        let vars = BTreeMap::from([
            ("last.weight", last.map_or(0.0, |l| l.weight as f64)),
            ("last.reps", last.map_or(0.0, |l| l.reps as f64)),
            ("last.sets", last.map_or(0.0, |l| l.sets as f64)),
            ("last.best_reps", last.map_or(0.0, |l| l.best_reps as f64)),
            ("last.amrap_reps", last.map_or(0.0, |l| l.amrap_reps as f64)),
            (
                "last.rir",
                last.and_then(|l| l.rir).map_or(-1.0, |r| r as f64),
            ),
            (
                "last.hit",
                flag(last.is_some_and(|l| l.outcome == PlanChangeCause::Hit)),
            ),
            (
                "last.missed",
                flag(last.is_some_and(|l| l.outcome == PlanChangeCause::Missed)),
            ),
            (
                "last.stopped_early",
                flag(last.is_some_and(|l| {
                    matches!(
                        l.outcome,
                        PlanChangeCause::StoppedEarly | PlanChangeCause::Rushed
                    )
                })),
            ),
            ("has_last", flag(last.is_some())),
            ("sessions", working_sessions(inputs.sessions) as f64),
            ("hits_in_row", hits as f64),
            ("fails_in_row", fails as f64),
            ("days_off", days_off as f64),
            ("max", walk.max.unwrap_or(0.0) as f64),
            ("start", inputs.start.unwrap_or(0.0) as f64),
            ("step", p.step_lb(ex, inputs.unit) as f64),
            ("kg", flag(inputs.unit == AppWeightUnit::Kg)),
            ("bodyweight", flag(p.is_bodyweight(ex))),
            ("rep_low", class.rep_low as f64),
            ("rep_high", class.rep_high as f64),
        ]);
        Self { inputs, vars }
    }
}

impl Scope for LiftScope<'_> {
    fn var(&self, name: &str) -> Option<f64> {
        self.vars.get(name).copied()
    }

    fn snap(&self, weight_lb: f64) -> f64 {
        let i = self.inputs;
        i.program.snap_lb(i.exercise, weight_lb as f32, i.unit) as f64
    }
}

/// What a formula gives, evaluated: weight (lb), reps, and the rest it
/// names. Its sets are counted before the budget hands out the rest
/// (`rule_sets`).
struct FormulaPlan {
    weight: f32,
    reps: i32,
    rest_seconds: Option<i32>,
}

fn evaluate_formula(f: &Formula, inputs: &LiftInputs) -> Result<FormulaPlan, String> {
    let scope = LiftScope::new(inputs);
    let evaluator = Evaluator::new(&f.lets, &scope)?;
    let whole = |src: &str, what: &str, lo: f64, hi: f64| -> Result<i32, String> {
        let v = evaluator
            .eval_src(src)
            .map_err(|e| format!("{what}: {e}"))?
            .round();
        if !(lo..=hi).contains(&v) {
            return Err(format!("{what} came to {v}, outside {lo}..={hi}"));
        }
        Ok(v as i32)
    };
    let weight = evaluator
        .eval_src(&f.weight)
        .map_err(|e| format!("weight: {e}"))?;
    if !(0.0..=2000.0).contains(&weight) {
        return Err(format!("weight came to {weight}, outside 0..=2000"));
    }
    Ok(FormulaPlan {
        weight: weight as f32,
        reps: whole(&f.reps, "reps", 1.0, 100.0)?,
        rest_seconds: f
            .rest_seconds
            .as_deref()
            .map(|s| whole(s, "rest_seconds", 0.0, 1800.0))
            .transpose()?,
    })
}

/// The working sets a lift's rule (or override) fixes, before the budget
/// hands out the rest: None leaves them to the budget.
pub fn rule_sets(inputs: &LiftInputs) -> Option<i32> {
    if let Some(sets) = inputs.over.and_then(|o| o.sets) {
        return Some(sets);
    }
    // A scheme of numbered sets only fixes them; one with a `rest` step
    // takes the rule's or the budget's, at least its numbered ones.
    if inputs.over.is_none() {
        if let Some(scheme) = inputs.program.scheme_of(inputs.exercise) {
            let (numbered, rest) = main_sets(scheme);
            if !rest {
                return Some(numbered.max(1));
            }
        }
    }
    match &*inputs.program.progression_of(inputs.exercise) {
        Progression::EstimatedMax => None,
        Progression::Fixed { sets, .. } => Some(*sets),
        Progression::Linear { sets, .. } | Progression::Double { sets, .. } => *sets,
        Progression::Cycle { steps } => {
            let step = &steps[working_sessions(inputs.sessions) % steps.len().max(1)];
            Some(step.sets)
        }
        Progression::Formula(f) => {
            let sets = f.sets.as_deref()?;
            let scope = LiftScope::new(inputs);
            let value = Evaluator::new(&f.lets, &scope).ok()?.eval_src(sets).ok()?;
            let sets = value.round();
            (1.0..=20.0).contains(&sets).then_some(sets as i32)
        }
    }
}

/// Whether a lift opens with warmups or a calibration ramp: the time its
/// sets wait for.
pub fn lead_in(inputs: &LiftInputs) -> bool {
    let p = inputs.program;
    let ex = inputs.exercise;
    p.class_of(ex).warmups || ramps(inputs)
}

/// A lift never done that finds its max with the calibration ramp.
fn ramps(inputs: &LiftInputs) -> bool {
    inputs.walk.max.is_none()
        && !inputs.program.is_bodyweight(inputs.exercise)
        && inputs.program.progression_of(inputs.exercise).ramps()
}

/// What one lift is given with `sets` sets, at `now`, by its rule.
pub fn plan_lift(inputs: &LiftInputs, sets: i32) -> ExerciseDecision {
    let LiftInputs {
        program: p,
        exercise: ex,
        walk,
        start,
        over,
        now,
        unit,
        ..
    } = *inputs;
    let class = p.class_of(ex);
    let rule_name = p.progression_name(ex);
    let rule = &*p.progression_of(ex);
    let bodyweight = p.is_bodyweight(ex);
    let (rep_low, rep_high) = match rule {
        Progression::Fixed { reps, .. } | Progression::Linear { reps, .. } => (*reps, *reps),
        Progression::Double {
            rep_low, rep_high, ..
        } => (*rep_low, *rep_high),
        _ => (class.rep_low, class.rep_high),
    };
    let mut d = ExerciseDecision {
        exercise: ex.to_string(),
        sets,
        rest_seconds: class.rest_seconds,
        warmups: class.warmups,
        rep_low,
        rep_high,
        reps: rep_low,
        progression: rule_name.to_string(),
        progression_kind: rule.kind().to_string(),
        ..Default::default()
    };
    let rule_reason = |text: &str| PlanReason {
        kind: PlanReasonKind::Rule as i32,
        rule: rule_name.to_string(),
        text: text.to_string(),
        ..Default::default()
    };
    let note = match rule {
        Progression::Formula(f) => f.note.as_str(),
        _ => "",
    };

    // A fixed rule knows its numbers, history or not.
    if let Progression::Fixed {
        reps, weight_lb, ..
    } = rule
    {
        d.reps = *reps;
        d.weight = if bodyweight {
            *weight_lb
        } else {
            p.snap_lb(ex, *weight_lb, unit)
        };
        if let Some(last) = &walk.last {
            d.reasons
                .push(versus_last(&d, last, (d.weight, d.reps), None));
        }
        d.reasons.push(rule_reason(note));
        return d;
    }

    // Never done: the ramp finds the max (a bodyweight lift starts at the
    // bottom of its range).
    let Some(max) = walk.max else {
        let start = start.filter(|w| *w > 0.0);
        if !bodyweight {
            let opener = p.opener_lb(ex, unit);
            d.weight = start
                .map(|w| {
                    p.snap_lb(ex, w * p.calibration.start_fraction, unit)
                        .max(opener)
                })
                .unwrap_or(opener);
            d.calibration = true;
        }
        d.reasons.push(PlanReason {
            kind: PlanReasonKind::FirstTime as i32,
            before: start.unwrap_or(0.0),
            after: d.weight,
            ..Default::default()
        });
        if !matches!(rule, Progression::EstimatedMax) {
            d.reasons.push(rule_reason(note));
        }
        return d;
    };

    let days = now.saturating_sub(walk.last_at) / DAY;
    let factor = p.time_off_factor(days);
    let off = (factor < 1.0).then_some(days);
    let walked = max;
    let max = walked * factor;
    d.max = max;
    let time_off = |before: f32, after: f32| PlanReason {
        kind: PlanReasonKind::TimeOff as i32,
        before,
        after,
        days_off: days as i32,
        at: walk.last_at,
        ..Default::default()
    };

    // The user's own numbers are the next session's, exactly.
    if let Some(o) = over.filter(|_| walk.from_override && factor >= 1.0) {
        d.reasons.extend(walk.reason.clone());
        d.weight = if bodyweight {
            o.weight
        } else {
            p.snap_lb(ex, o.weight, unit)
        };
        d.reps = o.reps;
        if !matches!(rule, Progression::EstimatedMax) {
            d.reasons.push(rule_reason(note));
        }
        return d;
    }

    match rule {
        Progression::EstimatedMax | Progression::Fixed { .. } => {
            estimated_max(inputs, &mut d, walked, factor, off);
        }
        Progression::Linear {
            reps,
            increment_lb,
            deload_after_fails,
            deload_factor,
            ..
        } => {
            let step = if *increment_lb > 0.0 {
                *increment_lb
            } else {
                p.step_lb(ex, unit)
            };
            d.reps = *reps;
            match (&walk.last, off) {
                (Some(last), None) => {
                    let (_, fails) = runs(inputs.sessions);
                    d.weight = match last.outcome {
                        PlanChangeCause::Hit => p.snap_lb(ex, last.weight + step, unit),
                        PlanChangeCause::Missed
                            if *deload_after_fails > 0 && fails >= *deload_after_fails =>
                        {
                            let lighter = p.snap_down_lb(ex, last.weight * deload_factor, unit);
                            d.reasons.push(PlanReason {
                                kind: PlanReasonKind::Deload as i32,
                                before: last.weight,
                                after: lighter,
                                count: fails,
                                ..Default::default()
                            });
                            lighter
                        }
                        _ => p.snap_lb(ex, last.weight, unit),
                    };
                    let comparison = versus_last(&d, last, (d.weight, d.reps), None);
                    d.reasons.insert(0, comparison);
                }
                (Some(last), Some(_)) => {
                    d.weight = p.snap_down_lb(ex, last.weight * factor, unit);
                    d.reasons.push(time_off(last.weight, d.weight));
                    let comparison = versus_last(&d, last, (d.weight, d.reps), off);
                    d.reasons.insert(0, comparison);
                }
                (None, _) => {
                    d.weight = from_max(p, ex, max, d.reps, sets, unit);
                    d.reasons.extend(walk.reason.clone());
                }
            }
            if bodyweight && *increment_lb <= 0.0 {
                d.weight = walk.last_weight.unwrap_or(0.0);
            }
            d.reasons.push(rule_reason(note));
        }
        Progression::Double {
            rep_low,
            rep_high,
            increment_lb,
            rep_step,
            ..
        } => {
            let step = if *increment_lb > 0.0 {
                *increment_lb
            } else {
                p.step_lb(ex, unit)
            };
            match (&walk.last, off) {
                (Some(last), None) => {
                    let reps = last.reps.clamp(*rep_low, *rep_high);
                    (d.weight, d.reps) = match last.outcome {
                        PlanChangeCause::Hit if reps >= *rep_high && step > 0.0 => {
                            (p.snap_lb(ex, last.weight + step, unit), *rep_low)
                        }
                        PlanChangeCause::Hit => (
                            p.snap_lb(ex, last.weight, unit),
                            (reps + (*rep_step).max(1)).min(*rep_high),
                        ),
                        _ => (p.snap_lb(ex, last.weight, unit), reps),
                    };
                    if bodyweight {
                        d.weight = last.weight;
                    }
                    let comparison = versus_last(&d, last, (d.weight, d.reps), None);
                    d.reasons.insert(0, comparison);
                }
                (Some(last), Some(_)) => {
                    d.weight = p.snap_down_lb(ex, last.weight * factor, unit);
                    d.reps = last.reps.clamp(*rep_low, *rep_high);
                    d.reasons.push(time_off(last.weight, d.weight));
                    let comparison = versus_last(&d, last, (d.weight, d.reps), off);
                    d.reasons.insert(0, comparison);
                }
                (None, _) => {
                    (d.weight, d.reps) = p.choose(ex, max, None, Shape::of(&d), unit);
                    d.reasons.extend(walk.reason.clone());
                }
            }
            d.reasons.push(rule_reason(note));
        }
        Progression::Cycle { steps } => {
            let i = working_sessions(inputs.sessions) % steps.len().max(1);
            let step = &steps[i];
            d.reps = step.reps;
            d.rep_low = step.reps;
            d.rep_high = step.reps;
            d.weight = if bodyweight {
                walk.last_weight.unwrap_or(0.0)
            } else {
                p.snap_down_lb(ex, max * step.fraction, unit)
            };
            d.reasons.extend(walk.reason.clone());
            if off.is_some() {
                d.reasons.push(time_off(walked, max));
            }
            d.reasons.push(PlanReason {
                kind: PlanReasonKind::CycleStep as i32,
                after: step.fraction,
                count: i as i32 + 1,
                of: steps.len() as i32,
                ..Default::default()
            });
            if let Some(last) = &walk.last {
                let comparison = versus_last(&d, last, (d.weight, d.reps), off);
                d.reasons.insert(0, comparison);
            }
            d.reasons.push(rule_reason(note));
        }
        Progression::Formula(f) => match evaluate_formula(f, inputs) {
            Ok(plan) => {
                d.weight = if bodyweight {
                    plan.weight
                } else {
                    p.snap_lb(ex, plan.weight, unit)
                };
                d.reps = plan.reps;
                d.rep_low = plan.reps;
                d.rep_high = plan.reps;
                if let Some(rest) = plan.rest_seconds {
                    d.rest_seconds = rest;
                }
                if let Some(last) = &walk.last {
                    let comparison = versus_last(&d, last, (d.weight, d.reps), off);
                    d.reasons.insert(0, comparison);
                }
                d.reasons.push(rule_reason(note));
            }
            Err(error) => {
                d.rep_low = class.rep_low;
                d.rep_high = class.rep_high;
                d.progression_kind = Progression::EstimatedMax.kind().to_string();
                estimated_max(inputs, &mut d, walked, factor, off);
                d.reasons.push(PlanReason {
                    kind: PlanReasonKind::Fallback as i32,
                    rule: rule_name.to_string(),
                    text: error,
                    ..Default::default()
                });
            }
        },
    }
    d
}

/// The heaviest loadable weight `max` covers for `sets` × `reps`.
fn from_max(p: &Program, ex: &str, max: f32, reps: i32, sets: i32, unit: AppWeightUnit) -> f32 {
    if p.is_bodyweight(ex) {
        return 0.0;
    }
    p.snap_down_lb(ex, p.estimate.weight_for(max, reps, sets), unit)
}

/// The estimated max rule: the walked max (cut for time away) in the
/// decision's rep range, compared with last time.
fn estimated_max(
    inputs: &LiftInputs,
    d: &mut ExerciseDecision,
    walked: f32,
    factor: f32,
    off: Option<i64>,
) {
    let LiftInputs {
        program: p,
        exercise: ex,
        walk,
        unit,
        ..
    } = *inputs;
    d.reasons.extend(walk.reason.clone());
    let max = walked * factor;
    let mut last = walk.last_weight;
    if factor < 1.0 {
        d.reasons.push(PlanReason {
            kind: PlanReasonKind::TimeOff as i32,
            before: walked,
            after: max,
            days_off: off.unwrap_or(0) as i32,
            at: walk.last_at,
            ..Default::default()
        });
        last = None;
    }
    (d.weight, d.reps) = p.choose(ex, max, last, Shape::of(d), unit);
    if let Some(previous) = &walk.last {
        let kept = p.choose(
            ex,
            max,
            last,
            Shape {
                sets: previous.sets,
                ..Shape::of(d)
            },
            unit,
        );
        d.reasons.insert(0, versus_last(d, previous, kept, off));
    }
}

// ── Sets: from the time budget ──

/// What a workout's parts take, in seconds: the user's own medians over the
/// program's learning window once there are enough of a kind, the
/// program's defaults until then.
#[derive(Clone, Debug, PartialEq)]
pub struct Costs {
    /// Lifting one set: its start to its end.
    pub set_seconds: f32,
    /// The rest after a set, per class: a set's end to the next set's start
    /// on the same lift.
    pub rest_seconds: BTreeMap<String, f32>,
    /// A lift's warmups (or a ramp): their span.
    pub warmup_seconds: f32,
    /// A lift's last set's end to the next lift's first set's start.
    pub between_seconds: f32,
}

fn median(mut samples: Vec<f32>, enough: usize) -> Option<f32> {
    if samples.len() < enough.max(1) {
        return None;
    }
    samples.sort_by(f32::total_cmp);
    let mid = samples.len() / 2;
    Some(if samples.len().is_multiple_of(2) {
        (samples[mid - 1] + samples[mid]) / 2.0
    } else {
        samples[mid]
    })
}

impl Costs {
    /// The program's defaults: its costs, each class's rest.
    pub fn defaults(program: &Program) -> Self {
        let c = &program.costs;
        Self {
            set_seconds: c.set_seconds,
            rest_seconds: program
                .classes
                .iter()
                .map(|(name, class)| (name.clone(), class.rest_seconds as f32))
                .collect(),
            warmup_seconds: c.warmup_seconds,
            between_seconds: c.between_seconds,
        }
    }

    /// Learned from the set timestamps of the workouts started in the
    /// program's learning window before `now`.
    pub fn learned(program: &Program, workouts: &[WorkoutRecord], now: i64) -> Self {
        let c = &program.costs;
        let window = c.learn_window_days * DAY;
        let mut lifting = Vec::new();
        let mut rests: BTreeMap<String, Vec<f32>> = BTreeMap::new();
        let mut warmups = Vec::new();
        let mut between = Vec::new();
        for record in workouts
            .iter()
            .filter(|r| r.workout.start_time >= now - window && r.workout.start_time <= now)
        {
            let by_id: HashMap<&str, &ProposedSet> = record
                .proposed_sets
                .iter()
                .map(|p| (p.id.as_str(), p))
                .collect();
            let mut done: Vec<(&CompletedSet, &ProposedSet)> = record
                .completed_sets
                .iter()
                .filter(|c| c.ended_at > 0)
                .filter_map(|c| by_id.get(c.proposed_set_id.as_str()).map(|p| (c, *p)))
                .collect();
            done.sort_by_key(|(c, _)| c.ended_at);
            let mut spans: Vec<(&str, i64, i64)> = Vec::new();
            let mut seen: HashSet<&str> = HashSet::new();
            let mut prev: Option<(&CompletedSet, &ProposedSet)> = None;
            for (c, p) in done {
                let working = p.is_working();
                if p.warmup {
                    let from = if c.started_at > 0 {
                        c.started_at
                    } else {
                        c.ended_at
                    };
                    match spans.iter_mut().find(|(ex, _, _)| *ex == p.exercise) {
                        Some(span) => span.2 = c.ended_at,
                        None => spans.push((&p.exercise, from, c.ended_at)),
                    }
                }
                if working && c.started_at > 0 {
                    lifting.push((c.ended_at - c.started_at) as f32);
                }
                if let Some((pc, pp)) = prev {
                    let gap = c.started_at - pc.ended_at;
                    if c.started_at > 0 && gap >= 0 {
                        if pp.exercise == p.exercise && working && pp.is_working() {
                            if let Some(e) = program.exercise(&p.exercise) {
                                rests.entry(e.class.clone()).or_default().push(gap as f32);
                            }
                        } else if pp.exercise != p.exercise && !seen.contains(p.exercise.as_str()) {
                            between.push(gap as f32);
                        }
                    }
                }
                seen.insert(&p.exercise);
                prev = Some((c, p));
            }
            warmups.extend(spans.into_iter().map(|(_, from, to)| (to - from) as f32));
        }
        // Only what was really timed counts: a set shorter than
        // `learn_min_set_seconds`, or a gap shorter than
        // `learn_min_gap_seconds`, was tapped through.
        let real = |samples: Vec<f32>, least: f32| -> Vec<f32> {
            samples.into_iter().filter(|s| *s >= least).collect()
        };
        let enough = c.learn_samples;
        let defaults = Self::defaults(program);
        let mut rest_seconds = defaults.rest_seconds;
        for (class, rest) in rest_seconds.iter_mut() {
            let samples = rests.remove(class).unwrap_or_default();
            *rest = median(real(samples, c.learn_min_gap_seconds), enough).unwrap_or(*rest);
        }
        Self {
            set_seconds: median(real(lifting, c.learn_min_set_seconds), enough)
                .unwrap_or(defaults.set_seconds),
            rest_seconds,
            warmup_seconds: median(real(warmups, c.learn_min_gap_seconds), enough)
                .unwrap_or(defaults.warmup_seconds),
            between_seconds: median(real(between, c.learn_min_gap_seconds), enough)
                .unwrap_or(defaults.between_seconds),
        }
    }

    /// The rest after one working set of a lift in `class`.
    pub fn rest(&self, class: &str) -> f32 {
        self.rest_seconds.get(class).copied().unwrap_or(0.0)
    }

    /// One more working set of a lift in `class`: lifting it and the rest
    /// after it.
    pub fn per_set(&self, class: &str) -> f32 {
        self.set_seconds + self.rest(class)
    }
}

/// One lift going into the allocation.
#[derive(Clone, Debug, PartialEq)]
pub struct Lift {
    pub exercise: String,
    /// Its class's name: what its rest costs.
    pub class: String,
    /// Sets that are not the budget's to give: an override's, a rule's, or
    /// a lift already planned in the workout.
    pub fixed_sets: Option<i32>,
    /// Warmups, or a calibration ramp, before its working sets.
    pub lead_in: bool,
    /// What its scheme adds beyond its main sets: drops and minis.
    pub extra_seconds: f32,
}

/// A scheme's numbered main sets (working, top, back-off), and whether it
/// has a `rest` step for the rule's or the budget's others.
pub fn main_sets(scheme: &Scheme) -> (i32, bool) {
    let mut numbered = 0;
    let mut rest = false;
    for step in scheme.steps.iter().filter(|s| s.role.is_main()) {
        match &step.count {
            crate::program::StepCount::Sets(n) => numbered += (*n).max(0),
            crate::program::StepCount::Word(_) => rest = true,
        }
    }
    (numbered, rest)
}

/// What a scheme's drops and minis add to a lift's time, as the budget
/// counts it: a drop a whole set, a mini half, each with its own rest.
fn scheme_extra_seconds(costs: &Costs, scheme: &Scheme) -> f32 {
    scheme
        .steps
        .iter()
        .filter(|s| !s.role.is_main())
        .map(|s| {
            let n = match &s.count {
                crate::program::StepCount::Sets(n) => (*n).max(0) as f32,
                crate::program::StepCount::Word(_) => 0.0,
            };
            let set = if s.role == Role::Mini { 0.5 } else { 1.0 };
            n * (costs.set_seconds * set + s.rest_seconds.unwrap_or(0) as f32)
        })
        .sum()
}

/// The same for a decision already laid out.
fn extra_seconds(costs: &Costs, planned: &[PlannedSet]) -> f32 {
    planned
        .iter()
        .filter(|p| matches!(SetRole::try_from(p.role), Ok(SetRole::Drop | SetRole::Mini)))
        .map(|p| {
            let set = if p.role == SetRole::Mini as i32 {
                0.5
            } else {
                1.0
            };
            costs.set_seconds * set + p.rest_seconds as f32
        })
        .sum()
}

/// A decision given its lift's shape: what its number counts, sides, a
/// tempo cue, and, when its scheme isn't straight sets (and the weight
/// wasn't set by hand, which is exactly that), its sets one by one. The
/// rule's sets are the main sets: the scheme's numbered ones, and its
/// `rest` step's share of the rest. Drops chain off the set before.
pub fn shape_lift(inputs: &LiftInputs, d: &mut ExerciseDecision) {
    let p = inputs.program;
    let ex = inputs.exercise;
    if let Some(def) = p.exercise(ex) {
        d.measure = def.measure.to_proto() as i32;
        d.per_side = def.per_side;
        d.tempo = def.tempo.clone();
    }
    let Some(scheme) = p.scheme_of(ex).filter(|_| inputs.over.is_none()) else {
        return;
    };
    d.scheme = p.scheme_name(ex).to_string();
    let (numbered, has_rest) = main_sets(scheme);
    let rest_count = if has_rest {
        (d.sets - numbered).max(0)
    } else {
        0
    };
    let mut planned = Vec::new();
    let mut last_fraction = 1.0;
    for step in &scheme.steps {
        let count = match &step.count {
            crate::program::StepCount::Sets(n) => (*n).max(0),
            crate::program::StepCount::Word(_) => rest_count,
        };
        for _ in 0..count {
            let fraction = if step.role == Role::Drop {
                last_fraction * step.fraction
            } else {
                step.fraction
            };
            last_fraction = fraction;
            planned.push(PlannedSet {
                role: step.role.to_proto() as i32,
                reps: step.reps.unwrap_or(0),
                fraction,
                amrap: step.amrap,
                rir: step.rir,
                rest_seconds: step.rest_seconds.unwrap_or(if step.role == Role::Drop {
                    0
                } else {
                    d.rest_seconds
                }),
                every_seconds: step.every_seconds.unwrap_or(0),
                on_miss: step.on_miss.as_ref().map(|m| crate::pb::OnMiss {
                    rest_seconds: m.rest_seconds.unwrap_or(0),
                    fraction: m.fraction.unwrap_or(0.0),
                    stop: m.stop,
                }),
            });
        }
    }
    // The rest after each set is for what comes next: none before a drop,
    // a mini's short pause before a mini, and after a lift's last drop or
    // mini its usual rest.
    let partial =
        |p: &PlannedSet| matches!(SetRole::try_from(p.role), Ok(SetRole::Drop | SetRole::Mini));
    for k in 0..planned.len() {
        let next = planned.get(k + 1).cloned();
        planned[k].rest_seconds = match next {
            Some(n) if n.role == SetRole::Drop as i32 => 0,
            Some(n) if n.role == SetRole::Mini as i32 => n.rest_seconds,
            _ if partial(&planned[k]) => d.rest_seconds,
            _ => planned[k].rest_seconds,
        };
    }
    let mains = planned.iter().filter(|p| !partial(p)).count() as i32;
    if mains == 0 || planned.is_empty() {
        return; // a scheme with no main set lays out nothing: straight
    }
    d.sets = mains;
    d.scheme_sets = planned;
}

/// A workout's groups put on its decisions: each group of two or more of
/// its lifts gets an id, its lifts' sets one by one (straight ones too),
/// and the rest that ends each lift's round shortened to the program's
/// `transition_seconds`, except the group's last lift, whose round ends on
/// the group's rest (or its own). Layout alternates the sets.
pub fn group_lifts(program: &Program, decisions: &mut [ExerciseDecision], groups: &[GroupDef]) {
    for (n, group) in groups.iter().enumerate() {
        let members: Vec<usize> = decisions
            .iter()
            .enumerate()
            .filter(|(_, d)| group.exercises.contains(&d.exercise) && d.group.is_empty())
            .map(|(i, _)| i)
            .collect();
        if members.len() < 2 {
            continue;
        }
        let id = format!("g{}", n + 1);
        for (m, &i) in members.iter().enumerate() {
            let d = &mut decisions[i];
            d.group = id.clone();
            if d.scheme_sets.is_empty() {
                d.scheme_sets = (0..d.sets.max(1))
                    .map(|_| PlannedSet {
                        role: SetRole::Unspecified as i32,
                        reps: 0,
                        fraction: 1.0,
                        rest_seconds: d.rest_seconds,
                        ..Default::default()
                    })
                    .collect();
            }
            let last = m + 1 == members.len();
            let round_rest = if last {
                group.rest_seconds.unwrap_or(d.rest_seconds)
            } else {
                program.transition_seconds
            };
            // A round ends at a set whose next set starts a new round (a
            // main set) or at the last set.
            let len = d.scheme_sets.len();
            for k in 0..len {
                let next_is_main = d.scheme_sets.get(k + 1).is_none_or(|next| {
                    !matches!(
                        SetRole::try_from(next.role),
                        Ok(SetRole::Drop | SetRole::Mini)
                    )
                });
                if next_is_main {
                    d.scheme_sets[k].rest_seconds = round_rest;
                }
            }
        }
    }
}

/// The seconds one lift takes with `sets`: its sets with a rest between
/// each (none after the last: the move to the next lift is its own cost),
/// its lead-in, and the move to it when it is not the first.
pub fn lift_seconds(costs: &Costs, lift: &Lift, sets: i32, first: bool) -> f32 {
    let mut seconds =
        sets as f32 * costs.per_set(&lift.class) - costs.rest(&lift.class) + lift.extra_seconds;
    if lift.lead_in {
        seconds += costs.warmup_seconds;
    }
    if !first {
        seconds += costs.between_seconds;
    }
    seconds
}

/// Each lift's sets: the program's minimum each (fixed ones as they are),
/// then one at a time, up to its maximum, to the lift whose primary muscle
/// is furthest below the weekly target counting what is given so far (ties
/// to the earlier lift), until that lift's next set would pass the budget.
/// `weekly` is the hard sets per muscle this week before the workout.
pub fn allocate(
    program: &Program,
    lifts: &[Lift],
    costs: &Costs,
    weekly: &BTreeMap<Muscle, f32>,
    budget_minutes: i32,
) -> Vec<i32> {
    let mut sets: Vec<i32> = lifts
        .iter()
        .map(|l| l.fixed_sets.unwrap_or(program.sets.min))
        .collect();
    let mut total: f32 = lifts
        .iter()
        .zip(&sets)
        .enumerate()
        .map(|(i, (lift, n))| lift_seconds(costs, lift, *n, i == 0))
        .sum();
    let budget = budget_minutes as f32 * 60.0;
    loop {
        let behind = |i: usize| {
            let Some(muscle) = program.primary_muscle(&lifts[i].exercise) else {
                return f32::NEG_INFINITY;
            };
            let mut done = weekly.get(&muscle).copied().unwrap_or(0.0);
            for (lift, n) in lifts.iter().zip(&sets) {
                if let Some((_, c)) = program.credit(&lift.exercise).find(|(m, _)| *m == muscle) {
                    done += *n as f32 * c;
                }
            }
            program.volume.target_low as f32 - done
        };
        let mut pick: Option<(usize, f32)> = None;
        for (i, lift) in lifts.iter().enumerate() {
            if lift.fixed_sets.is_some() || sets[i] >= program.sets.max {
                continue;
            }
            let deficit = behind(i);
            if pick.is_none_or(|(_, best)| deficit > best) {
                pick = Some((i, deficit));
            }
        }
        let Some((i, _)) = pick else {
            break;
        };
        let cost = costs.per_set(&lifts[i].class);
        if total + cost > budget {
            break;
        }
        sets[i] += 1;
        total += cost;
    }
    sets
}

// ── The account's lifts, planned ──

/// The account's history gathered once, to plan any number of lifts at one
/// moment under one program (the account's, or a draft's).
pub struct Planner<'a> {
    account: &'a Account,
    program: &'a Program,
    sessions: HashMap<String, Vec<SessionOutcome>>,
    weekly: BTreeMap<Muscle, f32>,
    costs: Costs,
    now: i64,
}

impl<'a> Planner<'a> {
    /// Under the account's program.
    pub fn new(account: &'a Account, now: i64) -> Self {
        Self::with_program(account, &account.program, now)
    }

    /// Under `program`, whatever the account's is.
    pub fn with_program(account: &'a Account, program: &'a Program, now: i64) -> Self {
        let mut finished: Vec<&WorkoutRecord> = account
            .workouts
            .iter()
            .filter(|r| r.workout.end_time > 0)
            .collect();
        finished.sort_by_key(|r| (workout_time(r), r.workout.start_time));
        let mut sessions: HashMap<String, Vec<SessionOutcome>> = HashMap::new();
        for record in finished {
            let mut outcomes: Vec<_> = session_outcomes(record).into_iter().collect();
            outcomes.sort_by(|(a, _), (b, _)| a.cmp(b));
            for (ex, outcome) in outcomes {
                sessions.entry(ex).or_default().push(outcome);
            }
        }
        Self {
            account,
            program,
            sessions,
            weekly: weekly_sets(program, &account.workouts, now),
            costs: Costs::learned(program, &account.workouts, now),
            now,
        }
    }

    pub fn program(&self) -> &Program {
        self.program
    }

    pub fn costs(&self) -> &Costs {
        &self.costs
    }

    fn sessions(&self, ex: &str) -> &[SessionOutcome] {
        self.sessions.get(ex).map(Vec::as_slice).unwrap_or(&[])
    }

    pub fn walk(&self, ex: &str) -> Walk {
        walk(
            self.program,
            ex,
            self.sessions(ex),
            self.account.overrides.get(ex),
        )
    }

    fn inputs<'w>(&'w self, ex: &'w str, walk: &'w Walk) -> LiftInputs<'w> {
        LiftInputs {
            program: self.program,
            exercise: ex,
            walk,
            sessions: self.sessions(ex),
            start: self.account.starting_weights.get(ex).copied(),
            over: self.account.overrides.get(ex),
            now: self.now,
            unit: self.account.unit(),
        }
    }

    /// The budget asked for, or the program's default.
    pub fn budget(&self, budget_minutes: i32) -> i32 {
        if budget_minutes > 0 {
            budget_minutes
        } else {
            self.program.sets.default_budget_minutes
        }
    }

    /// The decisions for `exercises` joining a workout whose lifts already
    /// planned are `planned` (they keep theirs), in `budget_minutes` (0 =
    /// the program's default). Exercises the program doesn't know are left
    /// out.
    pub fn workout(
        &self,
        exercises: &[String],
        planned: &[ExerciseDecision],
        budget_minutes: i32,
    ) -> Vec<ExerciseDecision> {
        let budget = self.budget(budget_minutes);
        let exercises: Vec<&String> = exercises
            .iter()
            .filter(|ex| self.program.knows(ex))
            .collect();
        let walks: Vec<Walk> = exercises.iter().map(|ex| self.walk(ex)).collect();
        let lifts = self.lifts(&exercises, &walks, planned);
        let first_new = lifts.len() - exercises.len();
        let sets = allocate(self.program, &lifts, &self.costs, &self.weekly, budget);
        exercises
            .iter()
            .zip(&walks)
            .enumerate()
            .map(|(n, (ex, walk))| {
                let i = first_new + n;
                let inputs = self.inputs(ex, walk);
                let mut d = plan_lift(&inputs, sets[i]);
                shape_lift(&inputs, &mut d);
                d.budget_minutes = budget;
                d.estimated_seconds = lift_seconds(&self.costs, &lifts[i], sets[i], i == 0) as i32;
                if lifts[i].fixed_sets.is_none() {
                    let muscle = self.program.primary_muscle(ex);
                    d.reasons.push(PlanReason {
                        kind: PlanReasonKind::SetsFromTime as i32,
                        before: self.program.sets.min as f32,
                        after: sets[i] as f32,
                        budget_minutes: budget,
                        muscle: muscle.map_or(0, |m| m.to_proto() as i32),
                        weekly_sets: muscle
                            .and_then(|m| self.weekly.get(&m).copied())
                            .unwrap_or(0.0),
                        ..Default::default()
                    });
                }
                d
            })
            .collect()
    }

    /// What goes into the allocation: the lifts already planned (their sets
    /// fixed), then `exercises` (a rule's or an override's sets fixed).
    fn lifts(
        &self,
        exercises: &[&String],
        walks: &[Walk],
        planned: &[ExerciseDecision],
    ) -> Vec<Lift> {
        let class = |ex: &str| {
            self.program
                .exercise(ex)
                .map(|e| e.class.clone())
                .unwrap_or_default()
        };
        let mut lifts: Vec<Lift> = planned
            .iter()
            .map(|d| Lift {
                exercise: d.exercise.clone(),
                class: class(&d.exercise),
                fixed_sets: Some(d.sets),
                lead_in: d.warmups || d.calibration,
                extra_seconds: extra_seconds(&self.costs, &d.scheme_sets),
            })
            .collect();
        for (ex, walk) in exercises.iter().zip(walks) {
            let inputs = self.inputs(ex, walk);
            lifts.push(Lift {
                exercise: ex.to_string(),
                class: class(ex),
                fixed_sets: rule_sets(&inputs),
                lead_in: lead_in(&inputs),
                extra_seconds: inputs
                    .program
                    .scheme_of(ex)
                    .filter(|_| inputs.over.is_none())
                    .map_or(0.0, |scheme| scheme_extra_seconds(&self.costs, scheme)),
            });
        }
        lifts
    }

    /// The longest `exercises` get as one workout: every lift whose sets
    /// are the budget's to give at the program's most, fixed sets as they
    /// are, costed as the estimate is. A budget at or past it buys nothing
    /// more.
    pub fn max_seconds(&self, exercises: &[String]) -> i32 {
        let exercises: Vec<&String> = exercises
            .iter()
            .filter(|ex| self.program.knows(ex))
            .collect();
        let walks: Vec<Walk> = exercises.iter().map(|ex| self.walk(ex)).collect();
        self.lifts(&exercises, &walks, &[])
            .iter()
            .enumerate()
            .map(|(i, lift)| {
                lift_seconds(
                    &self.costs,
                    lift,
                    lift.fixed_sets.unwrap_or(self.program.sets.max),
                    i == 0,
                ) as i32
            })
            .sum()
    }

    /// A decision as the screens show it.
    pub fn view(&self, decision: ExerciseDecision) -> ExercisePlan {
        let ex = decision.exercise.as_str();
        ExercisePlan {
            overridden: self.account.overrides.contains_key(ex),
            primary_muscle: self
                .program
                .primary_muscle(ex)
                .map_or(0, |m| m.to_proto() as i32),
            equipment: self.program.equipment_of(ex).to_proto() as i32,
            step: self.program.step_lb(ex, self.account.unit()),
            last_performed_at: self.sessions(ex).last().map(|s| s.at).unwrap_or(0),
            decision: Some(decision),
        }
    }
}

#[cfg(test)]
mod tests;
