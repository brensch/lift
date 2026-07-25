// Scenario: the full workout lifecycle — onboard, start the proposed workout,
// log a working set, then End Workout through the confirm dialog and land on the
// summary. Ending a workout is what drives the regime's progression, so this
// exercises the whole loop.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('solo — start, log a set, and finish the workout', (tester) async {
    final s = Scenario(binding, tester, 'solo_workout_finish');

    await s.launch();
    await s.devLogin('e2e_finish_${DateTime.now().millisecondsSinceEpoch}');
    await s.completeOnboarding();

    // Home → briefing → live workout.
    await s.tapText('START WORKOUT');
    await s.waitForText('est. time', seconds: 8);
    await s.tap(find.text('START WORKOUT').last);
    expect(await s.waitForText('Start Set', seconds: 10), isTrue,
        reason: 'should reach the live workout');

    // Log the first working set.
    await s.tapText('Start Set');
    await s.settle(seconds: 2);
    expect(await s.waitForText('Complete Set', seconds: 6), isTrue);
    await s.tapText('Complete Set');
    await s.settle(seconds: 2);
    await s.shot('One set logged, mid-workout');

    // End the workout via the confirm dialog.
    await s.tapText('End Workout');
    expect(await s.waitForText('This will end your current workout.', seconds: 6),
        isTrue,
        reason: 'the confirm dialog should appear');
    await s.shot('End-workout confirm dialog');
    await s.tap(find.text('End Workout').last); // dialog's confirm button

    // Land on the workout summary.
    final onSummary = await s.waitForText('Session snapshot', seconds: 12);
    await s.shot('Session snapshot',
        note: onSummary
            ? 'Workout ended; progression runs off the completed work.'
            : 'WARNING: did not reach the summary.');
    expect(onSummary, isTrue, reason: 'ending should land on the summary');

    s.note('Full workout lifecycle verified',
        detail: 'onboard → start → log → end → summary',
        kind: 'assert');
    await s.report();
  });
}
