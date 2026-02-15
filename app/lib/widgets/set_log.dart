import 'package:flutter/material.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../theme/app_theme.dart';

class SetLog extends StatelessWidget {
  final List<ProposedSet> proposedSets;
  final List<CompletedSet> completedSets;
  final void Function(String completedSetId)? onDelete;

  const SetLog({
    super.key,
    required this.proposedSets,
    required this.completedSets,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final done = completedSets
        .where((c) => c.endedAt != Int64.ZERO)
        .toList()
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));

    if (done.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'COMPLETED SETS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: colorScheme.tertiary,
            ),
          ),
        ),
        ...done.map((completed) {
          final proposed = proposedSets.cast<ProposedSet?>().firstWhere(
            (p) => p!.id == completed.proposedSetId,
            orElse: () => null,
          );
          final name = proposed != null ? (shortNames[proposed.exercise] ?? '?') : '?';
          final isWarmup = proposed?.warmup ?? false;
          final hitTarget = proposed != null ? completed.actualReps >= proposed.targetReps : true;

          Color fg;
          String label;

          if (isWarmup) {
            fg = AppTheme.warmupFg;
            label = 'W';
          } else if (hitTarget) {
            fg = AppTheme.successFg;
            label = 'S';
          } else {
            fg = AppTheme.warningFg;
            label = 'S';
          }

          final finishTime = DateTime.fromMillisecondsSinceEpoch(completed.endedAt.toInt() * 1000);
          final timeStr = "${finishTime.hour.toString().padLeft(2, '0')}:${finishTime.minute.toString().padLeft(2, '0')}";
          final durationSecs = (completed.endedAt - completed.startedAt).toInt();
          final durationStr = durationSecs < 60 ? "${durationSecs}s" : "${durationSecs ~/ 60}m${durationSecs % 60}s";

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Text(
                  '[$label]',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: fg,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$name ${completed.actualReps}x${completed.actualWeight.toInt()}lbs',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  '$durationStr @ $timeStr',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: colorScheme.tertiary,
                  ),
                ),
                if (onDelete != null)
                  GestureDetector(
                    onTap: () => onDelete!(completed.id),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(Icons.close, size: 14, color: colorScheme.error.withValues(alpha: 0.5)),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
