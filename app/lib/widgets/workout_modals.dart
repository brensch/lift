import 'package:flutter/material.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../logic/exercise_groups.dart';
import 'plate_visualization.dart';

Future<void> showEditExerciseDialog(
  BuildContext context, {
  required ExerciseGroupData group,
  required int groupIndex,
  required List<ExerciseStatus> exerciseStatuses,
  required bool Function(String setId) isSetDone,
  required void Function(int groupIndex, {required double targetWeight, bool? warmups, int? setCount}) onSave,
}) async {
  final workingSets = group.sets.where((s) => !s.warmup).toList();
  final unfinishedWorkingSets = workingSets.where((s) => !isSetDone(s.id)).toList();

  // Initialize from the first unfinished working set if available, otherwise from the first working set
  final referenceSet = unfinishedWorkingSets.isNotEmpty ? unfinishedWorkingSets.first : (workingSets.isNotEmpty ? workingSets.first : null);
  
  double weight = referenceSet?.targetWeight.toDouble() ?? 45.0;
  bool warmups = true; // Always start with warmups selected as requested
  int sets = workingSets.length;

  final weightController = TextEditingController(text: weight.toStringAsFixed(1).replaceAll('.0', ''));

  final status = exerciseStatuses.cast<ExerciseStatus?>().firstWhere(
        (s) => s!.exercise == group.exercise,
        orElse: () => null,
      );

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final colorScheme = Theme.of(ctx).colorScheme;

          void updateWeight(double newWeight) {
            setState(() {
              weight = newWeight;
              final text = weight.toStringAsFixed(1).replaceAll('.0', '');
              weightController.text = text;
              weightController.selection = TextSelection.fromPosition(TextPosition(offset: text.length));
            });
          }

          return Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'EDIT ${exerciseNames[group.exercise]?.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (status != null && status.explanation.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            status.explanation,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          IntrinsicWidth(
                            child: TextField(
                              controller: weightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                                letterSpacing: -2,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (v) {
                                final val = double.tryParse(v);
                                if (val != null) {
                                  setState(() => weight = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'LB',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      PlateVisualization(weight: weight, scale: 1.5),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _WeightButton(label: '-45', onPressed: () => updateWeight((weight - 45).clamp(0, 1000))),
                    _WeightButton(label: '-5', onPressed: () => updateWeight((weight - 5).clamp(0, 1000))),
                    _WeightButton(label: '+5', onPressed: () => updateWeight((weight + 5).clamp(0, 1000))),
                    _WeightButton(label: '+45', onPressed: () => updateWeight((weight + 45).clamp(0, 1000))),
                  ],
                ),
                const SizedBox(height: 16),
                Slider(
                  value: weight.clamp(0, 500),
                  min: 0,
                  max: 500,
                  divisions: 100,
                  label: weight.toStringAsFixed(1),
                  onChanged: (v) => updateWeight(v),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WORKING SETS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.tertiary,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _CountButton(icon: Icons.remove, onPressed: () => setState(() => sets = (sets - 1).clamp(1, 10))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  '$sets',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                                ),
                              ),
                              _CountButton(icon: Icons.add, onPressed: () => setState(() => sets = (sets + 1).clamp(1, 10))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'WARMUPS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.tertiary,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Switch(
                            value: warmups,
                            onChanged: (v) => setState(() => warmups = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onSave(groupIndex, targetWeight: weight, warmups: warmups, setCount: sets);
                    },
                    child: const Text(
                      'SAVE CHANGES',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> showAddExerciseDialog(
  BuildContext context, {
  required List<ExerciseStatus> exerciseStatuses,
  required void Function(Exercise exercise, double weight, int sets, int reps) onAdd,
}) async {
  Exercise? selected;
  double weight = 45;
  int sets = 3;
  int reps = 5;

  final weightController = TextEditingController(text: '45');
  final setsController = TextEditingController(text: '3');
  final repsController = TextEditingController(text: '5');

  await showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final colorScheme = Theme.of(ctx).colorScheme;
          final status = exerciseStatuses.cast<ExerciseStatus?>().firstWhere(
                (s) => s!.exercise == selected,
                orElse: () => null,
              );

          return AlertDialog(
            title: const Text(
              'Add Exercise',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<Exercise>(
                    value: selected,
                    hint: const Text('Select exercise'),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: Exercise.values
                        .where((e) => e != Exercise.EXERCISE_UNSPECIFIED)
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(exerciseNames[e] ?? '?'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        selected = v;
                        final s = exerciseStatuses.cast<ExerciseStatus?>().firstWhere(
                              (status) => status!.exercise == v,
                              orElse: () => null,
                            );
                        if (s != null) {
                          weight = s.targetWeight;
                          weightController.text = weight.toStringAsFixed(1).replaceAll('.0', '');
                          sets = s.defaultSets > 0 ? s.defaultSets : 3;
                          setsController.text = sets.toString();
                          reps = s.defaultReps > 0 ? s.defaultReps : 5;
                          repsController.text = reps.toString();
                        }
                      });
                    },
                  ),
                  if (status != null && status.explanation.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              status.explanation,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Weight (lbs)'),
                    onChanged: (v) => weight = double.tryParse(v) ?? weight,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: setsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Sets'),
                          onChanged: (v) => sets = int.tryParse(v) ?? sets,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: repsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Reps'),
                          onChanged: (v) => reps = int.tryParse(v) ?? reps,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selected == null
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        onAdd(selected!, weight, sets, reps);
                      },
                child: const Text('Add'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<bool> showEndWorkoutConfirmDialog(BuildContext context) async {
  final colorScheme = Theme.of(context).colorScheme;
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(
            'End Workout?',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: const Text('This will end your current workout.'),
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
              child: const Text('End Workout'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<bool> showDeleteGroupDialog(BuildContext context, String exerciseName) async {
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

class _WeightButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _WeightButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 44),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
      ),
    );
  }
}

class _CountButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _CountButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}
