// Scenario: a peer joins the app user's session, then the app user leaves it.
// The app should reflect both transitions — count rising to 2, then the session
// clearing back to solo.
//
// Note on what this does NOT assert: a *peer* leaving is not observable from the
// app here. `leave_current_session` only clears the leaver's own
// `user_current_session`; it doesn't prune `session_participants_current`, which
// is what other members read — so a departed peer keeps showing until something
// else rewrites that row. We therefore drive the leave from the app user's side,
// which the backend does reflect (their GetCurrentSession returns empty).

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('multiplayer — app user leaves, session clears to solo',
      (tester) async {
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

    final joined = await s.waitForText('Multiplayer (2)', seconds: 15);
    await s.shot('Peer joined',
        note: joined ? 'Session shows 2 people.' : 'WARNING: join not seen.');
    expect(joined, isTrue, reason: 'app should show the peer join');

    // The app user leaves; their GetCurrentSession then returns empty and the
    // app polls back to solo — the button loses its count.
    await host.leaveSession();
    s.note('App user left the session', kind: 'peer');

    final left = await s.waitForText('Multiplayer', seconds: 15) &&
        !s.isVisible('Multiplayer (2)');
    await s.shot('Left — back to solo',
        note: left
            ? 'Session cleared; the app is solo again.'
            : 'WARNING: leave not reflected.');
    expect(left, isTrue, reason: 'app should reflect the user leaving');

    s.note('Session teardown verified',
        detail: 'The app tracked a peer joining and then the user leaving.',
        kind: 'assert');
    await s.report();
  });
}
