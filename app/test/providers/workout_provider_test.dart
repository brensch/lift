/// The provider is a view over the core: every action is one call, and
/// what's on screen is the core's answer. These drive it against the real
/// core (in memory) — the rules themselves are tested in Rust
/// (core/tests/api.rs, the reducer and planner tests).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';

import '../support/provider_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderHarness h;

  setUp(() async {
    h = await ProviderHarness.boot(sandbox: true);
    await h.seedHistory({
      Exercise.EXERCISE_SQUAT: (185, 5),
      Exercise.EXERCISE_LATERAL_RAISE: (20, 10),
    });
  });

  tearDown(() => h.dispose());

  const squat = Exercise.EXERCISE_SQUAT;
  const raise = Exercise.EXERCISE_LATERAL_RAISE;

  test('a start lays out the planned blocks, warmups first', () async {
    await h.start([squat, raise]);
    final p = h.provider;
    expect(p.hasActiveWorkout, isTrue);
    expect(p.exerciseBlocks.map((b) => b.exercise), [squat, raise]);
    // Every rep last time: the same weight, the max nudged up.
    expect(h.working(squat).map((s) => s.targetWeight).toSet(), {185.0});
    final decision = p.logFor(squat)!.decision;
    expect(h.working(squat).map((s) => s.targetReps).toSet(), {decision.reps});
    // Against last time first, then the max's step.
    expect(
      decision.reasons.map((r) => r.kind),
      contains(PlanReasonKind.PLAN_REASON_KIND_MAX_UP),
    );
    expect(decision.budgetMinutes, 60);
    expect(h.working(squat).length, decision.sets);
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

  test('a reorder shows at once, before the core answers', () async {
    await h.start([squat, raise]);
    final done = h.provider.reorderExercises([raise, squat]);
    expect(h.provider.exerciseBlocks.map((b) => b.exercise), [raise, squat]);
    await done;
    expect(h.provider.exerciseBlocks.map((b) => b.exercise), [raise, squat]);
  });

  test('skipping warmups puts them behind you, kept', () async {
    await h.start([squat]);
    final warmups = h.provider.activeProposedSets.where((s) => s.warmup);
    expect(warmups, isNotEmpty);
    await h.provider.skipWarmups(squat);
    expect(warmups.every(h.provider.isPassedWarmup), isTrue);
    expect(h.provider.doneTargetSet!.warmup, isFalse);
  });

  test('ending moves the plan on and the home shows it', () async {
    await h.start([raise]);
    final started = h.provider.planFor(raise)!.lastPerformedAt;
    final maxBefore = h.provider.planFor(raise)!.decision.max;
    for (final set in h.working(raise)) {
      await h.provider.completeSet(set.id, 15, set.targetWeight);
    }
    await h.provider.endWorkout(fireEndedCallback: false);
    expect(h.provider.isWorkoutEnded, isTrue);
    expect(h.provider.home!.activeWorkoutId, isEmpty);
    final plan = h.provider.planFor(raise)!;
    expect(plan.lastPerformedAt, greaterThan(started));
    expect(
      plan.decision.reasons.map((r) => r.kind),
      containsAllInOrder([
        PlanReasonKind.PLAN_REASON_KIND_REPS_UP,
        PlanReasonKind.PLAN_REASON_KIND_MAX_UP,
      ]),
    );
    expect(plan.decision.max, greaterThan(maxBefore), reason: 'every rep hit');
    expect(
      plan.decision.reps,
      16,
      reason: 'past the top, while the next dumbbell is out of reach',
    );
  });

  test('the budget moves in 5-minute steps and plans the home', () async {
    expect(h.provider.budgetMinutes, 60);
    await h.provider.stepBudget(-1);
    expect(h.provider.budgetMinutes, 55);
    expect(h.provider.home!.budgetMinutes, 55);
    await h.start([raise]);
    expect(h.provider.logFor(raise)!.decision.budgetMinutes, 55);
  });

  test('an override is the next plan, and removing it goes back', () async {
    await h.provider.setOverride(exercise: squat, weightLb: 135, reps: 8);
    var plan = h.provider.planFor(squat)!;
    expect(plan.overridden, isTrue);
    expect(plan.decision.weight, 135);
    expect(plan.decision.reps, 8);
    expect(
      plan.decision.reasons.first.kind,
      PlanReasonKind.PLAN_REASON_KIND_USER_SET,
    );
    await h.provider.removeOverride(squat);
    plan = h.provider.planFor(squat)!;
    expect(plan.overridden, isFalse);
    expect(plan.decision.weight, 185);
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

  test('closing the summary keeps the home', () async {
    await h.start([raise]);
    await h.provider.endWorkout(fireEndedCallback: false);
    await h.provider.dismissEndedWorkout();
    expect(h.provider.workout, isNull);
    expect(h.provider.home, isNotNull, reason: 'home has something to show');
  });
}
