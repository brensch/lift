/// Chart models: the pan/zoom viewport and heart-rate zone definitions.
library;

import 'dart:math';

import 'package:flutter/material.dart';

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
  final String label;
  final double lowPct;
  final double highPct;

  const HeartRateZonePercent(this.name, this.label, this.lowPct, this.highPct);
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
