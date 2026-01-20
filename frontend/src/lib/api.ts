import { createPromiseClient, type Interceptor } from "@connectrpc/connect";
import { createConnectTransport } from "@connectrpc/connect-web";
import { WorkoutService } from "@/gen/workout/v1/workout_connect";

// Create a client factory that includes the username header
export function createWorkoutClient(username: string) {
  const authInterceptor: Interceptor = (next) => async (req) => {
    req.header.set("X-Username", username);
    return next(req);
  };

  return createPromiseClient(WorkoutService, createConnectTransport({
    baseUrl: "http://localhost:8080",
    interceptors: [authInterceptor],
  }));
}

// Export types from generated code
export * from "@/gen/workout/v1/workout_pb";
