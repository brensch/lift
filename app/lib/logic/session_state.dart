/// Pure session/workout-state logic: a snapshot's state on this clock,
/// participant ordering, and the client-side "who lifts next" derivation.
/// No Flutter imports.
library;

import 'dart:math';

import 'package:fixnum/fixnum.dart';

import '../gen/copy.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/group.pb.dart';

String formatRestClock(int seconds) {
  final m = seconds.abs() ~/ 60;
  final s = seconds.abs() % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String formatElapsedClock(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// A duration in hours and minutes: "1h 5m", "45m".
String formatDurationShort(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

/// A snapshot's state on this clock. The snapshot is from the last change,
/// so a rest it says is running may have run out since: that is yapping.
WorkoutState stateAt(WorkoutStateSnapshot? snapshot, int nowUnix) {
  final state = snapshot?.state ?? WorkoutState.WORKOUT_STATE_UNSPECIFIED;
  if (state == WorkoutState.WORKOUT_STATE_RESTING &&
      snapshot!.restUntil.toInt() <= nowUnix) {
    return WorkoutState.WORKOUT_STATE_YAPPING;
  }
  return state;
}

/// How long after a rest's end the in-app cue still plays. Later than this
/// (the app was suspended through it) the OS notification already rang.
const restEndCueWindowSeconds = 2;

/// Whether a rest that has run out ended just now, so the in-app sound and
/// haptic are for it, not for one that ended while the app was away.
bool restEndedJustNow(WorkoutStateSnapshot snapshot, int nowUnix) =>
    nowUnix - snapshot.restUntil.toInt() <= restEndCueWindowSeconds;

/// A workout's stage as every status line says it (your bar, a partner's
/// bar, the watch): its state on this clock ([stateAt]), the label, and the
/// clock. Lifting counts up from Start, resting down to the rest end,
/// yapping up from it; ready and all done have no clock.
({WorkoutState state, String label, String? timer}) stageOf(
  WorkoutStateSnapshot? snapshot,
  int nowUnix,
) {
  final state = stateAt(snapshot, nowUnix);
  final restEnd = snapshot?.restUntil.toInt() ?? 0;
  return switch (state) {
    WorkoutState.WORKOUT_STATE_LIFTING => (
      state: state,
      label: copy.workout.lifting,
      timer: formatRestClock(
        max(0, nowUnix - snapshot!.liftingStartedAt.toInt()),
      ),
    ),
    WorkoutState.WORKOUT_STATE_RESTING => (
      state: state,
      label: copy.workout.resting,
      timer: formatRestClock(max(0, restEnd - nowUnix)),
    ),
    WorkoutState.WORKOUT_STATE_YAPPING => (
      state: state,
      label: copy.workout.yapping,
      timer: formatRestClock(max(0, nowUnix - restEnd)),
    ),
    WorkoutState.WORKOUT_STATE_ALL_DONE => (
      state: state,
      label: copy.workout.allDone,
      timer: null,
    ),
    _ => (
      state: WorkoutState.WORKOUT_STATE_READY,
      label: copy.workout.ready,
      timer: null,
    ),
  };
}

/// The set a workout shows: the snapshot's, else the next one up.
ProposedSet? shownSet(WorkoutStateSnapshot? snapshot, ProposedSet? nextUp) =>
    snapshot != null && snapshot.hasDisplaySet() ? snapshot.displaySet : nextUp;

/// When a lifter is due at the rack: their rest end, past or not, or now
/// with no rest running. Null while lifting (on the rack, not waiting for
/// it), when all done, or with no set left.
int? scheduledStartUnix({
  required WorkoutState state,
  required int restUntil,
  required bool hasNextSet,
  required int nowUnix,
}) {
  if (!hasNextSet ||
      state == WorkoutState.WORKOUT_STATE_ALL_DONE ||
      state == WorkoutState.WORKOUT_STATE_LIFTING) {
    return null;
  }
  return restUntil > 0 ? restUntil : nowUnix;
}

/// A partner's [scheduledStartUnix]; null once their workout has ended.
int? participantScheduledStartUnix(
  ParticipantStatus participant, {
  required int nowUnix,
}) {
  if (participant.hasActiveWorkout() &&
      participant.activeWorkout.endTime != Int64.ZERO) {
    return null;
  }
  final snapshot = participant.hasStateSnapshot()
      ? participant.stateSnapshot
      : null;
  return scheduledStartUnix(
    state: stateAt(snapshot, nowUnix),
    restUntil: snapshot?.restUntil.toInt() ?? 0,
    hasNextSet: participant.hasNextUpSet(),
    nowUnix: nowUnix,
  );
}

String participantDisplayName(ParticipantStatus participant) {
  final name = participant.user.name.trim();
  if (name.isNotEmpty) return name;
  final id = participant.user.id.trim();
  if (id.isNotEmpty) return id;
  return 'Unknown';
}

/// How much of a rest is still to go, 0..1: from the last set's Done to
/// [restUntil]. Null when there's no rest to measure.
double? restLeftFraction(
  Iterable<CompletedSet> completedSets,
  int restUntil,
  int nowUnix,
) {
  if (completedSets.isEmpty || restUntil <= 0) return null;
  final start = completedSets.map((c) => c.endedAt.toInt()).reduce(max);
  final total = restUntil - start;
  if (total <= 0) return null;
  return ((restUntil - nowUnix) / total).clamp(0.0, 1.0);
}

int compareParticipantsByNextWorkout(
  ParticipantStatus a,
  ParticipantStatus b, {
  required int nowUnix,
}) {
  final aScheduled = participantScheduledStartUnix(a, nowUnix: nowUnix);
  final bScheduled = participantScheduledStartUnix(b, nowUnix: nowUnix);
  if (aScheduled != null && bScheduled != null && aScheduled != bScheduled) {
    return aScheduled.compareTo(bScheduled);
  }
  if (aScheduled != null && bScheduled == null) return -1;
  if (aScheduled == null && bScheduled != null) return 1;

  final nameCompare = participantDisplayName(
    a,
  ).toLowerCase().compareTo(participantDisplayName(b).toLowerCase());
  if (nameCompare != 0) return nameCompare;
  return a.user.id.compareTo(b.user.id);
}

/// Returns the userId of whoever is "next to lift" across all session members:
/// of those waiting (not lifting, not finished), the earliest scheduled start.
/// Tiebreak: lexicographic userId. Null when nobody else is in the session.
String? computeNextToLiftUserId({
  required String? myUserId,
  required List<ParticipantStatus> participants,
  required int nowUnix,
  required WorkoutState state,
  required int restUntil,
  required ProposedSet? nextSet,
}) {
  final others = participants.where(
    (p) => p.user.id.isNotEmpty && p.user.id != myUserId,
  );
  if (others.isEmpty) return null;

  String? bestId;
  int? bestStart;

  bool isCandidate(String uid, int start) {
    final b = bestId;
    final bs = bestStart;
    if (b == null || bs == null) return true;
    if (start != bs) return start < bs;
    return uid.compareTo(b) < 0;
  }

  for (final p in others) {
    final start = participantScheduledStartUnix(p, nowUnix: nowUnix);
    if (start == null) continue;
    if (isCandidate(p.user.id, start)) {
      bestId = p.user.id;
      bestStart = start;
    }
  }

  if (myUserId != null && myUserId.isNotEmpty) {
    final myStart = scheduledStartUnix(
      state: state,
      restUntil: restUntil,
      hasNextSet: nextSet != null,
      nowUnix: nowUnix,
    );
    if (myStart != null && isCandidate(myUserId, myStart)) {
      bestId = myUserId;
      bestStart = myStart;
    }
  }

  return bestId;
}
