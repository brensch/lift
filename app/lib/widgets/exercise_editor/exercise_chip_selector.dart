/// Chip row for picking which exercises are in a group.
library;

import 'package:flutter/material.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../exercise_picker.dart';
import 'editable_config.dart';

class ExerciseChipSelector extends StatefulWidget {
  final List<EditableConfig> configs;
  final List<ExerciseStatus> exerciseStatuses;
  final void Function(Exercise exercise, bool selected) onToggle;

  const ExerciseChipSelector({super.key, 
    required this.configs,
    required this.exerciseStatuses,
    required this.onToggle,
  });

  @override
  State<ExerciseChipSelector> createState() => ExerciseChipSelectorState();
}

class ExerciseChipSelectorState extends State<ExerciseChipSelector> {
  void _openPicker() {
    showExercisePicker(
      context: context,
      isSelected: (e) => widget.configs.any((c) => c.exercise == e),
      onToggle: (exercise, selected) {
        widget.onToggle(exercise, selected);
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final count = widget.configs.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EXERCISES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: colorScheme.tertiary,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _openPicker,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outline),
            ),
            child: Row(
              children: [
                Icon(Icons.add_circle_outline, size: 20, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    count == 0
                        ? 'Browse exercises…'
                        : '$count exercise${count == 1 ? '' : 's'} added · tap to edit',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: count == 0
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: colorScheme.outline),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
