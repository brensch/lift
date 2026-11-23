import { useEffect, useState } from "react";
import { ConnectError } from "@connectrpc/connect";
import { adminClient, authHeaders } from "@/lib/grpc";
import type { AssistantFeedback as Feedback } from "@/gen/workout/v1/analytics_pb";
import { formatWhen } from "@/lib/format";
import { Card, DataTable } from "./parts";

/**
 * What assistants said about the MCP tools (their send_feedback), newest
 * first: what to make easier next. No user: it is about the tools.
 */
export function AssistantFeedback({ token }: { token: string }) {
  const [feedback, setFeedback] = useState<Feedback[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    adminClient
      .listAssistantFeedback({}, authHeaders(token))
      .then((r) => setFeedback(r.feedback))
      .catch((err) =>
        setError(err instanceof ConnectError ? err.rawMessage : "Couldn't load the feedback."),
      );
  }, [token]);

  return (
    <Card
      title="Assistant feedback"
      subtitle="What assistants say about the MCP tools, one line each (send_feedback), newest first."
    >
      {error ? (
        <p className="text-danger text-sm m-0">{error}</p>
      ) : feedback === null ? (
        <p className="text-sm text-muted m-0">Loading…</p>
      ) : (
        <DataTable
          head={["When", "Assistant", "Tool", "Feedback"]}
          wrap={[3]}
          maxHeight="28rem"
          empty="No assistant has sent feedback yet."
          rows={feedback.map((f) => [
            formatWhen(Number(f.createdAt) * 1000),
            f.clientName,
            f.tool || "—",
            f.text,
          ])}
        />
      )}
    </Card>
  );
}
