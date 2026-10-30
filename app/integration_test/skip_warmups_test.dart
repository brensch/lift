// Skipping warmups marks them, it never removes them. Each exercise shows
// its warmups and working sets in two rows; "Skip all warmups" at the end of
// the warmup row marks the undone ones skipped, so the next set is the first
// working set — while every warmup stays in the plan and can still be done.
//
// Premise: the warmup ladder only exists for an exercise that has been
// performed before — a brand-new user's first session calibrates instead
// (docs/plans/one-tap-sets.md §7). So the user's history is seeded through
// the API first (one session of every StrongLifts lift), and the app's next
// session opens with warmups.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schlift/gen/copy.dart';
import 'package:schlift/gen/workout/v1/workout.pbgrpc.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('workout — skipping warmups keeps them, moves past them', (
    tester,
  ) async {
    final s = Scenario(binding, tester, 'skip_warmups');
    final username = 'warm_${DateTime.now().millisecondsSinceEpoch}';

    await s.run(() async {
      await s.launch();
      await s.devLogin(username);
      await s.completeOnboarding();

      // History first: a session of every lift the default templates can
      // prescribe, via the API, so the next session opens with warmups
      // instead of a calibration rung whichever template home suggests.
      final api = await s.api.login(username);
      await api.doWorkout('Seeded session', [
        for (final lift in Scenario.defaultTemplateLifts) MapEntry(lift, 95.0),
      ]);
      if (!await api.hasPerformed(Exercise.EXERCISE_SQUAT)) {
        throw StateError('the seeded session did not mark Squat performed');
      }

      await s.startWorkoutFromHome();
      await api.adoptActiveWorkout();
      final warmupsBefore =
          (await api.workoutDetail())?.proposedSets
              .where((x) => x.warmup)
              .length ??
          0;
      final first = s.nextSet!;
      expect(first.warmup, isTrue, reason: 'a performed lift opens warm');
      await s.shot('Warmups showing');

      // Skip all warmups: up next becomes the first working set.
      await s.tapText(copy.workout.skipWarmups);
      await s.settle(seconds: 2);
      await s.shot('Warmups skipped');
      final next = s.nextSet;
      expect(
        next?.exercise == first.exercise && next?.warmup == false,
        isTrue,
        reason: 'up next is the first working set',
      );

      final detail = await api.workoutDetail();
      final warmups = detail?.proposedSets.where((x) => x.warmup).toList() ?? [];
      expect(warmups.length, warmupsBefore, reason: 'no warmup is removed');
      expect(
        warmups.where((x) => x.exercise == first.exercise).every((x) => x.skipped),
        isTrue,
        reason: "the exercise's undone warmups are marked skipped",
      );

      // A skipped warmup can still be done.
      await s.tap(s.circleFor(first.id));
      await s.tap(s.circleFor(first.id));
      expect(s.workout.isSetDone(first.id), isTrue);

      s.note(
        'Warmups skipped, kept',
        detail:
            '${warmups.length} warmups still in the plan, marked skipped; '
            'one done afterwards anyway.',
        kind: 'assert',
      );
    });
  });
}
