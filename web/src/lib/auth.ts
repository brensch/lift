import { startRegistration, startAuthentication } from '@simplewebauthn/browser';
import type { PublicKeyCredentialCreationOptionsJSON, PublicKeyCredentialRequestOptionsJSON } from '@simplewebauthn/types';
import { authClient, withUserId } from './client';

export interface AuthResponse {
  sessionToken: string;
  userId: string;
  username: string;
}

export async function register(username: string, name?: string): Promise<AuthResponse> {
  const startData = await authClient.registerStart({ username });

  const optionsJSON = JSON.parse(startData.optionsJson) as PublicKeyCredentialCreationOptionsJSON;
  
  // Force residentKey: "required" so authenticators (including YubiKeys) store
  // discoverable credentials. webauthn-rs defaults to "discouraged" which makes
  // YubiKeys store non-resident keys that can't be found during sign-in.
  optionsJSON.authenticatorSelection = {
    ...optionsJSON.authenticatorSelection,
    residentKey: 'required',
    requireResidentKey: true,
  };

  const credential = await startRegistration({ optionsJSON });

  const finishData = await authClient.registerFinish({
    userId: startData.userId,
    credentialJson: JSON.stringify(credential),
    name: name || 'signup key',
  });

  return finishData;
}

export interface PasskeyInfo {
  credentialId: string;
  name?: string;
  createdAt: bigint;
  createdAtIp?: string;
  transports: string[];
}

export async function addPasskey(name?: string): Promise<void> {
  const startData = await authClient.addPasskeyStart({}, withUserId(''));

  const optionsJSON = JSON.parse(startData.optionsJson) as PublicKeyCredentialCreationOptionsJSON;
  optionsJSON.authenticatorSelection = {
    ...optionsJSON.authenticatorSelection,
    residentKey: 'required',
    requireResidentKey: true,
  };

  const credential = await startRegistration({ optionsJSON });

  await authClient.addPasskeyFinish({
    credentialJson: JSON.stringify(credential),
    name,
  }, withUserId(''));
}

export async function listPasskeys(): Promise<PasskeyInfo[]> {
  const res = await authClient.listPasskeys({}, withUserId(''));
  return res.passkeys;
}

export async function deletePasskey(credentialId: string): Promise<void> {
  await authClient.deletePasskey({ credentialId }, withUserId(''));
}

export async function login(): Promise<AuthResponse> {
  const startData = await authClient.loginStart({});

  const optionsJSON = JSON.parse(startData.optionsJson) as PublicKeyCredentialRequestOptionsJSON;

  const credential = await startAuthentication({
    optionsJSON,
  });

  const finishData = await authClient.loginFinish({
    challengeId: startData.challengeId,
    credentialJson: JSON.stringify(credential),
  });

  return finishData;
}

export async function logout(): Promise<void> {
  try {
    await authClient.logout({}, withUserId(''));
  } catch (e) {
    console.error('Failed to logout on server:', e);
  }
}
