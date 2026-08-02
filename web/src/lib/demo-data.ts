import type {
  DashboardData,
  ExerciseSeries,
  ProgressPoint,
  WorkoutRow,
} from "./dashboard-data";

// Deterministic sample data for the public demo dashboard: ~7 months of an
// A/B linear progression with occasional failed sessions and deloads, so the
// charts show the texture of real training rather than a straight line.

function lcg(seed: number): () => number {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 2 ** 32;
  };
}

interface DemoLift {
  key: string;
  name: string;
  startLb: number;
  incrementLb: number;
  /** Where this run of linear progression stalls out — fails cluster near it. */
  ceilingLb: number;
  sets: number;
  reps: number;
  day: "A" | "B" | "AB";
}

const LIFTS: DemoLift[] = [
  { key: "squat", name: "Squat", startLb: 135, incrementLb: 5, ceilingLb: 295, sets: 5, reps: 5, day: "AB" },
  { key: "bench", name: "Bench Press", startLb: 95, incrementLb: 5, ceilingLb: 200, sets: 5, reps: 5, day: "A" },
  { key: "row", name: "Barbell Row", startLb: 95, incrementLb: 5, ceilingLb: 175, sets: 5, reps: 5, day: "A" },
  { key: "ohp", name: "Overhead Press", startLb: 65, incrementLb: 5, ceilingLb: 130, sets: 5, reps: 5, day: "B" },
  { key: "deadlift", name: "Deadlift", startLb: 185, incrementLb: 10, ceilingLb: 365, sets: 1, reps: 5, day: "B" },
];

const DAY_MS = 86_400_000;

export function generateDemoData(): DashboardData {
  const rand = lcg(20260802);
  const weeks = 30;
  // Anchor "now" to the most recent Friday so the data always looks fresh.
  const now = new Date();
  const end = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const start = new Date(end.getTime() - weeks * 7 * DAY_MS);

  const weight: Record<string, number> = {};
  const fails: Record<string, number> = {};
  for (const l of LIFTS) {
    weight[l.key] = l.startLb;
    fails[l.key] = 0;
  }

  const series: Record<string, ProgressPoint[]> = Object.fromEntries(
    LIFTS.map((l) => [l.key, []])
  );
  const workouts: WorkoutRow[] = [];
  let totalVolumeLb = 0;
  let isDayA = true;

  for (let w = 0; w < weeks; w++) {
    for (const dow of [1, 3, 5]) {
      const dateMs = start.getTime() + (w * 7 + dow) * DAY_MS;
      if (dateMs > end.getTime()) break;
      // Life happens: skip ~7% of sessions.
      if (rand() < 0.07) continue;

      const dayLabel = isDayA ? "A" : "B";
      const dateS = Math.floor(dateMs / 1000) + 17 * 3600; // ~5pm session
      const lifts = LIFTS.filter((l) => l.day === "AB" || l.day === dayLabel);

      let workoutVolume = 0;
      let setCount = 0;
      let topExercise = "";
      let heaviestSetLb = 0;

      for (const l of lifts) {
        const wLb = weight[l.key];
        // Failure odds climb steeply near the lift's ceiling, so progress is
        // linear early and a believable sawtooth plateau late.
        const closeness = Math.min(wLb / l.ceilingLb, 1.05);
        const failChance = 0.04 + 0.7 * closeness ** 6;
        const failed = rand() < failChance;
        const reps = failed ? 3 + Math.floor(rand() * 2) : l.reps;
        const amrap =
          !failed && rand() < 0.2
            ? l.reps + 1 + Math.floor(rand() * 3 * (1.1 - closeness) + 1)
            : reps;
        const volume = l.sets * l.reps * wLb;
        const e1rm = wLb * (1 + amrap / 30);

        series[l.key].push({
          dateS,
          topWeightLb: wLb,
          topReps: amrap,
          e1rmLb: Math.round(e1rm * 10) / 10,
          volumeLb: volume,
          sets: l.sets,
        });

        workoutVolume += volume;
        setCount += l.sets;
        if (wLb > heaviestSetLb) {
          heaviestSetLb = wLb;
          topExercise = l.name;
        }

        if (failed) {
          fails[l.key] += 1;
          if (fails[l.key] >= 3) {
            weight[l.key] = Math.round((wLb * 0.9) / 5) * 5;
            fails[l.key] = 0;
          }
        } else {
          fails[l.key] = 0;
          weight[l.key] = wLb + l.incrementLb;
        }
      }

      const liftingS = setCount * (30 + Math.floor(rand() * 15));
      const restingS = setCount * (140 + Math.floor(rand() * 60));
      const yappingS = Math.floor((liftingS + restingS) * (0.1 + rand() * 0.3));
      const durationS = liftingS + restingS + yappingS + 300;

      workouts.push({
        id: `demo-${w}-${dow}`,
        name: `Workout ${dayLabel}`,
        startS: dateS,
        durationS,
        liftingS,
        restingS,
        yappingS,
        volumeLb: workoutVolume,
        topExercise,
        heaviestSetLb,
      });

      totalVolumeLb += workoutVolume;
      isDayA = !isDayA;
    }
  }

  workouts.reverse(); // newest first, matching the RPC

  const exercises: ExerciseSeries[] = LIFTS.map((l) => ({
    key: l.key,
    name: l.name,
    points: series[l.key],
  }));

  return {
    unit: "lb",
    workoutCount: workouts.length,
    totalVolumeLb,
    sinceS: workouts.length
      ? workouts[workouts.length - 1].startS
      : Math.floor(start.getTime() / 1000),
    exercises,
    workouts,
  };
}
