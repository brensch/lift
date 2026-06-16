import 'dart:async';
import 'dart:io' show Platform;
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../gen/workout/v1/group.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../logic/exercise_groups.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/multiplayer_provider.dart';
import '../screens/completed_workout_screen.dart';
import '../widgets/exercise_group_widget.dart';
import 'plate_visualization.dart';

Future<void> endWorkout(BuildContext context) async {
  final confirmed = await showEndWorkoutConfirmDialog(context);
  if (confirmed && context.mounted) {
    final wp = context.read<WorkoutProvider>();
    final mp = context.read<MultiplayerProvider>();
    final settings = context.read<SettingsProvider>();
    final navigator = Navigator.of(context, rootNavigator: true);

    final workoutId = wp.workout?.id;
    if (workoutId == null) return;

    final completedRoute = MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => CompletedWorkoutScreen(workoutId: workoutId),
    );
    unawaited(navigator.push(completedRoute));

    await wp.endWorkout(fireEndedCallback: false);
    final endedWorkout = wp.workout;
    final endSucceeded =
        endedWorkout != null &&
        endedWorkout.id == workoutId &&
        wp.isWorkoutEnded;
    if (!endSucceeded) {
      if (navigator.canPop()) navigator.pop();
      return;
    }

    await settings.refreshActiveTrainingProgramState();
    mp.markLocalWorkoutFinished();
  }
}

Future<void> showParticipantWorkoutModal(
  BuildContext context,
  ParticipantStatus participant,
) async {
  final groups = _buildParticipantExerciseGroups(participant);
  final activeSetId = _participantActiveSetId(participant);
  final workoutEnded = _isParticipantWorkoutEnded(participant);
  final displayName = participant.user.name.isNotEmpty
      ? participant.user.name
      : participant.user.id;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final colorScheme = Theme.of(ctx).colorScheme;

      return Container(
        decoration: BoxDecoration(
          color: colorScheme.secondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "$displayName's Workout",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: colorScheme.onSurface,
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

              if (groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No workout data available.',
                    style: TextStyle(fontSize: 14, color: colorScheme.tertiary),
                  ),
                )
              else
                Column(
                  children: [
                    for (var i = 0; i < groups.length; i++) ...[
                      ExerciseGroupWidget(
                        group: groups[i],
                        completedSets: participant.completedSets,
                        activeSetId: activeSetId,
                        isWorkoutEnded: workoutEnded,
                      ),
                      if (i < groups.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    },
  );
}

List<ExerciseGroupData> _buildParticipantExerciseGroups(
  ParticipantStatus participant,
) {
  final proposedSets = participant.proposedSets.toList()
    ..sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
  if (proposedSets.isEmpty) return [];

  if (participant.exerciseGroups.isEmpty) {
    return groupSetsByExercise(proposedSets);
  }

  final groups = participant.exerciseGroups.toList()
    ..sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
  final usedSetIds = <String>{};
  final result = <ExerciseGroupData>[];

  for (final group in groups) {
    final groupSets = proposedSets
        .where((s) => s.exerciseGroupId == group.id)
        .toList();
    if (groupSets.isEmpty) continue;
    groupSets.sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
    usedSetIds.addAll(groupSets.map((set) => set.id));
    final exercise = group.exerciseConfigs.isNotEmpty
        ? Exercise.valueOf(group.exerciseConfigs.first.exercise.value) ??
              Exercise.EXERCISE_UNSPECIFIED
        : groupSets.isNotEmpty
        ? groupSets.first.exercise
        : Exercise.EXERCISE_UNSPECIFIED;
    final exercises = <Exercise>[];
    for (final config in group.exerciseConfigs) {
      final ex = Exercise.valueOf(config.exercise.value);
      if (ex != null && !exercises.contains(ex)) exercises.add(ex);
    }
    result.add(
      ExerciseGroupData(
        exercise: exercise,
        sets: groupSets,
        group: group,
        exercises: exercises,
      ),
    );
  }

  final leftover = proposedSets
      .where((set) => !usedSetIds.contains(set.id))
      .toList();
  if (leftover.isNotEmpty) {
    result.addAll(groupSetsByExercise(leftover));
  }

  return result;
}

String? _participantActiveSetId(ParticipantStatus participant) {
  for (final completed in participant.completedSets) {
    if (completed.endedAt == Int64.ZERO) {
      return completed.proposedSetId;
    }
  }
  return null;
}

bool _isParticipantWorkoutEnded(ParticipantStatus participant) {
  if (!participant.hasActiveWorkout()) return true;
  return participant.activeWorkout.endTime != Int64.ZERO;
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
        _EditableConfig(
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
        _EditableConfig(
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
        _EditableConfig(
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
                          'Edit ${group.group?.name ?? exerciseNames[group.exercise] ?? 'Unknown'}',
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
                              differentEndWeight: false,
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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CompactExerciseConfig(
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
                              differentEndWeight: false,
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
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CompactExerciseConfig(
                          key: ValueKey(config.exercise.value),
                          config: config,
                          isExpanded: isExpanded,
                          onTap: () => setState(() {
                            expandedIndex = isExpanded ? null : idx;
                          }),
                          onDelete: () => setState(() {
                            configs.removeAt(idx);
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
                                  ..includeWarmup = c.includeWarmup
                                  ..lastSetAmrap = c.lastSetAmrap;
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
  bool differentEndWeight;
  int reps;
  bool includeWarmup;
  RestConfig? restConfig;
  // Carried through edits so the last-set AMRAP marker + instruction survive a
  // weight change. (Progression itself is reconciled server-side by exercise, so
  // it does not depend on this round-trip.)
  bool lastSetAmrap;

  _EditableConfig({
    required this.exercise,
    required this.startWeight,
    required this.endWeight,
    this.differentEndWeight = false,
    required this.reps,
    required this.includeWarmup,
    this.restConfig,
    this.lastSetAmrap = false,
  });
}

class _ExerciseChipSelector extends StatefulWidget {
  final List<_EditableConfig> configs;
  final List<ExerciseStatus> exerciseStatuses;
  final void Function(Exercise exercise, bool selected) onToggle;

  const _ExerciseChipSelector({
    required this.configs,
    required this.exerciseStatuses,
    required this.onToggle,
  });

  @override
  State<_ExerciseChipSelector> createState() => _ExerciseChipSelectorState();
}

class _ExerciseChipSelectorState extends State<_ExerciseChipSelector> {
  final TextEditingController _searchController = TextEditingController();
  final MenuController _menuController = MenuController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_query != _searchController.text) {
        setState(() {
          _query = _searchController.text;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final exercises = Exercise.values
        .where((e) => e != Exercise.EXERCISE_UNSPECIFIED)
        .toList();

    final filtered = exercises.where((e) {
      final name = exerciseNames[e]?.toLowerCase() ?? '';
      return name.contains(_query.toLowerCase());
    }).toList();

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
        MenuAnchor(
          controller: _menuController,
          style: MenuStyle(
            maximumSize: const WidgetStatePropertyAll(Size.fromHeight(300)),
            backgroundColor: WidgetStatePropertyAll(colorScheme.surface),
            surfaceTintColor: WidgetStatePropertyAll(colorScheme.surface),
            elevation: const WidgetStatePropertyAll(8),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          menuChildren: filtered.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No exercises found'),
                  ),
                ]
              : filtered.map((e) {
                  final isAdded = widget.configs.any((c) => c.exercise == e);
                  return MenuItemButton(
                    closeOnActivate: false,
                    onPressed: () {
                      widget.onToggle(e, !isAdded);
                      setState(() {});
                    },
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width - 64,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              isAdded
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              size: 20,
                              color: isAdded
                                  ? colorScheme.primary
                                  : colorScheme.outline,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                exerciseNames[e] ?? '?',
                                style: TextStyle(
                                  fontWeight: isAdded
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
          builder: (context, controller, child) {
            return TextField(
              controller: _searchController,
              onTap: () => controller.open(),
              onChanged: (v) {
                if (!controller.isOpen) controller.open();
              },
              decoration: InputDecoration(
                hintText: 'Search to add exercises...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outline),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Compact exercise config row. Tap to expand settings.
class _CompactExerciseConfig extends StatefulWidget {
  final _EditableConfig config;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<double> onStartWeightChanged;
  final ValueChanged<double> onEndWeightChanged;
  final ValueChanged<bool> onDifferentEndWeightChanged;
  final ValueChanged<bool> onWarmupChanged;
  final ValueChanged<RestConfig> onRestChanged;

  const _CompactExerciseConfig({
    super.key,
    required this.config,
    required this.isExpanded,
    required this.onTap,
    required this.onDelete,
    required this.onStartWeightChanged,
    required this.onEndWeightChanged,
    required this.onDifferentEndWeightChanged,
    required this.onWarmupChanged,
    required this.onRestChanged,
  });

  @override
  State<_CompactExerciseConfig> createState() => _CompactExerciseConfigState();
}

class _CompactExerciseConfigState extends State<_CompactExerciseConfig> {
  late FixedExtentScrollController _repsController;

  @override
  void initState() {
    super.initState();
    _repsController = FixedExtentScrollController(
      initialItem: (widget.config.reps - 1).clamp(0, 29),
    );
  }

  @override
  void didUpdateWidget(_CompactExerciseConfig oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.config.reps != oldWidget.config.reps) {
      final targetIndex = (widget.config.reps - 1).clamp(0, 29);
      if (_repsController.selectedItem != targetIndex) {
        _repsController.jumpToItem(targetIndex);
      }
    }
  }

  @override
  void dispose() {
    _repsController.dispose();
    super.dispose();
  }

  Future<void> _showWeightPicker(
    BuildContext context,
    double initialWeight,
    ValueChanged<double> onChanged,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _WeightPicker(initialWeight: initialWeight, onChanged: onChanged),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = exerciseNames[widget.config.exercise] ?? '?';
    final hasEndWeight = widget.config.differentEndWeight;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: widget.isExpanded
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
              : Colors.transparent,
          border: Border.all(
            color: widget.isExpanded
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outline.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Main Row
            InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(12),
                bottom: Radius.circular(widget.isExpanded ? 0 : 12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    // Exercise Name
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Weight Box (Start)
                    SizedBox(
                      height: 48,
                      child: _WeightDisplayBox(
                        weight: widget.config.startWeight,
                        onTap: () => _showWeightPicker(
                          context,
                          widget.config.startWeight,
                          widget.onStartWeightChanged,
                        ),
                      ),
                    ),

                    // 'x' separator
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'x',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.tertiary,
                        ),
                      ),
                    ),

                    // Reps Scrollwheel
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.5),
                        ),
                        color: colorScheme.surface,
                      ),
                      child: Stack(
                        children: [
                          ListWheelScrollView.useDelegate(
                            controller: _repsController,
                            itemExtent: 24, // Smaller extent to show neighbors
                            magnification: 1.3,
                            useMagnifier: true,
                            physics: const FixedExtentScrollPhysics(),
                            diameterRatio: 1.5,
                            squeeze: 1.2, // Squeeze items closer
                            perspective: 0.004,
                            onSelectedItemChanged: (index) {
                              widget.config.reps = index + 1;
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount:
                                  30, // Limit to 30 items (index 0 is rep 1)
                              builder: (context, index) {
                                final rep = index + 1;
                                return Center(
                                  child: Text(
                                    '$rep',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // Scroll indicators (gradients)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 12,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    colorScheme.surface,
                                    colorScheme.surface.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 12,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(8),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    colorScheme.surface,
                                    colorScheme.surface.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Settings Cog
                    Icon(
                      Icons.settings,
                      size: 20,
                      color: widget.isExpanded
                          ? colorScheme.primary
                          : colorScheme.tertiary,
                    ),
                  ],
                ),
              ),
            ),

            // Expanded Settings
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: widget.isExpanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
                          const Divider(),
                          const SizedBox(height: 8),

                          // Warmup & Delete Row
                          Row(
                            children: [
                              Switch(
                                value: widget.config.includeWarmup,
                                onChanged: widget.onWarmupChanged,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'WARMUP SET',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.tertiary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              IconButton.filledTonal(
                                onPressed: widget.onDelete,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: colorScheme.errorContainer,
                                  foregroundColor: colorScheme.onErrorContainer,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Different End Weight Row
                          Row(
                            children: [
                              Switch(
                                value: hasEndWeight,
                                onChanged: widget.onDifferentEndWeightChanged,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'DIFFERENT END WEIGHT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.tertiary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),

                          if (hasEndWeight) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                SizedBox(
                                  height: 48,
                                  child: _WeightDisplayBox(
                                    weight: widget.config.endWeight,
                                    onTap: () => _showWeightPicker(
                                      context,
                                      widget.config.endWeight,
                                      widget.onEndWeightChanged,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightDisplayBox extends StatelessWidget {
  final double weight;
  final VoidCallback onTap;

  const _WeightDisplayBox({required this.weight, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final displayWeight = snapDisplayWeight(
      displayWeightFromPounds(weight, unit),
      unit,
      poundStep: 5,
      kilogramStep: isMetricUnit(unit) ? 2.5 : 5,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 32,
              width: 56,
              child: FittedBox(
                alignment: Alignment.centerLeft,
                child: PlateVisualization(weight: weight, isInteractive: false),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              displayWeight % 1 == 0
                  ? displayWeight.toStringAsFixed(0)
                  : displayWeight.toStringAsFixed(1),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 4),
            Text(
              weightUnitSuffix(unit),
              style: TextStyle(fontSize: 12, color: colorScheme.tertiary),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 14, color: colorScheme.tertiary),
          ],
        ),
      ),
    );
  }
}

class _WeightPicker extends StatefulWidget {
  final double initialWeight;
  final ValueChanged<double> onChanged;

  const _WeightPicker({required this.initialWeight, required this.onChanged});

  @override
  State<_WeightPicker> createState() => _WeightPickerState();
}

class _WeightPickerState extends State<_WeightPicker> {
  late double _displayWeight;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    final unit = context.read<SettingsProvider>().weightUnit;
    _displayWeight = snapDisplayWeight(
      displayWeightFromPounds(widget.initialWeight, unit),
      unit,
      poundStep: 5,
      kilogramStep: isMetricUnit(unit) ? 2.5 : 5,
    );
    _textController = TextEditingController(
      text: _displayWeight % 1 == 0
          ? _displayWeight.toStringAsFixed(0)
          : _displayWeight.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _updateWeight(double newDisplayWeight) {
    final unit = context.read<SettingsProvider>().weightUnit;
    setState(() {
      _displayWeight = newDisplayWeight.clamp(
        0,
        isMetricUnit(unit) ? 300 : 600,
      );
      _textController.text = _displayWeight % 1 == 0
          ? _displayWeight.toStringAsFixed(0)
          : _displayWeight.toStringAsFixed(1);
    });
    widget.onChanged(poundsFromDisplayWeight(_displayWeight, unit));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final smallStep = isMetricUnit(unit) ? 2.5 : 5.0;
    final bigStep = isMetricUnit(unit) ? 20.0 : 45.0;
    final maxDisplay = isMetricUnit(unit) ? 300.0 : 600.0;
    final sliderDivisions = (maxDisplay / smallStep).round();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SET WEIGHT',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Weight Input & Display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _textController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    final w = double.tryParse(val);
                    if (w != null) {
                      _updateWeight(w);
                    }
                  },
                ),
              ),
              Text(
                weightUnitSuffix(unit).toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          PlateVisualization(
            weight: poundsFromDisplayWeight(_displayWeight, unit),
            scale: 1.2,
          ),
          const SizedBox(height: 24),

          // Quick Adjust Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _WeightAdjustBtn(
                label: '-${bigStep % 1 == 0 ? bigStep.toInt() : bigStep}',
                onPressed: () => _updateWeight(_displayWeight - bigStep),
              ),
              _WeightAdjustBtn(
                label: '-${smallStep % 1 == 0 ? smallStep.toInt() : smallStep}',
                onPressed: () => _updateWeight(_displayWeight - smallStep),
              ),
              _WeightAdjustBtn(
                label: '+${smallStep % 1 == 0 ? smallStep.toInt() : smallStep}',
                onPressed: () => _updateWeight(_displayWeight + smallStep),
              ),
              _WeightAdjustBtn(
                label: '+${bigStep % 1 == 0 ? bigStep.toInt() : bigStep}',
                onPressed: () => _updateWeight(_displayWeight + bigStep),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Slider
          Slider(
            value: _displayWeight.clamp(0, maxDisplay),
            min: 0,
            max: maxDisplay,
            divisions: sliderDivisions,
            label: _displayWeight % 1 == 0
                ? _displayWeight.toStringAsFixed(0)
                : _displayWeight.toStringAsFixed(1),
            onChanged: _updateWeight,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _WeightAdjustBtn extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _WeightAdjustBtn({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
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
      ? 'Open Settings > Apps > Schlift > Health Connect, then enable workout permissions.'
      : 'Open Settings > Health > Data Access > Schlift, then enable workout permissions.';

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(
        'Sync Workouts',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: Text(
        'Schlift can save workouts to $storeName so they appear in your fitness apps.\n\n$steps',
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
