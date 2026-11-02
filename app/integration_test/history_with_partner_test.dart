// Feature test: a workout done while paired with a friend shows "with <name>" in
// History — the durable training-together history, surfaced where you browse.
//
// The workout is the app's own: a phone records its workout's session on the
// account (`SetWorkoutSession`, when the Sync stream reports the session), and
// History asks the server who else was in it. A workout written by another
// client as the same user would carry no session.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schlift/gen/workout/v1/workout.pbgrpc.dart';

import 'support/scenario.dart';
import 'package:schlift/theme/app_icons.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('history — a group workout shows who you trained with', (
    tester,
  ) async {
    final s = Scenario(binding, tester, 'history_with_partner');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final username = 'alice_$stamp';

    await s.launch();
    await s.devLogin(username);
    await s.completeOnboarding();

    // Bob joins Alice's invite → both in a session. Alice then trains in the
    // app, and the workout records the session it was done in.
    final me = await s.api.login(username);
    final invite = await me.inviteToken();
    final bob = await s.api.login('bob_$stamp');
    await bob.joinViaInvite(invite);
    expect(
      await s.waitForSessionOf(2, seconds: 15),
      isTrue,
      reason: 'app should show the partner join',
    );
    final sessionId = s.accountSync.session.sessionId;
    await s.startWorkoutInApp('Squat day', [
      MapEntry(Exercise.EXERCISE_SQUAT, 45.0),
    ]);
    var recorded = false;
    for (var i = 0; i < 20 && !recorded; i++) {
      recorded = s.workout.workout?.sessionId == sessionId;
      if (!recorded) await s.settle(seconds: 1);
    }
    expect(
      recorded,
      isTrue,
      reason: 'the workout should record the session it is trained in',
    );
    await s.finishWorkoutInApp();

    // History should list the workout with "with bob_...".
    await s.tap(find.byIcon(AppIcons.menu));
    await s.tapText('History');
    final sawPartner = await s.waitForTextContaining(
      'with bob_$stamp',
      seconds: 10,
    );
    await s.shot(
      'History shows the training partner',
      note: sawPartner
          ? 'The group workout is tagged with who you trained with.'
          : 'WARNING: partner not shown on the history card.',
    );
    expect(
      sawPartner,
      isTrue,
      reason: 'history should show who you trained with on a group workout',
    );

    s.note('Training-together surfaced in history', kind: 'assert');
    await s.report();
  });
}
