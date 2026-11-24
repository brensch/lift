//! Per-muscle recovery from workout history: "are my legs ready?"
//!
//! One recovery window per muscle, the program's (`recovery.hours`), over
//! the same 10-muscle taxonomy everything else uses. For each muscle the most recent workout that
//! trained it sets `last_trained_at`, from when that workout started (so
//! a long session does not push its first lift's recovery back);
//! recovered at `last + window`.

use crate::history::WorkoutRecord;
use crate::program::{Muscle, Program};
use crate::progress::is_done;

const HOUR: i64 = 3600;

#[derive(Clone, Copy, Debug)]
pub struct MuscleRecovery {
    pub muscle: Muscle,
    /// Start time of the most recent workout that trained it (0 = never).
    pub last_trained_at: i64,
    /// `last_trained_at + window` (0 = never trained).
    pub recovered_at: i64,
}

impl MuscleRecovery {
    pub fn is_recovered(&self, now: i64) -> bool {
        self.last_trained_at == 0 || now >= self.recovered_at
    }
    /// Hours until recovered (0 if already).
    pub fn hours_remaining(&self, now: i64) -> i64 {
        self.recovered_at
            .saturating_sub(now)
            .saturating_add(HOUR - 1)
            .max(0)
            / HOUR
    }
}

/// Exercises the user actually completed a working set for in a workout.
fn trained_exercises(record: &WorkoutRecord) -> Vec<&str> {
    let mut out: Vec<&str> = Vec::new();
    for proposed in &record.proposed_sets {
        if proposed.warmup {
            continue;
        }
        if is_done(&proposed.id, &record.completed_sets)
            && !out.contains(&proposed.exercise.as_str())
        {
            out.push(&proposed.exercise);
        }
    }
    out
}

/// Recovery for all 10 muscles, from history, by the program's windows.
pub fn per_muscle_recovery(
    program: &Program,
    history: &[impl AsRef<WorkoutRecord>],
) -> Vec<MuscleRecovery> {
    let mut latest: std::collections::HashMap<Muscle, i64> = std::collections::HashMap::new();

    for record in history.iter().map(AsRef::as_ref) {
        let t = record.workout.start_time;
        if t <= 0 {
            continue;
        }
        for ex in trained_exercises(record) {
            for &muscle in program.muscles(ex) {
                let entry = latest.entry(muscle).or_insert(0);
                if t > *entry {
                    *entry = t;
                }
            }
        }
    }

    Muscle::ALL
        .iter()
        .map(|&muscle| {
            let last = latest.get(&muscle).copied().unwrap_or(0);
            if last == 0 {
                return MuscleRecovery {
                    muscle,
                    last_trained_at: 0,
                    recovered_at: 0,
                };
            }
            MuscleRecovery {
                muscle,
                last_trained_at: last,
                recovered_at: last.saturating_add(program.recovery_hours(muscle) * HOUR),
            }
        })
        .collect()
}

#[cfg(test)]
mod tests;
