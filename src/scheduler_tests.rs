    use crate::regimes::linear_5x5::{build_linear_proposed_groups, calculate_linear_progression};
    use crate::regimes::SessionHistory;
    use lift::workout::v1::{Exercise, ExerciseCategory, ExerciseStatus};

    fn session(weight: f32, success: bool, days_ago: i64) -> SessionHistory {
        SessionHistory {
            weight,
            success,
            timestamp: chrono::Utc::now().timestamp() - days_ago * 86400,
            last_set_reps: if success { 5 } else { 3 },
        }
    }

    fn status(exercise: Exercise, last_performed_at: i64) -> ExerciseStatus {
        ExerciseStatus {
            exercise: exercise as i32,
            target_weight: 100.0,
            explanation: String::new(),
            last_performed_at,
            weight_history: vec![],
            muscle_groups: vec![],
            default_sets: 5,
            default_reps: 5,
            recovered: true,
            always_include: exercise == Exercise::Squat,
            category: ExerciseCategory::Compound as i32,
        }
    }

    #[test]
    fn proposed_groups_include_explanations() {
        let mut squat_status = status(Exercise::Squat, 1_000);
        squat_status.explanation = "Squat explanation".to_string();

        let mut bench_status = status(Exercise::BenchPress, 3_000);
        bench_status.explanation = "Bench explanation".to_string();

        let statuses = vec![squat_status, bench_status];

        let groups = build_linear_proposed_groups(&statuses);

        let squat_group = groups.iter().find(|g| g.name == "Squat").unwrap();
        assert_eq!(squat_group.explanation, "Squat explanation");

        let bench_group = groups.iter().find(|g| g.name == "Bench Press").unwrap();
        assert_eq!(bench_group.explanation, "Bench explanation");
    }

    #[test]
    fn proposed_groups_prioritize_compound_rotation_defaults() {
        let statuses = vec![
            status(Exercise::Squat, 1_000),
            status(Exercise::BenchPress, 3_000),
            status(Exercise::Deadlift, 2_000),
            status(Exercise::OverheadPress, 4_000),
            status(Exercise::BarbellRow, 1_500),
            status(Exercise::HipThrust, 0),
        ];

        let groups = build_linear_proposed_groups(&statuses);

        assert_eq!(groups[0].name, "Squat");
        assert_eq!(groups[1].name, "Barbell Row");
        assert_eq!(groups[2].name, "Deadlift");
        assert!(groups
            .iter()
            .any(|g| g.tags.contains(&"auxiliary".to_string())));
        // Top 3 (squat + 2 stalest rotation) should be tagged recommended
        assert!(groups[0].tags.contains(&"recommended".to_string()));
        assert!(groups[1].tags.contains(&"recommended".to_string()));
        assert!(groups[2].tags.contains(&"recommended".to_string()));
    }

    #[test]
    fn linear_progression_standard() {
        let now = chrono::Utc::now().timestamp();
        let history = vec![session(100.0, true, 1)];
        let (weight, explanation) =
            calculate_linear_progression(Exercise::BenchPress as i32, 45.0, &history, 100.0, now);
        assert_eq!(weight, 105.0);
        assert!(explanation.contains("105"));
    }

    #[test]
    fn linear_progression_failure_holds() {
        let now = chrono::Utc::now().timestamp();
        let history = vec![session(100.0, false, 1)];
        let (weight, _) =
            calculate_linear_progression(Exercise::BenchPress as i32, 45.0, &history, 100.0, now);
        assert_eq!(weight, 100.0);
    }

    #[test]
    fn linear_progression_plateau_deloads() {
        let now = chrono::Utc::now().timestamp();
        let history = vec![
            session(100.0, false, 3),
            session(100.0, false, 6),
            session(100.0, false, 9),
        ];
        let (weight, _) =
            calculate_linear_progression(Exercise::BenchPress as i32, 45.0, &history, 100.0, now);
        assert!(weight < 100.0);
    }
