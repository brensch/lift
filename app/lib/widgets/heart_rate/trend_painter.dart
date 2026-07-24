/// CustomPainter for the heart-rate trend line.
library;

import 'dart:math';
import 'package:flutter/material.dart';
import '../../gen/workout/v1/wearable.pb.dart';
import 'models.dart';

class HeartRateTrendPainter extends CustomPainter {
  final List<HeartRateSample> samples;
  final List<HeartRateZone> zones;

  const HeartRateTrendPainter({required this.samples, required this.zones});

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty || size.width <= 0 || size.height <= 0) return;

    final values = samples.map((sample) => sample.bpm).toList(growable: false);
    final minBpm = values.reduce(min);
    final maxBpm = values.reduce(max);
    final span = max(1.0, maxBpm - minBpm);
    final points = <Offset>[];

    for (int i = 0; i < values.length; i++) {
      final dx = values.length == 1
          ? 0.0
          : (i / (values.length - 1)) * size.width;
      final normalized = (values[i] - minBpm) / span;
      final dy = size.height - (normalized * (size.height - 2)) - 1;
      points.add(Offset(dx, dy));
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (points.length == 1) {
      canvas.drawCircle(
        points.first,
        1.5,
        Paint()..color = _zoneColorForBpm(values.first),
      );
      return;
    }

    for (var i = 1; i < points.length; i++) {
      paint.color = _zoneColorForBpm((values[i - 1] + values[i]) / 2);
      canvas.drawLine(points[i - 1], points[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant HeartRateTrendPainter oldDelegate) {
    if (oldDelegate.samples.length != samples.length) return true;
    if (_zonesChanged(oldDelegate.zones, zones)) return true;
    if (samples.isEmpty) return false;
    return oldDelegate.samples.last.bpm != samples.last.bpm ||
        oldDelegate.samples.last.sampledAt != samples.last.sampledAt;
  }

  bool _zonesChanged(List<HeartRateZone> a, List<HeartRateZone> b) {
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i].name != b[i].name ||
          a[i].low != b[i].low ||
          a[i].high != b[i].high) {
        return true;
      }
    }
    return false;
  }

  HeartRateZone? _zoneForBpm(double bpm) {
    for (final zone in zones) {
      if (bpm >= zone.low && bpm < zone.high) return zone;
    }
    if (zones.isNotEmpty && bpm >= zones.last.high) return zones.last;
    return null;
  }

  Color _zoneColorForBpm(double bpm) {
    final zone = _zoneForBpm(bpm);
    if (zone == null) return const Color(0xFF22C55E);
    switch (zone.name) {
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
}
