import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../logic/exercise_groups.dart';
import '../providers/workout_provider.dart';
import '../providers/multiplayer_provider.dart';
import 'plate_visualization.dart';

Future<void> endWorkout(BuildContext context) async {
  final confirmed = await showEndWorkoutConfirmDialog(context);
  if (confirmed && context.mounted) {
    final wp = context.read<WorkoutProvider>();
    final mp = context.read<MultiplayerProvider>();

    final workoutId = wp.workout?.id;
    if (workoutId == null) return;

    await wp.endWorkout();
    if (context.mounted) {
      if (mp.isInSession) {
        await mp.leaveSession();
      }
      context.push('/workout/$workoutId/completed');
    }
  }
}

Future<void> showEditExerciseDialog(
  BuildContext context, {
  required ExerciseGroupData group,
  required int groupIndex,
  required List<ExerciseStatus> exerciseStatuses,
  required bool Function(String setId) isSetDone,
  required void Function(
    int groupIndex, {
    required int sets,
    required bool interleaveWarmups,
    required List<ExerciseTypeConfig> exerciseConfigs,
    RestConfig? restConfig,
  })
  onSave,
}) async {
  int sets = group.group?.sets ?? 5;
  bool interleaveWarmups = group.group?.interleaveWarmups ?? false;
  RestConfig restConfig = group.group?.restConfig.deepCopy() ?? RestConfig();

  List<_EditableConfig> editableConfigs = [];
  if (group.group != null && group.group!.exerciseConfigs.isNotEmpty) {
    for (final config in group.group!.exerciseConfigs) {
      editableConfigs.add(
        _EditableConfig(
          exercise:
              Exercise.valueOf(config.exercise.value) ??
              Exercise.EXERCISE_UNSPECIFIED,
          startWeight: config.startWeight,
          endWeight: config.endWeight,
          reps: config.reps,
          includeWarmup: config.includeWarmup,
          restConfig: config.hasRestConfig()
              ? config.restConfig.deepCopy()
              : null,
        ),
      );
    }
  } else {
    final workingSets = group.sets.where((s) => !s.warmup).toList();
    final exercises = <Exercise>[];
    for (final s in group.sets) {
      if (!exercises.contains(s.exercise)) exercises.add(s.exercise);
    }
    for (final ex in exercises) {
      final weight = workingSets
          .firstWhere((s) => s.exercise == ex, orElse: () => workingSets.first)
          .targetWeight
          .toDouble();
      editableConfigs.add(
        _EditableConfig(
          exercise: ex,
          startWeight: weight,
          endWeight: weight,
          reps: workingSets.firstOrNull?.targetReps ?? 5,
          includeWarmup: group.sets.any((s) => s.warmup && s.exercise == ex),
        ),
      );
    }
  }

  // Track which exercise is expanded for weight editing
  int? expandedIndex;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final colorScheme = Theme.of(ctx).colorScheme;

          return Container(
            decoration: BoxDecoration(
              color: colorScheme.secondary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.5),
              ),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'EDIT ${group.group?.name.toUpperCase() ?? exerciseNames[group.exercise]?.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Add exercise chips
                  _ExerciseChipSelector(
                    configs: editableConfigs,
                    exerciseStatuses: exerciseStatuses,
                    onToggle: (exercise, selected) {
                      setState(() {
                        if (selected) {
                          final status = exerciseStatuses
                              .cast<ExerciseStatus?>()
                              .firstWhere(
                                (s) => s!.exercise == exercise,
                                orElse: () => null,
                              );
                          editableConfigs.add(
                            _EditableConfig(
                              exercise: exercise,
                              startWeight: status?.targetWeight ?? 45,
                              endWeight: status?.targetWeight ?? 45,
                              reps: status?.defaultReps ?? 5,
                              includeWarmup: true,
                            ),
                          );
                        } else {
                          editableConfigs.removeWhere(
                            (c) => c.exercise == exercise,
                          );
                          if (expandedIndex != null &&
                              expandedIndex! >= editableConfigs.length) {
                            expandedIndex = null;
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Compact exercise configs
                  ...editableConfigs.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final config = entry.value;
                    final isExpanded = expandedIndex == idx;
                    return _CompactExerciseConfig(
                      config: config,
                      isExpanded: isExpanded,
                      onTap: () => setState(() {
                        expandedIndex = isExpanded ? null : idx;
                      }),
                      onStartWeightChanged: (v) => setState(() {
                        final wasSynced =
                            config.startWeight == config.endWeight;
                        config.startWeight = v;
                        if (wasSynced) {
                          config.endWeight = v;
                        }
                      }),
                      onEndWeightChanged: (v) => setState(() {
                        config.endWeight = v;
                      }),
                      onWarmupChanged: (v) =>
                          setState(() => config.includeWarmup = v),
                      onRestChanged: (v) =>
                          setState(() => config.restConfig = v),
                    );
                  }),

                  const SizedBox(height: 16),
                  _GroupSettings(
                    sets: sets,
                    interleaveWarmups: interleaveWarmups,
                    showInterleave: editableConfigs.length > 1,
                    onSetsChanged: (v) => setState(() => sets = v),
                    onInterleaveChanged: (v) =>
                        setState(() => interleaveWarmups = v),
                  ),
                  const SizedBox(height: 16),
                  _RestSettings(
                    restConfig: restConfig,
                    onChanged: (v) => setState(() => restConfig = v),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: editableConfigs.isEmpty
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              final configs = editableConfigs.map((c) {
                                final config = ExerciseTypeConfig()
                                  ..exercise = c.exercise
                                  ..startWeight = c.startWeight
                                  ..endWeight = c.endWeight
                                  ..reps = c.reps
                                  ..includeWarmup = c.includeWarmup;
                                if (c.restConfig != null) {
                                  config.restConfig = c.restConfig!;
                                }
                                return config;
                              }).toList();
                              onSave(
                                groupIndex,
                                sets: sets,
                                interleaveWarmups: interleaveWarmups,
                                exerciseConfigs: configs,
                                restConfig: restConfig,
                              );
                            },
                      child: const Text(
                        'SAVE CHANGES',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
  required void Function(
    String name,
    int sets,
    bool interleaveWarmups,
    List<ExerciseTypeConfig> exerciseConfigs,
    RestConfig restConfig,
  )
  onAdd,
}) async {
  List<_EditableConfig> configs = [];
  String customName = '';
  int sets = 3;
  bool interleaveWarmups = false;
  RestConfig restConfig = RestConfig();
  int? expandedIndex;

  final nameController = TextEditingController();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final colorScheme = Theme.of(ctx).colorScheme;

          return Container(
            decoration: BoxDecoration(
              color: colorScheme.secondary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.5),
              ),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ADD EXERCISE GROUP',
                        style: TextStyle(
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
                  const SizedBox(height: 12),

                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'Group name (optional)',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    onChanged: (v) => customName = v,
                  ),
                  const SizedBox(height: 16),

                  // Exercise chips
                  _ExerciseChipSelector(
                    configs: configs,
                    exerciseStatuses: exerciseStatuses,
                    onToggle: (exercise, selected) {
                      setState(() {
                        if (selected) {
                          final status = exerciseStatuses
                              .cast<ExerciseStatus?>()
                              .firstWhere(
                                (s) => s!.exercise == exercise,
                                orElse: () => null,
                              );
                          configs.add(
                            _EditableConfig(
                              exercise: exercise,
                              startWeight: status?.targetWeight ?? 45,
                              endWeight: status?.targetWeight ?? 45,
                              reps: status?.defaultReps ?? 5,
                              includeWarmup: true,
                            ),
                          );
                          if (configs.length == 1) {
                            sets = status?.defaultSets ?? 3;
                          }
                        } else {
                          configs.removeWhere((c) => c.exercise == exercise);
                          if (expandedIndex != null &&
                              expandedIndex! >= configs.length) {
                            expandedIndex = null;
                          }
                        }
                        if (configs.length > 1) {
                          interleaveWarmups = true;
                        }
                      });
                    },
                  ),

                  if (configs.isNotEmpty) ...[
                    const SizedBox(height: 16),

                    // Compact exercise configs
                    ...configs.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final config = entry.value;
                      final isExpanded = expandedIndex == idx;
                      return _CompactExerciseConfig(
                        config: config,
                        isExpanded: isExpanded,
                        onTap: () => setState(() {
                          expandedIndex = isExpanded ? null : idx;
                        }),
                        onStartWeightChanged: (v) => setState(() {
                          final wasSynced =
                              config.startWeight == config.endWeight;
                          config.startWeight = v;
                          if (wasSynced) {
                            config.endWeight = v;
                          }
                        }),
                        onEndWeightChanged: (v) => setState(() {
                          config.endWeight = v;
                        }),
                        onWarmupChanged: (v) =>
                            setState(() => config.includeWarmup = v),
                        onRestChanged: (v) =>
                            setState(() => config.restConfig = v),
                      );
                    }),

                    const SizedBox(height: 16),
                    _GroupSettings(
                      sets: sets,
                      interleaveWarmups: interleaveWarmups,
                      showInterleave: configs.length > 1,
                      onSetsChanged: (v) => setState(() => sets = v),
                      onInterleaveChanged: (v) =>
                          setState(() => interleaveWarmups = v),
                    ),
                    const SizedBox(height: 16),
                    _RestSettings(
                      restConfig: restConfig,
                      onChanged: (v) => setState(() => restConfig = v),
                    ),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: configs.isEmpty
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              final exerciseConfigs = configs.map((c) {
                                final config = ExerciseTypeConfig()
                                  ..exercise = c.exercise
                                  ..startWeight = c.startWeight
                                  ..endWeight = c.endWeight
                                  ..reps = c.reps
                                  ..includeWarmup = c.includeWarmup;
                                if (c.restConfig != null) {
                                  config.restConfig = c.restConfig!;
                                }
                                return config;
                              }).toList();
                              onAdd(
                                customName,
                                sets,
                                interleaveWarmups,
                                exerciseConfigs,
                                restConfig,
                              );
                            },
                      child: const Text(
                        'ADD GROUP',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// --- Shared widgets ---

class _EditableConfig {
  Exercise exercise;
  double startWeight;
  double endWeight;
  int reps;
  bool includeWarmup;
  RestConfig? restConfig;

  _EditableConfig({
    required this.exercise,
    required this.startWeight,
    required this.endWeight,
    required this.reps,
    required this.includeWarmup,
    this.restConfig,
  });
}

class _ExerciseChipSelector extends StatelessWidget {
  final List<_EditableConfig> configs;
  final List<ExerciseStatus> exerciseStatuses;
  final void Function(Exercise exercise, bool selected) onToggle;

  const _ExerciseChipSelector({
    required this.configs,
    required this.exerciseStatuses,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: Exercise.values
              .where((e) => e != Exercise.EXERCISE_UNSPECIFIED)
              .map((e) {
                final isAdded = configs.any((c) => c.exercise == e);
                return FilterChip(
                  label: Text(
                    exerciseNames[e] ?? '?',
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: isAdded,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (selected) => onToggle(e, selected),
                );
              })
              .toList(),
        ),
      ],
    );
  }
}

/// Compact exercise config row. Tap to expand weight editor.
class _CompactExerciseConfig extends StatelessWidget {
  final _EditableConfig config;
  final bool isExpanded;
  final VoidCallback onTap;
  final ValueChanged<double> onStartWeightChanged;
  final ValueChanged<double> onEndWeightChanged;
  final ValueChanged<bool> onWarmupChanged;
  final ValueChanged<RestConfig> onRestChanged;

  const _CompactExerciseConfig({
    required this.config,
    required this.isExpanded,
    required this.onTap,
    required this.onStartWeightChanged,
    required this.onEndWeightChanged,
    required this.onWarmupChanged,
    required this.onRestChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = exerciseNames[config.exercise] ?? '?';
    final hasEndWeight = config.startWeight != config.endWeight;

    String formatWeight(double w) =>
        w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);

    final weightLabel = hasEndWeight
        ? '${formatWeight(config.startWeight)}→${formatWeight(config.endWeight)}lb'
        : '${formatWeight(config.startWeight)}lb';

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isExpanded
                  ? colorScheme.primary.withValues(alpha: 0.05)
                  : Colors.transparent,
              border: Border.all(
                color: isExpanded
                    ? colorScheme.primary.withValues(alpha: 0.3)
                    : colorScheme.outline,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Text(
                  weightLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'x${config.reps}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.tertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  config.includeWarmup
                      ? Icons.whatshot
                      : Icons.whatshot_outlined,
                  size: 16,
                  color: config.includeWarmup
                      ? colorScheme.primary
                      : colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: colorScheme.tertiary,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 8),
          _WeightEditor(
            startWeight: config.startWeight,
            endWeight: config.endWeight,
            includeWarmup: config.includeWarmup,
            onStartWeightChanged: onStartWeightChanged,
            onEndWeightChanged: onEndWeightChanged,
            onWarmupChanged: onWarmupChanged,
          ),
          const SizedBox(height: 8),
        ],
        if (!isExpanded) const SizedBox(height: 6),
      ],
    );
  }
}

/// Inline weight editor with plate viz, buttons, and optional end weight.
class _WeightEditor extends StatelessWidget {
  final double startWeight;
  final double endWeight;
  final bool includeWarmup;
  final ValueChanged<double> onStartWeightChanged;
  final ValueChanged<double> onEndWeightChanged;
  final ValueChanged<bool> onWarmupChanged;

  const _WeightEditor({
    required this.startWeight,
    required this.endWeight,
    required this.includeWarmup,
    required this.onStartWeightChanged,
    required this.onEndWeightChanged,
    required this.onWarmupChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasEndWeight = startWeight != endWeight;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          // Start weight section
          if (hasEndWeight)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'START WEIGHT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: colorScheme.tertiary,
                ),
              ),
            ),
          _WeightControl(weight: startWeight, onChanged: onStartWeightChanged),

          // End weight toggle + section
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              if (hasEndWeight) {
                onEndWeightChanged(startWeight);
              } else {
                onEndWeightChanged(startWeight);
                // Set a default drop: 80% of start weight rounded to 5
                final drop = ((startWeight * 0.8) / 5).round() * 5.0;
                onEndWeightChanged(drop.clamp(0, 1000));
              }
            },
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasEndWeight
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 18,
                    color: hasEndWeight
                        ? colorScheme.primary
                        : colorScheme.tertiary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'DIFFERENT END WEIGHT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: hasEndWeight
                          ? colorScheme.primary
                          : colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (hasEndWeight) ...[
            const SizedBox(height: 8),
            Text(
              'END WEIGHT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: colorScheme.tertiary,
              ),
            ),
            const SizedBox(height: 4),
            _WeightControl(weight: endWeight, onChanged: onEndWeightChanged),
          ],

          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'WARMUP',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.tertiary,
                ),
              ),
              Switch(value: includeWarmup, onChanged: onWarmupChanged),
            ],
          ),
        ],
      ),
    );
  }
}

/// Reusable weight display + buttons + slider.
class _WeightControl extends StatelessWidget {
  final double weight;
  final ValueChanged<double> onChanged;

  const _WeightControl({required this.weight, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${weight.toInt()}',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 4),
            Text(
              'LB',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: colorScheme.tertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        PlateVisualization(weight: weight),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _WeightButton(
              label: '-45',
              onPressed: () => onChanged((weight - 45).clamp(0, 1000)),
            ),
            _WeightButton(
              label: '-5',
              onPressed: () => onChanged((weight - 5).clamp(0, 1000)),
            ),
            _WeightButton(
              label: '+5',
              onPressed: () => onChanged((weight + 5).clamp(0, 1000)),
            ),
            _WeightButton(
              label: '+45',
              onPressed: () => onChanged((weight + 45).clamp(0, 1000)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: weight.clamp(0, 500),
          min: 0,
          max: 500,
          divisions: 100,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Group-level settings: sets count + interleave warmups toggle.
class _GroupSettings extends StatelessWidget {
  final int sets;
  final bool interleaveWarmups;
  final bool showInterleave;
  final ValueChanged<int> onSetsChanged;
  final ValueChanged<bool> onInterleaveChanged;

  const _GroupSettings({
    required this.sets,
    required this.interleaveWarmups,
    required this.showInterleave,
    required this.onSetsChanged,
    required this.onInterleaveChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
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
                  _CountButton(
                    icon: Icons.remove,
                    onPressed: () => onSetsChanged((sets - 1).clamp(1, 10)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '$sets',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _CountButton(
                    icon: Icons.add,
                    onPressed: () => onSetsChanged((sets + 1).clamp(1, 10)),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showInterleave)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'INTERLEAVE WARMUPS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.tertiary,
                    letterSpacing: 1.0,
                  ),
                ),
                Switch(
                  value: interleaveWarmups,
                  onChanged: onInterleaveChanged,
                ),
              ],
            ),
          ),
      ],
    );
  }
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

class _WeightButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _WeightButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(56, 36),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
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

Future<void> showHealthPermissionDialog(BuildContext context) async {
  final isAndroid = Platform.isAndroid;
  final storeName = isAndroid ? 'Health Connect' : 'Apple Health';
  final steps = isAndroid
      ? 'Open Settings > Apps > Lift > Health Connect, then enable workout permissions.'
      : 'Open Settings > Health > Data Access > Lift, then enable workout permissions.';

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(
        'Sync Workouts',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: Text(
        'Lift can save workouts to $storeName so they appear in your fitness apps.\n\n$steps',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

class _RestSettings extends StatelessWidget {
  final RestConfig restConfig;
  final ValueChanged<RestConfig> onChanged;

  const _RestSettings({required this.restConfig, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Default values if not set
    final success = restConfig.restAfterSuccess > 0
        ? restConfig.restAfterSuccess
        : 180;
    final failure = restConfig.restAfterFailure > 0
        ? restConfig.restAfterFailure
        : 300;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REST SETTINGS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: colorScheme.tertiary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _RestField(
                label: 'SUCCESS',
                seconds: success,
                onChanged: (v) {
                  final newRc = restConfig.deepCopy()..restAfterSuccess = v;
                  onChanged(newRc);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _RestField(
                label: 'FAILURE',
                seconds: failure,
                onChanged: (v) {
                  final newRc = restConfig.deepCopy()..restAfterFailure = v;
                  onChanged(newRc);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RestField extends StatelessWidget {
  final String label;
  final int seconds;
  final ValueChanged<int> onChanged;

  const _RestField({
    required this.label,
    required this.seconds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: colorScheme.tertiary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _CountButton(
              icon: Icons.remove,
              onPressed: () => onChanged((seconds - 15).clamp(0, 600)),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${seconds}s',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            _CountButton(
              icon: Icons.add,
              onPressed: () => onChanged((seconds + 15).clamp(0, 600)),
            ),
          ],
        ),
      ],
    );
  }
}
