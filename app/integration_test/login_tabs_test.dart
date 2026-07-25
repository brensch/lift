// Scenario: the login screen's two tabs. A fast, backend-light UI check that the
// NEW USER and SIGN IN tabs render their expected content.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login — NEW USER and SIGN IN tabs', (tester) async {
    final s = Scenario(binding, tester, 'login_tabs');

    await s.launch();
    // NEW USER tab is the default.
    expect(await s.waitForText('What should we call you', seconds: 6), isTrue,
        reason: 'NEW USER tab should be shown first');
    await s.shot('NEW USER tab', note: 'Username entry + create account.');

    // Switch to SIGN IN.
    await s.tapText('SIGN IN');
    final onSignIn = await s.waitForText(
        'Use a passkey on your device to sign in securely.',
        seconds: 6);
    await s.shot('SIGN IN tab',
        note: onSignIn ? 'Passkey sign-in.' : 'WARNING: sign-in copy missing.');
    expect(onSignIn, isTrue, reason: 'SIGN IN tab should show the passkey copy');

    s.note('Login tabs verified', kind: 'assert');
    await s.report();
  });
}
