import { useEffect, useMemo, useState } from "react";
import { Link, Navigate } from "react-router-dom";
import { WobblyText } from "@/components/wobbly-text";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/lib/use-auth";
import { LogOut, ArrowRight } from "lucide-react";
import {
  loadDashboardData,
  type DashboardData,
  type WorkoutRow,
} from "@/lib/dashboard-data";
import { generateDemoData } from "@/lib/demo-data";
import { StatTile } from "@/components/charts/stat-tile";
import { ChartCard } from "@/components/charts/chart-card";
import { LineChart } from "@/components/charts/line-chart";
import { ColumnChart } from "@/components/charts/column-chart";
import { TimeBars } from "@/components/charts/time-bars";
import {
  SERIES_1,
  SERIES_2,
  SERIES_3,
  CONTEXT,
} from "@/components/charts/chart-utils";
import {
  formatCompact,
  formatDate,
  formatDateFull,
  formatDuration,
  formatMonthYear,
  formatNumber,
  formatWeight,
  lbToDisplay,
  volumeComparison,
  type DisplayUnit,
} from "@/lib/format";
import { cn } from "@/lib/utils";

const DAY_S = 86_400;
const WEEK_S = 7 * DAY_S;

// Captured at module load — "last 30 days" doesn't need to tick live.
const NOW_S = Math.floor(Date.now() / 1000);

/** Bucket working-set volume by week (Monday start), zero-filling gaps. */
function weeklyVolume(workouts: WorkoutRow[], maxWeeks: number) {
  if (workouts.length === 0) return [];
  const weekOf = (s: number) => {
    const d = new Date(s * 1000);
    const day = (d.getDay() + 6) % 7; // Monday = 0
    const monday = new Date(d.getFullYear(), d.getMonth(), d.getDate() - day);
    return Math.floor(monday.getTime() / 1000);
  };
  const sums = new Map<number, number>();
  for (const w of workouts) {
    const k = weekOf(w.startS);
    sums.set(k, (sums.get(k) ?? 0) + w.volumeLb);
  }
  const keys = [...sums.keys()].sort((a, b) => a - b);
  const lastWeek = keys[keys.length - 1];
  const firstWeek = Math.max(keys[0], lastWeek - (maxWeeks - 1) * WEEK_S);
  const out: { weekS: number; volumeLb: number }[] = [];
  for (let k = firstWeek; k <= lastWeek; k += WEEK_S) {
    out.push({ weekS: k, volumeLb: sums.get(k) ?? 0 });
  }
  return out;
}

export function DashboardPage({ demo = false }: { demo?: boolean }) {
  const { user, loading, logout } = useAuth();
  // Demo data is synchronous — seed it at mount instead of via an effect.
  const [data, setData] = useState<DashboardData | null>(() =>
    demo ? generateDemoData() : null
  );
  const [error, setError] = useState<string | null>(null);
  const [selectedKey, setSelectedKey] = useState<string | null>(null);

  useEffect(() => {
    if (demo || !user) return;
    let cancelled = false;
    loadDashboardData(user.sessionToken)
      .then((d) => {
        if (!cancelled) {
          setError(null);
          setData(d);
        }
      })
      .catch((err: unknown) => {
        if (!cancelled) {
          setError(err instanceof Error ? err.message : "Failed to load your data");
        }
      });
    return () => {
      cancelled = true;
    };
  }, [demo, user]);

  // Everything below needs data; hooks must run unconditionally.
  const chartable = useMemo(
    () => (data?.exercises ?? []).filter((e) => e.points.length >= 2),
    [data]
  );
  const selected =
    chartable.find((e) => e.key === selectedKey) ?? chartable[0] ?? null;
  const unit: DisplayUnit = data?.unit ?? "lb";

  const bestLift = useMemo(() => {
    let best: { name: string; e1rmLb: number } | null = null;
    for (const ex of data?.exercises ?? []) {
      for (const p of ex.points) {
        if (!best || p.e1rmLb > best.e1rmLb) best = { name: ex.name, e1rmLb: p.e1rmLb };
      }
    }
    return best;
  }, [data]);

  const last30 = useMemo(
    () => (data?.workouts ?? []).filter((w) => w.startS > NOW_S - 30 * DAY_S).length,
    [data]
  );

  const weekly = useMemo(
    () => weeklyVolume(data?.workouts ?? [], 26),
    [data]
  );

  if (!demo) {
    if (loading) {
      return (
        <div className="flex items-center justify-center min-h-[calc(100vh-10rem)]">
          <p className="text-muted">Loading...</p>
        </div>
      );
    }
    if (!user) {
      return <Navigate to="/login" replace />;
    }
  }

  if (error) {
    return (
      <div className="flex items-center justify-center min-h-[calc(100vh-10rem)] px-5">
        <div className="border border-border rounded-xl bg-surface p-8 max-w-md text-center">
          <p className="text-danger font-semibold m-0">Couldn't load your data</p>
          <p className="text-muted text-sm mt-2">{error}</p>
          <Button className="mt-5" onClick={() => window.location.reload()}>
            Try again
          </Button>
        </div>
      </div>
    );
  }

  if (!data) {
    return (
      <div className="flex items-center justify-center min-h-[calc(100vh-10rem)]">
        <p className="text-muted">Loading...</p>
      </div>
    );
  }

  const hasData = data.workoutCount > 0;

  return (
    <div className="max-w-5xl mx-auto px-5 py-10">
      {demo && (
        <div className="border border-border rounded-xl bg-surface px-5 py-4 mb-8 flex flex-col sm:flex-row sm:items-center gap-3 justify-between">
          <p className="m-0 text-sm text-muted">
            <span className="text-text font-semibold">Sample data.</span> This
            is what your training looks like in Schlift — every set you log in
            the app builds this for real.
          </p>
          <div className="flex gap-2 shrink-0">
            <Link to="/" className="no-underline">
              <Button size="sm" variant="primary">
                Get the app
                <ArrowRight size={14} className="ml-1.5" />
              </Button>
            </Link>
            <Link to="/login" className="no-underline">
              <Button size="sm">Sign in</Button>
            </Link>
          </div>
        </div>
      )}

      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="font-display text-[clamp(1.5rem,3vw,2.2rem)] font-extrabold tracking-tight m-0">
            <WobblyText
              text={demo ? "DEMO GAINS" : `HEY ${user!.username.toUpperCase()}`}
              seed={88}
            />
          </h1>
          <p className="text-muted mt-1">Your training, on the big screen.</p>
        </div>
        {!demo && (
          <Button variant="ghost" size="sm" onClick={logout}>
            <LogOut size={16} className="mr-1.5" />
            Sign Out
          </Button>
        )}
      </div>

      {!hasData ? (
        <div className="border border-border rounded-xl bg-surface p-10 text-center">
          <h2 className="font-display text-2xl font-bold tracking-tight m-0">
            Nothing here yet
          </h2>
          <p className="text-muted mt-3 max-w-md mx-auto leading-relaxed">
            Your dashboard fills itself in the moment you finish your first
            workout in the app. Until then, you can see what it'll look like.
          </p>
          <div className="mt-6 flex gap-3 justify-center flex-wrap">
            <Link to="/demo" className="no-underline">
              <Button variant="primary">
                View sample dashboard
                <ArrowRight size={15} className="ml-1.5" />
              </Button>
            </Link>
          </div>
        </div>
      ) : (
        <>
          {/* KPI row */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <StatTile
              label="Workouts"
              value={formatNumber(data.workoutCount, 0)}
              sub={`since ${formatMonthYear(data.sinceS)}`}
            />
            <StatTile
              label="Total volume"
              value={`${formatCompact(lbToDisplay(data.totalVolumeLb, unit))} ${unit}`}
              sub={volumeComparison(data.totalVolumeLb) ?? undefined}
            />
            <StatTile
              label="Best est. 1RM"
              value={bestLift ? formatWeight(bestLift.e1rmLb, unit) : "—"}
              sub={bestLift?.name}
            />
            <StatTile
              label="Last 30 days"
              value={String(last30)}
              sub={`${last30 === 1 ? "session" : "sessions"} · ${formatNumber((last30 / 30) * 7)} per week`}
            />
          </div>

          {/* Progression */}
          {chartable.length > 0 && selected && (
            <section className="mt-10">
              <div className="flex flex-wrap items-baseline gap-x-4 gap-y-2 mb-4">
                <h2 className="font-display text-xl font-bold tracking-tight m-0">
                  Progression
                </h2>
                <div className="flex flex-wrap gap-1.5">
                  {chartable.map((ex) => (
                    <button
                      key={ex.key}
                      onClick={() => setSelectedKey(ex.key)}
                      className={cn(
                        "px-3 py-1 rounded-full text-xs font-medium border transition-colors cursor-pointer",
                        ex.key === selected.key
                          ? "bg-primary text-on-primary border-primary"
                          : "bg-transparent text-muted border-border hover:text-text"
                      )}
                    >
                      {ex.name}
                    </button>
                  ))}
                </div>
              </div>
              <ChartCard
                title={selected.name}
                subtitle={`Estimated 1RM vs heaviest working set, ${unit}`}
                legend={[
                  { label: "Est. 1RM", color: SERIES_1, shape: "line" },
                  { label: "Top set", color: CONTEXT, shape: "line" },
                ]}
                table={{
                  head: ["Date", `Top set (${unit})`, "Reps", `Est. 1RM (${unit})`, `Volume (${unit})`],
                  numeric: [1, 2, 3, 4],
                  rows: [...selected.points].reverse().map((p) => [
                    formatDateFull(p.dateS),
                    formatNumber(lbToDisplay(p.topWeightLb, unit)),
                    String(p.topReps),
                    formatNumber(lbToDisplay(p.e1rmLb, unit)),
                    formatNumber(lbToDisplay(p.volumeLb, unit), 0),
                  ]),
                }}
              >
                <LineChart
                  series={[
                    {
                      label: "Top set",
                      color: CONTEXT,
                      context: true,
                      points: selected.points.map((p) => ({
                        x: p.dateS,
                        y: lbToDisplay(p.topWeightLb, unit),
                      })),
                    },
                    {
                      label: "Est. 1RM",
                      color: SERIES_1,
                      points: selected.points.map((p) => ({
                        x: p.dateS,
                        y: lbToDisplay(p.e1rmLb, unit),
                      })),
                    },
                  ]}
                  yFormat={(v) => formatNumber(v, 0)}
                  tooltipExtra={(x) => {
                    const p = selected.points.find((pt) => pt.dateS === x);
                    return p
                      ? `${p.sets} sets · top set × ${p.topReps} reps`
                      : null;
                  }}
                />
              </ChartCard>
            </section>
          )}

          {/* Volume + time */}
          <div className="mt-6 grid grid-cols-1 lg:grid-cols-2 gap-6 items-start">
            <ChartCard
              title="Weekly volume"
              subtitle={`Working sets only, ${unit} per week`}
              table={{
                head: ["Week of", `Volume (${unit})`],
                numeric: [1],
                rows: [...weekly].reverse().map((w) => [
                  formatDateFull(w.weekS),
                  formatNumber(lbToDisplay(w.volumeLb, unit), 0),
                ]),
              }}
            >
              <ColumnChart
                data={weekly.map((w) => ({
                  label: formatDate(w.weekS),
                  value: lbToDisplay(w.volumeLb, unit),
                }))}
                color={SERIES_1}
                yFormat={formatCompact}
                tooltipValue={(c) => `${formatCompact(c.value)} ${unit} lifted`}
              />
            </ChartCard>

            <ChartCard
              title="Where the time goes"
              subtitle="Last 8 sessions"
              legend={[
                { label: "Lifting", color: SERIES_1, shape: "rect" },
                { label: "Resting", color: SERIES_2, shape: "rect" },
                { label: "Yapping", color: SERIES_3, shape: "rect" },
              ]}
              table={{
                head: ["Date", "Lifting", "Resting", "Yapping", "Total"],
                numeric: [1, 2, 3, 4],
                rows: data.workouts.slice(0, 8).map((w) => [
                  formatDateFull(w.startS),
                  formatDuration(w.liftingS),
                  formatDuration(w.restingS),
                  formatDuration(w.yappingS),
                  formatDuration(w.durationS),
                ]),
              }}
            >
              <TimeBars
                rows={data.workouts.slice(0, 8).map((w) => ({
                  label: formatDate(w.startS),
                  title: `${w.name} — ${formatDateFull(w.startS)}`,
                  segments: [
                    { label: "Lifting", color: SERIES_1, seconds: w.liftingS },
                    { label: "Resting", color: SERIES_2, seconds: w.restingS },
                    { label: "Yapping", color: SERIES_3, seconds: w.yappingS },
                  ],
                }))}
              />
            </ChartCard>
          </div>

          {/* Recent workouts */}
          <section className="mt-6">
            <div className="border border-border rounded-xl bg-surface p-5 sm:p-6">
              <h3 className="font-display font-bold text-base tracking-tight m-0 mb-4">
                Recent workouts
              </h3>
              <div className="overflow-x-auto">
                <table className="w-full text-sm border-collapse">
                  <thead>
                    <tr>
                      {["Date", "Workout", "Duration", `Volume (${unit})`, "Top lift"].map(
                        (h, i) => (
                          <th
                            key={h}
                            className={cn(
                              "text-muted font-medium text-xs uppercase tracking-wider py-2 px-2 border-b border-border text-left",
                              (i === 2 || i === 3) && "text-right"
                            )}
                          >
                            {h}
                          </th>
                        )
                      )}
                    </tr>
                  </thead>
                  <tbody>
                    {data.workouts.slice(0, 10).map((w) => (
                      <tr key={w.id}>
                        <td className="py-2 px-2 border-b border-border/40 text-text whitespace-nowrap">
                          {formatDateFull(w.startS)}
                        </td>
                        <td className="py-2 px-2 border-b border-border/40 text-text">
                          {w.name || "Workout"}
                        </td>
                        <td className="py-2 px-2 border-b border-border/40 text-text text-right [font-variant-numeric:tabular-nums]">
                          {formatDuration(w.durationS)}
                        </td>
                        <td className="py-2 px-2 border-b border-border/40 text-text text-right [font-variant-numeric:tabular-nums]">
                          {formatNumber(lbToDisplay(w.volumeLb, unit), 0)}
                        </td>
                        <td className="py-2 px-2 border-b border-border/40 text-muted whitespace-nowrap">
                          {w.topExercise}
                          {w.heaviestSetLb > 0 && (
                            <span className="text-text">
                              {" "}
                              · {formatWeight(w.heaviestSetLb, unit)}
                            </span>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </section>
        </>
      )}
    </div>
  );
}
