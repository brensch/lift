/// The banner's question after a set that asks how it went (a ramp set, or
/// a lift's last set with an effort target): Easy, Hard or Fail, in the row
/// the weight and reps take. No dialog, so the watch asks it the same way;
/// doing the next set moves on without an answer.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/wearable.pb.dart' show QuickAnswer;
import '../../providers/workout_provider.dart';
import '../../theme/theme_spec.dart';

class QuickQuestion extends StatelessWidget {
  final String setId;

  const QuickQuestion({super.key, required this.setId});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final w = copy.workout;
    final wp = context.read<WorkoutProvider>();
    final answers = [
      (QuickAnswer.QUICK_ANSWER_EASY, w.quickEasy),
      (QuickAnswer.QUICK_ANSWER_HARD, w.quickHard),
      (QuickAnswer.QUICK_ANSWER_FAIL, w.quickFail),
    ];
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
        for (final (answer, label) in answers) ...[
          Expanded(
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
          ),
          if (answer != QuickAnswer.QUICK_ANSWER_FAIL) const SizedBox(width: 6),
        ],
      ],
    );
  }
}
