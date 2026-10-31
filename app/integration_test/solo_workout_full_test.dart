// Scenario: play an ENTIRE workout end to end — start it, then drive every set
// on its circle (tap to start, tap when done, answering each finding-weight
// rung) until the workout is ALL_DONE, then end it. This is the guard for the whole
// live-workout state machine: a workout that never terminates (a set that
// re-opens itself and loops) blows the bounded step budget and fails here, and
// a peer on the same account cross-checks that every set was completed exactly
// once with no duplicate rows.
//
// A fresh user calibrates each loaded lift: one rung, "2–3", and the working
// sets are appended at that weight — so the plan grows as it is played. The
// loop is bounded by actions, not by the opening set count.
//
// Runs inside s.run(), so any failure prints an explicit block (error + last
// step + what's on screen) and a FAILURE screenshot — no log archaeology.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:schlift/gen/workout/v1/workout.pb.dart';

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
      await s.shot('Home — proposed workout');

      // Home → live workout.
      await s.startWorkoutFromHome();
      await s.shot('Workout — first set ready');

      // A peer on the SAME account (TestLogin is deterministic by username) reads
      // the backend as the UI drives it.
      final peer = await s.api.login(username);
      if (!await peer.adoptActiveWorkout()) {
        throw StateError('backend has no active workout after START');
      }

      // Drive the whole workout: each set on its circle, each rung answered
      // 2–3. The loop is
      // BOUNDED so a stuck set (the bug this scenario exists to catch)
      // exhausts the budget and fails instead of hanging the run. Three lifts
      // at five sets plus a rung each is ~18 sets, ~2 actions per set.
      const cap = 120;
      var dones = 0;
      var reachedEnd = false;
      for (var i = 0; i < cap; i++) {
        // Terminal signal is the workout's own state — "End workout" is also
        // a permanent link under the exercise list, so it can't be used.
        if (s.workout.stateSnapshot?.state ==
            WorkoutState.WORKOUT_STATE_ALL_DONE) {
          reachedEnd = true;
          break;
        }
        if (s.setOffered) {
          await s.liftSet();
          dones++;
          if (dones == 1 || dones == 8) {
            await s.shot('Lifted ×$dones');
          }
        }
        await s.settle(seconds: 1);
      }

      if (!reachedEnd) {
        throw StateError(
          'workout never reached ALL_DONE within $cap '
          'actions ($dones sets lifted) — stuck repeating a '
          'set. On screen: ${s.visibleTexts().join(" | ")}',
        );
      }
      await s.shot('All done');

      // Backend truth: every proposed set completed exactly once. Poll briefly
      // so the final set's async flush has landed before we read.
      var proposed = 0;
      var completedRows = 0;
      var distinctDone = 0;
      var neverStarted = 0;
      for (var i = 0; i < 10; i++) {
        final d = await peer.workoutDetail();
        proposed = d!.proposedSets.where((p) => !p.cancelled).length;
        final done = d.completedSets.where((c) => c.endedAt != 0).toList();
        completedRows = done.length;
        neverStarted = done.where((c) => c.startedAt == 0).length;
        distinctDone = done.map((c) => c.proposedSetId).toSet().length;
        if (distinctDone >= proposed) break;
        await s.settle(seconds: 1);
      }
      if (distinctDone != proposed) {
        throw StateError(
          'not every set completed on the backend: '
          '$distinctDone/$proposed distinct done',
        );
      }
      if (completedRows != proposed) {
        throw StateError(
          'duplicate completions: $completedRows rows for '
          '$proposed sets (a set re-opened itself)',
        );
      }
      if (dones != proposed) {
        throw StateError(
          'the UI lifted $dones sets but the backend holds $proposed sets',
        );
      }
      if (neverStarted != 0) {
        throw StateError(
          '$neverStarted completed sets have no start: every set was lifted '
          'through Start, so each should carry its started_at',
        );
      }

      s.note(
        'Full workout completed',
        detail:
            'Lifted all $proposed sets on their circles through the '
            'UI to "All sets complete"; backend holds exactly one completion '
            'per set, each with its start.',
        kind: 'assert',
      );

      // End the workout from the bar and land on the summary.
      await s.endWorkoutAndWaitForSummary();
      await s.shot('Summary after finishing the workout');
    });
  });
}
