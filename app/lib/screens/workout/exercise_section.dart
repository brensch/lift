/// One exercise of the live workout, full width: its name, then its sets
/// as circles in two rows — the warmups, then the working sets — each
/// labelled down its left edge. Nothing about weights here; the banner
/// shows the set you are on, and tapping the name opens the weight sheet.
/// A long press on any part that isn't a button drags the exercise to a new
/// place in the order.
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
import '../../logic/session_state.dart';
import '../../theme/theme_spec.dart';
import 'section_workout.dart';
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
    final calibrating =
        sets.any((s) => s.calibration) &&
        !sets.any((s) => !s.warmup && !s.calibration);

    // The rung just done asks how much was left in the tank; until it is
    // answered the plan below it is undecided, so no other set starts.
    final prompt = w.effortPrompt;
    final asking =
        prompt != null &&
        prompt.calibration &&
        prompt.effort == Effort.EFFORT_UNSPECIFIED;
    final askingHere = asking && prompt.exercise == block.exercise;

    // The up-next circle wears the workout's state colour, like the banner.
    final stateValue = w.stateValue;
    final nextColor = isRestingState(stateValue)
        ? t.workoutRestingFg
        : isYappingState(stateValue)
        ? t.workoutYappingFg
        : t.primary;
    final nextId = w.nextSetId;
    final liftingId = w.liftingSetId;

    Widget circle(ProposedSet set) {
      final done = w.doneFor(set.id);
      final reps = done?.actualReps ?? set.targetReps;
      final SetCircleState state;
      if (done != null) {
        state = reps >= set.targetReps
            ? SetCircleState.full
            : reps == 0
            ? SetCircleState.zero
            : SetCircleState.short;
      } else if (liftingId == set.id) {
        state = SetCircleState.lifting;
      } else if (!asking && nextId == set.id) {
        state = SetCircleState.next;
      } else if (w.isPassedWarmup(set)) {
        state = SetCircleState.skipped;
      } else {
        state = SetCircleState.pending;
      }
      final VoidCallback? onTap;
      if (wp == null) {
        onTap = null;
      } else if (done != null) {
        onTap = () => wp.tapDoneSet(done.id);
      } else if (asking) {
        onTap = null;
      } else if (state == SetCircleState.lifting) {
        onTap = () => wp.completeSet(set.id, set.targetReps, set.targetWeight);
      } else {
        onTap = () => wp.startSet(set.id);
      }
      return SetCircle(
        key: ValueKey('set-circle-${set.id}'),
        number: reps,
        state: state,
        nextColor: nextColor,
        small: set.warmup,
        square: set.calibration,
        onTap: onTap,
      );
    }

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

    // The header: the name (tap it, or the pencil, for the weight sheet),
    // finding weight if it is, and what it's set to now.
    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: _padding),
      child: Row(
        children: [
          // The name takes the room it needs before the target does.
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: GestureDetector(
                    onTap: onEdit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        exerciseNames[block.exercise] ?? '?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: t.size.subtitle,
                          fontWeight: t.weight.bold,
                          color: finished ? t.muted : t.text,
                        ),
                      ),
                    ),
                  ),
                ),
                if (calibrating) ...[
                  const SizedBox(width: 8),
                  Text(
                    copy.workout.calibrationLine.toUpperCase(),
                    style: t.mono(
                      TextStyle(
                        fontSize: t.size.caption,
                        fontWeight: t.weight.bold,
                        letterSpacing: 0.5,
                        color: t.primary,
                      ),
                    ),
                  ),
                ],
              ],
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
          if (askingHere)
            Padding(
              padding: const EdgeInsets.fromLTRB(_padding, 6, _padding, 6),
              child: _RepsLeftQuestion(
                onAnswer: (effort) =>
                    wp?.rateExercise(prompt.completedSetId, effort),
              ),
            ),
        ],
      ),
    );

    // A long press anywhere the circles, name and buttons don't take lifts
    // the exercise to drag it to a new place.
    final background = focused ? t.panel : Colors.transparent;
    final index = dragIndex;
    if (index == null) return ColoredBox(color: background, child: content);
    return Stack(
      children: [
        Positioned.fill(
          child: ReorderableDelayedDragStartListener(
            index: index,
            child: ColoredBox(color: background),
          ),
        ),
        content,
      ],
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

/// After a finding-weight rung: how many more reps were in the tank. Lots
/// climbs a rung; some settles here; none settles one rung back.
class _RepsLeftQuestion extends StatelessWidget {
  final void Function(Effort effort) onAnswer;

  const _RepsLeftQuestion({required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget option(String label, Effort effort) => Expanded(
      child: SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: () => onAnswer(effort),
          style: FilledButton.styleFrom(
            backgroundColor: t.text,
            foregroundColor: t.background,
            padding: EdgeInsets.zero,
          ),
          child: Text(
            label,
            style: t.mono(
              TextStyle(fontSize: t.size.bodyLg, fontWeight: t.weight.bold),
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          copy.workout.repsLeftQuestion,
          style: TextStyle(
            fontSize: t.size.body,
            fontWeight: t.weight.bold,
            color: t.text,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            option(copy.workout.repsLeftNone, Effort.EFFORT_HARD),
            const SizedBox(width: 6),
            option(copy.workout.repsLeftSome, Effort.EFFORT_RIGHT),
            const SizedBox(width: 6),
            option(copy.workout.repsLeftLots, Effort.EFFORT_EASY),
          ],
        ),
      ],
    );
  }
}
