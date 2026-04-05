import {
  useState,
  useEffect,
  useCallback,
  type ReactNode,
} from "react";
import { authClient, authHeaders } from "./grpc";
import { AuthContext, type User } from "./auth-context";

const TOKEN_KEY = "schlift_session_token";
const USER_KEY = "schlift_user";

function loadSession(): User | null {
  const token = localStorage.getItem(TOKEN_KEY);
  const raw = localStorage.getItem(USER_KEY);
  if (!token || !raw) return null;
  try {
    const parsed = JSON.parse(raw);
    return { ...parsed, sessionToken: token };
  } catch {
    return null;
  }
}

function saveSession(user: User) {
  localStorage.setItem(TOKEN_KEY, user.sessionToken);
  localStorage.setItem(
    USER_KEY,
    JSON.stringify({ userId: user.userId, username: user.username })
  );
}

function clearSession() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(USER_KEY);
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(loadSession);
  const [loading, setLoading] = useState(() => !!loadSession());

  // Validate existing session on mount
  useEffect(() => {
    const existing = loadSession();
    if (!existing) return;

    authClient
      .listPasskeys({}, authHeaders(existing.sessionToken))
      .then(() => {
        setUser(existing);
      })
      .catch(() => {
        clearSession();
        setUser(null);
      })
      .finally(() => setLoading(false));
  }, []);

  const login = useCallback(async () => {
    if (
      !window.PublicKeyCredential ||
      !(
        PublicKeyCredential as unknown as {
          parseRequestOptionsFromJSON?: unknown;
        }
      ).parseRequestOptionsFromJSON
    ) {
      throw new Error("Passkeys are not supported in this browser.");
    }

    // Step 1: LoginStart via gRPC
    const startResp = await authClient.loginStart({});

    // Step 2: Browser passkey ceremony
    const publicKey = (
      PublicKeyCredential as unknown as {
        parseRequestOptionsFromJSON: (
          opts: unknown
        ) => CredentialRequestOptions["publicKey"];
      }
    ).parseRequestOptionsFromJSON(JSON.parse(startResp.optionsJson));

    const credential = await navigator.credentials.get({ publicKey });
    if (!credential) throw new Error("No passkey response was returned.");

    const credentialJson = (
      credential as unknown as { toJSON?: () => unknown }
    ).toJSON?.();
    if (!credentialJson) throw new Error("Credential serialization failed.");

    // Step 3: LoginFinish via gRPC
    const finishResp = await authClient.loginFinish({
      challengeId: startResp.challengeId,
      credentialJson: JSON.stringify(credentialJson),
    });

    const newUser: User = {
      userId: finishResp.userId,
      username: finishResp.username,
      sessionToken: finishResp.sessionToken,
    };
    saveSession(newUser);
    setUser(newUser);
  }, []);

  const logout = useCallback(async () => {
    if (user) {
      try {
        await authClient.logout({}, authHeaders(user.sessionToken));
      } catch {
        // ignore — clearing local state regardless
      }
    }
    clearSession();
    setUser(null);
  }, [user]);

  return (
    <AuthContext.Provider value={{ user, loading, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}
