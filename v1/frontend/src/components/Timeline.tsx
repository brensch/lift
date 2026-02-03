import { useWorkout } from "@/context/WorkoutContext";
import { useUser } from "@/context/UserContext";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Clock, Dumbbell, Coffee } from "lucide-react";
import { ActivityType, Exercise, type Activity, type GroupActivity } from "@/lib/api";

// Helper to get exercise name
function getExerciseName(exercise: Exercise): string {
  const names: Record<number, string> = {
    [Exercise.SQUAT]: "Squat",
    [Exercise.BENCH]: "Bench",
    [Exercise.DEADLIFT]: "Deadlift",
    [Exercise.OHP]: "OHP",
    [Exercise.ROW]: "Row",
  };
  return names[exercise] || "Unknown";
}

// Helper to format time
function formatTime(date: Date): string {
  return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" });
}

// Helper to format duration
function formatDuration(seconds: number): string {
  const mins = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  if (mins > 0) {
    return `${mins}m ${secs}s`;
  }
  return `${secs}s`;
}

// Normalized activity type for rendering
interface NormalizedActivity {
  id: string;
  userId?: string;
  type: "set" | "rest";
  exercise: Exercise;
  setNumber: number;
  weight: number;
  targetReps: number;
  actualReps: number;
  startedAt?: Date;
  endedAt?: Date;
  plannedRestSeconds: number;
}

// Convert individual Activity to normalized format
function normalizeActivity(activity: Activity, index: number): NormalizedActivity {
  return {
    id: activity.id || `activity-${index}`,
    type: activity.type === ActivityType.SET ? "set" : "rest",
    exercise: activity.exercise,
    setNumber: activity.setNumber,
    weight: activity.weight,
    targetReps: activity.targetReps,
    actualReps: activity.actualReps,
    startedAt: activity.startedAt?.toDate(),
    endedAt: activity.endedAt?.toDate(),
    plannedRestSeconds: activity.plannedDurationSeconds,
  };
}

// Convert GroupActivity to normalized format
function normalizeGroupActivity(activity: GroupActivity): NormalizedActivity {
  return {
    id: activity.id,
    userId: activity.userId,
    type: activity.type as "set" | "rest",
    exercise: activity.exercise,
    setNumber: activity.setNumber,
    weight: activity.weight,
    targetReps: activity.targetReps,
    actualReps: activity.actualReps,
    startedAt: activity.startedAt?.toDate(),
    endedAt: activity.endedAt?.toDate(),
    plannedRestSeconds: activity.plannedRestSeconds,
  };
}

function ActivityItem({ activity, currentUsername, showUser }: {
  activity: NormalizedActivity;
  currentUsername: string;
  showUser: boolean;
}) {
  const isMe = !activity.userId || activity.userId === currentUsername;
  const displayName = showUser ? (isMe ? "You" : activity.userId) : undefined;

  const startTime = activity.startedAt;
  const endTime = activity.endedAt;

  // Calculate duration if completed
  let duration = "";
  if (startTime && endTime) {
    const durationSec = (endTime.getTime() - startTime.getTime()) / 1000;
    duration = formatDuration(durationSec);
  }

  if (activity.type === "set") {
    // Only show completed sets
    if (!endTime) return null;

    return (
      <div className={`flex items-start gap-3 py-2 ${showUser && isMe ? "bg-primary/5 -mx-2 px-2 rounded" : ""}`}>
        <div className="flex-shrink-0 mt-0.5">
          <Dumbbell className="h-4 w-4 text-yellow-600" />
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            {displayName && (
              <span className={`font-medium text-sm ${isMe ? "text-primary" : ""}`}>
                {displayName}
              </span>
            )}
            <span className="text-xs text-muted-foreground">
              {startTime && formatTime(startTime)}
            </span>
          </div>
          <div className="text-sm">
            {getExerciseName(activity.exercise)} #{activity.setNumber}
            <span className="text-muted-foreground"> @ {activity.weight}kg</span>
            {activity.actualReps > 0 && (
              <span className={activity.actualReps >= activity.targetReps ? "text-green-600" : "text-orange-500"}>
                {" "}- {activity.actualReps}/{activity.targetReps} reps
              </span>
            )}
            {duration && (
              <span className="text-xs text-muted-foreground ml-2">({duration})</span>
            )}
          </div>
        </div>
      </div>
    );
  } else if (activity.type === "rest") {
    // Only show completed rests
    if (!endTime) return null;

    const actualSeconds = startTime && endTime
      ? (endTime.getTime() - startTime.getTime()) / 1000
      : 0;
    const wentOver = activity.plannedRestSeconds > 0 && actualSeconds > activity.plannedRestSeconds;

    return (
      <div className={`flex items-start gap-3 py-2 ${showUser && isMe ? "bg-primary/5 -mx-2 px-2 rounded" : ""}`}>
        <div className="flex-shrink-0 mt-0.5">
          <Coffee className={`h-4 w-4 ${wentOver ? "text-orange-500" : "text-blue-500"}`} />
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            {displayName && (
              <span className={`font-medium text-sm ${isMe ? "text-primary" : ""}`}>
                {displayName}
              </span>
            )}
            <span className="text-xs text-muted-foreground">
              {startTime && formatTime(startTime)}
            </span>
          </div>
          <div className={`text-sm ${wentOver ? "text-orange-500" : "text-muted-foreground"}`}>
            {wentOver ? "Rest + Chat" : "Rest"}
            {duration && <span className="ml-2">- {duration}</span>}
            {wentOver && activity.plannedRestSeconds > 0 && (
              <span className="text-xs ml-1">(+{formatDuration(actualSeconds - activity.plannedRestSeconds)})</span>
            )}
          </div>
        </div>
      </div>
    );
  }

  return null;
}

export function Timeline() {
  const { username } = useUser();
  const { workoutState, activeSession, phase } = useWorkout();

  // Don't show in preview phase
  if (phase === "preview") {
    return null;
  }

  // Determine if we're in a group session and should use group timeline
  const isInGroup = activeSession && activeSession.status === "active";
  const groupTimeline = activeSession?.timeline || [];
  const individualTimeline = workoutState?.timeline || [];

  // Normalize the timeline data
  let normalizedTimeline: NormalizedActivity[];
  let showUser: boolean;

  if (isInGroup && groupTimeline.length > 0) {
    // Use group timeline - shows all users
    normalizedTimeline = groupTimeline.map(normalizeGroupActivity);
    showUser = true;
  } else if (individualTimeline.length > 0) {
    // Use individual timeline - solo workout
    normalizedTimeline = individualTimeline.map(normalizeActivity);
    showUser = false;
  } else {
    return null;
  }

  // Filter to only show completed activities and reverse for most recent first
  const completedActivities = normalizedTimeline
    .filter(a => a.endedAt)
    .reverse();

  if (completedActivities.length === 0) {
    return null;
  }

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-lg flex items-center gap-2">
          <Clock className="h-5 w-5" />
          {isInGroup ? "Group Activity" : "Timeline"}
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div className="space-y-1 divide-y divide-border max-h-80 overflow-y-auto">
          {completedActivities.slice(0, 30).map((activity) => (
            <ActivityItem
              key={activity.id}
              activity={activity}
              currentUsername={username || ""}
              showUser={showUser}
            />
          ))}
        </div>
        {completedActivities.length > 30 && (
          <div className="text-xs text-muted-foreground text-center mt-2">
            Showing last 30 of {completedActivities.length} activities
          </div>
        )}
      </CardContent>
    </Card>
  );
}
