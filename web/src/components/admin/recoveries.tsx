import { useCallback, useEffect, useState } from "react";
import { ConnectError } from "@connectrpc/connect";
import { adminClient, authHeaders } from "@/lib/grpc";
import type { RecoveryRequest } from "@/gen/workout/v1/analytics_pb";
import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";
import { formatWhen } from "@/lib/format";
import { Card, DataTable } from "./parts";

function errorText(err: unknown): string {
  if (err instanceof ConnectError) return err.rawMessage;
  return err instanceof Error ? err.message : "That didn't work.";
}

function plural(n: number, one: string): string {
  return `${n} ${one}${n === 1 ? "" : "s"}`;
}

/** Where a request stands, and what the admin should know before approving. */
function standing(r: RecoveryRequest): string {
  if (r.status !== "pending") return `${r.status} ${formatWhen(Number(r.decidedAt) * 1000)}`;
  return r.logins > 0
    ? `waiting · still signed in on ${plural(r.logins, "device")}`
    : "waiting · signed in nowhere";
}

/**
 * People who lost their passkey and made a new one at /recover. Approving is
 * by the code they send, never by picking a row: the request approved is the
 * one whose maker reached the admin.
 */
export function Recoveries({ token }: { token: string }) {
  const [requests, setRequests] = useState<RecoveryRequest[] | null>(null);
  const [code, setCode] = useState("");
  const [removeOthers, setRemoveOthers] = useState(false);
  const [confirming, setConfirming] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<string | null>(null);

  const load = useCallback(async () => {
    const res = await adminClient.listRecoveries({}, authHeaders(token));
    setRequests(res.recoveries);
  }, [token]);

  useEffect(() => {
    let cancelled = false;
    load().catch((err: unknown) => {
      if (!cancelled) setError(errorText(err));
    });
    return () => {
      cancelled = true;
    };
  }, [load]);

  async function decide(
    request: { case: "approveCode"; value: string } | { case: "denyRequestId"; value: string },
  ) {
    setBusy(true);
    setError(null);
    setDone(null);
    try {
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
      setRemoveOthers(false);
      await load();
    } catch (err) {
      setError(errorText(err));
    } finally {
      setBusy(false);
    }
  }

  const waiting = (requests ?? []).filter((r) => r.status === "pending");

  return (
    <Card
      title="Lost passkeys"
      subtitle="Requests made at /recover. Type the code the person sent you; only approve one you got from someone you know is them."
    >
      <div className="flex flex-col gap-3">
        <div className="flex flex-wrap items-center gap-3">
          <input
            className="rounded-md border border-border bg-background px-3 py-2 font-mono tracking-widest uppercase text-text outline-none focus:border-text w-44"
            value={code}
            onChange={(e) => setCode(e.target.value)}
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
            onClick={() => setConfirming(true)}
          >
            Approve
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
        {error && <p className="text-sm text-danger m-0">{error}</p>}
        {done && <p className="text-sm text-ok m-0">{done}</p>}

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
              formatWhen(Number(r.createdAt) * 1000),
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
        {waiting.some((r) => r.logins > 0) && (
          <p className="text-xs text-muted m-0">
            Someone still signed in doesn't need this: they can add a passkey from Settings in the
            app, and they see a banner there to turn the request down if it wasn't them.
          </p>
        )}
      </div>

      <ConfirmDialog
        open={confirming}
        title="Approve this code?"
        confirmLabel="Approve"
        onCancel={() => setConfirming(false)}
        onConfirm={() => {
          setConfirming(false);
          void decide({ case: "approveCode", value: code.trim() });
        }}
      >
        Whoever made the request with code{" "}
        <span className="font-mono font-semibold">{code.trim().toUpperCase()}</span> gets into the
        account it names
        {removeOthers ? ", and its other passkeys and signed-in devices are removed" : ""}. Only do
        this if the code reached you from the account's owner.
      </ConfirmDialog>
    </Card>
  );
}
