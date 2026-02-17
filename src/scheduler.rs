use chrono::Utc;
use lift::workout::v1::{
    Exercise, ExerciseCategory, ExerciseStatus, ExerciseTypeConfig,
    GetProposedWorkoutScheduleResponse, MuscleGroup, ProposedExerciseGroup,
};

use crate::db::CentralDb;

/// Recovery time in hours for each muscle group
const RECOVERY_HOURS: i64 = 24;

// Weight increments per successful workout
const UPPER_BODY_INCREMENT: f32 = 5.0;
const LOWER_BODY_INCREMENT: f32 = 5.0;
const DEADLIFT_INCREMENT: f32 = 10.0;

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

fn get_exercise_config(exercise: Exercise) -> Option<&'static ExerciseConfig> {
    EXERCISE_CONFIGS.iter().find(|c| c.exercise == exercise)
}

pub struct Scheduler {
    central_db: CentralDb,
}

impl Scheduler {
    pub fn new(central_db: CentralDb) -> Self {
        Self { central_db }
    }

    /// Generate exercise statuses with weight progression and recovery info.
    /// Uses 2 total DB queries (bulk fetch all exercises at once).
    pub async fn get_proposed_schedule(
        &self,
        user_id: &str,
    ) -> Result<GetProposedWorkoutScheduleResponse, Box<dyn std::error::Error + Send + Sync>> {
        // 2 queries total: bulk history + bulk max weights for ALL exercises
        let (all_history, all_max_weights) = self
            .central_db
            .get_all_exercise_history(user_id, 10)
            .await?;

        // Build muscle group recovery map from the fetched data
        let mut muscle_group_last_worked: std::collections::HashMap<i32, i64> =
            std::collections::HashMap::new();
        for config in EXERCISE_CONFIGS {
            let exercise = config.exercise as i32;
            let last_performed = all_history
                .get(&exercise)
                .and_then(|h| h.first())
                .map(|(_, _, date)| *date)
                .unwrap_or(0);
            if last_performed > 0 {
                for mg in config.muscle_groups {
                    let entry = muscle_group_last_worked.entry(*mg as i32).or_insert(0);
                    if last_performed > *entry {
                        *entry = last_performed;
                    }
                }
            }
        }

        let now = Utc::now().timestamp();
        let recovery_seconds = RECOVERY_HOURS * 3600;

        let mut exercise_statuses = Vec::new();
        for config in EXERCISE_CONFIGS {
            let exercise = config.exercise as i32;
            let empty_history = Vec::new();
            let history = all_history.get(&exercise).unwrap_or(&empty_history);
            let max_weight = all_max_weights.get(&exercise).copied().unwrap_or(0.0);
            let (weight, explanation, last_perf, weight_history) = Self::calculate_weight_from_data(
                exercise,
                config.default_weight,
                history,
                max_weight,
            );

            let recovered = config.muscle_groups.iter().all(|mg| {
                match muscle_group_last_worked.get(&(*mg as i32)) {
                    None => true,
                    Some(&last) => (now - last) >= recovery_seconds,
                }
            });

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

        // Build proposed groups from exercise statuses
        let proposed_groups = Self::build_proposed_groups(&exercise_statuses);

        // active_workout_id is set by the service handler from in-memory state
        Ok(GetProposedWorkoutScheduleResponse {
            exercise_statuses,
            active_workout_id: String::new(),
            proposed_groups,
        })
    }

    /// Build proposed exercise groups with smart grouping.
    /// Solo groups for heavy compounds (Squat, Deadlift).
    /// Antagonist supersets: Bench+Row, OHP+accessory.
    fn build_proposed_groups(statuses: &[ExerciseStatus]) -> Vec<ProposedExerciseGroup> {
        let mut groups = Vec::new();

        let find_status = |ex: Exercise| -> Option<&ExerciseStatus> {
            statuses.iter().find(|s| s.exercise == ex as i32)
        };

        let make_config = |status: &ExerciseStatus| -> ExerciseTypeConfig {
            let config = get_exercise_config(
                Exercise::try_from(status.exercise).unwrap_or(Exercise::Unspecified),
            );
            ExerciseTypeConfig {
                exercise: status.exercise,
                start_weight: status.target_weight,
                end_weight: status.target_weight,
                reps: config.map(|c| c.default_reps).unwrap_or(5),
                include_warmup: true,
                rest_config: None,
            }
        };

        // Squat — solo
        if let Some(s) = find_status(Exercise::Squat) {
            groups.push(ProposedExerciseGroup {
                name: "Squat".to_string(),
                sets: s.default_sets,
                interleave_warmups: false,
                exercise_configs: vec![make_config(s)],
                rest_config: None,
            });
        }

        // Bench Press — solo
        if let Some(bench) = find_status(Exercise::BenchPress) {
            groups.push(ProposedExerciseGroup {
                name: "Bench Press".to_string(),
                sets: bench.default_sets,
                interleave_warmups: false,
                exercise_configs: vec![make_config(bench)],
                rest_config: None,
            });
        }

        // Barbell Row — solo
        if let Some(row) = find_status(Exercise::BarbellRow) {
            groups.push(ProposedExerciseGroup {
                name: "Barbell Row".to_string(),
                sets: row.default_sets,
                interleave_warmups: false,
                exercise_configs: vec![make_config(row)],
                rest_config: None,
            });
        }

        // Deadlift — solo
        if let Some(s) = find_status(Exercise::Deadlift) {
            groups.push(ProposedExerciseGroup {
                name: "Deadlift".to_string(),
                sets: s.default_sets,
                interleave_warmups: false,
                exercise_configs: vec![make_config(s)],
                rest_config: None,
            });
        }

        // OHP — solo
        if let Some(s) = find_status(Exercise::OverheadPress) {
            groups.push(ProposedExerciseGroup {
                name: "Overhead Press".to_string(),
                sets: s.default_sets,
                interleave_warmups: false,
                exercise_configs: vec![make_config(s)],
                rest_config: None,
            });
        }

        // Auxiliary exercises — group complementary pairs
        let aux_pairs: Vec<(Exercise, Exercise)> = vec![
            (Exercise::HipThrust, Exercise::BulgarianSplitSquat),
            (Exercise::RomanianDeadlift, Exercise::LegCurl),
            (Exercise::GluteBridge, Exercise::Lunge),
        ];

        for (ex_a, ex_b) in &aux_pairs {
            if let (Some(a), Some(b)) = (find_status(*ex_a), find_status(*ex_b)) {
                groups.push(ProposedExerciseGroup {
                    name: format!(
                        "{} + {}",
                        exercise_display_name(*ex_a),
                        exercise_display_name(*ex_b)
                    ),
                    sets: a.default_sets,
                    interleave_warmups: true,
                    exercise_configs: vec![make_config(a), make_config(b)],
                    rest_config: None,
                });
            } else {
                if let Some(a) = find_status(*ex_a) {
                    groups.push(ProposedExerciseGroup {
                        name: exercise_display_name(*ex_a),
                        sets: a.default_sets,
                        interleave_warmups: false,
                        exercise_configs: vec![make_config(a)],
                        rest_config: None,
                    });
                }
                if let Some(b) = find_status(*ex_b) {
                    groups.push(ProposedExerciseGroup {
                        name: exercise_display_name(*ex_b),
                        sets: b.default_sets,
                        interleave_warmups: false,
                        exercise_configs: vec![make_config(b)],
                        rest_config: None,
                    });
                }
            }
        }

        groups
    }

    /// Pure function: calculate weight from pre-fetched data (no DB calls).
    fn calculate_weight_from_data(
        exercise: i32,
        default: f32,
        history: &[(f32, bool, i64)],
        max_weight: f32,
    ) -> (f32, String, i64, Vec<f32>) {
        let weight_history: Vec<f32> = history.iter().rev().map(|(w, _, _)| *w).collect();

        if history.is_empty() {
            return (
                default,
                format!("Starting at {} lbs.", default),
                0,
                weight_history,
            );
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
            return (
                new_weight.max(default),
                format!(
                    "Decreasing from {} to {} lbs because of {} day break.",
                    last_weight, new_weight, days_since
                ),
                last_date,
                weight_history,
            );
        }

        // 2. Plateau Detection (3 consecutive failures at same weight)
        if history.len() >= 3 {
            let same_weight = history[0].0 == history[1].0 && history[1].0 == history[2].0;
            let all_failed = !history[0].1 && !history[1].1 && !history[2].1;
            if same_weight && all_failed {
                let new_weight = (last_weight * 0.9 / 5.0).round() * 5.0;
                return (
                    new_weight.max(default),
                    format!(
                        "Decreasing from {} to {} lbs to reset progression after plateau.",
                        last_weight, new_weight
                    ),
                    last_date,
                    weight_history,
                );
            }
        }

        // 3. Recent Failure (1 or 2 times)
        if !last_success {
            return (
                last_weight,
                format!(
                    "Maintaining at {} lbs to master form after last failure.",
                    last_weight
                ),
                last_date,
                weight_history,
            );
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
                return (
                    new_weight,
                    format!(
                        "Increasing from {} to {} lbs to reclaim previous max of {} lbs.",
                        last_weight, new_weight, max_weight
                    ),
                    last_date,
                    weight_history,
                );
            }
        }

        // 5. Standard Progression
        let new_weight = last_weight + increment;
        (
            new_weight,
            format!(
                "Increasing from {} to {} lbs after successful last session.",
                last_weight, new_weight
            ),
            last_date,
            weight_history,
        )
    }
}

fn exercise_display_name(exercise: Exercise) -> String {
    match exercise {
        Exercise::Squat => "Squat".to_string(),
        Exercise::BenchPress => "Bench Press".to_string(),
        Exercise::Deadlift => "Deadlift".to_string(),
        Exercise::OverheadPress => "Overhead Press".to_string(),
        Exercise::BarbellRow => "Barbell Row".to_string(),
        Exercise::HipThrust => "Hip Thrust".to_string(),
        Exercise::BulgarianSplitSquat => "Bulgarian Split Squat".to_string(),
        Exercise::RomanianDeadlift => "Romanian Deadlift".to_string(),
        Exercise::GluteBridge => "Glute Bridge".to_string(),
        Exercise::Lunge => "Lunge".to_string(),
        Exercise::LegCurl => "Leg Curl".to_string(),
        _ => "Unknown".to_string(),
    }
}
