/// Summary strip under the heart-rate chart: time in each zone plus
/// average / min / max stat tiles.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../../gen/workout/v1/wearable.pb.dart';
import 'models.dart';
import '../../theme/theme_spec.dart';
import '../common/flat.dart';

class ZoneSummary extends StatelessWidget {
  final List<HeartRateSample> samples;
  final List<HeartRateZone> zones;

  /// The side margins of the zones; the figures' grid runs edge to edge.
  final double inset;

  /// Whether the grid draws its bottom line when no zones follow it.
  final bool closeGrid;

  const ZoneSummary({
    super.key,
    required this.samples,
    required this.zones,
    this.inset = 0,
    this.closeGrid = true,
  });

  @override
  Widget build(BuildContext context) {
    final available = samples;
    final colorScheme = Theme.of(context).colorScheme;
    final bpms = available.map((s) => s.bpm).toList(growable: false);
    final avg = bpms.reduce((a, b) => a + b) / bpms.length;
    final maxBpm = bpms.reduce(max);
    final minBpm = bpms.reduce(min);

    final zoneSeconds = {for (final z in zones) z.name: 0.0};
    for (var i = 1; i < available.length; i++) {
      final dt =
          (available[i].sampledAt.toInt() - available[i - 1].sampledAt.toInt())
              .toDouble();
      // Ignore long gaps (watch dropped out) so they don't inflate a zone.
      if (dt <= 0 || dt > 60) continue;
      final z = zoneFor(available[i - 1].bpm, zones);
      if (z != null) zoneSeconds[z.name] = (zoneSeconds[z.name] ?? 0) + dt;
    }
    final totalSec = zoneSeconds.values.fold<double>(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlatMetricGrid(
          topLine: true,
          bottomLine: totalSec > 0 || closeGrid,
          metrics: [
            ('Avg', avg.round().toString(), null),
            ('Max', maxBpm.round().toString(), null),
            ('Min', minBpm.round().toString(), null),
          ],
        ),
        if (totalSec > 0)
          Padding(
            padding: EdgeInsets.fromLTRB(inset, 20, inset, closeGrid ? 0 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Time in zone',
                  style: TextStyle(
                    fontSize: context.tokens.size.small,
                    fontWeight: context.tokens.weight.bold,
                    color: colorScheme.tertiary,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: context.tokens.brXs,
                  child: SizedBox(
                    height: 12,
                    child: Row(
                      children: [
                        for (final z in zones)
                          Expanded(
                            flex: (zoneSeconds[z.name] ?? 0).round(),
                            child: Container(
                              color: zoneColorByName(
                                z.name,
                                context.tokens.heartZones,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    for (final z in zones)
                      if ((zoneSeconds[z.name] ?? 0) >= 1)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: zoneColorByName(
                                  z.name,
                                  context.tokens.heartZones,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${z.name}  ${formatElapsedHms((zoneSeconds[z.name] ?? 0).round())}',
                              style: TextStyle(
                                fontSize: context.tokens.size.small,
                                fontWeight: context.tokens.weight.bold,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
