import 'package:flutter/material.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../logic/exercise_groups.dart';

Future<void> showEditExerciseDialog(
  BuildContext context, {
  required ExerciseGroupData group,
  required int groupIndex,
  required void Function(int groupIndex, {required double targetWeight, bool? warmups, int? setCount}) onSave,
}) async {
  final workingSets = group.sets.where((s) => !s.warmup).toList();
  final currentWeight = workingSets.isNotEmpty ? workingSets.first.targetWeight : 45.0;
  final hasWarmups = group.sets.any((s) => s.warmup);
  final setCount = workingSets.length;

  double weight = currentWeight.toDouble();
  bool warmups = hasWarmups;
  int sets = setCount;

  final weightController = TextEditingController(text: weight.toStringAsFixed(0));
  final setsController = TextEditingController(text: sets.toString());

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text('Edit ${exerciseNames[group.exercise]}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Weight (lbs)',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => weight = double.tryParse(v) ?? weight,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: setsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Working Sets',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => sets = int.tryParse(v) ?? sets,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Warmups'),
              value: warmups,
              onChanged: (v) => setState(() => warmups = v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onSave(groupIndex, targetWeight: weight, warmups: warmups, setCount: sets);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showAddExerciseDialog(
  BuildContext context, {
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
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Add Exercise'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<Exercise>(
                value: selected,
                hint: const Text('Select exercise'),
                isExpanded: true,
                items: Exercise.values
                    .where((e) => e != Exercise.EXERCISE_UNSPECIFIED)
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(exerciseNames[e] ?? '?'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => selected = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Weight (lbs)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => weight = double.tryParse(v) ?? weight,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: setsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Sets',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => sets = int.tryParse(v) ?? sets,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: repsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Reps',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => reps = int.tryParse(v) ?? reps,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
      ),
    ),
  );
}

Future<bool> showEndWorkoutConfirmDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('End Workout?'),
          content: const Text('This will end your current workout.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('End Workout'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<bool> showDeleteGroupDialog(BuildContext context, String exerciseName) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Remove $exerciseName?'),
          content: const Text('This will remove all sets for this exercise.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          ],
        ),
      ) ??
      false;
}
