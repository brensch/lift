// Scenario: a new user walks the entire onboarding flow — marker, units,
// program, starting weights, confirm — and lands on the home screen ready to
// train. Captures every step.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('solo — full onboarding to home', (tester) async {
    final s = Scenario(binding, tester, 'solo_onboarding_full');

    await s.launch();
    await s.devLogin('e2e_full_${DateTime.now().millisecondsSinceEpoch}');

    // Step 1 — marker (colour + creature). Defaults are valid, so just advance.
    expect(await s.waitForText('Choose your colour and creature', seconds: 10),
        isTrue,
        reason: 'onboarding should open on the marker step');
    await s.shot('Onboarding 1/5 — pick your marker');
    await s.tapText('NEXT');

    // Step 2 — units.
    expect(await s.waitForText('CHOOSE YOUR UNITS', seconds: 6), isTrue);
    await s.shot('Onboarding 2/5 — units');
    await s.tapText('NEXT');

    // Step 3 — program.
    expect(await s.waitForText('CHOOSE YOUR PROGRAM', seconds: 6), isTrue);
    await s.shot('Onboarding 3/5 — program', note: 'Defaults to Linear 5×5.');
    await s.tapText('NEXT');

    // Step 4 — starting weights (regime defaults are pre-filled).
    expect(await s.waitForText('Choose starting weights', seconds: 6), isTrue);
    await s.shot('Onboarding 4/5 — starting weights');
    await s.tapText('NEXT');

    // Step 5 — confirm, then commit with START.
    await s.settle(seconds: 2);
    await s.shot('Onboarding 5/5 — confirm');
    await s.tapText('START');

    // Landed on home, ready to train.
    final onHome = await s.waitForText('START WORKOUT', seconds: 12);
    await s.shot('Home — ready to train',
        note: onHome
            ? 'Onboarding persisted a program; home offers START WORKOUT.'
            : 'WARNING: did not reach the home screen.');
    expect(onHome, isTrue, reason: 'onboarding should land on home');

    s.note('Onboarding completed end to end',
        detail: 'marker → units → program → weights → confirm → home',
        kind: 'assert');
    await s.report();
  });
}
