/// The provider is a view over the core: every action is one call, and
/// what's on screen is the core's answer. These drive it against the real
/// core (in memory) — the rules themselves are tested in Rust
/// (core/tests/api.rs, the reducer and planner tests).
library;

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';

import '../support/provider_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderHarness h;

  setUp(() async {
    h = await ProviderHarness.boot(sandbox: true);
    await h.seedTrackers({
      Exercise.EXERCISE_SQUAT: 185,
      Exercise.EXERCISE_LATERAL_RAISE: 20,
    });
  });

  tearDown(() => h.dispose());

  const squat = Exercise.EXERCISE_SQUAT;
  const raise = Exercise.EXERCISE_LATERAL_RAISE;

  test('a start lays out the prescribed blocks, warmups first', () async {
    await h.start([squat, raise]);
    final p = h.provider;
    expect(p.hasActiveWorkout, isTrue);
    expect(p.exerciseBlocks.map((b) => b.exercise), [squat, raise]);
    expect(h.working(squat).map((s) => s.targetWeight).toSet(), {185.0});
    expect(p.activeProposedSets.first.warmup, isTrue);
    expect(
      p.stateSnapshot!.state,
      WorkoutState.WORKOUT_STATE_READY,
      reason: 'nothing done yet',
    );
  });

  test('start and done: lifting, then resting, the next set up', () async {
    await h.start([raise]);
    final first = h.working(raise).first;
    await h.provider.startSet(first.id);
    expect(h.provider.stateSnapshot!.state, WorkoutState.WORKOUT_STATE_LIFTING);
    await h.provider.completeSet(first.id, 10, 20);
    expect(h.provider.isSetDone(first.id), isTrue);
    expect(h.provider.stateSnapshot!.state, WorkoutState.WORKOUT_STATE_RESTING);
    expect(h.provider.doneTargetSet!.id, h.working(raise)[1].id);
  });

  test('tapping a done set takes a rep off, then undoes it', () async {
    await h.start([raise]);
    final first = h.working(raise).first;
    await h.provider.completeSet(first.id, 1, 20);
    final done = h.provider.activeCompletedSets.single;
    await h.provider.tapDoneSet(done.id);
    expect(h.provider.activeCompletedSets.single.actualReps, 0);
    await h.provider.tapDoneSet(done.id);
    expect(h.provider.activeCompletedSets, isEmpty);
  });

  test('skipping warmups puts them behind you, kept', () async {
    await h.start([squat]);
    final warmups = h.provider.activeProposedSets.where((s) => s.warmup);
    expect(warmups, isNotEmpty);
    await h.provider.skipWarmups(squat);
    expect(warmups.every(h.provider.isPassedWarmup), isTrue);
    expect(h.provider.doneTargetSet!.warmup, isFalse);
  });

  test('ending moves the tracker on and the home shows it', () async {
    await h.start([raise]);
    for (final set in h.working(raise)) {
      await h.provider.completeSet(set.id, 15, set.targetWeight);
    }
    await h.provider.endWorkout(fireEndedCallback: false);
    expect(h.provider.isWorkoutEnded, isTrue);
    expect(h.provider.home!.activeWorkoutId, isEmpty);
    final tracker = h.provider.trackerFor(raise)!;
    expect(tracker.lastPerformedAt, isNot(Int64.ZERO));
    expect(tracker.workingWeight, greaterThan(20), reason: 'topped the range');
  });

  test('the session a workout is in is recorded on it', () async {
    await h.start([raise]);
    await h.provider.recordSession('s1');
    expect(h.provider.activeWorkout!.sessionId, 's1');
  });

  test('an adjusted weight moves the pending sets', () async {
    await h.start([squat]);
    await h.provider.adjustExerciseWeight(squat, 195, targetReps: 7);
    expect(
      h.working(squat).every((s) => s.targetWeight == 195 && s.targetReps == 7),
      isTrue,
    );
  });
}
