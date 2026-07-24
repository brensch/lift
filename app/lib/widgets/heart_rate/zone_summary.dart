/// Summary strip under the heart-rate chart: time in each zone plus
/// average / min / max stat tiles.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../../gen/workout/v1/wearable.pb.dart';
import 'models.dart';

class ZoneSummary extends StatelessWidget {
  final List<HeartRateSample> samples;
  final List<HeartRateZone> zones;

  const ZoneSummary({super.key, required this.samples, required this.zones});

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
        Row(
          children: [
            StatTile(label: 'AVG', value: avg.round().toString()),
            StatTile(label: 'MAX', value: maxBpm.round().toString()),
            StatTile(label: 'MIN', value: minBpm.round().toString()),
          ],
        ),
        if (totalSec > 0) ...[
          const SizedBox(height: 20),
          Text(
            'TIME IN ZONE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: colorScheme.tertiary,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (final z in zones)
                    Expanded(
                      flex: (zoneSeconds[z.name] ?? 0).round(),
                      child: Container(color: zoneColorByName(z.name)),
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
                          color: zoneColorByName(z.name),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${z.name}  ${formatElapsedHms((zoneSeconds[z.name] ?? 0).round())}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
            ],
          ),
        ],
      ],
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;

  const StatTile({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colorScheme.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}
