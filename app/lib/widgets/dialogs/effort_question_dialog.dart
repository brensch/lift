/// A set with an effort target, just done: "how many more could you have
/// done?", with the ramp question's three answers. The answer sharpens the
/// next plan; "Not sure" (or dismissing it) leaves it unanswered, which is
/// fine. Laid out like the ramp's question so the two read as one.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/set_labels.dart';
import '../../providers/workout_provider.dart';
import '../../screens/workout/set_circle.dart';
import '../../theme/theme_spec.dart';
import 'rung_question_dialog.dart';

/// Ask about the set [proposedSetId], over whatever is on screen.
Future<void> showEffortQuestionDialog(
  BuildContext context,
  WorkoutProvider wp,
  String proposedSetId,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => ChangeNotifierProvider.value(
      value: wp,
      child: EffortQuestionDialog(proposedSetId: proposedSetId),
    ),
  );
}

class EffortQuestionDialog extends StatelessWidget {
  final String proposedSetId;

  const EffortQuestionDialog({super.key, required this.proposedSetId});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final w = copy.workout;
    final wp = context.watch<WorkoutProvider>();
    // Answered on the watch, or the next set done: nothing left to ask.
    if (wp.effortQuestionSetId != proposedSetId) {
      final route = ModalRoute.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route != null && route.isActive && context.mounted) {
          Navigator.of(context).removeRoute(route);
        }
      });
    }
    final set = wp.proposedSetById(proposedSetId);
    CompletedSet? done;
    for (final c in wp.completedSets.reversed) {
      if (c.proposedSetId == proposedSetId) {
        done = c;
        break;
      }
    }
    final reps = done?.actualReps ?? set?.targetReps ?? 0;
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
            Center(
              child: SetCircle(
                number: reps,
                text: set == null ? null : repsLabel(set, reps, done: true),
                state: set != null && reps < set.targetReps
                    ? SetCircleState.short
                    : SetCircleState.full,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              w.effortQuestion,
              style: TextStyle(
                fontSize: t.size.titleLg,
                fontWeight: t.weight.heavy,
                color: t.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              w.effortQuestionHint,
              style: TextStyle(fontSize: t.size.body, color: t.muted),
            ),
            const SizedBox(height: 16),
            for (final (repsLeft, text) in RungQuestionDialog.answers) ...[
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    wp.answerEffort(proposedSetId, repsLeft);
                  },
                  child: Text(text, style: label),
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                w.effortSkip,
                style: TextStyle(fontSize: t.size.body, color: t.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
