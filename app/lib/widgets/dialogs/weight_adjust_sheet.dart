/// The whole edit UI for a group mid-workout: weight up, weight down,
/// or remove the exercise. The app controls sets and reps — if the
/// prescribed weight is wrong, tap until it isn't. Warmups regenerate
/// for the new weight automatically.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/workout/v1/settings.pb.dart' show WeightUnit;
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercise_groups.dart';
import '../../logic/exercises.dart';
import '../../logic/weight_units.dart';
import '../../providers/settings_provider.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_theme.dart';

Future<void> showWeightAdjustSheet(
  BuildContext context, {
  required ExerciseGroupData group,
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
      child: _WeightAdjustSheet(group: group, onDelete: onDelete),
    ),
  );
}

class _WeightAdjustSheet extends StatefulWidget {
  final ExerciseGroupData group;
  final VoidCallback? onDelete;
  const _WeightAdjustSheet({required this.group, this.onDelete});

  @override
  State<_WeightAdjustSheet> createState() => _WeightAdjustSheetState();
}

class _WeightAdjustSheetState extends State<_WeightAdjustSheet> {
  /// Per exercise: the working weight (lb) being edited.
  late final Map<Exercise, double> _weights;
  bool _isSaving = false;

  List<ProposedSet> _workingSets(Exercise exercise) => widget.group.sets
      .where((s) => !s.warmup && !s.cancelled && s.exercise == exercise)
      .toList();

  @override
  void initState() {
    super.initState();
    _weights = {
      for (final exercise in _exercises())
        exercise: _workingSets(exercise).isEmpty
            ? 0
            : _workingSets(exercise).last.targetWeight.toDouble(),
    };
  }

  List<Exercise> _exercises() {
    final out = <Exercise>[];
    for (final set in widget.group.sets) {
      if (!set.warmup && !out.contains(set.exercise)) out.add(set.exercise);
    }
    return out;
  }

  /// One plate-pair in the display unit.
  double _stepLb(WeightUnit unit) =>
      isMetricUnit(unit) ? poundsFromDisplayWeight(2.5, unit) : 5.0;

  bool get _dirty {
    for (final exercise in _weights.keys) {
      final sets = _workingSets(exercise);
      if (sets.isNotEmpty &&
          (sets.last.targetWeight - _weights[exercise]!).abs() > 0.01) {
        return true;
      }
    }
    return false;
  }

  Future<void> _apply() async {
    if (!_dirty || _isSaving) {
      if (mounted && !_isSaving) Navigator.pop(context);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final wp = context.read<WorkoutProvider>();
      final groupIndex = wp.exerciseGroups.indexWhere(
        (candidate) => candidate.stableId == widget.group.stableId,
      );
      if (groupIndex == -1) return;
      final groupProto = widget.group.group;

      // Rebuild this group's configs with only the weights changed; sets,
      // reps, rest and warmups stay exactly as prescribed.
      final configs = <ExerciseTypeConfig>[];
      for (final exercise in _exercises()) {
        final sets = _workingSets(exercise);
        if (sets.isEmpty) continue;
        final config = ExerciseTypeConfig()
          ..exercise = exercise
          ..startWeight = _weights[exercise]!
          ..endWeight = _weights[exercise]!
          ..reps = sets.first.targetReps
          ..includeWarmup = widget.group.sets.any(
            (s) => s.warmup && s.exercise == exercise,
          )
          ..restConfig = (RestConfig()
            ..restAfterSuccess = sets.first.restAfterSuccess
            ..restAfterFailure = sets.first.restAfterFailure);
        configs.add(config);
      }
      await wp.updateGroup(
        groupIndex,
        sets: groupProto?.sets ?? _workingSets(_exercises().first).length,
        interleaveWarmups: groupProto?.interleaveWarmups ?? false,
        exerciseConfigs: configs,
        restConfig: groupProto != null && groupProto.hasRestConfig()
            ? groupProto.restConfig
            : null,
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
              const Expanded(
                child: Text(
                  'Adjust weight',
                  style: TextStyle(
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
          const SizedBox(height: 14),
          for (final exercise in _exercises())
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      exerciseNames[exercise] ?? '?',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _StepButton(
                    icon: Icons.remove,
                    onTap: () => setState(() {
                      _weights[exercise] =
                          (_weights[exercise]! - step).clamp(0, 2000);
                    }),
                  ),
                  SizedBox(
                    width: 92,
                    child: Text(
                      formatWeight(
                        _weights[exercise]!,
                        unit,
                        includeUnit: true,
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  _StepButton(
                    icon: Icons.add,
                    onTap: () => setState(() {
                      _weights[exercise] = _weights[exercise]! + step;
                    }),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
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
          width: 44,
          height: 44,
          child: Icon(icon, size: 22),
        ),
      ),
    );
  }
}

/// Confirm removing a whole exercise group from the session.
Future<bool> showDeleteGroupDialog(
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
          content: const Text('This will remove all sets for this exercise.'),
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
