/// A ramp set done with every rep: "how many more could you have done?".
/// 0–1 ends the ramp there; 2–4 and 5+ pick the next set's weight. Under
/// them, less prominent, a specific jump: type how much to add for the next
/// set and the ramp goes on from there. Dismissed, it stays unanswered and
/// the ramp climbs as usual.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/settings.pb.dart' show WeightUnit;
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/weight_units.dart';
import '../../providers/settings_provider.dart';
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

/// The largest jump the core takes, as a fraction of the set's weight
/// (core's `MAX_JUMP_FRACTION`): past it the button is off.
const double maxJumpFraction = 2.0;

class RungQuestionDialog extends StatefulWidget {
  final String proposedSetId;

  const RungQuestionDialog({super.key, required this.proposedSetId});

  static List<(RepsLeft, String)> get answers => [
    (RepsLeft.REPS_LEFT_ZERO_TO_ONE, copy.workout.rungAnswerZeroToOne),
    (RepsLeft.REPS_LEFT_TWO_TO_FOUR, copy.workout.rungAnswerTwoToFour),
    (RepsLeft.REPS_LEFT_FIVE_PLUS, copy.workout.rungAnswerFivePlus),
  ];

  /// The specific-jump field and its button, for tests.
  static const jumpFieldKey = Key('rung_jump_field');
  static const jumpApplyKey = Key('rung_jump_apply');

  @override
  State<RungQuestionDialog> createState() => _RungQuestionDialogState();
}

class _RungQuestionDialogState extends State<RungQuestionDialog> {
  final _jump = TextEditingController();

  @override
  void dispose() {
    _jump.dispose();
    super.dispose();
  }

  /// The weight the ramp set was lifted at, in pounds.
  double _rungWeight(WorkoutProvider wp) {
    for (final c in wp.activeCompletedSets.reversed) {
      if (c.proposedSetId == widget.proposedSetId && c.actualWeight > 0) {
        return c.actualWeight;
      }
    }
    return wp.proposedSetById(widget.proposedSetId)?.targetWeight ?? 0;
  }

  /// The typed jump in pounds, or null when it is nothing or too much.
  double? _jumpLb(WorkoutProvider wp, WeightUnit unit) {
    final typed = double.tryParse(_jump.text);
    if (typed == null || typed <= 0) return null;
    final pounds = poundsFromDisplayWeight(typed, unit);
    if (pounds > _rungWeight(wp) * maxJumpFraction) return null;
    return pounds;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final w = copy.workout;
    final wp = context.watch<WorkoutProvider>();
    final unit = context.watch<SettingsProvider>().weightUnit;
    final proposedSetId = widget.proposedSetId;
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
    final jumpLb = _jumpLb(wp, unit);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
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
                  for (final (repsLeft, text)
                      in RungQuestionDialog.answers) ...[
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
            const SizedBox(height: 8),
            // Edge to edge, "or" sitting on it.
            Stack(
              alignment: Alignment.center,
              children: [
                Divider(height: 1, thickness: 1, color: t.hairline),
                ColoredBox(
                  color: t.panel,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      w.rungOr,
                      style: TextStyle(fontSize: t.size.small, color: t.muted),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    w.rungJumpLabel,
                    style: TextStyle(
                      fontSize: t.size.small,
                      fontWeight: t.weight.bold,
                      color: t.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: RungQuestionDialog.jumpFieldKey,
                          controller: _jump,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          onChanged: (_) => setState(() {}),
                          style: t.mono(
                            TextStyle(
                              fontSize: t.size.body,
                              fontWeight: t.weight.bold,
                              color: t.text,
                            ),
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            prefixText: '+ ',
                            suffixText: weightUnitSuffix(unit),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        key: RungQuestionDialog.jumpApplyKey,
                        onPressed: jumpLb == null
                            ? null
                            : () {
                                Navigator.of(context).pop();
                                wp.answerRungJump(proposedSetId, jumpLb);
                              },
                        child: Text(w.rungJumpApply),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
