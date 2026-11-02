// Bug hunt: after finishing a workout, do the summary and the next plan
// agree? A fresh user's first session calibrates each lift: the starting
// weight is only a guess, the ramp finds the max, and the working sets are
// planned from it. The next plan walks from that session
// (docs/plans/planned-at-start.md). Starts in the UI, fast-forwards every
// set through the app's own account, ends from the UI, and checks the
// summary shows the calibrated weight and the next plan builds on it.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fixnum/fixnum.dart';
import 'package:schlift/gen/workout/v1/workout.pbenum.dart';
import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('workout — summary and next plan agree after finishing', (
    tester,
  ) async {
    final s = Scenario(binding, tester, 'workout_home_after_finish');
    final username = 'after_${DateTime.now().millisecondsSinceEpoch}';

    await s.run(() async {
      await s.launch();
      await s.devLogin(username);
      await s.completeOnboarding();

      final api = await s.api.login(username);
      final before = (await api.planFor(Exercise.EXERCISE_SQUAT))!;
      s.note(
        'Backend squat before',
        detail: '${before.decision.weight} lb ramp (never performed)',
        kind: 'api',
      );

      // Start in the UI, fast-forward every set, then finish from the UI.
      await s.startWorkoutFromHome();
      final completed = await s.completeAllWorkingSetsInApp();
      s.note('Completed in the app', detail: '$completed sets');
      await s.shot('All sets done');

      await s.endWorkoutAndWaitForSummary();
      await s.shot(
        'Summary after the calibrated session',
        note: 'Rungs count as warmups; the working sets carry the weight.',
      );

      // The heaviest working set done is the calibrated weight, as the
      // server holds it.
      await api.adoptActiveWorkout();
      api.workoutId ??= s.workout.workout?.id;
      final detail = (await api.workoutDetail())!;
      final proposedById = {for (final p in detail.proposedSets) p.id: p};
      var calibrated = 0.0;
      for (final c in detail.completedSets) {
        final p = proposedById[c.proposedSetId];
        if (p != null && !p.warmup && !p.calibration) {
          if (c.actualWeight > calibrated) calibrated = c.actualWeight;
        }
      }
      if (calibrated <= 0) {
        throw StateError('no working set was completed after the rung');
      }

      // Backend: the next plan builds on that session: performed, a max,
      // no ramp, and every rep hit means at least that weight again.
      final after = (await api.planFor(Exercise.EXERCISE_SQUAT))!;
      s.note(
        'Backend squat after finish',
        detail:
            '${after.decision.weight} lb × ${after.decision.reps}, '
            'max ${after.decision.max}, '
            'performed=${after.lastPerformedAt > Int64.ZERO}',
        kind: 'api',
      );
      expect(
        after.lastPerformedAt > Int64.ZERO,
        isTrue,
        reason:
            'finishing should mark the lift performed (no more calibration)',
      );
      expect(after.decision.calibration, isFalse);
      expect(after.decision.max, greaterThan(0));
      expect(
        after.decision.weight,
        greaterThanOrEqualTo(calibrated),
        reason:
            'every rep hit: the next plan stays at the calibrated weight or '
            'steps up, not back to the starting weight '
            '(${before.decision.weight})',
      );

      // The summary should render that weight (e.g. "Heaviest set: 110 lb").
      final shown = '${calibrated.toStringAsFixed(0)} lb';
      expect(
        find.textContaining(shown),
        findsWidgets,
        reason: 'the summary should show the calibrated weight ("$shown")',
      );

      s.note('The next plan builds on the calibration', kind: 'assert');
    });
  });
}
