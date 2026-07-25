// A scenario that drives the REAL app against a REAL backend and captures a
// screenshot of each screen for audit. See test/e2e/README.md.
//
//   make e2e-screens
//   open app/test_screenshots/onboarding/report.html
//
// Note: the runner reports a timeout at the end (a live-gRPC app never lets the
// flutter_test event loop go fully idle). The screenshots and report ARE
// produced before that — they are the product. `make e2e-screens` treats a
// produced report as success.

@Tags(['e2e'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

void main() {
  late TestBackend backend;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    installPluginStubs();
    await AppDriver.loadFonts();
    backend = await TestBackend.start(port: 51_090);
  });

  tearDownAll(() async => backend.stop());

  testWidgets('login screen renders against a live backend', (tester) async {
    final app = AppDriver(tester, 'onboarding');
    await app.launch(backend);
    await app.shot('cold start — login screen');
    app.expectVisible('SCHLIFT');
    await app.finish('Onboarding — login screen');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
