import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';

import '../../tutorial/tutorial_target.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../gen/copy.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercise_blocks.dart';
import '../../logic/exercises.dart';
import '../../logic/session_state.dart';
import '../../logic/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/workout_provider.dart';
import '../../providers/multiplayer_provider.dart';
import '../../widgets/set_log.dart';
import '../../widgets/dialogs/end_workout_dialog.dart';
import '../../widgets/dialogs/weight_adjust_sheet.dart';
import '../../widgets/exercise_picker.dart';
import '../../widgets/heart_rate/heart_rate_chart.dart';
import '../../widgets/workout_bar/workout_focus.dart';
import 'exercise_section.dart';
import 'section_workout.dart';
import 'workout_panels.dart';
import '../../theme/theme_spec.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  /// The view on show: the workout, the log, or heart rate. Picked by its
  /// header; there is no swiping between them.
  int _page = 0;

  /// The exercise in hand, so a tap on the banner can bring it into view.
  final _focusKey = GlobalKey();

  /// The last request answered: a tap made from another page lands before
  /// this screen is built, so it catches up on its first frame.
  static int _answered = 0;

  @override
  void initState() {
    super.initState();
    workoutFocusRequests.addListener(_showFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (workoutFocusRequests.value != _answered) _showFocus();
    });
  }

  @override
  void dispose() {
    workoutFocusRequests.removeListener(_showFocus);
    super.dispose();
  }

  /// To the workout view, scrolled so the exercise in hand sits at the
  /// bottom, just above the banner.
  void _showFocus() {
    if (!mounted) return;
    _answered = workoutFocusRequests.value;
    if (_page != 0) setState(() => _page = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _focusKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
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

    final blocks = wp.exerciseBlocks;
    final isEnded = wp.isWorkoutEnded;
    final focusedBlock = _focusedBlock(wp, blocks);
    // Completed blocks stay pinned (green) at the top of the list; only the
    // unfinished ones below them can be dragged/reordered.
    final completedBlocks = blocks
        .where((block) => _isBlockCompleted(block, wp.completedSets))
        .toList(growable: false);
    final unfinishedBlocks = blocks
        .where((block) => !_isBlockCompleted(block, wp.completedSets))
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

    // Overall progress for the session strip's bar: every set still in the
    // plan (warmups and calibration rungs included, cancelled ones not), so
    // each Done moves it. An exercise still finding its weight has no
    // working sets yet; its planned ones count as still to come.
    var totalSets = 0;
    var doneSets = 0;
    for (final g in blocks) {
      final sets = g.sets.where((s) => !s.cancelled).toList();
      totalSets += sets.length;
      final calibrating =
          sets.any((s) => s.calibration) &&
          !sets.any((s) => !s.warmup && !s.calibration);
      if (calibrating) totalSets += wp.trackerFor(g.exercise)?.sets ?? 0;
      doneSets += sets
          .where(
            (s) => wp.completedSets.any(
              (c) => c.proposedSetId == s.id && c.endedAt != Int64.ZERO,
            ),
          )
          .length;
    }
    final overallProgress = totalSets == 0 ? 0.0 : doneSets / totalSets;

    // The header shows the workout's name, without the "YYYY/MM/DD - "
    // prefix workouts are stored with.
    final sessionTitle =
        RegExp(
          r'^\d{4}/\d{2}/\d{2}\s*[-–—]\s*(.*)$',
        ).firstMatch(wp.workout!.name)?.group(1)?.trim() ??
        wp.workout!.name;

    final loggedCount = wp.completedSets
        .where((c) => c.endedAt != Int64.ZERO)
        .length;
    final pageTabs = <PageTabItem>[
      const PageTabItem('Workout'),
      PageTabItem('Log', count: loggedCount > 0 ? loggedCount : null),
      const PageTabItem('Heart'),
    ];

    final workout = wp.workout!;
    final sectionWorkout = SectionWorkout.mine(wp);
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: context.tokens.hairline,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Session strip: workout name with overall progress beside it ──
        const SizedBox(height: 8),
        ValueListenableBuilder<DateTime>(
          valueListenable: wp.clock,
          builder: (context, now, _) {
            final elapsed = workout.startTime == Int64.ZERO
                ? 0
                : (isEnded
                          ? workout.endTime.toInt()
                          : now.millisecondsSinceEpoch ~/ 1000) -
                      workout.startTime.toInt();
            final heart = wp.wearHeartRateSamples.isNotEmpty
                ? wp.wearHeartRateSamples.last
                : null;
            return SessionStrip(
              title: sessionTitle,
              progress: overallProgress,
              elapsedText: formatElapsedClock(max(0, elapsed)),
              heartRateText: !isEnded && heart != null && heart.bpm > 0
                  ? '${heart.bpm.round()}'
                  : null,
            );
          },
        ),
        const SizedBox(height: 8),
        // ── The views, by name ──
        TutorialTarget(
          id: 'workout_tabs',
          child: PageTabs(
            tabs: pageTabs,
            index: _page,
            onTap: (i) => setState(() => _page = i),
          ),
        ),
        Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.8)),

        // ── The view on show (the others keep their scroll position) ──
        Expanded(
          child: IndexedStack(
            index: _page,
            children: [
              // ════ PAGE 1 — the workout: every exercise, full width ════
              ListView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  // Done exercises stay pinned at the top; the rest drag
                  // into any order by their grip.
                  for (final block in completedBlocks) ...[
                    ExerciseSection(
                      key: ValueKey('section-${block.stableId}'),
                      block: block,
                      workout: sectionWorkout,
                      focused: false,
                      finished: true,
                      onEdit: isEnded
                          ? null
                          : () => _editBlock(context, wp, block),
                    ),
                    divider,
                  ],
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: unfinishedBlocks.length,
                    // onReorderItem hands back a newIndex already adjusted
                    // for the removed item, so no manual `newIndex -= 1`.
                    onReorderItem: (oldIndex, newIndex) {
                      if (isEnded || unfinishedBlocks.length < 2) return;
                      HapticFeedback.mediumImpact();
                      final items = List<ExerciseBlock>.from(unfinishedBlocks);
                      items.insert(newIndex, items.removeAt(oldIndex));
                      wp.reorderExercises([
                        ...completedBlocks.map((b) => b.exercise),
                        ...items.map((b) => b.exercise),
                      ]);
                    },
                    proxyDecorator: (child, index, animation) =>
                        AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) => Material(
                            elevation: lerpDouble(
                              0,
                              6,
                              Curves.easeInOut.transform(animation.value),
                            )!,
                            color: context.tokens.background,
                            child: child,
                          ),
                          child: child,
                        ),
                    itemBuilder: (context, idx) {
                      final block = unfinishedBlocks[idx];
                      return Column(
                        key: ValueKey('reorder-${block.stableId}'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ExerciseSection(
                            key: focusedBlock?.stableId == block.stableId
                                ? _focusKey
                                : null,
                            block: block,
                            workout: sectionWorkout,
                            focused: focusedBlock?.stableId == block.stableId,
                            finished: false,
                            dragIndex: isEnded || unfinishedBlocks.length < 2
                                ? null
                                : idx,
                            onEdit: isEnded
                                ? null
                                : () => _editBlock(context, wp, block),
                          ),
                          divider,
                        ],
                      );
                    },
                  ),
                  if (!isEnded) ...[
                    AddExerciseRow(onTap: () => _showAddExercise(context, wp)),
                    divider,
                  ],

                  // End workout: a rare, one-way action, so a quiet link
                  // rather than a full-width button.
                  if (!isEnded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
                          child: Text(
                            copy.workout.endWorkout,
                            style: TextStyle(
                              fontWeight: context.tokens.weight.bold,
                              fontSize: context.tokens.size.body,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // ════ PAGE 2 — completed sets ════
              SetLog(
                proposedSets: logProposedSets,
                completedSets: logCompletedSets,
                onDelete: isEnded ? null : (id) => wp.deleteCompletedSet(id),
                deletableWorkoutId: wp.workout?.id,
                workoutOwnerLabels: workoutOwnerLabels,
                workoutOwnerEmojis: workoutOwnerEmojis,
                stickyHeader: true,
              ),
              // ════ PAGE 3 — heart rate (full detail) ════
              if (hasHeartRate)
                ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    HeartRateChart(
                      heartRateSamples: wp.wearHeartRateSamples,
                      completedSets: wp.completedSets,
                      workoutStartTime: workout.startTime,
                      now: wp.now,
                      stateSnapshot: wp.stateSnapshot,
                      fullView: true,
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

  static bool _isBlockCompleted(
    ExerciseBlock block,
    List<CompletedSet> completedSets,
  ) {
    final workingSets = block.workingSets.toList();
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

  static ExerciseBlock? _focusedBlock(
    WorkoutProvider wp,
    List<ExerciseBlock> blocks,
  ) {
    final focusedSet = wp.stateSnapshot?.hasDisplaySet() == true
        ? wp.stateSnapshot!.displaySet
        : wp.nextPendingSet;
    if (focusedSet == null) return null;
    // The would-be set a rung is waiting on is not in the plan yet; its
    // exercise's block is still the one in focus.
    return blocks.cast<ExerciseBlock?>().firstWhere(
          (block) => block!.sets.any((set) => set.id == focusedSet.id),
          orElse: () => null,
        ) ??
        blocks.cast<ExerciseBlock?>().firstWhere(
          (block) => block!.exercise == focusedSet.exercise,
          orElse: () => null,
        );
  }

  Future<void> _confirmRemoveExercise(
    BuildContext context,
    WorkoutProvider wp,
    ExerciseBlock block,
  ) async {
    final confirmed = await showDeleteExerciseDialog(
      context,
      exerciseNames[block.exercise] ?? '?',
    );
    if (confirmed != true || !context.mounted) return;
    unawaited(wp.removeExercise(block.exercise));
  }

  void _showAddExercise(BuildContext context, WorkoutProvider wp) {
    // Pick movements only — the app prescribes weight, sets, reps, rest
    // and warmups from each exercise's tracker, same as a template start.
    // Nothing lands until SAVE; adjusting numbers is a separate flow.
    showExercisePicker(
      context: context,
      trackers: wp.trackers,
      initialSelected: const {},
      // An exercise already in the workout can't be added again.
      excluded: {for (final b in wp.exerciseBlocks) b.exercise},
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

  void _editBlock(
    BuildContext context,
    WorkoutProvider wp,
    ExerciseBlock block,
  ) {
    showWeightAdjustSheet(
      context,
      block: block,
      provider: wp,
      onDelete: () => _confirmRemoveExercise(context, wp, block),
    );
  }
}
