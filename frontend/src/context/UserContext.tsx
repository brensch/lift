import { createContext, useContext, useState, type ReactNode } from "react";
import { createWorkoutClient } from "@/lib/api";
import type { PromiseClient } from "@connectrpc/connect";
import type { WorkoutService } from "@/gen/workout/v1/workout_connect";

interface UserContextType {
  username: string | null;
  setUsername: (username: string) => void;
  client: PromiseClient<typeof WorkoutService> | null;
  logout: () => void;
}

const UserContext = createContext<UserContextType | null>(null);

export function UserProvider({ children }: { children: ReactNode }) {
  const [username, setUsernameState] = useState<string | null>(() => {
    return localStorage.getItem("lift-username");
  });
  const [client, setClient] = useState<PromiseClient<typeof WorkoutService> | null>(
    () => {
      const stored = localStorage.getItem("lift-username");
      return stored ? createWorkoutClient(stored) : null;
    }
  );

  const setUsername = (name: string) => {
    localStorage.setItem("lift-username", name);
    setUsernameState(name);
    setClient(createWorkoutClient(name));
  };

  const logout = () => {
    localStorage.removeItem("lift-username");
    setUsernameState(null);
    setClient(null);
  };

  return (
    <UserContext.Provider value={{ username, setUsername, client, logout }}>
      {children}
    </UserContext.Provider>
  );
}

export function useUser() {
  const context = useContext(UserContext);
  if (!context) {
    throw new Error("useUser must be used within a UserProvider");
  }
  return context;
}
