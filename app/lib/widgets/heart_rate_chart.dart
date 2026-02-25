import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/wearable.pb.dart';

class HeartRateChart extends StatelessWidget {
  final List<HeartRateSample> heartRateSamples;
  final List<CompletedSet> completedSets;
  final Int64 workoutStartTime; // seconds
  final DateTime now;

  const HeartRateChart({
    super.key,
    required this.heartRateSamples,
    required this.completedSets,
    required this.workoutStartTime,
    required this.now,
  });

  static const int _maxHr = 190;
  static const List<_Zone> _zones = [
    _Zone('Z1', 'RECOVERY', 95, 114),
    _Zone('Z2', 'ENDURANCE', 114, 133),
    _Zone('Z3', 'TEMPO', 133, 152),
    _Zone('Z4', 'THRESHOLD', 152, 171),
    _Zone('Z5', 'MAX', 171, 190),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final startMs = workoutStartTime.toInt() * 1000;

    // Filter to available samples and convert to seconds-since-start.
    final available = heartRateSamples
        .where(
          (s) =>
              s.availability ==
              HeartRateAvailability.HEART_RATE_AVAILABILITY_AVAILABLE,
        )
        .toList();
    if (available.isEmpty) return const SizedBox.shrink();

    // Downsample to ~300 points.
    final spots = _downsample(available, startMs, 300);

    // Current BPM = last available sample.
    final currentBpm = available.last.bpm;
    final currentZone = _zoneFor(currentBpm);

    // X range: 0 to now.
    final nowSec = (now.millisecondsSinceEpoch - startMs) / 1000.0;
    final maxX = max(nowSec, spots.isNotEmpty ? spots.last.x : 0.0);

    // Y range.
    const minY = 50.0;
    final maxY = _maxHr.toDouble();

    // Activity bands from completed sets.
    final activityBands = _buildActivityBands(startMs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            Text(
              'HEART RATE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: colorScheme.tertiary,
              ),
            ),
            const Spacer(),
            Text(
              '${currentBpm.round()}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1.0,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'BPM',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.tertiary,
              ),
            ),
            if (currentZone != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.tertiary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${currentZone.name} ${currentZone.label}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: colorScheme.tertiary,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // Chart
        SizedBox(
          height: 140,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
              clipData: const FlClipData.all(),
              lineTouchData: const LineTouchData(enabled: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 19, // ~5 zone boundaries
                    getTitlesWidget: (value, meta) {
                      final bpm = value.round();
                      if (bpm == 95 ||
                          bpm == 114 ||
                          bpm == 133 ||
                          bpm == 152 ||
                          bpm == 171 ||
                          bpm == 190) {
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            '$bpm',
                            style: TextStyle(
                              fontSize: 9,
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 20,
                    interval: 19,
                    getTitlesWidget: (value, meta) {
                      for (final z in _zones) {
                        final mid = (z.low + z.high) / 2.0;
                        if ((value - mid).abs() < 1) {
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              z.name,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                          );
                        }
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              rangeAnnotations: RangeAnnotations(
                horizontalRangeAnnotations: [
                  for (var i = 0; i < _zones.length; i++)
                    HorizontalRangeAnnotation(
                      y1: _zones[i].low.toDouble(),
                      y2: _zones[i].high.toDouble(),
                      color: i.isEven
                          ? colorScheme.onSurface.withValues(alpha: 0.03)
                          : Colors.transparent,
                    ),
                ],
                verticalRangeAnnotations: activityBands,
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.2,
                  color: colorScheme.onSurface,
                  barWidth: 1.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: colorScheme.onSurface.withValues(alpha: 0.06),
                  ),
                ),
              ],
            ),
            duration: Duration.zero,
          ),
        ),
      ],
    );
  }

  List<FlSpot> _downsample(
    List<HeartRateSample> samples,
    int startMs,
    int maxPoints,
  ) {
    if (samples.length <= maxPoints) {
      return samples
          .map(
            (s) => FlSpot(
              (s.sampledAt.toInt() - startMs) / 1000.0,
              s.bpm.clamp(50, _maxHr.toDouble()),
            ),
          )
          .toList();
    }
    final step = samples.length / maxPoints;
    final result = <FlSpot>[];
    for (var i = 0; i < maxPoints; i++) {
      final s = samples[(i * step).floor()];
      result.add(
        FlSpot(
          (s.sampledAt.toInt() - startMs) / 1000.0,
          s.bpm.clamp(50, _maxHr.toDouble()),
        ),
      );
    }
    return result;
  }

  List<VerticalRangeAnnotation> _buildActivityBands(int startMs) {
    final bands = <VerticalRangeAnnotation>[];
    // Sort completed sets by startedAt.
    final sorted = completedSets
        .where((c) => c.startedAt != Int64.ZERO && c.endedAt != Int64.ZERO)
        .toList()
      ..sort(
        (a, b) => a.startedAt.compareTo(b.startedAt),
      );

    const liftColor = Color(0xFFEC4899);
    const restColor = Color(0xFF3B82F6);
    const yapColor = Color(0xFFF97316);

    for (var i = 0; i < sorted.length; i++) {
      final c = sorted[i];
      final liftStart = (c.startedAt.toInt() * 1000 - startMs) / 1000.0;
      final liftEnd = (c.endedAt.toInt() * 1000 - startMs) / 1000.0;

      // Lifting band.
      if (liftEnd > liftStart) {
        bands.add(
          VerticalRangeAnnotation(
            x1: liftStart,
            x2: liftEnd,
            color: liftColor.withValues(alpha: 0.12),
          ),
        );
      }

      // Rest band.
      if (c.restUntil != Int64.ZERO) {
        final restEnd = (c.restUntil.toInt() * 1000 - startMs) / 1000.0;
        if (restEnd > liftEnd) {
          bands.add(
            VerticalRangeAnnotation(
              x1: liftEnd,
              x2: restEnd,
              color: restColor.withValues(alpha: 0.12),
            ),
          );
        }
      }

      // Yapping band: gap between previous rest end and this lift start.
      if (i > 0) {
        final prev = sorted[i - 1];
        final prevEnd = prev.restUntil != Int64.ZERO
            ? (prev.restUntil.toInt() * 1000 - startMs) / 1000.0
            : (prev.endedAt.toInt() * 1000 - startMs) / 1000.0;
        if (liftStart > prevEnd + 1) {
          bands.add(
            VerticalRangeAnnotation(
              x1: prevEnd,
              x2: liftStart,
              color: yapColor.withValues(alpha: 0.12),
            ),
          );
        }
      }
    }
    return bands;
  }

  _Zone? _zoneFor(double bpm) {
    for (final z in _zones) {
      if (bpm >= z.low && bpm < z.high) return z;
    }
    if (bpm >= _maxHr) return _zones.last;
    return null;
  }
}

class _Zone {
  final String name;
  final String label;
  final int low;
  final int high;

  const _Zone(this.name, this.label, this.low, this.high);
}
