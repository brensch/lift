import 'package:flutter/material.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercise_groups.dart';
import '../logic/exercises.dart';
import '../theme/app_theme.dart';

class ExerciseGroupWidget extends StatelessWidget {
  final ExerciseGroupData group;
  final List<CompletedSet> completedSets;
  final String? activeSetId;
  final bool isWorkoutEnded;
  final VoidCallback? onEdit;

  const ExerciseGroupWidget({
    super.key,
    required this.group,
    required this.completedSets,
    this.activeSetId,
    required this.isWorkoutEnded,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final workingSets = group.sets.where((s) => !s.warmup).toList();
    final completedWorkingSets = workingSets
        .where(
          (s) => completedSets.any(
            (c) => c.proposedSetId == s.id && c.endedAt != Int64.ZERO,
          ),
        )
        .length;
    final allCompleted =
        workingSets.isNotEmpty && completedWorkingSets == workingSets.length;

    final hasActiveSet = group.sets.any((s) => s.id == activeSetId);

    Color statusColor = colorScheme.outline;
    if (allCompleted) {
      statusColor = AppTheme.successFg;
    } else if (hasActiveSet) {
      statusColor = AppTheme.activeFg;
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasActiveSet
              ? statusColor.withValues(alpha: 0.5)
              : colorScheme.outline,
          width: hasActiveSet ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Status Bar
            Container(width: 6, color: statusColor),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (group.group?.name ??
                                        exerciseNames[group.exercise] ??
                                        'Unknown')
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  color: allCompleted
                                      ? colorScheme.tertiary
                                      : colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$completedWorkingSets / ${workingSets.length} SETS COMPLETED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: allCompleted
                                      ? AppTheme.successFg
                                      : colorScheme.tertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isWorkoutEnded && onEdit != null)
                          IconButton(
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            visualDensity: VisualDensity.compact,
                            color: colorScheme.tertiary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (group.sets.any((s) => s.warmup)) ...[
                      _buildSetRow(
                        context,
                        'WARMUP',
                        group.sets.where((s) => s.warmup).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (group.sets.any((s) => !s.warmup))
                      _buildSetRow(
                        context,
                        'WORKING',
                        group.sets.where((s) => !s.warmup).toList(),
                      ),
                  ],
                ),
              ),
            ),

            if (!isWorkoutEnded)
              Container(
                width: 44,
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: colorScheme.outline)),
                ),
                child: Center(
                  child: Icon(
                    Icons.drag_indicator,
                    size: 20,
                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetRow(
    BuildContext context,
    String label,
    List<ProposedSet> sets,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: colorScheme.tertiary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: sets
                .map((set) => _buildSetIndicator(context, set))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSetIndicator(BuildContext context, ProposedSet set) {
    final colorScheme = Theme.of(context).colorScheme;
    final completed = completedSets.cast<CompletedSet?>().firstWhere(
      (c) => c!.proposedSetId == set.id && c.endedAt != Int64.ZERO,
      orElse: () => null,
    );
    final isActive = set.id == activeSetId;
    final isSuperset =
        group.group?.type == ExerciseGroupType.EXERCISE_GROUP_TYPE_SUPERSET;
    final exerciseName = shortNames[set.exercise] ?? set.exercise.name;

    String text = '';
    if (completed != null) {
      final hitTarget = completed.actualReps >= set.targetReps;
      final color = hitTarget ? AppTheme.successFg : AppTheme.warningFg;
      final bgColor = hitTarget ? AppTheme.successBg : AppTheme.warningBg;

      text = set.warmup ? 'W' : (hitTarget ? '✓' : '${completed.actualReps}');
      if (isSuperset) text = '$exerciseName $text';

      return _chip(
        text,
        bgColor,
        color,
        border: color.withValues(alpha: 0.3),
        bold: true,
      );
    }

    if (set.warmup) {
      text = 'W:${set.targetReps}@${set.targetWeight.toInt()}';
      if (isSuperset) text = '$exerciseName $text';
      return _chip(
        text,
        isActive ? AppTheme.warmupLight : Colors.transparent,
        isActive ? AppTheme.warmupFg : colorScheme.tertiary,
        border: isActive ? AppTheme.warmupFg : colorScheme.outline,
        bold: isActive,
      );
    }

    text = '${set.targetReps}@${set.targetWeight.toInt()}';
    if (isSuperset) text = '$exerciseName $text';
    return _chip(
      text,
      isActive ? AppTheme.activeBg : colorScheme.surfaceContainerHighest,
      isActive ? AppTheme.activeFg : colorScheme.onSurface,
      border: isActive ? AppTheme.activeFg : colorScheme.outline,
      bold: isActive,
    );
  }

  Widget _chip(
    String text,
    Color bg,
    Color fg, {
    Color? border,
    bool bold = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 48),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border ?? Colors.transparent),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: fg,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
