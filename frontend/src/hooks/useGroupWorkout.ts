import { useState, useEffect, useRef, useCallback } from "react";
import { groupClient, transport } from "../lib/api";
import { createInflappableStream } from "../lib/stream";
import type { InviteEvent } from "../gen/lift/v1/group_pb.js";
import type {
  GroupWorkoutProposalsEvent,
  WorkoutEvent,
} from "../gen/lift/v1/group_pb.js";
import type { Exercise } from "../gen/lift/v1/exercise_pb.js";
import { createClient } from "@connectrpc/connect";
import { GroupService } from "../gen/lift/v1/group_pb.js";

export function useInviteListener(isAuthenticated: boolean) {
  const [invite, setInvite] = useState<InviteEvent | null>(null);
  const controllerRef = useRef<AbortController | null>(null);

  useEffect(() => {
    if (!isAuthenticated) return;

    const controller = new AbortController();
    controllerRef.current = controller;

    const client = createClient(GroupService, transport);

    createInflappableStream<InviteEvent>(
      (signal) => client.listenToInvites({}, { signal }),
      (msg) => setInvite(msg),
      (err) => console.error("invite stream error:", err),
      controller.signal,
    );

    return () => controller.abort();
  }, [isAuthenticated]);

  const clearInvite = useCallback(() => setInvite(null), []);

  return { invite, clearInvite };
}

export function useGroupProposals(groupWorkoutId: string | null) {
  const [proposals, setProposals] =
    useState<GroupWorkoutProposalsEvent | null>(null);
  const controllerRef = useRef<AbortController | null>(null);

  useEffect(() => {
    if (!groupWorkoutId) return;

    controllerRef.current?.abort();
    const controller = new AbortController();
    controllerRef.current = controller;

    const client = createClient(GroupService, transport);

    createInflappableStream<GroupWorkoutProposalsEvent>(
      (signal) =>
        client.groupWorkoutProposals({ groupWorkoutId }, { signal }),
      (msg) => setProposals(msg),
      (err) => console.error("proposals stream error:", err),
      controller.signal,
    );

    return () => controller.abort();
  }, [groupWorkoutId]);

  const submitSelection = useCallback(
    async (exercises: Exercise[], ready: boolean) => {
      if (!groupWorkoutId) return;
      await groupClient.submitExerciseSelection({
        groupWorkoutId,
        exercises,
        ready,
      });
    },
    [groupWorkoutId],
  );

  return { proposals, submitSelection };
}

export function useGroupWorkoutStream(groupWorkoutId: string | null) {
  const [workoutEvent, setWorkoutEvent] = useState<WorkoutEvent | null>(null);

  useEffect(() => {
    if (!groupWorkoutId) return;

    const controller = new AbortController();
    const client = createClient(GroupService, transport);

    createInflappableStream<WorkoutEvent>(
      (signal) => client.connectToWorkout({ groupWorkoutId }, { signal }),
      (msg) => setWorkoutEvent(msg),
      (err) => console.error("workout stream error:", err),
      controller.signal,
    );

    return () => controller.abort();
  }, [groupWorkoutId]);

  return { workoutEvent };
}
