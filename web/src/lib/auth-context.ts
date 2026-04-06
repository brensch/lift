import { createContext } from "react";

export interface User {
  userId: string;
  username: string;
  sessionToken: string;
}

export interface AuthContextValue {
  user: User | null;
  loading: boolean;
  login: () => Promise<void>;
  devLogin?: (username: string) => Promise<void>;
  logout: () => Promise<void>;
}

export const AuthContext = createContext<AuthContextValue | null>(null);
