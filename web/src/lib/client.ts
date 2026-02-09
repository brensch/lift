import { createClient, type CallOptions } from "@connectrpc/connect";
import { createGrpcWebTransport } from "@connectrpc/connect-web";
import { WorkoutService, UserService } from "../gen/workout/v1/workout_pb";
import { MultiplayerService } from "../gen/workout/v1/group_pb";

const transport = createGrpcWebTransport({
  baseUrl: window.location.origin,
});

export const workoutClient = createClient(WorkoutService, transport);
export const userClient = createClient(UserService, transport);
export const multiplayerClient = createClient(MultiplayerService, transport);

// Helper to create call options with auth header.
// Prefers session token if available, falls back to raw user ID.
export function withUserId(userId: string): CallOptions {
  const token = localStorage.getItem('liftSessionToken');
  if (token) {
    return { headers: { 'x-session-token': token } };
  }
  return { headers: { 'x-user-id': userId } };
}