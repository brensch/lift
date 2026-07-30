// Scenario: play an ENTIRE workout end to end — start it, then drive every set
// (warmups + working sets, AMRAP and all) through the real bar controls until the
// bar reads "All sets complete", then end it. This is the guard for the whole
// live-workout state machine: a workout that never terminates (a set that
// re-opens itself and loops) blows the bounded step budget and fails here, and a
// peer on the same account cross-checks that every set was completed exactly once
// with no duplicate rows.
//
// Runs inside s.run(), so any failure prints an explicit block (error + last step
// + what's on screen) and a FAILURE screenshot — no log archaeology.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('solo — play an entire workout to completion', (tester) async {
    final s = Scenario(binding, tester, 'solo_workout_full');
    final username = 'e2e_full_${DateTime.now().millisecondsSinceEpoch}';

    await s.run(() async {
      await s.launch();
      await s.devLogin(username);
      await s.completeOnboarding();
      await s.mustSee('START WORKOUT', seconds: 6);
      await s.shot('Home — proposed workout');

      // Home → briefing → live workout.
      await s.tapText('START WORKOUT');
      await s.mustSee('est. time', seconds: 8);
      await s.shot('Briefing — warmups & working sets');
      await s.tap(find.text('START WORKOUT').last);
      await s.mustSee('Start Set', seconds: 10);
      await s.shot('Workout — first set ready');

      // A peer on the SAME account (TestLogin is deterministic by username) reads
      // the backend as the UI drives it.
      final peer = await s.api.login(username);
      if (!await peer.adoptActiveWorkout()) {
        throw StateError('backend has no active workout after Start Workout');
      }
      final startDetail = await peer.workoutDetail();
      final totalSets =
          startDetail!.proposedSets.where((p) => !p.cancelled).length;
      if (totalSets <= 1) {
        throw StateError('expected a multi-set workout, got $totalSets sets');
      }

      // Drive the whole workout. Each set is start + complete; between sets we
      // "Start Early" to skip the rest wait. The loop is BOUNDED — roughly three
      // actions per set — so a stuck set (the bug this scenario exists to catch)
      // exhausts the budget and fails instead of hanging the run.
      final cap = totalSets * 3 + 12;
      var completes = 0;
      var reachedEnd = false;
      for (var i = 0; i < cap; i++) {
        // Terminal signal is the bottom bar's "All sets complete" label ONLY —
        // "End Workout" is also a permanent button in the exercise-list panel,
        // so it can't be used to detect completion.
        if (s.isVisible('All sets complete')) {
          reachedEnd = true;
          break;
        }
        if (s.isVisible('Complete Set')) {
          await s.tapText('Complete Set');
          completes++;
          if (completes == 1 || completes == totalSets ~/ 2) {
            await s.shot('Completed $completes of $totalSets sets');
          }
        } else if (s.isVisible('Start Set')) {
          await s.tapText('Start Set');
        } else if (s.isVisible('Start Early')) {
          await s.tapText('Start Early');
        }
        await s.settle(seconds: 1);
      }

      if (!reachedEnd) {
        throw StateError('workout never reached "All sets complete" within $cap '
            'steps ($completes completes of $totalSets sets) — stuck repeating a '
            'set. On screen: ${s.visibleTexts().join(" | ")}');
      }
      await s.shot('All sets complete');

      // Backend truth: every proposed set completed exactly once. The last-set
      // loop produced 33 completion rows for 23 sets; this catches that directly.
      // Poll briefly so the final set's async flush has landed before we read.
      var proposed = 0;
      var completedRows = 0;
      var distinctDone = 0;
      for (var i = 0; i < 10; i++) {
        final d = await peer.workoutDetail();
        proposed = d!.proposedSets.where((p) => !p.cancelled).length;
        final done = d.completedSets.where((c) => c.endedAt != 0).toList();
        completedRows = done.length;
        distinctDone = done.map((c) => c.proposedSetId).toSet().length;
        if (distinctDone >= proposed) break;
        await s.settle(seconds: 1);
      }
      if (distinctDone != proposed) {
        throw StateError('not every set completed on the backend: '
            '$distinctDone/$proposed distinct done');
      }
      if (completedRows != proposed) {
        throw StateError('duplicate completions: $completedRows rows for '
            '$proposed sets (a set re-opened itself)');
      }

      s.note('Full workout completed',
          detail: 'Played all $proposed sets through the UI to "All sets '
              'complete"; backend holds exactly one completion per set.',
          kind: 'assert');

      // End the workout and land back home.
      await s.tapText('End Workout');
      await s.settle(seconds: 3);
      await s.shot('Home after finishing the workout');
    });
  });
}
