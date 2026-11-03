// Smoke test: the real app boots, reaches the backend, and shows the login
// screen. Proves the scenario and screenshot pipeline end to end.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches to the login screen', (tester) async {
    await pumpApp(binding, tester);
    var seen = false;
    for (var i = 0; i < 30 && !seen; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      seen = find.text('Dev Login').evaluate().isNotEmpty;
    }
    await screenshot('smoke_00_login');

    expect(find.text('Dev Login'), findsWidgets);
  });
}
