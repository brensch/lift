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

    async fn get_workout(
        &self,
        request: Request<GetWorkoutRequest>,
    ) -> Result<Response<GetWorkoutResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "GetWorkout", %user_id, workout_id = %req.workout_id, "request");
        let response = read_api(&self.db, &user_id, |call| call.get_workout(req)).await?;
        Ok(Response::new(response.map_err(core_status)?))
    }

    async fn get_workout_heart_rate(
        &self,
        request: Request<GetWorkoutHeartRateRequest>,
    ) -> Result<Response<GetWorkoutHeartRateResponse>, Status> {
        let user_id = authed_user_id(&request, &self.db).await?;
        let req = request.into_inner();
        info!(rpc = "GetWorkoutHeartRate", %user_id, workout_id = %req.workout_id, "request");
        let response =
            read_api(&self.db, &user_id, |call| call.get_workout_heart_rate(req)).await?;
        Ok(Response::new(response.map_err(core_status)?))
    }
}
