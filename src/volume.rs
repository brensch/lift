//! Weekly volume per muscle, and the template suggestion built on it.
//!
//! Volume is the clearest dose-response lever in hypertrophy training, so
//! the app makes it visible: weighted hard sets per muscle over a rolling
//! 7 days, against a 10–20 band. A completed working set counts 1.0 for
//! the exercise's primary muscle and 0.5 for each secondary; warmups and
//! cancelled sets count 0.
//!
//! The suggestion is a pure sort over the user's own templates by muscle
//! deficit — computed fresh every request, never stored. If it ever needs
//! to remember something between sessions, it has gone wrong.

use std::collections::HashMap;

use crate::exercise_catalog::{muscle_label, muscles, primary_muscle, ALL_MUSCLES};
use crate::history::WorkoutRecord;
use schlift::workout::v1::{Exercise, MuscleGroup, MuscleVolume, WorkoutTemplate};

pub const VOLUME_WINDOW_SECONDS: i64 = 7 * 24 * 3600;
pub const VOLUME_TARGET_LOW: i32 = 10;
pub const VOLUME_TARGET_HIGH: i32 = 20;
const SECONDARY_WEIGHT: f32 = 0.5;

/// Weighted hard sets per muscle in the last 7 days. Counts completed,
/// non-warmup, non-cancelled sets from every workout in the window — the
/// in-progress one included, so the display moves while you train.
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
            if proposed.warmup || proposed.cancelled {
                continue;
            }
            let Ok(ex) = Exercise::try_from(proposed.exercise) else {
                continue;
            };
            for (idx, muscle) in muscles(ex).iter().enumerate() {
                let credit = if idx == 0 { 1.0 } else { SECONDARY_WEIGHT };
                *sets.entry(*muscle).or_insert(0.0) += credit;
            }
        }
    }

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

/// Pick the template whose primary muscles are furthest below the band.
///
/// score = Σ over the template's distinct primary muscles of
///         max(0, target_low − sets_7d)
///
/// Ties break toward the template least recently started (never started
/// sorts first). Returns the winner's id and a human reason naming the
/// two most-behind muscles. None when there are no templates or nothing
/// is behind (then nothing is marked — there is no debt to pay down).
pub fn suggest_template(
    templates: &[WorkoutTemplate],
    volume: &[MuscleVolume],
    last_started: &HashMap<String, i64>,
) -> Option<(String, String)> {
    let deficit: HashMap<i32, f32> = volume
        .iter()
        .map(|v| {
            (
                v.muscle,
                (v.target_low as f32 - v.completed_sets_7d).max(0.0),
            )
        })
        .collect();

    struct Candidate<'a> {
        score: f32,
        started: i64,
        template: &'a WorkoutTemplate,
        hit: Vec<(i32, f32)>,
    }
    let mut best: Option<Candidate> = None;
    for template in templates {
        // Distinct primary muscles, counted once each.
        let mut seen = Vec::new();
        let mut hit: Vec<(i32, f32)> = Vec::new();
        for exercise in &template.exercises {
            let Ok(ex) = Exercise::try_from(*exercise) else {
                continue;
            };
            let muscle = primary_muscle(ex) as i32;
            if seen.contains(&muscle) {
                continue;
            }
            seen.push(muscle);
            let d = deficit.get(&muscle).copied().unwrap_or(0.0);
            if d > 0.0 {
                hit.push((muscle, d));
            }
        }
        let score: f32 = hit.iter().map(|(_, d)| d).sum();
        let started = last_started.get(&template.id).copied().unwrap_or(0);
        let better = match &best {
            None => true,
            Some(candidate) => {
                score > candidate.score
                    || (score == candidate.score && started < candidate.started)
            }
        };
        if better {
            best = Some(Candidate {
                score,
                started,
                template,
                hit,
            });
        }
    }

    let Candidate {
        score,
        template,
        mut hit,
        ..
    } = best?;
    if score <= 0.0 {
        return None;
    }
    hit.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));
    let names: Vec<&str> = hit
        .iter()
        .take(2)
        .filter_map(|(muscle, _)| {
            MuscleGroup::try_from(*muscle)
                .ok()
                .map(muscle_label)
        })
        .collect();
    let behind: f32 = hit.iter().take(2).map(|(_, d)| d).sum();
    let reason = match names.as_slice() {
        [a] => format!("{a} is {behind:.0} sets behind this week"),
        [a, b] => format!("{a} and {b} are {behind:.0} sets behind this week"),
        _ => String::new(),
    };
    Some((template.id.clone(), reason))
}

#[cfg(test)]
mod tests {
    use super::*;
    use schlift::workout::v1::{CompletedSet, ProposedSet, Workout};

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
                started_at: at - 30,
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
            exercise_groups: Vec::new(),
            proposed_sets: proposed,
            completed_sets: completed,
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
            record_with_sets(now - 3600, &[(Exercise::Squat, true), (Exercise::Squat, false)]),
            record_with_sets(now - VOLUME_WINDOW_SECONDS - 100, &[(Exercise::Squat, false)]),
        ];
        let volume = muscle_volume_7d(&history, now);
        assert_eq!(volume_for(&volume, MuscleGroup::Quads), 1.0);
    }

    fn template(id: &str, exercises: &[Exercise]) -> WorkoutTemplate {
        WorkoutTemplate {
            id: id.to_string(),
            name: id.to_string(),
            exercises: exercises.iter().map(|e| *e as i32).collect(),
            ..Default::default()
        }
    }

    /// The template covering the most-behind muscles wins, and the reason
    /// names them.
    #[test]
    fn suggestion_picks_the_biggest_deficit() {
        let now = 1_000_000;
        // Ten quad sets this week, nothing else: legs are covered, pull is not.
        let history = vec![record_with_sets(
            now - 3600,
            &[(Exercise::LegExtension, false); 10],
        )];
        let volume = muscle_volume_7d(&history, now);
        let templates = vec![
            template("legs", &[Exercise::Squat, Exercise::LegExtension]),
            template("pull", &[Exercise::BarbellRow, Exercise::BarbellCurl]),
        ];
        let (id, reason) =
            suggest_template(&templates, &volume, &HashMap::new()).expect("a suggestion");
        assert_eq!(id, "pull");
        assert!(reason.contains("Back"), "{reason}");
    }

    /// Equal scores: the least recently started template wins.
    #[test]
    fn ties_break_toward_least_recent() {
        let volume = muscle_volume_7d(&[], 1_000_000);
        let templates = vec![
            template("a", &[Exercise::Squat]),
            template("b", &[Exercise::Squat]),
        ];
        let mut last = HashMap::new();
        last.insert("a".to_string(), 500i64);
        let (id, _) = suggest_template(&templates, &volume, &last).expect("a suggestion");
        assert_eq!(id, "b", "never-started beats recently-started");
    }

    #[test]
    fn no_deficit_means_no_suggestion() {
        let now = 1_000_000;
        let history = vec![record_with_sets(
            now - 3600,
            &[(Exercise::Squat, false); 12],
        )];
        let volume = muscle_volume_7d(&history, now);
        let templates = vec![template("legs", &[Exercise::Squat])];
        assert!(suggest_template(&templates, &volume, &HashMap::new()).is_none());
    }
}
