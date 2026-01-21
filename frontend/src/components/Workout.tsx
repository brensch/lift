import { useState } from "react";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { BarbellCalculator } from "@/components/BarbellCalculator";
import { RemainingSets } from "@/components/RemainingSets";
import { Timeline } from "@/components/Timeline";
import { WorkoutSummary } from "@/components/WorkoutSummary";
import { useUser } from "@/context/UserContext";
import { WorkoutProvider, useWorkout } from "@/context/WorkoutContext";
import {
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

function WorkoutContent() {
  const { username, logout } = useUser();
  const {
    workoutState,
    loading,
    error,
    phase,
    currentActivity,
    currentRoast,
    remainingSetsGrouped,
    nextSet,
    totalWorkoutSeconds,
    setElapsedSeconds,
    restInfo,
    fetchWorkoutState,
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
              {Object.entries(remainingSetsGrouped).map(([exercise, sets]) => {
                const exerciseNum = Number(exercise) as Exercise;
                
                return (
                  <div key={exercise} className="flex items-center justify-between gap-3">
                    <div className="flex items-center gap-3">
                      <span className="text-2xl">
                        {exerciseEmoji(exerciseNum)}
                      </span>
                      <div>
                        <p className="font-medium">
                          {exerciseToString(exerciseNum)}
                        </p>
                        <p className="text-sm text-muted-foreground">
                          {sets.length}x{sets[0]?.targetReps} @ {sets[0]?.targetWeight} lbs
                        </p>
                      </div>
                    </div>
                    <Button 
                      variant="ghost" 
                      size="sm"
                      onClick={() => openWeightEditor(exerciseNum, sets[0]?.targetWeight ?? 45)}
                    >
                      ✏️
                    </Button>
                  </div>
                );
              })}
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
                  <div className="flex items-center justify-center gap-2 mt-1">
                    <p className="text-lg text-muted-foreground">
                      Set {nextSet.setNumber} @ {nextSet.targetWeight} lbs
                    </p>
                    <Button 
                      variant="ghost" 
                      size="sm"
                      onClick={() => openWeightEditor(nextSet.exercise, nextSet.targetWeight)}
                    >
                      ✏️
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
                      ✏️
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
                    <Button 
                      variant="ghost" 
                      size="sm"
                      className="h-6 w-6 p-0"
                      onClick={() => openWeightEditor(nextSet.exercise, nextSet.targetWeight)}
                    >
                      ✏️
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
        <RemainingSets />

        {/* Timeline */}
        <Timeline />

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
    </WorkoutProvider>
  );
}
