// Bug hunt: after finishing a workout, does the app's home actually show the
// advanced weight? Completes the working sets, ends the workout from the UI, and
// checks that home renders the *new* squat weight (not the stale one).

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('workout — home shows the advanced weight after finishing',
      (tester) async {
    final s = Scenario(binding, tester, 'workout_home_after_finish');
    final username = 'after_${DateTime.now().millisecondsSinceEpoch}';

    await s.launch();
    await s.devLogin(username);
    await s.completeOnboarding();

    final api = await s.api.login(username);
    // Home starts at 45; assert it's showing that before we begin.
    expect(s.isVisible('45 lb'), isTrue,
        reason: 'home should show the starting squat weight');

    // Start in the UI, complete the working sets via API, then finish from the UI.
    await s.tapText('START WORKOUT');
    await s.waitForText('est. time', seconds: 8);
    await s.tap(find.text('START WORKOUT').last);
    expect(await s.waitForText('End Workout', seconds: 10), isTrue);
    await api.adoptActiveWorkout();
    await api.completeAllWorkingSets();

    await s.tapText('End Workout');
    if (await s.waitForText('This will end your current workout.', seconds: 6)) {
      await s.tap(find.text('End Workout').last);
    }
    // From the summary, go back to home.
    await s.waitForText('Session snapshot', seconds: 10);
    if (await s.waitForText('BACK', seconds: 4)) {
      await s.tapText('BACK');
    }
    await s.settle(seconds: 3);

    // Backend should have advanced; the app should render it.
    final after = await api.proposedGroups();
    final backendSquat = after
        .expand((g) => g.exerciseConfigs)
        .firstWhere((c) => c.exercise.name.contains('SQUAT'),
            orElse: () => throw StateError('no squat in proposal'))
        .startWeight;
    s.note('Backend squat after finish',
        detail: '$backendSquat lb', kind: 'api');
    await s.shot('Home after finishing the workout',
        note: 'Backend now proposes $backendSquat lb for squat.');

    expect(backendSquat, greaterThan(45),
        reason: 'finishing a full workout should advance squat past 45');
    // The app's home should show the advanced weight, not the stale 45.
    expect(s.isVisible('${backendSquat.toStringAsFixed(0)} lb'), isTrue,
        reason: 'home should render the advanced weight '
            '(${backendSquat.toStringAsFixed(0)} lb), not a stale value');

    s.note('Post-finish home display verified', kind: 'assert');
    await s.report();
  });
}
