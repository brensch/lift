/// One exercise of the live workout, full width: its name, what it's set
/// to (weight × reps) with a pencil for the weight sheet and a grip to drag
/// it to a new place in the order, then its sets as circles in two rows —
/// the warmups, then the working sets — each labelled down its left edge.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercise_blocks.dart';
import '../../logic/exercises.dart';
import '../../theme/app_icons.dart';
import '../../providers/settings_provider.dart';
import '../../logic/set_labels.dart';
import '../../theme/theme_spec.dart';
import 'section_workout.dart';
import 'live_set_circle.dart';
import 'set_circle.dart';

const double _padding = 16;
const double _circleGap = 10;
// Room around the circles for the lifting glow.
const double _glow = 8;

class ExerciseSection extends StatelessWidget {
  final ExerciseBlock block;

  /// The workout it belongs to: yours (tappable) or a partner's.
  final SectionWorkout workout;

  /// The exercise the next set belongs to: drawn on the panel colour.
  final bool focused;

  /// Every set of it is done.
  final bool finished;

  /// Set for a section that can be dragged to a new place in the order.
  final int? dragIndex;

  /// Opens the weight sheet (change the weight, or remove the exercise).
  final VoidCallback? onEdit;

  const ExerciseSection({
    super.key,
    required this.block,
    required this.workout,
    required this.focused,
    required this.finished,
    this.dragIndex,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final w = workout;
    final wp = w.actions;
    final live = wp != null;
    final sets = block.sets.where((s) => !s.cancelled).toList();
    final warmups = sets.where((s) => s.warmup).toList();
    final working = sets.where((s) => !s.warmup).toList();
    final openWarmups = warmups.any(
      (s) => !w.isDone(s.id) && !w.isPassedWarmup(s),
    );

    final nextId = w.nextSetId;
    final liftingId = w.liftingSetId;

    Widget circle(ProposedSet set) => LiveSetCircle(
      key: ValueKey('set-circle-${set.id}'),
      workout: w,
      set: set,
    );

    // The set a row follows: the one being lifted or up next, if it is in
    // that row.
    String? followIn(List<ProposedSet> row) {
      for (final id in [liftingId, nextId]) {
        if (id != null && row.any((s) => s.id == id)) return id;
      }
      return null;
    }

    // What it's set to now: the next working set still to do (or the last,
    // once all are done); mid-ramp, the rung.
    final unit = context.watch<SettingsProvider>().weightUnit;
    final targetSet =
        working.where((s) => !w.isDone(s.id)).firstOrNull ?? working.lastOrNull;

    // The header: the name (tap it, or the pencil, for the weight sheet)
    // and what it's set to now.
    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: _padding),
      child: Row(
        children: [
          // The name takes the room it needs before the target does.
          Expanded(
            child: GestureDetector(
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exerciseNames[block.exercise] ?? '?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: t.size.subtitle,
                        fontWeight: t.weight.bold,
                        color: finished ? t.muted : t.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // The pencil, then the target flush with the right margin.
          if (live && onEdit != null)
            IconButton(
              tooltip: 'Weight and reps',
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
              icon: Icon(AppIcons.edit, size: t.size.title, color: t.muted),
            ),
          if (targetSet != null)
            Text(
              setTextFor(targetSet, unit),
              style: t.mono(
                TextStyle(
                  fontSize: t.size.body,
                  fontWeight: t.weight.bold,
                  color: finished ? t.muted : t.text,
                ),
              ),
            ),
          // The grip: drags the exercise straight away.
          if (dragIndex != null)
            ReorderableDragStartListener(
              index: dragIndex!,
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Icon(AppIcons.drag, size: t.size.title, color: t.muted),
              ),
            ),
        ],
      ),
    );

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          // A finished exercise steps back so the one in hand stands out.
          Opacity(
            opacity: finished ? 0.45 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (warmups.isNotEmpty)
                  _CircleRow(
                    label: copy.workout.warmupLabel,
                    follow: followIn(warmups),
                    ids: [for (final s in warmups) s.id],
                    trailing: wp != null && openWarmups
                        ? _SkipButton(
                            onTap: () => wp.skipWarmups(block.exercise),
                          )
                        : null,
                    children: [for (final s in warmups) circle(s)],
                  ),
                _CircleRow(
                  label: copy.workout.workingLabel,
                  follow: followIn(working),
                  ids: [for (final s in working) s.id],
                  children: [for (final s in working) circle(s)],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return ColoredBox(
      color: focused ? t.panel : Colors.transparent,
      child: content,
    );
  }
}

/// One row of circles with its label written down its left edge. It
/// scrolls sideways when there are more than fit, and follows the set in
/// hand: that circle moves to the left so what's left is in view.
class _CircleRow extends StatefulWidget {
  final String label;
  final List<Widget> children;

  /// The set ids of [children], in order.
  final List<String> ids;

  /// The set to keep at the left, if it's in this row.
  final String? follow;

  /// After the circles (the warmups' skip button).
  final Widget? trailing;

  const _CircleRow({
    required this.label,
    required this.children,
    required this.ids,
    this.follow,
    this.trailing,
  });

  @override
  State<_CircleRow> createState() => _CircleRowState();
}

class _CircleRowState extends State<_CircleRow> {
  final _scroll = ScrollController();
  String? _followed;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _follow() {
    final id = widget.follow;
    if (id == null || id == _followed) return;
    _followed = id;
    final index = widget.ids.indexOf(id);
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        (index * (SetCircle.diameter + _circleGap)).clamp(
          0.0,
          _scroll.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    _follow();
    return Row(
      children: [
        // The label down the left edge, as narrow as it gets.
        SizedBox(
          width: _padding + 6,
          child: Center(
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                widget.label,
                maxLines: 1,
                style: t.mono(
                  TextStyle(
                    fontSize: t.size.caption,
                    fontWeight: t.weight.bold,
                    letterSpacing: 1,
                    color: t.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(4, _glow, _padding, _glow),
            child: Row(
              children: [
                for (var i = 0; i < widget.children.length; i++) ...[
                  if (i > 0) const SizedBox(width: _circleGap),
                  widget.children[i],
                ],
                if (widget.trailing != null) ...[
                  const SizedBox(width: _circleGap + 4),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Skip" at the end of the warmup row: skips the undone warmups.
class _SkipButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SkipButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: SetCircle.diameter,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: t.outline),
          borderRadius: t.brSm,
        ),
        child: Text(
          copy.workout.skipWarmups,
          style: TextStyle(
            fontSize: t.size.body,
            fontWeight: t.weight.bold,
            color: t.muted,
          ),
        ),
      ),
    );
  }
}
