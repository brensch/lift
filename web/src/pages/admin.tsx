import { useEffect, useMemo, useState } from "react";
import { Navigate, useSearchParams } from "react-router-dom";
import { Code, ConnectError } from "@connectrpc/connect";
import { X } from "lucide-react";
import { useAuth } from "@/lib/use-auth";
import { adminClient, authHeaders } from "@/lib/grpc";
import type {
  AuthAttemptStat,
  DailyStat,
  GetStatsResponse,
  PageStat,
  TrailEntry,
} from "@/gen/workout/v1/analytics_pb";
import { ChartCard } from "@/components/charts/chart-card";
import { ColumnChart } from "@/components/charts/column-chart";
import { StatTile } from "@/components/charts/stat-tile";
import { Select } from "@/components/ui/select";
import { CONTEXT, SERIES_1, SERIES_3 } from "@/components/charts/chart-utils";
import { formatNumber, formatWhen } from "@/lib/format";
import { Card, DataTable } from "@/components/admin/parts";
import { Recoveries } from "@/components/admin/recoveries";
import { Training } from "@/components/admin/training";

const WINDOWS = [7, 30, 90, 365];

function formatMs(ms: number): string {
  if (ms < 1000) return `${Math.round(ms)}ms`;
  const s = ms / 1000;
  if (s < 60) return `${s.toFixed(s < 10 ? 1 : 0)}s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ${Math.round(s % 60)}s`;
  return `${Math.floor(m / 60)}h ${m % 60}m`;
}

/** "2026-09-05" → "Sep 5". Short enough for the chart's label stride. */
function shortDay(day: string): string {
  return new Date(`${day}T00:00:00Z`).toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
    timeZone: "UTC",
  });
}

/**
 * Every UTC day in the window, oldest first. The server only returns days
 * that had activity; a quiet day has to show as a gap, not vanish.
 */
function fillDays(
  daily: DailyStat[],
  days: number,
): { day: string; views: number; users: number }[] {
  const byDay = new Map(daily.map((d) => [d.day, d]));
  const out = [];
  const today = Date.UTC(
    new Date().getUTCFullYear(),
    new Date().getUTCMonth(),
    new Date().getUTCDate(),
  );
  for (let i = days - 1; i >= 0; i--) {
    const day = new Date(today - i * 86_400_000).toISOString().slice(0, 10);
    const d = byDay.get(day);
    out.push({ day, views: Number(d?.views ?? 0), users: Number(d?.uniqueUsers ?? 0) });
  }
  return out;
}

function pct(n: number, of: number): string {
  return of > 0 ? `${Math.round((n / of) * 100)}%` : "–";
}

interface FunnelStep {
  label: string;
  count: number;
  /** Mean foreground time per visit; absent for steps that are not pages. */
  avgMs?: number;
}

function avgMs(p: PageStat): number | undefined {
  const views = Number(p.views);
  return views > 0 ? Number(p.totalDurationMs) / views : undefined;
}

/** Horizontal bars, each labelled with its count and its share of the first step. */
function Funnel({ steps, color }: { steps: FunnelStep[]; color: string }) {
  const top = Math.max(...steps.map((s) => s.count), 1);
  const first = steps[0]?.count ?? 0;
  if (steps.length === 0 || first === 0) {
    return <p className="text-sm text-muted m-0">Nothing recorded in this window yet.</p>;
  }
  return (
    <ol className="list-none p-0 m-0 flex flex-col gap-2">
      <li
        aria-hidden
        className="grid grid-cols-[minmax(0,9.5rem)_1fr_5.5rem_3.5rem] items-center gap-3 text-[0.65rem] uppercase tracking-wider text-muted"
      >
        <span />
        <span />
        <span className="text-right">Users</span>
        <span className="text-right">Avg time</span>
      </li>
      {steps.map((step, i) => (
        <li
          key={step.label}
          className="grid grid-cols-[minmax(0,9.5rem)_1fr_5.5rem_3.5rem] items-center gap-3 text-sm"
        >
          <span className="truncate text-muted" title={step.label}>
            {step.label}
          </span>
          <span className="h-5 rounded bg-background overflow-hidden">
            <span
              className="block h-full rounded"
              style={{
                width: `${(step.count / top) * 100}%`,
                background: color,
                minWidth: step.count > 0 ? 2 : 0,
              }}
            />
          </span>
          <span className="[font-variant-numeric:tabular-nums] text-text whitespace-nowrap text-right">
            {formatNumber(step.count, 0)}
            <span className="text-muted ml-2 inline-block w-9 text-right">
              {i === 0 ? "" : pct(step.count, first)}
            </span>
          </span>
          <span className="[font-variant-numeric:tabular-nums] text-muted whitespace-nowrap text-right">
            {step.avgMs === undefined ? "" : formatMs(step.avgMs)}
          </span>
        </li>
      ))}
    </ol>
  );
}

// ── Passkey health ──

const REASONS = ["cancelled", "no_credential", "unsupported", "platform_error", "timeout"] as const;

interface PasskeyRow {
  kind: string;
  platform: string;
  version: string;
  total: number;
  ok: number;
  rejected: number;
  /** Why the server refused, by its slug. */
  rejections: Record<string, number>;
  abandoned: number;
  reasons: Record<string, number>;
  otherErrors: number;
}

function passkeyRows(attempts: AuthAttemptStat[]): PasskeyRow[] {
  const rows = new Map<string, PasskeyRow>();
  for (const a of attempts) {
    const key = `${a.kind}|${a.platform}|${a.appVersion}`;
    const row =
      rows.get(key) ??
      ({
        kind: a.kind,
        platform: a.platform || "unknown",
        version: a.appVersion || "–",
        total: 0,
        ok: 0,
        rejected: 0,
        rejections: {},
        abandoned: 0,
        reasons: {},
        otherErrors: 0,
      } satisfies PasskeyRow);
    const n = Number(a.count);
    row.total += n;
    if (a.outcome === "ok") row.ok += n;
    else if (a.outcome === "rejected") {
      row.rejected += n;
      row.rejections[a.reason] = (row.rejections[a.reason] ?? 0) + n;
    } else if (a.outcome === "started") row.abandoned += n;
    else if ((REASONS as readonly string[]).includes(a.reason))
      row.reasons[a.reason] = (row.reasons[a.reason] ?? 0) + n;
    else row.otherErrors += n;
    rows.set(key, row);
  }
  return [...rows.values()].sort((a, b) => b.total - a.total);
}

const FAILURE_LABELS: [string, string][] = [
  ["cancelled", "cancelled"],
  ["no_credential", "no passkey"],
  ["unsupported", "unsupported"],
  ["platform_error", "OS error"],
  ["timeout", "timed out"],
];

/** What the server calls a refusal, as the table says it. */
const REJECTION_LABELS: Record<string, string> = {
  expired: "took too long",
  unknown_passkey: "passkey of no account",
  not_verified: "not verified (no biometric)",
  already_registered: "passkey already registered",
  name_taken: "name taken meanwhile",
  unknown_user: "nobody has that username",
  too_many_recoveries: "too many requests waiting",
  rejected: "didn't verify",
  internal: "server error",
};

/** "9 cancelled · 4 no passkey" — only the reasons that happened. */
function failureSummary(r: PasskeyRow): string {
  const parts = FAILURE_LABELS.filter(([key]) => r.reasons[key]).map(
    ([key, label]) => `${r.reasons[key]} ${label}`,
  );
  for (const [reason, n] of Object.entries(r.rejections).sort((a, b) => b[1] - a[1])) {
    // Rows from before refusals had slugs hold the whole error.
    parts.push(`${n} refused: ${REJECTION_LABELS[reason] ?? "other"}`);
  }
  if (r.otherErrors) parts.push(`${r.otherErrors} other`);
  return parts.length ? parts.join(" · ") : "–";
}

// ── Trail ──

function Trail({
  username,
  entries,
  failed,
  onClose,
}: {
  username: string;
  /** Null while this user's trail is still loading. */
  entries: TrailEntry[] | null;
  /** The fetch for it failed (the page shows why). */
  failed: boolean;
  onClose: () => void;
}) {
  // Newest sitting first; within a sitting, in the order it happened.
  const sittings = useMemo(() => {
    const bySession = new Map<string, TrailEntry[]>();
    for (const e of entries ?? []) {
      const list = bySession.get(e.appSessionId) ?? [];
      list.push(e);
      bySession.set(e.appSessionId, list);
    }
    return [...bySession.values()].map((list) => [...list].reverse());
  }, [entries]);

  return (
    <Card
      title={`${username}'s trail`}
      subtitle="Most recent 500 page views, grouped by app launch."
    >
      <button
        onClick={onClose}
        aria-label="Close trail"
        className="absolute top-4 right-4 p-1 text-muted hover:text-text bg-transparent border-0 cursor-pointer"
      >
        <X size={16} />
      </button>
      {entries === null ? (
        <p className="text-sm text-muted m-0">
          {failed ? "Couldn't load this trail." : "Loading…"}
        </p>
      ) : sittings.length === 0 ? (
        <p className="text-sm text-muted m-0">No page views recorded for this user.</p>
      ) : (
        <div className="flex flex-col gap-4 max-h-[32rem] overflow-y-auto pr-1">
          {sittings.map((sitting) => (
            <div key={sitting[0].appSessionId}>
              <p className="text-xs uppercase tracking-wider text-muted m-0 mb-1.5">
                {formatWhen(Number(sitting[0].enteredAtMs))} · {sitting[0].platform || "unknown"}{" "}
                {sitting[0].appVersion}
              </p>
              <ol className="list-none p-0 m-0 border-l border-border pl-3 flex flex-col gap-0.5">
                {sitting.map((e, i) => (
                  <li key={i} className="flex justify-between gap-3 text-sm">
                    <span className="font-mono text-[0.8rem] truncate">{e.page}</span>
                    <span className="text-muted [font-variant-numeric:tabular-nums] shrink-0">
                      {formatMs(Number(e.durationMs))}
                    </span>
                  </li>
                ))}
              </ol>
            </div>
          ))}
        </div>
      )}
    </Card>
  );
}

// ── Page ──

export function AdminPage() {
  const { user, loading } = useAuth();
  const [days, setDays] = useState(30);
  // ?user=<name> holds the open trail, so a trail can be linked to.
  const [params, setParams] = useSearchParams();
  const trailUser = params.get("user") ?? "";
  const setTrailUser = (username: string) =>
    setParams(username ? { user: username } : {}, { replace: true });
  const [stats, setStats] = useState<GetStatsResponse | null>(null);
  // The trail username `stats` was fetched for: `trailUser` changes at once,
  // the trail in `stats` only when the refetch lands.
  const [trailFor, setTrailFor] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  // The trail username the last failed fetch was for.
  const [errorFor, setErrorFor] = useState<string | null>(null);
  const [denied, setDenied] = useState(false);

  useEffect(() => {
    if (!user) return;
    let cancelled = false;
    adminClient
      .getStats({ days, trailUsername: trailUser }, authHeaders(user.sessionToken))
      .then((res) => {
        if (cancelled) return;
        setError(null);
        setStats(res);
        setTrailFor(trailUser);
      })
      .catch((err: unknown) => {
        if (cancelled) return;
        if (err instanceof ConnectError && err.code === Code.PermissionDenied) setDenied(true);
        else {
          setError(err instanceof Error ? err.message : "Failed to load stats");
          setErrorFor(trailUser);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [user, days, trailUser]);

  const pages = useMemo(() => stats?.pages ?? [], [stats]);
  const byPrefix = (prefix: string): PageStat[] =>
    pages.filter((p) => p.page.startsWith(prefix)).sort((a, b) => a.page.localeCompare(b.page));

  if (loading) return <p className="text-muted px-5 py-16 text-center">Loading…</p>;
  if (!user) return <Navigate to="/login" replace />;
  if (denied) {
    return (
      <div className="max-w-5xl mx-auto px-5 py-16">
        <h2 className="font-display text-2xl font-extrabold tracking-tight m-0">Not for you.</h2>
        <p className="text-muted mt-2">This page is for admins. {user.username} isn't one.</p>
      </div>
    );
  }

  const attempts = stats?.authAttempts ?? [];
  const registers = attempts.filter((a) => a.kind === "register");
  const registerStarted = registers.reduce((n, a) => n + Number(a.count), 0);
  const registerOk = registers
    .filter((a) => a.outcome === "ok")
    .reduce((n, a) => n + Number(a.count), 0);
  const users = (p: PageStat) => Number(p.uniqueUsers);

  const signupFunnel: FunnelStep[] = [
    { label: "Started sign-up", count: registerStarted },
    { label: "Passkey created", count: registerOk },
    ...byPrefix("onboarding/").map((p) => ({
      label: p.page.slice("onboarding/".length),
      count: users(p),
      avgMs: avgMs(p),
    })),
    ...byPrefix("tutorial/")
      .slice(0, 1)
      .map((p) => ({ label: "Opened tutorial", count: users(p) })),
    ...byPrefix("tutorial/")
      .slice(-1)
      .map((p) => ({ label: "Finished tutorial", count: users(p) })),
  ];
  const tutorialFunnel = byPrefix("tutorial/").map((p) => ({
    label: p.page.slice("tutorial/".length),
    count: users(p),
    avgMs: avgMs(p),
  }));
  const passkeys = passkeyRows(attempts);
  const totalViews = pages.reduce((n, p) => n + Number(p.views), 0);
  const daily = fillDays(stats?.daily ?? [], stats?.days ?? days);
  const peakUsers = Math.max(...daily.map((d) => d.users), 0);

  return (
    <div className="max-w-5xl mx-auto px-5 py-8 flex flex-col gap-4">
      <div className="flex items-end justify-between gap-3 flex-wrap">
        <div>
          <h2 className="font-display text-[clamp(1.5rem,3vw,2.2rem)] font-extrabold tracking-tight m-0">
            Stats
          </h2>
          <p className="text-sm text-muted mt-1 mb-0">
            Who is here, what they lifted, page views and sign-in attempts. First-party; kept until
            the account is deleted.
          </p>
        </div>
        <Select
          ariaLabel="Window"
          value={String(days)}
          onChange={(v) => setDays(Number(v))}
          options={WINDOWS.map((d) => ({ value: String(d), label: `Last ${d} days` }))}
        />
      </div>

      <Recoveries token={user.sessionToken} />

      {error && <p className="text-sm text-danger m-0">{error}</p>}
      {!stats && !error && <p className="text-muted py-8 text-center">Loading…</p>}

      {stats && (
        <>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <StatTile
              label="Accounts"
              value={formatNumber(Number(stats.totalUsers), 0)}
              sub="all time"
            />
            <StatTile
              label="New accounts"
              value={formatNumber(Number(stats.newUsers), 0)}
              sub={`last ${stats.days} days`}
            />
            <StatTile
              label="Active users"
              value={formatNumber(Number(stats.activeUsers), 0)}
              sub="opened the app"
            />
            <StatTile
              label="Page views"
              value={formatNumber(totalViews, 0)}
              sub={`last ${stats.days} days`}
            />
          </div>

          <Training
            token={user.sessionToken}
            days={days}
            views={new Map(stats.users.map((u) => [u.username, Number(u.views)]))}
            pickedUser={trailUser}
            onPickUser={setTrailUser}
            trail={
              trailUser && (
                <div className="relative">
                  <Trail
                    username={trailUser}
                    entries={trailFor === trailUser ? stats.trail : null}
                    failed={error !== null && errorFor === trailUser}
                    onClose={() => setTrailUser("")}
                  />

                  <div className="grid md:grid-cols-2 gap-4">
                    <Card
                      title="Sign-up funnel"
                      subtitle="Sign-up attempts, then distinct users reaching each step. Time is the average per visit."
                    >
                      <Funnel steps={signupFunnel} color={SERIES_1} />
                    </Card>
                    <Card
                      title="Tutorial"
                      subtitle="Distinct users who saw each step, and the average time on it."
                    >
                      <Funnel steps={tutorialFunnel} color={SERIES_3} />
                    </Card>
                  </div>

                  <Card
                    title="Passkey health"
                    subtitle="Every sign-up and sign-in ceremony the server started. Abandoned = the device never came back and never said why."
                  >
                    <DataTable
                      head={[
                        "Flow",
                        "Platform",
                        "Version",
                        "Attempts",
                        "OK",
                        "Success",
                        "Abandoned",
                        "Reported failures",
                      ]}
                      numeric={[3, 4, 5, 6]}
                      wrap={[7]}
                      rows={passkeys.map((r) => [
                        r.kind,
                        r.platform,
                        r.version,
                        r.total,
                        r.ok,
                        pct(r.ok, r.total),
                        r.abandoned,
                        failureSummary(r),
                      ])}
                    />
                  </Card>

                  <div className="grid md:grid-cols-2 gap-4">
                    <ChartCard
                      title="Daily active users"
                      subtitle={`Distinct users who opened the app each UTC day · peak ${formatNumber(peakUsers, 0)}`}
                      table={{
                        head: ["Day", "Users"],
                        rows: daily.map((d) => [d.day, String(d.users)]),
                        numeric: [1],
                      }}
                    >
                      <ColumnChart
                        data={daily.map((d) => ({ label: shortDay(d.day), value: d.users }))}
                        color={SERIES_1}
                        yFormat={(v) => formatNumber(v, 0)}
                        tooltipValue={(c) =>
                          `${formatNumber(c.value, 0)} ${c.value === 1 ? "user" : "users"}`
                        }
                      />
                    </ChartCard>
                    <ChartCard
                      title="Page views per day"
                      subtitle="UTC days"
                      table={{
                        head: ["Day", "Views"],
                        rows: daily.map((d) => [d.day, String(d.views)]),
                        numeric: [1],
                      }}
                    >
                      <ColumnChart
                        data={daily.map((d) => ({ label: shortDay(d.day), value: d.views }))}
                        color={CONTEXT}
                        yFormat={(v) => formatNumber(v, 0)}
                        tooltipValue={(c) => `${formatNumber(c.value, 0)} views`}
                      />
                    </ChartCard>
                  </div>

                  <Card
                    title="Pages"
                    subtitle="Median is time in the foreground on that page per visit."
                  >
                    <DataTable
                      head={["Page", "Views", "Users", "Median time", "Total time"]}
                      numeric={[1, 2, 3, 4]}
                      rows={pages.map((p) => [
                        p.page,
                        formatNumber(Number(p.views), 0),
                        formatNumber(Number(p.uniqueUsers), 0),
                        formatMs(Number(p.medianDurationMs)),
                        formatMs(Number(p.totalDurationMs)),
                      ])}
                    />
                  </Card>
                </div>
              )
            }
          />
        </>
      )}
    </div>
  );
}
