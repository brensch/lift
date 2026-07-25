// Bug hunt: completing a full Linear 5×5 workout should advance the weight. Reads
// the proposed squat weight, starts the workout in the app, completes every
// working set through the API (fast), ends it, then checks the *new* proposal —
// both the backend and what the app renders on home.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schlift/gen/workout/v1/workout.pbgrpc.dart';

import 'support/scenario.dart';

double _squatWeight(List<ProposedExerciseGroup> groups) {
  for (final g in groups) {
    for (final c in g.exerciseConfigs) {
      if (c.exercise == Exercise.EXERCISE_SQUAT) return c.startWeight;
    }
  }
  return -1;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('progression — a completed workout advances the weight',
      (tester) async {
    final s = Scenario(binding, tester, 'progression');
    final username = 'prog_${DateTime.now().millisecondsSinceEpoch}';

    await s.launch();
    await s.devLogin(username);
    await s.completeOnboarding();
    await s.shot('Home — before (squat at start weight)');

    final api = await s.api.login(username);
    final before = _squatWeight(await api.proposedGroups());
    s.note('Squat weight before', detail: '$before lb', kind: 'api');
    expect(before, greaterThan(0), reason: 'should have a proposed squat weight');

    // Start the workout in the app so it's created from the real proposal, then
    // complete all working sets + end it through the API.
    await s.tapText('START WORKOUT');
    await s.waitForText('est. time', seconds: 8);
    await s.tap(find.text('START WORKOUT').last);
    expect(await s.waitForText('Start Set', seconds: 10), isTrue);

    expect(await api.adoptActiveWorkout(), isTrue,
        reason: 'backend should expose the app-started workout');
    final completed = await api.completeAllWorkingSets();
    await api.endWorkout();
    s.note('Completed a full workout via API',
        detail: '$completed working sets', kind: 'api');

    // Progression should now show a heavier squat (Linear 5×5 adds to lower body).
    final after = _squatWeight(await api.proposedGroups());
    s.note('Squat weight after', detail: '$after lb', kind: 'api');
    expect(after, greaterThan(before),
        reason: 'a completed workout should increase the squat weight '
            '(before=$before, after=$after)');

    // And the app should render the advanced weight on home.
    await s.settle(seconds: 3);
    await s.shot('Home — after (weight should have advanced)',
        note: 'before=$before, after=$after');

    s.note('Progression verified', kind: 'assert');
    await s.report();
  });
}
