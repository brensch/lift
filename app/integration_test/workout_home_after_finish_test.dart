// Bug hunt: after finishing a workout, do the summary and the tracker agree?
// A fresh user's first session calibrates each lift: the onboarding seed is
// only a guess, the rung answered "Right" is the working weight, and that is
// what EndWorkout must write to the tracker (docs/plans/one-tap-sets.md §7).
// Starts in the UI, completes every set via the API peer (rung answered Right,
// then the appended working sets), ends from the UI, and checks the summary
// shows the calibrated weight and the backend tracker now holds it, performed.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:fixnum/fixnum.dart';
import 'package:schlift/gen/workout/v1/workout.pbenum.dart';
import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('workout — summary and tracker agree after finishing', (
    tester,
  ) async {
    final s = Scenario(binding, tester, 'workout_home_after_finish');
    final username = 'after_${DateTime.now().millisecondsSinceEpoch}';

    await s.run(() async {
      await s.launch();
      await s.devLogin(username);
      await s.completeOnboarding();

      final api = await s.api.login(username);
      final before = (await api.trackerFor(Exercise.EXERCISE_SQUAT))!;
      s.note(
        'Backend squat before',
        detail: '${before.workingWeight} lb (never performed)',
        kind: 'api',
      );

      // Start in the UI, complete every set via API, then finish from the UI.
      await s.startWorkoutFromHome();
      await api.adoptActiveWorkout();
      final completed = await api.completeAllWorkingSets();
      s.note('Completed via API', detail: '$completed sets', kind: 'api');
      await s.settle(seconds: 3); // let the app poll the backend's state
      await s.shot('All sets done by the API peer');

      await s.endWorkoutAndWaitForSummary();
      await s.shot(
        'Summary after the calibrated session',
        note: 'Rungs count as warmups; the working sets carry the weight.',
      );

      // The heaviest working set the peer completed is the calibrated weight.
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

      // Backend: the tracker is now that weight, and performed.
      final after = (await api.trackerFor(Exercise.EXERCISE_SQUAT))!;
      s.note(
        'Backend squat after finish',
        detail:
            '${after.workingWeight} lb, performed=${after.lastPerformedAt > Int64.ZERO}',
        kind: 'api',
      );
      expect(
        after.lastPerformedAt > Int64.ZERO,
        isTrue,
        reason:
            'finishing should mark the lift performed (no more calibration)',
      );
      expect(
        after.workingWeight,
        calibrated,
        reason:
            'the tracker should hold the calibrated working weight, not the '
            'onboarding seed (${before.workingWeight})',
      );

      // The summary should render that weight (e.g. "Heaviest set: 110 lb").
      final shown = '${calibrated.toStringAsFixed(0)} lb';
      expect(
        find.textContaining(shown),
        findsWidgets,
        reason: 'the summary should show the calibrated weight ("$shown")',
      );

      s.note('Calibration result landed on the tracker', kind: 'assert');
    });
  });
}
