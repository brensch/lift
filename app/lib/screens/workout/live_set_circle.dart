/// A set's circle, live: drawn from the workout and wired to it. The
/// exercise list and your status box show the same circle, and a tap on
/// either does the same thing.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/weight_units.dart';
import '../../providers/settings_provider.dart';
import '../../logic/exercises.dart';
import '../../providers/workout_provider.dart';
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
    final nextColor = switch (w.state) {
      WorkoutState.WORKOUT_STATE_RESTING => t.resting,
      WorkoutState.WORKOUT_STATE_YAPPING => t.yapping,
      _ => t.primary,
    };

    final done = w.doneFor(set.id);
    final reps = done?.actualReps ?? set.targetReps;
    final state = setCircleState(w, set);

    final VoidCallback? onTap;
    if (wp == null) {
      onTap = null;
    } else if (done == null &&
        state != SetCircleState.lifting &&
        w.isFirstTime(set)) {
      onTap = () => showFirstTimeDialog(context, wp, set);
    } else {
      onTap = () => tapSet(wp, w, set);
    }
    return SetCircle(
      number: reps,
      state: state,
      // Nothing known yet about a first-ever exercise.
      text: done == null && w.isFirstTime(set) ? '?' : null,
      nextColor: nextColor,
      small: set.warmup,
      onTap: onTap,
    );
  }

  /// What a set's circle shows: done in full, short or zero; being lifted;
  /// up next; a warmup passed; or still to do. The watch draws the same.
  static SetCircleState setCircleState(SectionWorkout w, ProposedSet set) {
    final done = w.doneFor(set.id);
    if (done != null) {
      return done.actualReps >= set.targetReps
          ? SetCircleState.full
          : done.actualReps == 0
          ? SetCircleState.zero
          : SetCircleState.short;
    }
    if (w.liftingSetId == set.id) return SetCircleState.lifting;
    if (w.nextSetId == set.id) return SetCircleState.next;
    if (w.isPassedWarmup(set)) return SetCircleState.skipped;
    return SetCircleState.pending;
  }

  /// A tap on a set's circle: a done set loses a rep (and after zero is
  /// undone), the set being lifted is done with every rep, anything else
  /// starts. The watch's taps run this too; a first-ever exercise waits on
  /// the phone, which asks for the weight first.
  static Future<void> tapSet(
    WorkoutProvider wp,
    SectionWorkout w,
    ProposedSet set,
  ) {
    final done = w.doneFor(set.id);
    if (done != null) return wp.tapDoneSet(done.id);
    if (w.liftingSetId == set.id) {
      return wp.completeSet(set.id, set.targetReps, set.targetWeight);
    }
    return wp.startSet(set.id);
  }
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
  /// Where the ramp starts, in lb: its first set as planned, or wherever
  /// the user moves it.
  late double _weightLb = widget.set.targetWeight;

  bool get _barbell =>
      widget.wp.equipmentOf(widget.set.exercise) ==
      EquipmentKind.EQUIPMENT_KIND_BARBELL;

  /// The ramp from the weight picked: its first set moved there when it
  /// isn't the planned one, then started. Right first time, it's one set.
  Future<void> _test() async {
    Navigator.pop(context);
    if (_weightLb != widget.set.targetWeight) {
      await widget.wp.adjustExerciseWeight(widget.set.exercise, _weightLb);
    }
    await widget.wp.startSet(widget.set.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final w = copy.workout;
    final name = exerciseName(widget.set.exercise);
    final unit = context.watch<SettingsProvider>().weightUnit;
    final label = TextStyle(
      fontSize: t.size.bodyLg,
      fontWeight: t.weight.heavy,
    );
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      // The dialog's corners clip the selector's lines, which run edge to
      // edge as they do in the sheets; the title and the button are inset.
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                w.firstTimeTitle.replaceAll('{exercise}', name),
                style: TextStyle(
                  fontSize: t.size.titleLg,
                  fontWeight: t.weight.heavy,
                  color: t.text,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Where the ramp starts: as planned, or moved.
            WeightSelector(
              weightLb: _weightLb,
              stepLb: widget.wp.weightStepOf(widget.set.exercise),
              barbell: _barbell,
              onChanged: (lb) => setState(() => _weightLb = lb),
            ),
            const SizedBox(height: 16),
            Container(
              height: 56,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton(
                onPressed: _weightLb > 0 ? _test : null,
                child: Text(
                  w.firstTimeTest.replaceAll(
                    '{weight}',
                    formatWeight(_weightLb, unit, includeUnit: true),
                  ),
                  style: label,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
