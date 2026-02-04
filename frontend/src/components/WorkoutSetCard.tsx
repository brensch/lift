import type { ProposedSet, CompletedSet } from "../gen/lift/v1/workout_pb.js";
import { exerciseName } from "../lib/utils";

interface WorkoutSetCardProps {
  proposedSet: ProposedSet;
  completedSet?: CompletedSet;
  isActive: boolean;
  onStart: () => void;
}

export function WorkoutSetCard({
  proposedSet,
  completedSet,
  isActive,
  onStart,
}: WorkoutSetCardProps) {
  const isDone = completedSet?.endedAt != null;
  const isInProgress = completedSet?.startedAt != null && !isDone;

  return (
    <div
      className={`rounded-lg border p-3 ${
        isDone
          ? "border-green-200 bg-green-50"
          : isInProgress || isActive
            ? "border-blue-300 bg-blue-50"
            : "border-gray-200 bg-white"
      }`}
    >
      <div className="flex items-center justify-between">
        <div>
          <span className="text-sm font-medium">
            {proposedSet.warmup && (
              <span className="mr-1 text-xs text-orange-500">[W]</span>
            )}
            {exerciseName(proposedSet.exercise)}
          </span>
          <span className="ml-2 text-sm text-gray-500">
            {proposedSet.targetReps} x {proposedSet.targetWeight}kg
          </span>
        </div>
        {isDone ? (
          <span className="text-xs text-green-600">
            {completedSet!.actualReps} x {completedSet!.actualWeight}kg
          </span>
        ) : isInProgress ? (
          <span className="text-xs text-blue-600">In progress...</span>
        ) : (
          <button
            onClick={onStart}
            className="rounded bg-blue-600 px-3 py-1 text-xs text-white hover:bg-blue-700"
          >
            Start
          </button>
        )}
      </div>
    </div>
  );
}
