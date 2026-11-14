import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../gen/copy.dart';
import '../../logic/exercise_blocks.dart';
import '../../logic/exercises.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/common/quiet_link.dart';
import '../../widgets/dialogs/discard_workout_dialog.dart';
import '../../widgets/dialogs/end_workout_dialog.dart';
import '../../widgets/dialogs/weight_adjust_sheet.dart';
import '../../widgets/exercise_picker.dart';
import '../../widgets/workout_bar/workout_focus.dart';
import 'exercise_section.dart';
import 'section_workout.dart';
import 'workout_note.dart';
import 'workout_panels.dart';
import '../../theme/theme_spec.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  /// The exercise in hand, so a tap on the banner can bring it into view.
  final _focusKey = GlobalKey();

  /// The last request answered: a tap made from another page lands before
  /// this screen is built, so it catches up on its first frame.
  static int _answered = 0;

  /// The exercise in hand at the last build: when it changes (the last
  /// exercise is finished), the next one scrolls up to the top.
  String? _focusedId;

  /// The exercises still to finish at the last build: one that has left
  /// this for the finished ones was finished just now, and folds away
  /// before your eyes instead of turning up folded.
  Set<String> _unfinishedIds = const {};

  void _scrollFocusToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _focusKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

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

    if (wp.workout == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final blocks = wp.exerciseBlocks;
    final isEnded = wp.isWorkoutEnded;
    final focusedBlock = _focusedBlock(wp, blocks);
    final focusedId = focusedBlock?.stableId;
    if (focusedId != _focusedId) {
      // Not on the first build: only moving on to the next exercise scrolls.
      if (_focusedId != null && focusedId != null) {
        _scrollFocusToTop();
      }
      _focusedId = focusedId;
    }
    // Completed blocks stay pinned (green) at the top of the list; only the
    // unfinished ones below them can be dragged/reordered.
    final completedBlocks = blocks
        .where((block) => _isBlockCompleted(block, wp))
        .toList(growable: false);
    final unfinishedBlocks = blocks
        .where((block) => !_isBlockCompleted(block, wp))
        .toList(growable: false);
    final justFinished = {
      for (final block in completedBlocks)
        if (_unfinishedIds.contains(block.stableId)) block.stableId,
    };
    _unfinishedIds = {for (final block in unfinishedBlocks) block.stableId};
    // Overall progress for the first row's hairline: every set still in the
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
      if (calibrating) totalSets += wp.logFor(g.exercise)?.decision.sets ?? 0;
      // A warmup skipped or passed by is behind you: it counts as done, so
      // the bar reaches the end when the workout does.
      doneSets += sets
          .where((s) => wp.isSetDone(s.id) || wp.isPassedWarmup(s))
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

    final sectionWorkout = SectionWorkout.mine(wp);
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: context.tokens.hairline,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── The first row: the workout's name, multiplayer and the menu;
        // progress as a hairline under it.
        WorkoutRow(title: sessionTitle),
        LinearProgressIndicator(
          value: overallProgress.clamp(0.0, 1.0),
          minHeight: 2,
          backgroundColor: context.tokens.hairline,
          valueColor: AlwaysStoppedAnimation(context.tokens.primary),
        ),

        // ── The workout: every exercise, full width ──
        Expanded(
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              // With nothing in hand (every set done) the line has no
              // exercise to sit with: it heads the list.
              if (focusedBlock == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: WorkoutNote(),
                ),
              // Done exercises stay pinned at the top; the rest drag
              // into any order by their grip.
              for (final block in completedBlocks) ...[
                ExerciseSection(
                  key: ValueKey('section-${block.stableId}'),
                  block: block,
                  workout: sectionWorkout,
                  focused: false,
                  finished: true,
                  justFinished: justFinished.contains(block.stableId),
                  onEdit: isEnded
                      ? null
                      : () => editExercise(context, wp, block),
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
                proxyDecorator: (child, index, animation) => AnimatedBuilder(
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
                        note: focusedBlock?.stableId == block.stableId
                            ? const WorkoutNote()
                            : null,
                        dragIndex: isEnded || unfinishedBlocks.length < 2
                            ? null
                            : idx,
                        onEdit: isEnded
                            ? null
                            : () => editExercise(context, wp, block),
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

              // End or throw away: rare, one-way actions, so quiet links
              // rather than full-width buttons.
              if (!isEnded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Column(
                    children: [
                      QuietLink(
                        label: copy.workout.endWorkout,
                        onPressed: () => endWorkout(context),
                      ),
                      QuietLink(
                        label: copy.workout.discardWorkout,
                        onPressed: () => _discard(context, wp),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static bool _isBlockCompleted(ExerciseBlock block, WorkoutProvider wp) {
    final workingSets = block.workingSets;
    return workingSets.isNotEmpty &&
        workingSets.every((s) => wp.isSetDone(s.id));
  }

  static ExerciseBlock? _focusedBlock(
    WorkoutProvider wp,
    List<ExerciseBlock> blocks,
  ) {
    final focusedSet = wp.doneTargetSet;
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

  /// Throw the workout away, once the person confirms: home is on screen.
  Future<void> _discard(BuildContext context, WorkoutProvider wp) async {
    if (!await confirmDiscardWorkout(context)) return;
    await wp.discardWorkout();
  }

  void _showAddExercise(BuildContext context, WorkoutProvider wp) {
    // Pick movements only — the core plans weight, sets, reps, rest and
    // warmups for each one in the workout's budget, same as a start.
    // Nothing lands until SAVE; adjusting numbers is a separate flow.
    showExercisePicker(
      context: context,
      plans: wp.plans,
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
}
