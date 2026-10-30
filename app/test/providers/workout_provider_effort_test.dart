/// The exceptions, the effort question and the calibration ramp, driven
/// through the real WorkoutProvider against the fake service. These pin
/// the Dart half of src/workout/reducer.rs (`is_prompt_worthy`,
/// `effort_prompt_from_state`, `apply_edit_completed_set_to_active`,
/// `apply_start_set_to_active`, `record_effort`, `resolve_stale_effort`)
/// to the same answers the Rust tests pin.
library;

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/logic/exercise_prescription.dart';

import '../support/provider_harness.dart';

const endOfExerciseRestSeconds = 60;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderHarness h;

  setUp(() async {
    h = await ProviderHarness.boot();
  });

  tearDown(() => h.dispose());

  int nowSecs() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  /// A squat block (warmup + two working sets) ahead of one bench set, so
  /// "the final working set of an exercise" is observable.
  Future<void> bootWorkout() async {
    await h.seedHome([tracker(Exercise.EXERCISE_SQUAT, weight: 185)]);
    await h.startWorkoutWith([
      set_('s1', Exercise.EXERCISE_SQUAT, order: 0, warmup: true, weight: 45),
      set_('s2', Exercise.EXERCISE_SQUAT, order: 1, weight: 185, reps: 6),
      set_('s3', Exercise.EXERCISE_SQUAT, order: 2, weight: 185, reps: 6),
      set_('b1', Exercise.EXERCISE_BENCH_PRESS, order: 3, weight: 135),
    ]);
  }

  /// A squat rung at [weight] followed by another exercise's set, so the
  /// splice point is observable.
  Future<void> bootRamp({double weight = 45, bool withBench = true}) async {
    await h.seedHome([tracker(Exercise.EXERCISE_SQUAT, weight: 185)]);
    await h.startWorkoutWith([
      rung('c1', Exercise.EXERCISE_SQUAT, order: 0, weight: weight),
      if (withBench)
        set_('b1', Exercise.EXERCISE_BENCH_PRESS, order: 1, weight: 135),
    ]);
  }

  CompletedSet done(String proposedId) => h.provider.activeCompletedSets
      .singleWhere((c) => c.proposedSetId == proposedId);

  List<ProposedSet> squatSets() => h.provider.activeProposedSets
      .where((s) => s.exercise == Exercise.EXERCISE_SQUAT)
      .toList();

  group('the effort prompt', () {
    test('is asked after every working set, never a warmup', () async {
      await bootWorkout();
      await h.provider.completeSet('s1', 5, 45);
      expect(h.provider.effortPrompt, isNull, reason: 'warmups never ask');

      await h.provider.completeSet('s2', 6, 185);
      final prompt = h.provider.effortPrompt;
      expect(prompt, isNotNull, reason: 'a non-final working set asks too');
      expect(prompt!.exercise, Exercise.EXERCISE_SQUAT);
      expect(prompt.completedSetId, done('s2').id);
      expect(prompt.effort, Effort.EFFORT_UNSPECIFIED);
      expect(prompt.calibration, isFalse);
      expect(
        h.provider.stateSnapshot!.state,
        WorkoutState.WORKOUT_STATE_RESTING,
      );
    });

    test('a newer Done moves the question on and closes the old one', () async {
      await bootWorkout();
      await h.provider.completeSet('s2', 6, 185);
      await h.provider.completeSet('s3', 6, 185);
      expect(h.provider.effortPrompt!.completedSetId, done('s3').id);
      expect(
        done('s2').effort,
        Effort.EFFORT_RIGHT,
        reason: 'unanswered at the next Done means right',
      );
    });

    test('the answer can change until the next Done', () async {
      await bootWorkout();
      await h.provider.completeSet('s2', 6, 185);
      final id = done('s2').id;

      await h.provider.rateExercise(id, Effort.EFFORT_HARD);
      expect(h.provider.effortPrompt!.effort, Effort.EFFORT_HARD);
      await h.provider.rateExercise(id, Effort.EFFORT_EASY);
      expect(done('s2').effort, Effort.EFFORT_EASY, reason: 're-rated');
      expect(h.provider.effortPrompt!.effort, Effort.EFFORT_EASY);

      // After the next Done, the old set can no longer be re-rated.
      await h.provider.completeSet('s3', 6, 185);
      await h.provider.rateExercise(id, Effort.EFFORT_HARD);
      expect(done('s2').effort, Effort.EFFORT_EASY);
    });

    test('rating a warmup is a no-op', () async {
      await bootWorkout();
      await h.provider.completeSet('s1', 5, 45);
      await h.provider.rateExercise(done('s1').id, Effort.EFFORT_EASY);
      expect(done('s1').effort, Effort.EFFORT_UNSPECIFIED);
    });

    test('rest ending resolves nothing; it reads yapping', () async {
      await bootWorkout();
      await h.provider.completeSet('s2', 6, 185, completedAt: nowSecs() - 500);
      expect(
        h.provider.stateSnapshot!.state,
        WorkoutState.WORKOUT_STATE_YAPPING,
      );
      expect(
        h.provider.effortPrompt,
        isNotNull,
        reason: 'the question outlives the rest',
      );
      expect(done('s2').effort, Effort.EFFORT_UNSPECIFIED);
      expect(
        h.provider.lastRestEnd,
        done('s2').restUntil,
        reason: 'the yapping count-up runs from here',
      );

      // Other mutations do not resolve it either; only a Done does.
      await h.provider.adjustExerciseWeight(Exercise.EXERCISE_SQUAT, 190);
      expect(done('s2').effort, Effort.EFFORT_UNSPECIFIED);
      await h.provider.completeSet('s3', 6, 190);
      expect(done('s2').effort, Effort.EFFORT_RIGHT);
    });
  });

  // Mirrors the Rust `lifting` tests in src/workout/reducer.rs.
  group('lifting', () {
    test('Start lifts the set until its Done', () async {
      await bootWorkout();
      final startedAt = nowSecs() - 30;
      await h.provider.startSet('s2', startedAt: startedAt);
      final snapshot = h.provider.stateSnapshot!;
      expect(snapshot.state, WorkoutState.WORKOUT_STATE_LIFTING);
      expect(snapshot.displaySet.id, 's2');
      expect(snapshot.liftingStartedAt.toInt(), startedAt);
      expect(snapshot.restUntil, Int64.ZERO, reason: 'no rest while lifting');

      await h.provider.completeSet('s2', 6, 185, effort: Effort.EFFORT_HARD);
      final c = done('s2');
      expect(c.startedAt.toInt(), startedAt, reason: 'the Start is kept');
      expect(c.effort, Effort.EFFORT_HARD, reason: 'rated by the same Done');
      expect(h.provider.effortPrompt!.effort, Effort.EFFORT_HARD);
      expect(h.provider.activeWorkout!.liftingSetId, isEmpty);
      expect(
        h.provider.stateSnapshot!.state,
        WorkoutState.WORKOUT_STATE_RESTING,
      );
    });

    test('starting while resting is lifting', () async {
      await bootWorkout();
      await h.provider.completeSet('s2', 6, 185);
      expect(
        h.provider.stateSnapshot!.state,
        WorkoutState.WORKOUT_STATE_RESTING,
      );
      await h.provider.startSet('s3');
      expect(
        h.provider.stateSnapshot!.state,
        WorkoutState.WORKOUT_STATE_LIFTING,
      );
      expect(
        done('s2').effort,
        Effort.EFFORT_RIGHT,
        reason: 'Start closes the last question unanswered, as Done would',
      );
    });

    test('restarting keeps the first Start; another set moves it', () async {
      await bootWorkout();
      final first = nowSecs() - 40;
      await h.provider.startSet('s2', startedAt: first);
      await h.provider.startSet('s2', startedAt: first + 10);
      expect(h.provider.stateSnapshot!.liftingStartedAt.toInt(), first);

      await h.provider.startSet('s3', startedAt: first + 20);
      final snapshot = h.provider.stateSnapshot!;
      expect(snapshot.displaySet.id, 's3');
      expect(snapshot.liftingStartedAt.toInt(), first + 20);
    });

    test('starting a done or unknown set is a no-op', () async {
      await bootWorkout();
      await h.provider.completeSet('s1', 5, 45);
      await h.provider.startSet('s1');
      await h.provider.startSet('nope');
      expect(h.provider.activeWorkout!.liftingSetId, isEmpty);
      expect(
        h.provider.stateSnapshot!.state,
        isNot(WorkoutState.WORKOUT_STATE_LIFTING),
      );
    });

    test('a Done never started has no start', () async {
      await bootWorkout();
      await h.provider.startSet('s3');
      await h.provider.completeSet('s2', 6, 185);
      expect(done('s2').startedAt, Int64.ZERO);
      expect(
        h.provider.activeWorkout!.liftingSetId,
        isEmpty,
        reason: 'any Done ends the lift',
      );
    });

    test('Start and the rated Done reach the server', () async {
      await bootWorkout();
      await h.provider.startSet('s2');
      await h.provider.completeSet('s2', 6, 185, effort: Effort.EFFORT_EASY);
      await h.settleQueue();
      final sent = h.service.flushedMutations;
      final start = sent.singleWhere((m) => m.hasStartSet()).startSet;
      expect(start.proposedSetId, 's2');
      expect(start.startedAt, isNot(Int64.ZERO));
      final complete = sent.singleWhere((m) => m.hasCompleteSet()).completeSet;
      expect(complete.effort, Effort.EFFORT_EASY);
      expect(
        sent.indexWhere((m) => m.hasStartSet()),
        lessThan(sent.indexWhere((m) => m.hasCompleteSet())),
      );
    });
  });

  // Mirrors the Rust "any set, any order" tests in src/workout/reducer.rs.
  group('warmups are never removed', () {
    test('a working set moves past its warmups', () async {
      await bootWorkout();
      await h.provider.completeSet('s2', 6, 185);
      expect(
        h.provider.doneTargetSet!.id,
        's3',
        reason: 'the warmup left behind is not up next',
      );
      await h.provider.completeSet('s3', 6, 185);
      expect(
        h.provider.doneTargetSet!.id,
        'b1',
        reason: 'and does not keep squat open',
      );
      expect(
        (done('s3').restUntil - done('s3').endedAt).toInt(),
        endOfExerciseRestSeconds,
        reason: 'the last working set rests short',
      );
      expect(h.provider.isSetDone('s1'), isFalse);
      expect(
        h.provider.activeProposedSets.any((p) => p.id == 's1'),
        isTrue,
        reason: 'the warmup is still in the plan',
      );
    });

    test('skipping warmups marks them, keeps them, moves past', () async {
      await bootWorkout();
      await h.provider.skipWarmups(Exercise.EXERCISE_SQUAT);
      final s1 = h.provider.proposedSetById('s1')!;
      expect(s1.skipped, isTrue);
      expect(s1.cancelled, isFalse, reason: 'nothing is removed');
      expect(h.provider.doneTargetSet!.id, 's2', reason: 'the working set');
      await h.provider.completeSet('s1', 5, 45);
      expect(h.provider.isSetDone('s1'), isTrue, reason: 'still doable');
      await h.settleQueue();
      expect(
        h.service.flushedMutations
            .singleWhere((m) => m.hasSkipWarmups())
            .skipWarmups
            .exercise,
        Exercise.EXERCISE_SQUAT,
      );
    });

    test('up next carries on with the exercise in hand', () async {
      await bootWorkout();
      await h.provider.completeSet('b1', 5, 135);
      expect(
        h.provider.doneTargetSet!.id,
        's1',
        reason: 'bench is finished, so back to the first open set',
      );
      await h.provider.completeSet('s2', 6, 185);
      expect(h.provider.doneTargetSet!.id, 's3', reason: 'squat continues');
    });
  });

  group('editCompletedSet', () {
    test(
      'each tap on a done set is a missed rep; past zero undoes it',
      () async {
        await bootWorkout();
        await h.provider.completeSet('s2', 6, 185);
        final id = done('s2').id;
        await h.provider.tapDoneSet(id);
        expect(done('s2').actualReps, 5, reason: 'one short');
        expect(
          (done('s2').restUntil - done('s2').endedAt).toInt(),
          180,
          reason: 'short of the target rests the failure rest',
        );
        for (var i = 0; i < 5; i++) {
          await h.provider.tapDoneSet(id);
        }
        expect(done('s2').actualReps, 0);
        await h.provider.tapDoneSet(id);
        expect(h.provider.isSetDone('s2'), isFalse, reason: 'undone');
        expect(h.provider.doneTargetSet!.id, 's1', reason: 'back in the plan');
      },
    );

    test('a rung short of its target is answered hard', () async {
      await bootRamp(withBench: false);
      await h.provider.completeSet('c1', 3, 45);
      expect(done('c1').effort, Effort.EFFORT_HARD);
      expect(h.provider.effortPrompt!.effort, Effort.EFFORT_HARD);
      expect(
        squatSets()
            .where((s) => !s.calibration)
            .every((s) => s.targetWeight == 45),
        isTrue,
        reason: 'settled at the opener',
      );
    });

    test('tapping a rung below its target re-answers it hard', () async {
      await bootRamp(withBench: false);
      await h.provider.completeSet('c1', 5, 45);
      await h.provider.rateExercise(done('c1').id, Effort.EFFORT_EASY);
      expect(squatSets()[1].calibration, isTrue, reason: 'climbed a rung');
      await h.provider.tapDoneSet(done('c1').id);
      expect(done('c1').effort, Effort.EFFORT_HARD);
      expect(
        squatSets().where((s) => s.calibration),
        hasLength(1),
        reason: 'the climbed rung is taken back',
      );
    });

    test('a done rung stops at zero', () async {
      await bootRamp(withBench: false);
      await h.provider.completeSet('c1', 1, 45);
      final id = done('c1').id;
      await h.provider.tapDoneSet(id);
      await h.provider.tapDoneSet(id);
      expect(done('c1').actualReps, 0, reason: 'still logged');
    });

    test('recomputes the rest from when the set ended', () async {
      await bootWorkout();
      await h.provider.completeSet('s2', 6, 185);
      final c = done('s2');
      expect((c.restUntil - c.endedAt).toInt(), 120, reason: 'success rest');

      await h.provider.editCompletedSet(c.id, 3, 175);
      final edited = done('s2');
      expect(edited.actualReps, 3);
      expect(edited.actualWeight, 175);
      expect(
        (edited.restUntil - edited.endedAt).toInt(),
        180,
        reason: 'fewer reps than planned switches to the failure rest',
      );
      expect(
        h.provider.stateSnapshot!.restUntil,
        edited.restUntil,
        reason: 'the countdown follows the edit',
      );

      await h.settleQueue();
      final edit = h.service.flushedMutations
          .singleWhere((m) => m.hasEditCompletedSet())
          .editCompletedSet;
      expect(edit.completedSetId, c.id);
      expect(edit.actualReps, 3);
      expect(edit.actualWeight, 175);
    });

    test('an unknown set is a no-op', () async {
      await bootWorkout();
      await h.provider.completeSet('s2', 6, 185);
      final before = h.provider.activeCompletedSets
          .map((c) => c.deepCopy())
          .toList();
      await h.provider.editCompletedSet('nope', 3, 185);
      expect(h.provider.activeCompletedSets, before);
    });
  });

  group('the calibration ramp', () {
    test(
      'a rung rests its own 90 s and asks even with nothing pending',
      () async {
        await bootRamp(withBench: false);
        await h.provider.completeSet('c1', 5, 45);
        final c = done('c1');
        expect(
          (c.restUntil - c.endedAt).toInt(),
          90,
          reason: 'not the 60 s end-of-exercise rest: the ramp continues',
        );
        final snapshot = h.provider.stateSnapshot!;
        expect(
          snapshot.state,
          WorkoutState.WORKOUT_STATE_RESTING,
          reason: 'a rung still asking is not the end of the workout',
        );
        expect(snapshot.displaySet.id, appendedSetId(c.id, 0));
        expect(snapshot.restUntil, c.restUntil);
        expect(h.provider.effortPrompt, isNotNull);
        expect(h.provider.effortPrompt!.calibration, isTrue);
      },
    );

    test(
      'an unanswered last rung reads YAPPING once its rest is over',
      () async {
        await bootRamp(withBench: false);
        await h.provider.completeSet('c1', 5, 45, completedAt: nowSecs() - 200);
        final snapshot = h.provider.stateSnapshot!;
        expect(snapshot.state, WorkoutState.WORKOUT_STATE_YAPPING);
        expect(snapshot.displaySet.id, appendedSetId(done('c1').id, 0));
        expect(
          snapshot.restUntil,
          done('c1').restUntil,
          reason: 'yapping counts up from the rung\'s rest end',
        );
      },
    );

    test(
      'with another exercise pending, Done still targets "{done}:0"',
      () async {
        await bootRamp();
        await h.provider.completeSet('c1', 5, 45);
        final wouldBe = appendedSetId(done('c1').id, 0);
        final snapshot = h.provider.stateSnapshot!;
        expect(snapshot.state, WorkoutState.WORKOUT_STATE_RESTING);
        expect(snapshot.displaySet.id, wouldBe, reason: 'not the bench set');
        expect(h.provider.doneTargetSet!.id, wouldBe);
        expect(
          h.provider.nextPendingSet!.id,
          wouldBe,
          reason: 'next-up follows the display set, as on the server',
        );

        await h.provider.completeSet(wouldBe, 6, 45);
        expect(h.provider.isSetDone(wouldBe), isTrue);
        expect(
          h.provider.isSetDone('b1'),
          isFalse,
          reason: 'bench still to do',
        );
        final ids = h.provider.activeProposedSets.map((s) => s.id).toList();
        expect(ids.last, 'b1', reason: 'the squat working sets sit before it');
      },
    );

    test('easy climbs a rung ahead of the next exercise', () async {
      await bootRamp();
      await h.provider.completeSet('c1', 5, 45);
      await h.provider.rateExercise(done('c1').id, Effort.EFFORT_EASY);

      final sets = h.provider.activeProposedSets;
      expect(sets, hasLength(3));
      final next = sets[1];
      expect(next.exercise, Exercise.EXERCISE_SQUAT, reason: 'spliced in');
      expect(
        next.id,
        appendedSetId(done('c1').id, 0),
        reason: 'the id the server mints for this append',
      );
      expect(next.calibration, isTrue);
      expect(next.targetReps, 5);
      expect(next.targetWeight, 50, reason: 'max(45 + 5, 45 × 1.1) snapped');
      expect(next.restAfterSuccess, 90);
      expect(next.restAfterFailure, 90);
      expect(sets[2].id, 'b1');
      expect(
        sets.map((s) => s.workoutOrder),
        List.generate(sets.length, (i) => i),
        reason: 'renumbered',
      );
      expect(done('c1').effort, Effort.EFFORT_EASY);
      expect(h.provider.effortPrompt!.effort, Effort.EFFORT_EASY);
      expect(h.provider.stateSnapshot!.displaySet.id, next.id);
    });

    test('a big rung climbs ten percent', () async {
      await bootRamp(weight: 200);
      await h.provider.completeSet('c1', 5, 200);
      await h.provider.rateExercise(done('c1').id, Effort.EFFORT_EASY);
      expect(h.provider.activeProposedSets[1].targetWeight, 220);
    });

    test('right settles here with the working sets minus one', () async {
      await bootRamp();
      await h.provider.completeSet('c1', 5, 45);
      await h.provider.rateExercise(done('c1').id, Effort.EFFORT_RIGHT);

      final squat = squatSets();
      expect(squat, hasLength(3), reason: 'the rung plus two working sets');
      final working = squat.where((s) => !s.calibration).toList();
      expect(working, hasLength(2));
      expect(working.map((s) => s.id), [
        appendedSetId(done('c1').id, 0),
        appendedSetId(done('c1').id, 1),
      ], reason: 'deterministic ids, in append order');
      for (final set in working) {
        expect(set.targetWeight, 45);
        expect(set.targetReps, 6, reason: 'squat range bottom');
        expect(set.restAfterSuccess, 180);
        expect(set.restAfterFailure, 240);
        expect(set.warmup, isFalse);
      }
      expect(
        h.provider.activeProposedSets[3].id,
        'b1',
        reason: 'other exercises stay behind',
      );
      final snapshot = h.provider.stateSnapshot!;
      expect(snapshot.state, WorkoutState.WORKOUT_STATE_RESTING);
      expect(snapshot.displaySet.id, working.first.id);
    });

    test('hard settles one rung down, or at the opener', () async {
      // Hard on the very first rung: that rung's weight is the weight.
      await bootRamp();
      await h.provider.completeSet('c1', 5, 45);
      await h.provider.rateExercise(done('c1').id, Effort.EFFORT_HARD);
      expect(
        squatSets()
            .where((s) => !s.calibration)
            .every((s) => s.targetWeight == 45),
        isTrue,
      );
    });

    test('easy then hard goes back to the previous rung', () async {
      await bootRamp();
      await h.provider.completeSet('c1', 5, 45);
      await h.provider.rateExercise(done('c1').id, Effort.EFFORT_EASY);
      final rung2 = h.provider.activeProposedSets[1].id;
      await h.provider.completeSet(rung2, 5, 50);
      await h.provider.rateExercise(done(rung2).id, Effort.EFFORT_HARD);

      final working = squatSets().where((s) => !s.calibration).toList();
      expect(working, hasLength(2));
      expect(
        working.every((s) => s.targetWeight == 45),
        isTrue,
        reason: 'back to rung one',
      );
      expect(done(rung2).effort, Effort.EFFORT_HARD, reason: 'kept');
    });

    test('the sixth rung settles whatever the answer', () async {
      await bootRamp();
      var current = 'c1';
      for (var i = 0; i < 5; i++) {
        final set = h.provider.proposedSetById(current)!;
        await h.provider.completeSet(current, 5, set.targetWeight);
        await h.provider.rateExercise(done(current).id, Effort.EFFORT_EASY);
        current = squatSets().last.id;
      }
      expect(squatSets(), hasLength(6), reason: 'five easies built the cap');

      final sixth = h.provider.proposedSetById(current)!;
      await h.provider.completeSet(current, 5, sixth.targetWeight);
      await h.provider.rateExercise(done(current).id, Effort.EFFORT_EASY);
      final squat = squatSets();
      expect(
        squat.where((s) => s.calibration),
        hasLength(6),
        reason: 'no seventh',
      );
      final working = squat.where((s) => !s.calibration).toList();
      expect(working, hasLength(2));
      expect(
        working.every((s) => s.targetWeight == sixth.targetWeight),
        isTrue,
      );
    });

    test('Done on an unanswered rung logs the "{done}:0" set', () async {
      await bootRamp(withBench: false);
      await h.provider.completeSet('c1', 5, 45);
      final rungDone = done('c1').id;
      final target = h.provider.doneTargetSet!;
      expect(
        target.id,
        appendedSetId(rungDone, 0),
        reason: 'the button shows what right would append, before any send',
      );
      expect(target.calibration, isFalse);
      expect((target.targetWeight, target.targetReps), (45, 6));
      expect(squatSets(), hasLength(1), reason: 'nothing appended yet');

      await h.provider.completeSet(
        target.id,
        target.targetReps,
        target.targetWeight,
      );
      expect(done('c1').effort, Effort.EFFORT_RIGHT);
      final working = squatSets().where((s) => !s.calibration).toList();
      expect(working.map((s) => s.id), [
        appendedSetId(rungDone, 0),
        appendedSetId(rungDone, 1),
      ]);
      expect(h.provider.isSetDone(appendedSetId(rungDone, 0)), isTrue);
    });

    test('re-rating a rung swaps what it appended', () async {
      await bootRamp();
      await h.provider.completeSet('c1', 5, 45);
      final rungDone = done('c1').id;
      await h.provider.rateExercise(rungDone, Effort.EFFORT_EASY);
      expect(squatSets(), hasLength(2));
      expect(squatSets()[1].calibration, isTrue);

      await h.provider.rateExercise(rungDone, Effort.EFFORT_RIGHT);
      final squat = squatSets();
      expect(squat, hasLength(3), reason: 'the extra rung is gone');
      expect(squat.where((s) => s.calibration).map((s) => s.id), ['c1']);
      expect(squat.skip(1).map((s) => s.id), [
        appendedSetId(rungDone, 0),
        appendedSetId(rungDone, 1),
      ]);
      expect(squat.skip(1).every((s) => s.targetWeight == 45), isTrue);
      expect(h.provider.activeProposedSets.last.id, 'b1');

      await h.provider.rateExercise(rungDone, Effort.EFFORT_EASY);
      expect(squatSets(), hasLength(2), reason: 'and back again');
      expect(squatSets()[1].targetWeight, 50);
    });

    test('adding a never-performed loaded exercise plans one rung', () async {
      await h.seedHome([
        tracker(Exercise.EXERCISE_SQUAT, weight: 185),
        tracker(Exercise.EXERCISE_BENCH_PRESS, weight: 135, performed: false),
        tracker(Exercise.EXERCISE_PUSH_UP, weight: 0, performed: false),
      ]);
      await h.startWorkoutWith([
        set_('s1', Exercise.EXERCISE_SQUAT, order: 0, weight: 185, reps: 6),
      ]);
      await h.provider.addPrescribedExercises([
        Exercise.EXERCISE_BENCH_PRESS,
        Exercise.EXERCISE_PUSH_UP,
      ]);

      final bench = h.provider.exerciseBlocks
          .singleWhere((b) => b.exercise == Exercise.EXERCISE_BENCH_PRESS)
          .sets;
      expect(bench, hasLength(1));
      expect(bench.single.calibration, isTrue);
      expect(bench.single.targetReps, 5);
      expect(
        bench.single.targetWeight,
        80,
        reason: '60% of the 135 seed, snapped to the bar',
      );
      final pushUps = h.provider.exerciseBlocks
          .singleWhere((b) => b.exercise == Exercise.EXERCISE_PUSH_UP)
          .sets;
      expect(
        pushUps.every((s) => !s.calibration),
        isTrue,
        reason: 'bodyweight never calibrates',
      );

      await h.settleQueue();
      final add = h.service.flushedMutations
          .singleWhere((m) => m.hasAddExercises())
          .addExercises;
      expect(
        add.clientWorkingSetIds.first,
        bench.single.id,
        reason: 'the server hands the rung the first client id',
      );
      expect(add.clientWorkingSetIds, hasLength(1 + pushUps.length));
    });
  });

  group('typed weight during calibration', () {
    test('mid-ramp: the pending rung becomes the full working sets', () async {
      await h.seedHome([tracker(Exercise.EXERCISE_SQUAT, weight: 185)]);
      await h.startWorkoutWith([
        rung('r0', Exercise.EXERCISE_SQUAT, order: 0, weight: 45),
        rung('r1', Exercise.EXERCISE_SQUAT, order: 1, weight: 50),
        set_('b1', Exercise.EXERCISE_BENCH_PRESS, order: 2, weight: 135),
      ]);
      await h.provider.completeSet('r0', 5, 45);
      await h.provider.rateExercise(done('r0').id, Effort.EFFORT_EASY);
      // Easy spliced a fresh rung in after r0, so two rungs are pending;
      // the ids key on the first of them.
      final pendingFirst = squatSets()
          .firstWhere((s) => s.calibration && !h.provider.isSetDone(s.id))
          .id;

      await h.provider.adjustExerciseWeight(Exercise.EXERCISE_SQUAT, 133);
      final squat = squatSets();
      expect(squat.where((s) => s.calibration).map((s) => s.id), ['r0']);
      final working = squat.where((s) => !s.calibration).toList();
      expect(working, hasLength(3), reason: 'the full prescription');
      expect(working.map((s) => s.id), [
        for (var n = 0; n < 3; n++) appendedSetId(pendingFirst, n),
      ]);
      for (final set in working) {
        expect(set.targetWeight, 135, reason: 'snapped to the bar');
        expect(set.targetReps, 6);
        expect((set.restAfterSuccess, set.restAfterFailure), (180, 240));
        expect(set.warmup, isFalse);
      }
      expect(h.provider.activeProposedSets.last.id, 'b1');
      expect(
        h.provider.activeProposedSets.map((s) => s.workoutOrder),
        List.generate(h.provider.activeProposedSets.length, (i) => i),
      );
    });

    test('pins the ids to the pending rung', () async {
      await h.seedHome([tracker(Exercise.EXERCISE_SQUAT, weight: 185)]);
      await h.startWorkoutWith([rung('r1', Exercise.EXERCISE_SQUAT)]);
      await h.provider.adjustExerciseWeight(Exercise.EXERCISE_SQUAT, 135);
      expect(
        squatSets().first.id,
        '0c571b2f-6816-54fa-a80e-f20800527fa9',
        reason: 'uuid5(NAMESPACE_OID, "r1:0")',
      );
    });

    test('an open rung prompt is closed right with nothing appended', () async {
      await h.seedHome([tracker(Exercise.EXERCISE_SQUAT, weight: 185)]);
      await h.startWorkoutWith([
        rung('r0', Exercise.EXERCISE_SQUAT, order: 0, weight: 45),
        rung('r1', Exercise.EXERCISE_SQUAT, order: 1, weight: 50),
      ]);
      await h.provider.completeSet('r0', 5, 45);
      expect(h.provider.effortPrompt, isNotNull);

      await h.provider.adjustExerciseWeight(Exercise.EXERCISE_SQUAT, 135);
      expect(done('r0').effort, Effort.EFFORT_RIGHT);
      expect(
        h.provider.effortPrompt!.effort,
        Effort.EFFORT_RIGHT,
        reason: 'still the latest done set, now answered',
      );
      final squat = squatSets();
      expect(squat, hasLength(4), reason: 'r0 plus three working sets');
      expect(squat.where((s) => s.calibration), hasLength(1));
      expect(
        squat.skip(1).map((s) => s.id),
        [for (var n = 0; n < 3; n++) appendedSetId('r1', n)],
        reason: 'no ramp extension from the closed prompt',
      );
    });

    test(
      'prompt open with no pending rung: ids come from the done rung',
      () async {
        await h.seedHome([tracker(Exercise.EXERCISE_SQUAT, weight: 185)]);
        await h.startWorkoutWith([
          rung('r0', Exercise.EXERCISE_SQUAT, order: 0, weight: 45),
          set_('b1', Exercise.EXERCISE_BENCH_PRESS, order: 1, weight: 135),
        ]);
        await h.provider.completeSet('r0', 5, 45);
        expect(h.provider.effortPrompt?.calibration, isTrue);
        final rungDoneId = done('r0').id;

        await h.provider.adjustExerciseWeight(Exercise.EXERCISE_SQUAT, 135);
        expect(done('r0').effort, Effort.EFFORT_RIGHT);
        expect(
          h.provider.effortPrompt!.effort,
          Effort.EFFORT_RIGHT,
          reason: 'still the latest done set, now answered',
        );
        final squat = squatSets();
        expect(squat, hasLength(4), reason: 'the rung plus three working sets');
        expect(squat.skip(1).map((s) => s.id), [
          for (var n = 0; n < 3; n++) appendedSetId(rungDoneId, n),
        ]);
        expect(squat.skip(1).every((s) => s.targetWeight == 135), isTrue);
        expect(
          h.provider.activeProposedSets.last.id,
          'b1',
          reason: 'spliced in right after the rung',
        );
      },
    );

    test('without a calibration rung the adjust is unchanged', () async {
      await bootWorkout();
      await h.provider.adjustExerciseWeight(Exercise.EXERCISE_SQUAT, 205);
      final byId = {for (final s in h.provider.activeProposedSets) s.id: s};
      expect(byId.keys, ['s1', 's2', 's3', 'b1']);
      expect(byId['s2']!.targetWeight, 205);
      expect(byId['s3']!.targetWeight, 205);
      expect(byId['s1']!.targetWeight, 45);
    });
  });

  test(
    'ending the workout closes every open question without appending',
    () async {
      // A sandbox provider: EndWorkout would otherwise reach the health plugin.
      final sb = await ProviderHarness.boot(sandbox: true);
      await sb.seedHome([tracker(Exercise.EXERCISE_SQUAT, weight: 185)]);
      await sb.startWorkoutWith([rung('c1', Exercise.EXERCISE_SQUAT)]);
      await sb.provider.completeSet('c1', 5, 45);
      expect(sb.provider.effortPrompt, isNotNull);

      await sb.provider.endWorkout(fireEndedCallback: false);
      final c = sb.provider.activeCompletedSets.single;
      expect(c.effort, Effort.EFFORT_RIGHT);
      expect(
        sb.provider.activeProposedSets,
        hasLength(1),
        reason: 'no pending rows on a finished workout',
      );
      expect(sb.provider.activeWorkout!.endTime, isNot(Int64.ZERO));
      sb.dispose();
    },
  );
}
