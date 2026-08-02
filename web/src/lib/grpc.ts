import { createGrpcWebTransport } from "@connectrpc/connect-web";
import { createClient } from "@connectrpc/connect";
import { AuthService } from "@/gen/workout/v1/auth_pb";
import { SettingsService } from "@/gen/workout/v1/settings_pb";
import { WorkoutService } from "@/gen/workout/v1/workout_pb";

const transport = createGrpcWebTransport({
  baseUrl: window.location.origin,
});

export const authClient = createClient(AuthService, transport);
export const settingsClient = createClient(SettingsService, transport);
export const workoutClient = createClient(WorkoutService, transport);

export function authHeaders(token: string) {
  return { headers: { "x-session-token": token } };
}
