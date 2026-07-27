// Bug hunt: skipping a warmup. The workout bar offers "Skip" on a warmup set;
// tapping it should cancel that set in the backend and move on, not wedge the
// workout.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('workout — skipping a warmup cancels it in the backend',
      (tester) async {
    final s = Scenario(binding, tester, 'skip_warmup');
    final username = 'skip_${DateTime.now().millisecondsSinceEpoch}';

    await s.launch();
    await s.devLogin(username);
    await s.completeOnboarding();

    await s.tapText('START WORKOUT');
    await s.waitForText('est. time', seconds: 8);
    await s.tap(find.text('START WORKOUT').last);
    expect(await s.waitForText('Start Set', seconds: 10), isTrue,
        reason: 'should reach the live workout');

    // Count the warmups the backend has before skipping. (getWorkout drops
    // cancelled sets from the plan, so we assert the count *decreases* rather
    // than looking for a cancelled flag.)
    final api = await s.api.login(username);
    await api.adoptActiveWorkout();
    final before =
        (await api.workoutDetail())?.proposedSets.where((x) => x.warmup).length ??
            0;
    expect(before, greaterThan(0), reason: 'Linear 5x5 opens with warmups');

    // Linear 5x5 opens with warmups, so the bar should offer "Skip".
    expect(await s.waitForText('Skip', seconds: 6), isTrue,
        reason: 'a warmup set should be skippable');
    await s.shot('Warmup set, Skip offered');
    await s.tapText('Skip');
    await s.settle(seconds: 3);
    await s.shot('After skipping a warmup');

    // The skipped warmup drops out of the plan, and the workout stays live.
    final after =
        (await api.workoutDetail())?.proposedSets.where((x) => x.warmup).length ??
            0;
    s.note('Warmups before/after skip', detail: '$before -> $after', kind: 'api');
    expect(after, before - 1,
        reason: 'skipping a warmup should remove exactly one warmup from the plan');
    expect(s.isVisible('Start Set') || s.isVisible('End Workout'), isTrue,
        reason: 'the workout should still be live after skipping');

    s.note('Skip-warmup verified', kind: 'assert');
    await s.report();
  });
}
