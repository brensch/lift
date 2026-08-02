import { workoutClient, settingsClient, authHeaders } from "./grpc";
import { exerciseName } from "./exercises";
import { WeightUnit } from "@/gen/workout/v1/settings_pb";
import type { DisplayUnit } from "./format";

// Plain view-model the dashboard renders. Both the live loader and the demo
// generator produce this shape, so the page never touches proto types.

export interface ProgressPoint {
  dateS: number;
  topWeightLb: number;
  topReps: number;
  e1rmLb: number;
  volumeLb: number;
  sets: number;
}

export interface ExerciseSeries {
  key: string;
  name: string;
  points: ProgressPoint[]; // oldest first
}

export interface WorkoutRow {
  id: string;
  name: string;
  startS: number;
  durationS: number;
  liftingS: number;
  restingS: number;
  yappingS: number;
  volumeLb: number;
  topExercise: string;
  heaviestSetLb: number;
}

export interface DashboardData {
  unit: DisplayUnit;
  workoutCount: number;
  totalVolumeLb: number;
  sinceS: number;
  exercises: ExerciseSeries[]; // most-improved first
  workouts: WorkoutRow[]; // newest first
}

export async function loadDashboardData(token: string): Promise<DashboardData> {
  const opts = authHeaders(token);
  const [progress, summaries, settings] = await Promise.all([
    workoutClient.getExerciseProgress({}, opts),
    workoutClient.listWorkoutSummaries({}, opts),
    // Unit preference is cosmetic — don't fail the dashboard over it.
    settingsClient.getSettings({}, opts).catch(() => null),
  ]);

  let unit: DisplayUnit = "lb";
  for (const s of settings?.settings ?? []) {
    if (s.setting.case === "weightUnit" && s.setting.value.unit === WeightUnit.KG) {
      unit = "kg";
    }
  }

  const exercises: ExerciseSeries[] = progress.exercises.map((ex) => ({
    key: String(ex.exercise),
    name: exerciseName(ex.exercise),
    points: ex.points.map((p) => ({
      dateS: Number(p.date),
      topWeightLb: p.topWeight,
      topReps: p.topReps,
      e1rmLb: p.bestOneRepMax,
      volumeLb: p.volume,
      sets: p.sets,
    })),
  }));

  const workouts: WorkoutRow[] = summaries.workouts
    .filter((w) => w.workout && w.summary)
    .map((w) => {
      const workout = w.workout!;
      const summary = w.summary!;
      const top = summary.exercises[0]; // sorted by volume, heaviest first
      return {
        id: workout.id,
        name: workout.name,
        startS: Number(workout.startTime),
        durationS: Number(summary.durationSeconds),
        liftingS: Number(summary.liftingSeconds),
        restingS: Number(summary.restingSeconds),
        yappingS: Number(summary.yappingSeconds),
        volumeLb: summary.totalVolume,
        topExercise: top ? exerciseName(top.exercise) : "—",
        heaviestSetLb: top?.heaviestSetWeight ?? 0,
      };
    });

  return {
    unit,
    workoutCount: progress.workoutCount,
    totalVolumeLb: progress.totalVolume,
    sinceS: Number(progress.since),
    exercises,
    workouts,
  };
}
