// A recovery this browser is waiting on (see pages/recover.tsx): someone who
// lost their passkey made a new one here, and it is held until an admin
// approves it. Until then the browser is not signed in to anything; it only
// remembers which request is its own, so the code can be shown again.

/** The request's id: what lets its state be read, and no use otherwise. */
const REQUEST_KEY = "schlift_recovery_request";
/** The username it was made for, as typed. */
const NAME_KEY = "schlift_recovery_username";

/** On a sign-in refused because its passkey is still waiting: its request. */
export const RECOVERY_REQUEST_HEADER = "x-recovery-request";

export function waitingRecovery(): string | null {
  return localStorage.getItem(REQUEST_KEY);
}

export function waitingRecoveryName(): string {
  return localStorage.getItem(NAME_KEY) ?? "";
}

/** Remember the request; `username` only when this browser made it. */
export function rememberRecovery(requestId: string, username?: string) {
  localStorage.setItem(REQUEST_KEY, requestId);
  if (username) localStorage.setItem(NAME_KEY, username);
}

export function forgetRecovery() {
  localStorage.removeItem(REQUEST_KEY);
  localStorage.removeItem(NAME_KEY);
}
