import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { useWorkout } from "../hooks/useWorkout";
import { groupClient } from "../lib/api";
import type { InviteEvent } from "../gen/lift/v1/group_pb.js";
import { GroupInviteBanner } from "../components/GroupInviteBanner";

interface HomeProps {
  invite: InviteEvent | null;
  onClearInvite: () => void;
}

export function Home({ invite, onClearInvite }: HomeProps) {
  const { name, logout } = useAuth();
  const { startWorkout, loading } = useWorkout();
  const navigate = useNavigate();
  const [inviteUserId, setInviteUserId] = useState("");
  const [users, setUsers] = useState<{ id: string; name: string }[]>([]);
  const [showInvite, setShowInvite] = useState(false);

  const handleStartWorkout = async () => {
    const state = await startWorkout();
    if (state?.workout) {
      navigate(`/workout/${state.workout.id}`);
    }
  };

  const handleInviteAccept = async (groupWorkoutId: string) => {
    onClearInvite();
    navigate(`/workout?group=${groupWorkoutId}`);
  };

  const handleShowInvite = async () => {
    try {
      const res = await groupClient.listUsers({});
      setUsers(res.users.map((u) => ({ id: u.id, name: u.name })));
      setShowInvite(true);
    } catch (e) {
      console.error("Failed to list users:", e);
    }
  };

  const handleSendInvite = async () => {
    if (!inviteUserId) return;
    try {
      await groupClient.inviteUser({ targetUserId: inviteUserId });
      setShowInvite(false);
      setInviteUserId("");
    } catch (e) {
      console.error("Failed to invite:", e);
    }
  };

  return (
    <div className="mx-auto max-w-md p-4 space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold">Hey, {name}</h1>
        <button
          onClick={logout}
          className="text-sm text-gray-500 hover:text-gray-700"
        >
          Logout
        </button>
      </div>

      {invite && (
        <GroupInviteBanner
          invite={invite}
          onAccept={handleInviteAccept}
          onDismiss={onClearInvite}
        />
      )}

      <button
        onClick={handleStartWorkout}
        disabled={loading}
        className="w-full rounded-md bg-blue-600 px-4 py-3 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
      >
        {loading ? "Starting..." : "Start Solo Workout"}
      </button>

      <button
        onClick={handleShowInvite}
        className="w-full rounded-md border border-purple-300 bg-purple-50 px-4 py-3 text-sm font-medium text-purple-700 hover:bg-purple-100"
      >
        Invite to Group Workout
      </button>

      {showInvite && (
        <div className="rounded-lg border bg-white p-4 space-y-3">
          <h3 className="text-sm font-semibold">Select a user to invite</h3>
          <select
            value={inviteUserId}
            onChange={(e) => setInviteUserId(e.target.value)}
            className="w-full rounded border px-2 py-1 text-sm"
          >
            <option value="">Choose...</option>
            {users.map((u) => (
              <option key={u.id} value={u.id}>
                {u.name}
              </option>
            ))}
          </select>
          <div className="flex gap-2">
            <button
              onClick={handleSendInvite}
              disabled={!inviteUserId}
              className="flex-1 rounded-md bg-purple-600 px-4 py-2 text-sm font-medium text-white hover:bg-purple-700 disabled:opacity-50"
            >
              Send Invite
            </button>
            <button
              onClick={() => setShowInvite(false)}
              className="flex-1 rounded-md border px-4 py-2 text-sm"
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      <button
        onClick={() => navigate("/history")}
        className="w-full rounded-md border px-4 py-3 text-sm text-gray-700 hover:bg-gray-50"
      >
        View History
      </button>
    </div>
  );
}
