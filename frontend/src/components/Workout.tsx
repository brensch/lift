import { useState } from "react";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { BarbellCalculator } from "@/components/BarbellCalculator";
import { RemainingSets } from "@/components/RemainingSets";
import { Timeline } from "@/components/Timeline";
import { WorkoutSummary } from "@/components/WorkoutSummary";
import { WorkoutGroupBar } from "@/components/WorkoutGroupBar";
import { GroupPlanningModal } from "@/components/GroupPlanningModal";
import { useUser } from "@/context/UserContext";
import { WorkoutProvider, useWorkout } from "@/context/WorkoutContext";
import {
  ActivityType,
  Exercise,
  type PlannedSet,
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

function formatDayName(date: Date): string {
  return date.toLocaleDateString([], { weekday: "short" });
}

function formatDateShort(date: Date): string {
  return date.toLocaleDateString([], { month: "short", day: "numeric" });
}

function isSameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate();
}

// Group sets by exercise for display
function groupSetsByExercise(sets: PlannedSet[]): Record<number, PlannedSet[]> {
  return sets.reduce((acc, set) => {
    if (!acc[set.exercise]) {
      acc[set.exercise] = [];
    }
    acc[set.exercise].push(set);
    return acc;
  }, {} as Record<number, PlannedSet[]>);
}

function WorkoutContent() {
  const { username, logout } = useUser();
  const {
    workoutState,
    upcomingWorkouts,
    loading,
    error,
    phase,
    currentActivity,
    currentRoast,
    selectedWorkoutIndex,
    nextSet,
    totalWorkoutSeconds,
    setElapsedSeconds,
    restInfo,
    refresh,
    selectWorkout,
    startWorkout,
    handleStartSet,
    handleSelectReps,
    handleStartNewWorkout,
    handleUpdateWeight,
    setError,
  } = useWorkout();

  // Weight editing state (for barbell calculator modal)
  const [editingExercise, setEditingExercise] = useState<Exercise | null>(null);
  const [editingCurrentWeight, setEditingCurrentWeight] = useState<number>(45);

  // Open the barbell calculator for an exercise
  const openWeightEditor = (exercise: Exercise, currentWeight: number) => {
    setEditingExercise(exercise);
    setEditingCurrentWeight(currentWeight);
  };

  // Close the barbell calculator
  const closeWeightEditor = () => {
    setEditingExercise(null);
  };

  if (loading || phase === "loading") {
    return (
      <div className="min-h-screen flex items-center justify-center bg-background">
        <div className="text-lg">Loading your workouts...</div>
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
            <Button onClick={() => { setError(null); refresh(); }}>Retry</Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  // Workout complete screen
  if (phase === "complete" || workoutState?.isComplete) {
    return (
      <div className="min-h-screen bg-background p-4">
        <div className="max-w-2xl mx-auto">
          {workoutState && (
            <WorkoutSummary
              timeline={workoutState.timeline}
              sessionStartedAt={workoutState.sessionStartedAt}
              onDismiss={handleStartNewWorkout}
              showDismissButton={true}
            />
          )}
          <Button onClick={logout} variant="outline" className="w-full mt-4">
            Logout
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b p-4 flex items-center justify-between sticky top-0 bg-background z-10">
        <div>
          <h1 className="text-xl font-bold">Lift</h1>
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

      {/* Group workout bar */}
      <div className="p-4 max-w-2xl mx-auto">
        <WorkoutGroupBar />
      </div>

      <main className="p-4 max-w-2xl mx-auto space-y-4">
        {/* Preview Phase - Show upcoming workouts calendar */}
        {phase === "preview" && (
          <>
            {/* Calendar-style list of upcoming workouts */}
            <div className="space-y-3">
              {upcomingWorkouts.map((workout, index) => {
                const targetDate = workout.targetDate?.toDate();
                const isToday = targetDate && isSameDay(targetDate, new Date());
                const isSelected = selectedWorkoutIndex === index;
                const dayName = targetDate ? formatDayName(targetDate) : "";
                const dateStr = targetDate ? formatDateShort(targetDate) : "";

                return (
                  <Card
                    key={index}
                    className={`cursor-pointer transition-all ${
                      isSelected ? "border-2 border-primary ring-2 ring-primary/20" : "hover:border-muted-foreground/50"
                    } ${isToday ? "bg-primary/5" : ""}`}
                    onClick={() => selectWorkout(index)}
                  >
                    <CardContent className="p-4">
                      <div className="flex items-center gap-4">
                        {/* Date column */}
                        <div className="text-center min-w-[60px]">
                          <div className={`text-xs uppercase ${isToday ? "text-primary font-bold" : "text-muted-foreground"}`}>
                            {isToday ? "Today" : dayName}
                          </div>
                          <div className={`text-lg font-bold ${isToday ? "text-primary" : ""}`}>
                            {dateStr}
                          </div>
                        </div>

                        {/* Workout info */}
                        <div className="flex-1">
                          <div className="flex items-center gap-2">
                            <span className={`text-sm font-bold px-2 py-0.5 rounded ${
                              workout.workoutType === "A" ? "bg-blue-100 text-blue-700" : "bg-purple-100 text-purple-700"
                            }`}>
                              {workout.workoutType}
                            </span>
                            <span className="text-sm text-muted-foreground">
                              {workout.sets.length} sets
                            </span>
                          </div>
                          <div className="flex gap-2 mt-1">
                            {Array.from(new Set(workout.sets.map(s => s.exercise))).map(ex => (
                              <span key={ex} className="text-lg" title={exerciseToString(ex)}>
                                {exerciseEmoji(ex)}
                              </span>
                            ))}
                          </div>
                        </div>

                        {/* Start button for selected */}
                        {isSelected && (
                          <Button onClick={(e) => { e.stopPropagation(); startWorkout(); }} size="sm">
                            Start
                          </Button>
                        )}
                      </div>

                      {/* Expanded details when selected */}
                      {isSelected && (
                        <div className="mt-4 pt-4 border-t space-y-2">
                          {Object.entries(groupSetsByExercise(workout.sets)).map(([exercise, sets]) => {
                            const exerciseNum = Number(exercise) as Exercise;
                            return (
                              <div key={exercise} className="flex items-center gap-3">
                                <span className="text-xl">{exerciseEmoji(exerciseNum)}</span>
                                <div className="flex-1">
                                  <span className="font-medium">{exerciseToString(exerciseNum)}</span>
                                  <span className="text-muted-foreground ml-2">
                                    {sets.length}x{sets[0]?.targetReps} @ {sets[0]?.targetWeight} lbs
                                  </span>
                                </div>
                              </div>
                            );
                          })}
                        </div>
                      )}
                    </CardContent>
                  </Card>
                );
              })}
            </div>
          </>
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
                  <div className="flex items-center justify-center gap-2 mt-1">
                    <p className="text-lg text-muted-foreground">
                      Set {nextSet.setNumber} @ {nextSet.targetWeight} lbs
                    </p>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => openWeightEditor(nextSet.exercise, nextSet.targetWeight)}
                    >
                      Edit
                    </Button>
                  </div>
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
                    Once done, select the number of reps you completed:
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
                    <Button
                      variant="ghost"
                      size="sm"
                      className="h-6 w-6 p-0"
                      onClick={() => openWeightEditor(nextSet.exercise, nextSet.targetWeight)}
                    >
                      Edit
                    </Button>
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
                  Chat Time
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
                    <Button
                      variant="ghost"
                      size="sm"
                      className="h-6 w-6 p-0"
                      onClick={() => openWeightEditor(nextSet.exercise, nextSet.targetWeight)}
                    >
                      Edit
                    </Button>
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

        {/* Remaining Sets (above Timeline) */}
        {phase !== "preview" && <RemainingSets />}

        {/* Timeline - shows individual or group activity depending on context */}
        {phase !== "preview" && <Timeline />}

        {/* Barbell Calculator Modal */}
        <BarbellCalculator
          isOpen={editingExercise !== null}
          onClose={closeWeightEditor}
          currentWeight={editingCurrentWeight}
          onSubmit={(newWeight) => {
            if (editingExercise !== null) {
              handleUpdateWeight(editingExercise, newWeight);
              closeWeightEditor();
            }
          }}
          exerciseName={editingExercise !== null ? exerciseToString(editingExercise) : ""}
        />
      </main>
    </div>
  );
}

export function Workout() {
  return (
    <WorkoutProvider>
      <WorkoutContent />
      <GroupPlanningModal />
    </WorkoutProvider>
  );
}
