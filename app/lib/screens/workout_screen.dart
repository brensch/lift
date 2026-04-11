import 'dart:ui';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercise_groups.dart';
import '../logic/exercises.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/multiplayer_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/participant_ticker.dart';
import '../widgets/set_log.dart';
import '../widgets/workout_modals.dart';
import '../widgets/heart_rate_chart.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  String? _dismissedWorkoutInfoId;
  String? _promptedWorkoutInfoId;

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    final mp = context.watch<MultiplayerProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    if (wp.workout == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final groups = wp.exerciseGroups;
    final activeSetId = wp.activeSetId;
    final isEnded = wp.isWorkoutEnded;
    final regimeContext = wp.regimeContext;
    final focusedGroup = _focusedGroup(wp, groups);
    final remainingGroups = groups
        .where((group) => !_isGroupCompleted(group, wp.completedSets))
        .toList(growable: false);

    final nextUpUserId = mp.sessionStatus?.nextUpUserId ?? '';
    final otherParticipants = mp.participants;
    final sessionLedgerProposed = <ProposedSet>[...wp.proposedSets];
    final sessionLedgerCompleted = <CompletedSet>[...wp.completedSets];
    final workoutOwnerLabels = <String, String>{};
    if (wp.workout != null) {
      workoutOwnerLabels[wp.workout!.id] = 'You';
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
        }
      }
    }
    final logProposedSets = sessionLedgerProposed;
    final logCompletedSets = sessionLedgerCompleted;

    final workout = wp.workout!;
    final hasWorkoutInfo =
        (regimeContext?.sessionDescription.isNotEmpty ?? false) ||
        (regimeContext?.coachingNotes.isNotEmpty ?? false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!hasWorkoutInfo) return;
      if (_promptedWorkoutInfoId == workout.id) return;
      _promptedWorkoutInfoId = workout.id;
      if (_dismissedWorkoutInfoId != workout.id) {
        _showWorkoutInfoDialog(workout.name, regimeContext);
      }
    });

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
                        if (hasWorkoutInfo &&
                            _dismissedWorkoutInfoId == workout.id) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _showWorkoutInfoDialog(
                              workout.name,
                              regimeContext,
                            ),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(28, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                            ),
                            icon: Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
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
                  completedSets: wp.completedSets,
                  activeSetId: activeSetId,
                  onEdit: () => _editCurrentGroup(context, wp, focusedGroup),
                  onInfo: () => _showGroupDetails(context, focusedGroup),
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
                        groupIndex: idx,
                        onDelete: () => _confirmDeleteGroup(context, wp, group),
                        onInfo: () => _showGroupDetails(context, group),
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

        // Participant cards (multiplayer)
        if (mp.isInSession && otherParticipants.isNotEmpty) ...[
          Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.8)),

          Padding(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),

                  child: Text(
                    'SESSION MEMBERS',

                    style: TextStyle(
                      fontSize: 11,

                      fontWeight: FontWeight.bold,

                      letterSpacing: 1.5,

                      color: colorScheme.tertiary,
                    ),
                  ),
                ),

                ...otherParticipants.map((p) {
                  final isNextUp =
                      nextUpUserId.isNotEmpty && nextUpUserId == p.user.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),

                    child: ParticipantCard(
                      participant: p,
                      isNextUp: isNextUp,
                      onTap: () => showParticipantWorkoutModal(context, p),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],

        Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.8)),

        Padding(
          padding: const EdgeInsets.all(16),

          child: SetLog(
            proposedSets: logProposedSets,
            completedSets: logCompletedSets,
            onDelete: isEnded ? null : (id) => wp.deleteCompletedSet(id),
            deletableWorkoutId: wp.workout?.id,
            workoutOwnerLabels: workoutOwnerLabels,
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

  void _showGroupDetails(BuildContext context, ExerciseGroupData group) {
    final rawGroup = group.group;
    if (rawGroup == null) return;
    showExerciseGroupDetailsSheet(
      context,
      title: rawGroup.name,
      explanation: rawGroup.instruction,
      exerciseConfigs: rawGroup.exerciseConfigs,
      fallbackSets: rawGroup.sets,
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

  Future<void> _showWorkoutInfoDialog(
    String workoutName,
    RegimeContext? regimeContext,
  ) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(
            workoutName,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (regimeContext != null &&
                    regimeContext.sessionDescription.isNotEmpty)
                  Text(
                    regimeContext.sessionDescription,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                if (regimeContext != null &&
                    regimeContext.sessionDescription.isNotEmpty &&
                    regimeContext.coachingNotes.isNotEmpty)
                  const SizedBox(height: 10),
                if (regimeContext != null &&
                    regimeContext.coachingNotes.isNotEmpty)
                  ...regimeContext.coachingNotes.map(
                    (note) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '· ',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.tertiary,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              note,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.tertiary.withValues(
                                  alpha: 0.9,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    setState(() {
      _dismissedWorkoutInfoId = context.read<WorkoutProvider>().workout?.id;
    });
  }
}

class _CurrentExerciseCard extends StatelessWidget {
  final ExerciseGroupData group;
  final List<CompletedSet> completedSets;
  final String? activeSetId;
  final VoidCallback onEdit;
  final VoidCallback onInfo;

  const _CurrentExerciseCard({
    required this.group,
    required this.completedSets,
    required this.activeSetId,
    required this.onEdit,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final stats = _CurrentExerciseStats.fromGroup(group, completedSets);
    final title =
        group.group?.name ?? exerciseNames[group.exercise] ?? 'Exercise';

    final activeSet = group.sets.cast<ProposedSet?>().firstWhere(
      (set) => set?.id == activeSetId,
      orElse: () => null,
    );
    final displaySet =
        activeSet ??
        group.sets.cast<ProposedSet?>().firstWhere(
          (set) => !completedSets.any(
            (completed) =>
                completed.proposedSetId == set?.id &&
                completed.endedAt != Int64.ZERO,
          ),
          orElse: () => null,
        );
    final currentWeight = displaySet == null
        ? null
        : formatWeight(
            displaySet.targetWeight.toDouble(),
            unit,
            includeUnit: true,
          );
    final currentReps = displaySet == null
        ? null
        : (displaySet.isAmrap
              ? '${displaySet.targetReps}+'
              : '${displaySet.targetReps}');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: activeSet != null
              ? const Color(0xFFEC4899).withValues(alpha: 0.35)
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
                  IconButton(
                    onPressed: onInfo,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CurrentSummaryChip(
                label: 'Warmups',
                value: '${stats.completedWarmupSets}/${stats.totalWarmupSets}',
                tint: AppTheme.warmupFg,
                background: AppTheme.warmupLight,
              ),
              _CurrentSummaryChip(
                label: 'Sets',
                value:
                    '${stats.completedWorkingSets}/${stats.totalWorkingSets}',
                tint:
                    stats.completedWorkingSets == stats.totalWorkingSets &&
                        stats.totalWorkingSets > 0
                    ? AppTheme.successFg
                    : colorScheme.onSurface,
                background:
                    stats.completedWorkingSets == stats.totalWorkingSets &&
                        stats.totalWorkingSets > 0
                    ? AppTheme.successBg
                    : colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.45,
                      ),
              ),
              _CurrentSummaryChip(
                label: 'Current',
                value: currentWeight != null && currentReps != null
                    ? '$currentWeight x $currentReps'
                    : '--',
                tint: displaySet == null
                    ? AppTheme.successFg
                    : displaySet.warmup
                    ? AppTheme.warmupFg
                    : (activeSet != null
                          ? const Color(0xFFEC4899)
                          : colorScheme.onSurface),
                background: displaySet == null
                    ? AppTheme.successBg
                    : displaySet.warmup
                    ? AppTheme.warmupLight
                    : (activeSet != null
                          ? const Color(0x1AEC4899)
                          : colorScheme.surfaceContainerHighest.withValues(
                              alpha: 0.45,
                            )),
              ),
            ],
          ),
          const SizedBox(height: 16),
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

class _CurrentSummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color tint;
  final Color background;

  const _CurrentSummaryChip({
    required this.label,
    required this.value,
    required this.tint,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: tint.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: tint,
            ),
          ),
        ],
      ),
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
      bg = const Color(0x1AEC4899);
      fg = const Color(0xFFEC4899);
      borderColor = const Color(0xFFEC4899).withValues(alpha: 0.4);
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

class _CurrentExerciseStats {
  final int completedWarmupSets;
  final int totalWarmupSets;
  final int completedWorkingSets;
  final int totalWorkingSets;

  const _CurrentExerciseStats({
    required this.completedWarmupSets,
    required this.totalWarmupSets,
    required this.completedWorkingSets,
    required this.totalWorkingSets,
  });

  factory _CurrentExerciseStats.fromGroup(
    ExerciseGroupData group,
    List<CompletedSet> completedSets,
  ) {
    final workingSets = group.sets.where((s) => !s.warmup).toList();
    final warmupSets = group.sets.where((s) => s.warmup).toList();

    bool isDone(ProposedSet set) => completedSets.any(
      (c) => c.proposedSetId == set.id && c.endedAt != Int64.ZERO,
    );

    final completedWorkingSets = workingSets.where(isDone).length;
    final completedWarmupSets = warmupSets.where(isDone).length;

    return _CurrentExerciseStats(
      completedWarmupSets: completedWarmupSets,
      totalWarmupSets: warmupSets.length,
      completedWorkingSets: completedWorkingSets,
      totalWorkingSets: workingSets.length,
    );
  }
}

class _RemainingExerciseCard extends StatelessWidget {
  final ExerciseGroupData group;
  final int groupIndex;
  final VoidCallback onDelete;
  final VoidCallback onInfo;
  final VoidCallback onEdit;

  const _RemainingExerciseCard({
    required this.group,
    required this.groupIndex,
    required this.onDelete,
    required this.onInfo,
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
      child: Row(
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
          iconButton(icon: Icons.info_outline_rounded, onPressed: onInfo),
          const SizedBox(width: 6),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
    );
  }
}
