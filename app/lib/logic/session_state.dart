/// Pure session/workout-state logic: snapshot-state predicates, participant ordering, and the client-side "who lifts next" derivation. No Flutter imports.
library;

import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/group.pb.dart';
import '../widgets/participant_ticker.dart';

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

bool isAllDoneState(int state) =>
    state == WorkoutState.WORKOUT_STATE_ALL_DONE.value;

bool isRestingState(int state) =>
    state == WorkoutState.WORKOUT_STATE_RESTING.value;

bool isReadyState(int state) => state == WorkoutState.WORKOUT_STATE_READY.value;

/// A set has been started and isn't done yet.
bool isLiftingState(int state) =>
    state == WorkoutState.WORKOUT_STATE_LIFTING.value;

/// The last set's rest has run out and the next set isn't started.
bool isYappingState(int state) =>
    state == WorkoutState.WORKOUT_STATE_YAPPING.value;

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

int compareParticipantsStable(ParticipantStatus a, ParticipantStatus b) {
  final nameCompare = participantDisplayName(
    a,
  ).toLowerCase().compareTo(participantDisplayName(b).toLowerCase());
  if (nameCompare != 0) return nameCompare;
  return a.user.id.compareTo(b.user.id);
}

/// Returns the userId of whoever is "next to lift" across all session members:
/// of those waiting (not lifting, not finished), the earliest scheduled start.
/// Tiebreak: lexicographic userId.
String? computeNextToLiftUserId({
  required String? myUserId,
  required List<ParticipantStatus> others,
  required int nowUnix,
  required int stateValue,
  required int restUntil,
  required ProposedSet? nextSet,
}) {
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
    // Lifting is on the rack already, not waiting for it.
    final myStart =
        !isAllDoneState(stateValue) &&
            !isLiftingState(stateValue) &&
            nextSet != null
        ? (restUntil > 0 ? restUntil : nowUnix)
        : null;
    if (myStart != null && isCandidate(myUserId, myStart)) {
      bestId = myUserId;
      bestStart = myStart;
    }
  }

  return bestId;
}

// ─── WorkoutBottomBar ─────────────────────────────────────────────────────────
