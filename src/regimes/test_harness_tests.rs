    use super::*;

    #[tokio::test]
    async fn test_linear_5x5_progression() {
        run_scenario(include_str!("scenarios/linear_5x5.json")).await;
    }

    #[tokio::test]
    async fn test_gzclp_progression() {
        run_scenario(include_str!("scenarios/gzclp.json")).await;
    }

    #[tokio::test]
    async fn test_wendler_531_4day_progression() {
        run_scenario(include_str!("scenarios/wendler_531.json")).await;
    }

    #[tokio::test]
    async fn test_wendler_531_3day_progression() {
        run_scenario(include_str!("scenarios/wendler_531_3day.json")).await;
    }
