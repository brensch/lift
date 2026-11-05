import { BrowserRouter, Routes, Route } from "react-router-dom";
import { AuthProvider } from "@/lib/auth";
import { Layout } from "@/components/layout";
import { HomePage } from "@/pages/home";
import { PrivacyPage } from "@/pages/privacy";
import { RoutinesPage } from "@/pages/routines";
import { DeleteAccountPage } from "@/pages/delete-account";
import { LoginPage } from "@/pages/login";
import { DashboardPage } from "@/pages/dashboard";
import { AdminPage } from "@/pages/admin";

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          <Route element={<Layout />}>
            <Route path="/" element={<HomePage />} />
            <Route path="/routines" element={<RoutinesPage />} />
            <Route path="/privacy" element={<PrivacyPage />} />
            <Route path="/delete-account" element={<DeleteAccountPage />} />
            <Route path="/login" element={<LoginPage />} />
            <Route path="/dashboard" element={<DashboardPage key="live" />} />
            <Route path="/demo" element={<DashboardPage key="demo" demo />} />
            <Route path="/admin" element={<AdminPage />} />
          </Route>
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  );
}
