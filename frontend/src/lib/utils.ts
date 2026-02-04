import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";
import type { Exercise } from "../gen/lift/v1/exercise_pb.js";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

const exerciseNames: Record<number, string> = {
  0: "Unspecified",
  1: "Bench Press",
  2: "Squat",
  3: "Deadlift",
  4: "Overhead Press",
  5: "Barbell Row",
  6: "Pull Up",
  7: "Dip",
  8: "Bicep Curl",
  9: "Tricep Extension",
  10: "Leg Press",
  11: "Leg Curl",
  12: "Leg Extension",
  13: "Lateral Raise",
  14: "Face Pull",
  15: "Cable Fly",
  16: "Romanian Deadlift",
};

export function exerciseName(exercise: Exercise): string {
  return exerciseNames[exercise] || `Exercise ${exercise}`;
}

export function formatDuration(seconds: number): string {
  const mins = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  return `${mins}:${secs.toString().padStart(2, "0")}`;
}

export function formatTime(date: Date): string {
  return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}
