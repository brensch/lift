import 'dart:async';
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
import '../../widgets/exercise_picker.dart';
import '../../widgets/heart_rate/heart_rate_chart.dart';
import 'current_exercise_card.dart';
import 'exercise_list_card.dart';
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

    final hasHeartRate = wp.wearHeartRateSamples.isNotEmpty;

    // Overall progress across every working set, for the session strip's bar.
    var totalWorking = 0;
    var doneWorking = 0;
    for (final g in groups) {
      final working = g.sets.where((s) => !s.warmup);
      totalWorking += working.length;
      doneWorking += working
          .where(
            (s) => wp.completedSets.any(
              (c) => c.proposedSetId == s.id && c.endedAt != Int64.ZERO,
            ),
          )
          .length;
    }
    final overallProgress = totalWorking == 0 ? 0.0 : doneWorking / totalWorking;

    // Compose the session-strip header out of the "YYYY/MM/DD - Name" workout
    // name: bold title, a faded exercise summary, and the date pulled to the side.
    var sessionTitle = wp.workout!.name;
    var sessionDate = '';
    final nameMatch = RegExp(
      r'^(\d{4})/(\d{2})/(\d{2})\s*[-–—]\s*(.*)$',
    ).firstMatch(wp.workout!.name);
    if (nameMatch != null) {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final mo = int.tryParse(nameMatch.group(2)!) ?? 0;
      final day = int.tryParse(nameMatch.group(3)!) ?? 0;
      if (mo >= 1 && mo <= 12) sessionDate = '${months[mo - 1]} $day';
      sessionTitle = nameMatch.group(4)!.trim();
    }
    final seenExercises = <int>{};
    final exerciseShort = <String>[];
    for (final g in groups) {
      final exs = g.exercises.isNotEmpty ? g.exercises : [g.exercise];
      for (final ex in exs) {
        if (ex == Exercise.EXERCISE_UNSPECIFIED) continue;
        if (seenExercises.add(ex.value)) {
          final s = shortNames[ex] ?? exerciseNames[ex];
          if (s != null && s.isNotEmpty) exerciseShort.add(s);
        }
      }
    }
    final sessionSubtitle = exerciseShort.join(' · ');

    final loggedCount = wp.completedSets
        .where((c) => c.endedAt != Int64.ZERO)
        .length;
    final pageTabs = <PageTabItem>[
      const PageTabItem('Workout'),
      PageTabItem('Log', count: loggedCount > 0 ? loggedCount : null),
      const PageTabItem('Heart'),
    ];

    final workout = wp.workout!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Session strip: workout name + one slim overall-progress bar ──
        const SizedBox(height: 8),
        SessionStrip(
          title: sessionTitle,
          subtitle: sessionSubtitle,
          dateLabel: sessionDate,
          progress: overallProgress,
        ),
        const SizedBox(height: 8),
        // ── Named, swipeable page tabs ──
        PageTabs(
          tabs: pageTabs,
          index: _page,
          onTap: (i) => _pageController.animateToPage(
            i,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          ),
        ),
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
                                            completedSets: wp.completedSets,
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
                                          // onReorderItem hands back a newIndex
                                          // already adjusted for the removed item,
                                          // so no manual `newIndex -= 1`.
                                          onReorderItem: (oldIndex, newIndex) {
                                            if (isEnded ||
                                                unfinishedGroups.length < 2) {
                                              return;
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
                                                completedSets: wp.completedSets,
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
                            // unfinished item. Each list card is ExerciseListCard.height
                            // tall with an 8px gap, so it tracks down past completed cards.
                            if (showBracket)
                              Positioned(
                                // Overlap both card edges by 1px so the line meets their
                                // borders and reads as a single continuous outline.
                                left: leftWidth - 1,
                                width: gutter + 2,
                                top: 21.0 +
                                    ExerciseListCard.height / 2 +
                                    completedGroups.length *
                                        (ExerciseListCard.height + 8.0),
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

                  // End workout — a rare, one-way action, so demoted to a quiet
                  // link rather than a full-width button competing mid-screen.
                  if (!isEnded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 20),
                      child: Center(
                        child: TextButton(
                          onPressed: () => endWorkout(context),
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                          ),
                          child: const Text(
                            'End workout',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 0.2,
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
    // Pick movements only — the app prescribes weight, sets, reps, rest
    // and warmups from each exercise's tracker, same as a template start.
    // Nothing lands until SAVE; adjusting numbers is a separate flow.
    showExercisePicker(
      context: context,
      trackers: wp.trackers,
      initialSelected: const {},
      onSave: (selected) {
        if (selected.isEmpty) return;
        // Catalog order keeps the additions deterministic.
        final ordered = [
          for (final info in exerciseCatalog)
            if (selected.contains(info.exercise)) info.exercise,
        ];
        unawaited(wp.addPrescribedExercises(ordered));
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
      trackers: wp.trackers,
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

}


