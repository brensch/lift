import { useCallback, useEffect, useState } from "react";
import { ConnectError } from "@connectrpc/connect";
import { adminClient, authHeaders } from "@/lib/grpc";
import type {
  GetRecoveryResponse,
  RecoveryAccount,
  RecoveryRequest,
} from "@/gen/workout/v1/analytics_pb";
import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";
import { exerciseName } from "@/lib/exercises";
import { formatCompact, formatDuration, formatNumber, formatWhen } from "@/lib/format";
import { Card, DataTable } from "./parts";

function errorText(err: unknown): string {
  if (err instanceof ConnectError) return err.rawMessage;
  return err instanceof Error ? err.message : "That didn't work.";
}

function plural(n: number, one: string): string {
  return `${n} ${one}${n === 1 ? "" : "s"}`;
}

const when = (unixSeconds: bigint | number) =>
  Number(unixSeconds) > 0 ? formatWhen(Number(unixSeconds) * 1000) : "never";

/** Where a request stands, and what the admin should know before approving. */
function standing(r: RecoveryRequest): string {
  if (r.status !== "pending") return `${r.status} ${when(r.decidedAt)}`;
  if (r.noAccount) return "waiting · nobody has that username";
  return r.logins > 0
    ? `waiting · still signed in on ${plural(r.logins, "device")}`
    : "waiting · signed in nowhere";
}

function Fact({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="min-w-0">
      <dt className="text-[0.65rem] uppercase tracking-wider text-muted">{label}</dt>
      <dd className="m-0 mt-0.5 text-sm break-words">{children}</dd>
    </div>
  );
}

function Heading({ children }: { children: React.ReactNode }) {
  return <h4 className="text-xs uppercase tracking-wider text-muted m-0 mb-2">{children}</h4>;
}

/**
 * The account a request asks for, laid out to question whoever is asking:
 * things its owner would know and a stranger would not.
 */
function Dossier({ request, account }: { request: RecoveryRequest; account: RecoveryAccount }) {
  const user = account.user;
  if (!user) return null;
  return (
    <div className="border border-border rounded-xl bg-background/60 p-4 sm:p-5 flex flex-col gap-5">
      <div className="flex items-center gap-4">
        <span
          aria-hidden="true"
          className="shrink-0 w-14 h-14 rounded-xl flex items-center justify-center text-3xl"
          style={{ background: account.colorHex }}
        >
          {account.emoji}
        </span>
        <div className="min-w-0">
          <p className="font-display text-2xl font-extrabold tracking-tight m-0 truncate">
            {user.username}
          </p>
          <p className="text-sm text-muted m-0">
            Asked {when(request.createdAt)} from{" "}
            {[request.platform || "unknown", request.createdIp].filter(Boolean).join(" · ")}
          </p>
        </div>
      </div>

      <dl className="grid grid-cols-2 md:grid-cols-4 gap-x-6 gap-y-4 m-0">
        <Fact label="Emoji and colour">
          {account.emoji} <span className="font-mono">{account.colorHex}</span>
        </Fact>
        <Fact label="Joined">{when(user.createdAt)}</Fact>
        <Fact label="Last in the app">
          {Number(user.lastSeenMs) > 0 ? formatWhen(Number(user.lastSeenMs)) : "never"}
          {Number(user.lastSeenMs) > 0 && ` · ${user.platform || "unknown"} ${user.appVersion}`}
        </Fact>
        <Fact label="Signed-in devices">
          {user.logins > 0 ? `${user.logins}, last used ${when(account.lastActiveAt)}` : "none"}
        </Fact>
        <Fact label="Workouts">
          {formatNumber(user.workouts, 0)}
          {user.liftingNow && " · one open right now"}
        </Fact>
        <Fact label="Last workout">{when(user.lastWorkoutAt)}</Fact>
        <Fact label="Lifted, all time">{formatCompact(user.volumeLb)} lb</Fact>
        <Fact label="Bodyweight">
          {account.bodyWeightKg > 0
            ? `${formatNumber(account.bodyWeightKg)} kg (${formatNumber(account.bodyWeightKg * 2.2046, 0)} lb)`
            : "never set"}
        </Fact>
      </dl>

      {user.logins > 0 && (
        <p className="text-sm text-danger m-0">
          Still signed in on {plural(user.logins, "device")}. Whoever holds one can add a passkey
          from Settings without you, and sees a banner there to refuse this request.
        </p>
      )}

      <div className="grid md:grid-cols-2 gap-x-8 gap-y-5">
        <div>
          <Heading>Trains with</Heading>
          <DataTable
            empty="Nobody: never trained in a session."
            head={["Who", "Sessions", "Last"]}
            numeric={[1]}
            rows={account.partners.map((p) => [
              p.username,
              p.sessionsTogether,
              when(p.lastTrainedAt),
            ])}
          />
        </div>
        <div>
          <Heading>Their saved workouts</Heading>
          {account.templates.length ? (
            <p className="text-sm m-0 leading-relaxed">{account.templates.join(" · ")}</p>
          ) : (
            <p className="text-sm text-muted m-0">None.</p>
          )}
          <div className="mt-5">
            <Heading>Passkeys they had</Heading>
            <DataTable
              empty="None left."
              head={["Name", "Added", "From"]}
              rows={account.passkeys.map((p) => [
                p.name || "unnamed",
                when(p.createdAt),
                p.createdIp || "–",
              ])}
            />
          </div>
        </div>
        <div>
          <Heading>Latest workouts</Heading>
          <DataTable
            empty="None finished."
            head={["Started", "Workout", "Time", "Sets", "With others"]}
            numeric={[2, 3]}
            rows={account.recentWorkouts.map((w) => [
              when(w.startTime),
              w.name || "–",
              formatDuration(Number(w.durationSeconds)),
              w.sets,
              w.together ? "yes" : "",
            ])}
          />
        </div>
        <div>
          <Heading>What they lift</Heading>
          <DataTable
            maxHeight="16rem"
            empty="Nothing yet."
            head={["Lift", "Sets", "Volume"]}
            numeric={[1, 2]}
            rows={account.lifts.map((e) => [
              exerciseName(e.exercise),
              formatNumber(Number(e.sets), 0),
              `${formatCompact(e.volumeLb)} lb`,
            ])}
          />
        </div>
      </div>
    </div>
  );
}

/**
 * People who lost their passkey and made a new one at /recover. The code
 * they send opens the account it asks for; approving comes after reading
 * it, and is by that code, never by picking a row: the request approved is
 * the one whose maker reached the admin.
 */
export function Recoveries({ token }: { token: string }) {
  const [requests, setRequests] = useState<RecoveryRequest[] | null>(null);
  const [code, setCode] = useState("");
  // The request the typed code opened, with the code that opened it.
  const [opened, setOpened] = useState<{ code: string; found: GetRecoveryResponse } | null>(null);
  const [removeOthers, setRemoveOthers] = useState(false);
  const [confirming, setConfirming] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<string | null>(null);

  const fetchRequests = useCallback(
    async () => (await adminClient.listRecoveries({}, authHeaders(token))).recoveries,
    [token],
  );

  useEffect(() => {
    let cancelled = false;
    fetchRequests()
      .then((recoveries) => {
        if (!cancelled) setRequests(recoveries);
      })
      .catch((err: unknown) => {
        if (!cancelled) setError(errorText(err));
      });
    return () => {
      cancelled = true;
    };
  }, [fetchRequests]);

  /** Runs one admin call, saying how it went. */
  async function run(call: () => Promise<void>) {
    setBusy(true);
    setError(null);
    setDone(null);
    try {
      await call();
    } catch (err) {
      setError(errorText(err));
    } finally {
      setBusy(false);
    }
  }

  const lookUp = () =>
    run(async () => {
      setOpened(null);
      const typed = code.trim();
      const found = await adminClient.getRecovery({ code: typed }, authHeaders(token));
      setOpened({ code: typed, found });
      setRemoveOthers(false);
    });

  const decide = (
    request: { case: "approveCode"; value: string } | { case: "denyRequestId"; value: string },
  ) =>
    run(async () => {
      const res = await adminClient.decideRecovery(
        { request, removeOtherPasskeys: request.case === "approveCode" && removeOthers },
        authHeaders(token),
      );
      const name = res.recovery?.username ?? "them";
      setDone(
        request.case === "approveCode"
          ? `Approved. ${name}'s new passkey signs in now.`
          : `Turned down the request for ${name}.`,
      );
      setCode("");
      setOpened(null);
      setRemoveOthers(false);
      setRequests(await fetchRequests());
    });

  const request = opened?.found.recovery;
  const account = opened?.found.account;

  return (
    <Card
      title="Lost passkeys"
      subtitle="Requests made at /recover. Type the code the person sent to open the account it asks for, ask them about it, then decide."
    >
      <div className="flex flex-col gap-4">
        <div className="flex flex-wrap items-center gap-3">
          <input
            className="rounded-md border border-border bg-background px-3 py-2 font-mono tracking-widest uppercase text-text outline-none focus:border-text w-44"
            value={code}
            onChange={(e) => setCode(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && !busy && code.trim() !== "") void lookUp();
            }}
            placeholder="XXXX-XXXX"
            aria-label="Recovery code"
            autoCapitalize="characters"
            autoCorrect="off"
            spellCheck={false}
          />
          <Button
            variant="primary"
            size="sm"
            className="disabled:opacity-60 disabled:cursor-not-allowed"
            disabled={busy || code.trim() === ""}
            onClick={() => void lookUp()}
          >
            Open
          </Button>
        </div>
        {error && <p className="text-sm text-danger m-0">{error}</p>}
        {done && <p className="text-sm text-ok m-0">{done}</p>}

        {opened && request && !account && (
          <div className="border border-border rounded-xl bg-background/60 p-4 sm:p-5 flex flex-col gap-3">
            <p className="font-display text-2xl font-extrabold tracking-tight m-0 break-words">
              Nobody is called “{request.username}”
            </p>
            <p className="text-sm text-muted m-0">
              That is the username they typed, {when(request.createdAt)} from{" "}
              {[request.platform || "unknown", request.createdIp].filter(Boolean).join(" · ")}.
              There is no such account, so there is nothing to approve: tell them the name is wrong
              and to try again with the right one.
            </p>
            <div>
              <Button
                size="sm"
                className="disabled:opacity-60 disabled:cursor-not-allowed"
                disabled={busy}
                onClick={() => void decide({ case: "denyRequestId", value: request.requestId })}
              >
                Turn down
              </Button>
            </div>
          </div>
        )}

        {opened && request && account && (
          <>
            <Dossier request={request} account={account} />
            <div className="flex flex-wrap items-center gap-3">
              <Button
                variant="primary"
                size="sm"
                className="disabled:opacity-60 disabled:cursor-not-allowed"
                disabled={busy}
                onClick={() => setConfirming(true)}
              >
                Approve {account.user?.username}
              </Button>
              <Button
                size="sm"
                className="disabled:opacity-60 disabled:cursor-not-allowed"
                disabled={busy}
                onClick={() => void decide({ case: "denyRequestId", value: request.requestId })}
              >
                Turn down
              </Button>
              <label className="flex items-center gap-2 text-sm text-muted">
                <input
                  type="checkbox"
                  checked={removeOthers}
                  onChange={(e) => setRemoveOthers(e.target.checked)}
                />
                Also remove their other passkeys and sign out their devices (stolen phone)
              </label>
            </div>
          </>
        )}

        {requests === null ? (
          !error && <p className="text-sm text-muted m-0">Loading…</p>
        ) : (
          <DataTable
            empty="Nobody is waiting."
            head={["User", "Asked", "From", "Passkeys", "Last in the app", "Standing", ""]}
            numeric={[3]}
            wrap={[5]}
            rows={requests.map((r) => [
              r.username,
              when(r.createdAt),
              [r.platform || "unknown", r.createdIp].filter(Boolean).join(" · "),
              r.passkeys,
              Number(r.lastSeenMs) > 0 ? formatWhen(Number(r.lastSeenMs)) : "never",
              standing(r),
              r.status === "pending" ? (
                <button
                  className="bg-transparent border-0 p-0 text-sm font-semibold text-danger cursor-pointer disabled:opacity-60"
                  disabled={busy}
                  onClick={() => void decide({ case: "denyRequestId", value: r.requestId })}
                >
                  Turn down
                </button>
              ) : (
                ""
              ),
            ])}
          />
        )}
      </div>

      <ConfirmDialog
        open={confirming}
        title={`Let them in as ${account?.user?.username ?? "this account"}?`}
        confirmLabel="Approve"
        onCancel={() => setConfirming(false)}
        onConfirm={() => {
          setConfirming(false);
          if (opened) void decide({ case: "approveCode", value: opened.code });
        }}
      >
        Whoever sent you this code gets into the account
        {removeOthers ? ", and its other passkeys and signed-in devices are removed" : ""}. Only do
        this if their answers matched what you just read.
      </ConfirmDialog>
    </Card>
  );
}
