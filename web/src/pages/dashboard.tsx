import { useEffect, useMemo, useState } from "react";
import { Link, Navigate } from "react-router-dom";
import { WobblyText } from "@/components/wobbly-text";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/lib/use-auth";
import { LogOut, ArrowRight, Trophy } from "lucide-react";
import { loadDashboardData, type DashboardData } from "@/lib/dashboard-data";
import { generateDemoData } from "@/lib/demo-data";
import { ChartCard } from "@/components/charts/chart-card";
import { LineChart } from "@/components/charts/line-chart";
import { ColumnChart } from "@/components/charts/column-chart";
import { TimeBars } from "@/components/charts/time-bars";
import { Sparkline } from "@/components/charts/sparkline";
import { SERIES_1, SERIES_2, SERIES_3, CONTEXT } from "@/components/charts/chart-utils";
import {
  formatCompact,
  formatDate,
  formatDateFull,
  formatDuration,
  formatNumber,
  formatWeight,
  lbToDisplay,
  volumeComparison,
  type DisplayUnit,
} from "@/lib/format";
import {
  DAY_S,
  RANGES,
  exercisesInRange,
  rangeStart,
  weeklyVolume,
  workoutsInRange,
  type RangeKey,
} from "@/lib/range";
import { cn } from "@/lib/utils";

// Captured at module load — "last 30 days" doesn't need to tick live.
const NOW_S = Math.floor(Date.now() / 1000);

function RangePicker({ value, onChange }: { value: RangeKey; onChange: (k: RangeKey) => void }) {
  return (
    <div
      role="radiogroup"
      aria-label="Time range"
      className="inline-flex items-center gap-0.5 border border-border rounded-full bg-surface p-1"
    >
      {RANGES.map((r) => (
        <button
          key={r.key}
          role="radio"
          aria-checked={r.key === value}
          onClick={() => onChange(r.key)}
          className={cn(
            "px-3.5 py-1.5 rounded-full text-sm font-semibold transition-colors cursor-pointer",
            r.key === value ? "bg-primary text-on-primary" : "text-muted hover:text-text",
          )}
        >
          {r.label}
        </button>
      ))}
    </div>
  );
}

function Stat({ label, value, sub, accent }: { label: string; value: string; sub?: string; accent?: string }) {
  return (
    <div className="border border-border rounded-xl bg-surface p-5 min-w-0">
      <p className="text-sm text-muted font-medium m-0">{label}</p>
      <p
        className="font-display text-2xl sm:text-3xl font-bold tracking-tight mt-1.5 mb-0 text-text [font-variant-numeric:tabular-nums]"
        style={accent ? { color: accent } : undefined}
      >
        {value}
      </p>
      {sub && <p className="text-sm text-muted mt-1.5 mb-0 truncate">{sub}</p>}
    </div>
  );
}

export function DashboardPage({ demo = false }: { demo?: boolean }) {
  const { user, loading, logout } = useAuth();
  const [data, setData] = useState<DashboardData | null>(() => (demo ? generateDemoData() : null));
  const [error, setError] = useState<string | null>(null);
  const [range, setRange] = useState<RangeKey>("3m");
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
        if (!cancelled) setError(err instanceof Error ? err.message : "Failed to load your data");
      });
    return () => {
      cancelled = true;
    };
  }, [demo, user]);

  // Every number below is scoped to the same range. Hooks run unconditionally.
  const unit: DisplayUnit = data?.unit ?? "lb";
  const startS = data ? rangeStart(range, NOW_S, data.sinceS) : NOW_S;
  const workouts = useMemo(() => (data ? workoutsInRange(data, startS) : []), [data, startS]);
  const exercises = useMemo(() => (data ? exercisesInRange(data, startS) : []), [data, startS]);
  const chartable = useMemo(() => exercises.filter((e) => e.points.length >= 2), [exercises]);
  const selected = chartable.find((e) => e.series.key === selectedKey) ?? chartable[0] ?? null;
  const weekly = useMemo(() => weeklyVolume(workouts, startS, NOW_S), [workouts, startS]);

  const volumeLb = workouts.reduce((s, w) => s + w.volumeLb, 0);
  const gymS = workouts.reduce((s, w) => s + w.durationS, 0);
  const liftingS = workouts.reduce((s, w) => s + w.liftingS, 0);
  const yappingS = workouts.reduce((s, w) => s + w.yappingS, 0);
  const spanDays = Math.max(1, (NOW_S - startS) / DAY_S);
  const perWeek = (workouts.length / spanDays) * 7;
  const prs = exercises.filter((e) => e.isPr);
  const best = exercises.reduce<{ name: string; lb: number } | null>(
    (acc, e) => (!acc || e.bestLb > acc.lb ? { name: e.series.name, lb: e.bestLb } : acc),
    null,
  );

  if (!demo) {
    if (loading) {
      return (
        <div className="flex items-center justify-center min-h-[calc(100vh-10rem)]">
          <p className="text-muted">Loading...</p>
        </div>
      );
    }
    if (!user) return <Navigate to="/login" replace />;
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
  const rangeLabel = RANGES.find((r) => r.key === range)!.label;

  return (
    <div className="w-full px-5 md:px-8 xl:px-12 py-8">
      {demo && (
        <div className="border border-border rounded-xl bg-surface px-5 py-4 mb-6 flex flex-col sm:flex-row sm:items-center gap-3 justify-between">
          <p className="m-0 text-sm text-muted">
            <span className="text-text font-semibold">Sample data.</span> This is what your training
            looks like in Schlift — every set you log in the app builds this for real.
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

      {/* Header + the one filter row that scopes everything below it */}
      <div className="flex flex-wrap items-end justify-between gap-4 mb-6">
        <div>
          <h1 className="font-display text-[clamp(1.5rem,3vw,2.2rem)] font-extrabold tracking-tight m-0">
            <WobblyText text={demo ? "DEMO GAINS" : `HEY ${user!.username.toUpperCase()}`} seed={88} />
          </h1>
          <p className="text-muted mt-1 mb-0">
            {workouts.length} {workouts.length === 1 ? "workout" : "workouts"} in the last {rangeLabel === "All" ? "" : rangeLabel + " · "}
            {rangeLabel === "All" ? `since ${formatDateFull(data.sinceS)}` : `${formatNumber(perWeek)} a week`}
          </p>
        </div>
        <div className="flex items-center gap-3">
          <RangePicker value={range} onChange={setRange} />
          {!demo && (
            <Button variant="ghost" size="sm" onClick={logout}>
              <LogOut size={16} className="mr-1.5" />
              Sign out
            </Button>
          )}
        </div>
      </div>

      {!hasData ? (
        <div className="border border-border rounded-xl bg-surface p-10 text-center">
          <h2 className="font-display text-2xl font-bold tracking-tight m-0">Nothing here yet</h2>
          <p className="text-muted mt-3 max-w-md mx-auto leading-relaxed">
            Your dashboard fills itself in the moment you finish your first workout in the app.
            Until then, you can see what it'll look like.
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
      ) : workouts.length === 0 ? (
        <div className="border border-border rounded-xl bg-surface p-10 text-center">
          <h2 className="font-display text-2xl font-bold tracking-tight m-0">Nothing in the last {rangeLabel}</h2>
          <p className="text-muted mt-3 max-w-md mx-auto leading-relaxed">
            Widen the range to see earlier training.
          </p>
          <div className="mt-6 flex justify-center">
            <Button variant="primary" onClick={() => setRange("all")}>
              Show everything
            </Button>
          </div>
        </div>
      ) : (
        <>
          {/* KPI row for the range */}
          <div className="grid grid-cols-2 lg:grid-cols-5 gap-4">
            <Stat
              label="Workouts"
              value={String(workouts.length)}
              sub={`${formatNumber(perWeek)} a week`}
            />
            <Stat
              label="Volume"
              value={`${formatCompact(lbToDisplay(volumeLb, unit))} ${unit}`}
              sub={volumeComparison(volumeLb) ?? undefined}
            />
            <Stat
              label="Time in the gym"
              value={formatDuration(gymS)}
              sub={gymS > 0 ? `${Math.round((liftingS / gymS) * 100)}% lifting · ${Math.round((yappingS / gymS) * 100)}% yapping` : undefined}
            />
            <Stat
              label="Best est. 1RM"
              value={best ? formatWeight(best.lb, unit) : "—"}
              sub={best?.name}
            />
            <Stat
              label="New PRs"
              value={String(prs.length)}
              sub={prs.length ? prs.slice(0, 2).map((p) => p.series.name).join(", ") + (prs.length > 2 ? "…" : "") : "none in range"}
              accent={prs.length ? SERIES_3 : undefined}
            />
          </div>

          {/* Every lift at a glance — click one to open it below */}
          {exercises.length > 0 && (
            <section className="mt-8">
              <h2 className="font-display text-xl font-bold tracking-tight m-0 mb-4">Every lift</h2>
              <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-5 2xl:grid-cols-6 gap-4">
                {exercises.map((e) => {
                  const active = selected?.series.key === e.series.key;
                  const delta = lbToDisplay(e.deltaLb, unit);
                  return (
                    <button
                      key={e.series.key}
                      onClick={() => setSelectedKey(e.series.key)}
                      disabled={e.points.length < 2}
                      className={cn(
                        "text-left border rounded-xl bg-surface p-4 transition-colors cursor-pointer disabled:cursor-default min-w-0",
                        active ? "border-text" : "border-border hover:border-muted",
                      )}
                    >
                      <div className="flex items-baseline justify-between gap-2">
                        <p className="text-sm font-semibold m-0 truncate">{e.series.name}</p>
                        {e.isPr && (
                          <span className="flex items-center gap-1 text-[11px] font-semibold shrink-0" style={{ color: SERIES_3 }}>
                            <Trophy size={12} /> PR
                          </span>
                        )}
                      </div>
                      <p className="font-display text-2xl font-bold tracking-tight m-0 mt-1 [font-variant-numeric:tabular-nums]">
                        {formatWeight(e.bestLb, unit)}
                      </p>
                      <p
                        className="text-xs mt-0.5 mb-2 [font-variant-numeric:tabular-nums]"
                        style={{ color: delta > 0 ? SERIES_3 : delta < 0 ? SERIES_2 : undefined }}
                      >
                        {delta > 0 ? "+" : ""}
                        {formatNumber(delta)} {unit} est. 1RM
                      </p>
                      {e.points.length >= 2 ? (
                        <Sparkline
                          color={active ? SERIES_1 : CONTEXT}
                          points={e.points.map((p) => ({ x: p.dateS, y: lbToDisplay(p.e1rmLb, unit) }))}
                        />
                      ) : (
                        <p className="text-xs text-muted m-0 h-11 flex items-center">One session</p>
                      )}
                    </button>
                  );
                })}
              </div>
            </section>
          )}

          {/* The selected lift, full width */}
          {selected && (
            <section className="mt-6">
              <ChartCard
                title={selected.series.name}
                subtitle={`Estimated 1RM and heaviest working set, ${unit}, last ${rangeLabel}`}
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
                  height={360}
                  series={[
                    {
                      label: "Top set",
                      color: CONTEXT,
                      context: true,
                      points: selected.points.map((p) => ({ x: p.dateS, y: lbToDisplay(p.topWeightLb, unit) })),
                    },
                    {
                      label: "Est. 1RM",
                      color: SERIES_1,
                      points: selected.points.map((p) => ({ x: p.dateS, y: lbToDisplay(p.e1rmLb, unit) })),
                    },
                  ]}
                  yFormat={(v) => formatNumber(v, 0)}
                  tooltipExtra={(x) => {
                    const p = selected.points.find((pt) => pt.dateS === x);
                    return p ? `${p.sets} sets · top set × ${p.topReps} reps` : null;
                  }}
                />
              </ChartCard>
            </section>
          )}

          {/* Volume and time, side by side on wide screens */}
          <div className="mt-6 grid grid-cols-1 xl:grid-cols-3 gap-6 items-start">
            <div className="xl:col-span-2">
              <ChartCard
                title="Weekly volume"
                subtitle={`Working sets only, ${unit} per week`}
                table={{
                  head: ["Week of", "Sessions", `Volume (${unit})`],
                  numeric: [1, 2],
                  rows: [...weekly].reverse().map((w) => [
                    formatDateFull(w.weekS),
                    String(w.sessions),
                    formatNumber(lbToDisplay(w.volumeLb, unit), 0),
                  ]),
                }}
              >
                <ColumnChart
                  height={300}
                  data={weekly.map((w) => ({ label: formatDate(w.weekS), value: lbToDisplay(w.volumeLb, unit) }))}
                  color={SERIES_1}
                  yFormat={formatCompact}
                  tooltipValue={(c) => {
                    const w = weekly.find((x) => formatDate(x.weekS) === c.label);
                    return `${formatCompact(c.value)} ${unit} · ${w?.sessions ?? 0} ${w?.sessions === 1 ? "session" : "sessions"}`;
                  }}
                />
              </ChartCard>
            </div>

            <ChartCard
              title="Where the time goes"
              subtitle={`Last ${Math.min(workouts.length, 12)} sessions`}
              legend={[
                { label: "Lifting", color: SERIES_1, shape: "rect" },
                { label: "Resting", color: SERIES_2, shape: "rect" },
                { label: "Yapping", color: SERIES_3, shape: "rect" },
              ]}
              table={{
                head: ["Date", "Lifting", "Resting", "Yapping", "Total"],
                numeric: [1, 2, 3, 4],
                rows: workouts.slice(0, 12).map((w) => [
                  formatDateFull(w.startS),
                  formatDuration(w.liftingS),
                  formatDuration(w.restingS),
                  formatDuration(w.yappingS),
                  formatDuration(w.durationS),
                ]),
              }}
            >
              <TimeBars
                rows={workouts.slice(0, 12).map((w) => ({
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

          {/* Every workout in range */}
          <section className="mt-6">
            <div className="border border-border rounded-xl bg-surface p-5 sm:p-6">
              <h3 className="font-display font-bold text-base tracking-tight m-0 mb-4">
                Workouts, last {rangeLabel}
              </h3>
              <div className="overflow-x-auto max-h-[28rem] overflow-y-auto">
                <table className="w-full text-sm border-collapse">
                  <thead className="sticky top-0 bg-surface">
                    <tr>
                      {["Date", "Workout", "Duration", `Volume (${unit})`, "Top lift"].map((h, i) => (
                        <th
                          key={h}
                          className={cn(
                            "text-muted font-medium text-xs uppercase tracking-wider py-2 px-2 border-b border-border text-left",
                            (i === 2 || i === 3) && "text-right",
                          )}
                        >
                          {h}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {workouts.map((w) => (
                      <tr key={w.id}>
                        <td className="py-2 px-2 border-b border-border/40 text-text whitespace-nowrap">
                          {formatDateFull(w.startS)}
                        </td>
                        <td className="py-2 px-2 border-b border-border/40 text-text">{w.name || "Workout"}</td>
                        <td className="py-2 px-2 border-b border-border/40 text-text text-right [font-variant-numeric:tabular-nums]">
                          {formatDuration(w.durationS)}
                        </td>
                        <td className="py-2 px-2 border-b border-border/40 text-text text-right [font-variant-numeric:tabular-nums]">
                          {formatNumber(lbToDisplay(w.volumeLb, unit), 0)}
                        </td>
                        <td className="py-2 px-2 border-b border-border/40 text-muted whitespace-nowrap">
                          {w.topExercise}
                          {w.heaviestSetLb > 0 && (
                            <span className="text-text"> · {formatWeight(w.heaviestSetLb, unit)}</span>
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
