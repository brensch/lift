import { createContext, useContext, useState, useEffect, useCallback, useRef, type ReactNode } from "react";
import { useUser } from "@/context/UserContext";
import {
  type WorkoutState,
  type Activity,
  type PlannedSet,
  type RestConfig,
  type ProposedWorkout,
  type UserPreferences,
  ActivityType,
  Exercise,
} from "@/lib/api";

// Roasts for when you're past your rest time
const CHAT_TIME_ROASTS = [
  "Did you get lost?",
  "The weights miss you",
  "Your muscles are getting cold",
  "Netflix break?",
  "Making new friends?",
  "Did you fall asleep?",
  "The bar is getting lonely",
  "Is there a line for the water fountain?",
  "Checking your DMs?",
  "Writing your memoir?",
];

function getRandomRoast(): string {
  return CHAT_TIME_ROASTS[Math.floor(Math.random() * CHAT_TIME_ROASTS.length)];
}

// UI phases for the workout flow
export type WorkoutPhase =
  | "loading"      // Initial load
  | "preview"      // Before workout starts - show upcoming workouts
  | "ready"        // Ready to start a set - show "Start Set" button
  | "performing"   // Currently doing a set - timer counting up, pick reps when done
  | "resting"      // Resting between sets - timer counting down
  | "chatting"     // Past rest time - timer counting up (unplanned rest)
  | "complete";    // Workout finished

interface WorkoutContextType {
  // State from backend
  workoutState: WorkoutState | null;
  upcomingWorkouts: ProposedWorkout[];
  restConfig: RestConfig | null;
  preferences: UserPreferences | null;

  // UI state
  loading: boolean;
  error: string | null;
  phase: WorkoutPhase;
  currentActivity: Activity | null;
  currentTime: Date;
  currentRoast: string;
  selectedWorkoutIndex: number;

  // Computed values
  remainingSetsGrouped: Record<number, PlannedSet[]>;
  orderedExercises: Exercise[];
  nextSet: PlannedSet | undefined;
  totalWorkoutSeconds: number;
  setElapsedSeconds: number;
  restInfo: {
    secondsRemaining: number;
    isPastTarget: boolean;
    targetTime: Date;
    plannedSeconds: number;
  } | null;

  // Actions
  refresh: () => Promise<void>;
  selectWorkout: (index: number) => void;
  startWorkout: () => Promise<void>;
  handleStartSet: () => Promise<void>;
  handleSelectReps: (reps: number) => Promise<void>;
  handleStartNewWorkout: () => Promise<void>;
  handleUpdateWeight: (exercise: Exercise, newWeight: number) => Promise<void>;
  updatePreferences: (workoutDays: number[]) => Promise<void>;
  setExerciseOrder: (exercises: Exercise[]) => void;
  setError: (error: string | null) => void;
}

const WorkoutContext = createContext<WorkoutContextType | null>(null);

export function WorkoutProvider({ children }: { children: ReactNode }) {
  const { client } = useUser();

  // State from backend
  const [workoutState, setWorkoutState] = useState<WorkoutState | null>(null);
  const [upcomingWorkouts, setUpcomingWorkouts] = useState<ProposedWorkout[]>([]);
  const [restConfig, setRestConfig] = useState<RestConfig | null>(null);
  const [preferences, setPreferences] = useState<UserPreferences | null>(null);

  // UI state
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [phase, setPhase] = useState<WorkoutPhase>("loading");
  const [currentActivity, setCurrentActivity] = useState<Activity | null>(null);
  const [selectedWorkoutIndex, setSelectedWorkoutIndex] = useState(0);

  // Timer state
  const [currentTime, setCurrentTime] = useState(new Date());
  const [currentRoast, setCurrentRoast] = useState<string>("");
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Exercise order state (user-controlled ordering for remaining sets)
  const [exerciseOrder, setExerciseOrder] = useState<Exercise[]>([]);

  // Determine phase from workout state
  const determinePhase = useCallback((state: WorkoutState | null): WorkoutPhase => {
    if (!state) return "preview";

    if (state.isComplete) {
      return "complete";
    }

    if (state.currentActivity) {
      const activity = state.currentActivity;

      if (activity.type === ActivityType.SET) {
        return "performing";
      } else if (activity.type === ActivityType.REST) {
        const restStarted = activity.startedAt?.toDate() ?? new Date();
        const restDuration = activity.plannedDurationSeconds * 1000;
        const restEndsAt = new Date(restStarted.getTime() + restDuration);

        if (new Date() > restEndsAt) {
          return "chatting";
        }
        return "resting";
      }
    }

    // Workout started but no current activity - ready for next set
    if (state.workoutStartedAt) {
      return "ready";
    }

    return "preview";
  }, []);

  // Fetch upcoming workouts and active workout from backend
  const refresh = useCallback(async () => {
    if (!client) return;

    try {
      setLoading(true);
      setError(null);
      const response = await client.getUpcomingWorkouts({});

      setUpcomingWorkouts(response.workouts);
      setRestConfig(response.restConfig ?? null);
      setPreferences(response.preferences ?? null);

      // Check if there's an active workout
      if (response.activeWorkout) {
        setWorkoutState(response.activeWorkout);
        const newPhase = determinePhase(response.activeWorkout);
        setPhase(newPhase);

        if (response.activeWorkout.currentActivity) {
          setCurrentActivity(response.activeWorkout.currentActivity);
        }

        if (newPhase === "chatting" && !currentRoast) {
          setCurrentRoast(getRandomRoast());
        }
      } else {
        setWorkoutState(null);
        setPhase("preview");
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to fetch workouts");
    } finally {
      setLoading(false);
    }
  }, [client, determinePhase, currentRoast]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  // Timer effect
  useEffect(() => {
    if (phase !== "preview" && phase !== "complete" && phase !== "loading") {
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
  const totalWorkoutSeconds = workoutState?.workoutStartedAt
    ? Math.floor((currentTime.getTime() - workoutState.workoutStartedAt.toDate().getTime()) / 1000)
    : 0;

  // Get sets to display (from active workout or selected upcoming workout)
  const displaySets = workoutState?.remainingSets ?? upcomingWorkouts[selectedWorkoutIndex]?.sets ?? [];

  // Get remaining sets grouped by exercise
  const remainingSetsGrouped = displaySets.reduce(
    (acc, set) => {
      if (!acc[set.exercise]) {
        acc[set.exercise] = [];
      }
      acc[set.exercise].push(set);
      return acc;
    },
    {} as Record<number, PlannedSet[]>
  );

  // Get unique exercises from remaining sets, preserving the order from the backend
  const exercisesInRemaining: Exercise[] = [];
  for (const set of displaySets) {
    if (!exercisesInRemaining.includes(set.exercise)) {
      exercisesInRemaining.push(set.exercise);
    }
  }

  // Use local exerciseOrder if set (during drag), otherwise use backend order
  const orderedExercises = exerciseOrder.length > 0
    ? exerciseOrder.filter(e => exercisesInRemaining.includes(e))
    : exercisesInRemaining;

  // Add any new exercises that aren't in the order yet
  const missingExercises = exercisesInRemaining.filter(e => !orderedExercises.includes(e));
  const finalOrderedExercises = [...orderedExercises, ...missingExercises];

  // Next set is determined by the first exercise in our order
  const nextSet = finalOrderedExercises.length > 0 && remainingSetsGrouped[finalOrderedExercises[0]]
    ? remainingSetsGrouped[finalOrderedExercises[0]][0]
    : workoutState?.nextSet;

  // Select which upcoming workout to view/start
  const selectWorkout = (index: number) => {
    setSelectedWorkoutIndex(index);
  };

  // Start the workout with the selected plan
  const startWorkout = async () => {
    if (!client) return;

    const selectedWorkout = upcomingWorkouts[selectedWorkoutIndex];
    if (!selectedWorkout) return;

    try {
      const response = await client.startWorkout({
        sets: selectedWorkout.sets,
        workoutType: selectedWorkout.workoutType,
      });

      if (response.state) {
        setWorkoutState(response.state);
        setPhase("ready");
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to start workout");
    }
  };

  // Update weight for an exercise (all sets) - only works during active workout
  const handleUpdateWeight = async (exercise: Exercise, newWeight: number) => {
    if (!client || !workoutState) return;

    try {
      await client.updatePlannedWeight({
        sessionId: workoutState.sessionId,
        exercise: exercise,
        newWeight: newWeight,
      });

      // Refetch to get updated state
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to update weight");
    }
  };

  // Update exercise order (persists to backend) - only works during active workout
  const handleSetExerciseOrder = async (exercises: Exercise[]) => {
    // Optimistically update local state immediately for responsiveness
    setExerciseOrder(exercises);

    if (!client || !workoutState) return;

    try {
      await client.setExerciseOrder({
        sessionId: workoutState.sessionId,
        exerciseOrder: exercises,
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to update exercise order");
      await refresh();
    }
  };

  // Update user preferences (workout days)
  const updatePreferences = async (workoutDays: number[]) => {
    if (!client) return;

    try {
      await client.updateUserPreferences({
        preferences: { workoutDays },
      });
      // Refresh to get updated upcoming workouts with new dates
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to update preferences");
    }
  };

  // Start a set (from ready, resting, or chatting phase)
  const handleStartSet = async () => {
    if (!client || !workoutState) return;

    // Use our computed nextSet (respecting user's exercise order), fallback to backend's nextSet
    const setToStart = nextSet ?? workoutState.nextSet;
    if (!setToStart) return;

    try {
      // If there's a current rest activity, finish it first
      if (currentActivity && currentActivity.type === ActivityType.REST) {
        await client.finishActivity({
          sessionId: workoutState.sessionId,
          activityId: currentActivity.id,
          actualReps: 0, // Not needed for REST
        });
      }

      const response = await client.startSet({
        sessionId: workoutState.sessionId,
        exercise: setToStart.exercise,
        setNumber: setToStart.setNumber,
        weight: setToStart.targetWeight,
        targetReps: setToStart.targetReps,
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

  // Return to preview (after completing a workout)
  const handleStartNewWorkout = async () => {
    setWorkoutState(null);
    setPhase("preview");
    setCurrentActivity(null);
    setCurrentRoast("");
    setExerciseOrder([]);
    setSelectedWorkoutIndex(0);
    await refresh();
  };

  return (
    <WorkoutContext.Provider
      value={{
        workoutState,
        upcomingWorkouts,
        restConfig,
        preferences,
        loading,
        error,
        phase,
        currentActivity,
        currentTime,
        currentRoast,
        selectedWorkoutIndex,
        remainingSetsGrouped,
        orderedExercises: finalOrderedExercises,
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
        updatePreferences,
        setExerciseOrder: handleSetExerciseOrder,
        setError,
      }}
    >
      {children}
    </WorkoutContext.Provider>
  );
}

export function useWorkout() {
  const context = useContext(WorkoutContext);
  if (!context) {
    throw new Error("useWorkout must be used within a WorkoutProvider");
  }
  return context;
}
