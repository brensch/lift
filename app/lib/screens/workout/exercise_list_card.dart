/// The full exercise list for the workout: reorderable groups, add-exercise affordance, connectors and hints.
library;

import 'dart:math' as math;
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercise_groups.dart';
import '../../logic/exercises.dart';
import '../../logic/weight_units.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';

class ExerciseListCard extends StatelessWidget {
  static const double height = 62;

  final ExerciseGroupData group;
  final List<CompletedSet> completedSets;
  final bool completed;
  final bool draggable;
  final int dragIndex;

  /// Tapping the row opens the edit modal (there's no pencil any more — the row
  /// itself is the target). The left rail is the drag handle for reordering.
  final VoidCallback? onEdit;

  const ExerciseListCard({
    super.key,
    required this.group,
    this.completedSets = const [],
    required this.completed,
    required this.draggable,
    this.dragIndex = 0,
    this.onEdit,
  });

  ProposedSet? _topWorkingSet() {
    ProposedSet? top;
    for (final set in group.sets.where((set) => !set.warmup)) {
      if (top == null || set.targetWeight > top.targetWeight) {
        top = set;
      }
    }
    return top;
  }

  /// Completed vs total working *rounds* (a round is one set of every exercise,
  /// so supersets count once per pass, not per exercise).
  (int, int) _workingProgress() {
    final rounds = group.rounds.where((r) => !r.isWarmup).toList();
    var done = 0;
    for (final round in rounds) {
      final allDone = round.sets.every(
        (s) => completedSets.any(
          (c) => c.proposedSetId == s.id && c.endedAt != Int64.ZERO,
        ),
      );
      if (allDone) done++;
    }
    return (done, rounds.length);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final title =
        group.group?.name ?? exerciseNames[group.exercise] ?? 'Exercise';
    final topSet = _topWorkingSet();
    final weightLabel = topSet == null
        ? '—'
        : formatWeight(topSet.targetWeight.toDouble(), unit, includeUnit: true);
    final repsLabel = topSet == null
        ? null
        : (topSet.isAmrap ? '${topSet.targetReps}+' : '${topSet.targetReps}');
    final contentColor = completed ? AppTheme.successFg : colorScheme.onSurface;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: -0.3,
            height: 1.05,
            color: contentColor,
          ),
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: weightLabel),
              if (repsLabel != null)
                TextSpan(
                  text: ' × $repsLabel',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
            color: contentColor.withValues(alpha: completed ? 0.85 : 1),
          ),
        ),
        if (!completed) ...[
          const SizedBox(height: 4),
          _ProgressDots(progress: _workingProgress()),
        ],
      ],
    );

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: completed
              ? AppTheme.successBg
              : colorScheme.surfaceContainerLowest,
          borderRadius: AppTheme.brMd,
          border: Border.all(
            color: completed
                ? AppTheme.successFg.withValues(alpha: 0.35)
                : colorScheme.outline.withValues(alpha: 0.45),
          ),
        ),
        child: ClipRRect(
          borderRadius: AppTheme.brMd,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The grab rail: a faint recessed strip down the left edge, so the
              // whole edge reads as the handle rather than a floating icon.
              if (draggable)
                ReorderableDragStartListener(
                  index: dragIndex,
                  child: _GrabRail(color: colorScheme.onSurfaceVariant),
                ),
              // Tap the body to edit (no pencil); drag the rail to reorder.
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: completed ? null : onEdit,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(draggable ? 10 : 12, 0, 8, 0),
                    child: Align(alignment: Alignment.centerLeft, child: body),
                  ),
                ),
              ),
              if (completed)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppTheme.successFg,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The slim grab rail — a recessed strip with a subtle 6-dot grip.
class _GrabRail extends StatelessWidget {
  final Color color;
  const _GrabRail({required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dotColor = color.withValues(alpha: 0.5);
    Widget dot() => Container(
      width: 2.4,
      height: 2.4,
      decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
    );
    Widget pair() => Row(
      mainAxisSize: MainAxisSize.min,
      children: [dot(), const SizedBox(width: 3), dot()],
    );
    return Container(
      width: 18,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        border: Border(
          right: BorderSide(color: cs.outline.withValues(alpha: 0.22)),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [pair(), const SizedBox(height: 3), pair(), const SizedBox(height: 3), pair()],
        ),
      ),
    );
  }
}

/// One dot per working round, filled up to the number completed. Falls back to
/// a compact "3 / 12" for high set counts where a dot row would be too wide.
class _ProgressDots extends StatelessWidget {
  final (int, int) progress;
  const _ProgressDots({required this.progress});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (done, total) = progress;
    if (total == 0) return const SizedBox.shrink();
    final offColor = cs.onSurface.withValues(alpha: 0.16);
    if (total > 6) {
      return Text(
        '$done / $total',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
          color: cs.onSurface.withValues(alpha: 0.5),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < total; i++)
          Padding(
            padding: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < done ? AppTheme.successFg : offColor,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Add-exercise button (dashed, same shape as the list cards) ─────────────

class AddExerciseButton extends StatelessWidget {
  final VoidCallback onTap;

  const AddExerciseButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = colorScheme.outline.withValues(alpha: 0.7);
    return SizedBox(
      height: ExerciseListCard.height,
      child: CustomPaint(
        painter: DashedRRectPainter(
          color: color,
          radius: AppTheme.radiusMd,
          strokeWidth: 1.5,
          dash: 5,
          gap: 4,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppTheme.brMd,
            onTap: onTap,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Add',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final source = Path()..addRRect(rrect);
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final len = math.min(dash, metric.length - distance);
        canvas.drawPath(metric.extractPath(distance, distance + len), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedRRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap;
}

// ─── Reorder affordance hint ───────────────────────────────────────────────

class ReorderHint extends StatelessWidget {
  const ReorderHint({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withValues(
      alpha: 0.32,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.swap_vert_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            'drag to reorder',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── No heart-rate monitor placeholder ─────────────────────────────────────

/// Joins the Current detail card (left) to the current list item (right) as if
/// their borders continue across the gap: same colour and weight as the card
/// borders, overlapping both edges so it reads as one connected outline.
class BracketConnector extends StatelessWidget {
  final Color color;
  const BracketConnector({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 1.5,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
