// Scenario: an API-driven peer joins the app user's session, and the real app
// reflects it. This is "Model B" — one real app instance, plus a peer that acts
// purely through the backend. The app can't tell the peer from another phone, so
// this faithfully exercises the multiplayer path with a single emulator.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('multiplayer — an API peer joins the app user\'s session',
      (tester) async {
    final s = Scenario(binding, tester, 'multiplayer_peer');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final username = 'alice_$stamp';

    await s.launch();
    await s.devLogin(username);
    await s.completeOnboarding();
    await s.shot('Home — solo',
        note: 'The app user is on home, not yet in a session.');

    // Log in as the same user over the API to read their (stable) invite token,
    // then bring up a second user — Bob — who joins purely through the backend.
    final alice = await s.api.login(username); // same user_id as the app
    final invite = await alice.inviteToken();
    final bob = await s.api.login('bob_$stamp');
    await bob.joinViaInvite(invite);
    s.note('API peer joined',
        detail: 'Bob joined $username\'s session via their invite token, '
            'entirely through the backend.',
        kind: 'peer');

    // The app polls the session ~1 Hz; the multiplayer button should now show 2.
    final sawPeer = await s.waitForText('Multiplayer (2)', seconds: 15);
    await s.shot('Home — peer detected',
        note: sawPeer
            ? 'The real app now shows a 2-person session.'
            : 'WARNING: the peer was not reflected in the app.');
    expect(sawPeer, isTrue,
        reason: 'the app should reflect the API peer joining the session');

    // Open the multiplayer modal — it lists the session participants.
    await s.tapText('Multiplayer (2)');
    await s.settle(seconds: 2);
    await s.shot('Multiplayer modal',
        note: 'Session participants as the app renders them.');

    s.note('Peer surfaced through the real app UI',
        detail: 'An API-driven peer was detected and displayed by the app.',
        kind: 'assert');
    await s.report();
  });
}
