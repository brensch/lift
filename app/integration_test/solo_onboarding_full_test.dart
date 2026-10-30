// Scenario: a new user walks the entire onboarding flow — marker, unit,
// strength, bodyweight, templates — and lands on the home screen ready to
// train. Captures every step.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schlift/gen/copy.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('solo — full onboarding to home', (tester) async {
    final s = Scenario(binding, tester, 'solo_onboarding_full');
    final o = copy.onboarding;

    await s.run(() async {
      await s.launch();
      await s.devLogin('e2e_full_${DateTime.now().millisecondsSinceEpoch}');

      // Step 1 — marker (emoji + colour). Defaults are valid, so just advance.
      await s.mustSee(o.marker.title, seconds: 10);
      await s.shot('Onboarding 1/5 — pick your marker');
      await s.tapText(o.next);

      // Step 2 — unit.
      await s.mustSee(o.unit.title, seconds: 6);
      await s.shot('Onboarding 2/5 — unit');
      await s.tapText(o.next);

      // Step 3 — strength slider (seeds the starting weights).
      await s.mustSee(o.strength.title, seconds: 6);
      await s.shot('Onboarding 3/5 — how huge are you');
      await s.tapText(o.next);

      // Step 4 — bodyweight (optional).
      await s.mustSee(o.weight.field, seconds: 6);
      await s.shot('Onboarding 4/5 — bodyweight');
      await s.tapText(o.next);

      // Step 5 — favourite workouts from the library (the defaults come
      // pre-ticked), then commit.
      await s.mustSee(o.templates.title, seconds: 6);
      await s.mustSee(Scenario.defaultTemplateName, seconds: 10);
      await s.shot('Onboarding 5/5 — favourite workouts');
      await s.tapText(o.templates.finish);

      // Landed on home (past the first-run tutorial), ready to train.
      await s.skipTutorial();
      final onHome = await s.waitForText(Scenario.homeStart, seconds: 12);
      await s.shot(
        'Home — ready to train',
        note: onHome
            ? 'Onboarding persisted the template; home offers START.'
            : 'WARNING: did not reach the home screen.',
      );
      expect(onHome, isTrue, reason: 'onboarding should land on home');
      expect(
        s.isVisible(Scenario.defaultTemplateName),
        isTrue,
        reason: 'the picked template should be on home',
      );

      s.note(
        'Onboarding completed end to end',
        detail: 'marker → unit → strength → bodyweight → templates → home',
        kind: 'assert',
      );
    });
  });
}
