/// The full exercise list for the workout: reorderable groups, add-exercise affordance, connectors and hints.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercise_groups.dart';
import '../../logic/exercises.dart';
import '../../logic/weight_units.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';

class ExerciseListCard extends StatelessWidget {
  static const double height = 52;

  final ExerciseGroupData group;
  final bool completed;
  final bool draggable;
  final int dragIndex;
  final VoidCallback? onEdit;

  const ExerciseListCard({super.key, 
    required this.group,
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

    Widget content = Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(draggable ? 2 : 12, 0, 4, 0),
      alignment: Alignment.centerLeft,
      child: Column(
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
          const SizedBox(height: 3),
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
        ],
      ),
    );

    // Draggable rows carry a grip on the left so they read as grabbable at a
    // glance. The whole body (grip + content) is the drag target — you can grab
    // anywhere — but the handle is the visible cue. Completed rows have no grip
    // (they show a ✓ and don't move), which separates movable from pinned.
    Widget body = content;
    if (draggable) {
      body = ReorderableDragStartListener(
        index: dragIndex,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(
                Icons.drag_indicator,
                size: 20,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      );
    }

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: completed
              ? AppTheme.successBg
              : colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: completed
                ? AppTheme.successFg.withValues(alpha: 0.35)
                : colorScheme.outline.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: body),
            if (completed)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: AppTheme.successFg,
                ),
              )
            else ...[
              IconButton(
                onPressed: onEdit,
                tooltip: 'Edit exercise',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 2),
            ],
          ],
        ),
      ),
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
          radius: 14,
          strokeWidth: 1.5,
          dash: 5,
          gap: 4,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
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
