import { Navigate } from "react-router-dom";
import { WobblyText } from "@/components/wobbly-text";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/lib/auth";
import { LogOut } from "lucide-react";

export function DashboardPage() {
  const { user, loading, logout } = useAuth();

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[calc(100vh-10rem)]">
        <p className="text-muted">Loading...</p>
      </div>
    );
  }

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  return (
    <div className="max-w-5xl mx-auto px-5 py-12">
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="font-display text-[clamp(1.5rem,3vw,2.2rem)] font-extrabold tracking-tight m-0">
            <WobblyText text={`HEY ${user.username.toUpperCase()}`} seed={88} />
          </h1>
          <p className="text-muted mt-1">Your workout dashboard</p>
        </div>
        <Button variant="ghost" size="sm" onClick={logout}>
          <LogOut size={16} className="mr-1.5" />
          Sign Out
        </Button>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <StatCard title="Stats" value="Coming soon" subtitle="Workout stats and PR tracking will live here." />
        <StatCard title="History" value="Coming soon" subtitle="Browse your past workouts and progress over time." />
        <StatCard title="Programs" value="Coming soon" subtitle="View and manage your training program state." />
      </div>
    </div>
  );
}

function StatCard({
  title,
  value,
  subtitle,
}: {
  title: string;
  value: string;
  subtitle: string;
}) {
  return (
    <div className="border border-border rounded-xl bg-surface p-6">
      <p className="text-sm text-muted font-medium">{title}</p>
      <p className="font-display text-2xl font-bold tracking-tight mt-1 text-text">
        {value}
      </p>
      <p className="text-sm text-muted mt-2 leading-relaxed">{subtitle}</p>
    </div>
  );
}
