import {
  useState,
  useEffect,
  useCallback,
  useRef,
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

function decodeClientDataChallenge(clientDataJSON: ArrayBuffer): string | null {
  try {
    const text = new TextDecoder().decode(new Uint8Array(clientDataJSON));
    const parsed = JSON.parse(text) as { challenge?: string };
    return typeof parsed.challenge === "string" ? parsed.challenge : null;
  } catch {
    return null;
  }
}

function decodeClientDataChallengeFromBase64(
  encodedClientDataJSON: string | null | undefined
): string | null {
  if (!encodedClientDataJSON) return null;
  try {
    const padded = encodedClientDataJSON
      .replace(/-/g, "+")
      .replace(/_/g, "/")
      .padEnd(Math.ceil(encodedClientDataJSON.length / 4) * 4, "=");
    const binary = atob(padded);
    const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
    return decodeClientDataChallenge(bytes.buffer);
  } catch {
    return null;
  }
}

function toBase64Url(input: ArrayBuffer | Uint8Array | null): string | null {
  if (!input) return null;

  const bytes = input instanceof Uint8Array ? input : new Uint8Array(input);
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function serializeAssertion(credential: PublicKeyCredential) {
  const response = credential.response;
  if (!(response instanceof AuthenticatorAssertionResponse)) {
    throw new Error("Unexpected passkey response type.");
  }

  return {
    id: credential.id,
    rawId: toBase64Url(credential.rawId),
    type: credential.type,
    authenticatorAttachment: credential.authenticatorAttachment ?? null,
    clientExtensionResults: credential.getClientExtensionResults(),
    response: {
      clientDataJSON: toBase64Url(response.clientDataJSON),
      authenticatorData: toBase64Url(response.authenticatorData),
      signature: toBase64Url(response.signature),
      userHandle: toBase64Url(response.userHandle),
    },
  };
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(loadSession);
  const [loading, setLoading] = useState(() => !!loadSession());
  const loginRequestRef = useRef<Promise<void> | null>(null);

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
    if (loginRequestRef.current) {
      return loginRequestRef.current;
    }

    const loginPromise = (async () => {
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
      const parsedOptions = JSON.parse(startResp.optionsJson) as {
        publicKey?: unknown;
        mediation?: CredentialMediationRequirement;
      };
      const publicKeyJson = parsedOptions.publicKey ?? parsedOptions;
      const publicKey = (
        PublicKeyCredential as unknown as {
          parseRequestOptionsFromJSON: (
            opts: unknown
          ) => CredentialRequestOptions["publicKey"];
        }
      ).parseRequestOptionsFromJSON(publicKeyJson);

      const credential = await navigator.credentials.get({
        publicKey,
        mediation: parsedOptions.mediation,
      });
      if (!credential) throw new Error("No passkey response was returned.");
      if (!(credential instanceof PublicKeyCredential)) {
        throw new Error("Unexpected passkey credential type.");
      }

      const requestChallenge =
        typeof startResp.optionsJson === "string"
          ? (JSON.parse(startResp.optionsJson) as { challenge?: string })
              .challenge ?? null
          : null;
      const response = credential.response as AuthenticatorAssertionResponse;
      const responseChallenge = decodeClientDataChallenge(response.clientDataJSON);

      if (requestChallenge && responseChallenge !== requestChallenge) {
        console.error("WebAuthn challenge mismatch before loginFinish", {
          requestChallenge,
          responseChallenge,
          challengeId: startResp.challengeId,
        });
        throw new Error("Passkey response challenge did not match request.");
      }

      const credentialJson = serializeAssertion(credential);
      const serializedChallenge = decodeClientDataChallengeFromBase64(
        credentialJson.response.clientDataJSON
      );

      if (requestChallenge && serializedChallenge !== requestChallenge) {
        console.error("WebAuthn serialized payload challenge mismatch", {
          requestChallenge,
          rawResponseChallenge: responseChallenge,
          serializedChallenge,
          challengeId: startResp.challengeId,
          serializedClientDataJSON: credentialJson.response.clientDataJSON,
        });
        throw new Error("Serialized passkey payload challenge did not match request.");
      }

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
    })();

    loginRequestRef.current = loginPromise;

    try {
      await loginPromise;
    } finally {
      if (loginRequestRef.current === loginPromise) {
        loginRequestRef.current = null;
      }
    }
  }, []);

  const devLogin: ((username: string) => Promise<void>) | undefined =
    import.meta.env.DEV
      ? async (username: string) => {
          const { performDevLogin } = await import("./auth-dev");
          const newUser = await performDevLogin(username);
          saveSession(newUser);
          setUser(newUser);
        }
      : undefined;

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
    <AuthContext.Provider value={{ user, loading, login, devLogin, logout }}>
      {children}
    </AuthContext.Provider>
  );
}
