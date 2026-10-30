// Scenario: a brand-new user dev-logs in and is routed to onboarding (they have
// no templates or workouts yet). Proves login + the new-user redirect end to end.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schlift/gen/copy.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('solo — new user is routed to onboarding', (tester) async {
    final s = Scenario(binding, tester, 'solo_onboarding');

    await s.run(() async {
      await s.launch();
      s.expectVisible(copy.login.devLogin);
      await s.shot(
        'Cold start — login screen',
        note: 'The real app on the emulator, connected to the backend.',
      );

      final username = 'e2e_onboard_${DateTime.now().millisecondsSinceEpoch}';
      await s.devLogin(username);
      await s.shot(
        'After dev login',
        note: 'Logged in as "$username" (test-auth), a brand-new user.',
      );

      // A user with no templates or workouts must land on onboarding, not home.
      final onboarding = await s.waitForText(
        copy.onboarding.marker.title,
        seconds: 10,
      );
      await s.shot(
        'Landed after login',
        note: onboarding
            ? 'Routed to onboarding as expected for a fresh user.'
            : 'WARNING: did not detect the onboarding screen.',
      );

      expect(
        onboarding,
        isTrue,
        reason: 'a new user with no program should reach onboarding',
      );
      s.note(
        'New-user redirect verified',
        detail: 'Fresh dev-login user reached the onboarding flow.',
        kind: 'assert',
      );
    });
  });
}
