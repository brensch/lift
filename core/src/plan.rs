//! The one rule that decides what every lift is given: its sets, reps and
//! weight, from one number per lift and the time the user has. See
//! docs/plans/planned-at-start.md.
//!
//! **The max.** Every lift has an estimated max (a rep max for bodyweight
//! lifts), worked out by walking its finished sessions in order. A set
//! shows the Epley estimate with one rep of reserve when it hit its target
//! (zero when it ran short) and half a rep of fatigue for each set before
//! it:
//!
//! ```text
//! shown max = weight × (1 + (reps + reserve + 0.5 × (set number − 1)) / 30)
//! ```
//!
//! | Session | The max after it |
//! |---|---|
//! | every working rep hit | the higher of the max before and what the session shows with one more rep on every set |
//! | a rep missed | the most any working set shows, never more than the max before |
//! | stopped early, or a miss rushed (started before the previous set's rest was up) | unchanged |
//!
//! Time away cuts it when a workout is planned (21 days ×0.9, 42 ×0.8). A
//! lift never done runs the calibration ramp, whose missed rung gives the
//! max (or its last rung, with the reserve its answer to "how many more
//! could you have done?" counts: `answered_reserve`). An override (weight and reps, maybe sets) is converted to the max
//! that prescribes it and is a new starting point.
//!
//! **Sets** come from the time budget: 2 a lift, then one at a time (up to
//! 5) to the lift whose muscles are furthest below 10 hard sets this week,
//! until the next would pass the budget. **Reps and weight** come from the
//! max (`choose`).
//!
//! **Why, against last time.** The first reason compares the plan with the
//! lift's last session — heavier, lighter, more reps, fewer, the same — and
//! says why in those terms: every rep hit, a rep missed, stopped early, a
//! rushed miss, time off, or a different number of sets (when last time's
//! sets would have kept last time's numbers, or when the max held and only
//! the sets can have moved them). The max's own steps follow it.
//!
//! Everything here is pure. A workout's start records what it decides;
//! folding the event lays the sets out from that record and never runs it.

use std::collections::{HashMap, HashSet};

use crate::account::Account;
use crate::exercise_catalog::{
    class_rules, lift_class, load_style, primary_muscle, progression_increment_lb, rules,
    snap_down_weight_lb, snap_weight_lb, starting_weight_lb, LiftClass, LoadStyle,
};
use crate::exercise_progress::{session_outcomes, SessionOutcome, SetDone};
use crate::history::{workout_time, WorkoutRecord};
use crate::pb::{
    CompletedSet, Exercise, ExerciseDecision, ExercisePlan, PlanChangeCause, PlanReason,
    PlanReasonKind, ProposedSet, RepsLeft,
};
use crate::volume::{credit, muscle_volume_7d, VOLUME_TARGET_LOW};
use crate::weight_units::AppWeightUnit;

pub const DEFAULT_BUDGET_MINUTES: i32 = 60;
/// Every lift gets this many sets before any lift gets more.
pub const MIN_SETS: i32 = 2;
pub const MAX_SETS: i32 = 5;
const DAY: i64 = 24 * 3600;
/// A ramp opens at this fraction of the lift's starting weight.
const RAMP_START_FRACTION: f32 = 0.6;
/// An override that names no sets means its weight and reps for as many
/// sets as the plan gives: its max is the one that covers them at the most.
const OVERRIDE_SETS: i32 = MAX_SETS;
/// Timings are learned from this far back, once there are this many of a
/// kind.
const LEARN_WINDOW: i64 = 28 * DAY;
const LEARN_SAMPLES: usize = 10;
/// What a set, the heavy lifts' warmups and the move between lifts cost
/// until the user's own timings are learned.
const DEFAULT_SET_SECONDS: f32 = 40.0;
const DEFAULT_WARMUP_SECONDS: f32 = 240.0;
const DEFAULT_BETWEEN_SECONDS: f32 = 120.0;

/// The weight and reps (and maybe sets) the user set by hand for a lift.
#[derive(Clone, Debug, PartialEq)]
pub struct Override {
    pub at: i64,
    pub weight: f32, // lb
    pub reps: i32,
    pub sets: Option<i32>,
}

pub fn is_bodyweight(ex: Exercise) -> bool {
    load_style(ex) == LoadStyle::Bodyweight
}

// ── The max ──

/// What one set shows (see the module docs): an estimated max, or for a
/// bodyweight lift a rep max. `reserve` is 1 for a set that hit its target
/// (a ramp rung's answer can say otherwise: `answered_reserve`).
pub fn shown_max(weight: f32, reps: i32, reserve: f32, set_number: usize, bodyweight: bool) -> f32 {
    let reps = reps as f32 + reserve + 0.5 * set_number.saturating_sub(1) as f32;
    if bodyweight {
        reps
    } else {
        weight * (1.0 + reps / 30.0)
    }
}

/// The max that `sets` × `reps` @ `weight` takes: the last set's, with one
/// rep in reserve.
pub fn max_needed(weight: f32, reps: i32, sets: i32, bodyweight: bool) -> f32 {
    shown_max(weight, reps, 1.0, sets.max(1) as usize, bodyweight)
}

/// The reps in reserve the last of `sets` sets keeps: one, and half a rep
/// more for each set before it.
fn reserve(sets: i32) -> f32 {
    1.0 + 0.5 * (sets.max(1) - 1) as f32
}

/// The weight `max` takes for `sets` × `reps`: the inverse of [max_needed].
pub(crate) fn weight_for(max: f32, reps: i32, sets: i32) -> f32 {
    max / (1.0 + (reps as f32 + reserve(sets)) / 30.0)
}

/// The reps in reserve a ramp rung's answer to "how many more could you
/// have done?" counts (`RepsLeft`): 0–1 as 0.5, 2–4 as 3, and 5+ as 8 (a
/// lot left: it should jump, and on five reps 8 in reserve puts the next
/// rung about a fifth heavier). None when unanswered or answered with a
/// specific jump (`jump_lb`): a full rung then counts the usual 1.
pub fn answered_reserve(reps_left: i32) -> Option<f32> {
    match RepsLeft::try_from(reps_left).ok()? {
        RepsLeft::ZeroToOne => Some(0.5),
        RepsLeft::TwoToFour => Some(3.0),
        RepsLeft::FivePlus => Some(8.0),
        RepsLeft::Unspecified => None,
    }
}

/// The most reps the max covers at `weight` across `sets` (may be below
/// zero when it covers none).
pub fn reps_covered(max: f32, weight: f32, sets: i32, bodyweight: bool) -> i32 {
    let reserve = reserve(sets);
    let reps = if bodyweight || weight <= 0.0 {
        max - reserve
    } else {
        (max / weight - 1.0) * 30.0 - reserve
    };
    (reps + 1e-3).floor() as i32
}

/// The weight and reps a max gives, in order:
///
/// 1. the last weight, for as many reps as the max covers there;
/// 2. past the top of the range: one step up, for as many reps as the max
///    covers there (capped at the top) — or, when the step covers less than
///    the bottom (a big jump between dumbbells), the last weight for every
///    rep the max covers, past the top, until the step fits;
/// 3. short of the bottom, or 4. no last weight: the heaviest loadable
///    weight the max covers at the bottom, for as many reps as it covers.
///
/// Bodyweight lifts keep their weight and take the reps.
pub fn choose(
    ex: Exercise,
    max: f32,
    last_weight: Option<f32>,
    sets: i32,
    rep_low: i32,
    rep_high: i32,
    unit: AppWeightUnit,
) -> (f32, i32) {
    if is_bodyweight(ex) {
        let weight = last_weight.unwrap_or(0.0);
        return (
            weight,
            reps_covered(max, weight, sets, true).clamp(rep_low, rep_high),
        );
    }
    if let Some(last) = last_weight.filter(|w| *w > 0.0) {
        let last = snap_weight_lb(ex, last, unit);
        let reps = reps_covered(max, last, sets, false);
        if reps > rep_high {
            let up = snap_weight_lb(ex, last + progression_increment_lb(ex, unit), unit);
            let up_reps = reps_covered(max, up, sets, false);
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
    let weight = snap_down_weight_lb(ex, weight_for(max, rep_low, sets), unit);
    (
        weight,
        reps_covered(max, weight, sets, false).clamp(rep_low, rep_high),
    )
}

/// The max cut for time away: 21 days or more ×0.9, 42 or more ×0.8.
pub fn time_off_factor(days: i64) -> f32 {
    if days >= 42 {
        0.8
    } else if days >= 21 {
        0.9
    } else {
        1.0
    }
}

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
    /// Hit, Missed, StoppedEarly or Rushed.
    pub outcome: PlanChangeCause,
}

/// Walk a lift's finished sessions (oldest first). The override takes its
/// place among them by time and starts the walk again from its max.
pub fn walk(ex: Exercise, sessions: &[SessionOutcome], over: Option<&Override>) -> Walk {
    let bodyweight = is_bodyweight(ex);
    let mut walk = Walk::default();
    let mut pending = over;
    for session in sessions {
        if let Some(o) = pending.filter(|o| o.at < session.at) {
            apply_override(&mut walk, o, bodyweight);
            pending = None;
        }
        if let Some(max) = walk.max {
            let days = session.started_at.saturating_sub(walk.last_at) / DAY;
            walk.max = Some(max * time_off_factor(days));
        }
        step(&mut walk, session, bodyweight);
    }
    if let Some(o) = pending {
        apply_override(&mut walk, o, bodyweight);
    }
    walk
}

fn apply_override(walk: &mut Walk, o: &Override, bodyweight: bool) {
    let after = max_needed(
        o.weight,
        o.reps,
        o.sets.unwrap_or(OVERRIDE_SETS),
        bodyweight,
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
fn most_shown(sets: &[SetDone], extra: i32, bodyweight: bool) -> Option<(f32, &str)> {
    sets.iter()
        .enumerate()
        .map(|(i, set)| {
            (
                shown_max(
                    set.weight,
                    set.reps.saturating_add(extra),
                    if set.hit { 1.0 } else { 0.0 },
                    i + 1,
                    bodyweight,
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
/// `TOO_HEAVY_REPS` reps (a set to failure, no reserve), or else the last
/// rung that was not too heavy, counting the reserve its answer gave (one
/// rep when unanswered). A too-heavy rung (fewer than `TOO_HEAVY_REPS`
/// reps) only stepped the ramp down and gives nothing — except when it
/// is the last rung and the ramp could go no further (the sixth rung) or
/// left nothing else: then it is read as best it can be, a set to failure
/// with at least one rep.
fn ramp_max(rungs: &[SetDone], bodyweight: bool) -> Option<(f32, &str)> {
    use crate::workout::{MAX_CALIBRATION_RUNGS, TOO_HEAVY_REPS};
    let too_heavy = |r: &SetDone| !r.hit && r.reps < TOO_HEAVY_REPS;
    let missed = rungs.iter().find(|r| !r.hit && !too_heavy(r));
    let last = rungs.last()?;
    let last_fair = rungs.iter().rev().find(|r| !too_heavy(r));
    let (rung, reps, reserve) = match (missed, last_fair) {
        (Some(missed), _) => (missed, missed.reps, 0.0),
        (None, Some(fair)) if rungs.len() < MAX_CALIBRATION_RUNGS || !too_heavy(last) => (
            fair,
            fair.reps,
            answered_reserve(fair.reps_left).unwrap_or(1.0),
        ),
        _ => (last, last.reps.max(1), 0.0),
    };
    // A rung short of its reps ran to failure: the max is no more than it
    // shows, whatever an answer on a full rung implied.
    let cap = rungs
        .iter()
        .filter(|r| !r.hit)
        .map(|r| shown_max(r.weight, r.reps.max(1), 0.0, 1, bodyweight))
        .fold(f32::INFINITY, f32::min);
    Some((
        shown_max(rung.weight, reps, reserve, 1, bodyweight).min(cap),
        rung.set_id.as_str(),
    ))
}

fn step(walk: &mut Walk, session: &SessionOutcome, bodyweight: bool) {
    let ramp = if walk.max.is_none() {
        ramp_max(&session.rungs, bodyweight)
    } else {
        None
    };
    let before = walk.max.or(ramp.map(|(max, _)| max));
    let outcome = if session.stopped_early {
        PlanChangeCause::StoppedEarly
    } else if session.rushed {
        PlanChangeCause::Rushed
    } else if session.all_hit() {
        PlanChangeCause::Hit
    } else {
        PlanChangeCause::Missed
    };
    let (kind, after, set_id) = if session.excused() {
        let after = before.or(most_shown(&session.sets, 0, bodyweight).map(|(m, _)| m));
        (PlanReasonKind::Held, after, "")
    } else if session.all_hit() {
        let shown = most_shown(&session.sets, 1, bodyweight).map(|(m, _)| m);
        match (before, shown) {
            (Some(b), Some(s)) if s > b + 1e-3 => (PlanReasonKind::MaxUp, Some(s), ""),
            (Some(b), _) => (PlanReasonKind::Held, Some(b), ""),
            (None, s) => (PlanReasonKind::MaxUp, s, ""),
        }
    } else if let Some((best, id)) = most_shown(&session.sets, 0, bodyweight) {
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
            outcome,
        });
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

/// What one lift is given with `sets` sets, at `now`: the class's range,
/// rest and warmups; the weight and reps from the walked max (cut for time
/// away) or, never done, a calibration ramp from `start` (60% of it, never
/// under the catalog opener) — a bodyweight lift at the bottom of its range.
pub fn plan_lift(
    ex: Exercise,
    walk: &Walk,
    start: Option<f32>,
    over: Option<&Override>,
    sets: i32,
    now: i64,
    unit: AppWeightUnit,
) -> ExerciseDecision {
    let p = rules(ex);
    let bodyweight = is_bodyweight(ex);
    let mut d = ExerciseDecision {
        exercise: ex as i32,
        sets,
        rest_seconds: p.rest_seconds,
        warmups: p.warmups,
        rep_low: p.rep_low,
        rep_high: p.rep_high,
        reps: p.rep_low,
        ..Default::default()
    };
    let Some(max) = walk.max else {
        let start = start.filter(|w| *w > 0.0);
        if !bodyweight {
            let opener = starting_weight_lb(ex, unit);
            d.weight = start
                .map(|w| snap_weight_lb(ex, w * RAMP_START_FRACTION, unit).max(opener))
                .unwrap_or(opener);
            d.calibration = true;
        }
        d.reasons.push(PlanReason {
            kind: PlanReasonKind::FirstTime as i32,
            before: start.unwrap_or(0.0),
            after: d.weight,
            ..Default::default()
        });
        return d;
    };
    d.reasons.extend(walk.reason.clone());
    let days = now.saturating_sub(walk.last_at) / DAY;
    let factor = time_off_factor(days);
    let mut max = max;
    let mut last = walk.last_weight;
    if factor < 1.0 {
        d.reasons.push(PlanReason {
            kind: PlanReasonKind::TimeOff as i32,
            before: max,
            after: max * factor,
            days_off: days as i32,
            at: walk.last_at,
            ..Default::default()
        });
        max *= factor;
        last = None;
    }
    d.max = max;
    match over.filter(|_| walk.from_override && factor >= 1.0) {
        Some(o) => {
            d.weight = if bodyweight {
                o.weight
            } else {
                snap_weight_lb(ex, o.weight, unit)
            };
            d.reps = o.reps;
        }
        None => {
            (d.weight, d.reps) = choose(ex, max, last, sets, p.rep_low, p.rep_high, unit);
            if let Some(previous) = &walk.last {
                let kept = choose(ex, max, last, previous.sets, p.rep_low, p.rep_high, unit);
                let off = (factor < 1.0).then_some(days);
                d.reasons.insert(0, versus_last(&d, previous, kept, off));
            }
        }
    }
    d
}

// ── Sets: from the time budget ──

fn class_index(class: LiftClass) -> usize {
    match class {
        LiftClass::Heavy => 0,
        LiftClass::Standard => 1,
        LiftClass::Bodyweight => 2,
    }
}

/// What a workout's parts take, in seconds: the user's own medians over the
/// last four weeks once there are ten of a kind, the defaults until then.
#[derive(Clone, Debug, PartialEq)]
pub struct Costs {
    /// Lifting one set: its start to its end.
    pub set_seconds: f32,
    /// The rest after a set, per class (heavy, standard, bodyweight): a set's
    /// end to the next set's start on the same lift.
    pub rest_seconds: [f32; 3],
    /// A heavy lift's warmups (or a ramp): their span.
    pub warmup_seconds: f32,
    /// A lift's last set's end to the next lift's first set's start.
    pub between_seconds: f32,
}

impl Default for Costs {
    fn default() -> Self {
        let rest = |class| class_rules(class).rest_seconds as f32;
        Self {
            set_seconds: DEFAULT_SET_SECONDS,
            rest_seconds: [
                rest(LiftClass::Heavy),
                rest(LiftClass::Standard),
                rest(LiftClass::Bodyweight),
            ],
            warmup_seconds: DEFAULT_WARMUP_SECONDS,
            between_seconds: DEFAULT_BETWEEN_SECONDS,
        }
    }
}

fn median(mut samples: Vec<f32>) -> Option<f32> {
    if samples.len() < LEARN_SAMPLES {
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
    /// Learned from the set timestamps of the workouts started in the last
    /// four weeks before `now`.
    pub fn learned(workouts: &[WorkoutRecord], now: i64) -> Self {
        let mut lifting = Vec::new();
        let mut rests: [Vec<f32>; 3] = Default::default();
        let mut warmups = Vec::new();
        let mut between = Vec::new();
        for record in workouts
            .iter()
            .filter(|r| r.workout.start_time >= now - LEARN_WINDOW && r.workout.start_time <= now)
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
            let mut spans: Vec<(i32, i64, i64)> = Vec::new();
            let mut seen: HashSet<i32> = HashSet::new();
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
                        None => spans.push((p.exercise, from, c.ended_at)),
                    }
                }
                if working && c.started_at > 0 {
                    lifting.push((c.ended_at - c.started_at) as f32);
                }
                if let Some((pc, pp)) = prev {
                    let gap = c.started_at - pc.ended_at;
                    if c.started_at > 0 && gap >= 0 {
                        if pp.exercise == p.exercise && working && pp.is_working() {
                            if let Ok(ex) = Exercise::try_from(p.exercise) {
                                rests[class_index(lift_class(ex))].push(gap as f32);
                            }
                        } else if pp.exercise != p.exercise && !seen.contains(&p.exercise) {
                            between.push(gap as f32);
                        }
                    }
                }
                seen.insert(p.exercise);
                prev = Some((c, p));
            }
            warmups.extend(spans.into_iter().map(|(_, from, to)| (to - from) as f32));
        }
        let defaults = Self::default();
        let mut rest_seconds = defaults.rest_seconds;
        for (rest, samples) in rest_seconds.iter_mut().zip(rests) {
            *rest = median(samples).unwrap_or(*rest);
        }
        Self {
            set_seconds: median(lifting).unwrap_or(defaults.set_seconds),
            rest_seconds,
            warmup_seconds: median(warmups).unwrap_or(defaults.warmup_seconds),
            between_seconds: median(between).unwrap_or(defaults.between_seconds),
        }
    }

    /// One more working set of `ex`: lifting it and the rest after it.
    pub fn per_set(&self, ex: Exercise) -> f32 {
        self.set_seconds + self.rest_seconds[class_index(lift_class(ex))]
    }
}

/// One lift going into the allocation.
#[derive(Clone, Debug, PartialEq)]
pub struct Lift {
    pub exercise: Exercise,
    /// Sets that are not the budget's to give: an override's, or a lift
    /// already planned in the workout.
    pub fixed_sets: Option<i32>,
    /// Warmups, or a calibration ramp, before its working sets.
    pub lead_in: bool,
}

/// The seconds one lift takes with `sets`: its sets with a rest between
/// each (none after the last: the move to the next lift is its own cost),
/// its lead-in, and the move to it when it is not the first.
pub fn lift_seconds(costs: &Costs, lift: &Lift, sets: i32, first: bool) -> f32 {
    let mut seconds = sets as f32 * costs.per_set(lift.exercise)
        - costs.rest_seconds[class_index(lift_class(lift.exercise))];
    if lift.lead_in {
        seconds += costs.warmup_seconds;
    }
    if !first {
        seconds += costs.between_seconds;
    }
    seconds
}

/// Each lift's sets: 2 each (fixed ones as they are), then one at a time,
/// up to 5, to the lift whose primary muscle is furthest below 10 hard sets
/// this week counting what is given so far (ties to the earlier lift),
/// until that lift's next set would pass the budget. `weekly` is the hard
/// sets per muscle (as i32) this week before the workout.
pub fn allocate(
    lifts: &[Lift],
    costs: &Costs,
    weekly: &HashMap<i32, f32>,
    budget_minutes: i32,
) -> Vec<i32> {
    let mut sets: Vec<i32> = lifts
        .iter()
        .map(|l| l.fixed_sets.unwrap_or(MIN_SETS))
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
            let muscle = primary_muscle(lifts[i].exercise);
            let mut done = weekly.get(&(muscle as i32)).copied().unwrap_or(0.0);
            for (lift, n) in lifts.iter().zip(&sets) {
                if let Some((_, c)) = credit(lift.exercise).find(|(m, _)| *m == muscle) {
                    done += *n as f32 * c;
                }
            }
            VOLUME_TARGET_LOW as f32 - done
        };
        let mut pick: Option<(usize, f32)> = None;
        for (i, lift) in lifts.iter().enumerate() {
            if lift.fixed_sets.is_some() || sets[i] >= MAX_SETS {
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
        let cost = costs.per_set(lifts[i].exercise);
        if total + cost > budget {
            break;
        }
        sets[i] += 1;
        total += cost;
    }
    sets
}

// ── The account's lifts, planned ──

/// The account's history gathered once, to plan any number of lifts at
/// one moment.
pub struct Planner<'a> {
    account: &'a Account,
    sessions: HashMap<i32, Vec<SessionOutcome>>,
    weekly: HashMap<i32, f32>,
    costs: Costs,
    now: i64,
}

impl<'a> Planner<'a> {
    pub fn new(account: &'a Account, now: i64) -> Self {
        let mut finished: Vec<&WorkoutRecord> = account
            .workouts
            .iter()
            .filter(|r| r.workout.end_time > 0)
            .collect();
        finished.sort_by_key(|r| (workout_time(r), r.workout.start_time));
        let mut sessions: HashMap<i32, Vec<SessionOutcome>> = HashMap::new();
        for record in finished {
            let mut outcomes: Vec<_> = session_outcomes(record).into_iter().collect();
            outcomes.sort_by_key(|(ex, _)| *ex);
            for (ex, outcome) in outcomes {
                sessions.entry(ex).or_default().push(outcome);
            }
        }
        let weekly = muscle_volume_7d(&account.workouts, now)
            .into_iter()
            .map(|v| (v.muscle, v.completed_sets_7d))
            .collect();
        Self {
            account,
            sessions,
            weekly,
            costs: Costs::learned(&account.workouts, now),
            now,
        }
    }

    pub fn costs(&self) -> &Costs {
        &self.costs
    }

    pub fn walk(&self, ex: Exercise) -> Walk {
        walk(
            ex,
            self.sessions
                .get(&(ex as i32))
                .map(Vec::as_slice)
                .unwrap_or(&[]),
            self.account.overrides.get(&(ex as i32)),
        )
    }

    /// The decisions for `exercises` joining a workout whose lifts already
    /// planned are `planned` (they keep theirs), in `budget_minutes` (0 =
    /// the default).
    pub fn workout(
        &self,
        exercises: &[Exercise],
        planned: &[ExerciseDecision],
        budget_minutes: i32,
    ) -> Vec<ExerciseDecision> {
        let budget = if budget_minutes > 0 {
            budget_minutes
        } else {
            DEFAULT_BUDGET_MINUTES
        };
        let walks: Vec<Walk> = exercises.iter().map(|ex| self.walk(*ex)).collect();
        let lifts = self.lifts(exercises, &walks, planned);
        let first_new = lifts.len() - exercises.len();
        let sets = allocate(&lifts, &self.costs, &self.weekly, budget);
        exercises
            .iter()
            .zip(&walks)
            .enumerate()
            .map(|(n, (ex, walk))| {
                let i = first_new + n;
                let value = *ex as i32;
                let over = self.account.overrides.get(&value);
                let mut d = plan_lift(
                    *ex,
                    walk,
                    self.account.starting_weights.get(&value).copied(),
                    over,
                    sets[i],
                    self.now,
                    self.account.unit(),
                );
                d.budget_minutes = budget;
                d.estimated_seconds = lift_seconds(&self.costs, &lifts[i], sets[i], i == 0) as i32;
                if lifts[i].fixed_sets.is_none() {
                    let muscle = primary_muscle(*ex);
                    d.reasons.push(PlanReason {
                        kind: PlanReasonKind::SetsFromTime as i32,
                        before: MIN_SETS as f32,
                        after: sets[i] as f32,
                        budget_minutes: budget,
                        muscle: muscle as i32,
                        weekly_sets: self.weekly.get(&(muscle as i32)).copied().unwrap_or(0.0),
                        ..Default::default()
                    });
                }
                d
            })
            .collect()
    }

    /// What goes into the allocation: the lifts already planned (their sets
    /// fixed), then `exercises` (an override's sets fixed).
    fn lifts(
        &self,
        exercises: &[Exercise],
        walks: &[Walk],
        planned: &[ExerciseDecision],
    ) -> Vec<Lift> {
        let mut lifts: Vec<Lift> = planned
            .iter()
            .filter_map(|d| {
                Some(Lift {
                    exercise: Exercise::try_from(d.exercise).ok()?,
                    fixed_sets: Some(d.sets),
                    lead_in: d.warmups || d.calibration,
                })
            })
            .collect();
        for (ex, walk) in exercises.iter().zip(walks) {
            let over = self.account.overrides.get(&(*ex as i32));
            lifts.push(Lift {
                exercise: *ex,
                fixed_sets: over.and_then(|o| o.sets),
                lead_in: rules(*ex).warmups || (walk.max.is_none() && !is_bodyweight(*ex)),
            });
        }
        lifts
    }

    /// The longest `exercises` get as one workout: every lift whose sets
    /// are the budget's to give at `MAX_SETS`, fixed sets as they are,
    /// costed as the estimate is. A budget at or past it buys nothing more.
    pub fn max_seconds(&self, exercises: &[Exercise]) -> i32 {
        let walks: Vec<Walk> = exercises.iter().map(|ex| self.walk(*ex)).collect();
        self.lifts(exercises, &walks, &[])
            .iter()
            .enumerate()
            .map(|(i, lift)| {
                lift_seconds(
                    &self.costs,
                    lift,
                    lift.fixed_sets.unwrap_or(MAX_SETS),
                    i == 0,
                ) as i32
            })
            .sum()
    }

    /// A decision as the screens show it.
    pub fn view(&self, decision: ExerciseDecision) -> ExercisePlan {
        let ex = Exercise::try_from(decision.exercise).unwrap_or(Exercise::Unspecified);
        ExercisePlan {
            overridden: self.account.overrides.contains_key(&decision.exercise),
            primary_muscle: primary_muscle(ex) as i32,
            equipment: load_style(ex).to_proto() as i32,
            step: progression_increment_lb(ex, self.account.unit()),
            last_performed_at: self
                .sessions
                .get(&decision.exercise)
                .and_then(|s| s.last())
                .map(|s| s.at)
                .unwrap_or(0),
            decision: Some(decision),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const LB: AppWeightUnit = AppWeightUnit::Lb;

    /// A set of `reps` at `weight`; a miss was planned for a rep more.
    fn set(weight: f32, reps: i32, hit: bool) -> SetDone {
        SetDone {
            set_id: format!("{weight}x{reps}"),
            weight,
            reps,
            target: if hit { reps } else { reps + 1 },
            hit,
            reps_left: 0,
        }
    }

    /// A session at `at` (days) of `sets` working sets.
    fn session(id: &str, day: i64, sets: Vec<SetDone>) -> SessionOutcome {
        SessionOutcome {
            workout_id: id.to_string(),
            started_at: day * DAY - 3600,
            at: day * DAY,
            planned_sets: sets.len() as i32,
            sets,
            rungs: Vec::new(),
            stopped_early: false,
            rushed: false,
        }
    }

    fn three(weight: f32, reps: i32) -> Vec<SetDone> {
        vec![set(weight, reps, true); 3]
    }

    fn kinds(d: &ExerciseDecision) -> Vec<PlanReasonKind> {
        d.reasons
            .iter()
            .map(|r| PlanReasonKind::try_from(r.kind).unwrap())
            .collect()
    }

    fn close(a: f32, b: f32) -> bool {
        (a - b).abs() < 1e-3
    }

    #[test]
    fn a_set_shows_epley_with_reserve_and_fatigue() {
        // 100 × (1 + (5 + 1 + 0.5 × 2) / 30)
        assert!(close(
            shown_max(100.0, 5, 1.0, 3, false),
            100.0 * (1.0 + 7.0 / 30.0)
        ));
        assert!(close(
            shown_max(100.0, 5, 0.0, 1, false),
            100.0 * (1.0 + 5.0 / 30.0)
        ));
        assert!(close(shown_max(0.0, 10, 1.0, 2, true), 11.5));
        // What a plan needs is what covers it, exactly.
        let max = max_needed(200.0, 6, 3, false);
        assert_eq!(reps_covered(max, 200.0, 3, false), 6);
    }

    /// Every rep hit: one rep's worth up at the weight lifted, so the plan
    /// at that weight is a rep more.
    #[test]
    fn a_hit_nudges_the_max_a_rep_up() {
        let w = walk(Exercise::Squat, &[session("w1", 1, three(200.0, 6))], None);
        let reason = w.reason.clone().unwrap();
        assert_eq!(reason.kind, PlanReasonKind::MaxUp as i32);
        assert_eq!(reason.workout_id, "w1");
        assert!(close(w.max.unwrap(), shown_max(200.0, 7, 1.0, 3, false)));
        let d = plan_lift(Exercise::Squat, &w, None, None, 3, 2 * DAY, LB);
        assert_eq!((d.weight, d.reps), (200.0, 7), "rule 1: a rep more");
        assert_eq!(
            kinds(&d),
            vec![PlanReasonKind::RepsUp, PlanReasonKind::MaxUp]
        );
    }

    /// Past the top of the range: one step up, as many reps as covered.
    #[test]
    fn past_the_top_it_steps_up() {
        let w = walk(Exercise::Squat, &[session("w1", 1, three(200.0, 8))], None);
        let d = plan_lift(Exercise::Squat, &w, None, None, 3, 2 * DAY, LB);
        assert_eq!(d.weight, 205.0);
        assert!((5..=8).contains(&d.reps), "{}", d.reps);
    }

    /// A miss sets the max to the most any set showed, never higher.
    #[test]
    fn a_miss_resets_the_max_to_what_the_sets_showed() {
        let sessions = [
            session("w1", 1, three(200.0, 6)),
            session(
                "w2",
                3,
                vec![
                    set(205.0, 6, true),
                    set(205.0, 5, false),
                    set(205.0, 3, false),
                ],
            ),
        ];
        let w = walk(Exercise::Squat, &sessions, None);
        let reason = w.reason.clone().unwrap();
        assert_eq!(reason.kind, PlanReasonKind::MaxFromMiss as i32);
        assert_eq!(reason.set_id, "205x6", "the set that showed it");
        assert!(close(w.max.unwrap(), shown_max(205.0, 6, 1.0, 1, false)));
        assert!(w.max.unwrap() <= reason.before);
        let d = plan_lift(Exercise::Squat, &w, None, None, 3, 4 * DAY, LB);
        assert!(d.max < reason.before);
        assert!(d.weight <= 205.0);

        // A miss that shows more than the max before keeps the max before.
        let sessions = [
            session("w1", 1, three(100.0, 5)),
            session("w2", 2, vec![set(150.0, 8, true), set(150.0, 4, false)]),
        ];
        let w = walk(Exercise::Squat, &sessions, None);
        assert!(close(w.max.unwrap(), shown_max(100.0, 6, 1.0, 3, false)));
    }

    /// The user lowered the weight and hit everything: the max stays.
    #[test]
    fn a_lowered_weight_holds_the_max() {
        let sessions = [
            session("w1", 1, three(200.0, 6)),
            session("w2", 3, three(150.0, 6)),
        ];
        let w = walk(Exercise::Squat, &sessions, None);
        let first = walk(Exercise::Squat, &sessions[..1], None).max.unwrap();
        assert_eq!(w.reason.clone().unwrap().kind, PlanReasonKind::Held as i32);
        assert!(close(w.max.unwrap(), first));
        assert_eq!(
            w.last_weight,
            Some(150.0),
            "rule 1 stays at the lowered weight"
        );
    }

    #[test]
    fn stopping_early_holds_the_max() {
        let mut stopped = session("w2", 3, vec![set(200.0, 2, false)]);
        stopped.stopped_early = true;
        let sessions = [session("w1", 1, three(200.0, 6)), stopped];
        let w = walk(Exercise::Squat, &sessions, None);
        let reason = w.reason.clone().unwrap();
        assert_eq!(reason.kind, PlanReasonKind::Held as i32);
        assert_eq!(reason.cause, PlanChangeCause::StoppedEarly as i32);
        assert!(close(
            w.max.unwrap(),
            walk(Exercise::Squat, &sessions[..1], None).max.unwrap()
        ));
    }

    /// A rushed miss is excused: the max holds, and the reason says it was
    /// rushed, not stopped early.
    #[test]
    fn a_rushed_miss_holds_the_max() {
        let first = walk(Exercise::Squat, &[session("w1", 1, three(200.0, 6))], None);
        let planned = plan_lift(Exercise::Squat, &first, None, None, 3, 2 * DAY, LB);
        let done = set(planned.weight, planned.reps, true);
        let mut rushed = session("w2", 3, vec![done.clone(), done]);
        rushed.planned_sets = 3;
        rushed.rushed = true;
        let sessions = [session("w1", 1, three(200.0, 6)), rushed];
        let w = walk(Exercise::Squat, &sessions, None);
        let reason = w.reason.clone().unwrap();
        assert_eq!(reason.kind, PlanReasonKind::Held as i32);
        assert_eq!(reason.cause, PlanChangeCause::Rushed as i32);
        assert!(close(
            w.max.unwrap(),
            walk(Exercise::Squat, &sessions[..1], None).max.unwrap()
        ));
        let d = plan_lift(Exercise::Squat, &w, None, None, 3, 4 * DAY, LB);
        assert_eq!(
            versus(&d),
            (PlanReasonKind::SameAsLast, PlanChangeCause::Rushed)
        );
    }

    /// The phone's case, in kg: an override of 110 × 5, a session of four
    /// sets at it whose fourth missed two reps before the third's rest was
    /// up, then five sets today. The max holds, and an override naming no
    /// sets covers five: the same 110 × 5 again, and why.
    #[test]
    fn a_rushed_miss_holds_the_override_for_more_sets() {
        use crate::pb::Workout;
        use crate::weight_units::kg_to_pounds;
        const KG: AppWeightUnit = AppWeightUnit::Kg;
        let ex = Exercise::Squat;
        let lb = kg_to_pounds(110.0);
        let over = Override {
            at: DAY,
            weight: lb,
            reps: 5,
            sets: None,
        };
        let mut record = WorkoutRecord::new(
            Workout {
                id: "w1".into(),
                start_time: 2 * DAY,
                end_time: 2 * DAY + 1800,
                ..Default::default()
            },
            Vec::new(),
            Vec::new(),
        );
        for (i, reps) in [5, 5, 5, 3].into_iter().enumerate() {
            let id = format!("s{i}");
            let ended = 2 * DAY + 300 * (i as i64 + 1);
            record.proposed_sets.push(ProposedSet {
                id: id.clone(),
                exercise: ex as i32,
                target_weight: lb,
                target_reps: 5,
                ..Default::default()
            });
            record.completed_sets.push(CompletedSet {
                proposed_set_id: id,
                actual_weight: lb,
                actual_reps: reps,
                started_at: ended - 40,
                ended_at: ended,
                // The third's rest runs past the fourth's end.
                rest_until: ended + if i == 2 { 400 } else { 180 },
                ..Default::default()
            });
        }
        let outcome = session_outcomes(&record)[&(ex as i32)].clone();
        assert!(outcome.rushed && !outcome.stopped_early);
        assert_eq!((outcome.sets.len(), outcome.planned_sets), (3, 4));

        let held = walk(ex, &[], Some(&over)).max.unwrap();
        let w = walk(ex, &[outcome], Some(&over));
        assert!(close(w.max.unwrap(), held), "the rushed miss is excused");
        let held_reason = w.reason.clone().unwrap();
        assert_eq!(held_reason.kind, PlanReasonKind::Held as i32);
        assert_eq!(held_reason.cause, PlanChangeCause::Rushed as i32);

        let d = plan_lift(ex, &w, None, Some(&over), 5, 3 * DAY, KG);
        assert_eq!((d.sets, d.reps), (5, 5));
        // 110 × 5 with no sets named holds for as many as the plan gives.
        assert!(close(d.weight, lb), "{}", d.weight);
        assert_eq!(
            versus(&d),
            (PlanReasonKind::SameAsLast, PlanChangeCause::Rushed)
        );
        assert_eq!(kinds(&d)[1], PlanReasonKind::Held);
    }

    /// Time off after a hit: the hit nudges the max up, then the time away
    /// cuts it, and both are reasons, in that order.
    #[test]
    fn time_off_after_a_hit() {
        let w = walk(Exercise::Squat, &[session("w1", 1, three(200.0, 6))], None);
        let d = plan_lift(Exercise::Squat, &w, None, None, 3, 31 * DAY, LB);
        assert_eq!(
            kinds(&d),
            vec![
                PlanReasonKind::WeightDown,
                PlanReasonKind::MaxUp,
                PlanReasonKind::TimeOff
            ]
        );
        assert_eq!(d.reasons[0].cause, PlanChangeCause::TimeOff as i32);
        assert_eq!(d.reasons[0].days_off, 30);
        let off = &d.reasons[2];
        assert_eq!(off.days_off, 30);
        assert!(close(off.after, off.before * 0.9));
        assert!(close(d.max, off.after));
        assert!(
            d.weight < 200.0,
            "no last weight: the heaviest covered at 5"
        );
        assert_eq!(
            plan_lift(Exercise::Squat, &w, None, None, 3, 50 * DAY, LB).reasons[2].after,
            w.max.unwrap() * 0.8
        );
        // The walk applies the cut the next session was planned with.
        let back = walk(
            Exercise::Squat,
            &[
                session("w1", 1, three(200.0, 6)),
                session("w2", 31, three(d.weight, d.reps)),
            ],
            None,
        );
        assert!(back.max.unwrap() < w.max.unwrap());
    }

    /// The plan against last time, with the weight that moved and why.
    fn versus(d: &ExerciseDecision) -> (PlanReasonKind, PlanChangeCause) {
        let r = &d.reasons[0];
        (
            PlanReasonKind::try_from(r.kind).unwrap(),
            PlanChangeCause::try_from(r.cause).unwrap(),
        )
    }

    /// Reps missed and the max covers less than the bottom at last time's
    /// weight: lighter, because of the miss.
    #[test]
    fn a_miss_brings_the_weight_down() {
        let missed = vec![set(200.0, 4, false); 3];
        let w = walk(Exercise::Squat, &[session("w1", 1, missed)], None);
        let d = plan_lift(Exercise::Squat, &w, None, None, 3, 2 * DAY, LB);
        assert_eq!(d.weight, 185.0);
        assert_eq!(
            versus(&d),
            (PlanReasonKind::WeightDown, PlanChangeCause::Missed)
        );
        let r = &d.reasons[0];
        assert_eq!((r.before, r.after), (200.0, 185.0));
        assert_eq!((r.reps_before, r.reps_after), (5, d.reps));
        assert_eq!(kinds(&d)[1], PlanReasonKind::MaxFromMiss);
    }

    /// Every rep hit, but more sets than last time take more than the max
    /// covers at that weight: lighter, because of the sets. With last
    /// time's sets it would have been a rep more.
    #[test]
    fn more_sets_bring_the_weight_down() {
        let w = walk(
            Exercise::Squat,
            &[session("w1", 1, three(200.0, 5)[..2].to_vec())],
            None,
        );
        let two = plan_lift(Exercise::Squat, &w, None, None, 2, 2 * DAY, LB);
        assert_eq!((two.weight, two.reps), (200.0, 6));
        assert_eq!(versus(&two), (PlanReasonKind::RepsUp, PlanChangeCause::Hit));
        let five = plan_lift(Exercise::Squat, &w, None, None, 5, 2 * DAY, LB);
        assert!(five.weight < 200.0, "{}", five.weight);
        assert_eq!(
            versus(&five),
            (PlanReasonKind::WeightDown, PlanChangeCause::Sets)
        );
        let r = &five.reasons[0];
        assert_eq!((r.sets_before, r.sets_after), (2, 5));
        // Never "held" beside a weight that moved: the max step after it
        // is the hit's.
        assert_eq!(kinds(&five)[1], PlanReasonKind::MaxUp);
    }

    /// Every rep hit: a rep more at the same weight, or past the top a
    /// step up.
    #[test]
    fn a_hit_brings_more_reps_or_more_weight() {
        let w = walk(Exercise::Squat, &[session("w1", 1, three(200.0, 6))], None);
        let d = plan_lift(Exercise::Squat, &w, None, None, 3, 2 * DAY, LB);
        assert_eq!(versus(&d), (PlanReasonKind::RepsUp, PlanChangeCause::Hit));
        assert_eq!((d.reasons[0].reps_before, d.reasons[0].reps_after), (6, 7));
        let w = walk(Exercise::Squat, &[session("w1", 1, three(200.0, 8))], None);
        let d = plan_lift(Exercise::Squat, &w, None, None, 3, 2 * DAY, LB);
        assert_eq!(versus(&d), (PlanReasonKind::WeightUp, PlanChangeCause::Hit));
        assert_eq!((d.reasons[0].before, d.reasons[0].after), (200.0, 205.0));
    }

    /// Stopped early: the max held and so do the numbers.
    #[test]
    fn stopped_early_keeps_last_times_numbers() {
        let mut first = session("w1", 1, three(200.0, 6));
        first.sets[2].hit = false;
        first.sets[2].reps = 5;
        first.sets[2].target = 6;
        let w1 = walk(Exercise::Squat, &[first.clone()], None);
        let planned = plan_lift(Exercise::Squat, &w1, None, None, 3, 2 * DAY, LB);
        let mut stopped = session(
            "w2",
            3,
            vec![SetDone {
                target: planned.reps,
                ..set(planned.weight, planned.reps, true)
            }],
        );
        stopped.planned_sets = 3;
        stopped.stopped_early = true;
        let w = walk(Exercise::Squat, &[first, stopped], None);
        // More sets today, the max held: the sets moved the weight.
        let more = plan_lift(Exercise::Squat, &w, None, None, 5, 4 * DAY, LB);
        if more.weight != planned.weight || more.reps != planned.reps {
            assert_eq!(versus(&more).1, PlanChangeCause::Sets);
        }
        let d = plan_lift(Exercise::Squat, &w, None, None, 3, 4 * DAY, LB);
        assert_eq!((d.weight, d.reps), (planned.weight, planned.reps));
        assert_eq!(
            versus(&d),
            (PlanReasonKind::SameAsLast, PlanChangeCause::StoppedEarly)
        );
        assert_eq!(kinds(&d)[1], PlanReasonKind::Held);
    }

    /// No comparison after an override or a lift never done.
    #[test]
    fn nothing_to_compare_with() {
        let d = plan_lift(Exercise::Squat, &Walk::default(), None, None, 3, 0, LB);
        assert_eq!(kinds(&d), vec![PlanReasonKind::FirstTime]);
    }

    /// A lift never done: a ramp from 60% of its starting weight, never under
    /// the empty bar; a bodyweight lift at the bottom of its range.
    #[test]
    fn first_time() {
        let none = Walk::default();
        let d = plan_lift(Exercise::Squat, &none, Some(180.0), None, 3, 0, LB);
        assert!(d.calibration);
        assert_eq!(d.weight, 110.0, "60% of 180, loadable");
        assert_eq!(kinds(&d), vec![PlanReasonKind::FirstTime]);
        assert_eq!(d.reasons[0].before, 180.0);
        assert_eq!(
            plan_lift(Exercise::Squat, &none, None, None, 3, 0, LB).weight,
            45.0
        );
        let pull = plan_lift(Exercise::PullUp, &none, None, None, 3, 0, LB);
        assert!(!pull.calibration);
        assert_eq!((pull.weight, pull.reps), (0.0, 5));
    }

    /// The ramp's missed rung gives the max; the working sets after it were
    /// judged from there.
    #[test]
    fn the_missed_rung_gives_the_max() {
        let mut ramp = session("w1", 1, Vec::new());
        ramp.rungs = vec![set(45.0, 5, true), set(50.0, 5, true), set(55.0, 3, false)];
        let w = walk(Exercise::Squat, &[ramp], None);
        assert_eq!(
            w.reason.clone().unwrap().kind,
            PlanReasonKind::FirstTime as i32
        );
        assert!(close(w.max.unwrap(), shown_max(55.0, 3, 0.0, 1, false)));
        assert_eq!(w.last_weight, None);
    }

    /// A ramp whose last rung was answered: its max counts the answer's
    /// reserve; unanswered, one rep; a later miss still wins.
    #[test]
    fn an_answered_rung_gives_the_max_with_its_reserve() {
        let answered = |reps_left: RepsLeft| SetDone {
            reps_left: reps_left as i32,
            ..set(55.0, 5, true)
        };
        for (reps_left, reserve) in [
            (RepsLeft::Unspecified, 1.0),
            (RepsLeft::ZeroToOne, 0.5),
            (RepsLeft::TwoToFour, 3.0),
            (RepsLeft::FivePlus, 8.0),
        ] {
            let mut ramp = session("w1", 1, Vec::new());
            ramp.rungs = vec![set(45.0, 5, true), answered(reps_left)];
            let w = walk(Exercise::Squat, &[ramp], None);
            assert!(
                close(w.max.unwrap(), shown_max(55.0, 5, reserve, 1, false)),
                "{reps_left:?}"
            );
        }
        let mut ramp = session("w1", 1, Vec::new());
        ramp.rungs = vec![answered(RepsLeft::FivePlus), set(65.0, 3, false)];
        let w = walk(Exercise::Squat, &[ramp], None);
        assert!(close(w.max.unwrap(), shown_max(65.0, 3, 0.0, 1, false)));
    }

    /// A too-heavy rung (under three reps) only stepped the ramp down: the
    /// max is the rung that ended it — a 3–4 miss after it, or the last
    /// fair rung — never the heavy one. At the sixth rung, too heavy, it
    /// is read as a set to failure of at least one rep.
    #[test]
    fn the_walk_ignores_too_heavy_rungs() {
        let max_of = |rungs: Vec<SetDone>| {
            let mut ramp = session("w1", 1, Vec::new());
            ramp.rungs = rungs;
            walk(Exercise::Squat, &[ramp], None).max.unwrap()
        };
        let m = max_of(vec![set(200.0, 0, false), set(160.0, 4, false)]);
        assert!(close(m, shown_max(160.0, 4, 0.0, 1, false)), "{m}");
        let m = max_of(vec![
            set(200.0, 2, false),
            set(160.0, 5, true),
            set(175.0, 1, false),
        ]);
        // 160 × 5 says 192, but 175 × 1 ran to failure: no more than 181.
        assert!(close(m, shown_max(175.0, 1, 0.0, 1, false)), "{m}");
        let m = max_of(vec![set(200.0, 1, false), set(160.0, 5, true)]);
        assert!(close(m, shown_max(160.0, 5, 1.0, 1, false)), "{m}");
        let m = max_of(vec![set(45.0, 0, false)]);
        assert!(
            close(m, shown_max(45.0, 1, 0.0, 1, false)),
            "nothing else: {m}"
        );
        let six: Vec<SetDone> = [100.0, 110.0, 120.0, 130.0, 140.0]
            .iter()
            .map(|w| set(*w, 5, true))
            .chain([set(150.0, 0, false)])
            .collect();
        let m = max_of(six);
        assert!(close(m, shown_max(150.0, 1, 0.0, 1, false)), "the cap: {m}");
    }

    /// An override converts to the max that prescribes it, is planned as
    /// given, and the walk carries on from it.
    #[test]
    fn an_override_is_a_new_start() {
        let over = Override {
            at: 2 * DAY,
            weight: 100.0,
            reps: 10,
            sets: Some(3),
        };
        let press = Exercise::LegPress;
        let earlier = [session("w1", 1, three(300.0, 6))];
        let w = walk(press, &earlier, Some(&over));
        assert!(w.from_override);
        assert!(close(w.max.unwrap(), max_needed(100.0, 10, 3, false)));
        let d = plan_lift(press, &w, None, Some(&over), 3, 3 * DAY, LB);
        assert_eq!((d.weight, d.reps), (100.0, 10));
        assert_eq!(kinds(&d), vec![PlanReasonKind::UserSet]);

        let after = [
            session("w1", 1, three(300.0, 6)),
            session("w2", 4, three(100.0, 10)),
        ];
        let w = walk(press, &after, Some(&over));
        assert!(!w.from_override);
        assert!(close(w.max.unwrap(), shown_max(100.0, 11, 1.0, 3, false)));
        let d = plan_lift(press, &w, None, Some(&over), 3, 5 * DAY, LB);
        assert_eq!((d.weight, d.reps), (100.0, 11), "progressing from it");
    }

    /// Bodyweight lifts track a rep max: a hit is one more rep.
    #[test]
    fn bodyweight_tracks_a_rep_max() {
        let w = walk(Exercise::PullUp, &[session("w1", 1, three(0.0, 8))], None);
        let d = plan_lift(Exercise::PullUp, &w, None, None, 3, 2 * DAY, LB);
        assert_eq!((d.weight, d.reps), (0.0, 9));
        let top = walk(Exercise::PullUp, &[session("w1", 1, three(0.0, 15))], None);
        let d = plan_lift(Exercise::PullUp, &top, None, None, 3, 2 * DAY, LB);
        assert_eq!(d.reps, 15, "capped at the top");
    }

    /// Snapping down to a loadable weight leaves room: the max covers a rep
    /// more there than at the bottom.
    #[test]
    fn rounding_down_gives_an_extra_rep() {
        // Exactly loadable: 205 × 5.
        let max = max_needed(205.0, 5, 3, false);
        assert_eq!(choose(Exercise::Squat, max, None, 3, 5, 8, LB), (205.0, 5));
        // The heaviest weight covered at 5 is 103 lb: the bar takes 100,
        // which covers 6 — a rep more before the next plate.
        let max = max_needed(103.0, 5, 3, false);
        assert_eq!(choose(Exercise::Squat, max, None, 3, 5, 8, LB), (100.0, 6));
    }

    // ── Sets ──

    fn lift(ex: Exercise) -> Lift {
        Lift {
            exercise: ex,
            fixed_sets: None,
            lead_in: false,
        }
    }

    #[test]
    fn sets_fill_the_budget_from_two_up_to_five() {
        let costs = Costs::default();
        let none = HashMap::new();
        let lifts = [lift(Exercise::LateralRaise), lift(Exercise::BarbellCurl)];
        // 160 s a set, less the rest after a lift's last: 2 each + the
        // move = 520 s. 60 min fills both to 5.
        assert_eq!(allocate(&lifts, &costs, &none, 60), vec![5, 5]);
        // 20 min = 1200 s: four more sets fit.
        assert_eq!(allocate(&lifts, &costs, &none, 20), vec![4, 4]);
        // 5 min doesn't fit 2 each: the floor stands, over the budget.
        assert_eq!(allocate(&lifts, &costs, &none, 5), vec![2, 2]);
        let over: f32 = lifts
            .iter()
            .enumerate()
            .map(|(i, l)| lift_seconds(&costs, l, 2, i == 0))
            .sum();
        assert!(over > 300.0, "\"needs {} min\"", (over / 60.0).ceil());
    }

    #[test]
    fn the_lift_furthest_behind_gets_the_sets() {
        let costs = Costs::default();
        let mut weekly = HashMap::new();
        weekly.insert(crate::pb::MuscleGroup::Shoulders as i32, 9.0);
        let lifts = [lift(Exercise::LateralRaise), lift(Exercise::BarbellCurl)];
        assert_eq!(
            allocate(&lifts, &costs, &weekly, 20),
            vec![3, 5],
            "biceps are behind; shoulders nearly at ten"
        );
        // Even, the earlier lift first.
        let lifts = [lift(Exercise::BarbellCurl), lift(Exercise::LateralRaise)];
        assert_eq!(allocate(&lifts, &costs, &HashMap::new(), 12), vec![3, 2]);
    }

    #[test]
    fn override_sets_are_kept() {
        let costs = Costs::default();
        let mut fixed = lift(Exercise::LateralRaise);
        fixed.fixed_sets = Some(1);
        let lifts = [fixed, lift(Exercise::BarbellCurl)];
        assert_eq!(allocate(&lifts, &costs, &HashMap::new(), 60), vec![1, 5]);
    }

    /// Ten samples of a kind replace its default with their median.
    #[test]
    fn learned_timings_replace_the_defaults_at_ten() {
        use crate::pb::Workout;
        let build = |n: usize| {
            let mut record = WorkoutRecord::new(
                Workout {
                    id: "w".into(),
                    start_time: 1000,
                    end_time: 100_000,
                    ..Default::default()
                },
                Vec::new(),
                Vec::new(),
            );
            let mut t = 1000;
            for i in 0..n {
                let id = format!("s{i}");
                record.proposed_sets.push(ProposedSet {
                    id: id.clone(),
                    exercise: Exercise::LateralRaise as i32,
                    target_reps: 8,
                    ..Default::default()
                });
                record.completed_sets.push(CompletedSet {
                    proposed_set_id: id,
                    started_at: t,
                    ended_at: t + 30,
                    actual_reps: 8,
                    ..Default::default()
                });
                t += 30 + 100;
            }
            vec![record]
        };
        let few = Costs::learned(&build(10), 2000);
        assert_eq!(few.set_seconds, 30.0, "ten sets lifted");
        assert_eq!(few.rest_seconds[1], 120.0, "nine rests: the default");
        let enough = Costs::learned(&build(11), 2000);
        assert_eq!(enough.rest_seconds[1], 100.0);
        assert_eq!(enough.rest_seconds[0], 180.0, "other classes keep theirs");
        assert_eq!(
            Costs::learned(&build(11), 1000 + 29 * DAY),
            Costs::default()
        );
    }
}
