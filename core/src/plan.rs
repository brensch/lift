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
//! | stopped early | unchanged |
//!
//! Time away cuts it when a workout is planned (21 days ×0.9, 42 ×0.8). A
//! lift never done runs the calibration ramp, whose missed rung gives the
//! max. An override (weight and reps, maybe sets) is converted to the max
//! that prescribes it and is a new starting point.
//!
//! **Sets** come from the time budget: 2 a lift, then one at a time (up to
//! 5) to the lift whose muscles are furthest below 10 hard sets this week,
//! until the next would pass the budget. **Reps and weight** come from the
//! max (`choose`).
//!
//! Everything here is pure. A workout's start records what it decides;
//! folding the event lays the sets out from that record and never runs it.

use std::collections::{HashMap, HashSet};

use crate::account::Account;
use crate::exercise_catalog::{
    class_rules, lift_class, load_style, muscles, primary_muscle, progression_increment_lb, rules,
    snap_down_weight_lb, snap_weight_lb, starting_weight_lb, LiftClass, LoadStyle,
};
use crate::exercise_progress::{session_outcomes, SessionOutcome, SetDone};
use crate::history::{workout_time, WorkoutRecord};
use crate::pb::{
    CompletedSet, Exercise, ExerciseDecision, ExercisePlan, PlanReason, PlanReasonKind, ProposedSet,
};
use crate::volume::{muscle_volume_7d, VOLUME_TARGET_LOW};
use crate::weight_units::AppWeightUnit;

pub const DEFAULT_BUDGET_MINUTES: i32 = 60;
/// Every lift gets this many sets before any lift gets more.
pub const MIN_SETS: i32 = 2;
pub const MAX_SETS: i32 = 5;
const DAY: i64 = 24 * 3600;
/// A ramp opens at this fraction of the lift's starting weight.
const RAMP_START_FRACTION: f32 = 0.6;
/// The sets an override names none of is converted to a max with.
const OVERRIDE_SETS: i32 = 3;
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
/// bodyweight lift a rep max. `reserve` is 1 for a set that hit its target.
pub fn shown_max(weight: f32, reps: i32, reserve: i32, set_number: usize, bodyweight: bool) -> f32 {
    let reps = reps as f32 + reserve as f32 + 0.5 * set_number.saturating_sub(1) as f32;
    if bodyweight {
        reps
    } else {
        weight * (1.0 + reps / 30.0)
    }
}

/// The max that `sets` × `reps` @ `weight` takes: the last set's, with one
/// rep in reserve.
pub fn max_needed(weight: f32, reps: i32, sets: i32, bodyweight: bool) -> f32 {
    shown_max(weight, reps, 1, sets.max(1) as usize, bodyweight)
}

/// The most reps the max covers at `weight` across `sets` (may be below
/// zero when it covers none).
pub fn reps_covered(max: f32, weight: f32, sets: i32, bodyweight: bool) -> i32 {
    let reserve = 1.0 + 0.5 * (sets.max(1) - 1) as f32;
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
///    covers there (capped at the top) — the last weight at the top when
///    the step covers less than the bottom;
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
                (last, rep_high)
            };
        }
        if reps >= rep_low {
            return (last, reps);
        }
    }
    let at_bottom = max / (1.0 + (rep_low as f32 + 1.0 + 0.5 * (sets.max(1) - 1) as f32) / 30.0);
    let weight = snap_down_weight_lb(ex, at_bottom, unit);
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
    /// The weight of the last working set done; None when the max came from
    /// a ramp alone.
    pub last_weight: Option<f32>,
    /// When the max was last set: the last session's end, or the override.
    pub last_at: i64,
    /// The override is the latest word: no session since it.
    pub from_override: bool,
    /// The step that set the max.
    pub reason: Option<PlanReason>,
    /// The max after each session, oldest first: (workout id, max).
    pub points: Vec<(String, f32)>,
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
            let days = (session.started_at - walk.last_at) / DAY;
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
}

/// The most any of `sets` shows, with `extra` reps on each, and the set.
fn most_shown(sets: &[SetDone], extra: i32, bodyweight: bool) -> Option<(f32, &str)> {
    sets.iter()
        .enumerate()
        .map(|(i, set)| {
            (
                shown_max(
                    set.weight,
                    set.reps + extra,
                    set.hit as i32,
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

/// What a calibration ramp found: the missed rung (a set to failure), or
/// the last rung when every one was full.
fn ramp_max(rungs: &[SetDone], bodyweight: bool) -> Option<(f32, &str)> {
    let (rung, reserve) = match rungs.iter().find(|r| !r.hit) {
        Some(missed) => (missed, 0),
        None => (rungs.last()?, 1),
    };
    Some((
        shown_max(rung.weight, rung.reps, reserve, 1, bodyweight),
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
    let (kind, after, set_id) = if session.stopped_early {
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
    walk.reason = Some(PlanReason {
        kind: kind as i32,
        before: walk.max.unwrap_or(0.0),
        after,
        workout_id: session.workout_id.clone(),
        set_id: set_id.to_string(),
        at: session.at,
        ..Default::default()
    });
    walk.max = Some(after);
    walk.last_weight = session.sets.last().map(|s| s.weight);
    walk.last_at = session.at;
    walk.from_override = false;
    walk.points.push((session.workout_id.clone(), after));
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
    let days = (now - walk.last_at) / DAY;
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
                let working = !p.warmup && !p.calibration;
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
                        if pp.exercise == p.exercise && working && !pp.warmup && !pp.calibration {
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

/// The seconds one lift takes with `sets`: its sets, its lead-in, and the
/// move to it when it is not the first.
pub fn lift_seconds(costs: &Costs, lift: &Lift, sets: i32, first: bool) -> f32 {
    let mut seconds = sets as f32 * costs.per_set(lift.exercise);
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
                if let Some(idx) = muscles(lift.exercise).iter().position(|m| *m == muscle) {
                    done += *n as f32 * if idx == 0 { 1.0 } else { 0.5 };
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
        let first_new = lifts.len();
        for (ex, walk) in exercises.iter().zip(&walks) {
            let over = self.account.overrides.get(&(*ex as i32));
            lifts.push(Lift {
                exercise: *ex,
                fixed_sets: over.and_then(|o| o.sets),
                lead_in: rules(*ex).warmups || (walk.max.is_none() && !is_bodyweight(*ex)),
            });
        }
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

    /// A decision as the screens show it.
    pub fn view(&self, decision: ExerciseDecision) -> ExercisePlan {
        let ex = Exercise::try_from(decision.exercise).unwrap_or(Exercise::Unspecified);
        ExercisePlan {
            overridden: self.account.overrides.contains_key(&decision.exercise),
            primary_muscle: primary_muscle(ex) as i32,
            equipment: load_style(ex).to_proto() as i32,
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

    fn set(weight: f32, reps: i32, hit: bool) -> SetDone {
        SetDone {
            set_id: format!("{weight}x{reps}"),
            weight,
            reps,
            hit,
        }
    }

    /// A session at `at` (days) of `sets` working sets.
    fn session(id: &str, day: i64, sets: Vec<SetDone>) -> SessionOutcome {
        SessionOutcome {
            workout_id: id.to_string(),
            started_at: day * DAY - 3600,
            at: day * DAY,
            sets,
            rungs: Vec::new(),
            stopped_early: false,
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
            shown_max(100.0, 5, 1, 3, false),
            100.0 * (1.0 + 7.0 / 30.0)
        ));
        assert!(close(
            shown_max(100.0, 5, 0, 1, false),
            100.0 * (1.0 + 5.0 / 30.0)
        ));
        assert!(close(shown_max(0.0, 10, 1, 2, true), 11.5));
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
        assert!(close(w.max.unwrap(), shown_max(200.0, 7, 1, 3, false)));
        let d = plan_lift(Exercise::Squat, &w, None, None, 3, 2 * DAY, LB);
        assert_eq!((d.weight, d.reps), (200.0, 7), "rule 1: a rep more");
        assert_eq!(kinds(&d), vec![PlanReasonKind::MaxUp]);
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
        assert!(close(w.max.unwrap(), shown_max(205.0, 6, 1, 1, false)));
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
        assert!(close(w.max.unwrap(), shown_max(100.0, 6, 1, 3, false)));
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
        assert_eq!(w.reason.clone().unwrap().kind, PlanReasonKind::Held as i32);
        assert!(close(
            w.max.unwrap(),
            walk(Exercise::Squat, &sessions[..1], None).max.unwrap()
        ));
    }

    /// Time off after a hit: the hit nudges the max up, then the time away
    /// cuts it, and both are reasons, in that order.
    #[test]
    fn time_off_after_a_hit() {
        let w = walk(Exercise::Squat, &[session("w1", 1, three(200.0, 6))], None);
        let d = plan_lift(Exercise::Squat, &w, None, None, 3, 31 * DAY, LB);
        assert_eq!(
            kinds(&d),
            vec![PlanReasonKind::MaxUp, PlanReasonKind::TimeOff]
        );
        let off = &d.reasons[1];
        assert_eq!(off.days_off, 30);
        assert!(close(off.after, off.before * 0.9));
        assert!(close(d.max, off.after));
        assert!(
            d.weight < 200.0,
            "no last weight: the heaviest covered at 5"
        );
        assert_eq!(
            plan_lift(Exercise::Squat, &w, None, None, 3, 50 * DAY, LB).reasons[1].after,
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
        assert!(close(w.max.unwrap(), shown_max(55.0, 3, 0, 1, false)));
        assert_eq!(w.last_weight, None);
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
        assert!(close(w.max.unwrap(), shown_max(100.0, 11, 1, 3, false)));
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
        // 160 s a set; 2 each + the move = 760 s. 60 min fills both to 5.
        assert_eq!(allocate(&lifts, &costs, &none, 60), vec![5, 5]);
        // 20 min = 1200 s: two more sets fit.
        assert_eq!(allocate(&lifts, &costs, &none, 20), vec![3, 3]);
        // 10 min doesn't fit 2 each: the floor stands, over the budget.
        assert_eq!(allocate(&lifts, &costs, &none, 10), vec![2, 2]);
        let over: f32 = lifts
            .iter()
            .enumerate()
            .map(|(i, l)| lift_seconds(&costs, l, 2, i == 0))
            .sum();
        assert!(over > 600.0, "\"needs {} min\"", (over / 60.0).ceil());
    }

    #[test]
    fn the_lift_furthest_behind_gets_the_sets() {
        let costs = Costs::default();
        let mut weekly = HashMap::new();
        weekly.insert(crate::pb::MuscleGroup::Shoulders as i32, 9.0);
        let lifts = [lift(Exercise::LateralRaise), lift(Exercise::BarbellCurl)];
        assert_eq!(
            allocate(&lifts, &costs, &weekly, 20),
            vec![2, 4],
            "biceps are behind; shoulders nearly at ten"
        );
        // Even, the earlier lift first.
        let lifts = [lift(Exercise::BarbellCurl), lift(Exercise::LateralRaise)];
        assert_eq!(allocate(&lifts, &costs, &HashMap::new(), 16), vec![3, 2]);
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
