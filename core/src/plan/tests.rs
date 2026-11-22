use super::*;
use crate::program::{CycleStep, ProgramRef};

fn builtin() -> ProgramRef {
    Program::builtin()
}

fn walk(ex: &str, sessions: &[SessionOutcome], over: Option<&Override>) -> Walk {
    super::walk(&builtin(), ex, sessions, over)
}

/// `ex` planned by the built-in program with `sets` sets at `now`.
fn plan_lift(
    ex: &str,
    walk: &Walk,
    start: Option<f32>,
    over: Option<&Override>,
    sets: i32,
    now: i64,
    unit: AppWeightUnit,
) -> ExerciseDecision {
    let program = builtin();
    super::plan_lift(
        &LiftInputs {
            program: &program,
            exercise: ex,
            walk,
            sessions: &[],
            start,
            over,
            now,
            unit,
        },
        sets,
    )
}

fn shown_max(weight: f32, reps: i32, reserve: f32, set_number: usize, bodyweight: bool) -> f32 {
    builtin()
        .estimate
        .shown_max(weight, reps, reserve, set_number, bodyweight)
}

fn max_needed(weight: f32, reps: i32, sets: i32, bodyweight: bool) -> f32 {
    builtin()
        .estimate
        .max_needed(weight, reps, sets, bodyweight)
}

fn reps_covered(max: f32, weight: f32, sets: i32, bodyweight: bool) -> i32 {
    builtin()
        .estimate
        .reps_covered(max, weight, sets, bodyweight)
}

fn choose(
    ex: &str,
    max: f32,
    last: Option<f32>,
    sets: i32,
    rep_low: i32,
    rep_high: i32,
    unit: AppWeightUnit,
) -> (f32, i32) {
    builtin().choose(
        ex,
        max,
        last,
        Shape {
            sets,
            rep_low,
            rep_high,
        },
        unit,
    )
}

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
    let w = walk("squat", &[session("w1", 1, three(200.0, 6))], None);
    let reason = w.reason.clone().unwrap();
    assert_eq!(reason.kind, PlanReasonKind::MaxUp as i32);
    assert_eq!(reason.workout_id, "w1");
    assert!(close(w.max.unwrap(), shown_max(200.0, 7, 1.0, 3, false)));
    let d = plan_lift("squat", &w, None, None, 3, 2 * DAY, LB);
    assert_eq!((d.weight, d.reps), (200.0, 7), "rule 1: a rep more");
    assert_eq!(
        kinds(&d),
        vec![PlanReasonKind::RepsUp, PlanReasonKind::MaxUp]
    );
}

/// Past the top of the range: one step up, as many reps as covered.
#[test]
fn past_the_top_it_steps_up() {
    let w = walk("squat", &[session("w1", 1, three(200.0, 8))], None);
    let d = plan_lift("squat", &w, None, None, 3, 2 * DAY, LB);
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
    let w = walk("squat", &sessions, None);
    let reason = w.reason.clone().unwrap();
    assert_eq!(reason.kind, PlanReasonKind::MaxFromMiss as i32);
    assert_eq!(reason.set_id, "205x6", "the set that showed it");
    assert!(close(w.max.unwrap(), shown_max(205.0, 6, 1.0, 1, false)));
    assert!(w.max.unwrap() <= reason.before);
    let d = plan_lift("squat", &w, None, None, 3, 4 * DAY, LB);
    assert!(d.max < reason.before);
    assert!(d.weight <= 205.0);

    // A miss that shows more than the max before keeps the max before.
    let sessions = [
        session("w1", 1, three(100.0, 5)),
        session("w2", 2, vec![set(150.0, 8, true), set(150.0, 4, false)]),
    ];
    let w = walk("squat", &sessions, None);
    assert!(close(w.max.unwrap(), shown_max(100.0, 6, 1.0, 3, false)));
}

/// The user lowered the weight and hit everything: the max stays.
#[test]
fn a_lowered_weight_holds_the_max() {
    let sessions = [
        session("w1", 1, three(200.0, 6)),
        session("w2", 3, three(150.0, 6)),
    ];
    let w = walk("squat", &sessions, None);
    let first = walk("squat", &sessions[..1], None).max.unwrap();
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
    let w = walk("squat", &sessions, None);
    let reason = w.reason.clone().unwrap();
    assert_eq!(reason.kind, PlanReasonKind::Held as i32);
    assert_eq!(reason.cause, PlanChangeCause::StoppedEarly as i32);
    assert!(close(
        w.max.unwrap(),
        walk("squat", &sessions[..1], None).max.unwrap()
    ));
}

/// A rushed miss is excused: the max holds, and the reason says it was
/// rushed, not stopped early.
#[test]
fn a_rushed_miss_holds_the_max() {
    let first = walk("squat", &[session("w1", 1, three(200.0, 6))], None);
    let planned = plan_lift("squat", &first, None, None, 3, 2 * DAY, LB);
    let done = set(planned.weight, planned.reps, true);
    let mut rushed = session("w2", 3, vec![done.clone(), done]);
    rushed.planned_sets = 3;
    rushed.rushed = true;
    let sessions = [session("w1", 1, three(200.0, 6)), rushed];
    let w = walk("squat", &sessions, None);
    let reason = w.reason.clone().unwrap();
    assert_eq!(reason.kind, PlanReasonKind::Held as i32);
    assert_eq!(reason.cause, PlanChangeCause::Rushed as i32);
    assert!(close(
        w.max.unwrap(),
        walk("squat", &sessions[..1], None).max.unwrap()
    ));
    let d = plan_lift("squat", &w, None, None, 3, 4 * DAY, LB);
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
    let ex = "squat";
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
            exercise: ex.to_string(),
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
    let outcome = session_outcomes(&record)[ex].clone();
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
    let w = walk("squat", &[session("w1", 1, three(200.0, 6))], None);
    let d = plan_lift("squat", &w, None, None, 3, 31 * DAY, LB);
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
        plan_lift("squat", &w, None, None, 3, 50 * DAY, LB).reasons[2].after,
        w.max.unwrap() * 0.8
    );
    // The walk applies the cut the next session was planned with.
    let back = walk(
        "squat",
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
    let w = walk("squat", &[session("w1", 1, missed)], None);
    let d = plan_lift("squat", &w, None, None, 3, 2 * DAY, LB);
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
        "squat",
        &[session("w1", 1, three(200.0, 5)[..2].to_vec())],
        None,
    );
    let two = plan_lift("squat", &w, None, None, 2, 2 * DAY, LB);
    assert_eq!((two.weight, two.reps), (200.0, 6));
    assert_eq!(versus(&two), (PlanReasonKind::RepsUp, PlanChangeCause::Hit));
    let five = plan_lift("squat", &w, None, None, 5, 2 * DAY, LB);
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
    let w = walk("squat", &[session("w1", 1, three(200.0, 6))], None);
    let d = plan_lift("squat", &w, None, None, 3, 2 * DAY, LB);
    assert_eq!(versus(&d), (PlanReasonKind::RepsUp, PlanChangeCause::Hit));
    assert_eq!((d.reasons[0].reps_before, d.reasons[0].reps_after), (6, 7));
    let w = walk("squat", &[session("w1", 1, three(200.0, 8))], None);
    let d = plan_lift("squat", &w, None, None, 3, 2 * DAY, LB);
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
    let w1 = walk("squat", &[first.clone()], None);
    let planned = plan_lift("squat", &w1, None, None, 3, 2 * DAY, LB);
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
    let w = walk("squat", &[first, stopped], None);
    // More sets today, the max held: the sets moved the weight.
    let more = plan_lift("squat", &w, None, None, 5, 4 * DAY, LB);
    if more.weight != planned.weight || more.reps != planned.reps {
        assert_eq!(versus(&more).1, PlanChangeCause::Sets);
    }
    let d = plan_lift("squat", &w, None, None, 3, 4 * DAY, LB);
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
    let d = plan_lift("squat", &Walk::default(), None, None, 3, 0, LB);
    assert_eq!(kinds(&d), vec![PlanReasonKind::FirstTime]);
}

/// A lift never done: a ramp from 60% of its starting weight, never under
/// the empty bar; a bodyweight lift at the bottom of its range.
#[test]
fn first_time() {
    let none = Walk::default();
    let d = plan_lift("squat", &none, Some(180.0), None, 3, 0, LB);
    assert!(d.calibration);
    assert_eq!(d.weight, 110.0, "60% of 180, loadable");
    assert_eq!(kinds(&d), vec![PlanReasonKind::FirstTime]);
    assert_eq!(d.reasons[0].before, 180.0);
    assert_eq!(plan_lift("squat", &none, None, None, 3, 0, LB).weight, 45.0);
    let pull = plan_lift("pull_up", &none, None, None, 3, 0, LB);
    assert!(!pull.calibration);
    assert_eq!((pull.weight, pull.reps), (0.0, 5));
}

/// The ramp's missed rung gives the max; the working sets after it were
/// judged from there.
#[test]
fn the_missed_rung_gives_the_max() {
    let mut ramp = session("w1", 1, Vec::new());
    ramp.rungs = vec![set(45.0, 5, true), set(50.0, 5, true), set(55.0, 3, false)];
    let w = walk("squat", &[ramp], None);
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
        let w = walk("squat", &[ramp], None);
        assert!(
            close(w.max.unwrap(), shown_max(55.0, 5, reserve, 1, false)),
            "{reps_left:?}"
        );
    }
    let mut ramp = session("w1", 1, Vec::new());
    ramp.rungs = vec![answered(RepsLeft::FivePlus), set(65.0, 3, false)];
    let w = walk("squat", &[ramp], None);
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
        walk("squat", &[ramp], None).max.unwrap()
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
    let press = "leg_press";
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
    let w = walk("pull_up", &[session("w1", 1, three(0.0, 8))], None);
    let d = plan_lift("pull_up", &w, None, None, 3, 2 * DAY, LB);
    assert_eq!((d.weight, d.reps), (0.0, 9));
    let top = walk("pull_up", &[session("w1", 1, three(0.0, 15))], None);
    let d = plan_lift("pull_up", &top, None, None, 3, 2 * DAY, LB);
    assert_eq!(d.reps, 15, "capped at the top");
}

/// Snapping down to a loadable weight leaves room: the max covers a rep
/// more there than at the bottom.
#[test]
fn rounding_down_gives_an_extra_rep() {
    // Exactly loadable: 205 × 5.
    let max = max_needed(205.0, 5, 3, false);
    assert_eq!(choose("squat", max, None, 3, 5, 8, LB), (205.0, 5));
    // The heaviest weight covered at 5 is 103 lb: the bar takes 100,
    // which covers 6 — a rep more before the next plate.
    let max = max_needed(103.0, 5, 3, false);
    assert_eq!(choose("squat", max, None, 3, 5, 8, LB), (100.0, 6));
}

// ── Sets ──

fn lift(ex: &str) -> Lift {
    Lift {
        exercise: ex.to_string(),
        class: builtin().exercise(ex).unwrap().class.clone(),
        fixed_sets: None,
        lead_in: false,
    }
}

#[test]
fn sets_fill_the_budget_from_two_up_to_five() {
    let costs = Costs::defaults(&builtin());
    let none = BTreeMap::new();
    let lifts = [lift("lateral_raise"), lift("barbell_curl")];
    // 160 s a set, less the rest after a lift's last: 2 each + the
    // move = 520 s. 60 min fills both to 5.
    assert_eq!(allocate(&builtin(), &lifts, &costs, &none, 60), vec![5, 5]);
    // 20 min = 1200 s: four more sets fit.
    assert_eq!(allocate(&builtin(), &lifts, &costs, &none, 20), vec![4, 4]);
    // 5 min doesn't fit 2 each: the floor stands, over the budget.
    assert_eq!(allocate(&builtin(), &lifts, &costs, &none, 5), vec![2, 2]);
    let over: f32 = lifts
        .iter()
        .enumerate()
        .map(|(i, l)| lift_seconds(&costs, l, 2, i == 0))
        .sum();
    assert!(over > 300.0, "\"needs {} min\"", (over / 60.0).ceil());
}

#[test]
fn the_lift_furthest_behind_gets_the_sets() {
    let costs = Costs::defaults(&builtin());
    let mut weekly = BTreeMap::new();
    weekly.insert(Muscle::Shoulders, 9.0);
    let lifts = [lift("lateral_raise"), lift("barbell_curl")];
    assert_eq!(
        allocate(&builtin(), &lifts, &costs, &weekly, 20),
        vec![3, 5],
        "biceps are behind; shoulders nearly at ten"
    );
    // Even, the earlier lift first.
    let lifts = [lift("barbell_curl"), lift("lateral_raise")];
    assert_eq!(
        allocate(&builtin(), &lifts, &costs, &BTreeMap::new(), 12),
        vec![3, 2]
    );
}

#[test]
fn override_sets_are_kept() {
    let costs = Costs::defaults(&builtin());
    let mut fixed = lift("lateral_raise");
    fixed.fixed_sets = Some(1);
    let lifts = [fixed, lift("barbell_curl")];
    assert_eq!(
        allocate(&builtin(), &lifts, &costs, &BTreeMap::new(), 60),
        vec![1, 5]
    );
}

/// Sets tapped through a second apart teach nothing: the defaults stay.
#[test]
fn tapped_through_sets_are_not_learned_from() {
    use crate::pb::Workout;
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
    for i in 0..30 {
        let id = format!("s{i}");
        record.proposed_sets.push(ProposedSet {
            id: id.clone(),
            exercise: "lateral_raise".to_string(),
            target_reps: 8,
            ..Default::default()
        });
        record.completed_sets.push(CompletedSet {
            proposed_set_id: id,
            started_at: 1000 + 2 * i,
            ended_at: 1001 + 2 * i,
            actual_reps: 8,
            ..Default::default()
        });
    }
    assert_eq!(
        Costs::learned(&builtin(), &[record], 2000),
        Costs::defaults(&builtin())
    );
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
                exercise: "lateral_raise".to_string(),
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
    let few = Costs::learned(&builtin(), &build(10), 2000);
    assert_eq!(few.set_seconds, 30.0, "ten sets lifted");
    assert_eq!(few.rest("standard"), 120.0, "nine rests: the default");
    let enough = Costs::learned(&builtin(), &build(11), 2000);
    assert_eq!(enough.rest("standard"), 100.0);
    assert_eq!(enough.rest("heavy"), 180.0, "other classes keep theirs");
    assert_eq!(
        Costs::learned(&builtin(), &build(11), 1000 + 29 * DAY),
        Costs::defaults(&builtin())
    );
}

// ── The program's other rules ──

/// The built-in program with `ex` following `rule`.
fn with_rule(ex: &str, rule: Progression) -> Program {
    let mut p = (*builtin()).clone();
    p.progressions.insert("rule".into(), rule);
    p.exercises
        .iter_mut()
        .find(|e| e.key == ex)
        .unwrap()
        .progression = Some("rule".into());
    p
}

fn plan_by(
    p: &Program,
    ex: &str,
    sessions: &[SessionOutcome],
    sets: i32,
    now: i64,
) -> ExerciseDecision {
    let w = super::walk(p, ex, sessions, None);
    super::plan_lift(
        &LiftInputs {
            program: p,
            exercise: ex,
            walk: &w,
            sessions,
            start: None,
            over: None,
            now,
            unit: LB,
        },
        sets,
    )
}

fn sets_by(p: &Program, ex: &str, sessions: &[SessionOutcome]) -> Option<i32> {
    let w = super::walk(p, ex, sessions, None);
    rule_sets(&LiftInputs {
        program: p,
        exercise: ex,
        walk: &w,
        sessions,
        start: None,
        over: None,
        now: 0,
        unit: LB,
    })
}

fn linear(deload_after_fails: i32, increment_lb: f32) -> Progression {
    Progression::Linear {
        sets: Some(3),
        reps: 5,
        increment_lb,
        deload_after_fails,
        deload_factor: 0.9,
    }
}

fn missed(day: i64, weight: f32) -> SessionOutcome {
    session(
        &format!("m{day}"),
        day,
        vec![
            set(weight, 5, true),
            set(weight, 5, true),
            set(weight, 3, false),
        ],
    )
}

/// Linear: a step up after every rep, the same weight after a miss, and a
/// tenth off after three misses in a row at it.
#[test]
fn linear_adds_a_step_holds_and_deloads() {
    let p = with_rule("squat", linear(3, 0.0));
    let d = plan_by(
        &p,
        "squat",
        &[session("w1", 1, three(200.0, 5))],
        3,
        2 * DAY,
    );
    assert_eq!((d.weight, d.reps, d.sets), (205.0, 5, 3));
    assert_eq!(versus(&d), (PlanReasonKind::WeightUp, PlanChangeCause::Hit));
    assert_eq!(kinds(&d).last(), Some(&PlanReasonKind::Rule));
    assert_eq!(d.progression, "rule");
    assert_eq!(d.progression_kind, "linear");
    assert_eq!(sets_by(&p, "squat", &[]), Some(3));

    let two = [missed(1, 200.0), missed(3, 200.0)];
    let d = plan_by(&p, "squat", &two, 3, 4 * DAY);
    assert_eq!(d.weight, 200.0, "two misses: the same weight");
    assert_eq!(
        versus(&d),
        (PlanReasonKind::SameAsLast, PlanChangeCause::Missed)
    );

    let three_misses = [missed(1, 200.0), missed(3, 200.0), missed(5, 200.0)];
    let d = plan_by(&p, "squat", &three_misses, 3, 6 * DAY);
    assert_eq!(d.weight, 180.0, "a tenth off, loadable");
    let deload = d
        .reasons
        .iter()
        .find(|r| r.kind == PlanReasonKind::Deload as i32)
        .expect("a deload reason");
    assert_eq!(
        (deload.before, deload.after, deload.count),
        (200.0, 180.0, 3)
    );

    // A miss at a new weight starts the count again.
    let after = [missed(1, 200.0), missed(3, 200.0), missed(5, 190.0)];
    assert_eq!(plan_by(&p, "squat", &after, 3, 6 * DAY).weight, 190.0);

    let ten = with_rule("squat", linear(0, 10.0));
    let d = plan_by(
        &ten,
        "squat",
        &[session("w1", 1, three(200.0, 5))],
        3,
        2 * DAY,
    );
    assert_eq!(d.weight, 210.0, "the rule's own increment");
}

/// Linear after time away: the weight cut by the program's table.
#[test]
fn linear_after_time_off() {
    let p = with_rule("squat", linear(3, 0.0));
    let d = plan_by(
        &p,
        "squat",
        &[session("w1", 1, three(200.0, 5))],
        3,
        31 * DAY,
    );
    assert_eq!(d.weight, 180.0);
    assert!(kinds(&d).contains(&PlanReasonKind::TimeOff));
    assert_eq!(d.reasons[0].cause, PlanChangeCause::TimeOff as i32);
}

/// Double progression: a rep more each hit to the top, then a step up and
/// back to the bottom; a miss holds both.
#[test]
fn double_climbs_reps_then_weight() {
    let p = with_rule(
        "lateral_raise",
        Progression::Double {
            sets: None,
            rep_low: 8,
            rep_high: 12,
            increment_lb: 0.0,
        },
    );
    let d = plan_by(
        &p,
        "lateral_raise",
        &[session("w1", 1, three(20.0, 8))],
        3,
        2 * DAY,
    );
    assert_eq!((d.weight, d.reps), (20.0, 9));
    assert_eq!((d.rep_low, d.rep_high), (8, 12));
    let d = plan_by(
        &p,
        "lateral_raise",
        &[session("w1", 1, three(20.0, 12))],
        3,
        2 * DAY,
    );
    assert_eq!((d.weight, d.reps), (25.0, 8));
    let miss = session(
        "w1",
        1,
        vec![
            set(20.0, 10, true),
            set(20.0, 10, true),
            set(20.0, 8, false),
        ],
    );
    let d = plan_by(&p, "lateral_raise", &[miss], 3, 2 * DAY);
    assert_eq!((d.weight, d.reps), (20.0, 10));
    assert_eq!(sets_by(&p, "lateral_raise", &[]), None, "the budget's sets");
}

/// Fixed: the same numbers every time, snapped to what loads, no ramp.
#[test]
fn fixed_is_fixed() {
    let p = with_rule(
        "squat",
        Progression::Fixed {
            sets: 4,
            reps: 6,
            weight_lb: 132.0,
        },
    );
    let d = plan_by(&p, "squat", &[], 4, 0);
    assert!(!d.calibration);
    assert_eq!(
        (d.weight, d.reps, d.sets),
        (130.0, 6, 4),
        "the nearest loadable"
    );
    assert_eq!(sets_by(&p, "squat", &[]), Some(4));
}

/// A cycle: one step a session, round and round, at fractions of the max.
#[test]
fn cycle_steps_by_session() {
    let steps = vec![
        CycleStep {
            sets: 3,
            reps: 5,
            fraction: 0.75,
        },
        CycleStep {
            sets: 3,
            reps: 3,
            fraction: 0.85,
        },
        CycleStep {
            sets: 1,
            reps: 1,
            fraction: 0.95,
        },
    ];
    let p = with_rule("squat", Progression::Cycle { steps });
    let one = [session("w1", 1, three(200.0, 5))];
    let max = super::walk(&p, "squat", &one, None).max.unwrap();
    let d = plan_by(&p, "squat", &one, 3, 2 * DAY);
    assert_eq!(d.reps, 3);
    assert_eq!(d.weight, p.snap_down_lb("squat", max * 0.85, LB));
    let step = d
        .reasons
        .iter()
        .find(|r| r.kind == PlanReasonKind::CycleStep as i32)
        .unwrap();
    assert_eq!((step.count, step.of), (2, 3));
    assert_eq!(sets_by(&p, "squat", &one), Some(3));
    let three_done = [
        session("w1", 1, three(200.0, 5)),
        session("w2", 3, three(170.0, 3)),
        session("w3", 5, vec![set(190.0, 1, true)]),
    ];
    assert_eq!(
        sets_by(&p, "squat", &three_done),
        Some(3),
        "back to the first"
    );
    assert_eq!(plan_by(&p, "squat", &three_done, 3, 6 * DAY).reps, 5);
}

fn formula(sets: Option<&str>, reps: &str, weight: &str) -> Progression {
    Progression::Formula(Formula {
        lets: BTreeMap::from([("top".to_string(), "8".to_string())]),
        sets: sets.map(str::to_string),
        reps: reps.to_string(),
        weight: weight.to_string(),
        rest_seconds: Some("150".to_string()),
        note: "Reps to eight, then a step.".to_string(),
    })
}

/// A formula plans from its own expressions, its note the reason.
#[test]
fn formula_plans_from_its_expressions() {
    let p = with_rule(
        "squat",
        formula(
            Some("3"),
            "if(last.hit and last.reps < top, last.reps + 1, if(last.hit, 5, last.reps))",
            "if(last.hit and last.reps >= top, last.weight + step, last.weight)",
        ),
    );
    let d = plan_by(
        &p,
        "squat",
        &[session("w1", 1, three(200.0, 6))],
        3,
        2 * DAY,
    );
    assert_eq!((d.weight, d.reps, d.rest_seconds), (200.0, 7, 150));
    let d = plan_by(
        &p,
        "squat",
        &[session("w1", 1, three(200.0, 8))],
        3,
        2 * DAY,
    );
    assert_eq!((d.weight, d.reps), (205.0, 5));
    let rule = d.reasons.last().unwrap();
    assert_eq!(rule.kind, PlanReasonKind::Rule as i32);
    assert_eq!(rule.text, "Reps to eight, then a step.");
    assert_eq!(sets_by(&p, "squat", &[]), Some(3));
}

/// A formula that fails on this history plans by the estimated max, and
/// says why.
#[test]
fn a_failing_formula_falls_back() {
    let p = with_rule("squat", formula(None, "5", "last.weight / (sessions - 1)"));
    let d = plan_by(
        &p,
        "squat",
        &[session("w1", 1, three(200.0, 6))],
        3,
        2 * DAY,
    );
    assert_eq!(d.progression_kind, "estimated_max");
    let fallback = d.reasons.last().unwrap();
    assert_eq!(fallback.kind, PlanReasonKind::Fallback as i32);
    assert!(fallback.text.contains("zero"), "{}", fallback.text);
    let estimated = plan_lift(
        "squat",
        &walk("squat", &[session("w1", 1, three(200.0, 6))], None),
        None,
        None,
        3,
        2 * DAY,
        LB,
    );
    assert_eq!((d.weight, d.reps), (estimated.weight, estimated.reps));
}

/// Whatever the rule (but fixed), a loaded lift never done ramps first.
#[test]
fn a_lift_never_done_ramps_under_any_rule() {
    let p = with_rule("squat", linear(3, 0.0));
    let d = plan_by(&p, "squat", &[], 3, 0);
    assert!(d.calibration);
    assert_eq!(
        kinds(&d),
        vec![PlanReasonKind::FirstTime, PlanReasonKind::Rule]
    );
    assert_eq!(
        (d.rep_low, d.rep_high),
        (5, 5),
        "the ramp settles at the rule's reps"
    );
}
