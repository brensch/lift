import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Card } from "@/components/ui/card";
import { Check, Clock, Dumbbell } from "lucide-react";
import { type GroupSessionMember, type PlannedSet, Exercise } from "@/lib/api";
import { useState, useEffect } from "react";

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

// Helper to format seconds as MM:SS
function formatTime(seconds: number): string {
  const absSeconds = Math.abs(Math.floor(seconds));
  const mins = Math.floor(absSeconds / 60);
  const secs = absSeconds % 60;
  const sign = seconds < 0 ? "-" : "";
  return `${sign}${mins}:${secs.toString().padStart(2, "0")}`;
}

// Group sets by exercise
function groupSetsByExercise(sets: PlannedSet[]): Map<Exercise, PlannedSet[]> {
  const grouped = new Map<Exercise, PlannedSet[]>();
  for (const set of sets) {
    const existing = grouped.get(set.exercise) || [];
    existing.push(set);
    grouped.set(set.exercise, existing);
  }
  return grouped;
}

interface MemberWorkoutModalProps {
  member: GroupSessionMember | null;
  open: boolean;
  onClose: () => void;
}

export function MemberWorkoutModal({ member, open, onClose }: MemberWorkoutModalProps) {
  const [now, setNow] = useState(new Date());

  // Update time every second for realtime
  useEffect(() => {
    if (!open) return;
    const interval = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(interval);
  }, [open]);

  if (!member) return null;

  const activity = member.currentActivity;
  const remainingByExercise = groupSetsByExercise(member.remainingSets || []);
  const completedByExercise = groupSetsByExercise(member.completedSets || []);

  // Get all exercises (from both remaining and completed)
  const allExercises = new Set<Exercise>();
  for (const ex of remainingByExercise.keys()) allExercises.add(ex);
  for (const ex of completedByExercise.keys()) allExercises.add(ex);

  // Calculate realtime status
  let statusText = "Idle";
  let statusColor = "text-muted-foreground";
  let timeDisplay = "";

  if (activity && activity.startedAt) {
    const activityStart = activity.startedAt.toDate();
    const elapsedMs = now.getTime() - activityStart.getTime();
    const elapsedSeconds = elapsedMs / 1000;

    if (activity.type === "set") {
      statusText = `${getExerciseName(activity.exercise)} Set #${activity.setNumber}`;
      statusColor = "text-yellow-600";
      timeDisplay = formatTime(elapsedSeconds);
    } else if (activity.type === "rest") {
      const assumedPlannedRest = 180;
      const currentRemaining = assumedPlannedRest - elapsedSeconds;

      if (currentRemaining > 0) {
        statusText = "Resting";
        statusColor = "text-blue-500";
        timeDisplay = formatTime(currentRemaining);
      } else {
        statusText = "Rest complete";
        statusColor = "text-orange-500";
        timeDisplay = "+" + formatTime(Math.abs(currentRemaining));
      }
    }
  }

  const totalRemaining = member.remainingSets?.length ?? 0;
  const totalCompleted = member.completedSets?.length ?? 0;
  const totalSets = totalRemaining + totalCompleted;

  return (
    <Dialog open={open} onOpenChange={(isOpen) => { if (!isOpen) onClose(); }}>
      <DialogContent className="max-w-md max-h-[80vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Dumbbell className="h-5 w-5" />
            {member.userId}'s Workout
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-4 py-2">
          {/* Current status */}
          <Card className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <div className="text-sm text-muted-foreground">Current Status</div>
                <div className={`font-medium ${statusColor}`}>{statusText}</div>
              </div>
              {timeDisplay && (
                <div className={`flex items-center gap-1 text-lg font-mono ${statusColor}`}>
                  <Clock className="h-4 w-4" />
                  {timeDisplay}
                </div>
              )}
            </div>
            <div className="mt-2 text-sm text-muted-foreground">
              Progress: {totalCompleted}/{totalSets} sets
            </div>
          </Card>

          {/* Exercises breakdown */}
          <div className="space-y-3">
            {Array.from(allExercises).map((exercise) => {
              const remaining = remainingByExercise.get(exercise) || [];
              const completed = completedByExercise.get(exercise) || [];
              const total = remaining.length + completed.length;
              const weight = remaining[0]?.targetWeight ?? completed[0]?.targetWeight ?? 0;

              return (
                <Card key={exercise} className="p-3">
                  <div className="flex items-center justify-between mb-2">
                    <div className="font-medium">{getExerciseName(exercise)}</div>
                    <div className="text-sm text-muted-foreground">
                      {weight}kg
                    </div>
                  </div>

                  {/* Set indicators */}
                  <div className="flex gap-1">
                    {/* Completed sets */}
                    {completed.map((set, i) => (
                      <div
                        key={`completed-${i}`}
                        className="w-8 h-8 rounded bg-green-500 text-white flex items-center justify-center text-xs font-medium"
                        title={`Set ${set.setNumber}: ${set.targetReps} reps @ ${set.targetWeight}kg`}
                      >
                        <Check className="h-4 w-4" />
                      </div>
                    ))}
                    {/* Remaining sets */}
                    {remaining.map((set, i) => {
                      const isCurrentSet = activity?.type === "set" &&
                        activity.exercise === exercise &&
                        activity.setNumber === set.setNumber;

                      return (
                        <div
                          key={`remaining-${i}`}
                          className={`w-8 h-8 rounded flex items-center justify-center text-xs font-medium ${
                            isCurrentSet
                              ? "bg-yellow-500 text-white animate-pulse"
                              : "bg-muted"
                          }`}
                          title={`Set ${set.setNumber}: ${set.targetReps} reps @ ${set.targetWeight}kg`}
                        >
                          {set.setNumber}
                        </div>
                      );
                    })}
                  </div>

                  {/* Show total */}
                  <div className="mt-1 text-xs text-muted-foreground">
                    {completed.length}/{total} sets complete
                  </div>
                </Card>
              );
            })}

            {allExercises.size === 0 && (
              <div className="text-center text-muted-foreground py-4">
                No workout data available
              </div>
            )}
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
