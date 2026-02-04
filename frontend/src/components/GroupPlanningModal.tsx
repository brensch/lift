import { useState } from "react";
import type { Exercise } from "../gen/lift/v1/exercise_pb.js";
import type { GroupWorkoutProposalsEvent } from "../gen/lift/v1/group_pb.js";
import { ExercisePicker } from "./ExercisePicker";
import { exerciseName } from "../lib/utils";

interface GroupPlanningModalProps {
  proposals: GroupWorkoutProposalsEvent;
  userId: string;
  onSubmit: (exercises: Exercise[], ready: boolean) => void;
  onClose: () => void;
}

export function GroupPlanningModal({
  proposals,
  userId,
  onSubmit,
  onClose,
}: GroupPlanningModalProps) {
  const mySel = proposals.selections.find((s) => s.userId === userId);
  const [selectedExercises, setSelectedExercises] = useState<Exercise[]>(
    mySel?.exercises || [],
  );

  const handleToggle = (exercise: Exercise) => {
    setSelectedExercises((prev) =>
      prev.includes(exercise)
        ? prev.filter((e) => e !== exercise)
        : [...prev, exercise],
    );
  };

  const handleReady = () => {
    onSubmit(selectedExercises, true);
  };

  const handleUpdate = () => {
    onSubmit(selectedExercises, false);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
      <div className="mx-4 max-h-[90vh] w-full max-w-md overflow-y-auto rounded-lg bg-white p-6">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-semibold">Group Exercise Selection</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600">
            x
          </button>
        </div>

        {/* Other participants' selections */}
        <div className="mb-4 space-y-2">
          <h3 className="text-sm font-medium text-gray-700">Participants</h3>
          {proposals.selections.map((sel) => (
            <div key={sel.userId} className="rounded border p-2 text-sm">
              <div className="flex items-center justify-between">
                <span className="font-medium">{sel.userName}</span>
                <span
                  className={`text-xs ${sel.ready ? "text-green-600" : "text-yellow-600"}`}
                >
                  {sel.ready ? "Ready" : "Selecting..."}
                </span>
              </div>
              {sel.exercises.length > 0 && (
                <p className="mt-1 text-xs text-gray-500">
                  {sel.exercises.map((ex) => exerciseName(ex)).join(", ")}
                </p>
              )}
            </div>
          ))}
        </div>

        {/* My selection */}
        <div className="mb-4">
          <h3 className="mb-2 text-sm font-medium text-gray-700">
            Your Exercises
          </h3>
          <ExercisePicker selected={selectedExercises} onToggle={handleToggle} />
        </div>

        <div className="flex gap-2">
          <button
            onClick={handleUpdate}
            className="flex-1 rounded-md border px-4 py-2 text-sm hover:bg-gray-50"
          >
            Update
          </button>
          <button
            onClick={handleReady}
            className="flex-1 rounded-md bg-green-600 px-4 py-2 text-sm font-medium text-white hover:bg-green-700"
          >
            Ready
          </button>
        </div>
      </div>
    </div>
  );
}
