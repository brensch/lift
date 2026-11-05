import { test } from "node:test";
import assert from "node:assert/strict";
import type { DashboardData, ExerciseSeries, WorkoutRow } from "../src/lib/dashboard-data.ts";
import {
  DAY_S,
  exercisesInRange,
  resolveRange,
  weeklyVolume,
  workoutsInRange,
} from "../src/lib/range.ts";

// Run with TZ=America/Los_Angeles (the `test` script sets it), so local
// dates below cross a real DST change.

/** Unix seconds of a local date and time. */
const at = (y: number, m: number, d: number, h = 0) =>
  Math.floor(new Date(y, m - 1, d, h).getTime() / 1000);

const workout = (startS: number, volumeLb: number): WorkoutRow => ({
  id: String(startS),
  name: "W",
  startS,
  durationS: 3600,
  restingS: 0,
  volumeLb,
  topExercise: "squat",
  heaviestSetLb: 0,
});

const series = (key: string, points: [number, number][]): ExerciseSeries => ({
  key,
  name: key,
  points: points.map(([dateS, e1rmLb]) => ({
    dateS,
    e1rmLb,
    topWeightLb: e1rmLb,
    topReps: 1,
    volumeLb: 0,
    sets: 1,
  })),
});

const data = (exercises: ExerciseSeries[], workouts: WorkoutRow[] = []) =>
  ({ exercises, workouts }) as unknown as DashboardData;

test("the test zone has a DST change inside the weekly-volume case", () => {
  assert.notEqual(
    new Date(2026, 9, 19).getTimezoneOffset(),
    new Date(2026, 10, 9).getTimezoneOffset(),
    "run with TZ=America/Los_Angeles",
  );
});

test("weeklyVolume buckets by local Monday across a DST change", () => {
  // DST ends Sunday 2026-11-01 in Los Angeles.
  const workouts = [
    workout(at(2026, 10, 20, 18), 1000), // Tue, week of Mon Oct 19
    workout(at(2026, 10, 22, 18), 500), // Thu, same week
    workout(at(2026, 11, 3, 18), 2000), // Tue, week of Mon Nov 2 (after the change)
    workout(at(2026, 11, 9, 7), 3000), // Mon Nov 9 morning
  ];
  const weeks = weeklyVolume(workouts, at(2026, 10, 1), at(2026, 11, 12, 12));
  assert.deepEqual(weeks, [
    { weekS: at(2026, 10, 19), volumeLb: 1500, sessions: 2 },
    { weekS: at(2026, 10, 26), volumeLb: 0, sessions: 0 },
    { weekS: at(2026, 11, 2), volumeLb: 2000, sessions: 1 },
    { weekS: at(2026, 11, 9), volumeLb: 3000, sessions: 1 },
  ]);
});

test("weeklyVolume starts at the range start when workouts predate it", () => {
  const workouts = [workout(at(2026, 3, 4, 9), 100), workout(at(2026, 3, 25, 9), 200)];
  const weeks = weeklyVolume(workouts, at(2026, 3, 18), at(2026, 3, 26));
  assert.deepEqual(
    weeks.map((w) => w.weekS),
    [at(2026, 3, 16), at(2026, 3, 23)],
  );
  assert.equal(weeks[1].volumeLb, 200);
});

test("weeklyVolume of no workouts is empty", () => {
  assert.deepEqual(weeklyVolume([], 0, at(2026, 1, 1)), []);
});

test("exercisesInRange measures against the best before the range", () => {
  const start = at(2026, 6, 1);
  const out = exercisesInRange(
    data([
      // History before: best 300; in range best 310 is a PR, +10.
      series("squat", [
        [at(2026, 5, 1), 300],
        [at(2026, 5, 15), 290],
        [at(2026, 6, 5), 305],
        [at(2026, 6, 20), 310],
      ]),
      // History before: best 250; in range 240 is no PR, -10.
      series("bench", [
        [at(2026, 5, 1), 250],
        [at(2026, 6, 10), 240],
      ]),
      // No history before: last minus first, never a PR.
      series("row", [
        [at(2026, 6, 2), 100],
        [at(2026, 6, 30), 130],
      ]),
      // Nothing in range: left out.
      series("curl", [[at(2026, 5, 1), 80]]),
    ]),
    start,
  );
  assert.deepEqual(
    out.map((e) => [e.series.key, e.deltaLb, e.bestLb, e.isPr]),
    [
      ["row", 30, 130, false],
      ["squat", 10, 310, true],
      ["bench", -10, 240, false],
    ],
  );
  assert.equal(out[1].points.length, 2);
  assert.equal(out[1].lastDateS, at(2026, 6, 20));
});

test("exercisesInRange drops points after the end", () => {
  const out = exercisesInRange(
    data([
      series("squat", [
        [at(2026, 6, 1), 300],
        [at(2026, 7, 1), 400],
      ]),
    ]),
    at(2026, 5, 1),
    at(2026, 6, 15),
  );
  assert.equal(out[0].bestLb, 300);
});

test("workoutsInRange is inclusive at both ends", () => {
  const ws = [workout(10, 1), workout(20, 1), workout(30, 1)];
  assert.deepEqual(
    workoutsInRange(data([], ws), 10, 20).map((w) => w.startS),
    [10, 20],
  );
});

test("resolveRange: a custom range runs to the end of its last day", () => {
  const from = at(2026, 6, 1);
  const to = at(2026, 6, 10);
  const r = resolveRange({ preset: "custom", fromS: from, toS: to }, at(2026, 7, 1), 0);
  assert.equal(r.startS, from);
  assert.equal(r.endS, to + DAY_S - 1);
  assert.equal(r.label, "custom");
});

test("resolveRange: presets count back from now, All from the first workout", () => {
  const now = at(2026, 7, 1);
  const since = at(2025, 1, 1);
  assert.deepEqual(resolveRange({ preset: "1m" }, now, since), {
    startS: now - 30 * DAY_S,
    endS: now,
    label: "1M",
  });
  assert.equal(resolveRange({ preset: "all" }, now, since).startS, since);
});
