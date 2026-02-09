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

export async function login(): Promise<AuthResponse> {
  // Step 1: Get authentication options from server
  const startData = (await authFetch('/login/start', {})) as {
    challenge_id: string;
    options: { publicKey: Record<string, unknown> };
  };

  // Step 2: Authenticate via browser WebAuthn API
  // webauthn-rs wraps options in { publicKey: { ... } } — SimpleWebAuthn expects the inner object
  const credential = await startAuthentication({
    optionsJSON: startData.options.publicKey as Parameters<typeof startAuthentication>[0]['optionsJSON'],
  });

  // Step 3: Send assertion to server
  return (await authFetch('/login/finish', {
    challenge_id: startData.challenge_id,
    credential,
  })) as AuthResponse;
}
