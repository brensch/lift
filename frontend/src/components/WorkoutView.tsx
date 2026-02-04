import { useState } from "react";
import type { WorkoutState, ProposedSet } from "../gen/lift/v1/workout_pb.js";
import { Exercise } from "../gen/lift/v1/exercise_pb.js";
import { WorkoutSetCard } from "./WorkoutSetCard";
import { ActiveSetPanel } from "./ActiveSetPanel";
import { RestTimer } from "./RestTimer";
import { CompletedSetLedger } from "./CompletedSetLedger";
import { exerciseName, formatDuration } from "../lib/utils";
import { useTimer } from "../hooks/useTimer";
import { create } from "@bufbuild/protobuf";
import { ProposedSetSchema } from "../gen/lift/v1/workout_pb.js";
import { timestampDate } from "@bufbuild/protobuf/wkt";

interface WorkoutViewProps {
  state: WorkoutState;
  onModifyProposedSets: (sets: ProposedSet[]) => void;
  onStartSet: (proposedSetId: string) => void;
  onCompleteSet: (
    proposedSetId: string,
    reps: number,
    weight: number,
    restSeconds: number,
  ) => void;
  onEndWorkout: () => void;
}

export function WorkoutView({
  state,
  onModifyProposedSets,
  onStartSet,
  onCompleteSet,
  onEndWorkout,
}: WorkoutViewProps) {
  const [showAddExercise, setShowAddExercise] = useState(false);
  const [newExercise, setNewExercise] = useState<Exercise>(
    Exercise.BENCH_PRESS,
  );
  const [newSets, setNewSets] = useState(3);
  const [newReps, setNewReps] = useState(10);
  const [newWeight, setNewWeight] = useState(60);
  const { getElapsedSeconds } = useTimer();

  const completedMap = new Map(
    state.completedSets.map((cs) => [cs.proposedSetId, cs]),
  );

  // Find the active set (started but not completed)
  const activeCompleted = state.completedSets.find(
    (cs) => cs.startedAt != null && cs.endedAt == null,
  );
  const activeProposed = activeCompleted
    ? state.proposedSets.find((ps) => ps.id === activeCompleted.proposedSetId)
    : null;

  // Find the latest rest timer
  const latestCompletedWithRest = [...state.completedSets]
    .filter((cs) => cs.restUntil != null && cs.endedAt != null)
    .sort((a, b) => {
      const aTime = a.endedAt ? timestampDate(a.endedAt).getTime() : 0;
      const bTime = b.endedAt ? timestampDate(b.endedAt).getTime() : 0;
      return bTime - aTime;
    })[0];

  const restUntil = latestCompletedWithRest?.restUntil
    ? timestampDate(latestCompletedWithRest.restUntil)
    : null;
  const isResting = restUntil && restUntil.getTime() > Date.now();

  const workoutStart = state.workout?.startTime
    ? timestampDate(state.workout.startTime)
    : null;
  const workoutElapsed = workoutStart ? getElapsedSeconds(workoutStart) : 0;

  const handleAddExercise = () => {
    const existingSets = [...state.proposedSets];
    let order = existingSets.length;

    for (let i = 0; i < newSets; i++) {
      const ps = create(ProposedSetSchema, {
        workoutId: state.workout!.id,
        workoutOrder: order++,
        exercise: newExercise,
        targetReps: newReps,
        targetWeight: newWeight,
        warmup: false,
      });
      existingSets.push(ps);
    }

    onModifyProposedSets(existingSets);
    setShowAddExercise(false);
  };

  const handleRemoveSet = (index: number) => {
    const updated = state.proposedSets.filter((_, i) => i !== index);
    const reordered = updated.map((ps, i) => {
      const newPs = create(ProposedSetSchema, { ...ps });
      newPs.workoutOrder = i;
      return newPs;
    });
    onModifyProposedSets(reordered);
  };

  return (
    <div className="space-y-4">
      {/* Workout header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold">Workout</h2>
          <span className="text-sm text-gray-500 font-mono">
            {formatDuration(workoutElapsed)}
          </span>
        </div>
        {!state.workout?.endTime && (
          <button
            onClick={onEndWorkout}
            className="rounded-md bg-red-600 px-4 py-2 text-sm font-medium text-white hover:bg-red-700"
          >
            End Workout
          </button>
        )}
      </div>

      {/* Rest timer */}
      {isResting && restUntil && <RestTimer restUntil={restUntil} />}

      {/* Active set */}
      {activeProposed && activeCompleted && (
        <ActiveSetPanel
          proposedSet={activeProposed}
          completedSet={activeCompleted}
          onComplete={(reps, weight, restSecs) =>
            onCompleteSet(activeProposed.id, reps, weight, restSecs)
          }
        />
      )}

      {/* Proposed sets */}
      <div className="space-y-2">
        <h3 className="text-sm font-semibold text-gray-700">Sets</h3>
        {state.proposedSets.map((ps, index) => (
          <div key={ps.id || index} className="flex items-center gap-2">
            <div className="flex-1">
              <WorkoutSetCard
                proposedSet={ps}
                completedSet={completedMap.get(ps.id)}
                isActive={activeProposed?.id === ps.id}
                onStart={() => onStartSet(ps.id)}
              />
            </div>
            {!completedMap.has(ps.id) && (
              <button
                onClick={() => handleRemoveSet(index)}
                className="text-gray-400 hover:text-red-500 text-sm"
              >
                x
              </button>
            )}
          </div>
        ))}
      </div>

      {/* Add exercise */}
      {!state.workout?.endTime && (
        <>
          {showAddExercise ? (
            <div className="rounded-lg border bg-white p-4 space-y-3">
              <div>
                <label className="block text-xs text-gray-500 mb-1">
                  Exercise
                </label>
                <select
                  value={newExercise}
                  onChange={(e) => setNewExercise(Number(e.target.value))}
                  className="w-full rounded border px-2 py-1 text-sm"
                >
                  {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16].map(
                    (ex) => (
                      <option key={ex} value={ex}>
                        {exerciseName(ex as Exercise)}
                      </option>
                    ),
                  )}
                </select>
              </div>
              <div className="grid grid-cols-3 gap-2">
                <div>
                  <label className="block text-xs text-gray-500">Sets</label>
                  <input
                    type="number"
                    value={newSets}
                    onChange={(e) => setNewSets(Number(e.target.value))}
                    className="w-full rounded border px-2 py-1 text-center text-sm"
                  />
                </div>
                <div>
                  <label className="block text-xs text-gray-500">Reps</label>
                  <input
                    type="number"
                    value={newReps}
                    onChange={(e) => setNewReps(Number(e.target.value))}
                    className="w-full rounded border px-2 py-1 text-center text-sm"
                  />
                </div>
                <div>
                  <label className="block text-xs text-gray-500">
                    Weight (kg)
                  </label>
                  <input
                    type="number"
                    step="0.5"
                    value={newWeight}
                    onChange={(e) => setNewWeight(Number(e.target.value))}
                    className="w-full rounded border px-2 py-1 text-center text-sm"
                  />
                </div>
              </div>
              <div className="flex gap-2">
                <button
                  onClick={handleAddExercise}
                  className="flex-1 rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
                >
                  Add
                </button>
                <button
                  onClick={() => setShowAddExercise(false)}
                  className="flex-1 rounded-md border px-4 py-2 text-sm"
                >
                  Cancel
                </button>
              </div>
            </div>
          ) : (
            <button
              onClick={() => setShowAddExercise(true)}
              className="w-full rounded-md border-2 border-dashed border-gray-300 px-4 py-3 text-sm text-gray-500 hover:border-blue-400 hover:text-blue-600"
            >
              + Add Exercise
            </button>
          )}
        </>
      )}

      {/* Completed sets ledger */}
      <CompletedSetLedger
        completedSets={state.completedSets}
        proposedSets={state.proposedSets}
      />
    </div>
  );
}
