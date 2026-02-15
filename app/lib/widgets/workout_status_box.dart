import 'package:flutter/material.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../theme/app_theme.dart';
import 'plate_visualization.dart';

class StatusBox extends StatelessWidget {
  final String label;
  final Color color;
  final Widget? child;
  final String? timerText;
  final Color? timerColor;
  final ProposedSet? set;
  final bool isComplete;

  const StatusBox({
    super.key,
    required this.label,
    required this.color,
    this.child,
    this.timerText,
    this.timerColor,
    this.set,
    this.isComplete = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (set != null) ...[
                  const SizedBox(height: 4),
                  StatusSetWeightInfo(set: set!),
                ] else if (isComplete) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'ALL SETS COMPLETE',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ] else if (child != null) ...[
                  const SizedBox(height: 4),
                  child!,
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (timerText != null)
                Text(
                  timerText!,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    letterSpacing: -1,
                    height: 1.0,
                    color: timerColor ?? color,
                  ),
                ),
              if (set != null) ...[
                const SizedBox(height: 8),
                PlateVisualization(weight: set!.targetWeight.toDouble()),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class StatusSetWeightInfo extends StatelessWidget {
  final ProposedSet set;

  const StatusSetWeightInfo({super.key, required this.set});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = exerciseNames[set.exercise] ?? '?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (set.warmup) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: AppTheme.warmupFg.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'W',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.warmupFg,
                  ),
                ),
              ),
            ],
            Text(
              '${set.targetReps}\u00D7${set.targetWeight.toInt()}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              ' lb',
              style: TextStyle(fontSize: 11, color: colorScheme.tertiary),
            ),
          ],
        ),
      ],
    );
  }
}
