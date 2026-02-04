import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { AuthProvider, useAuth } from "./context/AuthContext";
import { useInviteListener } from "./hooks/useGroupWorkout";
import { Login } from "./components/Login";
import { Home } from "./pages/Home";
import { WorkoutPage } from "./pages/Workout";
import { History } from "./pages/History";

function AppRoutes() {
  const { isAuthenticated } = useAuth();
  const { invite, clearInvite } = useInviteListener(isAuthenticated);

  if (!isAuthenticated) {
    return <Login />;
  }

  return (
    <Routes>
      <Route
        path="/"
        element={<Home invite={invite} onClearInvite={clearInvite} />}
      />
      <Route path="/workout/:id" element={<WorkoutPage />} />
      <Route path="/workout" element={<WorkoutPage />} />
      <Route path="/history" element={<History />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>
    </BrowserRouter>
  );
}
