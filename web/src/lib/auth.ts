import { startRegistration, startAuthentication } from '@simplewebauthn/browser';

const AUTH_BASE = `${window.location.origin}/auth`;

interface AuthResponse {
  session_token: string;
  user_id: string;
  username: string;
}

async function authFetch(path: string, body: unknown): Promise<unknown> {
  const res = await fetch(`${AUTH_BASE}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(text || `Request failed: ${res.status}`);
  }
  return res.json();
}

export async function register(username: string): Promise<AuthResponse> {
  const startData = (await authFetch('/register/start', { username })) as {
    user_id: string;
    options: { publicKey: Record<string, unknown> };
  };

  // Force residentKey: "required" so authenticators (including YubiKeys) store
  // discoverable credentials. webauthn-rs defaults to "discouraged" which makes
  // YubiKeys store non-resident keys that can't be found during sign-in.
  const optionsJSON = startData.options.publicKey as Record<string, unknown>;
  const authSel = (optionsJSON.authenticatorSelection ?? {}) as Record<string, unknown>;
  authSel.residentKey = 'required';
  authSel.requireResidentKey = true;
  optionsJSON.authenticatorSelection = authSel;

  const credential = await startRegistration({
    optionsJSON: optionsJSON as Parameters<typeof startRegistration>[0]['optionsJSON'],
  });

  return (await authFetch('/register/finish', {
    user_id: startData.user_id,
    credential,
  })) as AuthResponse;
}

export async function login(): Promise<AuthResponse> {
  // Get discoverable authentication challenge (empty allowCredentials)
  const startData = (await authFetch('/login/start', {})) as {
    challenge_id: string;
    options: { publicKey: Record<string, unknown> };
  };

  // Modal discoverable auth — on Android this shows the credential selector
  // bottom sheet with "Sign in as [user] to [site]"
  const credential = await startAuthentication({
    optionsJSON: startData.options.publicKey as Parameters<typeof startAuthentication>[0]['optionsJSON'],
  });

  return (await authFetch('/login/finish', {
    challenge_id: startData.challenge_id,
    credential,
  })) as AuthResponse;
}
