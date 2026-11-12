import { useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { ConnectError } from "@connectrpc/connect";
import { WobblyText } from "@/components/wobbly-text";
import { Button } from "@/components/ui/button";
import { authClient } from "@/lib/grpc";
import { RecoveryState } from "@/gen/workout/v1/auth_pb";
import {
  forgetRecovery,
  rememberRecovery,
  waitingRecovery,
  waitingRecoveryName,
} from "@/lib/recovery";

const POLL_MS = 5_000;

interface Held {
  state: RecoveryState;
  code: string;
  expiresAt: number;
  username: string;
}

function errorText(err: unknown): string {
  if (err instanceof DOMException && err.name === "NotAllowedError") {
    return "The passkey prompt was cancelled or timed out.";
  }
  if (err instanceof ConnectError) return err.rawMessage;
  return err instanceof Error ? err.message : "Something went wrong.";
}

type CreationParser = {
  parseCreationOptionsFromJSON?: (opts: unknown) => CredentialCreationOptions["publicKey"];
};

/** Makes the passkey for `username`'s account and has the server hold it. */
async function requestRecovery(username: string): Promise<string> {
  const parser = (window.PublicKeyCredential ?? {}) as unknown as CreationParser;
  if (!parser.parseCreationOptionsFromJSON) {
    throw new Error("This browser can't make passkeys. Try your phone's own browser.");
  }
  const start = await authClient.recoveryStart({ username });
  const options = JSON.parse(start.optionsJson) as { publicKey?: Record<string, unknown> };
  const asked = options.publicKey ?? (options as Record<string, unknown>);
  // Signing in never names the account, so the passkey has to be one its
  // manager can find by itself (discoverable). The server leaves that to
  // the client, as it does for the app.
  const publicKey = parser.parseCreationOptionsFromJSON({
    ...asked,
    authenticatorSelection: {
      ...(asked.authenticatorSelection as Record<string, unknown> | undefined),
      residentKey: "required",
      requireResidentKey: true,
    },
  });
  const credential = await navigator.credentials.create({ publicKey });
  if (!(credential instanceof PublicKeyCredential)) {
    throw new Error("No passkey was made.");
  }
  await authClient.recoveryFinish({
    requestId: start.requestId,
    credentialJson: JSON.stringify(credential.toJSON()),
  });
  return start.requestId;
}

function Shell({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="flex items-center justify-center min-h-[calc(100vh-10rem)] px-5 py-8">
      <div className="border border-border rounded-xl bg-surface p-8 md:p-12 w-full max-w-md space-y-5">
        <h1 className="font-display text-3xl font-extrabold tracking-tight m-0">
          <WobblyText text={title} seed={71} />
        </h1>
        {children}
      </div>
    </div>
  );
}

export function RecoverPage() {
  const [requestId, setRequestId] = useState<string | null>(waitingRecovery);
  const [held, setHeld] = useState<Held | null>(null);
  const [username, setUsername] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  const refresh = useCallback(async (id: string) => {
    const res = await authClient.recoveryStatus({ requestId: id });
    setHeld({
      state: res.state,
      code: res.code,
      expiresAt: Number(res.expiresAt),
      username: res.username || waitingRecoveryName(),
    });
  }, []);

  // While a request waits, ask how it stands; an outage keeps what is shown.
  const waiting = held === null || held.state === RecoveryState.PENDING;
  useEffect(() => {
    if (!requestId || !waiting) return;
    let cancelled = false;
    const tick = () => {
      if (!cancelled) refresh(requestId).catch(() => {});
    };
    tick();
    const timer = setInterval(tick, POLL_MS);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, [requestId, waiting, refresh]);

  async function start() {
    const name = username.trim();
    if (!name) {
      setError("Type the username of the account you lost.");
      return;
    }
    setError(null);
    setBusy(true);
    try {
      const id = await requestRecovery(name);
      rememberRecovery(id, name);
      setHeld(null);
      setRequestId(id);
    } catch (err) {
      setError(errorText(err));
    } finally {
      setBusy(false);
    }
  }

  function startOver() {
    forgetRecovery();
    setRequestId(null);
    setHeld(null);
    setError(null);
  }

  async function copyCode(code: string) {
    try {
      await navigator.clipboard.writeText(code);
      setCopied(true);
      setTimeout(() => setCopied(false), 2_000);
    } catch {
      // No clipboard: the code is on screen to read out.
    }
  }

  if (!requestId) {
    return (
      <Shell title="LOST PASSKEY">
        <p className="text-muted leading-relaxed">
          Type your old username below to make a new passkey. You'll get a code to send to brendan,
          and he'll inspect your soul and decide if you own that account.
        </p>
        <input
          className="w-full rounded-md border border-border bg-background px-3 py-2.5 text-text outline-none focus:border-text"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && !busy) void start();
          }}
          placeholder="your username"
          aria-label="Username"
          autoCapitalize="none"
          autoCorrect="off"
          spellCheck={false}
        />
        <Button
          variant="primary"
          size="lg"
          className="w-full disabled:opacity-60 disabled:cursor-not-allowed"
          onClick={() => void start()}
          disabled={busy}
        >
          {busy ? "Waiting for passkey..." : "Make a new passkey"}
        </Button>
        {error && <p className="text-danger font-semibold text-sm">{error}</p>}
      </Shell>
    );
  }

  if (!held) {
    return (
      <Shell title="LOST PASSKEY">
        <p className="text-muted">Loading…</p>
      </Shell>
    );
  }

  if (held.state === RecoveryState.PENDING) {
    return (
      <Shell title="SEND THIS CODE">
        <p className="text-muted leading-relaxed">
          Your new passkey for <span className="text-text font-semibold">{held.username}</span> is
          saved. Send Brendan this code, somewhere he'll know it's you:
        </p>
        <button
          onClick={() => void copyCode(held.code)}
          className="w-full rounded-md border border-border bg-background py-4 font-mono text-3xl font-bold tracking-[0.15em] text-text cursor-pointer"
          aria-label={`Copy code ${held.code}`}
        >
          {held.code}
        </button>
        <p className="text-sm text-muted" aria-live="polite">
          {copied ? "Copied." : "Tap the code to copy it."}
        </p>
        <p className="text-sm text-muted leading-relaxed">
          This page updates when he approves it. Lost the page? Sign in here with the new passkey
          and you'll land back on your code. It lasts until{" "}
          {new Date(held.expiresAt * 1000).toLocaleDateString(undefined, {
            weekday: "long",
            month: "short",
            day: "numeric",
          })}
          , so don't delete the passkey in the meantime.
        </p>
        <Button variant="ghost" size="sm" className="w-full" onClick={startOver}>
          Start over
        </Button>
      </Shell>
    );
  }

  if (held.state === RecoveryState.APPROVED) {
    return (
      <Shell title="YOU'RE BACK">
        <p className="text-muted leading-relaxed">
          Your new passkey for <span className="text-text font-semibold">{held.username}</span> now
          signs in. Open the app and tap Sign in.
        </p>
        <Link
          to="/login"
          onClick={forgetRecovery}
          className="block w-full text-center px-7 py-3.5 rounded-md text-lg font-semibold bg-primary text-on-primary no-underline"
        >
          Sign in here
        </Link>
      </Shell>
    );
  }

  return (
    <Shell title="NO LUCK">
      <p className="text-muted leading-relaxed">
        {held.state === RecoveryState.DENIED
          ? "That request was turned down. If it was you, check with Brendan and try again."
          : "That request ran out before it was approved."}{" "}
        The passkey it made won't work; you can delete it from your passkey manager.
      </p>
      <Button variant="primary" size="lg" className="w-full" onClick={startOver}>
        Try again
      </Button>
    </Shell>
  );
}
