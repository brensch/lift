import type { InviteEvent } from "../gen/lift/v1/group_pb.js";

interface GroupInviteBannerProps {
  invite: InviteEvent;
  onAccept: (groupWorkoutId: string) => void;
  onDismiss: () => void;
}

export function GroupInviteBanner({
  invite,
  onAccept,
  onDismiss,
}: GroupInviteBannerProps) {
  return (
    <div className="rounded-lg border-2 border-purple-300 bg-purple-50 p-4">
      <p className="mb-2 text-sm font-medium text-purple-800">
        {invite.inviterName || "Someone"} invited you to a group workout!
      </p>
      <div className="flex gap-2">
        <button
          onClick={() => onAccept(invite.groupWorkoutId)}
          className="flex-1 rounded-md bg-purple-600 px-4 py-2 text-sm font-medium text-white hover:bg-purple-700"
        >
          Join
        </button>
        <button
          onClick={onDismiss}
          className="flex-1 rounded-md border border-purple-300 px-4 py-2 text-sm text-purple-700 hover:bg-purple-100"
        >
          Dismiss
        </button>
      </div>
    </div>
  );
}
