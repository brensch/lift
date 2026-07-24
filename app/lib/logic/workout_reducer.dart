/// Optimistic state transitions on the active workout's set lists.
///
/// This is the client-side mirror of the server's reducer
/// (`src/workout/reducer.rs`): the app applies the same transition locally the
/// moment the user acts, then reconciles when the server responds. If the two
/// disagree, the user watches their state change twice — so any semantic
/// change here must be mirrored there, and vice versa.
///
/// Pure list manipulation, no Flutter imports; covered by
/// `test/logic/workout_reducer_test.dart`.
library;

import 'package:fixnum/fixnum.dart';
import 'package:uuid/uuid.dart';

import '../gen/workout/v1/workout.pb.dart';

const _uuid = Uuid();

/// Rest after the final set of an exercise group — just long enough to move
/// to the next exercise. Mirrors `END_OF_EXERCISE_GROUP_REST_SECONDS` in
/// `src/workout/mod.rs`; the server is authoritative, so a different value
/// here makes the rest countdown visibly jump when the response lands.
const int endOfGroupRestSeconds = 60;

/// Open an in-progress completed set for [proposedSetId].
///
/// No-ops (like the server) when the set is missing or cancelled — stale watch
/// intents must not error — and when the set is already in progress, so
/// at-least-once delivery cannot open two rows.
void applyLocalStartSet({
  required String workoutId,
  required List<ProposedSet> proposedSets,
  required List<CompletedSet> completedSets,
  required String proposedSetId,
  required int nowSecs,
  int? startedAt,
}) {
  final proposed = proposedSets.cast<ProposedSet?>().firstWhere(
    (p) => p?.id == proposedSetId && !(p?.cancelled ?? true),
    orElse: () => null,
  );
  if (proposed == null) return;
  final alreadyActive = completedSets.any(
    (c) => c.proposedSetId == proposedSetId && c.endedAt == Int64.ZERO,
  );
  if (alreadyActive) return;
  completedSets.add(
    CompletedSet()
      ..id = _uuid.v4()
      ..workoutId = workoutId
      ..proposedSetId = proposedSetId
      ..actualReps = proposed.targetReps
      ..actualWeight = proposed.targetWeight
      ..startedAt = Int64(startedAt ?? nowSecs)
      ..endedAt = Int64.ZERO
      ..restUntil = Int64.ZERO,
  );
}

/// Finish [proposedSetId]: update the in-progress row if one exists (keeping
/// its start time), otherwise create the row directly (one-tap completion).
/// Rest is success/failure rest based on hitting the target, shortened to
/// [endOfGroupRestSeconds] when this was the group's final pending set.
void applyLocalCompleteSet({
  required String workoutId,
  required List<ProposedSet> proposedSets,
  required List<CompletedSet> completedSets,
  required String proposedSetId,
  required int actualReps,
  required double actualWeight,
  required int nowSecs,
  int? completedAt,
}) {
  final proposed = proposedSets.cast<ProposedSet?>().firstWhere(
    (p) => p?.id == proposedSetId && !(p?.cancelled ?? true),
    orElse: () => null,
  );
  if (proposed == null) return;
  final endedAt = completedAt ?? nowSecs;
  var restSeconds = actualReps >= proposed.targetReps
      ? proposed.restAfterSuccess
      : proposed.restAfterFailure;
  final pendingInGroup = proposedSets.where(
    (set) =>
        set.exerciseGroupId == proposed.exerciseGroupId &&
        !set.cancelled &&
        set.id != proposed.id &&
        !completedSets.any(
          (done) => done.proposedSetId == set.id && done.endedAt != Int64.ZERO,
        ),
  );
  if (pendingInGroup.isEmpty) {
    restSeconds = endOfGroupRestSeconds;
  }

  final existingIdx = completedSets.indexWhere(
    (c) => c.proposedSetId == proposedSetId && c.endedAt == Int64.ZERO,
  );
  if (existingIdx != -1) {
    final set = completedSets[existingIdx];
    set
      ..actualReps = actualReps
      ..actualWeight = actualWeight
      ..endedAt = Int64(endedAt)
      ..restUntil = Int64(endedAt + restSeconds);
  } else {
    completedSets.add(
      CompletedSet()
        ..id = _uuid.v4()
        ..workoutId = workoutId
        ..proposedSetId = proposedSetId
        ..actualReps = actualReps
        ..actualWeight = actualWeight
        ..startedAt = Int64(endedAt)
        ..endedAt = Int64(endedAt)
        ..restUntil = Int64(endedAt + restSeconds),
    );
  }
}

/// Remove a completed set, returning its proposed set to pending.
void applyLocalDeleteCompletedSet({
  required List<CompletedSet> completedSets,
  required String completedSetId,
}) {
  completedSets.removeWhere((c) => c.id == completedSetId);
}

/// Soft-cancel a warmup. Working sets cannot be skipped.
void applyLocalSkipWarmup({
  required List<ProposedSet> proposedSets,
  required String proposedSetId,
}) {
  final idx = proposedSets.indexWhere((set) => set.id == proposedSetId);
  if (idx == -1) return;
  if (!proposedSets[idx].warmup) return;
  proposedSets[idx].cancelled = true;
}
