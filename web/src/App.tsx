import { BrowserRouter, Routes, Route } from "react-router-dom";
import { AuthProvider } from "@/lib/auth";
import { Layout } from "@/components/layout";
import { HomePage } from "@/pages/home";
import { PrivacyPage } from "@/pages/privacy";
import { DeleteAccountPage } from "@/pages/delete-account";
import { LoginPage } from "@/pages/login";
import { DashboardPage } from "@/pages/dashboard";

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          <Route element={<Layout />}>
            <Route path="/" element={<HomePage />} />
            <Route path="/privacy" element={<PrivacyPage />} />
            <Route path="/delete-account" element={<DeleteAccountPage />} />
            <Route path="/login" element={<LoginPage />} />
            <Route path="/dashboard" element={<DashboardPage />} />
            <Route path="/demo" element={<DashboardPage demo />} />
          </Route>
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  );
}
