import { createClient, type CallOptions } from "@connectrpc/connect";
import { createGrpcWebTransport } from "@connectrpc/connect-web";
import { WorkoutService, UserService } from "../gen/workout/v1/workout_pb";
import { MultiplayerService } from "../gen/workout/v1/group_pb";

const transport = createGrpcWebTransport({
  baseUrl: "http://127.0.0.1:50051",
});

export const workoutClient = createClient(WorkoutService, transport);
export const userClient = createClient(UserService, transport);
export const multiplayerClient = createClient(MultiplayerService, transport);

// Helper to create call options with user ID header
export function withUserId(userId: string): CallOptions {
  return {
    headers: {
      "x-user-id": userId,
    },
  };
}