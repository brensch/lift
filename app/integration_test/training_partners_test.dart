// Feature test: after the app user trains with a peer, the durable roster records
// them as a training partner — and it survives the peer leaving. Proves the new
// "who did I work out with" history end to end through the real app + backend.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('multiplayer — training-together history is durable',
      (tester) async {
    final s = Scenario(binding, tester, 'training_partners');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final username = 'host_$stamp';

    await s.launch();
    await s.devLogin(username);
    await s.completeOnboarding();

    // A peer joins the app user's session (Model B), then leaves.
    final me = await s.api.login(username);
    final invite = await me.inviteToken();
    final bob = await s.api.login('bob_$stamp');
    await bob.joinViaInvite(invite);
    expect(await s.waitForText('Multiplayer (2)', seconds: 15), isTrue,
        reason: 'app should reflect the peer joining');
    await s.shot('Trained together — peer in session');

    await bob.leaveSession();
    s.note('Peer left the session', kind: 'peer');

    // The durable roster should still list the peer as a training partner — for
    // both users, symmetrically.
    final myPartners = await me.trainingPartners();
    s.note('My training partners',
        detail: myPartners.map((p) => p.user.name).join(', '), kind: 'api');
    expect(myPartners.any((p) => p.user.id == bob.userId), isTrue,
        reason: 'the app user should have the peer as a training partner');
    expect(myPartners.firstWhere((p) => p.user.id == bob.userId).sessionsTogether,
        greaterThanOrEqualTo(1));

    final bobPartners = await bob.trainingPartners();
    expect(bobPartners.any((p) => p.user.id == me.userId), isTrue,
        reason: 'history is symmetric — the peer should also see the app user');

    // Now prove the APP surfaces it: leave the session, then open the multiplayer
    // sheet — the peer should appear under "TRAINED WITH" for a one-tap re-pair.
    await me.leaveSession();
    expect(await s.waitForText('Multiplayer', seconds: 12), isTrue,
        reason: 'app should return to solo after leaving');
    await s.tapText('Multiplayer');
    final sawList = await s.waitForText('TRAINED WITH', seconds: 8);
    await s.shot('Trained-with list in the app',
        note: sawList
            ? 'The peer is offered for a one-tap re-pair.'
            : 'WARNING: the trained-with list did not render.');
    expect(sawList, isTrue,
        reason: 'the multiplayer sheet should show the trained-with list');
    expect(s.isVisible('bob_$stamp'), isTrue,
        reason: 'the peer should be listed as a training partner in the UI');

    s.note('Durable training-partner history verified (backend + UI)',
        kind: 'assert');
    await s.report();
  });
}
