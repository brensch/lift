/// Chart models: the pan/zoom viewport, heart-rate zones, the samples a
/// window draws and the workout's phase bands. All pure.
library;

import 'dart:math';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';

import '../../gen/workout/v1/wearable.pb.dart';
import '../../gen/workout/v1/workout.pb.dart';

/// The max heart rate used when no personalised one is available.
const int defaultMaxHr = 200;

/// The narrowest and widest window the chart pans and pinches between.
const double minWindowSeconds = 60;
const double maxWindowSeconds = 3600;

class ChartViewport {
  final double startSec;
  final double endSec;
  final double spanSec;

  const ChartViewport({
    required this.startSec,
    required this.endSec,
    required this.spanSec,
  });
}

class HeartRateZone {
  final String name;
  final String label;
  final int low;
  final int high;

  const HeartRateZone(this.name, this.label, this.low, this.high);
}

class HeartRateZonePercent {
  final String name;
  final double lowPct;
  final double highPct;

  const HeartRateZonePercent(this.name, this.lowPct, this.highPct);

  /// "50-60%".
  String get label => '${(lowPct * 100).round()}-${(highPct * 100).round()}%';
}

/// The five zones as fractions of max heart rate (or, with a resting heart
/// rate, of the reserve above it).
const List<HeartRateZonePercent> zonePercents = [
  HeartRateZonePercent('Z1', 0.50, 0.60),
  HeartRateZonePercent('Z2', 0.60, 0.70),
  HeartRateZonePercent('Z3', 0.70, 0.80),
  HeartRateZonePercent('Z4', 0.80, 0.90),
  HeartRateZonePercent('Z5', 0.90, 1.00),
];

/// The zones as percentages of [maxHr].
List<HeartRateZone> zonesForMaxHr(int maxHr) {
  return zonePercents.map((z) {
    final low = (z.lowPct * maxHr).round();
    final high = (z.highPct * maxHr).round();
    return HeartRateZone(z.name, z.label, low, high);
  }).toList();
}

/// The zones by heart-rate reserve (Karvonen) when [restingHr] is known
/// and below [maxHr], else by percentage of [maxHr]. Each zone starts where
/// the one below ends, and none goes past [maxHr].
List<HeartRateZone> zonesForConfig({required int maxHr, double? restingHr}) {
  if (restingHr == null || !restingHr.isFinite || restingHr <= 0) {
    return zonesForMaxHr(maxHr);
  }

  final reserve = maxHr - restingHr;
  if (reserve <= 0) return zonesForMaxHr(maxHr);

  final out = <HeartRateZone>[];
  var lastHigh = 0;
  for (final z in zonePercents) {
    var low = (restingHr + reserve * z.lowPct).round();
    var high = (restingHr + reserve * z.highPct).round();
    low = low.clamp(0, maxHr);
    high = high.clamp(0, maxHr);
    if (low < lastHigh) low = lastHigh;
    if (high <= low) high = min(maxHr, low + 1);
    out.add(HeartRateZone(z.name, z.label, low, high));
    lastHigh = high;
  }
  return out;
}

/// A window of [spanSec] (held between [minWindowSeconds] and
/// [maxWindowSeconds]) starting at [startSec], kept from starting before
/// the workout or so late that under 5% of it shows data up to
/// [domainMaxX].
ChartViewport clampViewport({
  required double startSec,
  required double spanSec,
  required double domainMaxX,
}) {
  final clampedSpan = spanSec
      .clamp(minWindowSeconds, maxWindowSeconds)
      .toDouble();
  final maxStart = max(0.0, domainMaxX - clampedSpan * 0.05);
  // The window may start before the workout does, by up to three quarters
  // of itself: early on, now still sits towards the right and the workout's
  // start comes in from the left.
  final minStart = -clampedSpan * 0.75;
  final clampedStart = startSec.clamp(minStart, maxStart).toDouble();
  return ChartViewport(
    startSec: clampedStart,
    endSec: clampedStart + clampedSpan,
    spanSec: clampedSpan,
  );
}

/// The samples to draw for the window [minX]..[maxX] (seconds into the
/// workout, which started at [startMs]), widened by [marginSec] each side.
/// A window with no sample in it (the watch dropped out, or a pan into a
/// gap) gets the nearest sample on each side, so the line carries on from
/// the last known reading.
List<HeartRateSample> samplesInRange(
  List<HeartRateSample> samples, {
  required int startMs,
  required double minX,
  required double maxX,
  double marginSec = 0,
}) {
  final minRange = minX - marginSec;
  final maxRange = maxX + marginSec;
  double at(HeartRateSample s) => (s.sampledAt.toInt() - startMs) / 1000.0;
  final filtered = samples.where((s) {
    final x = at(s);
    return x >= minRange && x <= maxRange;
  }).toList();
  if (filtered.isNotEmpty) return filtered;
  HeartRateSample? before;
  HeartRateSample? after;
  for (final s in samples) {
    final x = at(s);
    if (x < minRange && (before == null || x > at(before))) before = s;
    if (x > maxRange && (after == null || x < at(after))) after = s;
  }
  return [?before, ?after];
}

enum WorkoutPhase { lifting, resting, yapping }

/// One stretch of the workout, in seconds since its start.
class PhaseBand {
  final double x1;
  final double x2;
  final WorkoutPhase phase;

  const PhaseBand(this.x1, this.x2, this.phase);

  @override
  bool operator ==(Object other) =>
      other is PhaseBand &&
      other.x1 == x1 &&
      other.x2 == x2 &&
      other.phase == phase;

  @override
  int get hashCode => Object.hash(x1, x2, phase);

  @override
  String toString() => 'PhaseBand($x1, $x2, ${phase.name})';
}

/// The workout's phases: lifting (a set's start to its end), resting (the
/// end to the rest's end) and yapping (rest over, next set not started).
/// [startMs] is the workout's start. Live ([liveNowSec] set), the phase in
/// progress runs to now, and [liveLiftStartSec] is when the set being
/// lifted started, if one is. A finished workout stops at the last rest's
/// end. Sets with the same end and rest are counted once.
List<PhaseBand> phaseBands(
  List<CompletedSet> sets, {
  required int startMs,
  double? liveNowSec,
  double? liveLiftStartSec,
}) {
  final sorted = sets.toList()..sort((a, b) => a.endedAt.compareTo(b.endedAt));
  final deduped = <CompletedSet>[];
  final seenKeys = <String>{};
  for (final c in sorted) {
    if (seenKeys.add('${c.endedAt.toInt()}:${c.restUntil.toInt()}')) {
      deduped.add(c);
    }
  }
  double at(Int64 unixSec) => (unixSec.toInt() * 1000 - startMs) / 1000.0;

  final bands = <PhaseBand>[];
  void band(double x1, double x2, WorkoutPhase phase) {
    if (x2 > x1) bands.add(PhaseBand(x1, x2, phase));
  }

  for (var i = 0; i < deduped.length; i++) {
    final c = deduped[i];
    final ended = at(c.endedAt);
    if (c.startedAt > Int64.ZERO) {
      band(at(c.startedAt), ended, WorkoutPhase.lifting);
    }
    // Where this set's rest-and-chat stops: the next set's start (its end
    // when its start wasn't recorded), or, live, the set now being lifted
    // or now itself. A finished workout stops at the rest's end.
    final next = i + 1 < deduped.length ? deduped[i + 1] : null;
    final double? stop = next != null
        ? at(next.startedAt > Int64.ZERO ? next.startedAt : next.endedAt)
        : liveNowSec != null
        ? (liveLiftStartSec ?? liveNowSec)
        : null;
    final restEnd = c.restUntil == Int64.ZERO ? ended : at(c.restUntil);
    band(
      ended,
      stop == null ? restEnd : min(restEnd, stop),
      WorkoutPhase.resting,
    );
    if (stop != null) {
      band(max(restEnd, ended), stop, WorkoutPhase.yapping);
    }
  }
  if (liveNowSec != null && liveLiftStartSec != null) {
    band(liveLiftStartSec, liveNowSec, WorkoutPhase.lifting);
  }
  return bands;
}

/// Vertical gradient colouring the trend line by heart-rate zone, in
/// [zoneColors] (the theme's heartZones).
LinearGradient zoneGradient(
  List<HeartRateZone> zones,
  double maxY,
  List<Color> zoneColors,
) {
  final colors = <Color>[];
  final stops = <double>[];
  if (zones.isEmpty || maxY <= 0) {
    return LinearGradient(colors: [zoneColors.first, zoneColors.first]);
  }
  void add(Color c, double stop) {
    final s = stop.clamp(0.0, 1.0);
    // Keep stops non-decreasing (LinearGradient requires ascending order).
    colors.add(c);
    stops.add(stops.isEmpty ? s : (s < stops.last ? stops.last : s));
  }

  add(zoneColorByName(zones.first.name, zoneColors), 0.0);
  for (final z in zones) {
    final c = zoneColorByName(z.name, zoneColors);
    add(c, z.low / maxY);
    add(c, z.high / maxY);
  }
  add(zoneColorByName(zones.last.name, zoneColors), 1.0);

  return LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: colors,
    stops: stops,
  );
}

/// Colour for a named heart-rate zone (Z1 recovery through Z5 max) out of
/// [zoneColors]; Z1's for any other name.
Color zoneColorByName(String name, List<Color> zoneColors) {
  final i = const ['Z1', 'Z2', 'Z3', 'Z4', 'Z5'].indexOf(name);
  return zoneColors[i < 0 ? 0 : i];
}

/// Zone containing `bpm`, or null when below every zone floor.
HeartRateZone? zoneFor(double bpm, List<HeartRateZone> zones) {
  for (final z in zones) {
    if (bpm >= z.low && bpm < z.high) return z;
  }
  if (zones.isNotEmpty && bpm >= zones.last.high) return zones.last;
  return null;
}

/// m:ss, or h:mm from an hour, for elapsed-time axis labels.
String formatElapsedHms(int seconds) {
  final s = max(0, seconds);
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}';
  }
  return '$m:${sec.toString().padLeft(2, '0')}';
}
