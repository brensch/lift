import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/logic/workout_reducer.dart';

/// Mirrors `src/workout/reducer.rs`'s tests. The app applies these transitions
/// optimistically and the server applies the same ones authoritatively; each
/// behaviour asserted here is asserted on the Rust side too, so a semantic
/// change on either side that isn't mirrored fails one of the two suites.
void main() {
  ProposedSet proposed(String id, int order, {bool warmup = false}) =>
      ProposedSet()
        ..id = id
        ..workoutId = 'w1'
        ..workoutOrder = order
        ..targetReps = 5
        ..targetWeight = 135.0
        ..warmup = warmup
        ..exerciseGroupId = 'g1'
        ..restAfterSuccess = 180
        ..restAfterFailure = 300
        ..cancelled = false;

  group('applyLocalStartSet', () {
    test('opens an in-progress completed set', () {
      final sets = [proposed('s1', 0)];
      final completed = <CompletedSet>[];
      applyLocalStartSet(
        workoutId: 'w1',
        proposedSets: sets,
        completedSets: completed,
        proposedSetId: 's1',
        nowSecs: 2000,
      );
      expect(completed, hasLength(1));
      expect(completed[0].startedAt.toInt(), 2000);
      expect(completed[0].endedAt, Int64.ZERO,
          reason: 'starting a set must not complete it');
    });

    test('is idempotent while the set is in progress', () {
      // The watch delivers intents at-least-once; a duplicate StartSet must
      // not open a second in-progress row.
      final sets = [proposed('s1', 0)];
      final completed = <CompletedSet>[];
      for (final at in [2000, 2050]) {
        applyLocalStartSet(
          workoutId: 'w1',
          proposedSets: sets,
          completedSets: completed,
          proposedSetId: 's1',
          nowSecs: at,
        );
      }
      expect(completed, hasLength(1));
      expect(completed[0].startedAt.toInt(), 2000);
    });

    test('is a no-op for cancelled or unknown sets', () {
      final sets = [proposed('s1', 0, warmup: true)..cancelled = true];
      final completed = <CompletedSet>[];
      for (final id in ['s1', 'nope']) {
        applyLocalStartSet(
          workoutId: 'w1',
          proposedSets: sets,
          completedSets: completed,
          proposedSetId: id,
          nowSecs: 2000,
        );
      }
      expect(completed, isEmpty);
    });
  });

  group('applyLocalCompleteSet', () {
    test('finishes the in-progress row, preserving its start time', () {
      final sets = [proposed('s1', 0), proposed('s2', 1)];
      final completed = <CompletedSet>[];
      applyLocalStartSet(
        workoutId: 'w1',
        proposedSets: sets,
        completedSets: completed,
        proposedSetId: 's1',
        nowSecs: 2000,
      );
      applyLocalCompleteSet(
        workoutId: 'w1',
        proposedSets: sets,
        completedSets: completed,
        proposedSetId: 's1',
        actualReps: 5,
        actualWeight: 135.0,
        nowSecs: 2040,
      );
      expect(completed, hasLength(1));
      expect(completed[0].startedAt.toInt(), 2000);
      expect(completed[0].endedAt.toInt(), 2040);
    });

    test('creates the row directly without a prior start (one-tap)', () {
      final sets = [proposed('s1', 0), proposed('s2', 1)];
      final completed = <CompletedSet>[];
      applyLocalCompleteSet(
        workoutId: 'w1',
        proposedSets: sets,
        completedSets: completed,
        proposedSetId: 's1',
        actualReps: 5,
        actualWeight: 135.0,
        nowSecs: 2040,
      );
      expect(completed, hasLength(1));
      expect(completed[0].endedAt.toInt(), 2040);
    });

    test('rest depends on hitting the target', () {
      for (final (reps, rest) in [(5, 180), (3, 300)]) {
        final sets = [proposed('s1', 0), proposed('s2', 1)];
        final completed = <CompletedSet>[];
        applyLocalCompleteSet(
          workoutId: 'w1',
          proposedSets: sets,
          completedSets: completed,
          proposedSetId: 's1',
          actualReps: reps,
          actualWeight: 135.0,
          nowSecs: 2000,
        );
        expect(completed[0].restUntil.toInt(), 2000 + rest,
            reason: 'reps=$reps');
      }
    });

    test(
        'the final set of a group rests endOfGroupRestSeconds, matching the '
        'server', () {
      final sets = [proposed('s1', 0), proposed('s2', 1)];
      final completed = <CompletedSet>[];
      for (final (id, at) in [('s1', 2000), ('s2', 2300)]) {
        applyLocalCompleteSet(
          workoutId: 'w1',
          proposedSets: sets,
          completedSets: completed,
          proposedSetId: id,
          actualReps: 5,
          actualWeight: 135.0,
          nowSecs: at,
        );
      }
      final last = completed.firstWhere((c) => c.proposedSetId == 's2');
      // Mirrors END_OF_EXERCISE_GROUP_REST_SECONDS in src/workout/mod.rs. The
      // client previously used 10s here, so the rest countdown visibly jumped
      // to 60 when the server's authoritative state arrived.
      expect(endOfGroupRestSeconds, 60);
      expect(last.restUntil.toInt(), 2300 + endOfGroupRestSeconds);
    });

    test('completing a cancelled set is a no-op', () {
      final sets = [
        proposed('s1', 0, warmup: true)..cancelled = true,
        proposed('s2', 1),
      ];
      final completed = <CompletedSet>[];
      applyLocalCompleteSet(
        workoutId: 'w1',
        proposedSets: sets,
        completedSets: completed,
        proposedSetId: 's1',
        actualReps: 5,
        actualWeight: 135.0,
        nowSecs: 2000,
      );
      expect(completed, isEmpty);
    });
  });

  group('delete and skip', () {
    test('deleting a completed set returns it to pending', () {
      final sets = [proposed('s1', 0)];
      final completed = <CompletedSet>[];
      applyLocalCompleteSet(
        workoutId: 'w1',
        proposedSets: sets,
        completedSets: completed,
        proposedSetId: 's1',
        actualReps: 5,
        actualWeight: 135.0,
        nowSecs: 2000,
      );
      applyLocalDeleteCompletedSet(
        completedSets: completed,
        completedSetId: completed[0].id,
      );
      expect(completed, isEmpty);
    });

    test('only warmups can be skipped, and skipping is a soft delete', () {
      final sets = [proposed('w1', 0, warmup: true), proposed('s1', 1)];
      applyLocalSkipWarmup(proposedSets: sets, proposedSetId: 's1');
      expect(sets[1].cancelled, isFalse,
          reason: 'working sets must not be skippable');
      applyLocalSkipWarmup(proposedSets: sets, proposedSetId: 'w1');
      expect(sets[0].cancelled, isTrue);
      expect(sets, hasLength(2), reason: 'the row is retained');
    });
  });
}
