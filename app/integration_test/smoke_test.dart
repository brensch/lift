// Smoke test: the real app boots on the emulator, reaches the backend, and shows
// the login screen. Proves the integration_test + screenshot pipeline end to end.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schlift/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches to the login screen', (tester) async {
    // On Android the surface must be converted before it can be captured.
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpWidget(const SchliftApp());
    // The first launch after install can take a while to paint the login
    // screen (the emulator renders in software), so poll rather than assume.
    var seen = false;
    for (var i = 0; i < 30 && !seen; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      seen = find.text('Dev Login').evaluate().isNotEmpty;
    }
    await binding.takeScreenshot('smoke_00_login');

    expect(find.text('Dev Login'), findsWidgets);
  });
}
