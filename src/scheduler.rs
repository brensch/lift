use chrono::Utc;
use lift::workout::v1::{
    Exercise, ExerciseCategory, ExerciseStatus, GetProposedWorkoutScheduleResponse, MuscleGroup,
    ProposedSet,
};

use crate::db::UserDb;

/// Plate-friendly warmup stops (bar + combinations of 45/25 plates per side).
/// Must match PLATE_STOPS in web/src/lib/warmup.ts.
#[allow(dead_code)]
const PLATE_STOPS: &[f32] = &[
    45.0, 95.0, 135.0, 185.0, 225.0, 275.0, 315.0, 365.0, 405.0, 455.0, 495.0, 545.0, 585.0,
    635.0,
];

#[allow(dead_code)]
const REP_SCHEMES: &[&[i32]] = &[
    &[5],          // 1 warmup
    &[5, 5],       // 2 warmups
    &[5, 5, 3],    // 3 warmups
    &[5, 5, 3, 2], // 4 warmups
];

/// Generate progressive warmup sets for a given exercise and working weight.
#[allow(dead_code)]
fn generate_warmup_sets(exercise: i32, working_weight: f32, order: &mut i32) -> Vec<ProposedSet> {
    if working_weight <= 45.0 {
        return Vec::new();
    }

    let candidates: Vec<f32> = PLATE_STOPS
        .iter()
        .copied()
        .filter(|&w| w < working_weight)
        .collect();
    if candidates.is_empty() {
        return Vec::new();
    }

    let selected: Vec<f32> = if candidates.len() <= 4 {
        candidates
    } else {
        let n = candidates.len();
        let step = (n - 1) as f64 / 3.0;
        vec![
            candidates[0],
            candidates[step.round() as usize],
            candidates[(step * 2.0).round() as usize],
            candidates[n - 1],
        ]
    };

    let reps = REP_SCHEMES[selected.len() - 1];

    selected
        .iter()
        .enumerate()
        .map(|(i, &weight)| {
            let set = ProposedSet {
                id: String::new(),
                workout_id: String::new(),
                workout_order: *order,
                exercise,
                target_reps: reps[i],
                target_weight: weight,
                warmup: true,
                exercise_group_id: String::new(),
            };
            *order += 1;
            set
        })
        .collect()
}

/// Create warmup + working sets for an exercise.
#[allow(dead_code)]
fn create_exercise_sets(
    exercise: i32,
    weight: f32,
    set_count: usize,
    reps: i32,
    order: &mut i32,
) -> Vec<ProposedSet> {
    let mut sets = generate_warmup_sets(exercise, weight, order);
    for _ in 0..set_count {
        sets.push(ProposedSet {
            id: String::new(),
            workout_id: String::new(),
            workout_order: *order,
            exercise,
            target_reps: reps,
            target_weight: weight,
            warmup: false,
            exercise_group_id: String::new(),
        });
        *order += 1;
    }
    sets
}

// Weight increments per successful workout
const UPPER_BODY_INCREMENT: f32 = 5.0;
const LOWER_BODY_INCREMENT: f32 = 5.0;
const DEADLIFT_INCREMENT: f32 = 10.0;

/// Recovery time in hours for each muscle group
const RECOVERY_HOURS: i64 = 24;

struct ExerciseConfig {
    exercise: Exercise,
    default_weight: f32,
    muscle_groups: &'static [MuscleGroup],
    default_sets: i32,
    default_reps: i32,
    category: ExerciseCategory,
    always_include: bool,
}

const EXERCISE_CONFIGS: &[ExerciseConfig] = &[
    // Compound exercises
    ExerciseConfig {
        exercise: Exercise::Squat,
        default_weight: 45.0,
        muscle_groups: &[MuscleGroup::Quads, MuscleGroup::Glutes],
        default_sets: 5,
        default_reps: 5,
        category: ExerciseCategory::Compound,
        always_include: true,
    },
    ExerciseConfig {
        exercise: Exercise::BenchPress,
        default_weight: 45.0,
        muscle_groups: &[
            MuscleGroup::Chest,
            MuscleGroup::Triceps,
            MuscleGroup::Shoulders,
        ],
        default_sets: 5,
        default_reps: 5,
        category: ExerciseCategory::Compound,
        always_include: false,
    },
    ExerciseConfig {
        exercise: Exercise::Deadlift,
        default_weight: 135.0,
        muscle_groups: &[
            MuscleGroup::Back,
            MuscleGroup::Hamstrings,
            MuscleGroup::Glutes,
        ],
        default_sets: 1,
        default_reps: 5,
        category: ExerciseCategory::Compound,
        always_include: false,
    },
    ExerciseConfig {
        exercise: Exercise::OverheadPress,
        default_weight: 45.0,
        muscle_groups: &[MuscleGroup::Shoulders, MuscleGroup::Triceps],
        default_sets: 5,
        default_reps: 5,
        category: ExerciseCategory::Compound,
        always_include: false,
    },
    ExerciseConfig {
        exercise: Exercise::BarbellRow,
        default_weight: 65.0,
        muscle_groups: &[MuscleGroup::Back, MuscleGroup::Biceps],
        default_sets: 5,
        default_reps: 5,
        category: ExerciseCategory::Compound,
        always_include: false,
    },
    // Auxiliary exercises
    ExerciseConfig {
        exercise: Exercise::HipThrust,
        default_weight: 45.0,
        muscle_groups: &[MuscleGroup::Glutes, MuscleGroup::Hamstrings],
        default_sets: 5,
        default_reps: 5,
        category: ExerciseCategory::Auxiliary,
        always_include: false,
    },
    ExerciseConfig {
        exercise: Exercise::BulgarianSplitSquat,
        default_weight: 45.0,
        muscle_groups: &[MuscleGroup::Quads, MuscleGroup::Glutes],
        default_sets: 5,
        default_reps: 5,
        category: ExerciseCategory::Auxiliary,
        always_include: false,
    },
    ExerciseConfig {
        exercise: Exercise::RomanianDeadlift,
        default_weight: 45.0,
        muscle_groups: &[
            MuscleGroup::Hamstrings,
            MuscleGroup::Glutes,
            MuscleGroup::Back,
        ],
        default_sets: 5,
        default_reps: 5,
        category: ExerciseCategory::Auxiliary,
        always_include: false,
    },
    ExerciseConfig {
        exercise: Exercise::GluteBridge,
        default_weight: 45.0,
        muscle_groups: &[MuscleGroup::Glutes],
        default_sets: 5,
        default_reps: 5,
        category: ExerciseCategory::Auxiliary,
        always_include: false,
    },
    ExerciseConfig {
        exercise: Exercise::Lunge,
        default_weight: 45.0,
        muscle_groups: &[MuscleGroup::Quads, MuscleGroup::Glutes],
        default_sets: 5,
        default_reps: 5,
        category: ExerciseCategory::Auxiliary,
        always_include: false,
    },
    ExerciseConfig {
        exercise: Exercise::LegCurl,
        default_weight: 45.0,
        muscle_groups: &[MuscleGroup::Hamstrings],
        default_sets: 5,
        default_reps: 5,
        category: ExerciseCategory::Auxiliary,
        always_include: false,
    },
];

pub struct Scheduler {
    user_db: UserDb,
}

impl Scheduler {
    pub fn new(user_db: UserDb) -> Self {
        Self { user_db }
    }

    /// Generate exercise statuses with weight progression and recovery info
    pub async fn get_proposed_schedule(
        &self,
    ) -> Result<GetProposedWorkoutScheduleResponse, Box<dyn std::error::Error + Send + Sync>> {
        // Collect last_performed_at for ALL exercises first (needed for muscle group recovery)
        let mut exercise_last_performed: Vec<(Exercise, i64)> = Vec::new();
        for config in EXERCISE_CONFIGS {
            let history = self
                .user_db
                .get_exercise_history(config.exercise as i32, 1)
                .await?;
            let last_performed = history.first().map(|(_, _, date)| *date).unwrap_or(0);
            exercise_last_performed.push((config.exercise, last_performed));
        }

        // Build a map of muscle group -> most recent time it was worked
        let mut muscle_group_last_worked: std::collections::HashMap<i32, i64> =
            std::collections::HashMap::new();
        for (i, config) in EXERCISE_CONFIGS.iter().enumerate() {
            let last_performed = exercise_last_performed[i].1;
            if last_performed > 0 {
                for mg in config.muscle_groups {
                    let entry = muscle_group_last_worked
                        .entry(*mg as i32)
                        .or_insert(0);
                    if last_performed > *entry {
                        *entry = last_performed;
                    }
                }
            }
        }

        let now = Utc::now().timestamp();
        let recovery_seconds = RECOVERY_HOURS * 3600;

        let mut exercise_statuses = Vec::new();
        for (i, config) in EXERCISE_CONFIGS.iter().enumerate() {
            let (weight, explanation, last_perf, weight_history) = self
                .calculate_sophisticated_weight(config.exercise as i32, config.default_weight)
                .await?;

            // Check if ALL muscle groups for this exercise have recovered
            let recovered = config.muscle_groups.iter().all(|mg| {
                match muscle_group_last_worked.get(&(*mg as i32)) {
                    None => true, // never worked = recovered
                    Some(&last) => (now - last) >= recovery_seconds,
                }
            });

            let _ = i; // suppress unused warning

            exercise_statuses.push(ExerciseStatus {
                exercise: config.exercise as i32,
                target_weight: weight,
                explanation,
                last_performed_at: last_perf,
                weight_history,
                muscle_groups: config.muscle_groups.iter().map(|mg| *mg as i32).collect(),
                default_sets: config.default_sets,
                default_reps: config.default_reps,
                recovered,
                always_include: config.always_include,
                category: config.category as i32,
            });
        }

        let active_workout = self.user_db.get_active_workout().await?;
        let active_workout_id = active_workout.map(|w| w.id).unwrap_or_default();

        Ok(GetProposedWorkoutScheduleResponse {
            exercise_statuses,
            active_workout_id,
        })
    }

    async fn calculate_sophisticated_weight(
        &self,
        exercise: i32,
        default: f32,
    ) -> Result<(f32, String, i64, Vec<f32>), Box<dyn std::error::Error + Send + Sync>> {
        let history = self.user_db.get_exercise_history(exercise, 10).await?;
        let max_weight = self
            .user_db
            .get_all_time_max_weight_for_exercise(exercise)
            .await?;
        let weight_history: Vec<f32> = history.iter().rev().map(|(w, _, _)| *w).collect();

        if history.is_empty() {
            return Ok((
                default,
                format!("Starting at {} lbs.", default),
                0,
                weight_history,
            ));
        }

        let (last_weight, last_success, last_date) = history[0];
        let now = Utc::now().timestamp();
        let days_since = (now - last_date) / (24 * 3600);

        let increment = if exercise == Exercise::Deadlift as i32 {
            DEADLIFT_INCREMENT
        } else if exercise == Exercise::Squat as i32 {
            LOWER_BODY_INCREMENT
        } else {
            UPPER_BODY_INCREMENT
        };

        // 1. Long Break Deload
        if days_since > 14 {
            let deload_pct = if days_since > 30 { 0.8 } else { 0.9 };
            let new_weight = (last_weight * deload_pct / 5.0).round() * 5.0;
            return Ok((
                new_weight.max(default),
                format!(
                    "Decreasing from {} to {} lbs because of {} day break.",
                    last_weight, new_weight, days_since
                ),
                last_date,
                weight_history,
            ));
        }

        // 2. Plateau Detection (3 consecutive failures at same weight)
        if history.len() >= 3 {
            let same_weight = history[0].0 == history[1].0 && history[1].0 == history[2].0;
            let all_failed = !history[0].1 && !history[1].1 && !history[2].1;
            if same_weight && all_failed {
                let new_weight = (last_weight * 0.9 / 5.0).round() * 5.0;
                return Ok((
                    new_weight.max(default),
                    format!(
                        "Decreasing from {} to {} lbs to reset progression after plateau.",
                        last_weight, new_weight
                    ),
                    last_date,
                    weight_history,
                ));
            }
        }

        // 3. Recent Failure (1 or 2 times)
        if !last_success {
            return Ok((
                last_weight,
                format!(
                    "Maintaining at {} lbs to master form after last failure.",
                    last_weight
                ),
                last_date,
                weight_history,
            ));
        }

        // 4. Return to Weight Mode
        if max_weight > last_weight + increment {
            let successes_since_deload = history
                .iter()
                .take_while(|(_, success, _)| *success)
                .count();
            if successes_since_deload >= 2 {
                let fast_increment = increment * 2.0;
                let new_weight = last_weight + fast_increment;
                return Ok((
                    new_weight,
                    format!(
                        "Increasing from {} to {} lbs to reclaim previous max of {} lbs.",
                        last_weight, new_weight, max_weight
                    ),
                    last_date,
                    weight_history,
                ));
            }
        }

        // 5. Standard Progression
        let new_weight = last_weight + increment;
        Ok((
            new_weight,
            format!(
                "Increasing from {} to {} lbs after successful last session.",
                last_weight, new_weight
            ),
            last_date,
            weight_history,
        ))
    }
}
