import 'package:flutter/material.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../theme/app_theme.dart';

class SetLog extends StatelessWidget {
  final List<ProposedSet> proposedSets;
  final List<CompletedSet> completedSets;
  final void Function(String completedSetId)? onDelete;
  final String? deletableWorkoutId;
  final Map<String, String>? workoutOwnerLabels;

  const SetLog({
    super.key,
    required this.proposedSets,
    required this.completedSets,
    this.onDelete,
    this.deletableWorkoutId,
    this.workoutOwnerLabels,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final proposedById = <String, ProposedSet>{
      for (final proposed in proposedSets) proposed.id: proposed,
    };
    final done = completedSets.where((c) => c.endedAt != Int64.ZERO).toList()
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
          final proposed = proposedById[completed.proposedSetId];
          final name = proposed != null
              ? (shortNames[proposed.exercise] ?? '?')
              : '?';
          final isWarmup = proposed?.warmup ?? false;
          final hitTarget = proposed != null
              ? completed.actualReps >= proposed.targetReps
              : true;

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

          final finishTime = DateTime.fromMillisecondsSinceEpoch(
            completed.endedAt.toInt() * 1000,
          );
          final timeStr =
              "${finishTime.hour.toString().padLeft(2, '0')}:${finishTime.minute.toString().padLeft(2, '0')}";
          final durationSecs = (completed.endedAt - completed.startedAt)
              .toInt();
          final durationStr = durationSecs < 60
              ? "${durationSecs}s"
              : "${durationSecs ~/ 60}m${durationSecs % 60}s";

          final canDelete =
              onDelete != null &&
              (deletableWorkoutId == null ||
                  completed.workoutId == deletableWorkoutId);
          final ownerLabel = workoutOwnerLabels?[completed.workoutId];

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: fg.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: fg,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$name ${completed.actualReps}x${completed.actualWeight.toInt()}lbs',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (ownerLabel != null && ownerLabel.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withValues(
                                  alpha: 0.6,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.25,
                                  ),
                                ),
                              ),
                              child: Text(
                                ownerLabel.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$durationStr @ $timeStr',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canDelete) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      tooltip: 'Delete set',
                      onPressed: () async {
                        final weight = completed.actualWeight.toDouble();
                        final weightText = weight == weight.roundToDouble()
                            ? weight.toInt().toString()
                            : weight.toStringAsFixed(1);
                        final confirmed = await _confirmDelete(
                          context,
                          setSummary: '${completed.actualReps}x$weightText',
                        );
                        if (confirmed == true) {
                          onDelete!(completed.id);
                        }
                      },
                      icon: const Icon(Icons.delete_outline, size: 20),
                      style: IconButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        backgroundColor: colorScheme.error.withValues(
                          alpha: 0.08,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: colorScheme.error.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<bool?> _confirmDelete(
    BuildContext context, {
    required String setSummary,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('Delete Completed Set?'),
          content: Text('Remove set $setSummary? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
