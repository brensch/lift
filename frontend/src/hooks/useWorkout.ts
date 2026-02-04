import { useState, useCallback } from "react";
import { workoutClient } from "../lib/api";
import type { WorkoutState, ProposedSet } from "../gen/lift/v1/workout_pb.js";

export function useWorkout() {
  const [workoutState, setWorkoutState] = useState<WorkoutState | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const startWorkout = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await workoutClient.startWorkout({});
      if (res.state) setWorkoutState(res.state);
      return res.state;
    } catch (e) {
      setError(String(e));
      return null;
    } finally {
      setLoading(false);
    }
  }, []);

  const getWorkout = useCallback(async (workoutId: string) => {
    setLoading(true);
    setError(null);
    try {
      const res = await workoutClient.getWorkout({ workoutId });
      if (res.state) setWorkoutState(res.state);
    } catch (e) {
      setError(String(e));
    } finally {
      setLoading(false);
    }
  }, []);

  const modifyProposedSets = useCallback(
    async (workoutId: string, proposedSets: ProposedSet[]) => {
      setError(null);
      try {
        const res = await workoutClient.modifyProposedSets({
          workoutId,
          proposedSets,
        });
        if (res.state) setWorkoutState(res.state);
      } catch (e) {
        setError(String(e));
      }
    },
    [],
  );

  const startSet = useCallback(
    async (workoutId: string, proposedSetId: string) => {
      setError(null);
      try {
        const res = await workoutClient.startSet({ workoutId, proposedSetId });
        if (res.state) setWorkoutState(res.state);
      } catch (e) {
        setError(String(e));
      }
    },
    [],
  );

  const completeSet = useCallback(
    async (
      workoutId: string,
      proposedSetId: string,
      actualReps: number,
      actualWeight: number,
      restSeconds: number,
    ) => {
      setError(null);
      try {
        const res = await workoutClient.completeSet({
          workoutId,
          proposedSetId,
          actualReps,
          actualWeight,
          restSeconds,
        });
        if (res.state) setWorkoutState(res.state);
      } catch (e) {
        setError(String(e));
      }
    },
    [],
  );

  const endWorkout = useCallback(async (workoutId: string) => {
    setError(null);
    try {
      const res = await workoutClient.endWorkout({ workoutId });
      if (res.state) setWorkoutState(res.state);
    } catch (e) {
      setError(String(e));
    }
  }, []);

  return {
    workoutState,
    loading,
    error,
    startWorkout,
    getWorkout,
    modifyProposedSets,
    startSet,
    completeSet,
    endWorkout,
    setWorkoutState,
  };
}
