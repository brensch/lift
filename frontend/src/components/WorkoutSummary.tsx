import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Activity, ActivityType, Exercise } from "@/lib/api";
import { Timestamp } from "@bufbuild/protobuf";

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

function formatDuration(seconds: number): string {
  if (seconds < 60) {
    return `${seconds}s`;
  }
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  if (mins < 60) {
    return secs > 0 ? `${mins}m ${secs}s` : `${mins}m`;
  }
  const hours = Math.floor(mins / 60);
  const remainingMins = mins % 60;
  return remainingMins > 0 ? `${hours}h ${remainingMins}m` : `${hours}h`;
}

function formatDate(timestamp: Timestamp | undefined): string {
  if (!timestamp) return "";
  const date = timestamp.toDate();
  return date.toLocaleDateString([], { 
    weekday: 'short', 
    month: 'short', 
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });
}

// Color mapping for exercises
function exerciseColor(exercise: Exercise): string {
  switch (exercise) {
    case Exercise.SQUAT:
      return "bg-blue-500";
    case Exercise.BENCH:
      return "bg-green-500";
    case Exercise.DEADLIFT:
      return "bg-purple-500";
    case Exercise.OHP:
      return "bg-orange-500";
    case Exercise.ROW:
      return "bg-pink-500";
    default:
      return "bg-gray-500";
  }
}

interface TimelineSegment {
  type: 'set' | 'rest' | 'chatting';
  exercise?: Exercise;
  durationMs: number;
  percentWidth: number;
  activity: Activity;
  actualReps?: number;
  targetReps?: number;
}

function buildTimelineSegments(timeline: Activity[], sessionStartedAt?: Timestamp): TimelineSegment[] {
  if (timeline.length === 0 || !sessionStartedAt) return [];

  const sessionStart = sessionStartedAt.toDate().getTime();
  
  // Helper to check if a timestamp is valid (not null/zero)
  const isValidTimestamp = (ts?: Timestamp): boolean => {
    if (!ts) return false;
    const time = ts.toDate().getTime();
    return time > 0;
  };
  
  // Find the last activity with a valid endedAt timestamp
  let lastEndTime = sessionStart;
  for (const activity of timeline) {
    if (isValidTimestamp(activity.endedAt)) {
      const endTime = activity.endedAt!.toDate().getTime();
      if (endTime > lastEndTime) {
        lastEndTime = endTime;
      }
    }
  }
  
  // If no activities have ended, we can't build timeline
  if (lastEndTime === sessionStart) return [];
  
  const totalDuration = lastEndTime - sessionStart;
  if (totalDuration <= 0) return [];

  const segments: TimelineSegment[] = [];

  for (const activity of timeline) {
    if (!isValidTimestamp(activity.startedAt)) continue;
    
    const startTime = activity.startedAt!.toDate().getTime();
    // If activity has no valid endedAt, skip it (it's still ongoing)
    if (!isValidTimestamp(activity.endedAt)) continue;
    
    const endTime = activity.endedAt!.toDate().getTime();
    const durationMs = endTime - startTime;

    if (activity.type === ActivityType.SET) {
      segments.push({
        type: 'set',
        exercise: activity.exercise,
        durationMs,
        percentWidth: (durationMs / totalDuration) * 100,
        activity,
        actualReps: activity.actualReps,
        targetReps: activity.targetReps,
      });
    } else if (activity.type === ActivityType.REST) {
      const plannedMs = activity.plannedDurationSeconds * 1000;
      
      if (durationMs <= plannedMs) {
        // All planned rest
        segments.push({
          type: 'rest',
          durationMs,
          percentWidth: (durationMs / totalDuration) * 100,
          activity,
        });
      } else {
        // Split into rest + chatting
        segments.push({
          type: 'rest',
          durationMs: plannedMs,
          percentWidth: (plannedMs / totalDuration) * 100,
          activity,
        });
        segments.push({
          type: 'chatting',
          durationMs: durationMs - plannedMs,
          percentWidth: ((durationMs - plannedMs) / totalDuration) * 100,
          activity,
        });
      }
    }
  }

  return segments;
}

interface WorkoutStats {
  totalSets: number;
  totalWorkoutSeconds: number;
  totalRestSeconds: number;
  totalChattingSeconds: number;
  totalWorkingSeconds: number;
  successfulSets: number;
}

function calculateStats(timeline: Activity[], sessionStartedAt?: Timestamp): WorkoutStats {
  let totalRestSeconds = 0;
  let totalChattingSeconds = 0;
  let totalWorkingSeconds = 0;
  let totalSets = 0;
  let successfulSets = 0;

  for (const activity of timeline) {
    if (!activity.startedAt || !activity.endedAt) continue;

    const startTime = activity.startedAt.toDate().getTime();
    const endTime = activity.endedAt.toDate().getTime();
    const durationSeconds = Math.floor((endTime - startTime) / 1000);

    if (activity.type === ActivityType.SET) {
      totalSets++;
      totalWorkingSeconds += durationSeconds;
      if (activity.actualReps >= activity.targetReps) {
        successfulSets++;
      }
    } else if (activity.type === ActivityType.REST) {
      const plannedSeconds = activity.plannedDurationSeconds;
      if (durationSeconds <= plannedSeconds) {
        // All time was planned rest
        totalRestSeconds += durationSeconds;
      } else {
        // Split: planned rest + chatting (over rest time)
        totalRestSeconds += plannedSeconds;
        totalChattingSeconds += durationSeconds - plannedSeconds;
      }
    }
  }

  // Calculate total workout time from session start to last activity end
  let totalWorkoutSeconds = 0;
  if (sessionStartedAt && timeline.length > 0) {
    const sessionStart = sessionStartedAt.toDate().getTime();
    const lastActivity = timeline[timeline.length - 1];
    if (lastActivity.endedAt) {
      const lastEnd = lastActivity.endedAt.toDate().getTime();
      totalWorkoutSeconds = Math.floor((lastEnd - sessionStart) / 1000);
    }
  }

  return {
    totalSets,
    totalWorkoutSeconds,
    totalRestSeconds,
    totalChattingSeconds,
    totalWorkingSeconds,
    successfulSets,
  };
}

export interface WorkoutSummaryProps {
  timeline: Activity[];
  sessionStartedAt?: Timestamp;
  onDismiss?: () => void;
  showDismissButton?: boolean;
  title?: string;
}

export function WorkoutSummary({ 
  timeline, 
  sessionStartedAt,
  onDismiss,
  showDismissButton = true,
  title = "🎉 Great Workout!"
}: WorkoutSummaryProps) {
  const stats = calculateStats(timeline, sessionStartedAt);
  const setActivities = timeline.filter(a => a.type === ActivityType.SET);
  const timelineSegments = buildTimelineSegments(timeline, sessionStartedAt);

  return (
    <div className="space-y-4">
      {/* Header Card */}
      <Card>
        <CardHeader className="text-center">
          <CardTitle className="text-3xl">{title}</CardTitle>
          <CardDescription>
            {sessionStartedAt && (
              <span className="block text-sm">{formatDate(sessionStartedAt)}</span>
            )}
            You completed {stats.totalSets} sets ({stats.successfulSets} at target reps)
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {/* Stats Grid */}
          <div className="grid grid-cols-2 gap-3">
            <div className="bg-muted/50 rounded-lg p-3 text-center">
              <div className="text-2xl font-bold">{formatDuration(stats.totalWorkoutSeconds)}</div>
              <div className="text-xs text-muted-foreground">Total Duration</div>
            </div>
            <div className="bg-muted/50 rounded-lg p-3 text-center">
              <div className="text-2xl font-bold">{formatDuration(stats.totalWorkingSeconds)}</div>
              <div className="text-xs text-muted-foreground">⏱️ Working</div>
            </div>
            <div className="bg-muted/50 rounded-lg p-3 text-center">
              <div className="text-2xl font-bold">{formatDuration(stats.totalRestSeconds)}</div>
              <div className="text-xs text-muted-foreground">😴 Resting</div>
            </div>
            <div className="bg-muted/50 rounded-lg p-3 text-center">
              <div className="text-2xl font-bold text-yellow-500">{formatDuration(stats.totalChattingSeconds)}</div>
              <div className="text-xs text-muted-foreground">💬 Chatting</div>
            </div>
          </div>

          {/* Visual Timeline */}
          <div className="space-y-2">
            <div className="text-sm font-medium text-muted-foreground">Workout Timeline</div>
            {timelineSegments.length > 0 ? (
              <>
              <div className="w-full">
                {/* Timeline bar */}
                <div className="flex w-full h-8 rounded-lg overflow-hidden border">
                  {timelineSegments.map((segment, idx) => {
                    let bgColor = "";
                    let emoji = "";
                    
                    if (segment.type === 'set' && segment.exercise !== undefined) {
                      bgColor = exerciseColor(segment.exercise);
                      emoji = exerciseEmoji(segment.exercise);
                    } else if (segment.type === 'rest') {
                      bgColor = "bg-slate-400";
                      emoji = "😴";
                    } else if (segment.type === 'chatting') {
                      bgColor = "bg-yellow-400";
                      emoji = "💬";
                    }
                    
                    return (
                      <div
                        key={idx}
                        className={`${bgColor} flex items-center justify-center text-white text-xs font-bold relative group`}
                        style={{ width: `${segment.percentWidth}%`, minWidth: segment.type === 'set' ? '24px' : '4px' }}
                        title={segment.type === 'set' 
                          ? `${exerciseToString(segment.exercise!)} Set ${segment.activity.setNumber}: ${segment.actualReps}/${segment.targetReps} reps`
                          : segment.type === 'rest' 
                            ? `Rest: ${formatDuration(Math.floor(segment.durationMs / 1000))}`
                            : `Chatting: ${formatDuration(Math.floor(segment.durationMs / 1000))}`
                        }
                      >
                        {segment.percentWidth > 3 && <span>{emoji}</span>}
                      </div>
                    );
                  })}
                </div>
                
                {/* Reps labels below sets */}
                <div className="flex w-full mt-1">
                  {timelineSegments.map((segment, idx) => (
                    <div
                      key={idx}
                      className="flex items-start justify-center"
                      style={{ width: `${segment.percentWidth}%`, minWidth: segment.type === 'set' ? '24px' : '4px' }}
                    >
                      {segment.type === 'set' && segment.percentWidth > 2 && (
                        <span className={`text-[10px] font-medium ${
                          segment.actualReps! < segment.targetReps! ? "text-yellow-600" : "text-green-600"
                        }`}>
                          {segment.actualReps}/{segment.targetReps}
                        </span>
                      )}
                    </div>
                  ))}
                </div>
              </div>
              
              {/* Legend */}
              <div className="flex flex-wrap gap-2 text-xs mt-2">
                {Array.from(new Set(setActivities.map(a => a.exercise))).map(exercise => (
                  <div key={exercise} className="flex items-center gap-1">
                    <div className={`w-3 h-3 rounded ${exerciseColor(exercise)}`}></div>
                    <span>{exerciseEmoji(exercise)} {exerciseToString(exercise)}</span>
                  </div>
                ))}
                <div className="flex items-center gap-1">
                  <div className="w-3 h-3 rounded bg-slate-400"></div>
                  <span>😴 Rest</span>
                </div>
                {stats.totalChattingSeconds > 0 && (
                  <div className="flex items-center gap-1">
                    <div className="w-3 h-3 rounded bg-yellow-400"></div>
                    <span>💬 Chatting</span>
                  </div>
                )}
              </div>
            </>
            ) : (
              <div className="text-xs text-muted-foreground">
                Timeline: {timeline.length} activities, {setActivities.length} sets
              </div>
            )}
          </div>

          {showDismissButton && onDismiss && (
            <Button onClick={onDismiss} className="w-full">
              Done
            </Button>
          )}
        </CardContent>
      </Card>

      {/* Set Details Card */}
      {setActivities.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Set Details</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2 text-sm">
              {setActivities.map((activity, idx) => (
                <div key={idx} className="flex justify-between items-center py-1 border-b last:border-0">
                  <div className="flex items-center gap-2">
                    <span>{exerciseEmoji(activity.exercise)}</span>
                    <span>{exerciseToString(activity.exercise)}</span>
                    <span className="text-muted-foreground">Set {activity.setNumber}</span>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className={activity.actualReps < activity.targetReps ? "text-yellow-500" : "text-green-500"}>
                      {activity.actualReps}/{activity.targetReps} reps
                    </span>
                    <span className="text-muted-foreground">{activity.weight} lbs</span>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
