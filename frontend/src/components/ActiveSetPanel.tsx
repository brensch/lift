import { useState } from "react";
import type { ProposedSet, CompletedSet } from "../gen/lift/v1/workout_pb.js";
import { exerciseName, formatDuration } from "../lib/utils";
import { useTimer } from "../hooks/useTimer";
import { timestampDate } from "@bufbuild/protobuf/wkt";

interface ActiveSetPanelProps {
  proposedSet: ProposedSet;
  completedSet: CompletedSet;
  onComplete: (
    actualReps: number,
    actualWeight: number,
    restSeconds: number,
  ) => void;
}

export function ActiveSetPanel({
  proposedSet,
  completedSet,
  onComplete,
}: ActiveSetPanelProps) {
  const [reps, setReps] = useState(proposedSet.targetReps);
  const [weight, setWeight] = useState(proposedSet.targetWeight);
  const [restSeconds, setRestSeconds] = useState(90);
  const { getElapsedSeconds } = useTimer();

  const startedAt = completedSet.startedAt
    ? timestampDate(completedSet.startedAt)
    : null;
  const elapsed = startedAt ? getElapsedSeconds(startedAt) : 0;

  return (
    <div className="rounded-lg border-2 border-blue-500 bg-blue-50 p-4">
      <div className="mb-3 flex items-center justify-between">
        <h3 className="font-semibold">{exerciseName(proposedSet.exercise)}</h3>
        <span className="text-lg font-mono text-blue-600">
          {formatDuration(elapsed)}
        </span>
      </div>

      <div className="mb-3 grid grid-cols-3 gap-2">
        <div>
          <label className="block text-xs text-gray-500">Reps</label>
          <input
            type="number"
            value={reps}
            onChange={(e) => setReps(Number(e.target.value))}
            className="w-full rounded border px-2 py-1 text-center text-sm"
          />
        </div>
        <div>
          <label className="block text-xs text-gray-500">Weight (kg)</label>
          <input
            type="number"
            step="0.5"
            value={weight}
            onChange={(e) => setWeight(Number(e.target.value))}
            className="w-full rounded border px-2 py-1 text-center text-sm"
          />
        </div>
        <div>
          <label className="block text-xs text-gray-500">Rest (sec)</label>
          <input
            type="number"
            step="15"
            value={restSeconds}
            onChange={(e) => setRestSeconds(Number(e.target.value))}
            className="w-full rounded border px-2 py-1 text-center text-sm"
          />
        </div>
      </div>

      <button
        onClick={() => onComplete(reps, weight, restSeconds)}
        className="w-full rounded-md bg-green-600 px-4 py-2 text-sm font-medium text-white hover:bg-green-700"
      >
        Complete Set
      </button>
    </div>
  );
}
