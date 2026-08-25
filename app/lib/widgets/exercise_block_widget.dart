import 'package:flutter/material.dart';
import 'package:fixnum/fixnum.dart';
import 'package:provider/provider.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercise_blocks.dart';
import '../logic/exercises.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

class ExerciseBlockWidget extends StatefulWidget {
  final ExerciseBlock block;
  final List<CompletedSet> completedSets;
  final String? activeSetId;
  final bool isWorkoutEnded;
  final VoidCallback? onEdit;
  final int? dragIndex; // null = not draggable (completed block)

  const ExerciseBlockWidget({
    super.key,
    required this.block,
    required this.completedSets,
    this.activeSetId,
    required this.isWorkoutEnded,
    this.onEdit,
    this.dragIndex,
  });

  @override
  State<ExerciseBlockWidget> createState() => _ExerciseBlockWidgetState();
}

class _ExerciseBlockWidgetState extends State<ExerciseBlockWidget> {
  static const _activeLiftFg = AppTheme.workoutLiftingFg;
  static const _activeLiftBg = AppTheme.workoutLiftingBg;
  bool _isManualExpanded = false;

  Widget _iconActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(borderRadius: AppTheme.brSm),
      child: InkWell(
        borderRadius: AppTheme.brSm,
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            icon,
            size: 18,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final workingSets = widget.block.workingSets.toList();
    final warmupSets = widget.block.warmupSets.toList();

    final completedWorkingSets = workingSets
        .where(
          (s) => widget.completedSets.any(
            (c) => c.proposedSetId == s.id && c.endedAt != Int64.ZERO,
          ),
        )
        .length;
    final completedWorkingReps = workingSets.fold<int>(0, (sum, s) {
      final completed = widget.completedSets.cast<CompletedSet?>().firstWhere(
        (c) => c!.proposedSetId == s.id && c.endedAt != Int64.ZERO,
        orElse: () => null,
      );
      return sum + (completed?.actualReps ?? 0);
    });
    final targetWorkingRepsMin = workingSets.fold<int>(
      0,
      (sum, s) => sum + s.targetReps,
    );
    final remainingWorkingRepsMin =
        (targetWorkingRepsMin - completedWorkingReps).clamp(0, 1 << 30);
    final completedWarmupSets = warmupSets
        .where(
          (s) => widget.completedSets.any(
            (c) => c.proposedSetId == s.id && c.endedAt != Int64.ZERO,
          ),
        )
        .length;

    final allCompleted =
        workingSets.isNotEmpty && completedWorkingSets == workingSets.length;
    final hasActiveSet = widget.block.sets.any(
      (s) => s.id == widget.activeSetId,
    );
    final isExpanded = hasActiveSet || _isManualExpanded || !allCompleted;

    Color barColor = colorScheme.outline.withValues(alpha: 0.25);
    if (allCompleted) {
      barColor = AppTheme.successFg;
    } else if (hasActiveSet) {
      barColor = _activeLiftFg;
    }

    // ── COLLAPSED (completed) ──────────────────────────────────────────────
    if (allCompleted && !isExpanded) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.4),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status bar
                Container(width: 4, color: barColor),

                // Content
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isManualExpanded = true),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 13,
                            color: AppTheme.successFg,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              (exerciseNames[widget.block.exercise] ??
                                  'Unknown'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: colorScheme.tertiary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Expand button (same width as drag handle)
                GestureDetector(
                  onTap: () => setState(() => _isManualExpanded = true),
                  child: Container(
                    width: 32,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: colorScheme.onSurface.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── EXPANDED (active / upcoming / manually expanded completed) ──────────
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasActiveSet
                ? _activeLiftFg.withValues(alpha: 0.6)
                : colorScheme.outline.withValues(alpha: 0.4),
            width: hasActiveSet ? 1.5 : 1,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status bar
              Container(width: 4, color: barColor),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        (exerciseNames[widget
                                                .block
                                                .exercise] ??
                                            'Unknown'),
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.4,
                                          color: allCompleted
                                              ? colorScheme.tertiary
                                              : colorScheme.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (!widget.isWorkoutEnded &&
                                        widget.onEdit != null)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: _iconActionButton(
                                          icon: Icons.edit_outlined,
                                          onTap: widget.onEdit!,
                                        ),
                                      ),
                                  ],
                                ),
                                Text(
                                  warmupSets.isNotEmpty
                                      ? '$completedWarmupSets/${warmupSets.length} Warmups   $completedWorkingSets/${workingSets.length} Sets'
                                      : '$completedWorkingSets/${workingSets.length} Sets',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                    color: allCompleted
                                        ? AppTheme.successFg
                                        : colorScheme.tertiary,
                                  ),
                                ),
                                if (workingSets.isNotEmpty)
                                  Text(
                                    'Target $targetWorkingRepsMin reps • $completedWorkingReps done • $remainingWorkingRepsMin to go',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.tertiary.withValues(
                                        alpha: 0.72,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: widget.block.sets
                            .map((s) => _buildChip(context, s))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),

              // Right panel: collapse for completed, drag handle for others
              if (allCompleted)
                GestureDetector(
                  onTap: () => setState(() => _isManualExpanded = false),
                  child: Container(
                    width: 32,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 18,
                        color: colorScheme.onSurface.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                )
              else if (!widget.isWorkoutEnded && widget.dragIndex != null)
                ReorderableDragStartListener(
                  index: widget.dragIndex!,
                  child: Container(
                    width: 32,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.drag_indicator,
                        size: 16,
                        color: colorScheme.onSurface.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(BuildContext context, ProposedSet set) {
    final colorScheme = Theme.of(context).colorScheme;
    final completed = widget.completedSets.cast<CompletedSet?>().firstWhere(
      (c) => c!.proposedSetId == set.id && c.endedAt != Int64.ZERO,
      orElse: () => null,
    );
    final isActive = set.id == widget.activeSetId;

    final unit = context.watch<SettingsProvider>().weightUnit;
    final String weight = formatWeight(set.targetWeight.toDouble(), unit);

    Color bg;
    Color fg;
    Color borderColor;
    String text;
    FontWeight fontWeight;

    if (completed != null) {
      final hitTarget = completed.actualReps >= set.targetReps;
      bg = hitTarget ? AppTheme.successBg : AppTheme.warningBg;
      fg = hitTarget ? AppTheme.successFg : AppTheme.warningFg;
      borderColor = fg.withValues(alpha: 0.2);
      text = set.warmup ? 'W' : (hitTarget ? '✓' : '${completed.actualReps}');
      fontWeight = FontWeight.w800;
    } else if (set.warmup) {
      bg = isActive ? AppTheme.warmupLight : Colors.transparent;
      fg = isActive
          ? AppTheme.warmupFg
          : colorScheme.tertiary.withValues(alpha: 0.6);
      borderColor = isActive
          ? AppTheme.warmupFg.withValues(alpha: 0.6)
          : colorScheme.outline.withValues(alpha: 0.25);
      text = 'W:${set.targetReps}@$weight';
      fontWeight = isActive ? FontWeight.w800 : FontWeight.w600;
    } else if (isActive) {
      bg = _activeLiftBg;
      fg = _activeLiftFg;
      borderColor = _activeLiftFg.withValues(alpha: 0.5);
      text = '${set.targetReps}@$weight';
      fontWeight = FontWeight.w800;
    } else {
      bg = Colors.transparent;
      fg = colorScheme.onSurface.withValues(alpha: 0.75);
      borderColor = colorScheme.outline.withValues(alpha: 0.25);
      text = '${set.targetReps}@$weight';
      fontWeight = FontWeight.w600;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: fg,
          fontWeight: fontWeight,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
