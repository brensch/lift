//! Recovery- and cadence-aware readiness.
//!
//! Pure functions over workout history (no DB, no clock of their own — `now` is
//! always passed in), so the whole thing is unit-testable by mocking time and
//! synthetic completed workouts. Answers: which muscles are recovered, how often
//! the user actually trains, and whether — for the *next* workout — they should
//! train now, rest, or are overdue.
//!
//! The muscle map is a straight port of `app/lib/logic/exercises.dart`
//! (`BodyPart` + `ExerciseInfo.bodyParts`); `muscle_map_parity` pins them together.

use schlift::workout::v1::Exercise;

use crate::schplanner::SchplannerWorkoutRecord;

const HOUR: i64 = 3600;

#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum MuscleGroup {
    Chest,
    Back,
    Shoulders,
    Arms,
    Legs,
    Ass,
    Core,
}

impl MuscleGroup {
    pub const ALL: [MuscleGroup; 7] = [
        MuscleGroup::Chest,
        MuscleGroup::Back,
        MuscleGroup::Shoulders,
        MuscleGroup::Arms,
        MuscleGroup::Legs,
        MuscleGroup::Ass,
        MuscleGroup::Core,
    ];

    pub fn label(self) -> &'static str {
        match self {
            MuscleGroup::Chest => "Chest",
            MuscleGroup::Back => "Back",
            MuscleGroup::Shoulders => "Shoulders",
            MuscleGroup::Arms => "Arms",
            MuscleGroup::Legs => "Legs",
            MuscleGroup::Ass => "Ass",
            MuscleGroup::Core => "Core",
        }
    }

    /// Stable key for the proto (matches the Flutter BodyPart names, lower-case).
    pub fn key(self) -> &'static str {
        match self {
            MuscleGroup::Chest => "chest",
            MuscleGroup::Back => "back",
            MuscleGroup::Shoulders => "shoulders",
            MuscleGroup::Arms => "arms",
            MuscleGroup::Legs => "legs",
            MuscleGroup::Ass => "ass",
            MuscleGroup::Core => "core",
        }
    }

}

/// A regime's recovery model: how many hours each muscle group needs before the
/// program wants to train it again. First-class and regime-owned — the program
/// that prescribes the work decides how long recovery takes, so a program built
/// around squatting every session (Stronglifts) reports legs ready far sooner
/// than a once-a-week-per-lift program. Muscles absent from the map fall back to
/// `default_hours`.
#[derive(Clone, Debug)]
pub struct RecoveryProfile {
    per_muscle: std::collections::HashMap<MuscleGroup, i64>,
    default_hours: i64,
}

impl RecoveryProfile {
    /// Build from an explicit `(muscle, hours)` list plus a fallback.
    pub fn new(entries: &[(MuscleGroup, i64)], default_hours: i64) -> Self {
        RecoveryProfile {
            per_muscle: entries.iter().copied().collect(),
            default_hours,
        }
    }

    pub fn hours_for(&self, muscle: MuscleGroup) -> i64 {
        self.per_muscle
            .get(&muscle)
            .copied()
            .unwrap_or(self.default_hours)
    }
}

impl Default for RecoveryProfile {
    /// Frequency-friendly heuristic for regimes that don't specify their own:
    /// large muscles ~2 days, small muscles ~1.5, core ~1. No heavy-compound
    /// penalty — the old "+72h for any squat/deadlift" rule wrongly modelled a
    /// submaximal 5×5 squat like a max single and is gone.
    fn default() -> Self {
        use MuscleGroup::*;
        RecoveryProfile::new(
            &[
                (Legs, 48),
                (Back, 48),
                (Ass, 48),
                (Chest, 48),
                (Shoulders, 36),
                (Arms, 36),
                (Core, 24),
            ],
            48,
        )
    }
}

/// Muscle groups a move trains, primary mover first. Ported verbatim from
/// `exerciseCatalog` in `app/lib/logic/exercises.dart`.
pub fn muscle_groups(ex: Exercise) -> &'static [MuscleGroup] {
    use Exercise as E;
    use MuscleGroup::*;
    match ex {
        E::Squat => &[Legs, Ass],
        E::BenchPress => &[Chest],
        E::Deadlift => &[Back, Ass],
        E::OverheadPress => &[Shoulders],
        E::BarbellRow => &[Back],
        E::HipThrust => &[Ass, Legs],
        E::BulgarianSplitSquat => &[Legs, Ass],
        E::RomanianDeadlift => &[Ass, Legs],
        E::GluteBridge => &[Ass],
        E::Lunge => &[Legs, Ass],
        E::LegCurl => &[Legs],
        E::InclineBenchPress => &[Chest, Shoulders],
        E::DumbbellBenchPress => &[Chest],
        E::InclineDumbbellPress => &[Chest, Shoulders],
        E::DumbbellFly => &[Chest],
        E::CableFly => &[Chest],
        E::PushUp => &[Chest, Arms],
        E::ChestDip => &[Chest, Arms],
        E::MachineChestPress => &[Chest],
        E::PecDeck => &[Chest],
        E::PullUp => &[Back, Arms],
        E::ChinUp => &[Back, Arms],
        E::LatPulldown => &[Back],
        E::SeatedCableRow => &[Back],
        E::DumbbellRow => &[Back],
        E::TBarRow => &[Back],
        E::PendlayRow => &[Back],
        E::FacePull => &[Shoulders, Back],
        E::Shrug => &[Back, Shoulders],
        E::BackExtension => &[Back, Ass],
        E::DumbbellShoulderPress => &[Shoulders],
        E::ArnoldPress => &[Shoulders],
        E::LateralRaise => &[Shoulders],
        E::FrontRaise => &[Shoulders],
        E::RearDeltFly => &[Shoulders, Back],
        E::UprightRow => &[Shoulders, Back],
        E::BarbellCurl => &[Arms],
        E::DumbbellCurl => &[Arms],
        E::HammerCurl => &[Arms],
        E::PreacherCurl => &[Arms],
        E::ConcentrationCurl => &[Arms],
        E::CableCurl => &[Arms],
        E::TricepPushdown => &[Arms],
        E::OverheadTricepExtension => &[Arms],
        E::SkullCrusher => &[Arms],
        E::CloseGripBenchPress => &[Arms, Chest],
        E::TricepDip => &[Arms, Chest],
        E::TricepKickback => &[Arms],
        E::FrontSquat => &[Legs, Ass],
        E::LegPress => &[Legs, Ass],
        E::LegExtension => &[Legs],
        E::HackSquat => &[Legs, Ass],
        E::GobletSquat => &[Legs, Ass],
        E::WalkingLunge => &[Legs, Ass],
        E::StepUp => &[Legs, Ass],
        E::CalfRaise => &[Legs],
        E::SeatedCalfRaise => &[Legs],
        E::NordicCurl => &[Legs],
        E::GoodMorning => &[Ass, Back],
        E::GluteKickback => &[Ass],
        E::SumoDeadlift => &[Ass, Back],
        E::SumoSquat => &[Ass, Legs],
        E::CurtsyLunge => &[Ass, Legs],
        E::FrogPump => &[Ass],
        E::SingleLegHipThrust => &[Ass, Legs],
        E::CablePullThrough => &[Ass, Back],
        E::HipAbduction => &[Ass],
        E::HipAdduction => &[Legs],
        E::Plank => &[Core],
        E::HangingLegRaise => &[Core],
        E::CableCrunch => &[Core],
        E::RussianTwist => &[Core],
        E::AbWheelRollout => &[Core],
        E::SitUp => &[Core],
        E::Crunch => &[Core],
        E::MountainClimber => &[Core, Legs],
        E::Unspecified => &[],
    }
}

#[derive(Clone, Copy, Debug)]
pub struct MuscleRecovery {
    pub group: MuscleGroup,
    /// End time of the most recent workout that trained this muscle (0 = never).
    pub last_trained_at: i64,
    /// When it's considered recovered (`last_trained_at + window`; 0 = never trained).
    pub recovered_at: i64,
    /// 0.0 (just trained) → 1.0 (fully recovered); 1.0 if never trained.
    pub fraction: f32,
}

impl MuscleRecovery {
    pub fn is_recovered(&self, now: i64) -> bool {
        self.last_trained_at == 0 || now >= self.recovered_at
    }
    /// Hours until recovered (0 if already).
    pub fn hours_remaining(&self, now: i64) -> i64 {
        ((self.recovered_at - now) + HOUR - 1).max(0) / HOUR
    }
}

/// The end time of a workout for recovery purposes: prefer `end_time`, fall back
/// to `start_time`.
fn workout_time(rec: &SchplannerWorkoutRecord) -> i64 {
    if rec.workout.end_time > 0 {
        rec.workout.end_time
    } else {
        rec.workout.start_time
    }
}

/// Exercises the user actually completed a working set for in a workout.
fn trained_exercises(rec: &SchplannerWorkoutRecord) -> Vec<Exercise> {
    let mut out = Vec::new();
    for proposed in &rec.proposed_sets {
        if proposed.warmup {
            continue;
        }
        let done = rec
            .completed_sets
            .iter()
            .any(|c| c.proposed_set_id == proposed.id && c.ended_at != 0);
        if done {
            let ex = Exercise::try_from(proposed.exercise).unwrap_or(Exercise::Unspecified);
            if !out.contains(&ex) {
                out.push(ex);
            }
        }
    }
    out
}

/// Per-muscle recovery from history, using the active regime's `profile` for the
/// window. For each group the most recent workout that trained it sets
/// `last_trained_at`; `recovered_at = last + profile.hours_for(group)`.
pub fn per_muscle_recovery(
    history: &[SchplannerWorkoutRecord],
    now: i64,
    profile: &RecoveryProfile,
) -> Vec<MuscleRecovery> {
    // group -> last_trained_at
    let mut latest: std::collections::HashMap<MuscleGroup, i64> =
        std::collections::HashMap::new();

    for rec in history {
        let t = workout_time(rec);
        if t <= 0 {
            continue;
        }
        for ex in trained_exercises(rec) {
            for &m in muscle_groups(ex) {
                let entry = latest.entry(m).or_insert(0);
                if t > *entry {
                    *entry = t;
                }
            }
        }
    }

    MuscleGroup::ALL
        .iter()
        .map(|&group| {
            let last = latest.get(&group).copied().unwrap_or(0);
            if last == 0 {
                return MuscleRecovery {
                    group,
                    last_trained_at: 0,
                    recovered_at: 0,
                    fraction: 1.0,
                };
            }
            let window = profile.hours_for(group) * HOUR;
            let recovered_at = last + window;
            let elapsed = (now - last).max(0) as f32;
            let fraction = (elapsed / window as f32).clamp(0.0, 1.0);
            MuscleRecovery {
                group,
                last_trained_at: last,
                recovered_at,
                fraction,
            }
        })
        .collect()
}

#[derive(Clone, Copy, Debug, Default)]
pub struct Cadence {
    /// Mean hours between consecutive sessions (None with < 2 sessions).
    pub avg_gap_hours: Option<i64>,
    pub sessions_last_7d: i32,
}

/// Learn the user's actual training rhythm from history.
pub fn cadence(history: &[SchplannerWorkoutRecord], now: i64) -> Cadence {
    let mut times: Vec<i64> = history
        .iter()
        .map(workout_time)
        .filter(|&t| t > 0)
        .collect();
    times.sort_unstable();
    times.dedup();

    let avg_gap_hours = if times.len() >= 2 {
        let total: i64 = times.windows(2).map(|w| w[1] - w[0]).sum();
        Some(total / (times.len() as i64 - 1) / HOUR)
    } else {
        None
    };
    let week_ago = now - 7 * 24 * HOUR;
    let sessions_last_7d = times.iter().filter(|&&t| t >= week_ago).count() as i32;

    Cadence {
        avg_gap_hours,
        sessions_last_7d,
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ReadinessState {
    /// Never trained — nothing to recover from.
    FirstTime,
    /// The next workout's muscles are recovered (and min rest elapsed). Train.
    Ready,
    /// Not yet — some of the next workout's muscles are still recovering.
    Recovering,
    /// Long past ready and behind the weekly target — a gentle nudge.
    Overdue,
    /// Recovered, but already met the weekly target — training is a bonus.
    Ahead,
}

#[derive(Clone, Debug)]
pub struct Readiness {
    pub state: ReadinessState,
    /// When the next workout's muscles are recovered (floored by min rest).
    pub next_ready_at: i64,
    /// Muscles of the next workout still recovering (drives "legs need Xh").
    pub blocking: Vec<MuscleGroup>,
}

/// Decide train / rest / overdue for the *next* workout.
///
/// - `next_workout_muscles`: the groups the proposed next session will hit.
/// - `min_rest_hours`: the program's floor between any two sessions.
/// - `weekly_target`: prescribed sessions per week (for the ahead/overdue read).
#[allow(clippy::too_many_arguments)]
pub fn compute_readiness(
    next_workout_muscles: &[MuscleGroup],
    recovery: &[MuscleRecovery],
    cadence: &Cadence,
    last_session_at: i64,
    min_rest_hours: i64,
    weekly_target: i32,
    now: i64,
) -> Readiness {
    if last_session_at <= 0 {
        return Readiness {
            state: ReadinessState::FirstTime,
            next_ready_at: now,
            blocking: Vec::new(),
        };
    }

    let find = |m: MuscleGroup| recovery.iter().find(|r| r.group == m).copied();

    // Ready when every targeted muscle is recovered, and at least min-rest has
    // passed since the last session.
    let muscles_ready_at = next_workout_muscles
        .iter()
        .filter_map(|&m| find(m).map(|r| r.recovered_at))
        .max()
        .unwrap_or(0);
    let min_rest_floor = last_session_at + min_rest_hours * HOUR;
    let next_ready_at = muscles_ready_at.max(min_rest_floor);

    let blocking: Vec<MuscleGroup> = next_workout_muscles
        .iter()
        .copied()
        .filter(|&m| find(m).map(|r| !r.is_recovered(now)).unwrap_or(false))
        .collect();

    let state = if now < next_ready_at {
        ReadinessState::Recovering
    } else {
        // Recovered. Decide ready vs ahead vs overdue.
        let idle_hours = (now - last_session_at) / HOUR;
        // Expected gap: the user's own rhythm, else the min rest, else 48h.
        let expected_gap = cadence
            .avg_gap_hours
            .filter(|&g| g > 0)
            .unwrap_or(min_rest_hours.max(48));
        let overdue_after = (expected_gap * 2).max(96); // never nag before ~4 days
        let behind_target = weekly_target > 0 && cadence.sessions_last_7d < weekly_target;

        if idle_hours >= overdue_after && behind_target {
            ReadinessState::Overdue
        } else if weekly_target > 0 && cadence.sessions_last_7d >= weekly_target {
            ReadinessState::Ahead
        } else {
            ReadinessState::Ready
        }
    };

    Readiness {
        state,
        next_ready_at,
        blocking,
    }
}

/// The muscle groups a set of proposed exercises will train (deduped, order-stable).
pub fn muscles_for_exercises(exercises: &[Exercise]) -> Vec<MuscleGroup> {
    let mut out: Vec<MuscleGroup> = Vec::new();
    for &ex in exercises {
        for &m in muscle_groups(ex) {
            if !out.contains(&m) {
                out.push(m);
            }
        }
    }
    out
}

#[cfg(test)]
mod tests;
