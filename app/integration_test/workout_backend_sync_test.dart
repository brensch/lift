// Bug hunt: a set completed through the UI must actually land in the backend.
// Logs a set in the real app (one tap: Done), then reads the same user's active
// workout over the API and asserts the completed set is there — catching any
// UI↔backend desync in the mutation log.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('workout — a UI-logged set persists to the backend', (
    tester,
  ) async {
    final s = Scenario(binding, tester, 'workout_backend_sync');
    final username = 'sync_${DateTime.now().millisecondsSinceEpoch}';

    await s.run(() async {
      await s.launch();
      await s.devLogin(username);
      await s.completeOnboarding();

      await s.startWorkoutFromHome();
      await s.liftSet();
      await s.settle(seconds: 3);
      await s.shot('Set completed in the UI');

      // Cross-check against the backend (same user_id as the app).
      final api = await s.api.login(username);
      final hasWorkout = await api.adoptActiveWorkout();
      final detail = await api.workoutDetail();
      final completed = detail?.completedSets.length ?? 0;
      s.note(
        'Backend active workout',
        detail:
            'workout=${detail?.workout.id ?? "none"}, '
            'completedSets=$completed',
        kind: 'api',
      );

      expect(
        hasWorkout,
        isTrue,
        reason: 'the backend should have an active workout for this user',
      );
      expect(
        completed,
        greaterThanOrEqualTo(1),
        reason:
            'the set completed in the UI should be persisted in the backend',
      );

      s.note('UI→backend sync verified', kind: 'assert');
    });
  });
}
