// Feature test: request → approve to train together. A prior partner asks the
// app user to train; the app surfaces an approve/decline banner; approving pairs
// them into a session. Proves the consent handshake end to end.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('multiplayer — a train-together request must be approved',
      (tester) async {
    final s = Scenario(binding, tester, 'join_request');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final username = 'alice_$stamp';

    await s.launch();
    await s.devLogin(username);
    await s.completeOnboarding();

    // Establish a prior pairing (required to request): Bob joins Alice's invite,
    // then both leave so they're solo again.
    final me = await s.api.login(username);
    final invite = await me.inviteToken();
    final bob = await s.api.login('bob_$stamp');
    await bob.joinViaInvite(invite);
    expect(await s.waitForText('Multiplayer (2)', seconds: 15), isTrue);
    await bob.leaveSession();
    await me.leaveSession();
    expect(await s.waitForText('Multiplayer', seconds: 12), isTrue,
        reason: 'app should return to solo');

    // Bob asks Alice to train. Alice's app polls it and shows the request banner.
    await bob.requestJoinPartner(me.userId);
    final sawBanner = await s.waitForText('Accept', seconds: 15);
    await s.shot('Incoming train-together request',
        note: sawBanner
            ? 'Banner prompts the recipient to approve or decline.'
            : 'WARNING: request banner did not appear.');
    expect(sawBanner, isTrue,
        reason: 'the recipient should see the approve/decline banner');

    // Approve → both land in a session.
    await s.tapText('Accept');
    final paired = await s.waitForText('Multiplayer (2)', seconds: 15);
    await s.shot('Approved — now training together',
        note: paired ? 'Both are in the session.' : 'WARNING: not paired.');
    expect(paired, isTrue,
        reason: 'approving the request should pair both into a session');

    s.note('Request/approve pairing verified', kind: 'assert');
    await s.report();
  });
}
