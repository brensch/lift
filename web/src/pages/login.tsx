import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { WobblyText } from "@/components/wobbly-text";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/lib/auth";

export function LoginPage() {
  const { user, login, logout } = useAuth();
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
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
      </div>
    </div>
  );
}
