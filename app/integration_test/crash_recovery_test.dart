// Bug hunt: crash recovery. Start a workout, log a set, then cold-restart the
// app. The in-progress workout should come back with the set intact — this is
// the path where state that only lives in memory (the effort prompt, the
// pending rest) is known to be fragile.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('workout — survives a cold restart mid-session', (tester) async {
    final s = Scenario(binding, tester, 'crash_recovery');
    final username = 'crash_${DateTime.now().millisecondsSinceEpoch}';

    await s.run(() async {
      await s.launch();
      await s.devLogin(username);
      await s.completeOnboarding();

      await s.startWorkoutFromHome();
      await s.liftSet();
      await s.settle(seconds: 3);
      await s.shot('Mid-workout, one set logged');

      // Cold restart.
      await s.relaunch();

      // The app should recover into the live workout, not back to home. The
      // "End workout" link under the exercise list is only on the live screen.
      final recovered = await s.waitForText('End workout', seconds: 12);
      await s.shot(
        'After restart',
        note: recovered
            ? 'Recovered into the in-progress workout.'
            : 'WARNING: did not recover the active workout.',
      );
      expect(
        recovered,
        isTrue,
        reason: 'a cold restart should resume the in-progress workout',
      );

      // And the completed set should still be recorded (via the backend).
      final api = await s.api.login(username);
      await api.adoptActiveWorkout();
      final detail = await api.workoutDetail();
      final completed = detail?.completedSets.length ?? 0;
      s.note(
        'Backend after restart',
        detail: 'completedSets=$completed',
        kind: 'api',
      );
      expect(
        completed,
        greaterThanOrEqualTo(1),
        reason: 'the pre-restart set should still be recorded',
      );

      s.note('Crash recovery verified', kind: 'assert');
    });
  });
}
