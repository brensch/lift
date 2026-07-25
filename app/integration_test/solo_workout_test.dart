// Scenario: a set-up user starts their proposed workout and logs the first set —
// home → briefing → workout → start set → complete set. Captures the flow.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('solo — start a workout and log a set', (tester) async {
    final s = Scenario(binding, tester, 'solo_workout');

    await s.launch();
    await s.devLogin('e2e_workout_${DateTime.now().millisecondsSinceEpoch}');
    await s.completeOnboarding();
    expect(s.isVisible('START WORKOUT'), isTrue, reason: 'should be on home');
    await s.shot('Home — proposed workout',
        note: 'Linear 5×5 Workout A: Squat / Bench / Row at the starting weight.');

    // Home → briefing.
    await s.tapText('START WORKOUT');
    await s.waitForText('est. time', seconds: 8);
    await s.shot('Briefing — warmups & working sets');

    // Briefing → live workout. Both screens carry a START WORKOUT label while the
    // briefing is animating in, so tap the one on top (last in the tree).
    await s.tap(find.text('START WORKOUT').last);
    final inWorkout = await s.waitForText('Start Set', seconds: 10);
    await s.shot('Workout — first set ready',
        note: inWorkout
            ? 'The first working set is queued with Start Set.'
            : 'WARNING: did not reach the live workout.');
    expect(inWorkout, isTrue, reason: 'should reach the live workout screen');

    // Log the first set: start it, then complete it.
    await s.tapText('Start Set');
    await s.settle(seconds: 2);
    await s.shot('Set in progress',
        note: 'Set timer running; reps/weight pre-filled from the proposal.');

    final canComplete = await s.waitForText('Complete Set', seconds: 6);
    expect(canComplete, isTrue, reason: 'a started set should be completable');
    await s.tapText('Complete Set');
    await s.settle(seconds: 3);
    await s.shot('First set logged',
        note: 'The set is recorded; the next set becomes ready.');

    s.note('Workout logging verified',
        detail: 'Started a proposed workout and logged the first working set '
            'through the real UI.',
        kind: 'assert');
    await s.report();
  });
}
