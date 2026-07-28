// Seeds progressive workouts, opens Progress, taps an exercise to open the new
// per-lift detail view, and toggles Top-weight -> Est. 1RM.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schlift/gen/workout/v1/workout.pbgrpc.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('progress — exercise detail drill-down', (tester) async {
    final s = Scenario(binding, tester, 'exercise_detail');
    final username = 'exdet_${DateTime.now().millisecondsSinceEpoch}';

    await s.launch();
    await s.devLogin(username);
    await s.completeOnboarding();

    // Seed 5 climbing Squat sessions so the trend + est-1RM have data.
    final api = await s.api.login(username);
    for (var i = 0; i < 5; i++) {
      await api.doWorkout('Workout ${i + 1}', [
        MapEntry(Exercise.EXERCISE_SQUAT, 45 + i * 5.0),
        MapEntry(Exercise.EXERCISE_BENCH_PRESS, 45 + i * 2.5),
      ]);
    }
    s.note('Seeded 5 progressive workouts', kind: 'api');

    await s.tap(find.byIcon(Icons.menu));
    await s.tapText('Progress');
    await s.settle(seconds: 4);
    await s.shot('Progress screen');

    // Open the Squat detail.
    await s.tapText('Squat');
    expect(await s.waitForText('best est. 1RM', seconds: 6), isTrue,
        reason: 'the exercise detail view should open');
    expect(s.isVisible('EVERY SESSION'), isTrue,
        reason: 'the per-session breakdown should render');
    await s.shot('Exercise detail — top weight trend');

    // Toggle to the estimated-1RM trend.
    await s.tapText('Est. 1RM');
    await s.settle(seconds: 2);
    await s.shot('Exercise detail — est. 1RM trend');

    s.note('Exercise detail drill-down verified', kind: 'assert');
    await s.report();
  });
}
