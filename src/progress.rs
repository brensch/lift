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
/// the time breakdown covers every completed set (you spend time on warmups too).
pub fn compute_workout_summary(
    workout: &Workout,
    proposed_sets: &[ProposedSet],
    completed_sets: &[CompletedSet],
) -> WorkoutSummary {
    let proposed_by_id: HashMap<&str, &ProposedSet> = proposed_sets
        .iter()
        .map(|p| (p.id.as_str(), p))
        .collect();

    // Chronological completed sets that actually started, so rest can be capped
    // at when the next set began.
    let mut ordered: Vec<&CompletedSet> = completed_sets
        .iter()
        .filter(|c| c.ended_at != 0 && c.started_at != 0)
        .collect();
    ordered.sort_by_key(|c| c.started_at);

    let mut lifting_seconds: i64 = 0;
    let mut resting_seconds: i64 = 0;
    let mut total_volume: f32 = 0.0;
    let mut ex_index: HashMap<i32, usize> = HashMap::new();
    let mut exercises: Vec<ExerciseSummary> = Vec::new();

    for i in 0..ordered.len() {
        let c = ordered[i];
        let proposed = match proposed_by_id.get(c.proposed_set_id.as_str()) {
            Some(p) => *p,
            None => continue,
        };

        // Lifting time — every set.
        if c.ended_at > c.started_at {
            lifting_seconds += c.ended_at - c.started_at;
        }
        // Rest time — capped at the next set's start and at workout end.
        if c.rest_until > c.ended_at {
            let mut rest_end = c.rest_until;
            if i + 1 < ordered.len() && ordered[i + 1].started_at < rest_end {
                rest_end = ordered[i + 1].started_at;
            }
            if workout.end_time != 0 && workout.end_time < rest_end {
                rest_end = workout.end_time;
            }
            let secs = rest_end - c.ended_at;
            if secs > 0 {
                resting_seconds += secs;
            }
        }

        // Volume + per-exercise rollup — working sets only.
        if proposed.warmup {
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

    // Yapping = the gap between sets that isn't lifting or (prescribed) resting.
    let mut yapping_seconds: i64 = 0;
    for i in 0..ordered.len().saturating_sub(1) {
        let cur = ordered[i];
        let next = ordered[i + 1];
        let gap_start = if cur.rest_until > cur.ended_at {
            cur.rest_until
        } else {
            cur.ended_at
        };
        if next.started_at > gap_start {
            yapping_seconds += next.started_at - gap_start;
        }
    }

    let duration_seconds = if workout.end_time != 0 && workout.start_time != 0 {
        workout.end_time - workout.start_time
    } else {
        0
    };
    let lifting_minutes = (lifting_seconds / 60).max(1) as f32;
    let volume_per_minute = total_volume / lifting_minutes;
    let work_rest_ratio = if resting_seconds > 0 {
        lifting_seconds as f32 / resting_seconds as f32
    } else {
        lifting_seconds as f32
    };

    exercises.sort_by(|a, b| {
        b.total_volume
            .partial_cmp(&a.total_volume)
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    WorkoutSummary {
        total_volume,
        duration_seconds,
        lifting_seconds,
        resting_seconds,
        yapping_seconds,
        volume_per_minute,
        work_rest_ratio,
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
            if p.warmup {
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
    fn completed(
        pid: &str,
        reps: i32,
        weight: f32,
        started: i64,
        ended: i64,
        rest_until: i64,
    ) -> CompletedSet {
        CompletedSet {
            proposed_set_id: pid.to_string(),
            actual_reps: reps,
            actual_weight: weight,
            started_at: started,
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
        // warmup 1000..1030 (rest to 1060); work 1060..1090 (rest to 1150, next
        // starts 1150); work 1150..1180 (rest to 1240).
        let completed_sets = vec![
            completed("w", 5, 45.0, 1000, 1030, 1060),
            completed("a", 5, 100.0, 1060, 1090, 1150),
            completed("b", 5, 100.0, 1150, 1180, 1240),
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
        // Lifting time counts every set: 30 + 30 + 30 = 90.
        assert_eq!(s.lifting_seconds, 90);
        // Rest: warmup 30..60 = 30; set a 90..150 = 60; set b 180..240 but workout
        // ends at 300 so full 60. Total 150.
        assert_eq!(s.resting_seconds, 150);
        assert_eq!(s.duration_seconds, 300);
    }

    #[test]
    fn empty_workout_summary_is_zeroed() {
        let s = compute_workout_summary(&Workout::default(), &[], &[]);
        assert_eq!(s.total_volume, 0.0);
        assert!(s.exercises.is_empty());
        assert_eq!(s.lifting_seconds, 0);
    }
}

pub fn compute_next_up_set(
    proposed_sets: &[ProposedSet],
    completed_sets: &[CompletedSet],
) -> Option<ProposedSet> {
    // Find first proposed set that doesn't have a matching completed set
    proposed_sets
        .iter()
        .find(|p| {
            !completed_sets
                .iter()
                .any(|c| c.proposed_set_id == p.id && c.ended_at > 0)
        })
        .cloned()
}
