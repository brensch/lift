import { startRegistration, startAuthentication } from '@simplewebauthn/browser';
import type { PublicKeyCredentialCreationOptionsJSON, PublicKeyCredentialRequestOptionsJSON } from '@simplewebauthn/types';

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
    options: { publicKey: PublicKeyCredentialCreationOptionsJSON };
  };

  // Force residentKey: "required" so authenticators (including YubiKeys) store
  // discoverable credentials. webauthn-rs defaults to "discouraged" which makes
  // YubiKeys store non-resident keys that can't be found during sign-in.
  const optionsJSON = startData.options.publicKey;
  optionsJSON.authenticatorSelection = {
    ...optionsJSON.authenticatorSelection,
    residentKey: 'required',
    requireResidentKey: true,
  };

  const credential = await startRegistration({ optionsJSON });

  return (await authFetch('/register/finish', {
    user_id: startData.user_id,
    credential,
  })) as AuthResponse;
}

export interface PasskeyInfo {
  credential_id: string;
  created_at: number;
  transports: string[];
}

export async function addPasskey(): Promise<void> {
  const token = localStorage.getItem('liftSessionToken');
  if (!token) throw new Error('Not authenticated');

  const startRes = await fetch(`${AUTH_BASE}/passkey/add/start`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-session-token': token,
    },
  });
  if (!startRes.ok) {
    const text = await startRes.text();
    throw new Error(text || `Request failed: ${startRes.status}`);
  }
  const startData = (await startRes.json()) as {
    options: { publicKey: PublicKeyCredentialCreationOptionsJSON };
  };

  const optionsJSON = startData.options.publicKey;
  optionsJSON.authenticatorSelection = {
    ...optionsJSON.authenticatorSelection,
    residentKey: 'required',
    requireResidentKey: true,
  };

  const credential = await startRegistration({ optionsJSON });

  const finishRes = await fetch(`${AUTH_BASE}/passkey/add/finish`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-session-token': token,
    },
    body: JSON.stringify({ credential }),
  });
  if (!finishRes.ok) {
    const text = await finishRes.text();
    throw new Error(text || `Request failed: ${finishRes.status}`);
  }
}

export async function listPasskeys(): Promise<PasskeyInfo[]> {
  const token = localStorage.getItem('liftSessionToken');
  if (!token) throw new Error('Not authenticated');

  const res = await fetch(`${AUTH_BASE}/passkeys`, {
    method: 'GET',
    headers: { 'x-session-token': token },
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(text || `Request failed: ${res.status}`);
  }
  return res.json();
}

export async function login(): Promise<AuthResponse> {
  // Get discoverable authentication challenge (empty allowCredentials)
  const startData = (await authFetch('/login/start', {})) as {
    challenge_id: string;
    options: { publicKey: PublicKeyCredentialRequestOptionsJSON };
  };

  // Modal discoverable auth — on Android this shows the credential selector
  // bottom sheet with "Sign in as [user] to [site]"
  const credential = await startAuthentication({
    optionsJSON: startData.options.publicKey,
  });

  return (await authFetch('/login/finish', {
    challenge_id: startData.challenge_id,
    credential,
  })) as AuthResponse;
}

export async function logout(): Promise<void> {
  const token = localStorage.getItem('liftSessionToken');
  if (!token) return;

  try {
    await fetch(`${AUTH_BASE}/logout`, {
      method: 'POST',
      headers: { 'x-session-token': token },
    });
  } catch (e) {
    console.error('Failed to logout on server:', e);
  }
}
