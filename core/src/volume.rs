//! Weekly volume per muscle, and the template suggestion built on it.
//!
//! Volume is the clearest dose-response lever in hypertrophy training, so
//! the app makes it visible: weighted hard sets per muscle over the
//! program's window (`volume.window_days`), against its band
//! (`target_low`–`target_high`). A completed working set counts 1.0 for
//! the exercise's primary muscle and `secondary_credit` for each other;
//! warmups and cancelled sets count 0.
//!
//! The suggestion is a pure sort over the user's rotation by the deficit
//! of the muscles that have recovered, leaving out templates whose first
//! lift's muscle is still recovering, computed fresh every request from
//! history and never stored. If it ever needs to remember something
//! between sessions, it has gone wrong.

use std::cmp::Ordering;
use std::collections::{BTreeMap, HashMap};

use crate::history::WorkoutRecord;
use crate::pb::{MuscleVolume, NextRule, RecoveringMuscle, SuggestionMuscle, SuggestionReason};
use crate::plan::DAY;
use crate::program::{Muscle, Next, Program, Weekday, WorkoutDef};
use crate::recovery::MuscleRecovery;

/// Weighted hard sets per muscle in the program's window. Counts
/// completed, non-warmup, non-cancelled sets from every workout in the
/// window — the in-progress one included, so the display moves while you
/// train. Calibration rungs count as warmups; drops and minis part of a set.
pub fn weekly_sets(
    program: &Program,
    history: &[impl AsRef<WorkoutRecord>],
    now: i64,
) -> BTreeMap<Muscle, f32> {
    let cutoff = now - program.volume.window_days * DAY;
    let mut sets: BTreeMap<Muscle, f32> = BTreeMap::new();

    for record in history.iter().map(AsRef::as_ref) {
        let proposed_by_id: HashMap<&str, _> = record
            .proposed_sets
            .iter()
            .map(|set| (set.id.as_str(), set))
            .collect();
        for completed in &record.completed_sets {
            if completed.ended_at <= cutoff || completed.ended_at == 0 {
                continue;
            }
            let Some(proposed) = proposed_by_id.get(completed.proposed_set_id.as_str()) else {
                continue;
            };
            if !proposed.is_working() || proposed.cancelled {
                continue;
            }
            // A drop or a mini counts part of a set (`volume.partial_credit`).
            let share = if proposed.is_partial() {
                program.volume.partial_credit
            } else {
                1.0
            };
            for (muscle, credit) in program.credit(&proposed.exercise) {
                *sets.entry(muscle).or_insert(0.0) += credit * share;
            }
        }
    }
    sets
}

/// The window's sets per muscle, against the band, as Home shows them.
pub fn muscle_volume(
    program: &Program,
    history: &[impl AsRef<WorkoutRecord>],
    now: i64,
) -> Vec<MuscleVolume> {
    volume_rows(program, &weekly_sets(program, history, now))
}

/// Every muscle's sets, against the volume band.
pub fn volume_rows(program: &Program, sets: &BTreeMap<Muscle, f32>) -> Vec<MuscleVolume> {
    Muscle::ALL
        .iter()
        .map(|muscle| MuscleVolume {
            muscle: muscle.to_proto() as i32,
            completed_sets_7d: sets.get(muscle).copied().unwrap_or(0.0),
            target_low: program.volume.band(*muscle).0,
            target_high: program.volume.band(*muscle).1,
        })
        .collect()
}

/// The suggestion: a rotation template and why.
#[derive(Clone, Debug, PartialEq)]
pub struct Suggestion {
    pub template_id: String,
    pub reason: SuggestionReason,
}

/// A template's distinct primary muscles, in exercise order.
pub fn primary_muscles(program: &Program, exercises: &[String]) -> Vec<Muscle> {
    let mut out = Vec::new();
    for muscle in exercises.iter().filter_map(|ex| program.primary_muscle(ex)) {
        if !out.contains(&muscle) {
            out.push(muscle);
        }
    }
    out
}

/// Pick the rotation template whose recovered primary muscles are
/// furthest below the band.
///
/// score = Σ over the template's distinct primary muscles that have
///         recovered now of max(0, target_low − sets_7d)
///
/// A template whose first lift's primary muscle is still recovering is
/// left out. Of the rest, every template within `volume.tie_fraction` of
/// the best score is tied; the tie goes to the one started least recently (never
/// started first), so the rotation turns over instead of one broad
/// template winning every day. When none of them is both recovered and
/// behind, the one started least recently (`fallback`). When every
/// template is left out, the one whose first lift's muscle recovers
/// soonest (`first_lift_recovering`). Reserves (templates out of
/// rotation) are never picked; None when nothing is in rotation.
pub fn suggest_template(
    program: &Program,
    volume: &[MuscleVolume],
    recovery: &[MuscleRecovery],
    now: i64,
    last_started: &HashMap<String, i64>,
    utc_offset: i64,
) -> Option<Suggestion> {
    match program.next {
        Next::Volume => {}
        Next::Sequence => return in_sequence(program, last_started),
        Next::Schedule => {
            if let Some(s) = by_schedule(program, now, last_started, utc_offset) {
                return Some(s);
            }
        }
    }
    by_volume(program, volume, recovery, now, last_started)
}

/// `next: sequence`: the rotation workout after the last one started, round
/// and round; the first when none has been.
fn in_sequence(program: &Program, last_started: &HashMap<String, i64>) -> Option<Suggestion> {
    let rotation: Vec<&WorkoutDef> = program.workouts.iter().filter(|t| t.rotation).collect();
    let started = |t: &WorkoutDef| last_started.get(&t.id).copied().unwrap_or(0);
    let last = rotation
        .iter()
        .enumerate()
        .filter(|(_, t)| started(t) > 0)
        .max_by_key(|(i, t)| (started(t), std::cmp::Reverse(*i)))
        .map(|(i, _)| i);
    let next = match last {
        Some(i) => rotation[(i + 1) % rotation.len()],
        None => rotation.first()?,
    };
    Some(Suggestion {
        template_id: next.id.clone(),
        reason: SuggestionReason {
            rule: NextRule::Sequence as i32,
            ..Default::default()
        },
    })
}

/// `next: schedule`: the workout `schedule` gives today, unless it was
/// already started today; otherwise the next day that has one. None when
/// the schedule names no workout the program has.
fn by_schedule(
    program: &Program,
    now: i64,
    last_started: &HashMap<String, i64>,
    utc_offset: i64,
) -> Option<Suggestion> {
    let day = |t: i64| (t + utc_offset).div_euclid(86_400);
    let today = Weekday::of(now, utc_offset).index();
    // Through to the same day next week, for a schedule of one day.
    (0..=7).find_map(|d| {
        let id = program.schedule.get(&Weekday::ALL[(today + d) % 7])?;
        program.workout(id)?;
        let done_today = last_started.get(id).is_some_and(|&at| day(at) == day(now));
        (d > 0 || !done_today).then(|| Suggestion {
            template_id: id.clone(),
            reason: SuggestionReason {
                rule: NextRule::Schedule as i32,
                days_until: d as i32,
                ..Default::default()
            },
        })
    })
}

/// `next: volume`: the rotation workout whose rested muscles are furthest
/// behind the week's targets.
fn by_volume(
    program: &Program,
    volume: &[MuscleVolume],
    recovery: &[MuscleRecovery],
    now: i64,
    last_started: &HashMap<String, i64>,
) -> Option<Suggestion> {
    let sets = |muscle: Muscle| {
        volume
            .iter()
            .find(|v| v.muscle == muscle.to_proto() as i32)
            .map_or((0.0, program.volume.target_low), |v| {
                (v.completed_sets_7d, v.target_low)
            })
    };
    let deficit = |muscle: Muscle| {
        let (done, target) = sets(muscle);
        (target as f32 - done).max(0.0)
    };
    let recovering = |muscle: Muscle| {
        recovery
            .iter()
            .find(|r| r.muscle == muscle)
            .filter(|r| !r.is_recovered(now))
    };

    struct Scored<'a> {
        template: &'a WorkoutDef,
        index: usize,
        started: i64,
        score: f32,
        behind: Vec<Muscle>,
        /// The first lift's muscle, while it recovers.
        blocked: Option<&'a MuscleRecovery>,
    }
    let by_deficit = |a: &Muscle, b: &Muscle| {
        deficit(*b)
            .partial_cmp(&deficit(*a))
            .unwrap_or(Ordering::Equal)
            .then((a.to_proto() as i32).cmp(&(b.to_proto() as i32)))
    };
    let mut scored = Vec::new();
    let mut ruled_out: Vec<Muscle> = Vec::new();
    for (index, template) in program.workouts.iter().filter(|t| t.rotation).enumerate() {
        let mut behind = Vec::new();
        for muscle in primary_muscles(program, &template.exercises) {
            if deficit(muscle) <= 0.0 {
                continue;
            }
            if recovering(muscle).is_some() {
                if !ruled_out.contains(&muscle) {
                    ruled_out.push(muscle);
                }
            } else {
                behind.push(muscle);
            }
        }
        behind.sort_by(by_deficit);
        let first = template
            .exercises
            .iter()
            .find_map(|ex| program.primary_muscle(ex));
        scored.push(Scored {
            blocked: first.and_then(recovering),
            template,
            index,
            started: last_started.get(&template.id).copied().unwrap_or(0),
            score: behind.iter().map(|m| deficit(*m)).sum(),
            behind,
        });
    }
    let ready: Vec<&Scored> = scored.iter().filter(|s| s.blocked.is_none()).collect();
    let best = ready.iter().map(|s| s.score).fold(0.0f32, f32::max);
    let fallback = !ready.is_empty() && best <= 0.0;
    let least_recent = |a: &&Scored, b: &&Scored| {
        a.started
            .cmp(&b.started)
            .then(b.score.partial_cmp(&a.score).unwrap_or(Ordering::Equal))
            .then(a.index.cmp(&b.index))
    };
    let winner = if ready.is_empty() {
        scored.iter().min_by(|a, b| {
            let soonest = |s: &Scored| s.blocked.map_or(0, |r| r.recovered_at);
            soonest(a).cmp(&soonest(b)).then(least_recent(a, b))
        })?
    } else {
        ready
            .iter()
            .copied()
            .filter(|s| fallback || s.score >= best * program.volume.tie_fraction)
            .min_by(least_recent)?
    };

    ruled_out.sort_by(by_deficit);
    Some(Suggestion {
        template_id: winner.template.id.clone(),
        reason: SuggestionReason {
            behind: winner
                .behind
                .iter()
                .map(|m| {
                    let (done, target) = sets(*m);
                    SuggestionMuscle {
                        muscle: m.to_proto() as i32,
                        sets_7d: done,
                        target,
                    }
                })
                .collect(),
            recovering: ruled_out
                .iter()
                .filter_map(|m| recovering(*m))
                .map(|r| RecoveringMuscle {
                    muscle: r.muscle.to_proto() as i32,
                    hours_remaining: r.hours_remaining(now) as i32,
                })
                .collect(),
            fallback,
            first_lift_recovering: winner.blocked.filter(|_| ready.is_empty()).map(|r| {
                RecoveringMuscle {
                    muscle: r.muscle.to_proto() as i32,
                    hours_remaining: r.hours_remaining(now) as i32,
                }
            }),
            ..Default::default()
        },
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pb::{CompletedSet, MuscleGroup, ProposedSet, Workout};

    fn record_with_sets(at: i64, sets: &[(&str, bool)]) -> WorkoutRecord {
        let mut proposed = Vec::new();
        let mut completed = Vec::new();
        for (i, (ex, warmup)) in sets.iter().enumerate() {
            let id = format!("s{i}");
            proposed.push(ProposedSet {
                id: id.clone(),
                exercise: ex.to_string(),
                target_reps: 10,
                warmup: *warmup,
                ..Default::default()
            });
            completed.push(CompletedSet {
                proposed_set_id: id,
                actual_reps: 10,
                actual_weight: 100.0,
                ended_at: at,
                ..Default::default()
            });
        }
        WorkoutRecord {
            workout: Workout {
                id: format!("w{at}"),
                start_time: at - 3600,
                end_time: at,
                ..Default::default()
            },
            proposed_sets: proposed,
            completed_sets: completed,
            heart_rate: Vec::new(),
            exercise_logs: Vec::new(),
            ..Default::default()
        }
    }

    fn volume_for(volume: &[MuscleVolume], muscle: MuscleGroup) -> f32 {
        volume
            .iter()
            .find(|v| v.muscle == muscle as i32)
            .unwrap()
            .completed_sets_7d
    }

    /// Primary counts 1.0, secondary 0.5: three bench sets are 3.0 chest
    /// and 1.5 triceps.
    #[test]
    fn secondary_muscles_get_half_credit() {
        let now = 1_000_000;
        let history = vec![record_with_sets(
            now - 3600,
            &[
                ("bench_press", false),
                ("bench_press", false),
                ("bench_press", false),
            ],
        )];
        let volume = muscle_volume(&Program::builtin(), &history, now);
        assert_eq!(volume_for(&volume, MuscleGroup::Chest), 3.0);
        assert_eq!(volume_for(&volume, MuscleGroup::Triceps), 1.5);
        assert_eq!(volume_for(&volume, MuscleGroup::Quads), 0.0);
        assert_eq!(volume.len(), 10, "one entry per muscle, always");
    }

    /// Warmups count 0, and sets older than 7 days fall out of the window.
    #[test]
    fn warmups_and_old_sets_are_excluded() {
        let now = 1_000_000;
        let history = vec![
            record_with_sets(now - 3600, &[("squat", true), ("squat", false)]),
            record_with_sets(now - 7 * DAY - 100, &[("squat", false)]),
        ];
        let volume = muscle_volume(&Program::builtin(), &history, now);
        assert_eq!(volume_for(&volume, MuscleGroup::Quads), 1.0);
    }

    fn template(id: &str, exercises: &[&str]) -> WorkoutDef {
        WorkoutDef {
            id: id.to_string(),
            name: id.to_string(),
            exercises: exercises.iter().map(|e| e.to_string()).collect(),
            rotation: true,
            notes: String::new(),
            from_library: String::new(),
            groups: Vec::new(),
        }
    }

    fn suggest(
        templates: &[WorkoutDef],
        history: &[WorkoutRecord],
        now: i64,
        last: &HashMap<String, i64>,
    ) -> Option<Suggestion> {
        let program = Program::builtin().with_workouts(templates.to_vec());
        suggest_template(
            &program,
            &muscle_volume(&program, history, now),
            &per_muscle_recovery(&program, history),
            now,
            last,
            0,
        )
    }

    use crate::recovery::per_muscle_recovery;

    /// The template covering the most-behind muscles wins, and the reason
    /// names them with their sets and the target.
    #[test]
    fn suggestion_picks_the_biggest_deficit() {
        let now = 1_000_000;
        // Ten leg extensions three days ago: quads covered and rested.
        let history = vec![record_with_sets(
            now - 3 * 86_400,
            &[("leg_extension", false); 10],
        )];
        let templates = vec![
            template("legs", &["squat", "leg_extension"]),
            template("pull", &["barbell_row", "barbell_curl"]),
        ];
        let got = suggest(&templates, &history, now, &HashMap::new()).expect("a suggestion");
        assert_eq!(got.template_id, "pull");
        let behind: Vec<i32> = got.reason.behind.iter().map(|m| m.muscle).collect();
        assert_eq!(
            behind,
            vec![MuscleGroup::Back as i32, MuscleGroup::Biceps as i32]
        );
        assert_eq!(got.reason.behind[0].sets_7d, 0.0);
        assert_eq!(
            got.reason.behind[0].target,
            Program::builtin().volume.target_low
        );
        assert!(got.reason.recovering.is_empty());
        assert!(!got.reason.fallback);
    }

    /// A muscle still recovering scores nothing, however far behind: a
    /// squat yesterday rules quads and glutes out (legs opens on the
    /// Romanian deadlift, so it is still in) and the reason says for how
    /// long.
    #[test]
    fn recovering_muscles_score_nothing() {
        let now = 1_000_000;
        let history = vec![record_with_sets(now - 20 * 3600, &[("squat", false)])];
        let templates = vec![
            template("legs", &["romanian_deadlift", "squat", "hip_thrust"]),
            template("arms", &["barbell_curl"]),
        ];
        let got = suggest(&templates, &history, now, &HashMap::new()).expect("a suggestion");
        // Legs: glutes (9.5 behind) and quads (9) recovering, so only
        // hamstrings (10) count;
        // arms: biceps (10). Tied, and neither started: the higher score,
        // then the earlier template.
        assert_eq!(got.template_id, "legs");
        let recovering: Vec<(i32, i32)> = got
            .reason
            .recovering
            .iter()
            .map(|r| (r.muscle, r.hours_remaining))
            .collect();
        assert_eq!(
            recovering,
            vec![
                (MuscleGroup::Glutes as i32, 27),
                (MuscleGroup::Quads as i32, 27)
            ]
        );
        let behind: Vec<i32> = got.reason.behind.iter().map(|m| m.muscle).collect();
        assert_eq!(behind, vec![MuscleGroup::Hamstrings as i32]);
    }

    /// Within 20% of the best score is a tie, and the tie goes to the
    /// template started least recently. Past 20% the higher score wins
    /// whoever was started last.
    #[test]
    fn ties_within_a_fifth_go_to_the_least_recent() {
        let now = 1_000_000;
        // Nothing done: chest, back and biceps 10 behind each.
        let big = template("big", &["bench_press", "barbell_row", "barbell_curl"]);
        let pull = template("pull", &["barbell_row", "barbell_curl"]);
        let mut last = HashMap::new();
        last.insert("big".to_string(), now - 86_400);
        last.insert("pull".to_string(), now - 2 * 86_400);
        // 20 is under 80% of 30: big wins though started since.
        let got = suggest(&[big.clone(), pull], &[], now, &last).unwrap();
        assert_eq!(got.template_id, "big");

        // Core 5 behind as well: 25 against 30 is a tie, and the template
        // started earlier wins it.
        let pull_core = template("pull_core", &["barbell_row", "barbell_curl", "crunch"]);
        last.insert("pull_core".to_string(), now - 2 * 86_400);
        let history = vec![record_with_sets(now - 3 * 86_400, &[("crunch", false); 5])];
        let got = suggest(&[big.clone(), pull_core.clone()], &history, now, &last).unwrap();
        assert_eq!(got.template_id, "pull_core", "it won the tie on its score");

        // Started more recently than big: big wins the tie.
        last.insert("pull_core".to_string(), now - 2 * 3600);
        let got = suggest(&[big, pull_core], &history, now, &last).unwrap();
        assert_eq!(got.template_id, "big");
    }

    /// A template whose first lift's muscle is recovering is left out,
    /// however far behind the rest of it is; when every template is, the
    /// one whose first lift recovers soonest, and the reason says so.
    #[test]
    fn a_recovering_first_lift_leaves_the_template_out() {
        let now = 1_000_000;
        // Bench started 21 hours ago: chest has 27 hours to go, triceps 15.
        let history = vec![record_with_sets(now - 20 * 3600, &[("bench_press", false)])];
        let push = template("push", &["bench_press", "overhead_press", "lateral_raise"]);
        let arms = template("arms", &["barbell_curl"]);
        let got = suggest(&[push.clone(), arms], &history, now, &HashMap::new()).unwrap();
        assert_eq!(got.template_id, "arms", "push opens on chest");
        assert!(got.reason.first_lift_recovering.is_none());

        // Only templates that open on something recovering: the one that
        // comes back first, whoever is behind.
        let dips = template("dips", &["skull_crusher", "barbell_curl"]);
        let got = suggest(&[push, dips], &history, now, &HashMap::new()).unwrap();
        assert_eq!(got.template_id, "dips", "triceps back before chest");
        let waiting = got.reason.first_lift_recovering.expect("says so");
        assert_eq!(
            (waiting.muscle, waiting.hours_remaining),
            (MuscleGroup::Triceps as i32, 15)
        );
        assert!(!got.reason.fallback);
    }

    /// Nothing recovered and behind: the rotation template started least
    /// recently, flagged as the fallback.
    #[test]
    fn nothing_behind_falls_back_to_the_least_recent() {
        let now = 1_000_000;
        // Quads rested and past ten this week.
        let history = vec![record_with_sets(now - 3 * 86_400, &[("squat", false); 12])];
        let templates = vec![template("a", &["squat"]), template("b", &["leg_press"])];
        let mut last = HashMap::new();
        last.insert("a".to_string(), now - 2 * 86_400);
        last.insert("b".to_string(), now - 5 * 86_400);
        let got = suggest(&templates, &history, now, &last).expect("a suggestion");
        assert_eq!(got.template_id, "b");
        assert!(got.reason.fallback);
        assert!(got.reason.behind.is_empty());
    }

    /// Reserves are never suggested, however far behind; with nothing in
    /// rotation there is no suggestion.
    #[test]
    fn reserves_are_never_suggested() {
        let now = 1_000_000;
        let mut legs = template("legs", &["squat", "romanian_deadlift"]);
        legs.rotation = false;
        let arms = template("arms", &["barbell_curl"]);
        let got = suggest(&[legs.clone(), arms], &[], now, &HashMap::new()).unwrap();
        assert_eq!(got.template_id, "arms");
        assert!(suggest(&[legs], &[], now, &HashMap::new()).is_none());
    }

    /// The rotation in order: the one after the last started, round and
    /// round, the first when none has been; recovery and volume don't
    /// skip one.
    #[test]
    fn sequence_goes_in_order() {
        let mut program = Program::builtin().with_workouts(vec![
            template("a", &["squat"]),
            template("b", &["bench_press"]),
            template("c", &["deadlift"]),
        ]);
        program.next = Next::Sequence;
        let pick = |last: &[(&str, i64)]| {
            let last: HashMap<String, i64> =
                last.iter().map(|(id, at)| (id.to_string(), *at)).collect();
            let s = suggest_template(&program, &[], &[], 1_000_000, &last, 0).unwrap();
            assert_eq!(s.reason.rule, NextRule::Sequence as i32);
            s.template_id
        };
        assert_eq!(pick(&[]), "a");
        assert_eq!(pick(&[("a", 10), ("b", 20)]), "c");
        assert_eq!(pick(&[("a", 10), ("b", 20), ("c", 30)]), "a");
        // A workout outside the rotation doesn't move it.
        assert_eq!(pick(&[("b", 20), ("reserve", 40)]), "c");
    }

    /// By the day: today's workout, unless it's been started today; then
    /// the next day that has one. The day is the phone's, by its offset.
    #[test]
    fn schedule_reads_the_day() {
        let mut program = Program::builtin().with_workouts(vec![
            template("upper", &["bench_press"]),
            template("lower", &["squat"]),
        ]);
        program.next = Next::Schedule;
        program.schedule = BTreeMap::from([
            (Weekday::Mon, "upper".to_string()),
            (Weekday::Thu, "lower".to_string()),
        ]);
        // Monday 3 March 2025, 10:00 UTC.
        let monday = 1_740_996_000;
        assert_eq!(Weekday::of(monday, 0), Weekday::Mon);
        let pick = |now: i64, last: &[(&str, i64)], offset: i64| {
            let last: HashMap<String, i64> =
                last.iter().map(|(id, at)| (id.to_string(), *at)).collect();
            let s = suggest_template(&program, &[], &[], now, &last, offset).unwrap();
            assert_eq!(s.reason.rule, NextRule::Schedule as i32);
            (s.template_id, s.reason.days_until)
        };
        assert_eq!(pick(monday, &[], 0), ("upper".to_string(), 0));
        // Done this morning: Thursday's is next.
        assert_eq!(
            pick(monday, &[("upper", monday - 3600)], 0),
            ("lower".to_string(), 3)
        );
        // Tuesday: Thursday's, two days off.
        assert_eq!(pick(monday + 86_400, &[], 0), ("lower".to_string(), 2));
        // Eleven hours behind UTC it's still Sunday: Monday's, tomorrow.
        assert_eq!(pick(monday, &[], -11 * 3600), ("upper".to_string(), 1));
        // One day a week, done today: the same day next week.
        program.schedule = BTreeMap::from([(Weekday::Mon, "upper".to_string())]);
        let pick_one = suggest_template(
            &program,
            &[],
            &[],
            monday,
            &HashMap::from([("upper".to_string(), monday - 60)]),
            0,
        )
        .unwrap();
        assert_eq!(pick_one.reason.days_until, 7);
    }

    /// A muscle's own target is its band on Home and what the suggestion
    /// scores it against.
    #[test]
    fn a_muscles_own_target() {
        let mut program = Program::clone(&Program::builtin());
        program.volume.targets.insert(
            Muscle::Shoulders,
            crate::program::Band { low: 16, high: 24 },
        );
        let rows = volume_rows(&program, &BTreeMap::new());
        let shoulders = rows
            .iter()
            .find(|r| r.muscle == Muscle::Shoulders.to_proto() as i32)
            .unwrap();
        assert_eq!((shoulders.target_low, shoulders.target_high), (16, 24));
        let chest = rows
            .iter()
            .find(|r| r.muscle == Muscle::Chest.to_proto() as i32)
            .unwrap();
        assert_eq!(
            (chest.target_low, chest.target_high),
            (program.volume.target_low, program.volume.target_high)
        );
    }
}
