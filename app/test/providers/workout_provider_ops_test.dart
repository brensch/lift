/// The optimistic plan ops and the offline queue, driven through the real
/// WorkoutProvider against the fake service. These pin the client half of
/// the semantics the server tests pin in src/server/workout_tests.rs.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';

import '../support/provider_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderHarness h;

  setUp(() async {
    h = await ProviderHarness.boot();
  });

  tearDown(() => h.dispose());

  Future<void> bootWorkout() async {
    await h.seedHome([
      tracker(Exercise.EXERCISE_SQUAT, weight: 185, sets: 3, reps: 6),
      tracker(Exercise.EXERCISE_BENCH_PRESS, weight: 135, sets: 4, reps: 8),
      tracker(Exercise.EXERCISE_BARBELL_CURL, weight: 45, sets: 2, reps: 10),
    ]);
    await h.startWorkoutWith([
      set_('s1', Exercise.EXERCISE_SQUAT, order: 0, warmup: true, weight: 45),
      set_('s2', Exercise.EXERCISE_SQUAT, order: 1, weight: 185, reps: 6),
      set_('s3', Exercise.EXERCISE_SQUAT, order: 2, weight: 185, reps: 6),
    ]);
  }

  group('addPrescribedExercises', () {
    test('builds the block from the tracker and queues matching ids', () async {
      await bootWorkout();
      await h.provider.addPrescribedExercises([Exercise.EXERCISE_BENCH_PRESS]);

      final bench = h.provider.exerciseBlocks
          .where((b) => b.exercise == Exercise.EXERCISE_BENCH_PRESS)
          .toList();
      expect(bench, hasLength(1));
      final sets = bench.single.sets;
      expect(sets, hasLength(4), reason: 'tracker prescribes 4 sets');
      expect(sets.every((s) => s.targetWeight == 135), isTrue);
      expect(sets.every((s) => s.targetReps == 8), isTrue);
      expect(sets.every((s) => !s.warmup), isTrue,
          reason: 'warmups are server-side; the optimistic add has none');

      await h.settleQueue();
      final add = h.service.flushedMutations
          .singleWhere((m) => m.hasAddExercises())
          .addExercises;
      expect(add.exercises, [Exercise.EXERCISE_BENCH_PRESS]);
      expect(add.clientWorkingSetIds, sets.map((s) => s.id).toList(),
          reason: 'the queued ids must be the optimistic set ids, in order');
    });

    test('replaying a queued add over adopted server state never duplicates',
        () async {
      await bootWorkout();
      h.service.failMutations = true; // hold the add in the queue
      await h.provider.addPrescribedExercises([Exercise.EXERCISE_BENCH_PRESS]);
      await h.settleQueue();

      final optimisticIds = h.provider.exerciseBlocks
          .singleWhere((b) => b.exercise == Exercise.EXERCISE_BENCH_PRESS)
          .sets
          .map((s) => s.id)
          .toList();

      // The server applied the add (ack was lost): its state already
      // contains the client ids. Reload + overlay must not double them.
      h.service.workoutResponse = GetWorkoutResponse(
        workout: Workout(id: 'w1', name: 'Test'),
        proposedSets: [
          set_('s1', Exercise.EXERCISE_SQUAT, order: 0, warmup: true, weight: 45),
          set_('s2', Exercise.EXERCISE_SQUAT, order: 1, weight: 185, reps: 6),
          set_('s3', Exercise.EXERCISE_SQUAT, order: 2, weight: 185, reps: 6),
          for (var i = 0; i < optimisticIds.length; i++)
            set_(optimisticIds[i], Exercise.EXERCISE_BENCH_PRESS,
                order: 3 + i, weight: 135),
        ],
      );
      await h.provider.loadWorkoutFromServer('w1');

      final ids = h.provider.activeProposedSets.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length,
          reason: 'no duplicate set ids after overlay replay');
      expect(
        h.provider.activeProposedSets
            .where((s) => s.exercise == Exercise.EXERCISE_BENCH_PRESS)
            .length,
        optimisticIds.length,
      );
    });
  });

  group('adjustExerciseWeight', () {
    test('moves pending working sets, leaves completed and warmups alone',
        () async {
      await bootWorkout();
      await h.provider.completeSet('s2', 6, 185);
      await h.provider.adjustExerciseWeight(Exercise.EXERCISE_SQUAT, 205);

      final byId = {
        for (final s in h.provider.activeProposedSets) s.id: s,
      };
      expect(byId['s1']!.targetWeight, 45, reason: 'warmup untouched locally');
      expect(byId['s2']!.targetWeight, 185, reason: 'completed set untouched');
      expect(byId['s3']!.targetWeight, 205, reason: 'pending set moved');

      await h.settleQueue();
      final adjust = h.service.flushedMutations
          .singleWhere((m) => m.hasAdjustExerciseWeight())
          .adjustExerciseWeight;
      expect(adjust.exercise, Exercise.EXERCISE_SQUAT);
      expect(adjust.workingWeight, 205);
    });
  });

  group('removeExercise', () {
    test('cancels pending sets, keeps completed ones, blocks update', () async {
      await bootWorkout();
      await h.provider.completeSet('s2', 6, 185);
      await h.provider.removeExercise(Exercise.EXERCISE_SQUAT);

      final byId = {
        for (final s in h.provider.activeProposedSets) s.id: s,
      };
      expect(byId['s1']!.cancelled, isTrue, reason: 'pending warmup cancelled');
      expect(byId['s2']!.cancelled, isFalse, reason: 'done work stays');
      expect(byId['s3']!.cancelled, isTrue);

      final squatBlock = h.provider.exerciseBlocks
          .where((b) => b.exercise == Exercise.EXERCISE_SQUAT)
          .toList();
      expect(squatBlock, hasLength(1));
      expect(squatBlock.single.sets.map((s) => s.id), ['s2'],
          reason: 'the derived block keeps only the completed set');
    });
  });

  group('reorderExercises', () {
    test('moves whole blocks and renumbers orders', () async {
      await bootWorkout();
      await h.provider.addPrescribedExercises([Exercise.EXERCISE_BARBELL_CURL]);
      await h.provider.reorderExercises([
        Exercise.EXERCISE_BARBELL_CURL,
        Exercise.EXERCISE_SQUAT,
      ]);

      final blocks = h.provider.exerciseBlocks;
      expect(blocks.first.exercise, Exercise.EXERCISE_BARBELL_CURL);
      final orders =
          h.provider.activeProposedSets.map((s) => s.workoutOrder).toList();
      expect(orders, List.generate(orders.length, (i) => i),
          reason: 'orders renumber 0..n-1');

      await h.settleQueue();
      final reorder = h.service.flushedMutations
          .singleWhere((m) => m.hasReorderExercises())
          .reorderExercises;
      expect(reorder.exercises,
          [Exercise.EXERCISE_BARBELL_CURL, Exercise.EXERCISE_SQUAT]);
    });
  });

  group('offline queue', () {
    test('mutations survive a failed flush and resend in order', () async {
      await bootWorkout();
      h.service.failMutations = true;
      await h.provider.completeSet('s2', 6, 185);
      await h.provider.adjustExerciseWeight(Exercise.EXERCISE_SQUAT, 205);
      await h.settleQueue();
      expect(h.service.flushedMutations, isEmpty, reason: 'still offline');

      h.service.failMutations = false;
      // The provider retries with backoff (2s base) — wait it out.
      await Future<void>.delayed(const Duration(milliseconds: 2600));
      final kinds = h.service.flushedMutations
          .map((m) => m.whichMutation())
          .toList();
      expect(kinds, [
        WorkoutMutation_Mutation.completeSet,
        WorkoutMutation_Mutation.adjustExerciseWeight,
      ]);
    });

    test('the final set of an exercise gets the short local rest', () async {
      await bootWorkout();
      // Complete warmup + first working set, then the exercise's last set.
      await h.provider.completeSet('s1', 5, 45);
      await h.provider.completeSet('s2', 6, 185);
      await h.provider.completeSet('s3', 6, 185);
      final lastDone = h.provider.activeCompletedSets
          .singleWhere((c) => c.proposedSetId == 's3');
      final restSeconds = (lastDone.restUntil - lastDone.endedAt).toInt();
      expect(restSeconds, 60,
          reason: 'end-of-exercise rest, mirroring the server reducer');
    });
  });
}
