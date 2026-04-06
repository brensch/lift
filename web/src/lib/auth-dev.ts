import { authClient } from "./grpc";
import type { User } from "./auth-context";

export async function performDevLogin(username: string): Promise<User> {
  const normalized = username.trim();
  if (!normalized) {
    throw new Error("Username is required.");
  }
  if (/\s/.test(normalized)) {
    throw new Error("Username cannot contain spaces.");
  }

  const response = await authClient.testLogin({ username: normalized });
  return {
    userId: response.userId,
    username: response.username,
    sessionToken: response.sessionToken,
  };
}
