/// The edit sheet for an exercise mid-workout: its weight and reps for the
/// rest of this workout, or remove it. Warmups regenerate for the new
/// weight automatically. The change is recorded in the workout's weight
/// log; the next plan reads what was lifted.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercise_blocks.dart';
import '../../logic/exercises.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../common/flat.dart';
import '../common/weight_selector.dart';
import 'confirm_dialog.dart';
import 'workout_sheet.dart';
import '../../theme/theme_spec.dart';
import '../../theme/app_icons.dart';

Future<void> showWeightAdjustSheet(
  BuildContext context, {
  required ExerciseBlock block,
  required WorkoutProvider provider,
  required VoidCallback onDelete,
}) {
  return showWorkoutSheet(
    context,
    provider: provider,
    child: _WeightAdjustSheet(block: block, onDelete: onDelete),
  );
}

class _WeightAdjustSheet extends StatefulWidget {
  final ExerciseBlock block;
  final VoidCallback onDelete;
  const _WeightAdjustSheet({required this.block, required this.onDelete});

  @override
  State<_WeightAdjustSheet> createState() => _WeightAdjustSheetState();
}

class _WeightAdjustSheetState extends State<_WeightAdjustSheet> {
  /// The working weight (lb) and reps being edited.
  late double _weight;
  late int _reps;
  late final double _startWeight;
  late final int _startReps;
  bool _isSaving = false;

  /// The sets the weight is read from: the working sets, or — mid-ramp,
  /// before any exist — the calibration rungs.
  List<ProposedSet> get _workingSets {
    final working = widget.block.workingSets.toList();
    return working.isNotEmpty ? working : widget.block.calibrationSets.toList();
  }

  @override
  void initState() {
    super.initState();
    final sets = _workingSets;
    _weight = sets.isEmpty ? 0 : sets.last.targetWeight.toDouble();
    final working = widget.block.workingSets.toList();
    final decision = context
        .read<WorkoutProvider>()
        .logFor(widget.block.exercise)
        ?.decision;
    _reps = working.isNotEmpty
        ? working.last.targetReps
        : (decision != null && decision.reps > 0 ? decision.reps : 5);
    _startWeight = _weight;
    _startReps = _reps;
  }

  bool get _barbell =>
      context.read<WorkoutProvider>().equipmentOf(widget.block.exercise) ==
      EquipmentKind.EQUIPMENT_KIND_BARBELL;

  bool get _dirty =>
      (_startWeight - _weight).abs() > 0.01 || _startReps != _reps;

  /// This workout's remaining sets take the new numbers.
  Future<void> _apply() async {
    if (!_dirty || _isSaving) {
      if (mounted && !_isSaving) Navigator.pop(context);
      return;
    }
    setState(() => _isSaving = true);
    final wp = context.read<WorkoutProvider>();
    final exercise = widget.block.exercise;
    try {
      await wp.adjustExerciseWeight(exercise, _weight, targetReps: _reps);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final name = exerciseName(widget.block.exercise);

    Widget stepper(
      String label,
      String value,
      VoidCallback onDown,
      VoidCallback onUp, {
      bool last = false,
    }) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          border: Border(
            right: last ? BorderSide.none : BorderSide(color: t.hairline),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label),
            const SizedBox(height: 10),
            Row(
              children: [
                _StepButton(icon: AppIcons.remove, onTap: onDown),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: t.mono(
                        TextStyle(
                          fontSize: t.size.titleLg,
                          fontWeight: t.weight.bold,
                          color: t.text,
                        ),
                      ),
                    ),
                  ),
                ),
                _StepButton(icon: AppIcons.add, onTap: onUp),
              ],
            ),
          ],
        ),
      ),
    );

    return Container(
      color: AppTheme.sheetColor(context),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTheme.sheetHandle(context, gap: 0),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 4, 0),
            child: Row(
              children: [
                Expanded(child: PageTitle(name)),
                IconButton(
                  tooltip: copy.adjustWeight.removeTooltip,
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDelete();
                  },
                  icon: Icon(AppIcons.delete, color: t.error),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              copy.adjustWeight.body.replaceAll('{name}', name),
              style: TextStyle(fontSize: t.size.body, color: t.muted),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: WeightSelector(
              weightLb: _weight,
              stepLb: context.read<WorkoutProvider>().weightStepOf(
                widget.block.exercise,
              ),
              barbell: _barbell,
              onChanged: (lb) => setState(() => _weight = lb),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: t.hairline),
              ),
            ),
            child: Row(
              children: [
                stepper(
                  copy.adjustWeight.reps,
                  '$_reps',
                  () => setState(() => _reps = (_reps - 1).clamp(1, 100)),
                  () => setState(() => _reps = (_reps + 1).clamp(1, 100)),
                  last: true,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _isSaving ? null : _apply,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _dirty
                            ? copy.adjustWeight.save
                            : copy.adjustWeight.done,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A square − / + for the steppers.
class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(side: BorderSide(color: t.outline)),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: t.size.title, color: t.text),
        ),
      ),
    );
  }
}

/// Confirm removing an exercise's remaining sets from the session.
Future<bool> showDeleteExerciseDialog(
  BuildContext context,
  String exerciseName,
) => confirmDialog(
  context,
  title: copy.adjustWeight.removeTitle.replaceAll('{exercise}', exerciseName),
  body: copy.adjustWeight.removeBody,
  confirm: copy.adjustWeight.removeConfirm,
  cancel: copy.adjustWeight.removeCancel,
  destructive: true,
);
