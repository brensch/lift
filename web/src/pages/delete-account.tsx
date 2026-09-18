import { useState } from "react";
import { WobblyText } from "@/components/wobbly-text";
import { Button } from "@/components/ui/button";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";
import { authClient, authHeaders } from "@/lib/grpc";
import { useAuth } from "@/lib/use-auth";

export function DeleteAccountPage() {
  const { user, login, logout } = useAuth();
  const [status, setStatus] = useState<{
    text: string;
    type: "info" | "ok" | "error";
  } | null>(null);
  const [loading, setLoading] = useState(false);
  const [confirming, setConfirming] = useState(false);
  // Once the account is gone the button must not be usable again: a second
  // click would only ask a deleted account for its passkey.
  const [deleted, setDeleted] = useState(false);

  async function handleDelete() {
    setConfirming(false);
    setLoading(true);
    setStatus(null);

    try {
      let token: string;

      if (user) {
        token = user.sessionToken;
      } else {
        // Need to authenticate first
        setStatus({
          text: "Authenticating with passkey...",
          type: "info",
        });
        await login();
        // After login, user state is updated — but we need the token now.
        // Re-read from localStorage since state update is async.
        const storedToken = localStorage.getItem("schlift_session_token");
        if (!storedToken) throw new Error("Login succeeded but no token found.");
        token = storedToken;
      }

      setStatus({ text: "Deleting your account data...", type: "info" });

      const resp = await authClient.deleteAccount(
        {},
        authHeaders(token)
      );

      // Clear local session since account is gone
      await logout();

      setDeleted(true);
      setStatus({
        text: `Account deleted (user id: ${resp.deletedUserId})`,
        type: "ok",
      });
    } catch (err) {
      setStatus({
        text: err instanceof Error ? err.message : "Delete request failed",
        type: "error",
      });
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="max-w-3xl mx-auto px-5 py-12">
      <div className="border border-border rounded-xl bg-surface p-6 md:p-10 space-y-5">
        <h1 className="font-display text-[clamp(1.5rem,3vw,2.2rem)] font-extrabold tracking-tight m-0">
          <WobblyText text="DELETE ACCOUNT" seed={91} />
        </h1>

        <div className="border border-danger-border bg-danger-bg rounded-[10px] p-4">
          <p className="text-danger-text font-semibold text-[0.95rem] leading-relaxed m-0">
            This action permanently deletes your account, passkeys, workout
            history, heart-rate data, and active sessions.
          </p>
        </div>

        {!deleted && (
          <p className="text-muted leading-relaxed">
            {user
              ? `Signed in as ${user.username}. Click below to permanently delete your account.`
              : "You'll authenticate with a passkey to prove account ownership, then your data will be deleted."}
          </p>
        )}

        <div>
          <Button
            variant="primary"
            onClick={() => setConfirming(true)}
            disabled={loading || deleted}
            className="disabled:opacity-60 disabled:cursor-not-allowed disabled:hover:translate-y-0"
          >
            {deleted
              ? "Account deleted"
              : loading
                ? "Processing..."
                : user
                  ? "Delete my account"
                  : "Authenticate & delete my account"}
          </Button>
        </div>

        <ConfirmDialog
          open={confirming}
          title={user ? `Delete ${user.username}?` : "Delete your account?"}
          confirmLabel={user ? "Delete permanently" : "Authenticate & delete"}
          onConfirm={handleDelete}
          onCancel={() => setConfirming(false)}
        >
          <p className="m-0">
            This permanently deletes the account, its passkeys, workout history
            and heart-rate data. It cannot be undone.
          </p>
          {!user && (
            <p className="m-0 mt-2">
              You'll be asked for your passkey first, to prove the account is
              yours.
            </p>
          )}
        </ConfirmDialog>

        {status && (
          <p
            className={`font-semibold ${
              status.type === "ok"
                ? "text-ok"
                : status.type === "error"
                  ? "text-danger"
                  : "text-muted"
            }`}
          >
            {status.text}
          </p>
        )}

        <p className="text-sm text-muted">
          If passkeys are unsupported, open this page in a modern browser with
          WebAuthn support.
        </p>
      </div>
    </div>
  );
}
