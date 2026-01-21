import { createPromiseClient, type Interceptor } from "@connectrpc/connect";
import { createConnectTransport } from "@connectrpc/connect-web";
import { WorkoutService } from "@/gen/workout/v1/workout_connect";

// Use relative URL in production, localhost in development
const API_BASE_URL = import.meta.env.DEV 
  ? "http://localhost:8080" 
  : window.location.origin;

// Create a client factory that includes the username header
export function createWorkoutClient(username: string) {
  const authInterceptor: Interceptor = (next) => async (req) => {
    req.header.set("X-Username", username);
    return next(req);
  };

  return createPromiseClient(WorkoutService, createConnectTransport({
    baseUrl: API_BASE_URL,
    interceptors: [authInterceptor],
  }));
}

// Export types from generated code
export * from "@/gen/workout/v1/workout_pb";
