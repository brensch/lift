/// The whole edit UI for an exercise mid-workout: weight up, weight down,
/// or remove it. The app controls sets and reps — if the prescribed
/// weight is wrong, tap until it isn't. Warmups regenerate for the new
/// weight automatically.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/workout/v1/settings.pb.dart' show WeightUnit;
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercise_blocks.dart';
import '../../logic/exercises.dart';
import '../../logic/weight_units.dart';
import '../../providers/settings_provider.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_theme.dart';

Future<void> showWeightAdjustSheet(
  BuildContext context, {
  required ExerciseBlock block,
  required WorkoutProvider provider,
  VoidCallback? onDelete,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: _WeightAdjustSheet(block: block, onDelete: onDelete),
    ),
  );
}

class _WeightAdjustSheet extends StatefulWidget {
  final ExerciseBlock block;
  final VoidCallback? onDelete;
  const _WeightAdjustSheet({required this.block, this.onDelete});

  @override
  State<_WeightAdjustSheet> createState() => _WeightAdjustSheetState();
}

class _WeightAdjustSheetState extends State<_WeightAdjustSheet> {
  /// The working weight (lb) being edited.
  late double _weight;
  bool _isSaving = false;

  List<ProposedSet> get _workingSets => widget.block.workingSets.toList();

  @override
  void initState() {
    super.initState();
    final sets = _workingSets;
    _weight = sets.isEmpty ? 0 : sets.last.targetWeight.toDouble();
  }

  /// One plate-pair in the display unit.
  double _stepLb(WeightUnit unit) =>
      isMetricUnit(unit) ? poundsFromDisplayWeight(2.5, unit) : 5.0;

  bool get _dirty {
    final sets = _workingSets;
    return sets.isNotEmpty && (sets.last.targetWeight - _weight).abs() > 0.01;
  }

  Future<void> _apply() async {
    if (!_dirty || _isSaving) {
      if (mounted && !_isSaving) Navigator.pop(context);
      return;
    }
    setState(() => _isSaving = true);
    try {
      await context
          .read<WorkoutProvider>()
          .adjustExerciseWeight(widget.block.exercise, _weight);
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

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.sheetColor(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
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
                child: Text(
                  exerciseNames[widget.block.exercise] ?? 'Adjust weight',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (widget.onDelete != null)
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDelete!();
                  },
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: cs.error.withValues(alpha: 0.8),
                  ),
                ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            'Reps and sets are handled — this sticks for the rest of the '
            'session, and finishing at the new weight updates your '
            'progression.',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepButton(
                icon: Icons.remove,
                onTap: () => setState(() {
                  _weight = (_weight - step).clamp(0, 2000);
                }),
              ),
              SizedBox(
                width: 130,
                child: Text(
                  formatWeight(_weight, unit, includeUnit: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add,
                onTap: () => setState(() {
                  _weight = (_weight + step).clamp(0, 2000);
                }),
              ),
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
                      _dirty ? 'UPDATE' : 'DONE',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
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
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, size: 24),
        ),
      ),
    );
  }
}

/// Confirm removing an exercise's remaining sets from the session.
Future<bool> showDeleteExerciseDialog(
  BuildContext context,
  String exerciseName,
) async {
  final colorScheme = Theme.of(context).colorScheme;
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Remove $exerciseName?',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'This will remove its remaining sets. Sets you already did stay.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: const Text('Remove'),
            ),
          ],
        ),
      ) ??
      false;
}
