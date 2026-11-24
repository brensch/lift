// Bug hunt: a set completed through the UI must actually land in the backend.
// Logs a set in the real app (one tap: Done) and ends the workout (the server
// writes a workout when it ends), then reads the same user's workout over the
// API and asserts the completed set is there — catching any UI↔backend
// desync in the mutation log.

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
      final workoutId = s.workout.workout?.id;
      expect(workoutId, isNotNull, reason: 'a workout is under way');
      await s.liftSet();
      await s.settle(seconds: 3);
      await s.shot('Set completed in the UI');

      // The server writes a workout when it ends: then cross-check against
      // the backend (same user_id as the app).
      await s.endWorkoutAndWaitForSummary();
      final api = await s.api.login(username);
      api.adoptWorkout(workoutId!);
      final detail = await api.endedWorkoutDetail();
      final completed = detail.completedSets.length;
      s.note(
        'Backend workout',
        detail: 'workout=${detail.workout.id}, completedSets=$completed',
        kind: 'api',
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
