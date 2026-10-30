use schlift::workout::v1::{
    CompletedSet, ExerciseProgress, ExerciseProgressPoint, ExerciseSummary, ProposedSet, Workout,
    WorkoutSummary,
};
use std::collections::HashMap;

/// Epley estimated 1RM. The single source of truth — the app used to compute
/// this in three places.
fn estimate_one_rep_max(weight: f32, reps: i32) -> f32 {
    if weight <= 0.0 || reps <= 0 {
        return 0.0;
    }
    weight * (1.0 + reps as f32 / 30.0)
}

/// Roll a finished (or in-progress) workout up into the render-ready summary the
/// client displays. Volume and per-exercise stats cover **working sets only**;
/// lifting, resting and yapping time cover every done set (you rest after
/// warmups too).
pub fn compute_workout_summary(
    workout: &Workout,
    proposed_sets: &[ProposedSet],
    completed_sets: &[CompletedSet],
) -> WorkoutSummary {
    let proposed_by_id: HashMap<&str, &ProposedSet> =
        proposed_sets.iter().map(|p| (p.id.as_str(), p)).collect();

    // Chronological done sets, so rest can be capped at when the next set was
    // done.
    let mut ordered: Vec<&CompletedSet> =
        completed_sets.iter().filter(|c| c.ended_at != 0).collect();
    ordered.sort_by_key(|c| c.ended_at);

    let mut resting_seconds: i64 = 0;
    let mut yapping_seconds: i64 = 0;
    let mut lifting_seconds: i64 = 0;
    let mut total_volume: f32 = 0.0;
    let mut ex_index: HashMap<i32, usize> = HashMap::new();
    let mut exercises: Vec<ExerciseSummary> = Vec::new();

    for i in 0..ordered.len() {
        let c = ordered[i];
        let proposed = match proposed_by_id.get(c.proposed_set_id.as_str()) {
            Some(p) => *p,
            None => continue,
        };

        // When the next set began: its Start, or its Done if it was never
        // started. Rest and yapping both stop there, and at workout end.
        let cap = |t: i64| {
            if workout.end_time != 0 {
                t.min(workout.end_time)
            } else {
                t
            }
        };
        let next_start = ordered.get(i + 1).map(|next| {
            cap(if next.started_at > 0 {
                next.started_at
            } else {
                next.ended_at
            })
        });

        // Lifting — Start to Done, for a set that was started.
        if c.started_at > 0 && c.ended_at > c.started_at {
            lifting_seconds += c.ended_at - c.started_at;
        }

        // Resting — Done to the rest's end, cut short by the next set.
        let rest_end = cap(next_start.map_or(c.rest_until, |n| n.min(c.rest_until)));
        if rest_end > c.ended_at {
            resting_seconds += rest_end - c.ended_at;
        }

        // Yapping — once the rest has run out, until the next set began.
        // The last set has none.
        if let Some(next_start) = next_start {
            let yap_start = c.rest_until.max(c.ended_at);
            if next_start > yap_start {
                yapping_seconds += next_start - yap_start;
            }
        }

        // Volume + per-exercise rollup — working sets only (a calibration
        // rung is a warmup here).
        if proposed.warmup || proposed.calibration {
            continue;
        }
        let set_volume = c.actual_reps as f32 * c.actual_weight;
        if set_volume.is_finite() {
            total_volume += set_volume;
        }
        let idx = *ex_index.entry(proposed.exercise).or_insert_with(|| {
            exercises.push(ExerciseSummary {
                exercise: proposed.exercise,
                ..Default::default()
            });
            exercises.len() - 1
        });
        let e = &mut exercises[idx];
        e.total_sets += 1;
        e.total_reps += c.actual_reps;
        if set_volume.is_finite() {
            e.total_volume += set_volume;
        }
        if c.actual_weight > e.heaviest_set_weight {
            e.heaviest_set_weight = c.actual_weight;
        }
        let one_rm = estimate_one_rep_max(c.actual_weight, c.actual_reps);
        if one_rm > e.best_one_rep_max {
            e.best_one_rep_max = one_rm;
        }
    }

    let duration_seconds = if workout.end_time != 0 && workout.start_time != 0 {
        workout.end_time - workout.start_time
    } else {
        0
    };

    exercises.sort_by(|a, b| {
        b.total_volume
            .partial_cmp(&a.total_volume)
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    WorkoutSummary {
        total_volume,
        duration_seconds,
        resting_seconds,
        yapping_seconds,
        lifting_seconds,
        exercises,
    }
}

/// Per-exercise progress series built from every finished workout's working
/// sets. Points are oldest-first per exercise; exercises are ordered
/// most-improved first (by top-weight gain). One point per workout the exercise
/// appears in.
pub fn compute_exercise_progress(
    workouts: &[(Workout, Vec<ProposedSet>, Vec<CompletedSet>)],
) -> Vec<ExerciseProgress> {
    struct Acc {
        top_weight: f32,
        top_reps: i32,
        best_1rm: f32,
        volume: f32,
        sets: i32,
    }

    let mut index: HashMap<i32, usize> = HashMap::new();
    let mut series: Vec<ExerciseProgress> = Vec::new();

    let mut ordered: Vec<&(Workout, Vec<ProposedSet>, Vec<CompletedSet>)> =
        workouts.iter().collect();
    ordered.sort_by_key(|(w, _, _)| w.start_time);

    for (workout, proposed, completed) in ordered {
        let proposed_by_id: HashMap<&str, &ProposedSet> =
            proposed.iter().map(|p| (p.id.as_str(), p)).collect();

        let mut per_ex: HashMap<i32, Acc> = HashMap::new();
        for c in completed {
            if c.ended_at == 0 {
                continue;
            }
            let p = match proposed_by_id.get(c.proposed_set_id.as_str()) {
                Some(p) => *p,
                None => continue,
            };
            if p.warmup || p.calibration {
                continue;
            }
            let a = per_ex.entry(p.exercise).or_insert(Acc {
                top_weight: 0.0,
                top_reps: 0,
                best_1rm: 0.0,
                volume: 0.0,
                sets: 0,
            });
            a.sets += 1;
            a.volume += c.actual_reps as f32 * c.actual_weight;
            if c.actual_weight > a.top_weight {
                a.top_weight = c.actual_weight;
                a.top_reps = c.actual_reps;
            }
            let rm = estimate_one_rep_max(c.actual_weight, c.actual_reps);
            if rm > a.best_1rm {
                a.best_1rm = rm;
            }
        }

        for (ex, a) in per_ex {
            let idx = *index.entry(ex).or_insert_with(|| {
                series.push(ExerciseProgress {
                    exercise: ex,
                    points: Vec::new(),
                });
                series.len() - 1
            });
            series[idx].points.push(ExerciseProgressPoint {
                date: workout.start_time,
                workout_id: workout.id.clone(),
                top_weight: a.top_weight,
                top_reps: a.top_reps,
                best_one_rep_max: a.best_1rm,
                volume: a.volume,
                sets: a.sets,
            });
        }
    }

    series.sort_by(|a, b| {
        let gain = |s: &ExerciseProgress| match (s.points.first(), s.points.last()) {
            (Some(f), Some(l)) => l.top_weight - f.top_weight,
            _ => 0.0,
        };
        gain(b)
            .partial_cmp(&gain(a))
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    series
}

/// An exercise's undone warmup once it was skipped ("skip all warmups") or
/// one of the exercise's working sets (or rungs) is done: behind you. It
/// stays in the plan and can still be done; nothing waits on it.
pub fn is_passed_warmup(
    set: &ProposedSet,
    proposed_sets: &[ProposedSet],
    completed_sets: &[CompletedSet],
) -> bool {
    let done = |id: &str| {
        completed_sets
            .iter()
            .any(|c| c.proposed_set_id == id && c.ended_at > 0)
    };
    set.warmup
        && !done(&set.id)
        && (set.skipped
            || proposed_sets
                .iter()
                .any(|p| p.exercise == set.exercise && !p.warmup && done(&p.id)))
}

/// The set up next — the one source of truth for `next_up_set` and the
/// snapshot's `display_set` (multiplayer peers read it too). While the
/// latest done set is an unanswered calibration rung it is the first set
/// "right" would append (`{done_id}:0`), whatever else is pending, so nobody
/// jumps past their own working sets. Otherwise it is the first open set in
/// plan order: the order is the person's (they drag exercises into it), so
/// whatever is on top is what's next. Passed warmups are not open; with
/// nothing open the workout is done.
pub fn compute_next_up_set(
    proposed_sets: &[ProposedSet],
    completed_sets: &[CompletedSet],
) -> Option<ProposedSet> {
    if let Some(next) = crate::workout::awaiting_ramp_set(proposed_sets, completed_sets) {
        return Some(next);
    }
    proposed_sets
        .iter()
        .find(|p| {
            !completed_sets
                .iter()
                .any(|c| c.proposed_set_id == p.id && c.ended_at > 0)
                && !is_passed_warmup(p, proposed_sets, completed_sets)
        })
        .cloned()
}

#[cfg(test)]
mod summary_tests {
    use super::*;

    fn proposed(id: &str, ex: i32, warmup: bool) -> ProposedSet {
        ProposedSet {
            id: id.to_string(),
            exercise: ex,
            warmup,
            ..Default::default()
        }
    }
    fn completed(pid: &str, reps: i32, weight: f32, ended: i64, rest_until: i64) -> CompletedSet {
        CompletedSet {
            proposed_set_id: pid.to_string(),
            actual_reps: reps,
            actual_weight: weight,
            ended_at: ended,
            rest_until,
            ..Default::default()
        }
    }

    #[test]
    fn summary_excludes_warmups_from_volume_but_counts_their_time() {
        // Real timestamps (never 0 in practice). Base at t=1000.
        let workout = Workout {
            start_time: 1000,
            end_time: 1300,
            ..Default::default()
        };
        let proposed_sets = vec![
            proposed("w", 1, true),  // warmup: 45x5
            proposed("a", 1, false), // work: 100x5
            proposed("b", 1, false), // work: 100x5
        ];
        // warmup done at 1030 (rest to 1060); work done at 1090 (rest to 1150,
        // but the next set is done at 1130 so the rest is cut short); work done
        // at 1130 (rest to 1190).
        let completed_sets = vec![
            completed("w", 5, 45.0, 1030, 1060),
            completed("a", 5, 100.0, 1090, 1150),
            completed("b", 5, 100.0, 1130, 1190),
        ];
        let s = compute_workout_summary(&workout, &proposed_sets, &completed_sets);

        // Volume: working sets only -> 2 * (5*100) = 1000. Warmup excluded.
        assert_eq!(s.total_volume, 1000.0);
        // One exercise, 2 working sets, 10 reps.
        assert_eq!(s.exercises.len(), 1);
        assert_eq!(s.exercises[0].total_sets, 2);
        assert_eq!(s.exercises[0].total_reps, 10);
        // Epley best: 100*(1+5/30) = 116.666...
        assert!((s.exercises[0].best_one_rep_max - 116.6667).abs() < 0.01);
        assert_eq!(s.exercises[0].heaviest_set_weight, 100.0);
        // Rest counts every set, warmup included: warmup 1030..1060 = 30; set a
        // 1090..1150 but set b was done at 1130, so 40; set b 1130..1190 = 60.
        // Total 130.
        assert_eq!(s.resting_seconds, 130);
        // Yapping is what's left between sets once the rest has run out: the
        // warmup's rest ended at 1060 and set a was done at 1090, so 30; set
        // a was done before its rest ended; set b is the last set. Total 30.
        assert_eq!(s.yapping_seconds, 30);
        assert_eq!(s.duration_seconds, 300);
    }

    #[test]
    fn started_sets_split_into_lifting_resting_and_yapping() {
        // a: started 1000, done 1030, rest to 1090. b: started 1100, done
        // 1130, rest to 1190.
        let workout = Workout {
            start_time: 1000,
            end_time: 1300,
            ..Default::default()
        };
        let proposed_sets = vec![proposed("a", 1, false), proposed("b", 1, false)];
        let completed_sets = vec![
            CompletedSet {
                started_at: 1000,
                ..completed("a", 5, 100.0, 1030, 1090)
            },
            CompletedSet {
                started_at: 1100,
                ..completed("b", 5, 100.0, 1130, 1190)
            },
        ];
        let s = compute_workout_summary(&workout, &proposed_sets, &completed_sets);
        // Lifting: Start to Done, 30 + 30.
        assert_eq!(s.lifting_seconds, 60);
        // Resting: a 1030..1090, b 1130..1190.
        assert_eq!(s.resting_seconds, 120);
        // Yapping: a's rest ended at 1090 and b was *started* at 1100.
        assert_eq!(s.yapping_seconds, 10);
    }

    #[test]
    fn yapping_stops_at_workout_end() {
        // Rest ends at 1060; the next set's done time (1500) is after the
        // workout ended (1200), so yapping is 1060..1200 = 140.
        let workout = Workout {
            start_time: 1000,
            end_time: 1200,
            ..Default::default()
        };
        let proposed_sets = vec![proposed("a", 1, false), proposed("b", 1, false)];
        let completed_sets = vec![
            completed("a", 5, 100.0, 1030, 1060),
            completed("b", 5, 100.0, 1500, 1560),
        ];
        let s = compute_workout_summary(&workout, &proposed_sets, &completed_sets);
        assert_eq!(s.yapping_seconds, 140);
    }

    #[test]
    fn empty_workout_summary_is_zeroed() {
        let s = compute_workout_summary(&Workout::default(), &[], &[]);
        assert_eq!(s.total_volume, 0.0);
        assert!(s.exercises.is_empty());
        assert_eq!(s.resting_seconds, 0);
        assert_eq!(s.duration_seconds, 0);
    }

    #[test]
    fn rest_is_capped_at_workout_end() {
        // The final set's rest runs past end_time: only the part inside the
        // workout counts.
        let workout = Workout {
            start_time: 1000,
            end_time: 1200,
            ..Default::default()
        };
        let proposed_sets = vec![proposed("a", 1, false)];
        let completed_sets = vec![completed("a", 5, 100.0, 1180, 1300)];
        let s = compute_workout_summary(&workout, &proposed_sets, &completed_sets);
        assert_eq!(s.resting_seconds, 20);
    }
}
