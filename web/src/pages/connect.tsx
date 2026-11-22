import { useEffect, useMemo, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { ConnectError } from "@connectrpc/connect";
import { WobblyText } from "@/components/wobbly-text";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/lib/use-auth";
import { assistantClient, authHeaders } from "@/lib/grpc";
import type {
  AssistantGrant,
  ConnectRequest,
  DescribeConnectResponse,
} from "@/gen/workout/v1/assistant_pb";

// The OAuth authorization endpoint for MCP: an assistant sends the person
// here to allow it (src/mcp). Opened without a request, it lists the
// assistants they've allowed, with Revoke.

function message(err: unknown, fallback: string): string {
  if (err instanceof ConnectError) return err.rawMessage;
  if (err instanceof Error) return err.message;
  return fallback;
}

function Card({
  title,
  seed,
  children,
}: {
  title: string;
  seed: number;
  children: React.ReactNode;
}) {
  return (
    <div className="flex items-center justify-center min-h-[calc(100vh-10rem)] px-5">
      <div className="border border-border rounded-xl bg-surface p-8 md:p-12 w-full max-w-md space-y-6">
        <h1 className="font-display text-3xl font-extrabold tracking-tight m-0">
          <WobblyText text={title} seed={seed} />
        </h1>
        {children}
      </div>
    </div>
  );
}

export function ConnectPage() {
  const [params] = useSearchParams();
  const request: ConnectRequest | null = useMemo(() => {
    const clientId = params.get("client_id");
    if (!clientId || params.get("response_type") !== "code") return null;
    return {
      $typeName: "workout.v1.ConnectRequest",
      clientId,
      redirectUri: params.get("redirect_uri") ?? "",
      codeChallenge: params.get("code_challenge") ?? "",
      codeChallengeMethod: params.get("code_challenge_method") ?? "",
      state: params.get("state") ?? "",
      scope: params.get("scope") ?? "",
      resource: params.get("resource") ?? "",
    };
  }, [params]);
  return request ? <Consent request={request} /> : <Connected />;
}

function Consent({ request }: { request: ConnectRequest }) {
  const { user, login } = useAuth();
  const [described, setDescribed] = useState<DescribeConnectResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    assistantClient
      .describeConnect({ request })
      .then(setDescribed)
      .catch((err) => setError(message(err, "This request can't be used.")));
  }, [request]);

  async function answer(allow: boolean) {
    if (!user) return;
    setBusy(true);
    setError(null);
    try {
      const { redirectTo } = await assistantClient.answerConnect(
        { request, allow },
        authHeaders(user.sessionToken),
      );
      window.location.assign(redirectTo);
    } catch (err) {
      setError(message(err, "That didn't work. Try again."));
      setBusy(false);
    }
  }

  async function signIn() {
    setBusy(true);
    setError(null);
    try {
      await login();
    } catch (err) {
      setError(message(err, "Sign-in failed"));
    } finally {
      setBusy(false);
    }
  }

  if (!described) {
    return (
      <Card title="CONNECT" seed={71}>
        {error ? (
          <p className="text-danger font-semibold text-sm">{error}</p>
        ) : (
          <p className="text-muted">Checking the request…</p>
        )}
      </Card>
    );
  }

  return (
    <Card title="CONNECT" seed={71}>
      <p className="text-muted leading-relaxed">
        <span className="text-text font-semibold">{described.clientName}</span> wants to connect to
        your Schlift account. It will be able to:
      </p>
      <ul className="m-0 pl-5 space-y-1 text-text">
        {described.can.map((line) => (
          <li key={line}>{line}</li>
        ))}
      </ul>
      <p className="text-sm text-muted">
        You'll go back to <span className="font-semibold text-text">{described.redirectHost}</span>.
        You can cut it off any time from this page or the app.
      </p>
      {user ? (
        <div className="flex flex-col gap-3">
          <Button
            variant="primary"
            size="lg"
            className="w-full"
            disabled={busy}
            onClick={() => answer(true)}
          >
            Allow as {user.username}
          </Button>
          <Button
            variant="default"
            className="w-full"
            disabled={busy}
            onClick={() => answer(false)}
          >
            Don't allow
          </Button>
        </div>
      ) : (
        <Button variant="primary" size="lg" className="w-full" disabled={busy} onClick={signIn}>
          {busy ? "Waiting for passkey..." : "Sign in with Passkey"}
        </Button>
      )}
      {error && <p className="text-danger font-semibold text-sm">{error}</p>}
    </Card>
  );
}

function Connected() {
  const { user } = useAuth();
  const [grants, setGrants] = useState<AssistantGrant[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!user) return;
    assistantClient
      .listAssistants({}, authHeaders(user.sessionToken))
      .then((r) => setGrants(r.grants))
      .catch((err) => setError(message(err, "Couldn't load them.")));
  }, [user]);

  async function revoke(grantId: string) {
    if (!user) return;
    try {
      await assistantClient.revokeAssistant({ grantId }, authHeaders(user.sessionToken));
      setGrants((g) => (g ?? []).filter((x) => x.grantId !== grantId));
    } catch (err) {
      setError(message(err, "Couldn't revoke it."));
    }
  }

  if (!user) {
    return (
      <Card title="ASSISTANTS" seed={72}>
        <p className="text-muted">
          <Link to="/login" className="text-text font-semibold hover:underline">
            Sign in
          </Link>{" "}
          to see the assistants you've connected.
        </p>
      </Card>
    );
  }

  return (
    <Card title="ASSISTANTS" seed={72}>
      <p className="text-muted leading-relaxed">
        Assistants you've connected can read your training and set your program.
      </p>
      {grants === null && !error && <p className="text-muted">Loading…</p>}
      {grants?.length === 0 && <p className="text-muted">None yet.</p>}
      <ul className="list-none p-0 m-0 divide-y divide-border">
        {grants?.map((g) => (
          <li key={g.grantId} className="py-3 flex items-center justify-between gap-3">
            <div className="min-w-0">
              <div className="font-semibold text-text truncate">{g.clientName}</div>
              <div className="text-sm text-muted">
                {Number(g.lastUsedAt) > 0
                  ? `Last used ${new Date(Number(g.lastUsedAt) * 1000).toLocaleDateString()}`
                  : "Not used yet"}
              </div>
            </div>
            <Button variant="default" onClick={() => revoke(g.grantId)}>
              Revoke
            </Button>
          </li>
        ))}
      </ul>
      {error && <p className="text-danger font-semibold text-sm">{error}</p>}
    </Card>
  );
}
