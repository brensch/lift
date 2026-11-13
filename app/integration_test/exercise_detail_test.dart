// Seeds progressive workouts, opens Progress, taps an exercise to open the
// per-lift detail view: the estimated max now, the trend (the max after each
// session with the heaviest set under it), the totals, the records and every
// session by month.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schlift/gen/workout/v1/workout.pbgrpc.dart';
import 'package:schlift/logic/utils.dart';

import 'support/scenario.dart';
import 'package:schlift/theme/app_icons.dart';

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
    await s.waitForAppToCatchUp(api);

    await s.tap(find.byIcon(AppIcons.menu));
    await s.tapText('Progress');
    await s.settle(seconds: 4);
    await s.shot('Progress screen');

    // Open the Squat detail.
    await s.tapText('Squat');
    expect(
      await s.waitForText('estimated max', seconds: 6),
      isTrue,
      reason: 'the exercise detail view should open',
    );
    expect(
      s.isVisible('heaviest set last time'),
      isTrue,
      reason: 'the headline should show the last session beside the max',
    );
    await s.shot('Exercise detail — the max and its trend');

    // The per-session breakdown, under this month's heading: one row per
    // seeded session. The list builds rows as they scroll in, so go to its
    // end, where all five are.
    await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
    await s.settle(seconds: 1);
    expect(
      find.text(monthYear(DateTime.now())),
      findsOneWidget,
      reason: "the sessions sit under this month's heading",
    );
    expect(
      find.textContaining(RegExp(r'^\d+ sets · ')),
      findsNWidgets(5),
      reason: 'every seeded session should have its row',
    );
    await s.shot('Exercise detail — every session');

    s.note('Exercise detail drill-down verified', kind: 'assert');
    await s.report();
  });
}
