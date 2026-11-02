/// A ramp set done with every rep: "how many more could you have done?".
/// 0–1 ends the ramp there; 2–3 and 4+ pick the next set's weight.
/// Dismissed, it stays unanswered and the ramp climbs as usual.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../providers/workout_provider.dart';
import '../../theme/theme_spec.dart';

/// Ask about the ramp set [proposedSetId], over whatever is on screen.
Future<void> showRungQuestionDialog(
  BuildContext context,
  WorkoutProvider wp,
  String proposedSetId,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => ChangeNotifierProvider.value(
      value: wp,
      child: RungQuestionDialog(proposedSetId: proposedSetId),
    ),
  );
}

class RungQuestionDialog extends StatelessWidget {
  final String proposedSetId;

  const RungQuestionDialog({super.key, required this.proposedSetId});

  static List<(RepsLeft, String)> get answers => [
    (RepsLeft.REPS_LEFT_ZERO_TO_ONE, copy.workout.rungAnswerZeroToOne),
    (RepsLeft.REPS_LEFT_TWO_TO_FOUR, copy.workout.rungAnswerTwoToFour),
    (RepsLeft.REPS_LEFT_FIVE_PLUS, copy.workout.rungAnswerFivePlus),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final w = copy.workout;
    final wp = context.watch<WorkoutProvider>();
    // Answered on the watch, or the next set started: nothing left to ask.
    if (wp.rungQuestionSetId != proposedSetId) {
      // This dialog's own route, never whatever is under it.
      final route = ModalRoute.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route != null && route.isActive && context.mounted) {
          Navigator.of(context).removeRoute(route);
        }
      });
    }
    final label = TextStyle(
      fontSize: t.size.titleLg,
      fontWeight: t.weight.heavy,
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
              w.rungQuestion,
              style: TextStyle(
                fontSize: t.size.titleLg,
                fontWeight: t.weight.heavy,
                color: t.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              w.rungQuestionHint,
              style: TextStyle(fontSize: t.size.body, color: t.muted),
            ),
            const SizedBox(height: 16),
            for (final (repsLeft, text) in answers) ...[
              SizedBox(
                height: 64,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    wp.answerRung(proposedSetId, repsLeft);
                  },
                  child: Text(text, style: label),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
