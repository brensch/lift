use super::*;

// ── Workout Service ──
//
// Reads for the web, answered by the core from the account the phone syncs —
// the same code the phone runs to answer them itself.

#[derive(Clone)]
pub struct ServerWorkoutService {
    pub db: ServerDb,
}

#[tonic::async_trait]
impl WorkoutService for ServerWorkoutService {
    async fn list_workout_summaries(
        &self,
        request: Request<ListWorkoutSummariesRequest>,
    ) -> Result<Response<ListWorkoutSummariesResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "ListWorkoutSummaries", %user_id, "request");
        Ok(Response::new(
            read_api(&self.db, &user_id, |call| call.list_workout_summaries()).await?,
        ))
    }

    async fn get_exercise_progress(
        &self,
        request: Request<GetExerciseProgressRequest>,
    ) -> Result<Response<GetExerciseProgressResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        info!(rpc = "GetExerciseProgress", %user_id, "request");
        Ok(Response::new(
            read_api(&self.db, &user_id, |call| call.get_exercise_progress()).await?,
        ))
    }
}
