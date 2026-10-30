import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercise_blocks.dart';
import '../logic/exercises.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import '../theme/theme_spec.dart';
import '../theme/app_icons.dart';

/// Read-only view of one exercise's block of sets — used for looking at a
/// session partner's workout. Your own workout renders through
/// ExerciseListCard / CurrentExerciseCard instead.
class ExerciseBlockWidget extends StatefulWidget {
  final ExerciseBlock block;
  final List<CompletedSet> completedSets;

  /// The partner's next pending set, drawn a touch bolder than the rest.
  final String? nextSetId;

  const ExerciseBlockWidget({
    super.key,
    required this.block,
    required this.completedSets,
    this.nextSetId,
  });

  @override
  State<ExerciseBlockWidget> createState() => _ExerciseBlockWidgetState();
}

class _ExerciseBlockWidgetState extends State<ExerciseBlockWidget> {
  bool _isManualExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final workingSets = widget.block.workingSets.toList();
    final warmupSets = widget.block.warmupSets.toList();

    final completedWorkingSets = workingSets
        .where((s) => widget.completedSets.any((c) => c.proposedSetId == s.id))
        .length;
    final completedWorkingReps = workingSets.fold<int>(0, (sum, s) {
      final completed = widget.completedSets.cast<CompletedSet?>().firstWhere(
        (c) => c!.proposedSetId == s.id,
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
        .where((s) => widget.completedSets.any((c) => c.proposedSetId == s.id))
        .length;

    final allCompleted =
        workingSets.isNotEmpty && completedWorkingSets == workingSets.length;
    final isExpanded = _isManualExpanded || !allCompleted;

    final barColor = allCompleted
        ? context.tokens.successFg
        : colorScheme.outline.withValues(alpha: 0.25);

    // ── COLLAPSED (completed) ──────────────────────────────────────────────
    if (allCompleted && !isExpanded) {
      return ClipRRect(
        borderRadius: context.tokens.br(8),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: context.tokens.br(8),
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
                            AppIcons.checkCircle,
                            size: 13,
                            color: context.tokens.successFg,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              (exerciseNames[widget.block.exercise] ??
                                  'Unknown'),
                              style: TextStyle(
                                fontSize: context.tokens.size.bodyLg,
                                fontWeight: context.tokens.weight.heavy,
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
                        AppIcons.expandDown,
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

    // ── EXPANDED (upcoming / manually expanded completed) ───────────────────
    return ClipRRect(
      borderRadius: context.tokens.br(8),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: context.tokens.br(8),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.4)),
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
                                        (exerciseNames[widget.block.exercise] ??
                                            'Unknown'),
                                        style: TextStyle(
                                          fontSize:
                                              context.tokens.size.subtitle,
                                          fontWeight:
                                              context.tokens.weight.heavy,
                                          letterSpacing: -0.4,
                                          color: allCompleted
                                              ? colorScheme.tertiary
                                              : colorScheme.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  warmupSets.isNotEmpty
                                      ? '$completedWarmupSets/${warmupSets.length} Warmups   $completedWorkingSets/${workingSets.length} Sets'
                                      : '$completedWorkingSets/${workingSets.length} Sets',
                                  style: TextStyle(
                                    fontSize: context.tokens.size.small,
                                    fontWeight: context.tokens.weight.bold,
                                    letterSpacing: 0.4,
                                    color: allCompleted
                                        ? context.tokens.successFg
                                        : colorScheme.tertiary,
                                  ),
                                ),
                                if (workingSets.isNotEmpty)
                                  Text(
                                    'Target $targetWorkingRepsMin reps • $completedWorkingReps done • $remainingWorkingRepsMin to go',
                                    style: TextStyle(
                                      fontSize: context.tokens.size.small,
                                      fontWeight: context.tokens.weight.bold,
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

              // Right panel: collapse toggle for completed blocks.
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
                        AppIcons.expandUp,
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

  Widget _buildChip(BuildContext context, ProposedSet set) {
    final colorScheme = Theme.of(context).colorScheme;
    final completed = widget.completedSets.cast<CompletedSet?>().firstWhere(
      (c) => c!.proposedSetId == set.id,
      orElse: () => null,
    );
    final isNext = set.id == widget.nextSetId;

    final unit = context.watch<SettingsProvider>().weightUnit;
    final String weight = formatWeight(set.targetWeight.toDouble(), unit);

    Color bg;
    Color fg;
    Color borderColor;
    String text;
    FontWeight fontWeight;

    if (completed != null) {
      final hitTarget = completed.actualReps >= set.targetReps;
      bg = hitTarget ? context.tokens.successBg : context.tokens.warningBg;
      fg = hitTarget ? context.tokens.successFg : context.tokens.warningFg;
      borderColor = fg.withValues(alpha: 0.2);
      text = set.warmup ? 'W' : (hitTarget ? '✓' : '${completed.actualReps}');
      fontWeight = context.tokens.weight.heavy;
    } else if (set.warmup) {
      bg = isNext ? context.tokens.warmupLight : Colors.transparent;
      fg = isNext
          ? context.tokens.warmupFg
          : colorScheme.tertiary.withValues(alpha: 0.6);
      borderColor = isNext
          ? context.tokens.warmupFg.withValues(alpha: 0.6)
          : colorScheme.outline.withValues(alpha: 0.25);
      text = 'W:${set.targetReps}@$weight';
      fontWeight = isNext
          ? context.tokens.weight.heavy
          : context.tokens.weight.bold;
    } else {
      bg = Colors.transparent;
      fg = colorScheme.onSurface.withValues(alpha: isNext ? 1 : 0.75);
      borderColor = colorScheme.outline.withValues(alpha: isNext ? 0.6 : 0.25);
      text = '${set.targetReps}@$weight';
      fontWeight = isNext
          ? context.tokens.weight.heavy
          : context.tokens.weight.bold;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: borderColor),
        borderRadius: context.tokens.br(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: context.tokens.size.body,
          color: fg,
          fontWeight: fontWeight,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
