import { createContext, useContext, useState, useEffect, useCallback, useRef, type ReactNode } from "react";
import { useUser } from "@/context/UserContext";
import {
  type WorkoutState,
  type Activity,
  type PlannedSet,
  type RestConfig,
  type ProposedWorkout,
  type UserPreferences,
  type WorkoutGroup,
  type GroupInvite,
  type GroupWorkoutPlan,
  type WorkoutUpdate,
  type GroupSession,
  type UserExercisePlan,
  ActivityType,
  Exercise,
  UpdateType,
  watchNotifications,
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

  // Group state
  activeGroup: WorkoutGroup | null;
  activeSession: GroupSession | null;  // New group session system
  pendingInvites: GroupInvite[];
  groupWorkoutPlan: GroupWorkoutPlan | null;
  showPlanningModal: boolean;

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

  // Group actions
  inviteToGroup: (username: string) => Promise<{ plan: GroupWorkoutPlan | null; error: string | null }>;
  respondToInvite: (inviteId: string, accept: boolean) => Promise<void>;
  leaveGroup: () => Promise<void>;

  // New group session actions
  createGroupSession: (inviteUsername: string) => Promise<{ session: GroupSession | null; error: string | null }>;
  joinGroupSession: (inviteId: string) => Promise<{ session: GroupSession | null; error: string | null }>;
  updateMyPlan: (exercises: UserExercisePlan[]) => Promise<void>;
  setReady: (ready: boolean) => Promise<void>;
  startGroupWorkout: () => Promise<void>;
  leaveGroupSession: () => Promise<void>;
  closePlanningModal: () => void;

  // Workout control
  finishWorkoutEarly: () => Promise<void>;
}

const WorkoutContext = createContext<WorkoutContextType | null>(null);

export function WorkoutProvider({ children }: { children: ReactNode }) {
  const { client, username } = useUser();

  // State from backend
  const [workoutState, setWorkoutState] = useState<WorkoutState | null>(null);
  const [upcomingWorkouts, setUpcomingWorkouts] = useState<ProposedWorkout[]>([]);
  const [restConfig, setRestConfig] = useState<RestConfig | null>(null);
  const [preferences, setPreferences] = useState<UserPreferences | null>(null);

  // Group state
  const [activeGroup, setActiveGroup] = useState<WorkoutGroup | null>(null);
  const [activeSession, setActiveSession] = useState<GroupSession | null>(null);
  const [pendingInvites, setPendingInvites] = useState<GroupInvite[]>([]);
  const [groupWorkoutPlan, setGroupWorkoutPlan] = useState<GroupWorkoutPlan | null>(null);
  const [showPlanningModal, setShowPlanningModal] = useState(false);

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
      setPendingInvites(response.pendingInvites ?? []);
      setActiveGroup(response.activeGroup ?? null);

      // New group session system
      if (response.activeSession) {
        setActiveSession(response.activeSession);
        // Show planning modal if session is in planning phase
        if (response.activeSession.status === "planning") {
          setShowPlanningModal(true);
        }
      } else {
        setActiveSession(null);
      }

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

  // Real-time streaming subscription - connect when logged in with auto-reconnect
  useEffect(() => {
    if (!username) return;

    let abortController: AbortController | null = null;
    let reconnectTimeout: ReturnType<typeof setTimeout> | null = null;
    let isCleaningUp = false;

    const connect = () => {
      if (isCleaningUp) return;

      console.log("Connecting to notification stream for:", username);

      abortController = watchNotifications(
        username,
        (update: WorkoutUpdate) => {
          // Ignore heartbeat messages - they're just to keep connection alive
          if (update.type === UpdateType.HEARTBEAT) {
            return;
          }

          console.log("Received update:", update.type, update);

          // Handle different update types
          switch (update.type) {
            case UpdateType.INVITE_RECEIVED:
            // Someone invited us - refresh to show the pending invite
            console.log("Received invite from:", update.userId);
            refresh();
            break;
          case UpdateType.INVITE_ACCEPTED:
            // Someone accepted our invite - refresh to show them in the group
            console.log("Invite accepted by:", update.userId);
            if (update.group) {
              setActiveGroup(update.group);
            }
            refresh();
            break;
          case UpdateType.INVITE_DECLINED:
            // Someone declined our invite
            console.log("Invite declined by:", update.userId);
            break;
          case UpdateType.USER_JOINED:
            // Someone joined the group
            console.log("User joined group:", update.userId);
            if (update.group) {
              setActiveGroup(update.group);
            }
            if (update.session) {
              setActiveSession(update.session);
              // Show planning modal when joining a new session (if in planning phase)
              if (update.session.status === "planning") {
                setShowPlanningModal(true);
              }
            }
            refresh();
            break;
          case UpdateType.USER_LEFT:
            // Someone left the group
            console.log("User left group:", update.userId);
            if (update.session) {
              setActiveSession(update.session);
            }
            refresh();
            break;
          case UpdateType.SET_STARTED:
          case UpdateType.SET_COMPLETED:
          case UpdateType.REST_STARTED:
          case UpdateType.REST_SKIPPED:
          case UpdateType.GROUP_UPDATED:
            // Activity update from another user - update session if provided
            if (update.session) {
              setActiveSession(update.session);
            }
            refresh();
            break;
          case UpdateType.PLAN_UPDATED:
            // Someone updated their plan during planning phase
            console.log("Plan updated by:", update.userId);
            if (update.session) {
              setActiveSession(update.session);
            }
            break;
          case UpdateType.USER_READY:
            console.log("User marked ready:", update.userId);
            if (update.session) {
              setActiveSession(update.session);
            }
            break;
          case UpdateType.USER_NOT_READY:
            console.log("User unmarked ready:", update.userId);
            if (update.session) {
              setActiveSession(update.session);
            }
            break;
          case UpdateType.WORKOUT_STARTED:
            // Planning complete, workout is starting
            console.log("Group workout started");
            if (update.session) {
              setActiveSession(update.session);
            }
            setShowPlanningModal(false);
            refresh(); // Refresh to get the new personal workout state
            break;
          case UpdateType.SESSION_UPDATED:
            if (update.session) {
              setActiveSession(update.session);
            }
            break;
          default:
            // Unknown update type - refresh to be safe
            refresh();
        }
        },
        (error) => {
          console.error("Notification stream error:", error);
          // Reconnect after a delay if not cleaning up
          if (!isCleaningUp) {
            console.log("Will reconnect in 2 seconds...");
            reconnectTimeout = setTimeout(connect, 2000);
          }
        },
        () => {
          console.log("Notification stream closed");
          // Reconnect after a delay if not cleaning up
          if (!isCleaningUp) {
            console.log("Will reconnect in 2 seconds...");
            reconnectTimeout = setTimeout(connect, 2000);
          }
        }
      );
    };

    // Start initial connection
    connect();

    return () => {
      console.log("Disconnecting notification stream");
      isCleaningUp = true;
      if (reconnectTimeout) {
        clearTimeout(reconnectTimeout);
      }
      if (abortController) {
        abortController.abort();
      }
    };
  }, [username, refresh]);

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
    setActiveGroup(null);
    setGroupWorkoutPlan(null);
    await refresh();
  };

  // Finish the workout early (before all sets are done)
  const finishWorkoutEarly = async () => {
    if (!client || !workoutState) return;

    try {
      const response = await client.finishWorkoutEarly({
        sessionId: workoutState.sessionId,
      });

      if (response.state) {
        setWorkoutState(response.state);
        setPhase("complete");
        setCurrentActivity(null);
        setActiveSession(null);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to finish workout");
    }
  };

  // Invite a user to join your workout group
  // Returns { plan, error } - plan is set on success, error message on failure
  const inviteToGroup = async (username: string): Promise<{ plan: GroupWorkoutPlan | null; error: string | null }> => {
    if (!client) return { plan: null, error: "Not connected" };

    try {
      const response = await client.inviteToGroup({ username });
      if (response.plan) {
        setGroupWorkoutPlan(response.plan);
      }
      return { plan: response.plan ?? null, error: null };
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : "Failed to invite user";
      return { plan: null, error: errorMessage };
    }
  };

  // Respond to a group invite (accept or decline)
  const respondToInvite = async (inviteId: string, accept: boolean): Promise<void> => {
    if (!client) return;

    try {
      const response = await client.respondToInvite({ inviteId, accept });
      if (accept && response.group) {
        setActiveGroup(response.group);
        if (response.plan) {
          setGroupWorkoutPlan(response.plan);
        }
        if (response.state) {
          setWorkoutState(response.state);
          setPhase(determinePhase(response.state));
        }
      }
      // Remove the invite from pending list
      setPendingInvites(prev => prev.filter(inv => inv.id !== inviteId));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to respond to invite");
    }
  };

  // Leave the current workout group
  const leaveGroup = async (): Promise<void> => {
    if (!client) return;

    try {
      await client.leaveGroup({});
      setActiveGroup(null);
      setGroupWorkoutPlan(null);
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to leave group");
    }
  };

  // === New Group Session Functions ===

  // Create a new group session and invite someone
  const createGroupSession = async (inviteUsername: string): Promise<{ session: GroupSession | null; error: string | null }> => {
    if (!client) return { session: null, error: "Not connected" };

    try {
      const response = await client.createGroupSession({ inviteUsername });
      if (response.session) {
        setActiveSession(response.session);
        setShowPlanningModal(true);
      }
      return { session: response.session ?? null, error: null };
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : "Failed to create group session";
      return { session: null, error: errorMessage };
    }
  };

  // Join a group session (accept invite)
  const joinGroupSession = async (inviteId: string): Promise<{ session: GroupSession | null; error: string | null }> => {
    if (!client) return { session: null, error: "Not connected" };

    try {
      const response = await client.joinGroupSession({ inviteId });
      if (response.session) {
        setActiveSession(response.session);
        setShowPlanningModal(true);
      }
      // Remove the invite from pending list
      setPendingInvites(prev => prev.filter(inv => inv.id !== inviteId));
      return { session: response.session ?? null, error: null };
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : "Failed to join group session";
      return { session: null, error: errorMessage };
    }
  };

  // Update my plan during planning phase
  const updateMyPlan = async (exercises: UserExercisePlan[]): Promise<void> => {
    if (!client || !activeSession) return;

    try {
      const response = await client.updateMyPlan({
        sessionId: activeSession.id,
        exercises,
      });
      if (response.session) {
        setActiveSession(response.session);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to update plan");
    }
  };

  // Mark self as ready
  const setReady = async (ready: boolean): Promise<void> => {
    if (!client || !activeSession) return;

    try {
      const response = await client.setReady({
        sessionId: activeSession.id,
        ready,
      });
      if (response.session) {
        setActiveSession(response.session);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to set ready status");
    }
  };

  // Start the group workout (when all ready)
  const startGroupWorkout = async (): Promise<void> => {
    if (!client || !activeSession) return;

    try {
      const response = await client.startGroupWorkout({
        sessionId: activeSession.id,
      });
      if (response.session) {
        setActiveSession(response.session);
        setShowPlanningModal(false);
        // Refresh to get the new personal workout state
        await refresh();
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to start group workout");
    }
  };

  // Leave the group session
  const leaveGroupSession = async (): Promise<void> => {
    if (!client || !activeSession) return;

    try {
      await client.leaveGroupSession({ sessionId: activeSession.id });
      setActiveSession(null);
      setShowPlanningModal(false);
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to leave group session");
    }
  };

  // Close planning modal
  const closePlanningModal = () => {
    setShowPlanningModal(false);
  };

  return (
    <WorkoutContext.Provider
      value={{
        workoutState,
        upcomingWorkouts,
        restConfig,
        preferences,
        activeGroup,
        activeSession,
        pendingInvites,
        groupWorkoutPlan,
        showPlanningModal,
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
        inviteToGroup,
        respondToInvite,
        leaveGroup,
        createGroupSession,
        joinGroupSession,
        updateMyPlan,
        setReady,
        startGroupWorkout,
        leaveGroupSession,
        closePlanningModal,
        finishWorkoutEarly,
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
