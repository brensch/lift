import type { DashboardData, ExerciseSeries, WorkoutRow } from "./dashboard-data";

// One time range scopes every chart, stat and table on the dashboard, so the
// numbers always agree with each other.

export const DAY_S = 86_400;

export type RangeKey = "1m" | "3m" | "6m" | "1y" | "all";

export const RANGES: { key: RangeKey; label: string; days: number | null }[] = [
  { key: "1m", label: "1M", days: 30 },
  { key: "3m", label: "3M", days: 91 },
  { key: "6m", label: "6M", days: 182 },
  { key: "1y", label: "1Y", days: 365 },
  { key: "all", label: "All", days: null },
];

export function rangeStart(key: RangeKey, nowS: number, sinceS: number): number {
  const r = RANGES.find((x) => x.key === key)!;
  return r.days === null ? Math.min(sinceS, nowS) : nowS - r.days * DAY_S;
}

/** The exercise's points in range, plus how it moved and whether it set a PR. */
export interface ExerciseInRange {
  series: ExerciseSeries;
  points: ExerciseSeries["points"];
  /** Best e1RM in range minus the best before the range started; with no
   *  history before, last minus first in range. */
  deltaLb: number;
  bestLb: number;
  /** Best e1RM in range beats every session before the range. */
  isPr: boolean;
  lastDateS: number;
}

export function exercisesInRange(
  data: DashboardData,
  startS: number,
  endS = Infinity,
): ExerciseInRange[] {
  const out: ExerciseInRange[] = [];
  for (const series of data.exercises) {
    const points = series.points.filter((p) => p.dateS >= startS && p.dateS <= endS);
    if (points.length === 0) continue;
    const before = series.points.filter((p) => p.dateS < startS);
    const bestBefore = before.length ? Math.max(...before.map((p) => p.e1rmLb)) : 0;
    const bestLb = Math.max(...points.map((p) => p.e1rmLb));
    const first = points[0].e1rmLb;
    const last = points[points.length - 1].e1rmLb;
    out.push({
      series,
      points,
      deltaLb: before.length ? bestLb - bestBefore : last - first,
      bestLb,
      isPr: bestBefore > 0 && bestLb > bestBefore,
      lastDateS: points[points.length - 1].dateS,
    });
  }
  // Most improved first; ties by most recent.
  return out.sort((a, b) => b.deltaLb - a.deltaLb || b.lastDateS - a.lastDateS);
}

export function workoutsInRange(
  data: DashboardData,
  startS: number,
  endS = Infinity,
): WorkoutRow[] {
  return data.workouts.filter((w) => w.startS >= startS && w.startS <= endS);
}

/** A preset or a custom window; resolved against now and the first workout. */
export type RangeState = { preset: RangeKey } | { preset: "custom"; fromS: number; toS: number };

export function resolveRange(
  state: RangeState,
  nowS: number,
  sinceS: number,
): { startS: number; endS: number; label: string } {
  if (state.preset === "custom") {
    return { startS: state.fromS, endS: state.toS + DAY_S - 1, label: "custom" };
  }
  const r = RANGES.find((x) => x.key === state.preset)!;
  return { startS: rangeStart(state.preset, nowS, sinceS), endS: nowS, label: r.label };
}

/** Bucket working-set volume by week (Monday start), zero-filling gaps. */
export function weeklyVolume(workouts: WorkoutRow[], startS: number, endS: number) {
  const nowS = endS;
  // Local-midnight Monday of the week. Weeks are stepped by calendar date, not
  // a fixed 7 * DAY_S, so they still line up after a DST change.
  const mondayOf = (s: number) => {
    const d = new Date(s * 1000);
    const day = (d.getDay() + 6) % 7; // Monday = 0
    return new Date(d.getFullYear(), d.getMonth(), d.getDate() - day);
  };
  const weekOf = (s: number) => Math.floor(mondayOf(s).getTime() / 1000);
  const sums = new Map<number, { volumeLb: number; sessions: number }>();
  for (const w of workouts) {
    const k = weekOf(w.startS);
    const cur = sums.get(k) ?? { volumeLb: 0, sessions: 0 };
    sums.set(k, { volumeLb: cur.volumeLb + w.volumeLb, sessions: cur.sessions + 1 });
  }
  if (sums.size === 0) return [];
  const lastWeek = weekOf(nowS);
  const out: { weekS: number; volumeLb: number; sessions: number }[] = [];
  const monday = mondayOf(Math.max(startS, Math.min(...workouts.map((w) => w.startS))));
  for (let k = monday.getTime() / 1000; k <= lastWeek; k = monday.getTime() / 1000) {
    const v = sums.get(k);
    out.push({ weekS: k, volumeLb: v?.volumeLb ?? 0, sessions: v?.sessions ?? 0 });
    monday.setDate(monday.getDate() + 7);
  }
  return out;
}
