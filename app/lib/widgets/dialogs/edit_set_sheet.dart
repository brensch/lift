/// Correct a set you already did: reps on a wheel, weight by plate step.
/// This is how a miss is recorded — tap the done chip. The edit lands
/// through `editCompletedSet`, which recomputes the rest the way Done
/// would have.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/workout/v1/settings.pb.dart' show WeightUnit;
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercises.dart';
import '../../logic/set_labels.dart';
import '../../logic/weight_units.dart';
import '../../providers/settings_provider.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_spec.dart';
import '../../theme/app_icons.dart';

Future<void> showEditSetSheet(
  BuildContext context, {
  required WorkoutProvider provider,
  required ProposedSet proposed,
  required CompletedSet completed,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: EditSetSheet(proposed: proposed, completed: completed),
    ),
  );
}

class EditSetSheet extends StatefulWidget {
  final ProposedSet proposed;
  final CompletedSet completed;

  const EditSetSheet({
    super.key,
    required this.proposed,
    required this.completed,
  });

  @override
  State<EditSetSheet> createState() => _EditSetSheetState();
}

class _EditSetSheetState extends State<EditSetSheet> {
  static const int _wheelCeiling = 50;

  late int _reps;
  late double _weightLb;
  bool _isSaving = false;

  int get _maxReps => _wheelCeiling > widget.proposed.targetReps
      ? _wheelCeiling
      : widget.proposed.targetReps;

  @override
  void initState() {
    super.initState();
    final current = widget.completed.actualReps;
    _reps = current.clamp(0, _maxReps);
    _weightLb = widget.completed.actualWeight.toDouble();
  }

  /// One plate-pair in the display unit. The 0..2000 clamp mirrors the
  /// server's range check in the reducer.
  double _stepLb(WeightUnit unit) =>
      isMetricUnit(unit) ? poundsFromDisplayWeight(2.5, unit) : 5.0;

  Future<void> _apply() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await context.read<WorkoutProvider>().editCompletedSet(
        widget.completed.id,
        _reps,
        _weightLb,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final step = _stepLb(unit);
    final provider = context.read<WorkoutProvider>();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.sheetColor(context),
        border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: AppTheme.sheetHandle(context)),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exerciseNames[widget.proposed.exercise] ?? '?',
                      style: TextStyle(
                        fontSize: context.tokens.size.subtitle,
                        fontWeight: context.tokens.weight.heavy,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      setLineFor(widget.proposed, provider.activeProposedSets),
                      style: TextStyle(
                        fontSize: context.tokens.size.small,
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(AppIcons.close),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                children: [
                  RepWheel(
                    maxReps: _maxReps,
                    initialReps: _reps,
                    onChanged: (reps) => setState(() => _reps = reps),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'reps',
                    style: TextStyle(
                      fontSize: context.tokens.size.small,
                      fontWeight: context.tokens.weight.bold,
                      letterSpacing: 0.4,
                      color: cs.tertiary,
                    ),
                  ),
                ],
              ),
              ...[
                const SizedBox(width: 24),
                Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StepButton(
                          icon: AppIcons.remove,
                          onTap: () => setState(() {
                            _weightLb = (_weightLb - step).clamp(0, 2000);
                          }),
                        ),
                        SizedBox(
                          width: 104,
                          child: Text(
                            formatWeight(_weightLb, unit, includeUnit: true),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: context.tokens.size.title,
                              fontWeight: context.tokens.weight.heavy,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        _StepButton(
                          icon: AppIcons.add,
                          onTap: () => setState(() {
                            _weightLb = (_weightLb + step).clamp(0, 2000);
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'weight',
                      style: TextStyle(
                        fontSize: context.tokens.size.small,
                        fontWeight: context.tokens.weight.bold,
                        letterSpacing: 0.4,
                        color: cs.tertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _isSaving ? null : _apply,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'UPDATE',
                      style: TextStyle(
                        fontWeight: context.tokens.weight.heavy,
                        fontSize: context.tokens.size.bodyLg,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A rep count on a wheel, 0..[maxReps]. The only picker in the app.
class RepWheel extends StatefulWidget {
  final int maxReps;
  final int initialReps;
  final ValueChanged<int> onChanged;

  const RepWheel({
    super.key,
    required this.maxReps,
    required this.initialReps,
    required this.onChanged,
  });

  @override
  State<RepWheel> createState() => _RepWheelState();
}

class _RepWheelState extends State<RepWheel> {
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(
        initialItem: widget.initialReps.clamp(0, widget.maxReps),
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 132,
      width: 84,
      decoration: BoxDecoration(
        borderRadius: context.tokens.br(12),
        border: Border.all(color: cs.outline),
      ),
      child: ListWheelScrollView.useDelegate(
        controller: _controller,
        itemExtent: 34,
        magnification: 1.3,
        useMagnifier: true,
        physics: const FixedExtentScrollPhysics(),
        diameterRatio: 1.4,
        perspective: 0.003,
        onSelectedItemChanged: widget.onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            if (index < 0 || index > widget.maxReps) return null;
            return Center(
              child: Text(
                '$index',
                style: TextStyle(
                  fontSize: context.tokens.size.title,
                  fontWeight: context.tokens.weight.heavy,
                  color: cs.onSurface,
                ),
              ),
            );
          },
          childCount: widget.maxReps + 1,
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 22)),
      ),
    );
  }
}
