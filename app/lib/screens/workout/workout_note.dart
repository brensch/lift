/// The line of words about the set in hand: on a first workout, what to do
/// now; otherwise, as a lift comes up, why it has the numbers it has. It
/// sits with the exercise it is about, under its name.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/settings.pb.dart' show WeightUnit;
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/plan_text.dart';
import '../../logic/session_state.dart';
import '../../providers/settings_provider.dart';
import '../../providers/workout_provider.dart';
import '../../theme/theme_spec.dart';

/// The first workout's coaching: what the stage on show wants of you.
String _hint(WorkoutProvider wp, int nowUnix) {
  final state = stateAt(wp.stateSnapshot, nowUnix);
  if (state == WorkoutState.WORKOUT_STATE_ALL_DONE ||
      wp.doneTargetSet == null) {
    return copy.workout.hints.allDone;
  }
  return switch (state) {
    WorkoutState.WORKOUT_STATE_LIFTING => copy.workout.hints.lifting,
    WorkoutState.WORKOUT_STATE_RESTING => copy.workout.hints.resting,
    WorkoutState.WORKOUT_STATE_YAPPING => copy.workout.hints.yapping,
    _ => copy.workout.hints.ready,
  };
}

/// Why [set]'s lift has the numbers it has, for as long as it is the lift
/// in hand; '' when there is nothing to say.
String _liftReason(WorkoutProvider wp, ProposedSet? set, WeightUnit unit) {
  if (set == null) return '';
  final decision = wp.logFor(set.exercise)?.decision;
  return decision == null ? '' : reasonShort(decision, unit);
}

/// The line for the workout as it stands now; '' when there is nothing to
/// say.
String workoutNote(WorkoutProvider wp, int nowUnix, WeightUnit unit) =>
    wp.isFirstWorkout
    ? _hint(wp, nowUnix)
    : _liftReason(wp, wp.doneTargetSet, unit);

/// [workoutNote] as a line of text, kept up with the clock (the stages
/// change by time alone); nothing at all when there is nothing to say.
class WorkoutNote extends StatelessWidget {
  const WorkoutNote({super.key});

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    final unit = context.watch<SettingsProvider>().weightUnit;
    final t = context.tokens;
    return ValueListenableBuilder<DateTime>(
      valueListenable: wp.clock,
      builder: (context, now, _) {
        final note = workoutNote(wp, now.millisecondsSinceEpoch ~/ 1000, unit);
        if (note.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            note,
            style: TextStyle(
              fontSize: t.size.body,
              fontWeight: t.weight.medium,
              color: t.text,
            ),
          ),
        );
      },
    );
  }
}
