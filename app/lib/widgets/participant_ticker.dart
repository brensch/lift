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
  // In the group, no workout started yet: picking one.
  if (!participant.hasActiveWorkout() && snapshot == null && nextSet == null) {
    return ParticipantVisualStatus(
      stateLabel: copy.workout.choosing,
      stateColor: tokens.muted,
    );
  }

  final ended =
      participant.hasActiveWorkout() &&
      participant.activeWorkout.endTime != Int64.ZERO;
  // On this clock, as it would be on their phone.
  final stage = stageOf(snapshot, nowUnix);
  final set = stage.state == WorkoutState.WORKOUT_STATE_LIFTING
      ? shownSet(snapshot, nextSet)
      : nextSet;
  return workoutVisualStatus(
    snapshot: snapshot,
    set: ended ? null : set,
    completedSets: participant.completedSets,
    nowUnix: nowUnix,
    tokens: tokens,
  );
}

/// A workout's stage as its status bar shows it, with [set] the set in
/// hand: all done when there is none left.
ParticipantVisualStatus workoutVisualStatus({
  required WorkoutStateSnapshot? snapshot,
  required ProposedSet? set,
  required Iterable<CompletedSet> completedSets,
  required int nowUnix,
  required ThemeSpec tokens,
}) {
  final stage = stageOf(snapshot, nowUnix);
  if (set == null || stage.state == WorkoutState.WORKOUT_STATE_ALL_DONE) {
    return ParticipantVisualStatus(
      stateLabel: copy.workout.allDone,
      stateColor: tokens.success,
    );
  }
  return ParticipantVisualStatus(
    stateLabel: stage.label,
    stateColor: stageColor(stage.state, tokens),
    proposedSet: set,
    timerText: stage.timer,
    restLeft: stage.state == WorkoutState.WORKOUT_STATE_RESTING
        ? restLeftFraction(completedSets, snapshot!.restUntil.toInt(), nowUnix)
        : null,
  );
}

/// The colour of a stage's label, one per state, wherever it's shown.
Color stageColor(WorkoutState state, ThemeSpec t) => switch (state) {
  WorkoutState.WORKOUT_STATE_LIFTING => t.lifting,
  WorkoutState.WORKOUT_STATE_RESTING => t.resting,
  WorkoutState.WORKOUT_STATE_YAPPING => t.yapping,
  WorkoutState.WORKOUT_STATE_ALL_DONE => t.success,
  _ => t.ready,
};

class ParticipantVisualStatus {
  final String stateLabel;
  final Color stateColor;
  final ProposedSet? proposedSet;
  final String? timerText;

  /// 0..1 of the rest still to go, while resting.
  final double? restLeft;

  const ParticipantVisualStatus({
    required this.stateLabel,
    required this.stateColor,
    this.proposedSet,
    this.timerText,
    this.restLeft,
  });
}
