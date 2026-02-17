use sqlx::sqlite::{SqliteConnectOptions, SqlitePoolOptions};
use sqlx::Row;
use std::collections::HashSet;
use std::path::Path;
use std::str::FromStr;

fn exercise_name(ex: i32) -> &'static str {
    match ex {
        1 => "Squat",
        2 => "Bench Press",
        3 => "Deadlift",
        4 => "Overhead Press",
        5 => "Barbell Row",
        6 => "Hip Thrust",
        7 => "Bulgarian Split Squat",
        8 => "Romanian Deadlift",
        9 => "Glute Bridge",
        10 => "Lunge",
        11 => "Leg Curl",
        _ => "Unknown",
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let db_path = "data/central.sqlite";
    if !Path::new(db_path).exists() {
        return Err(format!("Database not found at {}", db_path).into());
    }

    let db_url = format!("sqlite://{}", db_path);
    let options = SqliteConnectOptions::from_str(&db_url)?.read_only(true);
    let pool = SqlitePoolOptions::new()
        .max_connections(1)
        .connect_with(options)
        .await?;

    let workout_row = sqlx::query(
        "SELECT id, user_id, name, start_time
         FROM workouts
         WHERE end_time IS NULL
         ORDER BY start_time DESC
         LIMIT 1",
    )
    .fetch_optional(&pool)
    .await?;

    let workout_row = match workout_row {
        Some(row) => row,
        None => {
            println!("No active workout found.");
            return Ok(());
        }
    };

    let workout_id: String = workout_row.get("id");
    let user_id: String = workout_row.get("user_id");
    let workout_name: String = workout_row.get("name");
    println!("Active workout: {} ({})", workout_name, workout_id);
    println!("User: {}", user_id);

    let completed_rows = sqlx::query(
        "SELECT proposed_set_id
         FROM completed_sets
         WHERE workout_id = ? AND ended_at > 0",
    )
    .bind(&workout_id)
    .fetch_all(&pool)
    .await?;
    let completed_ids: HashSet<String> = completed_rows
        .into_iter()
        .map(|row| row.get::<String, _>("proposed_set_id"))
        .filter(|id| !id.is_empty())
        .collect();

    let proposed_rows = sqlx::query(
        "SELECT id, workout_order, exercise, warmup, cancelled, target_weight, target_reps, exercise_group_id
         FROM proposed_sets
         WHERE workout_id = ?
         ORDER BY workout_order",
    )
    .bind(&workout_id)
    .fetch_all(&pool)
    .await?;

    println!("\nProposed sets (in order):");
    for row in &proposed_rows {
        let id: String = row.get("id");
        let order: i32 = row.get("workout_order");
        let ex: i32 = row.get("exercise");
        let warmup: bool = row.get("warmup");
        let cancelled: bool = row.get::<Option<bool>, _>("cancelled").unwrap_or(false);
        let done = completed_ids.contains(&id);
        let target_weight: f32 = row.get("target_weight");
        let target_reps: i32 = row.get("target_reps");
        println!(
            "#{:02} {:<12} {:<6} wt={:<5} reps={:<2} cancelled={} done={} id={}",
            order,
            exercise_name(ex),
            if warmup { "warmup" } else { "work" },
            target_weight,
            target_reps,
            cancelled,
            done,
            id
        );
    }

    let next_with_cancelled = proposed_rows
        .iter()
        .find(|row| {
            let id: String = row.get("id");
            !completed_ids.contains(&id)
        })
        .map(|row| {
            let id: String = row.get("id");
            let order: i32 = row.get("workout_order");
            let ex: i32 = row.get("exercise");
            let warmup: bool = row.get("warmup");
            let cancelled: bool = row.get::<Option<bool>, _>("cancelled").unwrap_or(false);
            let target_weight: f32 = row.get("target_weight");
            let target_reps: i32 = row.get("target_reps");
            (id, order, ex, warmup, cancelled, target_weight, target_reps)
        });

    let next_active_only = proposed_rows
        .iter()
        .find(|row| {
            let id: String = row.get("id");
            let cancelled: bool = row.get::<Option<bool>, _>("cancelled").unwrap_or(false);
            !cancelled && !completed_ids.contains(&id)
        })
        .map(|row| {
            let id: String = row.get("id");
            let order: i32 = row.get("workout_order");
            let ex: i32 = row.get("exercise");
            let warmup: bool = row.get("warmup");
            let cancelled: bool = row.get::<Option<bool>, _>("cancelled").unwrap_or(false);
            let target_weight: f32 = row.get("target_weight");
            let target_reps: i32 = row.get("target_reps");
            (id, order, ex, warmup, cancelled, target_weight, target_reps)
        });

    println!("\nComputed next-up:");
    if let Some((id, order, ex, warmup, cancelled, wt, reps)) = next_with_cancelled {
        println!(
            "  Legacy (ignoring cancelled): #{:02} {} {} wt={} reps={} cancelled={} id={}",
            order,
            exercise_name(ex),
            if warmup { "(warmup)" } else { "(work)" },
            wt,
            reps,
            cancelled,
            id
        );
    } else {
        println!("  Legacy (ignoring cancelled): none");
    }

    if let Some((id, order, ex, warmup, cancelled, wt, reps)) = next_active_only {
        println!(
            "  Current (active only):       #{:02} {} {} wt={} reps={} cancelled={} id={}",
            order,
            exercise_name(ex),
            if warmup { "(warmup)" } else { "(work)" },
            wt,
            reps,
            cancelled,
            id
        );
    } else {
        println!("  Current (active only): none");
    }

    Ok(())
}
