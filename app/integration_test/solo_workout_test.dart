// Scenario: a set-up user starts their proposed workout and lifts the first
// sets on their circles — tap to start (lifting), tap when done (resting),
// once more per missed rep. Captures the flow.
//
// A brand-new user's first session of a loaded exercise opens with a
// calibration rung ("Finding weight"), not warmups + working sets: one
// 5-rep set, then its rating decides the working weight
// (docs/plans/one-tap-sets.md §7). This scenario answers 2–3 reps left.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('solo — start a workout and log a set', (tester) async {
    final s = Scenario(binding, tester, 'solo_workout');

    await s.run(() async {
      await s.launch();
      await s.devLogin('e2e_workout_${DateTime.now().millisecondsSinceEpoch}');
      await s.completeOnboarding();
      await s.shot(
        'Home — proposed workout',
        note: 'StrongLifts A: Squat / Bench / Row, the plan from the trackers.',
      );

      // Home → live workout (no briefing: START opens the bar directly).
      await s.startWorkoutFromHome();
      final first = s.nextSet!;
      await s.shot(
        'Workout — first set ready',
        note: first.calibration
            ? 'First session of Squat: a finding-weight rung, its circle up next.'
            : 'WARNING: expected the calibration rung on a fresh user.',
      );
      expect(
        first.calibration,
        isTrue,
        reason: 'a fresh user calibrates first',
      );

      // The first tap on the up-next circle starts the set: LIFTING, the
      // banner counting up.
      await s.tap(s.circleFor(first.id));
      final lifting =
          s.workout.stateSnapshot?.state ==
              WorkoutState.WORKOUT_STATE_LIFTING &&
          s.isVisible(copy.workout.lifting);
      await s.shot(
        'Started — lifting',
        note: lifting
            ? 'The circle pulses orange; the banner reads Lifting.'
            : 'WARNING: the first tap did not put the set into Lifting.',
      );
      expect(lifting, isTrue, reason: 'the first tap lifts the set');

      // The second tap logs it with every rep; the rung then asks how many
      // were left, and 2–3 settles the working weight.
      await s.tap(s.circleFor(first.id));
      expect(s.workout.isSetDone(first.id), isTrue, reason: 'logged');
      await s.mustSee(copy.workout.repsLeftQuestion, seconds: 4);
      await s.shot('Rung logged — how many were left?');
      await s.tapText(copy.workout.repsLeftSome);
      expect(
        s.workout.activeProposedSets.where(
          (p) => p.exercise == first.exercise && !p.calibration && !p.warmup,
        ),
        isNotEmpty,
        reason: 'the working sets are appended',
      );
      expect(
        s.workout.stateSnapshot?.state,
        WorkoutState.WORKOUT_STATE_RESTING,
        reason: 'a logged set rests',
      );
      await s.shot('Answered 2–3 — resting, working sets appended');

      // A working set one rep short: start, done, one more tap.
      final working = s.nextSet!;
      await s.liftSet(missed: 1);
      final logged = s.workout.activeCompletedSets.singleWhere(
        (c) => c.proposedSetId == working.id,
      );
      expect(
        logged.actualReps,
        working.targetReps - 1,
        reason: 'each extra tap is a missed rep',
      );
      await s.shot('First working set, one rep short');

      s.note(
        'Workout logging verified',
        detail:
            'Started a proposed workout, lifted the finding-weight rung on its '
            'circle and answered 2–3, then lifted a working set one rep short, '
            'all through the real UI.',
        kind: 'assert',
      );
    });
  });
}
