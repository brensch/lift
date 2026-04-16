import 'dart:ui';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercise_groups.dart';
import '../logic/exercises.dart';
import '../logic/user_profile.dart';
import '../logic/weight_units.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/multiplayer_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/set_log.dart';
import '../widgets/workout_modals.dart';
import '../widgets/heart_rate_chart.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    final mp = context.watch<MultiplayerProvider>();
    final auth = context.watch<AuthProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    if (wp.workout == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final groups = wp.exerciseGroups;
    final activeSetId = wp.activeSetId;
    final isEnded = wp.isWorkoutEnded;
    final focusedGroup = _focusedGroup(wp, groups);
    final remainingGroups = groups
        .where((group) => !_isGroupCompleted(group, wp.completedSets))
        .toList(growable: false);
    final sessionMessages = wp.workoutMessages
        .where(
          (message) =>
              message.exerciseGroupId.isEmpty &&
              message.exercise == Exercise.EXERCISE_UNSPECIFIED,
        )
        .toList(growable: false);

    final sessionLedgerProposed = <ProposedSet>[...wp.proposedSets];
    final sessionLedgerCompleted = <CompletedSet>[...wp.completedSets];
    final workoutOwnerLabels = <String, String>{};
    final workoutOwnerEmojis = <String, String>{};
    if (wp.workout != null) {
      workoutOwnerLabels[wp.workout!.id] = 'You';
      workoutOwnerEmojis[wp.workout!.id] = normalizedProfileEmoji(
        auth.profileEmoji,
      );
    }
    if (mp.isInSession && mp.sessionStatus != null) {
      for (final participant in mp.participants) {
        sessionLedgerProposed.addAll(participant.proposedSets);
        sessionLedgerCompleted.addAll(participant.completedSets);
        if (participant.activeWorkoutId.isNotEmpty) {
          final rawName = participant.user.name.isNotEmpty
              ? participant.user.name
              : participant.user.id;
          workoutOwnerLabels[participant.activeWorkoutId] = rawName;
          workoutOwnerEmojis[participant.activeWorkoutId] =
              normalizedProfileEmoji(participant.user.profileEmoji);
        }
      }
    }
    final logProposedSets = sessionLedgerProposed;
    final logCompletedSets = sessionLedgerCompleted;

    final workout = wp.workout!;
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEnded ? 'Workout Completed' : 'Workout In Progress',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: colorScheme.tertiary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            workout.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.0,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (sessionMessages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _WorkoutMessagesSection(messages: sessionMessages),
          ),
        if (wp.wearHeartRateSamples.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: HeartRateChart(
              heartRateSamples: wp.wearHeartRateSamples,
              completedSets: wp.completedSets,
              workoutStartTime: workout.startTime,
              now: wp.now,
              stateSnapshot: wp.stateSnapshot,
              collapsible: true,
              startCollapsed: true,
            ),
          ),

        Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.8)),

        Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),

                child: Text(
                  focusedGroup != null
                      ? 'Current Exercise'
                      : 'Exercises Remaining',

                  style: TextStyle(
                    fontSize: 11,

                    fontWeight: FontWeight.bold,

                    letterSpacing: 1.5,

                    color: colorScheme.tertiary,
                  ),
                ),
              ),

              if (focusedGroup != null) ...[
                _CurrentExerciseCard(
                  group: focusedGroup,
                  messages: _messagesForWorkoutGroup(
                    focusedGroup,
                    wp.workoutMessages,
                  ),
                  completedSets: wp.completedSets,
                  activeSetId: activeSetId,
                  onEdit: () => _editCurrentGroup(context, wp, focusedGroup),
                ),
                const SizedBox(height: 16),
                Text(
                  'Exercises Remaining',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: colorScheme.tertiary,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              if (remainingGroups.isNotEmpty)
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: remainingGroups.length,
                  onReorder: (oldIndex, newIndex) {
                    if (isEnded || remainingGroups.length < 2) return;

                    if (oldIndex < newIndex) newIndex -= 1;

                    HapticFeedback.mediumImpact();

                    final items = List<ExerciseGroupData>.from(remainingGroups);
                    final item = items.removeAt(oldIndex);
                    items.insert(newIndex, item);

                    final groupIds = <String>[
                      ...items
                          .where((g) => g.group != null)
                          .map((g) => g.group!.id),
                      ...groups
                          .where((g) => _isGroupCompleted(g, wp.completedSets))
                          .where((g) => g.group != null)
                          .map((g) => g.group!.id),
                    ];
                    wp.reorderExerciseGroups(groupIds);
                  },
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        final animValue = Curves.easeInOut.transform(
                          animation.value,
                        );
                        final elevation = lerpDouble(0, 4, animValue)!;
                        return Material(
                          elevation: elevation,
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: child,
                        );
                      },
                      child: child,
                    );
                  },
                  itemBuilder: (context, idx) {
                    final group = remainingGroups[idx];
                    final stableKey = group.stableId;

                    return Padding(
                      key: ValueKey('reorder-$stableKey'),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _RemainingExerciseCard(
                        group: group,
                        messages: _messagesForWorkoutGroup(
                          group,
                          wp.workoutMessages,
                        ),
                        groupIndex: idx,
                        onDelete: () => _confirmDeleteGroup(context, wp, group),
                        onEdit: () => _editCurrentGroup(context, wp, group),
                      ),
                    );
                  },
                ),
              if (remainingGroups.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'No exercises remaining.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.tertiary,
                    ),
                  ),
                ),

              if (!isEnded) ...[
                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,

                  height: 44,

                  child: OutlinedButton.icon(
                    onPressed: () => _showAddExercise(context, wp),

                    icon: const Icon(Icons.add, size: 18),

                    label: const Text(
                      'Add Exercise',

                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.8)),

        Padding(
          padding: const EdgeInsets.all(16),

          child: SetLog(
            proposedSets: logProposedSets,
            completedSets: logCompletedSets,
            onDelete: isEnded ? null : (id) => wp.deleteCompletedSet(id),
            deletableWorkoutId: wp.workout?.id,
            workoutOwnerLabels: workoutOwnerLabels,
            workoutOwnerEmojis: workoutOwnerEmojis,
          ),
        ),

        if (!isEnded) ...[
          const SizedBox(height: 8),

          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.8)),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),

            child: SizedBox(
              width: double.infinity,

              height: 44,

              child: OutlinedButton(
                onPressed: () => endWorkout(context),

                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,

                  side: BorderSide(
                    color: colorScheme.error.withValues(alpha: 0.5),
                  ),
                ),

                child: const Text(
                  'End Workout',

                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  static bool _isGroupCompleted(
    ExerciseGroupData group,
    List<CompletedSet> completedSets,
  ) {
    final workingSets = group.sets.where((s) => !s.warmup).toList();
    if (workingSets.isEmpty) return false;
    final completedCount = workingSets
        .where(
          (s) => completedSets.any(
            (c) => c.proposedSetId == s.id && c.endedAt != Int64.ZERO,
          ),
        )
        .length;
    return completedCount == workingSets.length;
  }

  static ExerciseGroupData? _focusedGroup(
    WorkoutProvider wp,
    List<ExerciseGroupData> groups,
  ) {
    final focusedSet = wp.stateSnapshot?.hasDisplaySet() == true
        ? wp.stateSnapshot!.displaySet
        : wp.nextPendingSet;
    if (focusedSet == null) return null;
    return groups.cast<ExerciseGroupData?>().firstWhere(
      (group) => group!.sets.any((set) => set.id == focusedSet.id),
      orElse: () => null,
    );
  }

  Future<void> _confirmDeleteGroup(
    BuildContext context,
    WorkoutProvider wp,
    ExerciseGroupData group,
  ) async {
    final confirmed = await showDeleteGroupDialog(
      context,
      group.group?.name ?? exerciseNames[group.exercise] ?? '?',
    );
    if (confirmed != true || !context.mounted) return;

    final deleteIndex = wp.exerciseGroups.indexWhere(
      (candidate) => candidate.stableId == group.stableId,
    );
    if (deleteIndex == -1) return;
    wp.deleteExerciseGroup(deleteIndex);
  }

  void _showAddExercise(BuildContext context, WorkoutProvider wp) {
    showAddExerciseDialog(
      context,
      exerciseStatuses: wp.exerciseStatuses,
      onAdd: (name, sets, interleaveWarmups, exerciseConfigs, restConfig) {
        final finalName = name.isNotEmpty
            ? name
            : exerciseConfigs
                  .map(
                    (c) =>
                        exerciseNames[Exercise.valueOf(c.exercise.value)] ??
                        '?',
                  )
                  .join(' / ');

        wp.addExerciseGroup(
          name: finalName,
          sets: sets,
          interleaveWarmups: interleaveWarmups,
          exerciseConfigs: exerciseConfigs,
          restConfig: restConfig,
        );
      },
    );
  }

  void _editCurrentGroup(
    BuildContext context,
    WorkoutProvider wp,
    ExerciseGroupData group,
  ) {
    final groupIndex = wp.exerciseGroups.indexWhere(
      (candidate) => candidate.stableId == group.stableId,
    );
    if (groupIndex == -1) return;

    showEditExerciseDialog(
      context,
      group: group,
      groupIndex: groupIndex,
      exerciseStatuses: wp.exerciseStatuses,
      isSetDone: wp.isSetDone,
      onSave:
          (
            groupIndex, {
            required int sets,
            required bool interleaveWarmups,
            required List<ExerciseTypeConfig> exerciseConfigs,
            RestConfig? restConfig,
          }) {
            wp.updateGroup(
              groupIndex,
              sets: sets,
              interleaveWarmups: interleaveWarmups,
              exerciseConfigs: exerciseConfigs,
              restConfig: restConfig,
            );
          },
    );
  }
}

List<UserMessage> _messagesForWorkoutGroup(
  ExerciseGroupData group,
  List<UserMessage> messages,
) {
  final groupId = group.group?.id ?? '';
  final exercises = <Exercise>{group.exercise, ...group.exercises};
  final seen = <String>{};
  final out = <UserMessage>[];
  for (final message in messages) {
    final matchesGroupId =
        groupId.isNotEmpty && message.exerciseGroupId == groupId;
    final matchesExercise =
        message.exerciseGroupId.isEmpty &&
        message.exercise != Exercise.EXERCISE_UNSPECIFIED &&
        exercises.contains(message.exercise);
    if (!matchesGroupId && !matchesExercise) continue;
    if (!seen.add(message.messageKey)) continue;
    out.add(message);
  }
  return out;
}

class _WorkoutMessagesSection extends StatelessWidget {
  final List<UserMessage> messages;

  const _WorkoutMessagesSection({required this.messages});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.read<WorkoutProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Session updates',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: colorScheme.tertiary,
          ),
        ),
        const SizedBox(height: 8),
        for (final message in messages.take(6)) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.title.isNotEmpty)
                        Text(
                          message.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      if (message.title.isNotEmpty) const SizedBox(height: 4),
                      Text(
                        message.body,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: colorScheme.onSurface.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
                if (message.dismissible) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () =>
                        provider.dismissUserMessages([message.messageKey]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CurrentExerciseCard extends StatelessWidget {
  final ExerciseGroupData group;
  final List<UserMessage> messages;
  final List<CompletedSet> completedSets;
  final String? activeSetId;
  final VoidCallback onEdit;

  const _CurrentExerciseCard({
    required this.group,
    required this.messages,
    required this.completedSets,
    required this.activeSetId,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title =
        group.group?.name ?? exerciseNames[group.exercise] ?? 'Exercise';

    final activeSet = group.sets.cast<ProposedSet?>().firstWhere(
      (set) => set?.id == activeSetId,
      orElse: () => null,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: activeSet != null
              ? AppTheme.workoutLiftingFg.withValues(alpha: 0.35)
              : colorScheme.outline.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onEdit,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (messages.isNotEmpty) ...[
            _ExerciseMessagesBlock(messages: messages),
            const SizedBox(height: 14),
          ],
          if (group.sets.any((set) => set.warmup)) ...[
            _SetProgressSection(
              label: 'Warmup',
              children: group.sets
                  .where((set) => set.warmup)
                  .map(
                    (set) => _CurrentSetChip(
                      set: set,
                      completedSets: completedSets,
                      activeSetId: activeSetId,
                      isSuperset: group.exercises.length > 1,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
          ],
          if (group.sets.any((set) => !set.warmup))
            _SetProgressSection(
              label: 'Working Sets',
              children: group.sets
                  .where((set) => !set.warmup)
                  .map(
                    (set) => _CurrentSetChip(
                      set: set,
                      completedSets: completedSets,
                      activeSetId: activeSetId,
                      isSuperset: group.exercises.length > 1,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _SetProgressSection extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _SetProgressSection({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.35,
            color: colorScheme.tertiary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

class _CurrentSetChip extends StatelessWidget {
  final ProposedSet set;
  final List<CompletedSet> completedSets;
  final String? activeSetId;
  final bool isSuperset;

  const _CurrentSetChip({
    required this.set,
    required this.completedSets,
    required this.activeSetId,
    required this.isSuperset,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final exerciseName = exerciseNames[set.exercise] ?? '?';
    final exerciseMarker = exerciseName.isNotEmpty ? exerciseName[0] : '?';
    final completed = completedSets.cast<CompletedSet?>().firstWhere(
      (c) => c!.proposedSetId == set.id && c.endedAt != Int64.ZERO,
      orElse: () => null,
    );
    final isActive = set.id == activeSetId;
    final weight = formatWeight(set.targetWeight.toDouble(), unit);
    final targetText = set.isAmrap ? '${set.targetReps}+' : '${set.targetReps}';

    Color bg;
    Color fg;
    Color borderColor;
    String mainText;

    if (completed != null) {
      final hitTarget = completed.actualReps >= set.targetReps;
      bg = hitTarget ? AppTheme.successBg : AppTheme.warningBg;
      fg = hitTarget ? AppTheme.successFg : AppTheme.warningFg;
      borderColor = fg.withValues(alpha: 0.25);
      mainText = '${completed.actualReps}/$targetText';
    } else if (set.warmup) {
      bg = isActive
          ? AppTheme.warmupLight
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);
      fg = isActive
          ? AppTheme.warmupFg
          : colorScheme.onSurface.withValues(alpha: 0.78);
      borderColor = isActive
          ? AppTheme.warmupFg.withValues(alpha: 0.4)
          : colorScheme.outline.withValues(alpha: 0.22);
      mainText = '$weight · $targetText';
    } else if (isActive) {
      bg = AppTheme.workoutLiftingBg;
      fg = AppTheme.workoutLiftingFg;
      borderColor = AppTheme.workoutLiftingFg.withValues(alpha: 0.4);
      mainText = '$weight · $targetText';
    } else {
      bg = colorScheme.surfaceContainerLowest;
      fg = colorScheme.onSurface;
      borderColor = colorScheme.outline.withValues(alpha: 0.22);
      mainText = '$weight · $targetText';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        isSuperset ? '$exerciseMarker $mainText' : mainText,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.3,
          color: fg,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _RemainingExerciseCard extends StatelessWidget {
  final ExerciseGroupData group;
  final List<UserMessage> messages;
  final int groupIndex;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _RemainingExerciseCard({
    required this.group,
    required this.messages,
    required this.groupIndex,
    required this.onDelete,
    required this.onEdit,
  });

  double? _maxWorkingWeight() {
    double? maxWeight;
    for (final set in group.sets.where((set) => !set.warmup)) {
      final weight = set.targetWeight.toDouble();
      if (maxWeight == null || weight > maxWeight) {
        maxWeight = weight;
      }
    }
    return maxWeight;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final weight = _maxWorkingWeight();
    final setCount = group.sets.where((set) => !set.warmup).length;
    final weightLabel = weight == null
        ? 'No weight'
        : formatWeight(weight, unit, includeUnit: true);
    final title =
        group.group?.name ?? exerciseNames[group.exercise] ?? 'Exercise';

    Widget iconButton({
      required IconData icon,
      required VoidCallback onPressed,
      Color? color,
    }) {
      return IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size(30, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
        ),
        icon: Icon(
          icon,
          size: 18,
          color: color ?? colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ReorderableDragStartListener(
                index: groupIndex,
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.drag_indicator,
                    size: 18,
                    color: colorScheme.onSurface.withValues(alpha: 0.24),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: -0.3,
                    height: 1.0,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                weightLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$setCount sets',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface.withValues(alpha: 0.78),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              iconButton(icon: Icons.edit_outlined, onPressed: onEdit),
              iconButton(
                icon: Icons.delete_outline_rounded,
                onPressed: onDelete,
                color: colorScheme.error,
              ),
            ],
          ),
          if (messages.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ExerciseMessagesBlock(messages: messages),
          ],
        ],
      ),
    );
  }
}

class _ExerciseMessagesBlock extends StatelessWidget {
  final List<UserMessage> messages;

  const _ExerciseMessagesBlock({required this.messages});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.read<WorkoutProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.35,
            color: colorScheme.tertiary,
          ),
        ),
        const SizedBox(height: 6),
        for (final message in messages.take(3)) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.title.isNotEmpty)
                        Text(
                          message.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      if (message.title.isNotEmpty) const SizedBox(height: 4),
                      Text(
                        message.body,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: colorScheme.onSurface.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
                if (message.dismissible) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () =>
                        provider.dismissUserMessages([message.messageKey]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
