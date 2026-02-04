import { createClient } from "@connectrpc/connect";
import { createConnectTransport } from "@connectrpc/connect-web";
import { AuthService } from "../gen/lift/v1/auth_pb.js";
import { WorkoutService } from "../gen/lift/v1/workout_pb.js";
import { GroupService } from "../gen/lift/v1/group_pb.js";

function getToken(): string | null {
  return localStorage.getItem("token");
}

const transport = createConnectTransport({
  baseUrl: window.location.origin,
  interceptors: [
    (next) => async (req) => {
      const token = getToken();
      if (token) {
        req.header.set("Authorization", `Bearer ${token}`);
      }
      return next(req);
    },
  ],
});

export const authClient = createClient(AuthService, transport);
export const workoutClient = createClient(WorkoutService, transport);
export const groupClient = createClient(GroupService, transport);
export { transport };
