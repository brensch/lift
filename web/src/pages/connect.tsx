import { useEffect, useMemo, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { ConnectError } from "@connectrpc/connect";
import { WobblyText } from "@/components/wobbly-text";
import { Button } from "@/components/ui/button";
import { FlatHeading, FlatRow, FlatSection } from "@/components/flat";
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

// A page in the app's flat style: the title section, then full-width
// sections under it.
function Page({
  title,
  seed,
  intro,
  children,
}: {
  title: string;
  seed: number;
  intro?: React.ReactNode;
  children?: React.ReactNode;
}) {
  return (
    <div className="pb-16">
      <FlatSection className="pt-10 pb-6 space-y-3">
        <h1 className="font-display text-3xl font-extrabold tracking-tight m-0">
          <WobblyText text={title} seed={seed} />
        </h1>
        {intro && <div className="text-lg leading-snug text-text">{intro}</div>}
      </FlatSection>
      {children}
    </div>
  );
}

function Problem({ children }: { children: React.ReactNode }) {
  return <p className="m-0 text-danger font-semibold text-sm">{children}</p>;
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
      <Page
        title="CONNECT"
        seed={71}
        intro={
          error ? (
            <Problem>{error}</Problem>
          ) : (
            <span className="text-muted">Checking the request…</span>
          )
        }
      />
    );
  }

  return (
    <Page
      title="CONNECT"
      seed={71}
      intro={
        <>
          <span className="font-bold">{described.clientName}</span> wants to connect to your Schlift
          account.
        </>
      }
    >
      <FlatHeading>It will be able to</FlatHeading>
      {described.can.map((line) => (
        <FlatRow key={line} label={line} />
      ))}
      <FlatHeading>It can't</FlatHeading>
      <FlatRow label="Record or delete your training" />
      <FlatRow label="Fix your shoulder injury" />
      <FlatSection className="space-y-3">
        {user ? (
          <>
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
          </>
        ) : (
          <Button variant="primary" size="lg" className="w-full" disabled={busy} onClick={signIn}>
            {busy ? "Waiting for passkey..." : "Sign in with Passkey"}
          </Button>
        )}
        {error && <Problem>{error}</Problem>}
        <p className="m-0 text-sm text-muted leading-relaxed">
          Revoke at any time in settings, or remove the connector from the AI. You'll go back to{" "}
          <span className="font-mono text-text">{described.redirectHost}</span>.
        </p>
      </FlatSection>
    </Page>
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
      <Page
        title="ASSISTANTS"
        seed={72}
        intro={
          <span className="text-muted">
            <Link to="/login" className="text-text font-semibold hover:underline">
              Sign in
            </Link>{" "}
            to see the assistants you've connected.
          </span>
        }
      />
    );
  }

  return (
    <Page
      title="ASSISTANTS"
      seed={72}
      intro={
        <span className="text-muted">
          Assistants you've connected can read your training and set your program.
        </span>
      }
    >
      <FlatHeading>Connected</FlatHeading>
      {grants === null && !error && (
        <FlatRow label={<span className="text-muted font-normal">Loading…</span>} />
      )}
      {grants?.length === 0 && (
        <FlatRow label={<span className="text-muted font-normal">None yet.</span>} />
      )}
      {grants?.map((g) => (
        <FlatRow
          key={g.grantId}
          label={g.clientName}
          sub={
            Number(g.lastUsedAt) > 0
              ? `Last used ${new Date(Number(g.lastUsedAt) * 1000).toLocaleDateString()}`
              : "Not used yet"
          }
          right={
            <Button variant="default" onClick={() => revoke(g.grantId)}>
              Revoke
            </Button>
          }
        />
      ))}
      {error && (
        <FlatSection>
          <Problem>{error}</Problem>
        </FlatSection>
      )}
    </Page>
  );
}
