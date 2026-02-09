use chrono::{Datelike, Duration, NaiveDate, Utc, Weekday};
use lift::workout::v1::{Exercise, ExerciseStatus, GetProposedWorkoutScheduleResponse, ProposedSet, ScheduledWorkout};

use crate::db::UserDb;

/// StrongLifts 5x5 Program
///
/// Workout A: Squat, Bench Press, Barbell Row (5x5 each)
/// Workout B: Squat, Overhead Press, Deadlift (5x5 Squat/OHP, 1x5 Deadlift)
///
/// Alternates A-B-A, B-A-B each week
/// Training days: Monday, Wednesday, Friday

/// Plate-friendly warmup stops (bar + combinations of 45/25 plates per side).
/// Must match PLATE_STOPS in web/src/lib/warmup.ts.
#[allow(dead_code)]
const PLATE_STOPS: &[f32] = &[
    45.0, 95.0, 135.0, 185.0, 225.0, 275.0, 315.0, 365.0,
    405.0, 455.0, 495.0, 545.0, 585.0, 635.0,
];

#[allow(dead_code)]
const REP_SCHEMES: &[&[i32]] = &[
    &[5],          // 1 warmup
    &[5, 5],       // 2 warmups
    &[5, 5, 3],    // 3 warmups
    &[5, 5, 3, 2], // 4 warmups
];

/// Generate progressive warmup sets for a given exercise and working weight.
/// Uses plate-friendly stops (same algorithm as the frontend warmup.ts).
#[allow(dead_code)]
fn generate_warmup_sets(exercise: i32, working_weight: f32, order: &mut i32) -> Vec<ProposedSet> {
    if working_weight <= 45.0 {
        return Vec::new();
    }

    let candidates: Vec<f32> = PLATE_STOPS.iter().copied().filter(|&w| w < working_weight).collect();
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

    selected.iter().enumerate().map(|(i, &weight)| {
        let set = ProposedSet {
            id: String::new(),
            workout_id: String::new(),
            workout_order: *order,
            exercise,
            target_reps: reps[i],
            target_weight: weight,
            warmup: true,
        };
        *order += 1;
        set
    }).collect()
}

/// Create warmup + working sets for an exercise.
#[allow(dead_code)]
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

pub const WORKOUT_A: &str = "Workout A";
pub const WORKOUT_B: &str = "Workout B";

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

    /// Generate the proposed schedule and exercise status
    pub async fn get_proposed_schedule(&self) -> Result<GetProposedWorkoutScheduleResponse, Box<dyn std::error::Error + Send + Sync>> {
        let exercises = vec![
            (Exercise::Squat, DEFAULT_SQUAT_WEIGHT),
            (Exercise::BenchPress, DEFAULT_BENCH_WEIGHT),
            (Exercise::BarbellRow, DEFAULT_ROW_WEIGHT),
            (Exercise::OverheadPress, DEFAULT_OHP_WEIGHT),
            (Exercise::Deadlift, DEFAULT_DEADLIFT_WEIGHT),
        ];

        let mut exercise_statuses = Vec::new();
        for (ex, default) in exercises {
            let (weight, explanation, last_perf, weight_history) = self.calculate_sophisticated_weight(ex as i32, default).await?;
            exercise_statuses.push(ExerciseStatus {
                exercise: ex as i32,
                target_weight: weight,
                explanation,
                last_performed_at: last_perf,
                weight_history,
            });
        }

        let last_workout = self.user_db.get_last_completed_workout().await?;
        let next_recommended_workout_name = match last_workout {
            Some(w) if w.name == WORKOUT_A => WORKOUT_B.to_string(),
            _ => WORKOUT_A.to_string(),
        };

        // Generate 4 weeks of schedule (12 workouts)
        let training_days = self.get_next_training_days(12);
        let mut schedule = Vec::new();
        let mut is_a = next_recommended_workout_name == WORKOUT_A;

        for day in training_days {
            let timestamp = day.and_hms_opt(9, 0, 0).unwrap().and_utc().timestamp();
            schedule.push(ScheduledWorkout {
                workout_name: if is_a { WORKOUT_A.to_string() } else { WORKOUT_B.to_string() },
                scheduled_at: timestamp,
            });
            is_a = !is_a;
        }

        Ok(GetProposedWorkoutScheduleResponse {
            exercise_statuses,
            schedule,
            next_recommended_workout_name,
        })
    }

    async fn calculate_sophisticated_weight(&self, exercise: i32, default: f32) -> Result<(f32, String, i64, Vec<f32>), Box<dyn std::error::Error + Send + Sync>> {
        let history = self.user_db.get_exercise_history(exercise, 10).await?;
        let max_weight = self.user_db.get_all_time_max_weight_for_exercise(exercise).await?;
        let weight_history: Vec<f32> = history.iter().rev().map(|(w, _, _)| *w).collect();
        
        if history.is_empty() {
            return Ok((default, format!("Starting at {} lbs.", default), 0, weight_history));
        }

        let (last_weight, last_success, last_date) = history[0];
        let now = Utc::now().timestamp();
        let days_since = (now - last_date) / (24 * 3600);
        
        let increment = if exercise == Exercise::Deadlift as i32 { DEADLIFT_INCREMENT } 
                        else if exercise == Exercise::Squat as i32 { LOWER_BODY_INCREMENT }
                        else { UPPER_BODY_INCREMENT };

        // 1. Long Break Deload
        if days_since > 14 {
            let deload_pct = if days_since > 30 { 0.8 } else { 0.9 };
            let new_weight = (last_weight * deload_pct / 5.0).round() * 5.0;
            return Ok((new_weight.max(default), format!("Decreasing from {} to {} lbs because of {} day break.", last_weight, new_weight, days_since), last_date, weight_history));
        }

        // 2. Plateau Detection (3 consecutive failures at same weight)
        if history.len() >= 3 {
            let same_weight = history[0].0 == history[1].0 && history[1].0 == history[2].0;
            let all_failed = !history[0].1 && !history[1].1 && !history[2].1;
            if same_weight && all_failed {
                let new_weight = (last_weight * 0.9 / 5.0).round() * 5.0;
                return Ok((new_weight.max(default), format!("Decreasing from {} to {} lbs to reset progression after plateau.", last_weight, new_weight), last_date, weight_history));
            }
        }

        // 3. Recent Failure (1 or 2 times)
        if !last_success {
            return Ok((last_weight, format!("Maintaining at {} lbs to master form after last failure.", last_weight), last_date, weight_history));
        }

        // 4. Return to Weight Mode
        if max_weight > last_weight + increment {
            let successes_since_deload = history.iter().take_while(|(_, success, _)| *success).count();
            if successes_since_deload >= 2 {
                let fast_increment = increment * 2.0;
                let new_weight = last_weight + fast_increment;
                return Ok((new_weight, format!("Increasing from {} to {} lbs to reclaim previous max of {} lbs.", last_weight, new_weight, max_weight), last_date, weight_history));
            }
        }

        // 5. Standard Progression
        let new_weight = last_weight + increment;
        Ok((new_weight, format!("Increasing from {} to {} lbs after successful last session.", last_weight, new_weight), last_date, weight_history))
    }

    fn get_next_training_days(&self, count: usize) -> Vec<NaiveDate> {
        let today = Utc::now().date_naive();
        let mut days = Vec::new();
        let mut current = today;

        while days.len() < count {
            current = current + Duration::days(1);
            match current.weekday() {
                Weekday::Mon | Weekday::Wed | Weekday::Fri => {
                    days.push(current);
                }
                _ => {}
            }
        }
        days
    }

    #[allow(dead_code)]
    pub fn create_workout_a_sets(&self, squat_weight: f32, bench_weight: f32, row_weight: f32) -> Vec<ProposedSet> {
        let mut order = 0;
        let mut sets = Vec::new();
        sets.extend(create_exercise_sets(Exercise::Squat as i32, squat_weight, 5, 5, &mut order));
        sets.extend(create_exercise_sets(Exercise::BenchPress as i32, bench_weight, 5, 5, &mut order));
        sets.extend(create_exercise_sets(Exercise::BarbellRow as i32, row_weight, 5, 5, &mut order));
        sets
    }

    #[allow(dead_code)]
    pub fn create_workout_b_sets(&self, squat_weight: f32, ohp_weight: f32, deadlift_weight: f32) -> Vec<ProposedSet> {
        let mut order = 0;
        let mut sets = Vec::new();
        sets.extend(create_exercise_sets(Exercise::Squat as i32, squat_weight, 5, 5, &mut order));
        sets.extend(create_exercise_sets(Exercise::OverheadPress as i32, ohp_weight, 5, 5, &mut order));
        sets.extend(create_exercise_sets(Exercise::Deadlift as i32, deadlift_weight, 1, 5, &mut order));
        sets
    }
}
