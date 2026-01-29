import { createPromiseClient, type Interceptor } from "@connectrpc/connect";
import { createConnectTransport } from "@connectrpc/connect-web";
import { WorkoutService } from "@/gen/workout/v1/workout_connect";
import type { WorkoutUpdate } from "@/gen/workout/v1/workout_pb";

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

// Subscribe to user notifications (server streaming)
// This is the main streaming endpoint - connect on login
// Returns an AbortController to cancel the subscription
export function watchNotifications(
  username: string,
  onUpdate: (update: WorkoutUpdate) => void,
  onError?: (error: Error) => void,
  onClose?: () => void
): AbortController {
  const abortController = new AbortController();

  // Create client with auth header
  const authInterceptor: Interceptor = (next) => async (req) => {
    req.header.set("X-Username", username);
    return next(req);
  };

  const transport = createConnectTransport({
    baseUrl: API_BASE_URL,
    interceptors: [authInterceptor],
  });

  const client = createPromiseClient(WorkoutService, transport);

  // Start the streaming call
  (async () => {
    try {
      for await (const update of client.watchNotifications(
        {},
        { signal: abortController.signal }
      )) {
        onUpdate(update);
      }
      onClose?.();
    } catch (err) {
      if (abortController.signal.aborted) {
        onClose?.();
      } else {
        onError?.(err instanceof Error ? err : new Error(String(err)));
      }
    }
  })();

  return abortController;
}

// Legacy: Subscribe to workout updates (deprecated - use watchNotifications)
export function watchWorkout(
  sessionId: string,
  userId: string,
  onUpdate: (update: WorkoutUpdate) => void,
  onError?: (error: Error) => void,
  onClose?: () => void
): AbortController {
  const abortController = new AbortController();

  const transport = createConnectTransport({
    baseUrl: API_BASE_URL,
  });

  const client = createPromiseClient(WorkoutService, transport);

  // Start the streaming call
  (async () => {
    try {
      for await (const update of client.watchWorkout(
        { sessionId, userId },
        { signal: abortController.signal }
      )) {
        onUpdate(update);
      }
      onClose?.();
    } catch (err) {
      if (abortController.signal.aborted) {
        onClose?.();
      } else {
        onError?.(err instanceof Error ? err : new Error(String(err)));
      }
    }
  })();

  return abortController;
}

// Export types from generated code
export * from "@/gen/workout/v1/workout_pb";
