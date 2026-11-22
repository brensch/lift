// Seeds a few progressive workouts, then captures the Progress (graphs) and
// History screens so their design can be reviewed against real data.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('history + progress — populated views', (tester) async {
    final s = Scenario(binding, tester, 'history_graphs');
    final username = 'hist_${DateTime.now().millisecondsSinceEpoch}';

    await s.launch();
    await s.devLogin(username);
    await s.completeOnboarding();

    // Seed 5 sessions of Squat / Bench / Row climbing over time.
    final api = await s.api.login(username);
    for (var i = 0; i < 5; i++) {
      await api.doWorkout('Workout ${i + 1}', [
        MapEntry('squat', 45 + i * 5.0),
        MapEntry('bench_press', 45 + i * 2.5),
        MapEntry('barbell_row', 45 + i * 5.0),
      ]);
    }
    s.note('Seeded 5 progressive workouts', kind: 'api');

    // Progress (graphs).
    await s.openMenu();
    await s.tapText('Progress');
    await s.settle(seconds: 4);
    await s.shot('Progress screen', note: 'Weight-over-time per exercise.');

    // History.
    await s.openMenu();
    await s.tapText('History');
    await s.settle(seconds: 3);
    await s.shot('History screen', note: 'Past workouts list.');

    await s.report();
  });
}
