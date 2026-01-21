import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useWorkout } from "@/context/WorkoutContext";
import { ActivityType, Exercise } from "@/lib/api";

function exerciseToString(exercise: Exercise): string {
  switch (exercise) {
    case Exercise.SQUAT:
      return "Squat";
    case Exercise.BENCH:
      return "Bench Press";
    case Exercise.DEADLIFT:
      return "Deadlift";
    case Exercise.OHP:
      return "Overhead Press";
    case Exercise.ROW:
      return "Barbell Row";
    default:
      return "Unknown";
  }
}

function exerciseEmoji(exercise: Exercise): string {
  switch (exercise) {
    case Exercise.SQUAT:
      return "🦵";
    case Exercise.BENCH:
      return "💪";
    case Exercise.DEADLIFT:
      return "🏋️";
    case Exercise.OHP:
      return "🙆";
    case Exercise.ROW:
      return "🚣";
    default:
      return "❓";
  }
}

function formatTime(seconds: number): string {
  const absSeconds = Math.abs(seconds);
  const mins = Math.floor(absSeconds / 60);
  const secs = absSeconds % 60;
  const sign = seconds < 0 ? "-" : "";
  return `${sign}${mins}:${secs.toString().padStart(2, "0")}`;
}

function formatTimestamp(date: Date): string {
  return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" });
}

export function Timeline() {
  const { workoutState, phase } = useWorkout();

  // Don't show in preview phase or if no timeline
  if (phase === "preview" || !workoutState || workoutState.timeline.length === 0) {
    return null;
  }

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-lg">Timeline</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="space-y-2 text-sm max-h-64 overflow-y-auto">
          {[...workoutState.timeline].reverse().map((activity, idx) => (
            <div key={idx} className="py-2 border-b last:border-0">
              {activity.type === ActivityType.SET && activity.endedAt ? (
                <div className="flex justify-between items-center">
                  <div className="flex items-center gap-2">
                    <span className="text-lg">{exerciseEmoji(activity.exercise)}</span>
                    <div>
                      <span className="font-medium">{exerciseToString(activity.exercise)}</span>
                      <span className="text-muted-foreground ml-2">Set {activity.setNumber}</span>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className={`font-medium ${activity.actualReps < activity.targetReps ? "text-yellow-500" : "text-green-500"}`}>
                      {activity.actualReps}/{activity.targetReps}
                    </span>
                    <span className="text-xs text-muted-foreground">
                      {formatTimestamp(activity.endedAt.toDate())}
                    </span>
                  </div>
                </div>
              ) : activity.type === ActivityType.REST && activity.endedAt ? (
                (() => {
                  const actualSeconds = activity.startedAt && activity.endedAt
                    ? Math.floor((activity.endedAt.toDate().getTime() - activity.startedAt.toDate().getTime()) / 1000)
                    : 0;
                  const wentOver = actualSeconds > activity.plannedDurationSeconds;
                  return (
                    <div className={`flex justify-between items-center rounded px-2 py-1 ${
                      wentOver ? "text-destructive bg-destructive/10" : "text-muted-foreground bg-muted/50"
                    }`}>
                      <div className="flex items-center gap-2">
                        <span>{wentOver ? "💬" : "⏱️"}</span>
                        <span>{wentOver ? "Rest + Chat" : "Rest"}</span>
                      </div>
                      <div className="text-xs flex gap-2">
                        <span>Actual: {formatTime(actualSeconds)}</span>
                        {wentOver && (
                          <span className="text-muted-foreground">(+{formatTime(actualSeconds - activity.plannedDurationSeconds)})</span>
                        )}
                      </div>
                    </div>
                  );
                })()
              ) : null}
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  );
}
