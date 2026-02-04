import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { workoutClient } from "../lib/api";
import type { WorkoutState } from "../gen/lift/v1/workout_pb.js";
import { exerciseName } from "../lib/utils";
import { timestampDate } from "@bufbuild/protobuf/wkt";

export function History() {
  const [workouts, setWorkouts] = useState<WorkoutState[]>([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    workoutClient
      .listWorkouts({})
      .then((res) => setWorkouts(res.workouts))
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div className="flex h-screen items-center justify-center">
        <p className="text-gray-500">Loading...</p>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-md p-4 space-y-4">
      <button
        onClick={() => navigate("/")}
        className="text-sm text-blue-600 hover:underline"
      >
        &larr; Home
      </button>

      <h1 className="text-xl font-bold">Workout History</h1>

      {workouts.length === 0 ? (
        <p className="text-gray-500 text-sm">No workouts yet.</p>
      ) : (
        <div className="space-y-3">
          {workouts.map((ws) => {
            const startTime = ws.workout?.startTime
              ? timestampDate(ws.workout.startTime)
              : null;
            const exercises = [
              ...new Set(
                ws.proposedSets.map((ps) => exerciseName(ps.exercise)),
              ),
            ];
            const completedCount = ws.completedSets.filter(
              (cs) => cs.endedAt != null,
            ).length;

            return (
              <button
                key={ws.workout?.id}
                onClick={() => navigate(`/workout/${ws.workout?.id}`)}
                className="w-full rounded-lg border bg-white p-3 text-left hover:bg-gray-50"
              >
                <div className="flex items-center justify-between">
                  <span className="text-sm font-medium">
                    {startTime?.toLocaleDateString()}
                  </span>
                  <span className="text-xs text-gray-500">
                    {completedCount}/{ws.proposedSets.length} sets
                  </span>
                </div>
                {exercises.length > 0 && (
                  <p className="mt-1 text-xs text-gray-500">
                    {exercises.join(", ")}
                  </p>
                )}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}
