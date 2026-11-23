import { authClient } from "./grpc";
import type { User } from "./auth-context";

// The username rule is the server's (username_problem in src/server/auth.rs):
// a refused name comes back as its error.
export async function performDevLogin(username: string): Promise<User> {
  const response = await authClient.testLogin({ username: username.trim() });
  return {
    userId: response.userId,
    username: response.username,
    sessionToken: response.sessionToken,
  };
}
