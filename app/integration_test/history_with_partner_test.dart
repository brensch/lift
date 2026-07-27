// Feature test: a workout done while paired with a friend shows "with <name>" in
// History — the durable training-together history, surfaced where you browse.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schlift/gen/workout/v1/workout.pbgrpc.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('history — a group workout shows who you trained with',
      (tester) async {
    final s = Scenario(binding, tester, 'history_with_partner');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final username = 'alice_$stamp';

    await s.launch();
    await s.devLogin(username);
    await s.completeOnboarding();

    // Bob joins Alice's invite → both in a session, so Alice's next workout is
    // stamped with that session id. Alice logs a workout via the API.
    final me = await s.api.login(username);
    final invite = await me.inviteToken();
    final bob = await s.api.login('bob_$stamp');
    await bob.joinViaInvite(invite);
    await me.doWorkout('Squat day', [
      MapEntry(Exercise.EXERCISE_SQUAT, 45.0),
    ]);

    // History should list the workout with "with bob_...".
    await s.tap(find.byIcon(Icons.menu));
    await s.tapText('History');
    final sawPartner = await s.waitForText('👥 with bob_$stamp', seconds: 10);
    await s.shot('History shows the training partner',
        note: sawPartner
            ? 'The group workout is tagged with who you trained with.'
            : 'WARNING: partner not shown on the history card.');
    expect(sawPartner, isTrue,
        reason: 'history should show who you trained with on a group workout');

    s.note('Training-together surfaced in history', kind: 'assert');
    await s.report();
  });
}
