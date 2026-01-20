import { useState, useEffect, useCallback, useRef } from "react";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { useUser } from "@/context/UserContext";
import {
  type WorkoutState,
  type Activity,
  type PlannedSet,
  type RestConfig,
  ActivityType,
  Exercise,
} from "@/lib/api";

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

// Roasts for when you're past your rest time
const CHAT_TIME_ROASTS = [
  "Did you get lost? 🧭",
  "The weights miss you 😢",
  "Your muscles are getting cold 🥶",
  "Netflix break? 📺",
  "Making new friends? 👋",
  "Did you fall asleep? 😴",
  "The bar is getting lonely 💔",
  "Is there a line for the water fountain? 🚰",
  "Checking your DMs? 📱",
  "Writing your memoir? 📖",
];

function getRandomRoast(): string {
  return CHAT_TIME_ROASTS[Math.floor(Math.random() * CHAT_TIME_ROASTS.length)];
}

// UI phases for the workout flow
type WorkoutPhase = 
  | "preview"      // Before workout starts - show plan
  | "ready"        // Ready to start a set - show "Start Set" button
  | "performing"   // Currently doing a set - timer counting up, pick reps when done
  | "resting"      // Resting between sets - timer counting down
  | "chatting"     // Past rest time - timer counting up (unplanned rest)
  | "complete";    // Workout finished

export function Workout() {
  const { username, client, logout } = useUser();
  
  // State from backend
  const [workoutState, setWorkoutState] = useState<WorkoutState | null>(null);
  const [restConfig, setRestConfig] = useState<RestConfig | null>(null);
  
  // UI state
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [phase, setPhase] = useState<WorkoutPhase>("preview");
  const [currentActivity, setCurrentActivity] = useState<Activity | null>(null);
  
  // Timer state
  const [currentTime, setCurrentTime] = useState(new Date());
  const [currentRoast, setCurrentRoast] = useState<string>("");
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Fetch workout state from backend
  const fetchWorkoutState = useCallback(async () => {
    if (!client || !username) return;

    try {
      setLoading(true);
      setError(null);
      const response = await client.getWorkoutState({ userId: username });
      
      setWorkoutState(response.state ?? null);
      setRestConfig(response.restConfig ?? null);
      
      // Determine phase from state
      if (response.state) {
        const state = response.state;
        
        if (state.isComplete) {
          setPhase("complete");
        } else if (state.currentActivity) {
          const activity = state.currentActivity;
          setCurrentActivity(activity);
          
          if (activity.type === ActivityType.SET) {
            // Currently doing a set
            setPhase("performing");
          } else if (activity.type === ActivityType.REST) {
            // Check if rest is over
            const restStarted = activity.startedAt?.toDate() ?? new Date();
            const restDuration = activity.plannedDurationSeconds * 1000;
            const restEndsAt = new Date(restStarted.getTime() + restDuration);
            
            if (new Date() > restEndsAt) {
              setPhase("chatting");
              if (!currentRoast) setCurrentRoast(getRandomRoast());
            } else {
              setPhase("resting");
            }
          }
        } else if (state.timeline.length === 0) {
          // No activities yet - preview or ready phase
          setPhase("preview");
        } else {
          // Activities exist but nothing current - ready for next
          setPhase("ready");
        }
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to fetch workout");
    } finally {
      setLoading(false);
    }
  }, [client, username, currentRoast]);

  useEffect(() => {
    fetchWorkoutState();
  }, [fetchWorkoutState]);

  // Timer effect
  useEffect(() => {
    if (phase !== "preview" && phase !== "complete") {
      timerRef.current = setInterval(() => {
        const now = new Date();
        setCurrentTime(now);
        
        // Check if rest just ended and we should switch to chatting
        if (phase === "resting" && currentActivity && restConfig) {
          const restStarted = currentActivity.startedAt?.toDate() ?? new Date();
          const restDuration = currentActivity.plannedDurationSeconds * 1000;
          const restEndsAt = new Date(restStarted.getTime() + restDuration);
          
          if (now > restEndsAt) {
            setPhase("chatting");
            setCurrentRoast(getRandomRoast());
          }
        }
      }, 1000);
    } else {
      if (timerRef.current) {
        clearInterval(timerRef.current);
        timerRef.current = null;
      }
    }

    return () => {
      if (timerRef.current) {
        clearInterval(timerRef.current);
      }
    };
  }, [phase, currentActivity, restConfig]);

  // Calculate elapsed time for current set
  const setElapsedSeconds = currentActivity?.startedAt
    ? Math.floor((currentTime.getTime() - currentActivity.startedAt.toDate().getTime()) / 1000)
    : 0;

  // Calculate rest time remaining/overdue
  const restInfo = currentActivity && (phase === "resting" || phase === "chatting")
    ? (() => {
        const restStarted = currentActivity.startedAt?.toDate() ?? new Date();
        const restDuration = currentActivity.plannedDurationSeconds * 1000;
        const restEndsAt = new Date(restStarted.getTime() + restDuration);
        const msRemaining = restEndsAt.getTime() - currentTime.getTime();
        return {
          secondsRemaining: Math.floor(msRemaining / 1000),
          isPastTarget: msRemaining < 0,
          targetTime: restEndsAt,
          plannedSeconds: currentActivity.plannedDurationSeconds,
        };
      })()
    : null;

  // Calculate total workout time
  const totalWorkoutSeconds = workoutState?.sessionStartedAt
    ? Math.floor((currentTime.getTime() - workoutState.sessionStartedAt.toDate().getTime()) / 1000)
    : 0;

  // Start the workout (from preview)
  const startWorkout = () => {
    setPhase("ready");
  };

  // Start a set (from ready, resting, or chatting phase)
  const handleStartSet = async () => {
    if (!client || !workoutState?.nextSet) return;

    try {
      // If there's a current rest activity, finish it first
      if (currentActivity && currentActivity.type === ActivityType.REST) {
        await client.finishActivity({
          sessionId: workoutState.sessionId,
          activityId: currentActivity.id,
          actualReps: 0, // Not needed for REST
        });
      }

      const nextSet = workoutState.nextSet;
      const response = await client.startSet({
        sessionId: workoutState.sessionId,
        exercise: nextSet.exercise,
        setNumber: nextSet.setNumber,
        weight: nextSet.targetWeight,
        targetReps: nextSet.targetReps,
      });

      if (response.activity) {
        setCurrentActivity(response.activity);
        setPhase("performing");
        setCurrentRoast("");
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to start set");
    }
  };

  // Select actual reps completed
  const handleSelectReps = async (reps: number) => {
    if (!client || !currentActivity || !workoutState) return;

    try {
      const response = await client.finishActivity({
        sessionId: workoutState.sessionId,
        activityId: currentActivity.id,
        actualReps: reps,
      });

      if (response.nextActivity) {
        setCurrentActivity(response.nextActivity);
        setPhase("resting");
      }
      
      // Update state from response
      if (response.state) {
        setWorkoutState(response.state);
        if (response.state.isComplete) {
          setPhase("complete");
        }
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to complete set");
    }
  };

  // Start next workout
  const handleStartNewWorkout = async () => {
    // Reset local state and refetch
    setPhase("preview");
    setCurrentActivity(null);
    setCurrentRoast("");
    await fetchWorkoutState();
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background">
        <div className="text-lg">Loading your workout...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background p-4">
        <Card className="w-full max-w-md">
          <CardHeader>
            <CardTitle className="text-red-500">Error</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="mb-4">{error}</p>
            <Button onClick={() => { setError(null); fetchWorkoutState(); }}>Retry</Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  // Workout complete screen
  if (phase === "complete" || workoutState?.isComplete) {
    return (
      <div className="min-h-screen bg-background p-4">
        <div className="max-w-2xl mx-auto space-y-4">
          <Card>
            <CardHeader className="text-center">
              <CardTitle className="text-3xl">🎉 Great Workout!</CardTitle>
              <CardDescription>
                You completed {workoutState?.timeline.filter(a => a.type === ActivityType.SET).length ?? 0} sets
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <Button onClick={handleStartNewWorkout} className="w-full">
                Start Next Workout
              </Button>
              <Button onClick={logout} variant="outline" className="w-full">
                Logout
              </Button>
            </CardContent>
          </Card>

          {/* Final Summary */}
          {workoutState && (
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Workout Summary</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-2 text-sm">
                  {workoutState.timeline
                    .filter(a => a.type === ActivityType.SET)
                    .map((activity, idx) => (
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
      </div>
    );
  }

  // Get remaining sets grouped by exercise
  const remainingSetsGrouped = workoutState?.remainingSets.reduce(
    (acc, set) => {
      if (!acc[set.exercise]) {
        acc[set.exercise] = [];
      }
      acc[set.exercise].push(set);
      return acc;
    },
    {} as Record<number, PlannedSet[]>
  ) ?? {};

  const nextSet = workoutState?.nextSet;

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b p-4 flex items-center justify-between sticky top-0 bg-background z-10">
        <div>
          <h1 className="text-xl font-bold">🏋️ Lift</h1>
          <p className="text-sm text-muted-foreground">Hey, {username}!</p>
        </div>
        <div className="flex items-center gap-4">
          {phase !== "preview" && (
            <div className="text-right">
              <div className="text-lg font-mono font-bold">{formatTime(totalWorkoutSeconds)}</div>
              <div className="text-xs text-muted-foreground">Total Time</div>
            </div>
          )}
          <Button variant="ghost" size="sm" onClick={logout}>
            Logout
          </Button>
        </div>
      </header>

      <main className="p-4 max-w-2xl mx-auto space-y-4">
        {/* Preview Phase - Show plan before starting */}
        {phase === "preview" && (
          <Card>
            <CardHeader>
              <CardTitle>Today's Workout</CardTitle>
              <CardDescription>
                {workoutState?.remainingSets.length ?? 0} sets across{" "}
                {Object.keys(remainingSetsGrouped).length} exercises
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              {Object.entries(remainingSetsGrouped).map(([exercise, sets]) => (
                <div key={exercise} className="flex items-center gap-3">
                  <span className="text-2xl">
                    {exerciseEmoji(Number(exercise) as Exercise)}
                  </span>
                  <div>
                    <p className="font-medium">
                      {exerciseToString(Number(exercise) as Exercise)}
                    </p>
                    <p className="text-sm text-muted-foreground">
                      {sets.length}x{sets[0]?.targetReps} @ {sets[0]?.targetWeight} lbs
                    </p>
                  </div>
                </div>
              ))}
              <Button onClick={startWorkout} className="w-full mt-4">
                Start Workout
              </Button>
            </CardContent>
          </Card>
        )}

        {/* Ready Phase - Ready to start a set */}
        {phase === "ready" && nextSet && (
          <Card className="border-2 border-primary">
            <CardContent className="py-8">
              <div className="text-center space-y-6">
                <div>
                  <span className="text-6xl">{exerciseEmoji(nextSet.exercise)}</span>
                </div>
                <div>
                  <h2 className="text-2xl font-bold">
                    Do {nextSet.targetReps} {exerciseToString(nextSet.exercise)}
                  </h2>
                  <p className="text-lg text-muted-foreground mt-1">
                    Set {nextSet.setNumber} @ {nextSet.targetWeight} lbs
                  </p>
                </div>
                <Button 
                  onClick={handleStartSet} 
                  size="lg" 
                  className="w-full h-16 text-xl"
                >
                  Start Set
                </Button>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Performing Phase - Timer counting up during set, with rep buttons */}
        {phase === "performing" && currentActivity && (
          <Card className="border-2 border-yellow-500">
            <CardContent className="py-8">
              <div className="text-center space-y-6">
                <div>
                  <span className="text-6xl">{exerciseEmoji(currentActivity.exercise)}</span>
                </div>
                <div>
                  <div className="text-6xl font-mono font-bold text-yellow-500">
                    {formatTime(setElapsedSeconds)}
                  </div>
                  <p className="text-lg text-muted-foreground mt-2">
                    {currentActivity.targetReps} reps @ {currentActivity.weight} lbs
                  </p>
                </div>
                <div>
                  <p className="text-sm text-muted-foreground mb-3">
                    How many reps did you complete?
                  </p>
                  <div className="flex gap-3 justify-center flex-wrap">
                    {Array.from({ length: currentActivity.targetReps }, (_, i) => i + 1).map((reps) => (
                      <Button
                        key={reps}
                        onClick={() => handleSelectReps(reps)}
                        size="lg"
                        variant={reps === currentActivity.targetReps ? "default" : "outline"}
                        className={`w-16 h-16 text-2xl ${
                          reps === currentActivity.targetReps ? "ring-2 ring-green-500" : ""
                        }`}
                      >
                        {reps}
                      </Button>
                    ))}
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Resting Phase - Countdown to next set */}
        {phase === "resting" && restInfo && nextSet && (
          <Card className="border-2 border-primary">
            <CardContent className="py-8">
              <div className="text-center space-y-4">
                <div className="text-5xl font-mono font-bold">
                  {formatTime(restInfo.secondsRemaining)}
                </div>
                <div className="text-lg font-medium text-primary">
                  {restInfo.secondsRemaining > 60 ? "Recovering..." : "Almost ready!"}
                </div>
                <div className="text-sm text-muted-foreground">
                  Start next set at {formatTimestamp(restInfo.targetTime)}
                </div>

                {/* Progress bar */}
                <div className="h-2 bg-muted rounded-full overflow-hidden">
                  <div 
                    className="h-full bg-primary transition-all"
                    style={{ 
                      width: `${Math.max(0, 100 - (restInfo.secondsRemaining / restInfo.plannedSeconds) * 100)}%` 
                    }}
                  />
                </div>

                {/* Next set preview */}
                <div className="mt-6 p-4 bg-muted rounded-lg">
                  <p className="text-sm text-muted-foreground mb-2">Up Next:</p>
                  <div className="flex items-center justify-center gap-2">
                    <span className="text-2xl">{exerciseEmoji(nextSet.exercise)}</span>
                    <span className="font-medium">
                      {nextSet.targetReps} {exerciseToString(nextSet.exercise)}
                    </span>
                    <span className="text-muted-foreground">
                      @ {nextSet.targetWeight} lbs
                    </span>
                  </div>
                </div>

                <Button 
                  onClick={handleStartSet}
                  size="lg"
                  variant="outline"
                  className="w-full h-14 text-lg"
                >
                  Start Set Early
                </Button>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Chatting Phase - Past rest time or unplanned rest */}
        {phase === "chatting" && restInfo && nextSet && (
          <Card className="border-2 border-destructive">
            <CardContent className="py-8">
              <div className="text-center space-y-4">
                <div className="text-5xl font-mono font-bold text-destructive">
                  +{formatTime(Math.abs(restInfo.secondsRemaining))}
                </div>
                <div className="text-lg font-medium text-destructive">
                  Chat Time 💬
                </div>
                <div className="text-sm text-muted-foreground">
                  {currentRoast}
                </div>
                
                {/* Show how long planned rest was if we went over */}
                {restInfo.plannedSeconds > 0 && (
                  <div className="text-xs text-muted-foreground">
                    Planned rest: {formatTime(restInfo.plannedSeconds)}
                  </div>
                )}

                {/* Progress bar - full and red */}
                <div className="h-2 bg-muted rounded-full overflow-hidden">
                  <div className="h-full bg-destructive w-full" />
                </div>

                {/* Next set preview */}
                <div className="mt-6 p-4 bg-muted rounded-lg">
                  <p className="text-sm text-muted-foreground mb-2">Waiting for you:</p>
                  <div className="flex items-center justify-center gap-2">
                    <span className="text-2xl">{exerciseEmoji(nextSet.exercise)}</span>
                    <span className="font-medium">
                      {nextSet.targetReps} {exerciseToString(nextSet.exercise)}
                    </span>
                    <span className="text-muted-foreground">
                      @ {nextSet.targetWeight} lbs
                    </span>
                  </div>
                </div>

                <Button 
                  onClick={handleStartSet}
                  size="lg"
                  className="w-full h-16 text-xl"
                >
                  Start Set Now!
                </Button>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Progress indicator */}
        {phase !== "preview" && workoutState && (
          <div className="text-center text-sm text-muted-foreground">
            {workoutState.timeline.filter(a => a.type === ActivityType.SET && a.endedAt).length} / {(workoutState.timeline.filter(a => a.type === ActivityType.SET && a.endedAt).length + workoutState.remainingSets.length)} sets complete
          </div>
        )}

        {/* Timeline */}
        {phase !== "preview" && workoutState && workoutState.timeline.length > 0 && (
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
        )}

        {/* Remaining sets overview */}
        {phase !== "preview" && workoutState && workoutState.remainingSets.length > 0 && (
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-lg">Remaining Sets</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                {Object.entries(remainingSetsGrouped).map(([exercise, sets]) => (
                  <div key={exercise} className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <span>{exerciseEmoji(Number(exercise) as Exercise)}</span>
                      <span>{exerciseToString(Number(exercise) as Exercise)}</span>
                    </div>
                    <div className="flex gap-1">
                      {sets.map((set, idx) => (
                        <div 
                          key={idx}
                          className={`w-8 h-8 rounded flex items-center justify-center text-sm ${
                            set === nextSet 
                              ? "bg-primary text-primary-foreground font-bold" 
                              : "bg-muted text-muted-foreground"
                          }`}
                        >
                          {set.setNumber}
                        </div>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        )}
      </main>
    </div>
  );
}
