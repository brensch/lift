import 'package:flutter/material.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../theme/app_theme.dart';
import 'plate_visualization.dart';

class StatusBox extends StatelessWidget {
  final String sideLabel;
  final String? header;
  final Color color;
  final Widget? child;
  final String? stateLabel;
  final String? timerText;
  final Color? timerColor;
  final ProposedSet? set;
  final bool isComplete;

  const StatusBox({
    super.key,
    required this.sideLabel,
    this.header,
    required this.color,
    this.child,
    this.stateLabel,
    this.timerText,
    this.timerColor,
    this.set,
    this.isComplete = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = set != null ? (exerciseNames[set!.exercise] ?? '?') : null;

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Side Label: YOU / GROUP
            Container(
              width: 32,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    sideLabel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
            // Vertical Line
            Container(
              width: 1,
              color: color.withValues(alpha: 0.2),
            ),
            // Main Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Column 1: Info (Header, Exercise Name, Weight)
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (header != null) ...[
                            Text(
                              header!.toUpperCase(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: color,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                          ],
                          if (name != null) ...[
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (set != null) ...[
                            StatusSetWeightInfo(set: set!),
                          ] else if (isComplete) ...[
                            const Text(
                              'All sets complete',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ] else if (child != null) ...[
                            child!,
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Column 2: Plate Visualization
                    if (set != null) ...[
                      Expanded(
                        flex: 4,
                        child: Center(
                          child: PlateVisualization(weight: set!.targetWeight.toDouble()),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    // Column 3: Timer & State
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (stateLabel != null) ...[
                          Text(
                            stateLabel!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              color: color.withValues(alpha: 0.9),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        if (timerText != null)
                          Text(
                            timerText!,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              letterSpacing: -1.5,
                              height: 1.0,
                              color: timerColor ?? color,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
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
              fontSize: 32,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              letterSpacing: -1.5,
              height: 1.0,
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'lb',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colorScheme.tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
