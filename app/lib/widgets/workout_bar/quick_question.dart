/// The banner's question after a set that asks how it went (a ramp set, or
/// a lift's last set with an effort target), in the row the weight and reps
/// take: Easy, Hard, and the set's own circle, which takes a rep off per
/// tap when they weren't all there. A rep off is a miss, which closes the
/// question: the circle stays, alone, for the next tap, until the next set
/// starts. No dialog, so the watch asks it the same way.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/wearable.pb.dart' show QuickAnswer;
import '../../logic/set_labels.dart';
import '../../providers/workout_provider.dart';
import '../../screens/workout/live_set_circle.dart';
import '../../screens/workout/section_workout.dart';
import '../../screens/workout/set_circle.dart';
import '../../theme/theme_spec.dart';

class QuickQuestion extends StatelessWidget {
  final String setId;

  const QuickQuestion({super.key, required this.setId});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final w = copy.workout;
    final wp = context.watch<WorkoutProvider>();
    final set = wp.proposedSetById(setId);
    final open = wp.questionSetId == setId;
    final reps = wp.askingReps;
    Widget answer(QuickAnswer answer, String label) => Expanded(
      child: SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: () => wp.answerQuick(setId, answer),
          style: FilledButton.styleFrom(padding: EdgeInsets.zero),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: t.size.bodyLg,
                fontWeight: t.weight.heavy,
              ),
            ),
          ),
        ),
      ),
    );
    return Row(
      children: [
        Text(
          w.quickQuestion,
          style: TextStyle(
            fontSize: t.size.subtitle,
            fontWeight: t.weight.medium,
            color: t.muted,
          ),
        ),
        const SizedBox(width: 10),
        if (open) ...[
          answer(QuickAnswer.QUICK_ANSWER_EASY, w.quickEasy),
          const SizedBox(width: 6),
          answer(QuickAnswer.QUICK_ANSWER_HARD, w.quickHard),
          const SizedBox(width: 10),
        ] else
          const Spacer(),
        if (set != null)
          SetCircle(
            number: reps,
            state: LiveSetCircle.setCircleState(SectionWorkout.mine(wp), set),
            text: needsLabel(set) ? repsLabel(set, reps, done: true) : null,
            onTap: reps > 0
                ? () => wp.answerQuick(setId, QuickAnswer.QUICK_ANSWER_ONE_LESS)
                : null,
          ),
      ],
    );
  }
}
