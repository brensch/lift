use chrono::{Datelike, Duration, NaiveDate, Utc, Weekday};
use lift::workout::v1::{Exercise, ProposedSet, ProposedWorkout};

use crate::db::UserDb;

/// StrongLifts 5x5 Program
///
/// Workout A: Squat, Bench Press, Barbell Row (5x5 each)
/// Workout B: Squat, Overhead Press, Deadlift (5x5 Squat/OHP, 1x5 Deadlift)
///
/// Alternates A-B-A, B-A-B each week
/// Training days: Monday, Wednesday, Friday

/// Snap a weight to the nearest 5 lbs, minimum 45 (empty bar).
fn snap_weight(w: f32) -> f32 {
    let snapped = (w / 5.0).round() * 5.0;
    if snapped < 45.0 { 45.0 } else { snapped }
}

/// Generate progressive warmup sets for a given exercise and working weight.
fn generate_warmup_sets(exercise: i32, working_weight: f32, order: &mut i32) -> Vec<ProposedSet> {
    if working_weight <= 45.0 {
        return Vec::new();
    }

    let defs: Vec<(f32, i32)> = if working_weight <= 95.0 {
        vec![(45.0, 5)]
    } else if working_weight <= 135.0 {
        vec![(45.0, 5), (snap_weight(working_weight * 0.5), 5)]
    } else if working_weight <= 225.0 {
        vec![
            (45.0, 5),
            (snap_weight(working_weight * 0.5), 5),
            (snap_weight(working_weight * 0.75), 3),
        ]
    } else {
        vec![
            (45.0, 5),
            (snap_weight(working_weight * 0.5), 5),
            (snap_weight(working_weight * 0.75), 3),
            (snap_weight(working_weight * 0.9), 2),
        ]
    };

    defs.into_iter()
        .map(|(weight, reps)| {
            let set = ProposedSet {
                id: String::new(),
                workout_id: String::new(),
                workout_order: *order,
                exercise,
                target_reps: reps,
                target_weight: weight,
                warmup: true,
            };
            *order += 1;
            set
        })
        .collect()
}

/// Create warmup + working sets for an exercise.
fn create_exercise_sets(exercise: i32, weight: f32, set_count: usize, reps: i32, order: &mut i32) -> Vec<ProposedSet> {
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
        });
        *order += 1;
    }
    sets
}

const WORKOUT_A: &str = "Workout A";
const WORKOUT_B: &str = "Workout B";

// Starting weights (in lbs) for new lifters
const DEFAULT_SQUAT_WEIGHT: f32 = 45.0;
const DEFAULT_BENCH_WEIGHT: f32 = 45.0;
const DEFAULT_ROW_WEIGHT: f32 = 65.0;
const DEFAULT_OHP_WEIGHT: f32 = 45.0;
const DEFAULT_DEADLIFT_WEIGHT: f32 = 135.0;

// Weight increments per successful workout
const UPPER_BODY_INCREMENT: f32 = 5.0;
const LOWER_BODY_INCREMENT: f32 = 5.0;
const DEADLIFT_INCREMENT: f32 = 10.0;

pub struct Scheduler {
    user_db: UserDb,
}

impl Scheduler {
    pub fn new(user_db: UserDb) -> Self {
        Self { user_db }
    }

    /// Generate the next 5 proposed workouts based on user history
    pub async fn get_proposed_schedule(&self) -> Result<Vec<ProposedWorkout>, Box<dyn std::error::Error + Send + Sync>> {
        // Get last completed workout to determine next workout type
        let last_workout = self.user_db.get_last_completed_workout().await?;

        // Determine if next workout is A or B
        let start_with_a = match &last_workout {
            Some(w) => w.name == WORKOUT_B, // If last was B, next is A
            None => true, // Start with A if no history
        };

        // Get last weights for each exercise
        let squat_weight = self.get_next_weight(Exercise::Squat as i32, DEFAULT_SQUAT_WEIGHT).await?;
        let bench_weight = self.get_next_weight(Exercise::BenchPress as i32, DEFAULT_BENCH_WEIGHT).await?;
        let row_weight = self.get_next_weight(Exercise::BarbellRow as i32, DEFAULT_ROW_WEIGHT).await?;
        let ohp_weight = self.get_next_weight(Exercise::OverheadPress as i32, DEFAULT_OHP_WEIGHT).await?;
        let deadlift_weight = self.get_next_weight(Exercise::Deadlift as i32, DEFAULT_DEADLIFT_WEIGHT).await?;

        // Get next training days (Mon/Wed/Fri)
        let training_days = self.get_next_training_days(5);

        let mut proposed_workouts = Vec::new();
        let mut is_workout_a = start_with_a;

        // Track weight progression across the 5 workouts
        let mut current_squat = squat_weight;
        let mut current_bench = bench_weight;
        let mut current_row = row_weight;
        let mut current_ohp = ohp_weight;
        let mut current_deadlift = deadlift_weight;

        for day in training_days {
            let timestamp = day.and_hms_opt(9, 0, 0)
                .unwrap()
                .and_utc()
                .timestamp();

            let (name, sets, increments) = if is_workout_a {
                let sets = self.create_workout_a_sets(current_squat, current_bench, current_row);
                (
                    WORKOUT_A.to_string(),
                    sets,
                    (LOWER_BODY_INCREMENT, UPPER_BODY_INCREMENT, UPPER_BODY_INCREMENT), // squat, bench, row
                )
            } else {
                let sets = self.create_workout_b_sets(current_squat, current_ohp, current_deadlift);
                (
                    WORKOUT_B.to_string(),
                    sets,
                    (LOWER_BODY_INCREMENT, UPPER_BODY_INCREMENT, DEADLIFT_INCREMENT), // squat, ohp, deadlift
                )
            };

            proposed_workouts.push(ProposedWorkout {
                name,
                proposed_sets: sets,
                scheduled_for: timestamp,
            });

            // Update weights for next workout
            current_squat += LOWER_BODY_INCREMENT;
            if is_workout_a {
                current_bench += increments.1;
                current_row += increments.2;
            } else {
                current_ohp += increments.1;
                current_deadlift += increments.2;
            }

            is_workout_a = !is_workout_a;
        }

        Ok(proposed_workouts)
    }

    async fn get_next_weight(&self, exercise: i32, default: f32) -> Result<f32, Box<dyn std::error::Error + Send + Sync>> {
        match self.user_db.get_last_weight_for_exercise(exercise).await? {
            Some(last_weight) => {
                // Add appropriate increment based on exercise
                let increment = if exercise == Exercise::Deadlift as i32 {
                    DEADLIFT_INCREMENT
                } else if exercise == Exercise::Squat as i32 {
                    LOWER_BODY_INCREMENT
                } else {
                    UPPER_BODY_INCREMENT
                };
                Ok(last_weight + increment)
            }
            None => Ok(default),
        }
    }

    fn get_next_training_days(&self, count: usize) -> Vec<NaiveDate> {
        let today = Utc::now().date_naive();
        let mut days = Vec::new();
        let mut current = today;

        while days.len() < count {
            // Move to next day
            current = current + Duration::days(1);

            // Check if it's Mon, Wed, or Fri
            match current.weekday() {
                Weekday::Mon | Weekday::Wed | Weekday::Fri => {
                    days.push(current);
                }
                _ => {}
            }
        }

        days
    }

    fn create_workout_a_sets(&self, squat_weight: f32, bench_weight: f32, row_weight: f32) -> Vec<ProposedSet> {
        let mut order = 0;
        let mut sets = Vec::new();
        sets.extend(create_exercise_sets(Exercise::Squat as i32, squat_weight, 5, 5, &mut order));
        sets.extend(create_exercise_sets(Exercise::BenchPress as i32, bench_weight, 5, 5, &mut order));
        sets.extend(create_exercise_sets(Exercise::BarbellRow as i32, row_weight, 5, 5, &mut order));
        sets
    }

    fn create_workout_b_sets(&self, squat_weight: f32, ohp_weight: f32, deadlift_weight: f32) -> Vec<ProposedSet> {
        let mut order = 0;
        let mut sets = Vec::new();
        sets.extend(create_exercise_sets(Exercise::Squat as i32, squat_weight, 5, 5, &mut order));
        sets.extend(create_exercise_sets(Exercise::OverheadPress as i32, ohp_weight, 5, 5, &mut order));
        sets.extend(create_exercise_sets(Exercise::Deadlift as i32, deadlift_weight, 1, 5, &mut order));
        sets
    }
}
