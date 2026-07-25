// Bug hunt: crash recovery. Start a workout, log a set, then cold-restart the
// app. The in-progress workout should come back with the set intact — this is
// the path where in-memory-only fields (AMRAP markers, regime instructions) are
// known to be fragile.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('workout — survives a cold restart mid-session', (tester) async {
    final s = Scenario(binding, tester, 'crash_recovery');
    final username = 'crash_${DateTime.now().millisecondsSinceEpoch}';

    await s.launch();
    await s.devLogin(username);
    await s.completeOnboarding();

    await s.tapText('START WORKOUT');
    await s.waitForText('est. time', seconds: 8);
    await s.tap(find.text('START WORKOUT').last);
    expect(await s.waitForText('Start Set', seconds: 10), isTrue);
    await s.tapText('Start Set');
    await s.settle(seconds: 2);
    await s.tapText('Complete Set');
    await s.settle(seconds: 3);
    await s.shot('Mid-workout, one set logged');

    // Cold restart.
    await s.relaunch();
    // Dismiss the passkey notice if the fresh launch shows it again.
    if (await s.waitForText('I understand', seconds: 4)) {
      await s.tapText('I understand');
      await s.settle(seconds: 2);
    }

    // The app should recover into the live workout, not back to home/onboarding.
    final recovered = await s.waitForText('End Workout', seconds: 12);
    await s.shot('After restart',
        note: recovered
            ? 'Recovered into the in-progress workout.'
            : 'WARNING: did not recover the active workout.');
    expect(recovered, isTrue,
        reason: 'a cold restart should resume the in-progress workout');

    // And the completed set should still be recorded (via the backend).
    final api = await s.api.login(username);
    await api.adoptActiveWorkout();
    final detail = await api.workoutDetail();
    final completed = detail?.completedSets.length ?? 0;
    s.note('Backend after restart',
        detail: 'completedSets=$completed', kind: 'api');
    expect(completed, greaterThanOrEqualTo(1),
        reason: 'the pre-restart set should still be recorded');

    s.note('Crash recovery verified', kind: 'assert');
    await s.report();
  });
}
