import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { WobblyText } from "@/components/wobbly-text";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/lib/use-auth";

export function LoginPage() {
  const { user, login, devLogin, logout } = useAuth();
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [devUsername, setDevUsername] = useState("");
  const navigate = useNavigate();

  async function handleLogin() {
    setError(null);
    setLoading(true);
    try {
      await login();
      navigate("/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Login failed");
    } finally {
      setLoading(false);
    }
  }

  async function handleDevLogin() {
    if (!devLogin) return;
    setError(null);
    setLoading(true);
    try {
      await devLogin(devUsername);
      navigate("/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Dev login failed");
    } finally {
      setLoading(false);
    }
  }

  if (user) {
    return (
      <div className="flex items-center justify-center min-h-[calc(100vh-10rem)] px-5">
        <div className="border border-border rounded-xl bg-surface p-8 md:p-12 w-full max-w-md text-center space-y-6">
          <h1 className="font-display text-3xl font-extrabold tracking-tight m-0">
            <WobblyText text="SIGNED IN" seed={63} />
          </h1>
          <p className="text-muted">
            Logged in as{" "}
            <span className="text-text font-semibold">{user.username}</span>
          </p>
          <div className="flex flex-col gap-3">
            <Button
              variant="primary"
              size="lg"
              className="w-full"
              onClick={() => navigate("/dashboard")}
            >
              Go to Dashboard
            </Button>
            <Button variant="default" className="w-full" onClick={logout}>
              Sign Out
            </Button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex items-center justify-center min-h-[calc(100vh-10rem)] px-5">
      <div className="border border-border rounded-xl bg-surface p-8 md:p-12 w-full max-w-md text-center space-y-6">
        <h1 className="font-display text-3xl font-extrabold tracking-tight m-0">
          <WobblyText text="SIGN IN" seed={63} />
        </h1>

        <p className="text-muted leading-relaxed">
          Sign in with your Schlift passkey to view your workout stats and
          history online.
        </p>

        <Button
          variant="primary"
          size="lg"
          className="w-full disabled:opacity-60 disabled:cursor-not-allowed"
          onClick={handleLogin}
          disabled={loading}
        >
          {loading ? "Waiting for passkey..." : "Sign in with Passkey"}
        </Button>

        {error && <p className="text-danger font-semibold text-sm">{error}</p>}

        <p className="text-sm text-muted/70">
          You'll need a passkey created in the Schlift app.
        </p>

        {import.meta.env.DEV && devLogin && (
          <div className="border-t border-border pt-6 text-left space-y-3">
            <p className="text-xs font-semibold tracking-[0.18em] text-muted uppercase text-center">
              Dev Name Login
            </p>
            <input
              className="w-full rounded-md border border-border bg-background px-3 py-2 text-text outline-none focus:border-text"
              value={devUsername}
              onChange={(e) => setDevUsername(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter" && !loading) {
                  void handleDevLogin();
                }
              }}
              placeholder="username"
              autoCapitalize="none"
              autoCorrect="off"
              spellCheck={false}
            />
            <Button
              variant="default"
              className="w-full disabled:opacity-60 disabled:cursor-not-allowed"
              onClick={handleDevLogin}
              disabled={loading}
            >
              {loading ? "Signing in..." : "Sign in / Create Dev Account"}
            </Button>
          </div>
        )}
      </div>
    </div>
  );
}
