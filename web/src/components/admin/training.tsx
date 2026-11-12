import { useEffect, useState, type ReactNode } from "react";
import { adminClient, authHeaders } from "@/lib/grpc";
import type {
  AdminUser,
  GetTrainingStatsResponse,
  TrainingDay,
} from "@/gen/workout/v1/analytics_pb";
import { ChartCard } from "@/components/charts/chart-card";
import { ColumnChart } from "@/components/charts/column-chart";
import { StatTile } from "@/components/charts/stat-tile";
import { SERIES_2 } from "@/components/charts/chart-utils";
import { exerciseName } from "@/lib/exercises";
import { formatCompact, formatDuration, formatNumber } from "@/lib/format";
import { formatWhen } from "@/lib/format";
import { Card, DataTable } from "./parts";

const DAY_MS = 86_400_000;

function shortDay(epochDay: number): string {
  return new Date(epochDay * DAY_MS).toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
    timeZone: "UTC",
  });
}

/** Every UTC day in the window, oldest first: a day nobody trained is a gap. */
function fillDays(
  daily: TrainingDay[],
  days: number,
): { epochDay: number; workouts: number; lifters: number }[] {
  const byDay = new Map(daily.map((d) => [Number(d.epochDay), d]));
  const today = Math.floor(Date.now() / DAY_MS);
  const out = [];
  for (let epochDay = today - days + 1; epochDay <= today; epochDay++) {
    const d = byDay.get(epochDay);
    out.push({ epochDay, workouts: Number(d?.workouts ?? 0), lifters: Number(d?.lifters ?? 0) });
  }
  return out;
}

/** "3d ago" for anything recent, a date past a month. */
function ago(ms: number): string {
  if (ms <= 0) return "never";
  const days = Math.floor((Date.now() - ms) / DAY_MS);
  if (days <= 0) return "today";
  if (days === 1) return "yesterday";
  if (days < 30) return `${days}d ago`;
  return new Date(ms).toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

function date(unixSeconds: number): string {
  return new Date(unixSeconds * 1000).toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

/** Which builds people are on, by their latest page view, most users first. */
function builds(users: AdminUser[]): [string, string, number][] {
  const counts = new Map<string, [string, string, number]>();
  for (const u of users) {
    if (Number(u.lastSeenMs) <= 0) continue;
    const key = `${u.platform}|${u.appVersion}`;
    const row = counts.get(key) ?? [u.platform || "unknown", u.appVersion || "–", 0];
    row[2] += 1;
    counts.set(key, row);
  }
  return [...counts.values()].sort((a, b) => b[2] - a[2] || b[1].localeCompare(a[1]));
}

/**
 * Everyone and their training: accounts the server knows, and the finished
 * workouts folded from each one's events for this page.
 */
export function Training({
  token,
  days,
  views,
  pickedUser,
  onPickUser,
  trail,
}: {
  token: string;
  days: number;
  /** Page views in the window, by username. */
  views: Map<string, number>;
  /** The user whose trail is open, or "". */
  pickedUser: string;
  onPickUser: (username: string) => void;
  /** The open trail, shown under the list it was picked from. */
  trail: ReactNode;
}) {
  const [stats, setStats] = useState<GetTrainingStatsResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    adminClient
      .getTrainingStats({ days }, authHeaders(token))
      .then((res) => {
        if (cancelled) return;
        setError(null);
        setStats(res);
      })
      .catch((err: unknown) => {
        if (!cancelled) setError(err instanceof Error ? err.message : "Failed to load training");
      });
    return () => {
      cancelled = true;
    };
  }, [token, days]);

  if (error) return <p className="text-sm text-danger m-0">{error}</p>;
  if (!stats) return <p className="text-muted py-8 text-center">Loading everyone's training…</p>;

  const daily = fillDays(stats.daily, stats.days);
  const liftingNow = stats.users.filter((u) => u.liftingNow);
  const window = `last ${stats.days} days`;

  return (
    <>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <StatTile
          label="Workouts"
          value={formatNumber(Number(stats.workoutsInWindow), 0)}
          sub={`${window} · ${formatNumber(Number(stats.workoutsTotal), 0)} all time`}
        />
        <StatTile
          label="Lifters"
          value={formatNumber(Number(stats.liftersInWindow), 0)}
          sub="finished a workout"
        />
        <StatTile
          label="Lifting now"
          value={formatNumber(liftingNow.length, 0)}
          sub={
            liftingNow.length
              ? liftingNow
                  .slice(0, 3)
                  .map((u) => u.username)
                  .join(", ")
              : "nobody has a workout open"
          }
        />
        <StatTile
          label="Volume"
          value={`${formatCompact(stats.volumeLbInWindow)} lb`}
          sub={window}
        />
      </div>

      <div className="grid md:grid-cols-2 gap-4">
        <ChartCard
          title="Workouts per day"
          subtitle="Finished workouts, by the UTC day they started"
          table={{
            head: ["Day", "Workouts", "Lifters"],
            rows: daily.map((d) => [shortDay(d.epochDay), String(d.workouts), String(d.lifters)]),
            numeric: [1, 2],
          }}
        >
          <ColumnChart
            data={daily.map((d) => ({ label: shortDay(d.epochDay), value: d.workouts }))}
            color={SERIES_2}
            yFormat={(v) => formatNumber(v, 0)}
            tooltipValue={(c) =>
              `${formatNumber(c.value, 0)} ${c.value === 1 ? "workout" : "workouts"}`
            }
          />
        </ChartCard>
        <Card title="Lifts" subtitle={`Working sets finished, ${window}.`}>
          <DataTable
            maxHeight="17rem"
            head={["Lift", "Sets", "Lifters", "Volume"]}
            numeric={[1, 2, 3]}
            rows={stats.exercises.map((e) => [
              exerciseName(e.exercise),
              formatNumber(Number(e.sets), 0),
              formatNumber(Number(e.lifters), 0),
              `${formatCompact(e.volumeLb)} lb`,
            ])}
          />
        </Card>
      </div>

      <Card
        title="Workouts"
        subtitle={`Finished, ${window}, newest first${
          Number(stats.workoutsInWindow) > stats.workouts.length
            ? ` (the latest ${stats.workouts.length})`
            : ""
        }.`}
      >
        <DataTable
          maxHeight="26rem"
          head={["Started", "User", "Workout", "Time", "Lifts", "Sets", "Volume", "With others"]}
          numeric={[3, 4, 5, 6]}
          rows={stats.workouts.map((w) => [
            formatWhen(Number(w.startTime) * 1000),
            w.username,
            w.name || "–",
            formatDuration(Number(w.durationSeconds)),
            w.exercises,
            w.sets,
            `${formatCompact(w.volumeLb)} lb`,
            w.together ? "yes" : "",
          ])}
        />
      </Card>

      <Card
        title="Everyone"
        subtitle="Every account, most recently in the app first. Pick one to follow their trail."
      >
        <DataTable
          maxHeight="30rem"
          empty="No accounts."
          head={[
            "User",
            "Joined",
            "Last in the app",
            "On",
            "Views",
            "Workouts",
            "Last workout",
            "Volume",
            "Passkeys",
            "Devices",
            "Events",
          ]}
          numeric={[4, 5, 7, 8, 9, 10]}
          rows={stats.users.map((u) => [
            `${u.username}${u.isAdmin ? " (admin)" : ""}${u.liftingNow ? " · lifting" : ""}`,
            date(Number(u.createdAt)),
            ago(Number(u.lastSeenMs)),
            Number(u.lastSeenMs) > 0 ? `${u.platform || "unknown"} ${u.appVersion}` : "–",
            formatNumber(views.get(u.username) ?? 0, 0),
            u.workoutsInWindow === u.workouts
              ? formatNumber(u.workouts, 0)
              : `${formatNumber(u.workoutsInWindow, 0)} / ${formatNumber(u.workouts, 0)}`,
            ago(Number(u.lastWorkoutAt) * 1000),
            `${formatCompact(u.volumeLb)} lb`,
            u.passkeys,
            u.logins,
            formatNumber(Number(u.events), 0),
          ])}
          onRowClick={(i) => onPickUser(stats.users[i].username)}
          activeRow={stats.users.findIndex((u) => u.username === pickedUser)}
        />
        <p className="text-xs text-muted mt-3 mb-0">
          Workouts are in the window / all time. Devices are sign-ins that haven't lapsed. Views are{" "}
          {window}.
        </p>
      </Card>

      {trail}

      <Card title="Builds in use" subtitle="By each account's latest page view.">
        <DataTable
          empty="Nobody has opened the app."
          head={["Platform", "Version", "Accounts"]}
          numeric={[2]}
          rows={builds(stats.users)}
        />
      </Card>
    </>
  );
}
