import { useEffect, useMemo, useState } from "react";
import { Link, Navigate } from "react-router-dom";
import { WobblyText } from "@/components/wobbly-text";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/lib/use-auth";
import { LogOut, ArrowRight, Trophy, ChevronDown } from "lucide-react";
import { loadDashboardData, type DashboardData } from "@/lib/dashboard-data";
import { generateDemoData } from "@/lib/demo-data";
import { ChartCard } from "@/components/charts/chart-card";
import { LineChart } from "@/components/charts/line-chart";
import { ColumnChart } from "@/components/charts/column-chart";
import { TimeBars } from "@/components/charts/time-bars";
import { Sparkline } from "@/components/charts/sparkline";
import { RangePicker } from "@/components/dashboard/range-picker";
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
  exercisesInRange,
  resolveRange,
  weeklyVolume,
  workoutsInRange,
  type RangeState,
} from "@/lib/range";
import { cn } from "@/lib/utils";

// Captured at module load — "last 30 days" doesn't need to tick live.
const NOW_S = Math.floor(Date.now() / 1000);

/** A one-line stat: label left, value right. Five of these make one strip. */
function Stat({
  label,
  value,
  sub,
  accent,
}: {
  label: string;
  value: string;
  sub?: string;
  accent?: string;
}) {
  return (
    <div className="border border-border rounded-xl bg-surface px-4 py-3 min-w-0 flex flex-col gap-1 sm:flex-row sm:items-baseline sm:justify-between sm:gap-3">
      <div className="min-w-0">
        <p className="text-xs uppercase tracking-wider text-muted m-0">{label}</p>
        {sub && <p className="text-xs text-muted mt-0.5 mb-0 truncate">{sub}</p>}
      </div>
      <p
        className="font-display text-2xl font-bold tracking-tight m-0 text-text [font-variant-numeric:tabular-nums] shrink-0 order-first sm:order-none"
        style={accent ? { color: accent } : undefined}
      >
        {value}
      </p>
    </div>
  );
}

function Select({
  value,
  onChange,
  options,
  ariaLabel,
}: {
  value: string;
  onChange: (v: string) => void;
  options: { value: string; label: string }[];
  ariaLabel: string;
}) {
  return (
    <span className="relative inline-flex">
      <select
        aria-label={ariaLabel}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="h-9 appearance-none pl-3 pr-8 rounded-lg border border-border bg-surface text-sm font-semibold text-text hover:border-muted transition-colors cursor-pointer"
      >
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
      <ChevronDown
        size={14}
        className="pointer-events-none absolute right-2.5 top-1/2 -translate-y-1/2 text-muted"
      />
    </span>
  );
}

export function DashboardPage({ demo = false }: { demo?: boolean }) {
  const { user, loading, logout } = useAuth();
  const [data, setData] = useState<DashboardData | null>(() => (demo ? generateDemoData() : null));
  const [error, setError] = useState<string | null>(null);
  const [range, setRange] = useState<RangeState>({ preset: "3m" });
  const [selectedKey, setSelectedKey] = useState<string | null>(null);
  const [bottomTab, setBottomTab] = useState<"time" | "workouts">("time");

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
  const sinceS = data?.sinceS ?? NOW_S;
  const { startS, endS, label: rangeLabel } = resolveRange(range, NOW_S, sinceS);
  const workouts = useMemo(
    () => (data ? workoutsInRange(data, startS, endS) : []),
    [data, startS, endS],
  );
  const exercises = useMemo(
    () => (data ? exercisesInRange(data, startS, endS) : []),
    [data, startS, endS],
  );
  const chartable = useMemo(() => exercises.filter((e) => e.points.length >= 2), [exercises]);
  const selected = chartable.find((e) => e.series.key === selectedKey) ?? chartable[0] ?? null;
  const weekly = useMemo(() => weeklyVolume(workouts, startS, endS), [workouts, startS, endS]);

  const volumeLb = workouts.reduce((s, w) => s + w.volumeLb, 0);
  const gymS = workouts.reduce((s, w) => s + w.durationS, 0);
  const liftingS = workouts.reduce((s, w) => s + w.liftingS, 0);
  const yappingS = workouts.reduce((s, w) => s + w.yappingS, 0);
  const spanDays = Math.max(1, (endS - startS) / DAY_S);
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
  const rangeWords =
    range.preset === "custom"
      ? "in this range"
      : range.preset === "all"
        ? "all time"
        : `in the last ${rangeLabel}`;

  return (
    // On large screens the whole dashboard is one viewport: header row, stat
    // strip, then two rows of cards that share the remaining height. Below
    // that it stacks and scrolls like a normal page.
    <div className="w-full px-4 md:px-6 py-4 lg:h-[calc(100vh-4rem)] lg:flex lg:flex-col lg:gap-3">
      {/* Header + controls */}
      <div className="flex flex-wrap items-center justify-between gap-3 shrink-0">
        <div className="flex items-baseline gap-3 min-w-0">
          <h1 className="font-display text-2xl font-extrabold tracking-tight m-0 shrink-0">
            <WobblyText
              text={demo ? "DEMO GAINS" : `HEY ${user!.username.toUpperCase()}`}
              seed={88}
            />
          </h1>
          {hasData && (
            <p className="text-sm text-muted m-0 truncate">
              {workouts.length} {workouts.length === 1 ? "workout" : "workouts"} {rangeWords}
              {range.preset !== "all" && workouts.length > 0
                ? ` · ${formatNumber(perWeek)} a week`
                : ""}
            </p>
          )}
          {demo && (
            <span className="hidden md:inline text-xs text-muted border border-border rounded-full px-2 py-0.5">
              sample data
            </span>
          )}
        </div>
        <div className="flex items-center gap-2 flex-wrap">
          {chartable.length > 0 && selected && (
            <Select
              ariaLabel="Lift"
              value={selected.series.key}
              onChange={setSelectedKey}
              options={chartable.map((e) => ({ value: e.series.key, label: e.series.name }))}
            />
          )}
          {hasData && (
            <RangePicker value={range} onChange={setRange} nowS={NOW_S} sinceS={data.sinceS} />
          )}
          {demo ? (
            <Link to="/" className="no-underline">
              <Button size="sm" variant="primary">
                Get the app
                <ArrowRight size={14} className="ml-1.5" />
              </Button>
            </Link>
          ) : (
            <Button variant="ghost" size="sm" onClick={logout} aria-label="Sign out">
              <LogOut size={16} />
            </Button>
          )}
        </div>
      </div>

      {!hasData ? (
        <div className="border border-border rounded-xl bg-surface p-10 text-center mt-4">
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
        <div className="border border-border rounded-xl bg-surface p-10 text-center mt-4">
          <h2 className="font-display text-2xl font-bold tracking-tight m-0">
            Nothing {rangeWords}
          </h2>
          <p className="text-muted mt-3 max-w-md mx-auto leading-relaxed">
            Widen the range to see earlier training.
          </p>
          <div className="mt-6 flex justify-center">
            <Button variant="primary" onClick={() => setRange({ preset: "all" })}>
              Show everything
            </Button>
          </div>
        </div>
      ) : (
        <>
          {/* Stat strip */}
          <div className="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-5 gap-3 mt-3 lg:mt-0 shrink-0">
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
              label="In the gym"
              value={formatDuration(gymS)}
              sub={
                gymS > 0
                  ? `${Math.round((liftingS / gymS) * 100)}% lifting · ${Math.round((yappingS / gymS) * 100)}% yapping`
                  : undefined
              }
            />
            <Stat
              label="Best est. 1RM"
              value={best ? formatWeight(best.lb, unit) : "—"}
              sub={best?.name}
            />
            <Stat
              label="New PRs"
              value={String(prs.length)}
              sub={prs.length ? prs.map((p) => p.series.name).join(", ") : "none in range"}
              accent={prs.length ? SERIES_3 : undefined}
            />
          </div>

          {/* Row 1: the selected lift (wide) + every lift (list) */}
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-3 mt-3 lg:mt-0 lg:flex-1 lg:min-h-0">
            <div className="lg:col-span-8 min-h-[22rem] lg:min-h-0">
              {selected ? (
                <ChartCard
                  fill
                  title={selected.series.name}
                  subtitle={`Est. 1RM and heaviest working set, ${unit}`}
                  legend={[
                    { label: "Est. 1RM", color: SERIES_1, shape: "line" },
                    { label: "Top set", color: CONTEXT, shape: "line" },
                  ]}
                  table={{
                    head: [
                      "Date",
                      `Top set (${unit})`,
                      "Reps",
                      `Est. 1RM (${unit})`,
                      `Volume (${unit})`,
                    ],
                    numeric: [1, 2, 3, 4],
                    rows: [...selected.points]
                      .reverse()
                      .map((p) => [
                        formatDateFull(p.dateS),
                        formatNumber(lbToDisplay(p.topWeightLb, unit)),
                        String(p.topReps),
                        formatNumber(lbToDisplay(p.e1rmLb, unit)),
                        formatNumber(lbToDisplay(p.volumeLb, unit), 0),
                      ]),
                  }}
                >
                  <LineChart
                    height="fill"
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
                      return p ? `${p.sets} sets · top set × ${p.topReps} reps` : null;
                    }}
                  />
                </ChartCard>
              ) : (
                <div className="h-full border border-border rounded-xl bg-surface flex items-center justify-center text-sm text-muted">
                  Two sessions of a lift and its chart appears here.
                </div>
              )}
            </div>

            <div className="lg:col-span-4 min-h-0 border border-border rounded-xl bg-surface p-4 sm:p-5 flex flex-col">
              <div className="flex items-baseline justify-between mb-2 shrink-0">
                <h3 className="font-display font-bold text-base tracking-tight m-0">Every lift</h3>
                <span className="text-xs text-muted">best est. 1RM · change {rangeWords}</span>
              </div>
              <ul className="m-0 p-0 list-none overflow-y-auto min-h-0 flex-1 max-h-[22rem] lg:max-h-none divide-y divide-border/40">
                {exercises.map((e) => {
                  const active = selected?.series.key === e.series.key;
                  const delta = lbToDisplay(e.deltaLb, unit);
                  return (
                    <li key={e.series.key}>
                      <button
                        onClick={() => setSelectedKey(e.series.key)}
                        disabled={e.points.length < 2}
                        className={cn(
                          "w-full grid grid-cols-[1fr_auto_auto] items-center gap-3 py-2 px-2 -mx-2 rounded-lg text-left transition-colors cursor-pointer disabled:cursor-default",
                          active ? "bg-white/[0.05]" : "hover:bg-white/[0.03]",
                        )}
                      >
                        <span className="min-w-0">
                          <span className="flex items-center gap-1.5 text-sm font-semibold truncate">
                            {e.series.name}
                            {e.isPr && (
                              <Trophy size={12} style={{ color: SERIES_3 }} aria-label="PR" />
                            )}
                          </span>
                          <span
                            className="block text-xs [font-variant-numeric:tabular-nums]"
                            style={{
                              color:
                                delta > 0 ? SERIES_3 : delta < 0 ? SERIES_2 : "var(--color-muted)",
                            }}
                          >
                            {delta > 0 ? "+" : ""}
                            {formatNumber(delta)} {unit}
                          </span>
                        </span>
                        <span className="w-16">
                          {e.points.length >= 2 && (
                            <Sparkline
                              height={28}
                              color={active ? SERIES_1 : CONTEXT}
                              points={e.points.map((p) => ({
                                x: p.dateS,
                                y: lbToDisplay(p.e1rmLb, unit),
                              }))}
                            />
                          )}
                        </span>
                        <span className="font-display text-lg font-bold tracking-tight [font-variant-numeric:tabular-nums] text-right w-20">
                          {formatWeight(e.bestLb, unit)}
                        </span>
                      </button>
                    </li>
                  );
                })}
              </ul>
            </div>
          </div>

          {/* Row 2: weekly volume (wide) + time in gym / workouts (tabs) */}
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-3 mt-3 lg:mt-0 lg:flex-1 lg:min-h-0">
            <div className="lg:col-span-8 min-h-[18rem] lg:min-h-0">
              <ChartCard
                fill
                title="Weekly volume"
                subtitle={`Working sets, ${unit} per week`}
                table={{
                  head: ["Week of", "Sessions", `Volume (${unit})`],
                  numeric: [1, 2],
                  rows: [...weekly]
                    .reverse()
                    .map((w) => [
                      formatDateFull(w.weekS),
                      String(w.sessions),
                      formatNumber(lbToDisplay(w.volumeLb, unit), 0),
                    ]),
                }}
              >
                <ColumnChart
                  height="fill"
                  data={weekly.map((w) => ({
                    label: formatDate(w.weekS),
                    value: lbToDisplay(w.volumeLb, unit),
                  }))}
                  color={SERIES_1}
                  yFormat={formatCompact}
                  tooltipValue={(c) => {
                    const w = weekly.find((x) => formatDate(x.weekS) === c.label);
                    return `${formatCompact(c.value)} ${unit} · ${w?.sessions ?? 0} ${w?.sessions === 1 ? "session" : "sessions"}`;
                  }}
                />
              </ChartCard>
            </div>

            <div className="lg:col-span-4 min-h-0 border border-border rounded-xl bg-surface p-4 sm:p-5 flex flex-col">
              <div className="flex items-center justify-between mb-2 shrink-0">
                <div className="inline-flex border border-border rounded-lg p-0.5">
                  {(["time", "workouts"] as const).map((t) => (
                    <button
                      key={t}
                      onClick={() => setBottomTab(t)}
                      className={cn(
                        "px-2.5 py-1 rounded-md text-xs font-semibold cursor-pointer transition-colors",
                        bottomTab === t
                          ? "bg-primary text-on-primary"
                          : "text-muted hover:text-text",
                      )}
                    >
                      {t === "time" ? "Where the time goes" : "Workouts"}
                    </button>
                  ))}
                </div>
                {bottomTab === "time" && (
                  <div className="hidden xl:flex items-center gap-3 text-[11px] text-muted">
                    {[
                      ["Lifting", SERIES_1],
                      ["Resting", SERIES_2],
                      ["Yapping", SERIES_3],
                    ].map(([l, c]) => (
                      <span key={l} className="flex items-center gap-1">
                        <span
                          className="inline-block w-2 h-2 rounded-[2px]"
                          style={{ background: c }}
                        />
                        {l}
                      </span>
                    ))}
                  </div>
                )}
              </div>
              <div className="overflow-auto min-h-0 flex-1 max-h-[22rem] lg:max-h-none">
                {bottomTab === "time" ? (
                  <TimeBars
                    rows={workouts.map((w) => ({
                      label: formatDate(w.startS),
                      title: `${w.name} — ${formatDateFull(w.startS)}`,
                      segments: [
                        { label: "Lifting", color: SERIES_1, seconds: w.liftingS },
                        { label: "Resting", color: SERIES_2, seconds: w.restingS },
                        { label: "Yapping", color: SERIES_3, seconds: w.yappingS },
                      ],
                    }))}
                  />
                ) : (
                  <table className="w-full text-sm border-collapse">
                    <thead className="sticky top-0 bg-surface">
                      <tr>
                        {["Date", "Workout", "Time", unit, "Top lift"].map((h, i) => (
                          <th
                            key={h}
                            className={cn(
                              "text-muted font-medium text-[11px] uppercase tracking-wider py-1.5 px-1.5 border-b border-border text-left",
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
                          <td className="py-1.5 px-1.5 border-b border-border/40 whitespace-nowrap">
                            {formatDate(w.startS)}
                          </td>
                          <td className="py-1.5 px-1.5 border-b border-border/40 truncate max-w-[8rem]">
                            {w.name || "Workout"}
                          </td>
                          <td className="py-1.5 px-1.5 border-b border-border/40 text-right [font-variant-numeric:tabular-nums]">
                            {formatDuration(w.durationS)}
                          </td>
                          <td className="py-1.5 px-1.5 border-b border-border/40 text-right [font-variant-numeric:tabular-nums]">
                            {formatNumber(lbToDisplay(w.volumeLb, unit), 0)}
                          </td>
                          <td className="py-1.5 px-1.5 border-b border-border/40 text-muted whitespace-nowrap">
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
                )}
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
