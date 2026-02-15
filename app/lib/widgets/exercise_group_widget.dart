import 'package:flutter/material.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercise_groups.dart';
import '../logic/exercises.dart';
import '../theme/app_theme.dart';

class ExerciseGroupWidget extends StatelessWidget {
  final ExerciseGroupData group;
  final int groupIndex;
  final int totalGroups;
  final List<CompletedSet> completedSets;
  final String? activeSetId;
  final bool isWorkoutEnded;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onEdit;

  const ExerciseGroupWidget({
    super.key,
    required this.group,
    required this.groupIndex,
    required this.totalGroups,
    required this.completedSets,
    this.activeSetId,
    required this.isWorkoutEnded,
    this.onMoveUp,
    this.onMoveDown,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final workingSets = group.sets.where((s) => !s.warmup).toList();
    final allCompleted = workingSets.isNotEmpty &&
        workingSets.every((s) => completedSets.any(
            (c) => c.proposedSetId == s.id && c.endedAt != Int64.ZERO));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: allCompleted ? AppTheme.successBg : colorScheme.secondary,
        border: Border.all(
          color: allCompleted
              ? AppTheme.successFg.withValues(alpha: 0.2)
              : colorScheme.outline,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (!isWorkoutEnded && !allCompleted && onMoveUp != null && onMoveDown != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: groupIndex > 0 ? onMoveUp : null,
                  child: Text(
                    '\u25B2',
                    style: TextStyle(
                      fontSize: 10,
                      color: groupIndex > 0
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: groupIndex < totalGroups - 1 ? onMoveDown : null,
                  child: Text(
                    '\u25BC',
                    style: TextStyle(
                      fontSize: 10,
                      color: groupIndex < totalGroups - 1
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ],
            ),
          if (!isWorkoutEnded && !allCompleted && onMoveUp != null)
            const SizedBox(width: 4),

          SizedBox(
            width: 56,
            child: Text(
              shortNames[group.exercise] ?? '?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: allCompleted ? AppTheme.successFg : colorScheme.onSurface,
              ),
            ),
          ),

          if (!isWorkoutEnded && onEdit != null)
            GestureDetector(
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.edit, size: 14, color: colorScheme.tertiary),
              ),
            ),

          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: group.sets.map((set) => _buildSetIndicator(context, set)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetIndicator(BuildContext context, ProposedSet set) {
    final colorScheme = Theme.of(context).colorScheme;
    final completed = completedSets.cast<CompletedSet?>().firstWhere(
      (c) => c!.proposedSetId == set.id && c.endedAt != Int64.ZERO,
      orElse: () => null,
    );
    final isActive = set.id == activeSetId;

    if (completed != null) {
      if (set.warmup) {
        return _chip('W', AppTheme.warmupLight, AppTheme.warmupFg);
      }
      final hitTarget = completed.actualReps >= set.targetReps;
      return _chip(
        hitTarget ? '\u2713' : '\u2713${completed.actualReps}',
        hitTarget ? AppTheme.successBg : AppTheme.warningBg,
        hitTarget ? AppTheme.successFg : AppTheme.warningFg,
      );
    }

    if (set.warmup) {
      return _chip(
        'W:${set.targetReps}\u00D7${set.targetWeight.toInt()}',
        isActive ? AppTheme.warmupLight : Colors.transparent,
        AppTheme.warmupFg,
        border: isActive ? AppTheme.warmupFg : AppTheme.warmupFg.withValues(alpha: 0.3),
        bold: isActive,
      );
    }

    return _chip(
      '${set.targetReps}\u00D7${set.targetWeight.toInt()}',
      isActive ? colorScheme.primary.withValues(alpha: 0.1) : colorScheme.surfaceContainerHighest,
      isActive ? colorScheme.primary : colorScheme.tertiary,
      border: isActive ? colorScheme.primary : null,
      bold: isActive,
    );
  }

  Widget _chip(String text, Color bg, Color fg, {Color? border, bool bold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        border: border != null ? Border.all(color: border, width: 1) : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: fg,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
