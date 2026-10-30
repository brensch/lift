import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/group.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/user_profile.dart';
import '../theme/theme_spec.dart';
import '../gen/copy.dart';

String _fmt(int seconds) {
  final m = seconds.abs() ~/ 60;
  final s = seconds.abs() % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String participantDisplayName(ParticipantStatus participant) {
  final name = participant.user.name.trim();
  if (name.isNotEmpty) return name;
  final id = participant.user.id.trim();
  if (id.isNotEmpty) return id;
  return 'Unknown';
}

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
  // The snapshot is from their last change, so a rest it says is running
  // may have run out since: on this clock that is yapping, as it would be
  // on their phone.
  var state = snapshot?.state ?? WorkoutState.WORKOUT_STATE_UNSPECIFIED;
  if (state == WorkoutState.WORKOUT_STATE_RESTING && restUntil <= nowUnix) {
    state = WorkoutState.WORKOUT_STATE_YAPPING;
  }

  if (participant.hasActiveWorkout() &&
      participant.activeWorkout.endTime != Int64.ZERO) {
    return ParticipantVisualStatus(
      stateLabel: copy.workout.allDone,
      stateColor: tokens.successFg,
      sortPriority: 0,
      isComplete: true,
    );
  }

  final shownSet = snapshot != null && snapshot.hasDisplaySet()
      ? snapshot.displaySet
      : nextSet;

  if (state == WorkoutState.WORKOUT_STATE_LIFTING && shownSet != null) {
    return ParticipantVisualStatus(
      stateLabel: copy.workout.lifting,
      stateColor: tokens.workoutLiftingFg,
      proposedSet: shownSet,
      timerText: _fmt(max(0, nowUnix - snapshot!.liftingStartedAt.toInt())),
      sortPriority: 3,
    );
  }

  if (state == WorkoutState.WORKOUT_STATE_RESTING && nextSet != null) {
    return ParticipantVisualStatus(
      stateLabel: copy.workout.resting,
      stateColor: tokens.workoutRestingFg,
      proposedSet: nextSet,
      timerText: _fmt(max(0, restUntil - nowUnix)),
      sortPriority: 2,
    );
  }

  // Their rest has run out and the next set isn't started: yapping,
  // counting up from the rest end.
  if (state == WorkoutState.WORKOUT_STATE_YAPPING && nextSet != null) {
    return ParticipantVisualStatus(
      stateLabel: copy.workout.yapping,
      stateColor: tokens.workoutYappingFg,
      proposedSet: nextSet,
      timerText: _fmt(max(0, nowUnix - restUntil)),
      sortPriority: 1,
    );
  }

  if (nextSet != null) {
    return ParticipantVisualStatus(
      stateLabel: copy.workout.ready,
      stateColor: tokens.warmupFg,
      proposedSet: nextSet,
      sortPriority: 1,
    );
  }

  return ParticipantVisualStatus(
    stateLabel: copy.workout.allDone,
    stateColor: tokens.successFg,
    sortPriority: 0,
    isComplete: true,
  );
}

int? participantScheduledStartUnix(
  ParticipantStatus participant, {
  required int nowUnix,
}) {
  if (participant.hasActiveWorkout() &&
      participant.activeWorkout.endTime != Int64.ZERO) {
    return null;
  }

  if (!participant.hasNextUpSet()) return null;

  // Lifting: on the rack, not waiting for it. Resting or yapping: their
  // rest end, past or not. Otherwise they could go now.
  final snapshot = participant.hasStateSnapshot()
      ? participant.stateSnapshot
      : null;
  if (snapshot == null) return nowUnix;
  if (snapshot.state == WorkoutState.WORKOUT_STATE_LIFTING) return null;
  final restUntil = snapshot.restUntil.toInt();
  return restUntil > 0 ? restUntil : nowUnix;
}

class ParticipantVisualStatus {
  final String stateLabel;
  final Color stateColor;
  final ProposedSet? proposedSet;
  final String? timerText;
  final int sortPriority;
  final bool isComplete;

  const ParticipantVisualStatus({
    required this.stateLabel,
    required this.stateColor,
    this.proposedSet,
    this.timerText,
    required this.sortPriority,
    this.isComplete = false,
  });
}
