// Scenario: throwing workouts away. One under way, from the link under its
// exercises; then a finished one, from its summary opened in History. Each
// asks first, and each is gone afterwards: home is back, History is empty.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/theme/app_icons.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('discard — a workout under way, then a finished one', (
    tester,
  ) async {
    final s = Scenario(binding, tester, 'discard_workout');

    await s.run(() async {
      await s.launch();
      await s.devLogin('discard_${DateTime.now().millisecondsSinceEpoch}');
      await s.completeOnboarding();

      // Under way: a set done, then thrown away.
      await s.startWorkoutFromHome();
      await s.liftSet();
      await s.settle(seconds: 2);
      await s.tapText(copy.workout.discardWorkout);
      await s.mustSee(copy.workout.discardTitle, seconds: 6);
      await s.shot('Discard prompt, mid-workout');
      await s.tap(find.text(copy.workout.discardConfirm).last);
      await s.mustSee(Scenario.homeStart, seconds: 15);
      await s.shot('Home again', note: 'The workout under way is gone.');

      // Finished: ended, then thrown away from its summary in History.
      await s.startWorkoutFromHome();
      await s.liftSet();
      await s.settle(seconds: 2);
      await s.endWorkoutAndWaitForSummary();
      await s.tap(find.byIcon(AppIcons.back));
      await s.settle(seconds: 2);
      await s.tap(find.byIcon(AppIcons.menu));
      await s.tapText('History');
      await s.settle(seconds: 3);
      await s.shot('History: one workout');
      await s.tap(find.textContaining('StrongLifts').first);
      await s.mustSee('SESSION', seconds: 15);
      await s.tapText(copy.workout.discardWorkout);
      await s.mustSee(copy.workout.discardTitle, seconds: 6);
      await s.tap(find.text(copy.workout.discardConfirm).last);
      await s.mustSee('No completed workouts yet', seconds: 15);
      await s.shot('History: empty', note: 'The finished workout is gone.');

      s.note(
        'Discarding verified',
        detail: 'under way → prompt → home; finished → History → prompt → gone',
        kind: 'assert',
      );
    });
  });
}
