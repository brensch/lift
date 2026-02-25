use super::*;

#[test]
fn three_day_variant_names_paired_lifts_and_advances_week_after_3_sessions() {
    let regime = Wendler5313DayRegime;
    let mut history: HashMap<i32, Vec<SessionHistory>> = HashMap::new();
    history.insert(
        Exercise::Squat as i32,
        vec![SessionHistory {
            weight: 135.0,
            timestamp: 1,
        }],
    );
    history.insert(
        Exercise::BenchPress as i32,
        vec![SessionHistory {
            weight: 95.0,
            timestamp: 1,
        }],
    );
    history.insert(
        Exercise::Deadlift as i32,
        vec![SessionHistory {
            weight: 185.0,
            timestamp: 1,
        }],
    );
    history.insert(
        Exercise::OverheadPress as i32,
        vec![SessionHistory {
            weight: 65.0,
            timestamp: 1,
        }],
    );
    // 4 main-lift entries => 2 completed 3-day sessions in this paired-lift variant.

    let config = UserWorkoutConfig {
        regime_type: 0,
        days_per_week: 3,
        one_rep_maxes: HashMap::new(),
        regime_state_json: "{}".to_string(),
    };
    let state_json = regime.compute_updated_state(&config, &history);
    let cfg2 = UserWorkoutConfig {
        regime_state_json: state_json,
        ..config
    };
    let name = regime.suggested_workout_name(&cfg2);
    assert!(name.contains("Cycle 1"));
    assert!(name.contains("Week 1"));
    assert!(name.contains("+") || (name.contains("Squat") && name.contains("Bench")));
}
