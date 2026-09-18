// Store screenshot capture. Drives the real app on the emulator against a
// backend seeded with the `demo` account (SEED_DEMO_USER=demo) and takes one
// raw screenshot per store slide. Not a test of behaviour — it is the capture
// half of `make store-capture`; framing and upload happen in
// scripts/frame_store_screenshots.py and store-assets.yml.
//
// Slides are numbered by shot order; captions live in store/listing.yaml.
import 'dart:math' as math;

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:schlift/gen/workout/v1/wearable.pb.dart';
import 'package:schlift/providers/workout_provider.dart';

import 'support/scenario.dart';

/// Feed heart rate the way the watch does: a batch of samples into the
/// provider's wearable ingest path, covering the workout so far. Each call
/// extends the series up to now, so the bar's live number and the Heart tab
/// both have data. Shape: climbs through a set, falls through the rest.
Future<void> feedHeartRate(WidgetTester tester, {required int sinceMs}) async {
  final wp = Provider.of<WorkoutProvider>(
    tester.element(find.byType(MaterialApp).first),
    listen: false,
  );
  final workout = wp.activeWorkout;
  if (workout == null) return;
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final startMs = workout.startTime.toInt() * 1000;
  final samples = <HeartRateSample>[];
  for (var t = math.max(sinceMs, startMs); t <= nowMs; t += 2000) {
    final secs = (t - startMs) / 1000;
    // ~3-minute set/rest cycle: up to ~145 while lifting, down to ~105 resting.
    final phase = (secs % 180) / 180;
    final bpm = phase < 0.3
        ? 105 + 40 * (phase / 0.3)
        : 145 - 40 * ((phase - 0.3) / 0.7);
    samples.add(
      HeartRateSample()
        ..sampledAt = Int64(t)
        ..bpm = bpm + math.sin(secs / 7) * 2
        ..availability =
            HeartRateAvailability.HEART_RATE_AVAILABILITY_AVAILABLE,
    );
  }
  wp.ingestWearHeartRateBatch(
    WearSensorBatch()
      ..batchId = 'store-$sinceMs-$nowMs'
      ..workoutId = workout.id
      ..sentAt = Int64(nowMs)
      ..heartRateSamples.addAll(samples),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

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

      // 02 — one exercise in detail: whichever big lift is on screen first
      // (the list is ordered by recent progress, so it varies with the seed).
      const lifts = [
        'Bench Press',
        'Squat',
        'Deadlift',
        'Overhead Press',
        'Barbell Row',
        'Lat Pulldown',
      ];
      await s.tapText(
        lifts.firstWhere(
          s.isVisible,
          orElse: () => s.visibleTexts().firstWhere((t) => t.contains('Press')),
        ),
      );
      await s.settle(seconds: 3);
      await s.shot('Exercise detail');

      // 03 — history.
      await s.tap(find.byIcon(Icons.menu));
      await s.tapText('History');
      await s.settle(seconds: 3);
      await s.shot('History');

      // Switch to the account that is 24 minutes into a session (seeded by
      // SEED_DEMO_USER as `demo-live`); the app resumes straight into it.
      await s.tap(find.byIcon(Icons.menu));
      await s.tapText('Logout');
      await s.devLogin('demo-live');
      if (!await s.waitForText('Start Early', seconds: 20)) {
        await s.mustSee('Start Set', seconds: 5);
      }
      // Skip the next exercise's warmups so the live slides show a working set.
      for (var i = 0; i < 6 && s.isVisible('Skip'); i++) {
        if (!s.visibleTexts().any((t) => t == 'Warmup')) break;
        await s.tapText('Skip');
        await s.settle(seconds: 1);
      }
      // Heart rate "from the watch": back-fill the whole session so the bar
      // shows a live number and the Heart tab has a trace.
      await feedHeartRate(tester, sinceMs: 0);

      // 04 — mid-session: two exercises done, resting before the next.
      await s.shot('Workout ready');

      // 05 — a set in progress.
      await s.tapText(s.isVisible('Start Early') ? 'Start Early' : 'Start Set');
      await s.settle(seconds: 2);
      await feedHeartRate(
        tester,
        sinceMs: DateTime.now().millisecondsSinceEpoch - 20000,
      );
      await s.shot('Set in progress');

      // 06 — rest timer after completing a set.
      await s.tapText('Complete Set');
      await s.settle(seconds: 2);
      await feedHeartRate(
        tester,
        sinceMs: DateTime.now().millisecondsSinceEpoch - 20000,
      );
      await s.shot('Resting');

      // 07 — the Heart tab: the trace over the session.
      await s.tapText('Heart');
      await s.settle(seconds: 2);
      await feedHeartRate(
        tester,
        sinceMs: DateTime.now().millisecondsSinceEpoch - 20000,
      );
      await s.shot('Heart rate');

      // Leave the account clean for the next capture: end the open workout
      // through the API rather than the UI so the shots above stay untouched.
      final peer = await s.api.login('demo-live');
      if (await peer.adoptActiveWorkout()) {
        await peer.endWorkout();
      }
    });
  });
}
