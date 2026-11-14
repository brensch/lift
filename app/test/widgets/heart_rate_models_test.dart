/// The heart-rate chart's maths: its phase bands, zones, viewport and the
/// samples a window draws.
library;

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/wearable.pb.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/widgets/heart_rate/models.dart';

void main() {
  const start = 1761900000; // unix seconds
  const startMs = start * 1000;

  CompletedSet set(int startedAt, int endedAt, int restUntil) => CompletedSet(
    startedAt: Int64(start + startedAt),
    endedAt: Int64(start + endedAt),
    restUntil: Int64(start + restUntil),
  );

  group('phaseBands', () {
    const lifting = WorkoutPhase.lifting;
    const resting = WorkoutPhase.resting;
    const yapping = WorkoutPhase.yapping;

    test('lift, rest, then yapping once the rest runs out', () {
      final bands = phaseBands([
        set(0, 30, 120),
        set(150, 180, 300),
      ], startMs: startMs);
      expect(bands, const [
        PhaseBand(0, 30, lifting),
        PhaseBand(30, 120, resting),
        PhaseBand(120, 150, yapping),
        PhaseBand(150, 180, lifting),
        // Finished: the last rest runs to its end, no yapping after.
        PhaseBand(180, 300, resting),
      ]);
    });

    test('a set started before the rest ran out cuts the rest short', () {
      final bands = phaseBands([
        set(0, 30, 120),
        set(90, 120, 200),
      ], startMs: startMs);
      expect(bands.take(3), const [
        PhaseBand(0, 30, lifting),
        PhaseBand(30, 90, resting),
        PhaseBand(90, 120, lifting),
      ]);
    });

    test('a set with no rest after it is all yapping', () {
      final bands = phaseBands([
        set(0, 30, 30),
        set(120, 150, 150),
      ], startMs: startMs);
      expect(bands.take(3), const [
        PhaseBand(0, 30, lifting),
        PhaseBand(30, 120, yapping),
        PhaseBand(120, 150, lifting),
      ]);
    });

    test('live: the rest runs to now, then a lift in progress', () {
      expect(
        phaseBands([set(0, 30, 120)], startMs: startMs, liveNowSec: 100),
        const [PhaseBand(0, 30, lifting), PhaseBand(30, 100, resting)],
      );
      expect(
        phaseBands(
          [set(0, 30, 120)],
          startMs: startMs,
          liveNowSec: 200,
          liveLiftStartSec: 160,
        ),
        const [
          PhaseBand(0, 30, lifting),
          PhaseBand(30, 120, resting),
          PhaseBand(120, 160, yapping),
          PhaseBand(160, 200, lifting),
        ],
      );
    });

    test('the same set twice is drawn once, in order of finishing', () {
      final bands = phaseBands([
        set(150, 180, 300),
        set(0, 30, 120),
        set(0, 30, 120),
      ], startMs: startMs);
      expect(bands.where((b) => b.phase == lifting), const [
        PhaseBand(0, 30, lifting),
        PhaseBand(150, 180, lifting),
      ]);
    });
  });

  group('zones', () {
    void expectContiguous(List<HeartRateZone> zones, int maxHr) {
      expect(zones.map((z) => z.name), ['Z1', 'Z2', 'Z3', 'Z4', 'Z5']);
      for (var i = 0; i < zones.length; i++) {
        expect(zones[i].high, greaterThan(zones[i].low));
        expect(zones[i].high, lessThanOrEqualTo(maxHr));
        if (i > 0) expect(zones[i].low, zones[i - 1].high);
      }
    }

    test('by percentage of max', () {
      final zones = zonesForConfig(maxHr: 200);
      expectContiguous(zones, 200);
      expect(zones.first.low, 100);
      expect(zones.last.high, 200);
      expect(zones.first.label, '50-60%');
      expect(zones.last.label, '90-100%');
    });

    test('by heart-rate reserve when the resting rate is known', () {
      final zones = zonesForConfig(maxHr: 190, restingHr: 60);
      expectContiguous(zones, 190);
      expect(zones.first.low, 125); // 60 + 130 × 0.5
      expect(zones.last.high, 190);
    });

    test('a resting rate at or above max falls back to percentage', () {
      expect(
        zonesForConfig(maxHr: 150, restingHr: 160).map((z) => z.low),
        zonesForMaxHr(150).map((z) => z.low),
      );
    });
  });

  group('clampViewport', () {
    test('holds the span between the narrowest and widest window', () {
      expect(
        clampViewport(startSec: 0, spanSec: 10, domainMaxX: 1000).spanSec,
        minWindowSeconds,
      );
      expect(
        clampViewport(startSec: 0, spanSec: 99999, domainMaxX: 9999).spanSec,
        maxWindowSeconds,
      );
    });

    test(
      'starts at most three quarters of itself early, never past its data',
      () {
        expect(
          clampViewport(startSec: -50, spanSec: 600, domainMaxX: 1000).startSec,
          -50,
        );
        expect(
          clampViewport(
            startSec: -900,
            spanSec: 600,
            domainMaxX: 1000,
          ).startSec,
          -450,
        );
        final late = clampViewport(
          startSec: 5000,
          spanSec: 600,
          domainMaxX: 1000,
        );
        expect(late.startSec, 1000 - 600 * 0.05);
        expect(late.endSec, late.startSec + 600);
      },
    );
  });

  group('samplesInRange', () {
    HeartRateSample at(int sec, double bpm) =>
        HeartRateSample(sampledAt: Int64(startMs + sec * 1000), bpm: bpm);
    final samples = [at(0, 72), at(10, 80), at(100, 150), at(1000, 120)];

    test('the samples in the window and its margin', () {
      expect(
        samplesInRange(
          samples,
          startMs: startMs,
          minX: 60,
          maxX: 200,
          marginSec: 50,
        ).map((s) => s.bpm),
        [80, 150],
      );
    });

    test('an empty window carries on from the nearest reading each side, '
        'not the workout\'s first', () {
      expect(
        samplesInRange(
          samples,
          startMs: startMs,
          minX: 300,
          maxX: 600,
        ).map((s) => s.bpm),
        [150, 120],
      );
      // Live after a watch dropout: nothing since, so the last reading.
      expect(
        samplesInRange(
          samples,
          startMs: startMs,
          minX: 2000,
          maxX: 2600,
        ).map((s) => s.bpm),
        [120],
      );
    });
  });
}
