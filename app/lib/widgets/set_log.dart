import 'package:flutter/material.dart';
import 'package:fixnum/fixnum.dart';
import 'package:provider/provider.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
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

  // Layout constants — keep these in sync so dot and connector line up.
  static const double _timeWidth = 36;
  static const double _gap1 = 6;
  static const double _dotSize = 6;
  static const double _dotCenterX = _timeWidth + _gap1 + _dotSize / 2; // 45

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final proposedById = <String, ProposedSet>{
      for (final p in proposedSets) p.id: p,
    };
    final done = completedSets.where((c) => c.endedAt != Int64.ZERO).toList()
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));

    if (done.isEmpty) return const SizedBox.shrink();

    final lineColor = colorScheme.outline.withValues(alpha: 0.25);

    final List<Widget> items = [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
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
    ];

    for (int i = 0; i < done.length; i++) {
      items.add(_buildRow(context, done[i], proposedById, colorScheme));

      // Connecting line segment between rows
      if (i < done.length - 1) {
        items.add(
          Padding(
            padding: const EdgeInsets.only(left: _dotCenterX - 0.5),
            child: Container(width: 1, height: 7, color: lineColor),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    );
  }

  Widget _buildRow(
    BuildContext context,
    CompletedSet completed,
    Map<String, ProposedSet> proposedById,
    ColorScheme colorScheme,
  ) {
    final proposed = proposedById[completed.proposedSetId];
    final unit = context.watch<SettingsProvider>().weightUnit;
    final shortName = proposed != null
        ? (shortNames[proposed.exercise] ?? '?')
        : '?';
    final isWarmup = proposed?.warmup ?? false;
    final hitTarget = proposed != null
        ? completed.actualReps >= proposed.targetReps
        : true;

    final String weightStr = formatWeight(
      completed.actualWeight.toDouble(),
      unit,
    );

    Color dotColor;
    Color statusColor;
    String statusText;

    if (isWarmup) {
      dotColor = AppTheme.warmupFg.withValues(alpha: 0.5);
      statusColor = AppTheme.warmupFg;
      statusText = 'W';
    } else if (hitTarget) {
      dotColor = AppTheme.successFg;
      statusColor = AppTheme.successFg;
      statusText = '✓';
    } else {
      dotColor = AppTheme.warningFg;
      statusColor = AppTheme.warningFg;
      statusText = '${completed.actualReps}';
    }

    final finishTime = DateTime.fromMillisecondsSinceEpoch(
      completed.endedAt.toInt() * 1000,
    );
    final timeStr =
        '${finishTime.hour.toString().padLeft(2, '0')}:${finishTime.minute.toString().padLeft(2, '0')}';

    final durationSecs = (completed.endedAt - completed.startedAt).toInt();
    final durationStr = durationSecs < 60
        ? '${durationSecs}s'
        : '${durationSecs ~/ 60}m${(durationSecs % 60).toString().padLeft(2, '0')}s';

    final canDelete =
        onDelete != null &&
        (deletableWorkoutId == null ||
            completed.workoutId == deletableWorkoutId);
    final ownerLabel = workoutOwnerLabels?[completed.workoutId];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Time
        SizedBox(
          width: _timeWidth,
          child: Text(
            timeStr,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colorScheme.tertiary,
            ),
          ),
        ),
        const SizedBox(width: _gap1),

        // Dot
        Container(
          width: _dotSize,
          height: _dotSize,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),

        // Content
        Expanded(
          child: Row(
            children: [
              Text(
                shortName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isWarmup
                      ? colorScheme.tertiary
                      : colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '${completed.actualReps}×$weightStr',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
              const Spacer(),
              Text(
                durationStr,
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.tertiary.withValues(alpha: 0.7),
                ),
              ),
              if (ownerLabel != null && ownerLabel.isNotEmpty) ...[
                const SizedBox(width: 6),
                _ownerBadge(context, ownerLabel, colorScheme),
              ],
              if (canDelete) ...[
                const SizedBox(width: 4),
                _deleteButton(context, completed, colorScheme),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _ownerBadge(
    BuildContext context,
    String label,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _deleteButton(
    BuildContext context,
    CompletedSet completed,
    ColorScheme colorScheme,
  ) {
    return GestureDetector(
      onTap: () async {
        final weight = completed.actualWeight.toDouble();
        final weightText = formatWeight(
          weight,
          context.read<SettingsProvider>().weightUnit,
        );
        final confirmed = await _confirmDelete(
          context,
          setSummary: '${completed.actualReps}×$weightText',
        );
        if (confirmed == true) onDelete!(completed.id);
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Icon(
          Icons.close_rounded,
          size: 14,
          color: colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
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
