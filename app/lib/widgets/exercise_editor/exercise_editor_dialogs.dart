/// Add / edit / delete dialogs for an exercise group's plan.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercises.dart';
import '../../logic/exercise_groups.dart';
import '../../theme/app_theme.dart';
import 'compact_exercise_config.dart';
import 'editable_config.dart';
import 'exercise_chip_selector.dart';
import 'group_settings.dart';

Future<void> showEditExerciseDialog(
  BuildContext context, {
  required ExerciseGroupData group,
  required int groupIndex,
  required List<ExerciseTracker> trackers,
  required bool Function(String setId) isSetDone,
  required void Function(
    int groupIndex, {
    required int sets,
    required bool interleaveWarmups,
    required List<ExerciseTypeConfig> exerciseConfigs,
    RestConfig? restConfig,
  })
  onSave,
  VoidCallback? onDelete,
}) async {
  int sets = group.group?.sets ?? 5;
  bool interleaveWarmups = group.group?.interleaveWarmups ?? false;
  RestConfig restConfig = group.group?.restConfig.deepCopy() ?? RestConfig();

  List<EditableConfig> editableConfigs = [];
  final currentSets = List<ProposedSet>.from(group.sets)
    ..sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
  final currentWorkingSets = currentSets.where((s) => !s.warmup).toList();

  if (currentSets.isNotEmpty) {
    final exercises = <Exercise>[];
    for (final set in currentSets) {
      if (!exercises.contains(set.exercise)) {
        exercises.add(set.exercise);
      }
    }

    for (final exercise in exercises) {
      final exerciseWorkingSets =
          currentWorkingSets.where((s) => s.exercise == exercise).toList()
            ..sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
      // Only the not-yet-completed sets get re-planned on an edit. Completed sets keep
      // their own (older) weight, so deriving start/end from them would look like an
      // intentional ramp on a later edit and leave the remaining sets unequal/unchanged.
      final pendingWorkingSets = exerciseWorkingSets
          .where((s) => !isSetDone(s.id))
          .toList();
      final refWorkingSets = pendingWorkingSets.isNotEmpty
          ? pendingWorkingSets
          : exerciseWorkingSets;
      final matchingConfig = group.group?.exerciseConfigs
          .cast<ExerciseTypeConfig?>()
          .firstWhere(
            (config) => config?.exercise == exercise,
            orElse: () => null,
          );

      final baseSet = refWorkingSets.isNotEmpty
          ? refWorkingSets.first
          : currentSets.firstWhere((s) => s.exercise == exercise);
      final endSet = refWorkingSets.isNotEmpty ? refWorkingSets.last : baseSet;

      editableConfigs.add(
        EditableConfig(
          exercise: exercise,
          startWeight: baseSet.targetWeight.toDouble(),
          endWeight: endSet.targetWeight.toDouble(),
          differentEndWeight:
              refWorkingSets.length > 1 &&
              baseSet.targetWeight != endSet.targetWeight,
          reps: baseSet.targetReps,
          includeWarmup: currentSets.any(
            (s) => s.warmup && s.exercise == exercise,
          ),
          restConfig: matchingConfig != null && matchingConfig.hasRestConfig()
              ? matchingConfig.restConfig.deepCopy()
              : null,
          lastSetAmrap:
              (matchingConfig?.lastSetAmrap ?? false) ||
              exerciseWorkingSets.any((s) => s.isAmrap),
        ),
      );
    }
  } else if (group.group != null && group.group!.exerciseConfigs.isNotEmpty) {
    for (final config in group.group!.exerciseConfigs) {
      editableConfigs.add(
        EditableConfig(
          exercise:
              Exercise.valueOf(config.exercise.value) ??
              Exercise.EXERCISE_UNSPECIFIED,
          startWeight: config.startWeight,
          endWeight: config.endWeight,
          differentEndWeight: config.startWeight != config.endWeight,
          reps: config.reps,
          includeWarmup: config.includeWarmup,
          restConfig: config.hasRestConfig()
              ? config.restConfig.deepCopy()
              : null,
          lastSetAmrap: config.lastSetAmrap,
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
        EditableConfig(
          exercise: ex,
          startWeight: weight,
          endWeight: weight,
          differentEndWeight: false,
          reps: workingSets.firstOrNull?.targetReps ?? 5,
          includeWarmup: group.sets.any((s) => s.warmup && s.exercise == ex),
          lastSetAmrap: workingSets.any((s) => s.isAmrap),
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
              color: AppTheme.sheetColor(ctx),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusLg),
              ),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.5),
              ),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 8,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: AppTheme.sheetHandle(ctx)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Edit ${group.group?.name ?? exerciseNames[group.exercise] ?? 'Unknown'}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
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
                  ExerciseChipSelector(
                    configs: editableConfigs,
                    trackers: trackers,
                    onToggle: (exercise, selected) {
                      setState(() {
                        if (selected) {
                          final tracker = trackers
                              .cast<ExerciseTracker?>()
                              .firstWhere(
                                (t) => t!.exercise == exercise,
                                orElse: () => null,
                              );
                          editableConfigs.add(
                            EditableConfig(
                              exercise: exercise,
                              startWeight: tracker?.workingWeight ?? 45,
                              endWeight: tracker?.workingWeight ?? 45,
                              differentEndWeight: false,
                              reps: tracker?.targetReps ?? 8,
                              includeWarmup: tracker?.includeWarmup ?? false,
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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CompactExerciseConfig(
                        key: ValueKey(config.exercise.value),
                        config: config,
                        isExpanded: isExpanded,
                        onTap: () => setState(() {
                          expandedIndex = isExpanded ? null : idx;
                        }),
                        onDelete: () => setState(() {
                          editableConfigs.removeAt(idx);
                          if (expandedIndex == idx) {
                            expandedIndex = null;
                          } else if (expandedIndex != null &&
                              expandedIndex! > idx) {
                            expandedIndex = expandedIndex! - 1;
                          }
                        }),
                        onStartWeightChanged: (v) => setState(() {
                          config.startWeight = v;
                          if (!config.differentEndWeight) {
                            config.endWeight = v;
                          }
                        }),
                        onEndWeightChanged: (v) => setState(() {
                          config.endWeight = v;
                        }),
                        onDifferentEndWeightChanged: (v) => setState(() {
                          config.differentEndWeight = v;
                          if (!v) {
                            config.endWeight = config.startWeight;
                          }
                        }),
                        onWarmupChanged: (v) =>
                            setState(() => config.includeWarmup = v),
                        onRestChanged: (v) =>
                            setState(() => config.restConfig = v),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                  GroupSettings(
                    sets: sets,
                    interleaveWarmups: interleaveWarmups,
                    showInterleave: editableConfigs.length > 1,
                    onSetsChanged: (v) => setState(() => sets = v),
                    onInterleaveChanged: (v) =>
                        setState(() => interleaveWarmups = v),
                  ),
                  const SizedBox(height: 16),
                  RestSettings(
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
                                  ..includeWarmup = c.includeWarmup
                                  ..lastSetAmrap = c.lastSetAmrap;
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
                  if (onDelete != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onDelete();
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Delete exercise',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(ctx).colorScheme.error,
                          side: BorderSide(
                            color: Theme.of(
                              ctx,
                            ).colorScheme.error.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ],
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
