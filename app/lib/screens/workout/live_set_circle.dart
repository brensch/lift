/// A set's circle, live: drawn from the workout and wired to it. The
/// exercise list and your status box show the same circle, and a tap on
/// either does the same thing.
library;

import 'package:flutter/material.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercises.dart';
import '../../logic/session_state.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme_spec.dart';
import '../../widgets/common/weight_selector.dart';
import 'section_workout.dart';
import 'set_circle.dart';

class LiveSetCircle extends StatelessWidget {
  final SectionWorkout workout;
  final ProposedSet set;

  const LiveSetCircle({super.key, required this.workout, required this.set});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final w = workout;
    final wp = w.actions;

    // The up-next circle wears the workout's state colour, like the banner.
    final stateValue = w.stateValue;
    final nextColor = isRestingState(stateValue)
        ? t.workoutRestingFg
        : isYappingState(stateValue)
        ? t.workoutYappingFg
        : t.primary;

    final done = w.doneFor(set.id);
    final reps = done?.actualReps ?? set.targetReps;
    final SetCircleState state;
    if (done != null) {
      state = reps >= set.targetReps
          ? SetCircleState.full
          : reps == 0
          ? SetCircleState.zero
          : SetCircleState.short;
    } else if (w.liftingSetId == set.id) {
      state = SetCircleState.lifting;
    } else if (w.nextSetId == set.id) {
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
    } else if (state == SetCircleState.lifting) {
      onTap = () => wp.completeSet(set.id, set.targetReps, set.targetWeight);
    } else if (isFirstEver(w, set)) {
      onTap = () => showFirstTimeDialog(context, wp, set);
    } else {
      onTap = () => wp.startSet(set.id);
    }
    return SetCircle(
      number: reps,
      state: state,
      // Nothing known yet about a first-ever exercise.
      text: done == null && isFirstEver(w, set) ? '?' : null,
      nextColor: nextColor,
      small: set.warmup,
      onTap: onTap,
    );
  }

  /// The opening set of an exercise never done before: nothing of its
  /// calibration sets is lifted yet.
  static bool isFirstEver(SectionWorkout w, ProposedSet set) =>
      set.calibration &&
      !w.proposedSets.any(
        (s) =>
            s.exercise == set.exercise &&
            s.calibration &&
            w.doneFor(s.id) != null,
      );
}

/// First time doing an exercise: give the weight you lift (the working sets
/// start there, warmups first) or let the calibration sets work it out.
Future<void> showFirstTimeDialog(
  BuildContext context,
  WorkoutProvider wp,
  ProposedSet set,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _FirstTimeDialog(wp: wp, set: set),
  );
}

class _FirstTimeDialog extends StatefulWidget {
  final WorkoutProvider wp;
  final ProposedSet set;

  const _FirstTimeDialog({required this.wp, required this.set});

  @override
  State<_FirstTimeDialog> createState() => _FirstTimeDialogState();
}

class _FirstTimeDialogState extends State<_FirstTimeDialog> {
  /// What their strength answer at sign-up put this lift at, in lb.
  late double _weightLb =
      widget.wp.trackerFor(widget.set.exercise)?.workingWeight ??
      widget.set.targetWeight;

  bool get _barbell =>
      widget.wp.trackerFor(widget.set.exercise)?.equipment ==
      EquipmentKind.EQUIPMENT_KIND_BARBELL;

  void _lift() {
    if (_weightLb <= 0) return;
    Navigator.pop(context);
    widget.wp.adjustExerciseWeight(widget.set.exercise, _weightLb);
  }

  void _test() {
    Navigator.pop(context);
    widget.wp.startSet(widget.set.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final w = copy.workout;
    final name = exerciseNames[widget.set.exercise] ?? '?';
    final label = TextStyle(
      fontSize: t.size.bodyLg,
      fontWeight: t.weight.heavy,
      color: t.text,
    );
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              w.firstTimeTitle.replaceAll('{exercise}', name),
              style: TextStyle(
                fontSize: t.size.titleLg,
                fontWeight: t.weight.heavy,
                color: t.text,
              ),
            ),
            const SizedBox(height: 16),
            // You know your weight: set it, go.
            Text(w.firstTimeLift, style: label),
            const SizedBox(height: 8),
            WeightSelector(
              weightLb: _weightLb,
              barbell: _barbell,
              onChanged: (lb) => setState(() => _weightLb = lb),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _weightLb > 0 ? _lift : null,
                child: const Icon(AppIcons.forward),
              ),
            ),
            const SizedBox(height: 20),
            // You don't: the calibration sets find it.
            SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: _test,
                child: Text(w.firstTimeTest, style: label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
