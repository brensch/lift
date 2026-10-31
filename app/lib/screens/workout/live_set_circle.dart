/// A set's circle, live: drawn from the workout and wired to it. The
/// exercise list and your status box show the same circle, and a tap on
/// either does the same thing.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercises.dart';
import '../../logic/session_state.dart';
import '../../logic/weight_units.dart';
import '../../providers/settings_provider.dart';
import '../../providers/workout_provider.dart';
import '../../theme/theme_spec.dart';
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
    } else if (_firstEver(w, set)) {
      onTap = () => showFirstTimeDialog(context, wp, set);
    } else {
      onTap = () => wp.startSet(set.id);
    }
    return SetCircle(
      number: reps,
      state: state,
      nextColor: nextColor,
      small: set.warmup,
      onTap: onTap,
    );
  }

  /// The opening set of an exercise never done before: nothing of its
  /// finding-weight sets is lifted yet.
  static bool _firstEver(SectionWorkout w, ProposedSet set) =>
      set.calibration &&
      !w.proposedSets.any(
        (s) =>
            s.exercise == set.exercise &&
            s.calibration &&
            w.doneFor(s.id) != null,
      );
}

/// First time doing an exercise: give the weight you lift (the working sets
/// start there, warmups first) or let the finding-weight sets work it out.
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
  late final TextEditingController _weight;

  @override
  void initState() {
    super.initState();
    // What their strength answer at sign-up put this lift at.
    final unit = context.read<SettingsProvider>().weightUnit;
    final seed =
        widget.wp.trackerFor(widget.set.exercise)?.workingWeight ??
        widget.set.targetWeight;
    _weight = TextEditingController(text: formatWeight(seed, unit));
  }

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  void _lift() {
    final unit = context.read<SettingsProvider>().weightUnit;
    final value = double.tryParse(_weight.text.trim());
    if (value == null || value <= 0) return;
    Navigator.pop(context);
    widget.wp.adjustExerciseWeight(
      widget.set.exercise,
      poundsFromDisplayWeight(value, unit),
    );
  }

  void _test() {
    Navigator.pop(context);
    widget.wp.startSet(widget.set.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final w = copy.workout;
    final name = exerciseNames[widget.set.exercise] ?? '?';
    final label = TextStyle(
      fontSize: t.size.bodyLg,
      fontWeight: t.weight.heavy,
    );
    return AlertDialog(
      title: Text(
        w.firstTimeTitle.replaceAll('{exercise}', name),
        style: TextStyle(fontSize: t.size.title, fontWeight: t.weight.heavy),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _lift,
                    child: Text(w.firstTimeLift, style: label),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 112,
                child: TextField(
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  textAlign: TextAlign.center,
                  onSubmitted: (_) => _lift(),
                  style: t.mono(
                    TextStyle(
                      fontSize: t.size.title,
                      fontWeight: t.weight.bold,
                    ),
                  ),
                  decoration: InputDecoration(
                    suffixText: weightUnitSuffix(unit),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: _test,
              child: Text(w.firstTimeTest, style: label),
            ),
          ),
        ],
      ),
    );
  }
}
