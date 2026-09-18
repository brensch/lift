import { createGrpcWebTransport } from "@connectrpc/connect-web";
import { createClient } from "@connectrpc/connect";
import { AdminService } from "@/gen/workout/v1/analytics_pb";
import { AuthService } from "@/gen/workout/v1/auth_pb";
import { SettingsService } from "@/gen/workout/v1/settings_pb";
import { WorkoutService } from "@/gen/workout/v1/workout_pb";

const transport = createGrpcWebTransport({
  baseUrl: window.location.origin,
  // An analytics label only: lets the server split sign-in attempts by platform.
  interceptors: [
    (next) => (req) => {
      req.header.set("x-platform", "web");
      return next(req);
    },
  ],
});

export const adminClient = createClient(AdminService, transport);
export const authClient = createClient(AuthService, transport);
export const settingsClient = createClient(SettingsService, transport);
export const workoutClient = createClient(WorkoutService, transport);

export function authHeaders(token: string) {
  return { headers: { "x-session-token": token } };
}
