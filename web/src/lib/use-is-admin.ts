import { useEffect, useState } from "react";
import { adminClient, authHeaders } from "@/lib/grpc";
import { useAuth } from "@/lib/use-auth";

/**
 * Whether to show the stats link. Cosmetic: the server gates GetStats itself,
 * so a wrong answer here only hides or shows a link to a page that refuses.
 */
export function useIsAdmin(): boolean {
  const { user } = useAuth();
  const [adminToken, setAdminToken] = useState<string | null>(null);

  useEffect(() => {
    if (!user) return;
    let cancelled = false;
    adminClient
      .getAdminStatus({}, authHeaders(user.sessionToken))
      .then((res) => {
        if (!cancelled && res.isAdmin) setAdminToken(user.sessionToken);
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [user]);

  // Tied to the session that was checked, so logging out drops it at once.
  return user !== null && adminToken === user.sessionToken;
}
