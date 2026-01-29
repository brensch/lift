import { useState, useEffect } from "react";
import { useWorkout } from "@/context/WorkoutContext";
import { useUser } from "@/context/UserContext";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog";
import { Check, Users } from "lucide-react";
import { Exercise, UserExercisePlan } from "@/lib/api";

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

// All possible exercises
const ALL_EXERCISES = [
  Exercise.SQUAT,
  Exercise.BENCH,
  Exercise.DEADLIFT,
  Exercise.OHP,
  Exercise.ROW,
];

export function GroupPlanningModal() {
  const { username } = useUser();
  const {
    activeSession,
    showPlanningModal,
    closePlanningModal,
    updateMyPlan,
    setReady,
    startGroupWorkout,
    leaveGroupSession,
    upcomingWorkouts,
    workoutState,
  } = useWorkout();

  // Track which exercises the user has selected
  const [selectedExercises, setSelectedExercises] = useState<Set<Exercise>>(new Set());
  const [initialized, setInitialized] = useState(false);

  // Get current user's member info
  const currentUser = activeSession?.members.find(m => m.userId === username);
  const otherMembers = activeSession?.members.filter(m => m.userId !== username) ?? [];
  const isReady = currentUser?.status === "ready";
  const allReady = activeSession?.plan?.allReady ?? false;
  const memberCount = activeSession?.members.length ?? 0;
  const readyCount = activeSession?.members.filter(m => m.status === "ready").length ?? 0;

  // Determine if user has an active workout - use that instead of "next"
  const hasActiveWorkout = workoutState && !workoutState.isComplete && workoutState.remainingSets.length > 0;

  // Get exercises from active workout OR upcoming workout
  const myCurrentExercises = hasActiveWorkout
    ? [...new Set(workoutState.remainingSets.map(s => s.exercise))]
    : [];
  const myUpNext = upcomingWorkouts[0];
  const myUpNextExercises = myUpNext ? [...new Set(myUpNext.sets.map(s => s.exercise))] : [];

  // Use active workout exercises if available, otherwise upcoming
  const myExercises = hasActiveWorkout ? myCurrentExercises : myUpNextExercises;
  const exerciseLabel = hasActiveWorkout ? "Your current workout" : "Your next workout";

  // Initialize selected exercises from user's proposed plan or current/upcoming workout
  useEffect(() => {
    if (!initialized && activeSession) {
      const myPlan = currentUser?.proposedPlan;
      if (myPlan && myPlan.exercises.length > 0) {
        setSelectedExercises(new Set(myPlan.exercises.map(e => e.exercise)));
      } else if (myExercises.length > 0) {
        setSelectedExercises(new Set(myExercises));
      }
      setInitialized(true);
    }
  }, [activeSession, currentUser, initialized, myExercises]);

  // Reset initialized state when modal closes
  useEffect(() => {
    if (!showPlanningModal) {
      setInitialized(false);
    }
  }, [showPlanningModal]);

  if (!activeSession || !showPlanningModal) return null;

  // Get all exercises that any member wants to do
  const groupExercises = new Set<Exercise>();
  activeSession.members.forEach(m => {
    m.proposedPlan?.exercises.forEach(e => groupExercises.add(e.exercise));
  });

  const handleToggleExercise = async (exercise: Exercise) => {
    const newSelected = new Set(selectedExercises);
    if (newSelected.has(exercise)) {
      newSelected.delete(exercise);
    } else {
      newSelected.add(exercise);
    }
    setSelectedExercises(newSelected);

    // Build updated plan with default values for selected exercises
    // Use values from active workout if available, then upcoming workout, then defaults
    const updatedExercises: UserExercisePlan[] = Array.from(newSelected).map(ex => {
      // Try to get weight from active workout first
      const activeSet = workoutState?.remainingSets.find(s => s.exercise === ex);
      if (activeSet) {
        return new UserExercisePlan({
          exercise: ex,
          targetWeight: activeSet.targetWeight,
          targetSets: workoutState?.remainingSets.filter(s => s.exercise === ex).length ?? 5,
          targetReps: activeSet.targetReps,
        });
      }
      // Fallback to upcoming workout
      const upNextSet = myUpNext?.sets.find(s => s.exercise === ex);
      return new UserExercisePlan({
        exercise: ex,
        targetWeight: upNextSet?.targetWeight ?? 45,
        targetSets: 5,
        targetReps: upNextSet?.targetReps ?? 5,
      });
    });

    await updateMyPlan(updatedExercises);
  };

  const handleToggleReady = async () => {
    await setReady(!isReady);
  };

  const handleStartWorkout = async () => {
    await startGroupWorkout();
  };

  const handleLeave = async () => {
    await leaveGroupSession();
  };

  // Check if an exercise is in the user's current/upcoming workout
  const isInMyWorkout = (exercise: Exercise) => myExercises.includes(exercise);

  // Check if an exercise is selected by other members
  const isSelectedByOthers = (exercise: Exercise) => {
    return otherMembers.some(m =>
      m.proposedPlan?.exercises.some(e => e.exercise === exercise)
    );
  };

  return (
    <Dialog open={showPlanningModal} onOpenChange={(open) => { if (!open) closePlanningModal(); }}>
      <DialogContent className="max-w-lg max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Users className="h-5 w-5" />
            Plan Group Workout
          </DialogTitle>
          <DialogDescription>
            Select which exercises you want to do. {memberCount > 1 && `(${readyCount}/${memberCount} ready)`}
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-6 py-4">
          {/* Members ready status */}
          <div className="flex flex-wrap gap-2">
            {activeSession.members.map((member) => (
              <div
                key={member.userId}
                className={`flex items-center gap-2 px-3 py-1.5 rounded-full text-sm ${
                  member.status === "ready"
                    ? "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200"
                    : "bg-muted"
                }`}
              >
                {member.status === "ready" ? (
                  <Check className="h-4 w-4" />
                ) : (
                  <span className="w-4 h-4 rounded-full border-2 border-current" />
                )}
                <span>{member.userId === username ? "You" : member.userId}</span>
              </div>
            ))}
          </div>

          {/* Exercise selection */}
          <div className="space-y-3">
            <h3 className="font-semibold text-sm">Select Your Exercises</h3>

            {ALL_EXERCISES.map((exercise) => {
              const isSelected = selectedExercises.has(exercise);
              const inMyWorkout = isInMyWorkout(exercise);
              const othersWant = isSelectedByOthers(exercise);

              return (
                <Card
                  key={exercise}
                  className={`p-3 cursor-pointer transition-all ${
                    isSelected ? "border-primary bg-primary/5" : ""
                  }`}
                  onClick={() => !isReady && handleToggleExercise(exercise)}
                >
                  <div className="flex items-center gap-3">
                    <Checkbox
                      checked={isSelected}
                      disabled={isReady}
                      onCheckedChange={() => handleToggleExercise(exercise)}
                    />
                    <div className="flex-1">
                      <div className="font-medium">{getExerciseName(exercise)}</div>
                      <div className="text-xs text-muted-foreground flex gap-2">
                        {inMyWorkout && (
                          <span className="text-primary">{exerciseLabel}</span>
                        )}
                        {othersWant && (
                          <span className="text-blue-600 dark:text-blue-400">
                            Others want this
                          </span>
                        )}
                      </div>
                    </div>
                    {/* Show who else wants this exercise */}
                    <div className="flex -space-x-1">
                      {otherMembers
                        .filter(m => m.proposedPlan?.exercises.some(e => e.exercise === exercise))
                        .map(m => (
                          <div
                            key={m.userId}
                            className="w-6 h-6 rounded-full bg-muted flex items-center justify-center text-xs font-medium border-2 border-background"
                            title={m.userId}
                          >
                            {m.userId.charAt(0).toUpperCase()}
                          </div>
                        ))
                      }
                    </div>
                  </div>
                </Card>
              );
            })}
          </div>

          {/* Group plan preview */}
          {activeSession.plan && activeSession.plan.exercises.length > 0 && (
            <div className="space-y-2">
              <h3 className="font-semibold text-sm">Group Order (by weight)</h3>
              <div className="text-xs text-muted-foreground space-y-1">
                {activeSession.plan.exercises.map((groupEx) => (
                  <div key={groupEx.exercise} className="flex gap-2">
                    <span className="font-medium">{getExerciseName(groupEx.exercise)}:</span>
                    <span>
                      {groupEx.userSlots.map((slot, i) => (
                        <span key={slot.userId}>
                          {i > 0 && " → "}
                          {slot.userId === username ? "You" : slot.userId}
                          <span className="text-muted-foreground"> ({slot.weight}kg)</span>
                        </span>
                      ))}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        <DialogFooter className="flex flex-col sm:flex-row gap-2">
          <Button variant="outline" onClick={handleLeave}>
            Leave
          </Button>
          <div className="flex-1" />
          <Button
            variant={isReady ? "secondary" : "default"}
            onClick={handleToggleReady}
            disabled={selectedExercises.size === 0}
          >
            {isReady ? "Change Mind" : "I'm Ready"}
          </Button>
          {allReady && (
            <Button onClick={handleStartWorkout} className="bg-green-600 hover:bg-green-700">
              Start Workout
            </Button>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
