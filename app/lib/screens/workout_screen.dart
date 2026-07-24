import 'dart:math' as math;
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
import '../widgets/user_message_chip.dart';
import '../widgets/dialogs/end_workout_dialog.dart';
import '../widgets/exercise_editor/exercise_editor_dialogs.dart';
import '../widgets/heart_rate_chart.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final PageController _pageController = PageController();
  int _page = 0;
  // While the user is touching the heart-rate chart we lock horizontal paging
  // so the chart's own pan/zoom gesture wins instead of the page swipe.
  bool _lockPager = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
    // Completed groups stay pinned (green) at the top of the list; only the
    // unfinished ones below them can be dragged/reordered.
    final completedGroups = groups
        .where((group) => _isGroupCompleted(group, wp.completedSets))
        .toList(growable: false);
    final unfinishedGroups = groups
        .where((group) => !_isGroupCompleted(group, wp.completedSets))
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

    final exschplanationSections = _buildExschplanationSections(wp);
    final hasExschplanation = exschplanationSections.isNotEmpty;
    final hasHeartRate = wp.wearHeartRateSamples.isNotEmpty;

    final workout = wp.workout!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Fixed header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
        _PageDots(
          // Workout + Completed + Heart rate are always present; Exschplanation
          // only when the schplanner has notes.
          count: 3 + (hasExschplanation ? 1 : 0),
          index: _page,
          onTap: (i) => _pageController.animateToPage(
            i,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          ),
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.8)),

        // ── Swipeable pages ──
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _page = i),
            physics: _lockPager
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            children: [
              // ════ PAGE 1 — the workout ════
              ListView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const gutter = 16.0;
                        final available = constraints.maxWidth - gutter;
                        final leftWidth = available * 0.6;
                        final rightWidth = available * 0.4;
                        final showBracket =
                            focusedGroup != null && unfinishedGroups.isNotEmpty;

                        return Stack(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── LEFT: current exercise detail ──
                                SizedBox(
                                  width: leftWidth,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _ColumnLabel('Current'),
                                      const SizedBox(height: 8),
                                      if (focusedGroup != null)
                                        _CurrentExerciseCard(
                                          group: focusedGroup,
                                          completedSets: wp.completedSets,
                                          activeSetId: activeSetId,
                                          onEdit: () => _editCurrentGroup(
                                            context,
                                            wp,
                                            focusedGroup,
                                          ),
                                        )
                                      else
                                        const _EmptyPanel(
                                          text: 'No active exercise.',
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: gutter),
                                // ── RIGHT: ordered, draggable list ──
                                SizedBox(
                                  width: rightWidth,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const _ColumnLabel(
                                        'All exercises',
                                        align: TextAlign.right,
                                      ),
                                      const SizedBox(height: 8),
                                      // Completed — pinned at the top, green, static.
                                      for (final group in completedGroups)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: _ExerciseListCard(
                                            group: group,
                                            completed: true,
                                            draggable: false,
                                          ),
                                        ),
                                      // Unfinished — draggable.
                                      if (unfinishedGroups.isNotEmpty)
                                        ReorderableListView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          buildDefaultDragHandles: false,
                                          itemCount: unfinishedGroups.length,
                                          onReorder: (oldIndex, newIndex) {
                                            if (isEnded ||
                                                unfinishedGroups.length < 2) {
                                              return;
                                            }
                                            if (oldIndex < newIndex) {
                                              newIndex -= 1;
                                            }
                                            HapticFeedback.mediumImpact();
                                            final items =
                                                List<ExerciseGroupData>.from(
                                                  unfinishedGroups,
                                                );
                                            final item = items.removeAt(
                                              oldIndex,
                                            );
                                            items.insert(newIndex, item);
                                            final groupIds = <String>[
                                              ...completedGroups
                                                  .where((g) => g.group != null)
                                                  .map((g) => g.group!.id),
                                              ...items
                                                  .where((g) => g.group != null)
                                                  .map((g) => g.group!.id),
                                            ];
                                            wp.reorderExerciseGroups(groupIds);
                                          },
                                          proxyDecorator:
                                              (child, index, animation) {
                                                return AnimatedBuilder(
                                                  animation: animation,
                                                  builder: (context, child) {
                                                    final animValue = Curves
                                                        .easeInOut
                                                        .transform(
                                                          animation.value,
                                                        );
                                                    final elevation =
                                                        lerpDouble(
                                                          0,
                                                          4,
                                                          animValue,
                                                        )!;
                                                    return Material(
                                                      elevation: elevation,
                                                      color: Colors.transparent,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      child: child,
                                                    );
                                                  },
                                                  child: child,
                                                );
                                              },
                                          itemBuilder: (context, idx) {
                                            final group = unfinishedGroups[idx];
                                            return Padding(
                                              key: ValueKey(
                                                'reorder-${group.stableId}',
                                              ),
                                              padding: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: _ExerciseListCard(
                                                group: group,
                                                completed: false,
                                                draggable: true,
                                                dragIndex: idx,
                                                onEdit: () => _editCurrentGroup(
                                                  context,
                                                  wp,
                                                  group,
                                                ),
                                              ),
                                            );
                                          },
                                        )
                                      else if (completedGroups.isEmpty)
                                        const _EmptyPanel(
                                          text: 'No exercises remaining.',
                                        ),
                                      if (unfinishedGroups.length >= 2)
                                        const _ReorderHint(),
                                      if (!isEnded) ...[
                                        const SizedBox(height: 8),
                                        _AddExerciseButton(
                                          onTap: () =>
                                              _showAddExercise(context, wp),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // ── Connector: links the Current detail card to the first
                            // unfinished item. Each list card is a fixed 52px tall with
                            // an 8px gap, so it tracks down past any completed cards.
                            if (showBracket)
                              Positioned(
                                // Overlap both card edges by 1px so the line meets their
                                // borders and reads as a single continuous outline.
                                left: leftWidth - 1,
                                width: gutter + 2,
                                top: 47.0 + completedGroups.length * 60.0,
                                height: 1.5,
                                child: _BracketConnector(
                                  color: colorScheme.outline.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),

                  if (!isEnded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // ════ PAGE 2 — completed sets ════
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SetLog(
                  proposedSets: logProposedSets,
                  completedSets: logCompletedSets,
                  onDelete: isEnded ? null : (id) => wp.deleteCompletedSet(id),
                  deletableWorkoutId: wp.workout?.id,
                  workoutOwnerLabels: workoutOwnerLabels,
                  workoutOwnerEmojis: workoutOwnerEmojis,
                  stickyHeader: true,
                ),
              ),
              // ════ PAGE 3 — heart rate (full detail) ════
              if (hasHeartRate)
                ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    // Lock page-swiping while touching the chart so its own
                    // left/right pan/zoom gesture takes priority.
                    Listener(
                      onPointerDown: (_) {
                        if (!_lockPager) setState(() => _lockPager = true);
                      },
                      onPointerUp: (_) {
                        if (_lockPager) setState(() => _lockPager = false);
                      },
                      onPointerCancel: (_) {
                        if (_lockPager) setState(() => _lockPager = false);
                      },
                      child: HeartRateChart(
                        heartRateSamples: wp.wearHeartRateSamples,
                        completedSets: wp.completedSets,
                        workoutStartTime: workout.startTime,
                        now: wp.now,
                        stateSnapshot: wp.stateSnapshot,
                        fullView: true,
                      ),
                    ),
                  ],
                )
              else
                const _NoHeartRateMonitor(),
              // ════ PAGE 4 — exschplanation ════
              if (hasExschplanation)
                _ExschplanationPage(sections: exschplanationSections),
            ],
          ),
        ),
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
      onDelete: () => _confirmDeleteGroup(context, wp, group),
    );
  }

  List<_ExschplanationSection> _buildExschplanationSections(
    WorkoutProvider wp,
  ) {
    final all = wp.workoutMessages;
    final seen = <String>{};
    final sections = <_ExschplanationSection>[];

    final sessionMessages = all
        .where(
          (m) =>
              m.exerciseGroupId.isEmpty &&
              m.exercise == Exercise.EXERCISE_UNSPECIFIED,
        )
        .where((m) => seen.add(m.messageKey))
        .toList(growable: false);
    if (sessionMessages.isNotEmpty) {
      sections.add(_ExschplanationSection('This session', sessionMessages));
    }

    for (final group in wp.exerciseGroups) {
      final groupMessages = _messagesForWorkoutGroup(
        group,
        all,
      ).where((m) => seen.add(m.messageKey)).toList(growable: false);
      if (groupMessages.isEmpty) continue;
      final title =
          group.group?.name ?? exerciseNames[group.exercise] ?? 'Exercise';
      sections.add(_ExschplanationSection(title, groupMessages));
    }

    return sections;
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

/// One titled section of the Exschplanation sheet — a session-wide or
/// per-exercise group of schplanner messages.
class _ExschplanationSection {
  final String title;
  final List<UserMessage> messages;
  const _ExschplanationSection(this.title, this.messages);
}

/// PAGE 3 — the schplanner's reasoning for today's workout.
class _ExschplanationPage extends StatelessWidget {
  final List<_ExschplanationSection> sections;

  const _ExschplanationPage({required this.sections});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Row(
          children: [
            Icon(
              Icons.psychology_alt_rounded,
              size: 22,
              color: colorScheme.tertiary,
            ),
            const SizedBox(width: 10),
            const Text(
              'Exschplanation',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Why the schplanner planned today this way.',
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        if (sections.isEmpty)
          Text(
            'No notes for this workout.',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          )
        else
          for (final section in sections) ...[
            Text(
              section.title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: colorScheme.tertiary,
              ),
            ),
            const SizedBox(height: 10),
            for (final message in section.messages)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: UserMessageChip(message: message),
              ),
            const SizedBox(height: 18),
          ],
      ],
    );
  }
}

class _CurrentExerciseCard extends StatelessWidget {
  final ExerciseGroupData group;
  final List<CompletedSet> completedSets;
  final String? activeSetId;
  final VoidCallback onEdit;

  const _CurrentExerciseCard({
    required this.group,
    required this.completedSets,
    required this.activeSetId,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title =
        group.group?.name ?? exerciseNames[group.exercise] ?? 'Exercise';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.3),
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

    // The set you're currently lifting shimmers through a rainbow.
    if (isActive && completed == null) {
      final base = '$weight · $targetText';
      return _RainbowSetChip(
        text: isSuperset ? '$exerciseMarker $base' : base,
      );
    }

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

/// The set chip for whatever you're lifting right now: a rainbow gradient that
/// sweeps across both the border and the text.
class _RainbowSetChip extends StatefulWidget {
  final String text;
  const _RainbowSetChip({required this.text});

  @override
  State<_RainbowSetChip> createState() => _RainbowSetChipState();
}

class _RainbowSetChipState extends State<_RainbowSetChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(seconds: 2),
    vsync: this,
  )..repeat();

  static const _colors = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.red,
  ];
  static const _stops = [0.0, 0.17, 0.33, 0.5, 0.67, 0.83, 1.0];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final gradient = LinearGradient(
          colors: _colors,
          stops: _stops,
          begin: Alignment(-2.0 + 4 * t, 0),
          end: Alignment(0.0 + 4 * t, 0),
          tileMode: TileMode.repeated,
        );
        return Container(
          // Gradient border drawn as a 1.5px frame behind the inner fill.
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12.5),
            ),
            child: ShaderMask(
              shaderCallback: (bounds) => gradient.createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: Text(
                widget.text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: Colors.white, // replaced by the shader
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ExerciseListCard extends StatelessWidget {
  static const double height = 52;

  final ExerciseGroupData group;
  final bool completed;
  final bool draggable;
  final int dragIndex;
  final VoidCallback? onEdit;

  const _ExerciseListCard({
    required this.group,
    required this.completed,
    required this.draggable,
    this.dragIndex = 0,
    this.onEdit,
  });

  ProposedSet? _topWorkingSet() {
    ProposedSet? top;
    for (final set in group.sets.where((set) => !set.warmup)) {
      if (top == null || set.targetWeight > top.targetWeight) {
        top = set;
      }
    }
    return top;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final title =
        group.group?.name ?? exerciseNames[group.exercise] ?? 'Exercise';
    final topSet = _topWorkingSet();
    final weightLabel = topSet == null
        ? '—'
        : formatWeight(topSet.targetWeight.toDouble(), unit, includeUnit: true);
    final repsLabel = topSet == null
        ? null
        : (topSet.isAmrap ? '${topSet.targetReps}+' : '${topSet.targetReps}');
    final contentColor = completed ? AppTheme.successFg : colorScheme.onSurface;

    Widget content = Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: -0.3,
              height: 1.05,
              color: contentColor,
            ),
          ),
          const SizedBox(height: 3),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: weightLabel),
                if (repsLabel != null)
                  TextSpan(
                    text: '  × $repsLabel',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              color: contentColor.withValues(alpha: completed ? 0.85 : 1),
            ),
          ),
        ],
      ),
    );

    // The whole tile is the drag target, except the trailing control.
    if (draggable) {
      content = ReorderableDragStartListener(index: dragIndex, child: content);
    }

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: completed
              ? AppTheme.successBg
              : colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: completed
                ? AppTheme.successFg.withValues(alpha: 0.35)
                : colorScheme.outline.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: content),
            if (completed)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: AppTheme.successFg,
                ),
              )
            else ...[
              IconButton(
                onPressed: onEdit,
                tooltip: 'Edit exercise',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 2),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Add-exercise button (dashed, same shape as the list cards) ─────────────

class _AddExerciseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddExerciseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = colorScheme.outline.withValues(alpha: 0.7);
    return SizedBox(
      height: _ExerciseListCard.height,
      child: CustomPaint(
        painter: _DashedRRectPainter(
          color: color,
          radius: 14,
          strokeWidth: 1.5,
          dash: 5,
          gap: 4,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Add',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final source = Path()..addRRect(rrect);
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final len = math.min(dash, metric.length - distance);
        canvas.drawPath(metric.extractPath(distance, distance + len), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap;
}

// ─── Reorder affordance hint ───────────────────────────────────────────────

class _ReorderHint extends StatelessWidget {
  const _ReorderHint();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withValues(
      alpha: 0.32,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.swap_vert_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            'drag to reorder',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── No heart-rate monitor placeholder ─────────────────────────────────────

class _NoHeartRateMonitor extends StatelessWidget {
  const _NoHeartRateMonitor();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.watch_outlined, size: 52, color: colorScheme.tertiary),
            const SizedBox(height: 18),
            Text(
              'No heart rate yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Get the watch app and you can see how hard you are pumping '
              'your heart while schlifting.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page indicator ────────────────────────────────────────────────────────

class _PageDots extends StatelessWidget {
  final int count;
  final int index;
  final ValueChanged<int> onTap;

  const _PageDots({
    required this.count,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < count; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: i == index ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == index
                      ? colorScheme.primary
                      : colorScheme.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Two-column scaffolding ────────────────────────────────────────────────

class _ColumnLabel extends StatelessWidget {
  final String text;
  final TextAlign align;
  const _ColumnLabel(this.text, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      text.toUpperCase(),
      textAlign: align,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        color: colorScheme.tertiary,
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final String text;
  const _EmptyPanel({required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: colorScheme.tertiary,
        ),
      ),
    );
  }
}

/// Joins the Current detail card (left) to the current list item (right) as if
/// their borders continue across the gap: same colour and weight as the card
/// borders, overlapping both edges so it reads as one connected outline.
class _BracketConnector extends StatelessWidget {
  final Color color;
  const _BracketConnector({required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 1.5,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
