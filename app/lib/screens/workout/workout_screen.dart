import 'dart:ui';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercise_groups.dart';
import '../../logic/exercises.dart';
import '../../logic/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/workout_provider.dart';
import '../../providers/multiplayer_provider.dart';
import '../../widgets/set_log.dart';
import '../../widgets/dialogs/end_workout_dialog.dart';
import '../../widgets/exercise_editor/exercise_editor_dialogs.dart';
import '../../widgets/heart_rate_chart.dart';
import 'current_exercise_card.dart';
import 'exercise_list_card.dart';
import 'exschplanation_page.dart';
import 'workout_panels.dart';

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
        PageDots(
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
                                      const ColumnLabel('Current'),
                                      const SizedBox(height: 8),
                                      if (focusedGroup != null)
                                        CurrentExerciseCard(
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
                                        const EmptyPanel(
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
                                      const ColumnLabel(
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
                                          child: ExerciseListCard(
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
                                              child: ExerciseListCard(
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
                                        const EmptyPanel(
                                          text: 'No exercises remaining.',
                                        ),
                                      if (unfinishedGroups.length >= 2)
                                        const ReorderHint(),
                                      if (!isEnded) ...[
                                        const SizedBox(height: 8),
                                        AddExerciseButton(
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
                                child: BracketConnector(
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
                const NoHeartRateMonitor(),
              // ════ PAGE 4 — exschplanation ════
              if (hasExschplanation)
                ExschplanationPage(sections: exschplanationSections),
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

  List<ExschplanationSection> _buildExschplanationSections(
    WorkoutProvider wp,
  ) {
    final all = wp.workoutMessages;
    final seen = <String>{};
    final sections = <ExschplanationSection>[];

    final sessionMessages = all
        .where(
          (m) =>
              m.exerciseGroupId.isEmpty &&
              m.exercise == Exercise.EXERCISE_UNSPECIFIED,
        )
        .where((m) => seen.add(m.messageKey))
        .toList(growable: false);
    if (sessionMessages.isNotEmpty) {
      sections.add(ExschplanationSection('This session', sessionMessages));
    }

    for (final group in wp.exerciseGroups) {
      final groupMessages = _messagesForWorkoutGroup(
        group,
        all,
      ).where((m) => seen.add(m.messageKey)).toList(growable: false);
      if (groupMessages.isEmpty) continue;
      final title =
          group.group?.name ?? exerciseNames[group.exercise] ?? 'Exercise';
      sections.add(ExschplanationSection(title, groupMessages));
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

