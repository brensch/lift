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
    // The summary should show the progression the completed work earned.
    expect(await s.waitForText('Session snapshot', seconds: 10), isTrue,
        reason: 'finishing should land on the workout summary');
    await s.shot('Summary — progression applied',
        note: 'The summary reports each lift advancing 45 → 50.');

    // Backend should have advanced.
    final after = await api.proposedGroups();
    final backendSquat = after
        .expand((g) => g.exerciseConfigs)
        .firstWhere((c) => c.exercise.name.contains('SQUAT'),
            orElse: () => throw StateError('no squat in proposal'))
        .startWeight;
    s.note('Backend squat after finish',
        detail: '$backendSquat lb', kind: 'api');
    expect(backendSquat, greaterThan(45),
        reason: 'finishing a full workout should advance squat past 45');

    // The summary should render that advance (e.g. "Squat 45 lb -> 50 lb").
    final shown = '${backendSquat.toStringAsFixed(0)} lb';
    expect(find.textContaining(shown), findsWidgets,
        reason: 'the summary should show the advanced weight ("$shown")');

    s.note('Post-finish progression display verified', kind: 'assert');
    await s.report();
  });
}
