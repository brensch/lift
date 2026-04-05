import { Link, Outlet, useLocation } from "react-router-dom";
import { WobblyText } from "./wobbly-text";
import { Menu, X } from "lucide-react";
import { useState } from "react";
import { cn } from "@/lib/utils";
import { useAuth } from "@/lib/auth";

const navItems = [
  { to: "/", label: "Home" },
  { to: "/privacy", label: "Privacy" },
  { to: "/delete-account", label: "Delete Account" },
];

export function Layout() {
  const location = useLocation();
  const [menuOpen, setMenuOpen] = useState(false);
  const { user } = useAuth();

  const authLink = user
    ? { to: "/dashboard", label: user.username }
    : { to: "/login", label: "Sign In" };

  return (
    <div className="min-h-screen flex flex-col">
      <header className="border-b border-border/50 backdrop-blur-sm sticky top-0 z-50 bg-background/80">
        <div className="max-w-5xl mx-auto px-5 h-16 flex items-center justify-between">
          <Link to="/" className="no-underline">
            <h1 className="font-display text-2xl font-black tracking-[-0.06em] leading-none m-0">
              <WobblyText text="SCHLIFT" seed={42} />
            </h1>
          </Link>

          {/* Desktop nav */}
          <nav className="hidden md:flex items-center gap-1">
            {navItems.map((item) => (
              <Link
                key={item.to}
                to={item.to}
                className={cn(
                  "px-3 py-2 rounded-lg text-sm font-medium no-underline transition-colors",
                  location.pathname === item.to
                    ? "text-text bg-surface"
                    : "text-muted hover:text-text"
                )}
              >
                {item.label}
              </Link>
            ))}
            <Link
              to={authLink.to}
              className="ml-2 px-4 py-2 rounded-[10px] text-sm font-semibold bg-primary text-on-primary no-underline transition-transform hover:-translate-y-0.5"
            >
              {authLink.label}
            </Link>
          </nav>

          {/* Mobile hamburger */}
          <button
            className="md:hidden p-2 text-muted hover:text-text"
            onClick={() => setMenuOpen(!menuOpen)}
          >
            {menuOpen ? <X size={22} /> : <Menu size={22} />}
          </button>
        </div>

        {/* Mobile menu */}
        {menuOpen && (
          <nav className="md:hidden border-t border-border/50 px-5 py-4 flex flex-col gap-2 bg-background">
            {navItems.map((item) => (
              <Link
                key={item.to}
                to={item.to}
                onClick={() => setMenuOpen(false)}
                className={cn(
                  "px-3 py-2 rounded-lg text-sm font-medium no-underline transition-colors",
                  location.pathname === item.to
                    ? "text-text bg-surface"
                    : "text-muted hover:text-text"
                )}
              >
                {item.label}
              </Link>
            ))}
            <Link
              to={authLink.to}
              onClick={() => setMenuOpen(false)}
              className="px-4 py-2 rounded-[10px] text-sm font-semibold bg-primary text-on-primary no-underline text-center"
            >
              {authLink.label}
            </Link>
          </nav>
        )}
      </header>

      <main className="flex-1">
        <Outlet />
      </main>

      <footer className="border-t border-border/50 py-8 px-5">
        <div className="max-w-5xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4 text-sm text-muted">
          <span className="font-display font-bold tracking-[-0.04em]">
            SCHLIFT
          </span>
          <div className="flex gap-4">
            <Link
              to="/privacy"
              className="text-muted hover:text-text no-underline transition-colors"
            >
              Privacy
            </Link>
            <Link
              to="/delete-account"
              className="text-muted hover:text-text no-underline transition-colors"
            >
              Delete Account
            </Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
