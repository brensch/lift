// Store screenshot capture. Drives the real app on the emulator against a
// backend seeded with the `demo` account (SEED_DEMO_USER=demo) and takes one
// raw screenshot per store slide. Not a test of behaviour — it is the capture
// half of `make store-capture`; framing and upload happen in
// scripts/frame_store_screenshots.py and store-assets.yml.
//
// It also runs in the plain e2e suite, whose agent backend is not seeded.
// There `demo` and `demo-live` are brand-new accounts: the script onboards
// them and seeds a thin history over the API so the same slides render, just
// with less behind them. The real captures come from `make store-capture`.
//
// Slides are numbered by shot order; captions live in store/listing.yaml.
import 'dart:math' as math;

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:schlift/gen/workout/v1/wearable.pb.dart';
import 'package:schlift/gen/workout/v1/workout.pbgrpc.dart';
import 'package:schlift/providers/workout_provider.dart';

import 'support/api.dart';
import 'support/scenario.dart';
import 'package:schlift/theme/app_icons.dart';

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

/// On an unseeded backend, give [peer] a few climbing sessions of every
/// StrongLifts lift so Progress, History and the exercise detail have
/// something to draw and the next session opens with warmups rather than a
/// calibration rung.
/// Returns whether anything was seeded.
Future<bool> seedThinHistoryIfNeeded(Peer peer, {int sessions = 3}) async {
  if (await peer.hasPerformed(Exercise.EXERCISE_SQUAT)) return false;
  for (var i = 0; i < sessions; i++) {
    await peer.doWorkout('StrongLifts', [
      for (final lift in Scenario.defaultTemplateLifts)
        MapEntry(lift, 65 + i * 5.0),
    ]);
  }
  return true;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots', (tester) async {
    final s = Scenario(binding, tester, 'store');
    await s.run(() async {
      await s.launch();
      await s.devLogin('demo');
      await s.completeOnboarding(); // no-op for the seeded account
      await s.mustSee(Scenario.homeStart, seconds: 12);
      if (await seedThinHistoryIfNeeded(await s.api.login('demo'))) {
        s.note('Unseeded backend: thin history seeded for demo', kind: 'api');
        await s.relaunch(); // home re-reads the trackers and the volume
        await s.mustSee(Scenario.homeStart, seconds: 12);
      }

      // 00 — home: volume tracker, templates, the suggested one with its plan.
      await s.shot('Home');

      // 01 — progress charts (before the workout, so no timer bar overlays).
      await s.tap(find.byIcon(AppIcons.menu));
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
      await s.tap(find.byIcon(AppIcons.menu));
      await s.tapText('History');
      await s.settle(seconds: 3);
      await s.shot('History');

      // Switch to the account that is 24 minutes into a session (seeded by
      // SEED_DEMO_USER as `demo-live`); the app resumes straight into it. On
      // an unseeded backend it is a new account: onboard, seed, start one.
      await s.tap(find.byIcon(AppIcons.menu));
      await s.tapText('Logout');
      await s.devLogin('demo-live');
      await s.completeOnboarding();
      if (!await s.waitForText('End workout', seconds: 10)) {
        final live = await s.api.login('demo-live');
        if (await seedThinHistoryIfNeeded(live)) {
          s.note(
            'Unseeded backend: thin history seeded for demo-live',
            kind: 'api',
          );
        }
        await s.startWorkoutFromHome();
      }

      // Heart rate "from the watch": back-fill the whole session so the bar
      // shows a live number and the Heart tab has a trace.
      await feedHeartRate(tester, sinceMs: 0);

      // 04 — mid-session: exercises done, a working set ready, Start offered
      // (with the seeded rest still running or not).
      for (var i = 0; i < 6 && !s.setOffered; i++) {
        await s.settle(seconds: 1);
      }
      await s.shot('Workout ready');

      // 05 — resting after a set: Start, then Good; the countdown runs and
      // Start is offered for the next set.
      await s.liftSet();
      await s.settle(seconds: 2);
      await feedHeartRate(
        tester,
        sinceMs: DateTime.now().millisecondsSinceEpoch - 20000,
      );
      await s.shot('Resting');

      // 06 — the Heart tab: the trace over the session.
      await s.tapText('Heart');
      await s.settle(seconds: 2);
      await feedHeartRate(
        tester,
        sinceMs: DateTime.now().millisecondsSinceEpoch - 20000,
      );
      await s.shot('Heart rate');

      // 07 — the completed screen: Duration / Volume / Sets / Rest and the
      // heart-rate trace with the rests shaded. Ending through the UI also
      // leaves the account clean for the next capture.
      await s.tapText('Workout');
      await s.settle(seconds: 1);
      await s.endWorkoutAndWaitForSummary();
      await s.settle(seconds: 2);
      await s.shot('Workout complete');
    });
  });
}
