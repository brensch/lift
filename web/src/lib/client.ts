import { createClient } from "@connectrpc/connect";
import { createGrpcWebTransport } from "@connectrpc/connect-web";
import { WorkoutService } from "../gen/workout/v1/workout_pb";

const transport = createGrpcWebTransport({
  baseUrl: "http://localhost:50051",
});

export const workoutClient = createClient(WorkoutService, transport);
