import type { WorkoutEvent } from "../gen/lift/v1/group_pb.js";
import { timestampDate } from "@bufbuild/protobuf/wkt";

interface GroupWorkoutOverlayProps {
  workoutEvent: WorkoutEvent;
  currentUserId: string;
}

interface ParticipantStatus {
  userId: string;
  userName: string;
  isResting: boolean;
  restEnds: number;
  incompleteSets: number;
  hasActiveSet: boolean;
  completedCount: number;
  totalSets: number;
}

export function GroupWorkoutOverlay({
  workoutEvent,
  currentUserId,
}: GroupWorkoutOverlayProps) {
  const now = Date.now();

  const participantStatus: ParticipantStatus[] = workoutEvent.participants.map(
    (p) => {
      const ws = p.workoutState;
      if (!ws)
        return {
          userId: p.userId,
          userName: p.userName,
          isResting: false,
          restEnds: 0,
          incompleteSets: 0,
          hasActiveSet: false,
          completedCount: 0,
          totalSets: 0,
        };

      const completedIds = new Set(
        ws.completedSets.map((cs) => cs.proposedSetId),
      );
      const incompleteSets = ws.proposedSets.filter(
        (ps) => !completedIds.has(ps.id),
      ).length;

      const latestCompleted = [...ws.completedSets]
        .filter((cs) => cs.restUntil != null && cs.endedAt != null)
        .sort((a, b) => {
          const aTime = a.endedAt ? timestampDate(a.endedAt).getTime() : 0;
          const bTime = b.endedAt ? timestampDate(b.endedAt).getTime() : 0;
          return bTime - aTime;
        })[0];

      const restUntil = latestCompleted?.restUntil
        ? timestampDate(latestCompleted.restUntil)
        : null;
      const isResting = restUntil ? restUntil.getTime() > now : false;
      const restEnds = restUntil?.getTime() || 0;

      const hasActiveSet = ws.completedSets.some(
        (cs) => cs.startedAt != null && cs.endedAt == null,
      );

      return {
        userId: p.userId,
        userName: p.userName,
        isResting,
        restEnds,
        incompleteSets,
        hasActiveSet,
        completedCount: ws.completedSets.filter((cs) => cs.endedAt != null)
          .length,
        totalSets: ws.proposedSets.length,
      };
    },
  );

  const candidates = participantStatus.filter(
    (p) => !p.isResting && !p.hasActiveSet && p.incompleteSets > 0,
  );
  const nextUp = candidates.length > 0 ? candidates[0] : null;

  return (
    <div className="rounded-lg border bg-white p-3">
      {nextUp && (
        <div className="mb-3 rounded-md bg-yellow-50 border border-yellow-200 px-3 py-2 text-sm">
          <span className="font-medium text-yellow-800">
            Up next:{" "}
            {nextUp.userId === currentUserId ? "You!" : nextUp.userName}
          </span>
        </div>
      )}

      <h3 className="mb-2 text-sm font-semibold text-gray-700">
        Group Workout
      </h3>
      <div className="space-y-2">
        {participantStatus.map((p) => (
          <div
            key={p.userId}
            className={`rounded border p-2 text-sm ${
              p.userId === currentUserId ? "border-blue-200 bg-blue-50" : ""
            }`}
          >
            <div className="flex items-center justify-between">
              <span className="font-medium">
                {p.userName}
                {p.userId === currentUserId && " (You)"}
              </span>
              <span
                className={`text-xs ${
                  p.hasActiveSet
                    ? "text-blue-600"
                    : p.isResting
                      ? "text-orange-600"
                      : "text-green-600"
                }`}
              >
                {p.hasActiveSet
                  ? "Lifting"
                  : p.isResting
                    ? "Resting"
                    : "Ready"}
              </span>
            </div>
            <p className="mt-1 text-xs text-gray-500">
              {p.completedCount}/{p.totalSets} sets done
            </p>
          </div>
        ))}
      </div>
    </div>
  );
}
