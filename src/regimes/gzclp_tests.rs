    use super::*;

    #[test]
    fn compute_updated_state_is_idempotent_for_same_latest_session() {
        let regime = GzclpRegime;
        let mut history: HashMap<i32, Vec<SessionHistory>> = HashMap::new();
        history.insert(
            Exercise::Squat as i32,
            vec![SessionHistory {
                weight: 225.0,
                success: false,
                timestamp: 1_700_000_000,
                last_set_reps: 2,
            }],
        );

        let config = UserWorkoutConfig {
            regime_type: 0,
            days_per_week: 4,
            one_rep_maxes: HashMap::new(),
            regime_state_json: "{}".to_string(),
        };

        let state_once = regime.compute_updated_state(&config, &history);
        let config2 = UserWorkoutConfig {
            regime_state_json: state_once.clone(),
            ..config
        };
        let state_twice = regime.compute_updated_state(&config2, &history);

        let parsed_once = GzclpState::from_json(&state_once);
        let parsed_twice = GzclpState::from_json(&state_twice);
        assert_eq!(parsed_once.stage_for(Exercise::Squat), 2);
        assert_eq!(parsed_twice.stage_for(Exercise::Squat), 2);
        assert_eq!(state_once, state_twice);
    }
