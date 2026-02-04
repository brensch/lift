import { Exercise } from "../gen/lift/v1/exercise_pb.js";
import { exerciseName } from "../lib/utils";

const ALL_EXERCISES: Exercise[] = [
  Exercise.BENCH_PRESS,
  Exercise.SQUAT,
  Exercise.DEADLIFT,
  Exercise.OVERHEAD_PRESS,
  Exercise.BARBELL_ROW,
  Exercise.PULL_UP,
  Exercise.DIP,
  Exercise.BICEP_CURL,
  Exercise.TRICEP_EXTENSION,
  Exercise.LEG_PRESS,
  Exercise.LEG_CURL,
  Exercise.LEG_EXTENSION,
  Exercise.LATERAL_RAISE,
  Exercise.FACE_PULL,
  Exercise.CABLE_FLY,
  Exercise.ROMANIAN_DEADLIFT,
];

interface ExercisePickerProps {
  selected: Exercise[];
  onToggle: (exercise: Exercise) => void;
}

export function ExercisePicker({ selected, onToggle }: ExercisePickerProps) {
  return (
    <div className="grid grid-cols-2 gap-2">
      {ALL_EXERCISES.map((ex) => (
        <button
          key={ex}
          onClick={() => onToggle(ex)}
          className={`rounded-md border px-3 py-2 text-sm transition-colors ${
            selected.includes(ex)
              ? "border-blue-500 bg-blue-50 text-blue-700"
              : "border-gray-200 bg-white text-gray-700 hover:bg-gray-50"
          }`}
        >
          {exerciseName(ex)}
        </button>
      ))}
    </div>
  );
}
