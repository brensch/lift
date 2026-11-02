import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/group.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/session_state.dart';
import '../logic/user_profile.dart';
import '../theme/theme_spec.dart';
import '../gen/copy.dart';

String participantProfileEmoji(ParticipantStatus participant) {
  return normalizedProfileEmoji(participant.user.profileEmoji);
}

Color participantProfileColor(ParticipantStatus participant) {
  return profileColorFromHex(participant.user.profileColorHex);
}

ParticipantVisualStatus describeParticipantStatus(
  ParticipantStatus participant, {
  required ThemeSpec tokens,
  DateTime? now,
}) {
  final nowUnix = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
  final nextSet = participant.hasNextUpSet() ? participant.nextUpSet : null;
  // Their state is the server's snapshot of their workout, the same one
  // their own phone draws.
  final snapshot = participant.hasStateSnapshot()
      ? participant.stateSnapshot
      : null;
  final restUntil = snapshot?.restUntil.toInt() ?? 0;
  // On this clock, as it would be on their phone.
  final state = stateAt(snapshot, nowUnix);

  // In the group, no workout started yet: picking one.
  if (!participant.hasActiveWorkout() && snapshot == null && nextSet == null) {
    return ParticipantVisualStatus(
      stateLabel: copy.workout.choosing,
      stateColor: tokens.muted,
      sortPriority: 0,
    );
  }

  if (participant.hasActiveWorkout() &&
      participant.activeWorkout.endTime != Int64.ZERO) {
    return ParticipantVisualStatus(
      stateLabel: copy.workout.allDone,
      stateColor: tokens.success,
      sortPriority: 0,
      isComplete: true,
    );
  }

  final shown = shownSet(snapshot, nextSet);

  if (state == WorkoutState.WORKOUT_STATE_LIFTING && shown != null) {
    return ParticipantVisualStatus(
      stateLabel: copy.workout.lifting,
      stateColor: tokens.lifting,
      proposedSet: shown,
      timerText: formatRestClock(
        max(0, nowUnix - snapshot!.liftingStartedAt.toInt()),
      ),
      sortPriority: 3,
    );
  }

  if (state == WorkoutState.WORKOUT_STATE_RESTING && nextSet != null) {
    return ParticipantVisualStatus(
      stateLabel: copy.workout.resting,
      stateColor: tokens.resting,
      proposedSet: nextSet,
      timerText: formatRestClock(max(0, restUntil - nowUnix)),
      restLeft: restLeftFraction(participant.completedSets, restUntil, nowUnix),
      sortPriority: 2,
    );
  }

  // Their rest has run out and the next set isn't started: yapping,
  // counting up from the rest end.
  if (state == WorkoutState.WORKOUT_STATE_YAPPING && nextSet != null) {
    return ParticipantVisualStatus(
      stateLabel: copy.workout.yapping,
      stateColor: tokens.yapping,
      proposedSet: nextSet,
      timerText: formatRestClock(max(0, nowUnix - restUntil)),
      sortPriority: 1,
    );
  }

  if (nextSet != null) {
    return ParticipantVisualStatus(
      stateLabel: copy.workout.ready,
      stateColor: tokens.warmup,
      proposedSet: nextSet,
      sortPriority: 1,
    );
  }

  return ParticipantVisualStatus(
    stateLabel: copy.workout.allDone,
    stateColor: tokens.success,
    sortPriority: 0,
    isComplete: true,
  );
}

class ParticipantVisualStatus {
  final String stateLabel;
  final Color stateColor;
  final ProposedSet? proposedSet;
  final String? timerText;

  /// 0..1 of the rest still to go, while resting.
  final double? restLeft;
  final int sortPriority;
  final bool isComplete;

  const ParticipantVisualStatus({
    required this.stateLabel,
    required this.stateColor,
    this.proposedSet,
    this.timerText,
    this.restLeft,
    required this.sortPriority,
    this.isComplete = false,
  });
}
