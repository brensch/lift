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

/// Vertical gradient colouring the trend line by heart-rate zone.
LinearGradient zoneGradient(List<HeartRateZone> zones, double maxY) {
  final colors = <Color>[];
  final stops = <double>[];
  if (zones.isEmpty || maxY <= 0) {
    return const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF22C55E)]);
  }
  void add(Color c, double stop) {
    final s = stop.clamp(0.0, 1.0);
    // Keep stops non-decreasing (LinearGradient requires ascending order).
    colors.add(c);
    stops.add(stops.isEmpty ? s : (s < stops.last ? stops.last : s));
  }

  add(zoneColorByName(zones.first.name), 0.0);
  for (final z in zones) {
    final c = zoneColorByName(z.name);
    add(c, z.low / maxY);
    add(c, z.high / maxY);
  }
  add(zoneColorByName(zones.last.name), 1.0);

  return LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: colors,
    stops: stops,
  );
}

/// Colour for a named heart-rate zone (Z1 recovery through Z5 max).
Color zoneColorByName(String name) {
  switch (name) {
    case 'Z1':
      return const Color(0xFF22C55E);
    case 'Z2':
      return const Color(0xFFEAB308);
    case 'Z3':
      return const Color(0xFFF59E0B);
    case 'Z4':
      return const Color(0xFFEF4444);
    case 'Z5':
      return const Color(0xFFB91C1C);
    default:
      return const Color(0xFF22C55E);
  }
}

/// Zone containing `bpm`, or null when below every zone floor.
HeartRateZone? zoneFor(double bpm, List<HeartRateZone> zones) {
  for (final z in zones) {
    if (bpm >= z.low && bpm < z.high) return z;
  }
  if (zones.isNotEmpty && bpm >= zones.last.high) return zones.last;
  return null;
}

/// h:mm:ss / m:ss for elapsed-time axis labels.
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
