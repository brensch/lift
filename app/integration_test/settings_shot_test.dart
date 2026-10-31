// Captures the Settings screen for review (debug tiles, U5).

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/scenario.dart';
import 'package:schlift/theme/app_icons.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('review — capture settings', (tester) async {
    final s = Scenario(binding, tester, 'settings_shot');
    await s.launch();
    await s.devLogin('set_${DateTime.now().millisecondsSinceEpoch}');
    await s.completeOnboarding();

    // Settings is the cog at the foot of the menu.
    await s.tap(find.byIcon(AppIcons.menu));
    await s.settle(seconds: 1);
    await s.tap(find.byIcon(AppIcons.settings));
    await s.settle(seconds: 2);
    await s.shot('Settings — debug tiles (U5)');
    await s.report();
  });
}
