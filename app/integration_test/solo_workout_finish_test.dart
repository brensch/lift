// Scenario: the full workout lifecycle — onboard, start the proposed workout,
// log a set, then End workout through the confirm dialog and land on the
// summary. Ending a workout is what drives progression, so this exercises the
// whole loop.

import 'package:schlift/gen/copy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('solo — start, log a set, and finish the workout', (
    tester,
  ) async {
    final s = Scenario(binding, tester, 'solo_workout_finish');

    await s.run(() async {
      await s.launch();
      await s.devLogin('e2e_finish_${DateTime.now().millisecondsSinceEpoch}');
      await s.completeOnboarding();

      // Home → live workout; Start, then Good, logs the first set.
      await s.startWorkoutFromHome();
      await s.liftSet();
      await s.settle(seconds: 2);
      await s.shot('One set logged, mid-workout');

      // End the workout via the confirm dialog (the link under the list).
      await s.tapText('End workout');
      await s.mustSee('This will end your current workout.', seconds: 6);
      await s.shot('End-workout confirm dialog');
      await s.tap(find.text('End Workout').last); // dialog's confirm button

      // Land on the workout summary.
      await s.mustSee('SESSION', seconds: 15);
      await s.shot(
        'Session snapshot',
        note: 'Workout ended; Duration / Volume / Sets and the time tiles.',
      );
      for (final tile in [
        'Duration',
        'Volume',
        'Sets',
        copy.workout.lifting,
        copy.workout.resting,
        copy.workout.yapping,
      ]) {
        expect(
          s.isVisible(tile.toUpperCase()),
          isTrue,
          reason: 'the summary should show the $tile tile',
        );
      }

      s.note(
        'Full workout lifecycle verified',
        detail: 'onboard → start → Start, Good → end → summary',
        kind: 'assert',
      );
    });
  });
}
