//! Weekly volume per muscle, and the template suggestion built on it.
//!
//! Volume is the clearest dose-response lever in hypertrophy training, so
//! the app makes it visible: weighted hard sets per muscle over a rolling
//! 7 days, against a 10–20 band. A completed working set counts 1.0 for
//! the exercise's primary muscle and 0.5 for each secondary; warmups and
//! cancelled sets count 0.
//!
//! The suggestion is a pure sort over the user's rotation by the deficit
//! of the muscles that have recovered, leaving out templates whose first
//! lift's muscle is still recovering, computed fresh every request from
//! history and never stored. If it ever needs to remember something
//! between sessions, it has gone wrong.

use std::cmp::Ordering;
use std::collections::HashMap;

use crate::exercise_catalog::{muscles, primary_muscle, ALL_MUSCLES};
use crate::history::WorkoutRecord;
use crate::pb::{
    Exercise, MuscleGroup, MuscleVolume, RecoveringMuscle, SuggestionMuscle, SuggestionReason,
    WorkoutTemplate,
};
use crate::recovery::MuscleRecovery;

pub const VOLUME_WINDOW_SECONDS: i64 = 7 * 24 * 3600;
pub const VOLUME_TARGET_LOW: i32 = 10;
pub const VOLUME_TARGET_HIGH: i32 = 20;
const SECONDARY_WEIGHT: f32 = 0.5;

/// Weighted hard sets per muscle in the last 7 days. Counts completed,
/// non-warmup, non-cancelled sets from every workout in the window — the
/// in-progress one included, so the display moves while you train.
/// Calibration rungs count as warmups.
pub fn muscle_volume_7d(history: &[WorkoutRecord], now: i64) -> Vec<MuscleVolume> {
    let cutoff = now - VOLUME_WINDOW_SECONDS;
    let mut sets: HashMap<MuscleGroup, f32> = HashMap::new();

    for record in history {
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
            let Ok(ex) = Exercise::try_from(proposed.exercise) else {
                continue;
            };
            for (muscle, credit) in credit(ex) {
                *sets.entry(muscle).or_insert(0.0) += credit;
            }
        }
    }

    volume_rows(&sets)
}

/// What one working set of `ex` counts for each muscle it trains: 1.0 for
/// the primary, 0.5 for each secondary.
pub fn credit(ex: Exercise) -> impl Iterator<Item = (MuscleGroup, f32)> {
    muscles(ex).iter().enumerate().map(|(idx, muscle)| {
        let credit = if idx == 0 { 1.0 } else { SECONDARY_WEIGHT };
        (*muscle, credit)
    })
}

/// Every muscle's sets, against the volume band.
pub fn volume_rows(sets: &HashMap<MuscleGroup, f32>) -> Vec<MuscleVolume> {
    ALL_MUSCLES
        .iter()
        .map(|muscle| MuscleVolume {
            muscle: *muscle as i32,
            completed_sets_7d: sets.get(muscle).copied().unwrap_or(0.0),
            target_low: VOLUME_TARGET_LOW,
            target_high: VOLUME_TARGET_HIGH,
        })
        .collect()
}

/// A template within this fraction of the best score is tied with it.
pub const TIE_FRACTION: f32 = 0.8;

/// The suggestion: a rotation template and why.
#[derive(Clone, Debug, PartialEq)]
pub struct Suggestion {
    pub template_id: String,
    pub reason: SuggestionReason,
}

/// A template's distinct primary muscles, in exercise order.
pub fn primary_muscles(exercises: &[i32]) -> Vec<MuscleGroup> {
    let mut out = Vec::new();
    for ex in exercises.iter().filter_map(|e| Exercise::try_from(*e).ok()) {
        let muscle = primary_muscle(ex);
        if muscle != MuscleGroup::Unspecified && !out.contains(&muscle) {
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
/// left out. Of the rest, every template within [TIE_FRACTION] of the best
/// score is tied; the tie goes to the one started least recently (never
/// started first), so the rotation turns over instead of one broad
/// template winning every day. When none of them is both recovered and
/// behind, the one started least recently (`fallback`). When every
/// template is left out, the one whose first lift's muscle recovers
/// soonest (`first_lift_recovering`). Reserves (templates out of
/// rotation) are never picked; None when nothing is in rotation.
pub fn suggest_template(
    templates: &[WorkoutTemplate],
    volume: &[MuscleVolume],
    recovery: &[MuscleRecovery],
    now: i64,
    last_started: &HashMap<String, i64>,
) -> Option<Suggestion> {
    let sets = |muscle: MuscleGroup| {
        volume
            .iter()
            .find(|v| v.muscle == muscle as i32)
            .map_or((0.0, VOLUME_TARGET_LOW), |v| {
                (v.completed_sets_7d, v.target_low)
            })
    };
    let deficit = |muscle: MuscleGroup| {
        let (done, target) = sets(muscle);
        (target as f32 - done).max(0.0)
    };
    let recovering = |muscle: MuscleGroup| {
        recovery
            .iter()
            .find(|r| r.muscle == muscle)
            .filter(|r| !r.is_recovered(now))
    };

    struct Scored<'a> {
        template: &'a WorkoutTemplate,
        index: usize,
        started: i64,
        score: f32,
        behind: Vec<MuscleGroup>,
        /// The first lift's muscle, while it recovers.
        blocked: Option<&'a MuscleRecovery>,
    }
    let by_deficit = |a: &MuscleGroup, b: &MuscleGroup| {
        deficit(*b)
            .partial_cmp(&deficit(*a))
            .unwrap_or(Ordering::Equal)
            .then((*a as i32).cmp(&(*b as i32)))
    };
    let mut scored = Vec::new();
    let mut ruled_out: Vec<MuscleGroup> = Vec::new();
    for (index, template) in templates.iter().filter(|t| t.in_rotation).enumerate() {
        let mut behind = Vec::new();
        for muscle in primary_muscles(&template.exercises) {
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
            .filter_map(|e| Exercise::try_from(*e).ok())
            .find(|e| *e != Exercise::Unspecified);
        scored.push(Scored {
            blocked: first.and_then(|ex| recovering(primary_muscle(ex))),
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
            .filter(|s| fallback || s.score >= best * TIE_FRACTION)
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
                        muscle: *m as i32,
                        sets_7d: done,
                        target,
                    }
                })
                .collect(),
            recovering: ruled_out
                .iter()
                .filter_map(|m| recovering(*m))
                .map(|r| RecoveringMuscle {
                    muscle: r.muscle as i32,
                    hours_remaining: r.hours_remaining(now) as i32,
                })
                .collect(),
            fallback,
            first_lift_recovering: winner.blocked.filter(|_| ready.is_empty()).map(|r| {
                RecoveringMuscle {
                    muscle: r.muscle as i32,
                    hours_remaining: r.hours_remaining(now) as i32,
                }
            }),
        },
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pb::{CompletedSet, ProposedSet, Workout};

    fn record_with_sets(at: i64, sets: &[(Exercise, bool)]) -> WorkoutRecord {
        let mut proposed = Vec::new();
        let mut completed = Vec::new();
        for (i, (ex, warmup)) in sets.iter().enumerate() {
            let id = format!("s{i}");
            proposed.push(ProposedSet {
                id: id.clone(),
                exercise: *ex as i32,
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
                (Exercise::BenchPress, false),
                (Exercise::BenchPress, false),
                (Exercise::BenchPress, false),
            ],
        )];
        let volume = muscle_volume_7d(&history, now);
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
            record_with_sets(
                now - 3600,
                &[(Exercise::Squat, true), (Exercise::Squat, false)],
            ),
            record_with_sets(
                now - VOLUME_WINDOW_SECONDS - 100,
                &[(Exercise::Squat, false)],
            ),
        ];
        let volume = muscle_volume_7d(&history, now);
        assert_eq!(volume_for(&volume, MuscleGroup::Quads), 1.0);
    }

    fn template(id: &str, exercises: &[Exercise]) -> WorkoutTemplate {
        WorkoutTemplate {
            id: id.to_string(),
            name: id.to_string(),
            exercises: exercises.iter().map(|e| *e as i32).collect(),
            in_rotation: true,
            ..Default::default()
        }
    }

    fn suggest(
        templates: &[WorkoutTemplate],
        history: &[WorkoutRecord],
        now: i64,
        last: &HashMap<String, i64>,
    ) -> Option<Suggestion> {
        suggest_template(
            templates,
            &muscle_volume_7d(history, now),
            &per_muscle_recovery(history),
            now,
            last,
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
            &[(Exercise::LegExtension, false); 10],
        )];
        let templates = vec![
            template("legs", &[Exercise::Squat, Exercise::LegExtension]),
            template("pull", &[Exercise::BarbellRow, Exercise::BarbellCurl]),
        ];
        let got = suggest(&templates, &history, now, &HashMap::new()).expect("a suggestion");
        assert_eq!(got.template_id, "pull");
        let behind: Vec<i32> = got.reason.behind.iter().map(|m| m.muscle).collect();
        assert_eq!(
            behind,
            vec![MuscleGroup::Back as i32, MuscleGroup::Biceps as i32]
        );
        assert_eq!(got.reason.behind[0].sets_7d, 0.0);
        assert_eq!(got.reason.behind[0].target, VOLUME_TARGET_LOW);
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
        let history = vec![record_with_sets(
            now - 20 * 3600,
            &[(Exercise::Squat, false)],
        )];
        let templates = vec![
            template(
                "legs",
                &[
                    Exercise::RomanianDeadlift,
                    Exercise::Squat,
                    Exercise::HipThrust,
                ],
            ),
            template("arms", &[Exercise::BarbellCurl]),
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
        let big = template(
            "big",
            &[
                Exercise::BenchPress,
                Exercise::BarbellRow,
                Exercise::BarbellCurl,
            ],
        );
        let pull = template("pull", &[Exercise::BarbellRow, Exercise::BarbellCurl]);
        let mut last = HashMap::new();
        last.insert("big".to_string(), now - 86_400);
        last.insert("pull".to_string(), now - 2 * 86_400);
        // 20 is under 80% of 30: big wins though started since.
        let got = suggest(&[big.clone(), pull], &[], now, &last).unwrap();
        assert_eq!(got.template_id, "big");

        // Core 5 behind as well: 25 against 30 is a tie, and the template
        // started earlier wins it.
        let pull_core = template(
            "pull_core",
            &[
                Exercise::BarbellRow,
                Exercise::BarbellCurl,
                Exercise::Crunch,
            ],
        );
        last.insert("pull_core".to_string(), now - 2 * 86_400);
        let history = vec![record_with_sets(
            now - 3 * 86_400,
            &[(Exercise::Crunch, false); 5],
        )];
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
        let history = vec![record_with_sets(
            now - 20 * 3600,
            &[(Exercise::BenchPress, false)],
        )];
        let push = template(
            "push",
            &[
                Exercise::BenchPress,
                Exercise::OverheadPress,
                Exercise::LateralRaise,
            ],
        );
        let arms = template("arms", &[Exercise::BarbellCurl]);
        let got = suggest(&[push.clone(), arms], &history, now, &HashMap::new()).unwrap();
        assert_eq!(got.template_id, "arms", "push opens on chest");
        assert!(got.reason.first_lift_recovering.is_none());

        // Only templates that open on something recovering: the one that
        // comes back first, whoever is behind.
        let dips = template("dips", &[Exercise::SkullCrusher, Exercise::BarbellCurl]);
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
        let history = vec![record_with_sets(
            now - 3 * 86_400,
            &[(Exercise::Squat, false); 12],
        )];
        let templates = vec![
            template("a", &[Exercise::Squat]),
            template("b", &[Exercise::LegPress]),
        ];
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
        let mut legs = template("legs", &[Exercise::Squat, Exercise::RomanianDeadlift]);
        legs.in_rotation = false;
        let arms = template("arms", &[Exercise::BarbellCurl]);
        let got = suggest(&[legs.clone(), arms], &[], now, &HashMap::new()).unwrap();
        assert_eq!(got.template_id, "arms");
        assert!(suggest(&[legs], &[], now, &HashMap::new()).is_none());
    }
}
