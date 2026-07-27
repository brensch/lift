// Captures the Settings screen for review (debug tiles, U5).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('review — capture settings', (tester) async {
    final s = Scenario(binding, tester, 'settings_shot');
    await s.launch();
    await s.devLogin('set_${DateTime.now().millisecondsSinceEpoch}');
    await s.completeOnboarding();

    await s.tap(find.byIcon(Icons.menu));
    expect(await s.waitForText('Settings', seconds: 6), isTrue);
    await s.tapText('Settings');
    await s.settle(seconds: 2);
    await s.shot('Settings — debug tiles (U5)');
    await s.report();
  });
}
