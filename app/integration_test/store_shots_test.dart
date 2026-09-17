// Store screenshot capture. Drives the real app on the emulator against a
// backend seeded with the `demo` account (SEED_DEMO_USER=demo) and takes one
// raw screenshot per store slide. Not a test of behaviour — it is the capture
// half of `make store-capture`; framing and upload happen in
// scripts/frame_store_screenshots.py and store-assets.yml.
//
// Slides are numbered by shot order; captions live in store/listing.yaml.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots', (tester) async {
    final s = Scenario(binding, tester, 'store');
    await s.run(() async {
      await s.launch();
      await s.devLogin('demo');
      await s.completeOnboarding(); // no-op for the seeded account
      // A fresh install shows the tutorial once; it is not a store slide.
      if (await s.waitForText('SKIP', seconds: 6)) {
        await s.tapText('SKIP');
      }
      await s.mustSee('START', seconds: 12);

      // 00 — home: volume tracker, templates, the suggested one with its plan.
      await s.shot('Home');

      // 01 — progress charts (before the workout, so no timer bar overlays).
      await s.tap(find.byIcon(Icons.menu));
      await s.tapText('Progress');
      await s.settle(seconds: 3);
      await s.shot('Progress');

      // 02 — one exercise in detail.
      await s.tapText('Bench Press');
      await s.settle(seconds: 3);
      await s.shot('Exercise detail');

      // 03 — history.
      await s.tap(find.byIcon(Icons.menu));
      await s.tapText('History');
      await s.settle(seconds: 3);
      await s.shot('History');

      // Back home and into the suggested workout.
      await s.tap(find.byIcon(Icons.menu));
      await s.tapText('Workout');
      await s.mustSee('START', seconds: 10);
      await s.tapText('START');
      await s.mustSee('Start Set', seconds: 15);
      // Skip the warmups so the live slides show a working set.
      for (var i = 0; i < 6 && s.isVisible('Skip'); i++) {
        if (!s.visibleTexts().any((t) => t == 'Warmup')) break;
        await s.tapText('Skip');
        await s.settle(seconds: 1);
      }

      // 04 — the workout as prescribed, first working set ready.
      await s.mustSee('Start Set', seconds: 10);
      await s.shot('Workout ready');

      // 05 — a set in progress.
      await s.tapText('Start Set');
      await s.settle(seconds: 2);
      await s.shot('Set in progress');

      // 06 — rest timer after completing a set.
      await s.tapText('Complete Set');
      await s.settle(seconds: 2);
      await s.shot('Resting');

      // Leave the account clean for the next capture: end the open workout
      // through the API rather than the UI so the shots above stay untouched.
      final peer = await s.api.login('demo');
      if (await peer.adoptActiveWorkout()) {
        await peer.endWorkout();
      }
    });
  });
}
