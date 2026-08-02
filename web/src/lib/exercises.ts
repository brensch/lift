import { Exercise } from "@/gen/workout/v1/workout_pb";

// Enum keys that don't title-case cleanly.
const SPECIAL: Partial<Record<Exercise, string>> = {
  [Exercise.T_BAR_ROW]: "T-Bar Row",
  [Exercise.ROMANIAN_DEADLIFT]: "Romanian Deadlift",
};

const LOWERCASE_WORDS = new Set(["up", "down"]);

/** "BENCH_PRESS" → "Bench Press", with a few special cases. */
export function exerciseName(exercise: Exercise): string {
  const special = SPECIAL[exercise];
  if (special) return special;
  const key = Exercise[exercise];
  if (!key || exercise === Exercise.UNSPECIFIED) return "Unknown";
  return key
    .split("_")
    .map((word, i) => {
      const lower = word.toLowerCase();
      if (i > 0 && LOWERCASE_WORDS.has(lower)) return lower;
      return lower.charAt(0).toUpperCase() + lower.slice(1);
    })
    .join(" ");
}
