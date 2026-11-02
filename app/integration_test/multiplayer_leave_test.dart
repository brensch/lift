// Scenario: a peer joins the app user's session, then the app user leaves it.
// The app should reflect both transitions — count rising to 2, then the session
// clearing back to solo.
//
// The leave is driven from the app user's side (over the API, as the same
// user): `LeaveCurrentSession` clears their session pointer and announces it,
// and the server sends the now-empty session down the app's Sync stream.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('multiplayer — app user leaves, session clears to solo', (
    tester,
  ) async {
    final s = Scenario(binding, tester, 'multiplayer_leave');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final username = 'host_$stamp';

    await s.launch();
    await s.devLogin(username);
    await s.completeOnboarding();

    // Same user over the API, to read the invite token and later leave.
    final host = await s.api.login(username);
    final invite = await host.inviteToken();
    final peer = await s.api.login('peer_$stamp');
    await peer.joinViaInvite(invite);

    final joined = await s.waitForSessionOf(2, seconds: 15);
    await s.shot(
      'Peer joined',
      note: joined ? 'Session shows 2 people.' : 'WARNING: join not seen.',
    );
    expect(joined, isTrue, reason: 'app should show the peer join');

    // The app user leaves; the server sends the empty session down the Sync
    // stream and the app is solo again — the button loses its count.
    await host.leaveSession();
    s.note('App user left the session', kind: 'peer');

    final left = await s.waitForSolo(seconds: 15);
    await s.shot(
      'Left — back to solo',
      note: left
          ? 'Session cleared; the app is solo again.'
          : 'WARNING: leave not reflected.',
    );
    expect(left, isTrue, reason: 'app should reflect the user leaving');

    s.note(
      'Session teardown verified',
      detail: 'The app tracked a peer joining and then the user leaving.',
      kind: 'assert',
    );
    await s.report();
  });
}
