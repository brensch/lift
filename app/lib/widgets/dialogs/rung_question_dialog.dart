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
import '../../screens/workout/set_circle.dart';
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

  /// Reps taken off here: the question closes with the first, but the
  /// dialog stays to say what that did.
  bool _tapped = false;

  /// The done set this asks about.
  CompletedSet? _done(WorkoutProvider wp) {
    for (final c in wp.activeCompletedSets.reversed) {
      if (c.proposedSetId == widget.proposedSetId) return c;
    }
    return null;
  }

  /// What a miss did: the next set of the lift still to do — a lighter
  /// rung after a too-heavy one, else the working sets the ramp settled on.
  ProposedSet? _next(WorkoutProvider wp) {
    final exercise = wp.proposedSetById(widget.proposedSetId)?.exercise;
    final done = {for (final c in wp.activeCompletedSets) c.proposedSetId};
    return wp.activeProposedSets
        .where(
          (s) => s.exercise == exercise && !s.warmup && !done.contains(s.id),
        )
        .firstOrNull;
  }

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
    if (wp.rungQuestionSetId != proposedSetId && !_tapped) {
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
    final rungLb = wp.activeProposedSets
        .where((s) => s.id == proposedSetId)
        .firstOrNull
        ?.targetWeight;
    String weight(double lb) => formatWeight(lb, unit, includeUnit: true);
    String? outcomeText(RepsLeft repsLeft) {
      final o = wp.rungOutcome(repsLeft);
      if (o == null) return null;
      if (o.settles) {
        return w.rungOutcomeSettle.replaceAll('{weight}', weight(o.weight));
      }
      return w.rungOutcomeNext
          .replaceAll('{weight}', weight(o.weight))
          .replaceAll('{jump}', weight(o.weight - (rungLb ?? o.weight)));
    }

    final affix = t.mono(
      TextStyle(
        fontSize: t.size.bodyLg,
        fontWeight: t.weight.bold,
        color: t.muted,
      ),
    );
    final done = _done(wp);
    final target = wp.proposedSetById(proposedSetId)?.targetReps ?? 5;
    final reps = done?.actualReps ?? target;
    final missed = reps < target;
    final next = missed ? _next(wp) : null;
    final outcome = next == null
        ? ''
        : next.calibration
        ? w.rungMissedTooHeavy.replaceAll('{weight}', weight(next.targetWeight))
        : w.rungMissedSettled
              .replaceAll('{n}', '${target - reps}')
              .replaceAll('{weight}', weight(next.targetWeight));
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The set's own circle: a tap takes a rep off, as on every set.
            Center(
              child: SetCircle(
                number: reps,
                state: !missed
                    ? SetCircleState.full
                    : reps == 0
                    ? SetCircleState.zero
                    : SetCircleState.short,
                onTap: done == null || reps == 0
                    ? null
                    : () {
                        setState(() => _tapped = true);
                        wp.tapDoneSet(done.id);
                      },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                w.rungCircleHint,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: t.size.small, color: t.muted),
              ),
            ),
            if (missed) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  outcome,
                  style: TextStyle(
                    fontSize: t.size.bodyLg,
                    fontWeight: t.weight.bold,
                    color: t.text,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(w.rungOk, style: label),
                  ),
                ),
              ),
            ] else ...[
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(text, style: label),
                              if (outcomeText(repsLeft) case final line?)
                                Text(
                                  line,
                                  style: TextStyle(fontSize: t.size.small),
                                ),
                            ],
                          ),
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
                        style: TextStyle(
                          fontSize: t.size.small,
                          color: t.muted,
                        ),
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
                    // The field and its button, one height, as the dialog's
                    // other buttons.
                    SizedBox(
                      height: 56,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: TextField(
                              key: RungQuestionDialog.jumpFieldKey,
                              controller: _jump,
                              expands: true,
                              maxLines: null,
                              textAlignVertical: TextAlignVertical.center,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                                  fontSize: t.size.bodyLg,
                                  fontWeight: t.weight.bold,
                                  color: t.text,
                                ),
                              ),
                              // "+ 15 kg": the sign and unit always shown, in
                              // the field's own font.
                              decoration: InputDecoration(
                                prefixIcon: Center(
                                  widthFactor: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      left: 12,
                                      right: 6,
                                    ),
                                    child: Text('+', style: affix),
                                  ),
                                ),
                                prefixIconConstraints: const BoxConstraints(),
                                suffixIcon: Center(
                                  widthFactor: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Text(
                                      weightUnitSuffix(unit),
                                      style: affix,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            key: RungQuestionDialog.jumpApplyKey,
                            // The field's border, so the pair reads as one.
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: t.outline),
                            ),
                            onPressed: jumpLb == null
                                ? null
                                : () {
                                    Navigator.of(context).pop();
                                    wp.answerRungJump(proposedSetId, jumpLb);
                                  },
                            child: Text(
                              w.rungJumpApply,
                              style: TextStyle(
                                fontSize: t.size.bodyLg,
                                fontWeight: t.weight.heavy,
                                color: jumpLb == null ? t.muted : t.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
