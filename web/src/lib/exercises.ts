import { Exercise } from "@/gen/workout/v1/workout_pb";

// Names that don't title-case to what the app shows (app/lib/logic/exercises.dart).
const SPECIAL: Partial<Record<Exercise, string>> = {
  [Exercise.T_BAR_ROW]: "T-Bar Row",
  [Exercise.ROMANIAN_DEADLIFT]: "Romanian Deadlift",
  [Exercise.PUSH_UP]: "Push-Up",
  [Exercise.PULL_UP]: "Pull-Up",
  [Exercise.CHIN_UP]: "Chin-Up",
  [Exercise.STEP_UP]: "Step-Up",
  [Exercise.SIT_UP]: "Sit-Up",
  [Exercise.CLOSE_GRIP_BENCH_PRESS]: "Close-Grip Bench Press",
  [Exercise.SINGLE_LEG_HIP_THRUST]: "Single-Leg Hip Thrust",
  [Exercise.CABLE_PULL_THROUGH]: "Cable Pull-Through",
};

/** "BENCH_PRESS" → "Bench Press", with a few special cases. */
export function exerciseName(exercise: Exercise): string {
  const special = SPECIAL[exercise];
  if (special) return special;
  const key = Exercise[exercise];
  if (!key || exercise === Exercise.UNSPECIFIED) return "Unknown";
  return key
    .split("_")
    .map((word) => word.charAt(0) + word.slice(1).toLowerCase())
    .join(" ");
}
