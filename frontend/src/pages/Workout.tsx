import { useEffect, useState } from "react";
import { useParams, useSearchParams, useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { useWorkout } from "../hooks/useWorkout";
import {
  useGroupProposals,
  useGroupWorkoutStream,
} from "../hooks/useGroupWorkout";
import { WorkoutView } from "../components/WorkoutView";
import { GroupPlanningModal } from "../components/GroupPlanningModal";
import { GroupWorkoutOverlay } from "../components/GroupWorkoutOverlay";
import type { Exercise } from "../gen/lift/v1/exercise_pb.js";
import { create } from "@bufbuild/protobuf";
import { ProposedSetSchema } from "../gen/lift/v1/workout_pb.js";

export function WorkoutPage() {
  const { id } = useParams<{ id: string }>();
  const [searchParams] = useSearchParams();
  const groupId = searchParams.get("group");
  const navigate = useNavigate();
  const { userId } = useAuth();

  const {
    workoutState,
    getWorkout,
    startWorkout,
    modifyProposedSets,
    startSet,
    completeSet,
    endWorkout,
  } = useWorkout();

  const [activeGroupId, setActiveGroupId] = useState<string | null>(groupId);
  const [showPlanning, setShowPlanning] = useState(!!groupId && !id);
  const { proposals, submitSelection } = useGroupProposals(activeGroupId);
  const { workoutEvent } = useGroupWorkoutStream(
    activeGroupId && !showPlanning ? activeGroupId : null,
  );

  useEffect(() => {
    if (id) {
      getWorkout(id);
    } else if (groupId && !id) {
      // Joined a group workout, show planning modal first
      setShowPlanning(true);
    }
  }, [id, groupId, getWorkout]);

  // When all ready in group planning, create sets and start workout
  useEffect(() => {
    if (proposals?.allReady && showPlanning && userId) {
      const mySelection = proposals.selections.find(
        (s) => s.userId === userId,
      );
      if (mySelection && mySelection.exercises.length > 0) {
        handleGroupReady(mySelection.exercises);
      }
    }
  }, [proposals?.allReady]);

  const handleGroupReady = async (exercises: Exercise[]) => {
    // Start a workout if we don't have one
    let state = workoutState;
    if (!state) {
      state = (await startWorkout()) ?? null;
      if (!state?.workout) return;
    }

    // Create 3 sets per exercise
    const sets = exercises.flatMap((ex, exIdx) =>
      [0, 1, 2].map((setIdx) =>
        create(ProposedSetSchema, {
          workoutId: state!.workout!.id,
          workoutOrder: exIdx * 3 + setIdx,
          exercise: ex,
          targetReps: 10,
          targetWeight: 60,
          warmup: false,
        }),
      ),
    );

    await modifyProposedSets(state.workout!.id, sets);
    setShowPlanning(false);
    navigate(`/workout/${state.workout!.id}${activeGroupId ? `?group=${activeGroupId}` : ""}`, { replace: true });
  };

  const handleSubmitSelection = async (
    exercises: Exercise[],
    ready: boolean,
  ) => {
    await submitSelection(exercises, ready);
  };

  if (!workoutState && !showPlanning) {
    return (
      <div className="flex h-screen items-center justify-center">
        <p className="text-gray-500">Loading workout...</p>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-md p-4 space-y-4">
      <button
        onClick={() => navigate("/")}
        className="text-sm text-blue-600 hover:underline"
      >
        &larr; Home
      </button>

      {/* Group planning modal */}
      {showPlanning && proposals && userId && (
        <GroupPlanningModal
          proposals={proposals}
          userId={userId}
          onSubmit={handleSubmitSelection}
          onClose={() => {
            setShowPlanning(false);
            navigate("/");
          }}
        />
      )}

      {/* Group workout overlay */}
      {workoutEvent && userId && (
        <GroupWorkoutOverlay
          workoutEvent={workoutEvent}
          currentUserId={userId}
        />
      )}

      {/* Solo/own workout view */}
      {workoutState && (
        <WorkoutView
          state={workoutState}
          onModifyProposedSets={(sets) =>
            modifyProposedSets(workoutState.workout!.id, sets)
          }
          onStartSet={(psId) => startSet(workoutState.workout!.id, psId)}
          onCompleteSet={(psId, reps, weight, restSecs) =>
            completeSet(workoutState.workout!.id, psId, reps, weight, restSecs)
          }
          onEndWorkout={() => endWorkout(workoutState.workout!.id)}
        />
      )}
    </div>
  );
}
