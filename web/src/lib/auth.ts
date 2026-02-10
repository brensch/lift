import { startRegistration, startAuthentication, browserSupportsWebAuthnAutofill } from '@simplewebauthn/browser';

const AUTH_BASE = `${window.location.origin}/auth`;

interface AuthResponse {
  session_token: string;
  user_id: string;
  username: string;
}

interface LoginStartData {
  challenge_id: string;
  options: { publicKey: Record<string, unknown> };
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
  // Step 1: Get registration options from server
  const startData = (await authFetch('/register/start', { username })) as {
    user_id: string;
    options: { publicKey: Record<string, unknown> };
  };

  // Step 2: Create credential via browser WebAuthn API
  // webauthn-rs wraps options in { publicKey: { ... } } — SimpleWebAuthn expects the inner object
  const credential = await startRegistration({
    optionsJSON: startData.options.publicKey as Parameters<typeof startRegistration>[0]['optionsJSON'],
  });

  // Step 3: Send credential to server
  return (await authFetch('/register/finish', {
    user_id: startData.user_id,
    credential,
  })) as AuthResponse;
}

export async function login(username?: string): Promise<AuthResponse> {
  const startData = await loginStart(username);
  return loginFinish(startData);
}

/** Start login flow — get challenge from server */
export async function loginStart(username?: string): Promise<LoginStartData> {
  const body: Record<string, unknown> = {};
  if (username) {
    body.username = username;
  }
  return (await authFetch('/login/start', body)) as LoginStartData;
}

/** Finish login flow — authenticate with browser and verify with server */
export async function loginFinish(
  startData: LoginStartData,
  useBrowserAutofill = false,
): Promise<AuthResponse> {
  // webauthn-rs wraps options in { publicKey: { ... } } — SimpleWebAuthn expects the inner object
  const credential = await startAuthentication({
    optionsJSON: startData.options.publicKey as Parameters<typeof startAuthentication>[0]['optionsJSON'],
    useBrowserAutofill,
  });

  return (await authFetch('/login/finish', {
    challenge_id: startData.challenge_id,
    credential,
  })) as AuthResponse;
}

export { browserSupportsWebAuthnAutofill };
