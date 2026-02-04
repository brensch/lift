import {
  createContext,
  useContext,
  useState,
  useEffect,
  type ReactNode,
} from "react";
import { authClient } from "../lib/api";

interface AuthState {
  token: string | null;
  userId: string | null;
  name: string | null;
}

interface AuthContextType extends AuthState {
  signup: (name: string) => Promise<void>;
  login: (name: string) => Promise<void>;
  logout: () => void;
  isAuthenticated: boolean;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>(() => ({
    token: localStorage.getItem("token"),
    userId: localStorage.getItem("userId"),
    name: localStorage.getItem("name"),
  }));

  useEffect(() => {
    if (state.token) {
      localStorage.setItem("token", state.token);
      localStorage.setItem("userId", state.userId!);
      localStorage.setItem("name", state.name!);
    } else {
      localStorage.removeItem("token");
      localStorage.removeItem("userId");
      localStorage.removeItem("name");
    }
  }, [state]);

  const signup = async (name: string) => {
    const res = await authClient.signup({ name });
    setState({ token: res.token, userId: res.userId, name: res.name });
  };

  const login = async (name: string) => {
    const res = await authClient.login({ name });
    setState({ token: res.token, userId: res.userId, name: res.name });
  };

  const logout = () => {
    setState({ token: null, userId: null, name: null });
  };

  return (
    <AuthContext.Provider
      value={{
        ...state,
        signup,
        login,
        logout,
        isAuthenticated: !!state.token,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
