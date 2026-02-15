import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fixnum/fixnum.dart';
import 'package:uuid/uuid.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercise_groups.dart';
import '../logic/exercises.dart';
import '../logic/warmup.dart';
import '../providers/workout_provider.dart';
import '../providers/sound_provider.dart';
import '../widgets/exercise_group_widget.dart';
import '../widgets/active_boxes.dart';
import '../widgets/set_log.dart';
import '../widgets/workout_modals.dart';

const _uuid = Uuid();

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  bool _soundPlayed = false;
  int _prevRestSeconds = 0;

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    final soundProvider = context.read<SoundProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    if (wp.workout == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final restSeconds = wp.restSecondsRemaining;
    if (_prevRestSeconds > 0 && restSeconds == 0 && !_soundPlayed) {
      _soundPlayed = true;
      soundProvider.playCurrentSound();
    }
    if (restSeconds > 0) {
      _soundPlayed = false;
    }
    _prevRestSeconds = restSeconds;

    final groups = wp.exerciseGroups;
    final activeSetId = wp.activeSetId;
    final nextSet = wp.nextPendingSet;
    final isEnded = wp.isWorkoutEnded;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'WORKOUT',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        actions: [
          if (!isEnded) ...[
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddExercise(context, wp),
            ),
            IconButton(
              icon: Icon(Icons.stop, color: colorScheme.error),
              onPressed: () => _endWorkout(context, wp),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!isEnded) ...[
            if (wp.restingSet != null)
              RestingBox(secondsRemaining: restSeconds),
            if (activeSetId != null)
              _buildActiveSetBox(wp, activeSetId),
            if (activeSetId == null && wp.restingSet == null && nextSet != null)
              NextUpBox(
                nextSet: nextSet,
                onStart: () => wp.startSet(nextSet.id),
              ),
            if (activeSetId == null && wp.restingSet == null && nextSet == null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: Column(
                  children: [
                    const Text(
                      'ALL SETS COMPLETE',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => _endWorkout(context, wp),
                      child: const Text('End Workout'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],

          ...groups.asMap().entries.map((entry) {
            final idx = entry.key;
            final group = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Dismissible(
                key: ValueKey('group-$idx-${group.exercise.value}'),
                direction: isEnded ? DismissDirection.none : DismissDirection.endToStart,
                confirmDismiss: (_) => showDeleteGroupDialog(
                  context,
                  exerciseNames[group.exercise] ?? '?',
                ),
                onDismissed: (_) => _deleteGroup(wp, idx),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.delete, color: colorScheme.onError),
                ),
                child: ExerciseGroupWidget(
                  group: group,
                  groupIndex: idx,
                  totalGroups: groups.length,
                  completedSets: wp.completedSets,
                  activeSetId: activeSetId,
                  isWorkoutEnded: isEnded,
                  onMoveUp: () => _moveGroup(wp, idx, -1),
                  onMoveDown: () => _moveGroup(wp, idx, 1),
                  onEdit: () => _editGroup(context, wp, idx, group),
                ),
              ),
            );
          }),

          SetLog(
            proposedSets: wp.proposedSets,
            completedSets: wp.completedSets,
            onDelete: isEnded ? null : (id) => wp.deleteCompletedSet(id),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSetBox(WorkoutProvider wp, String activeSetId) {
    final proposed = wp.proposedSets.cast<ProposedSet?>().firstWhere(
      (p) => p!.id == activeSetId,
      orElse: () => null,
    );
    if (proposed == null) return const SizedBox.shrink();

    final activeCompleted = wp.completedSets.cast<CompletedSet?>().firstWhere(
      (c) => c!.proposedSetId == activeSetId && c.endedAt == Int64.ZERO,
      orElse: () => null,
    );

    return ActiveSetBox(
      proposedSet: proposed,
      activeCompletedSet: activeCompleted,
      now: wp.now,
      onComplete: (reps, weight) => wp.completeSet(activeSetId, reps, weight),
    );
  }

  void _moveGroup(WorkoutProvider wp, int index, int direction) {
    final groups = List<ExerciseGroupData>.from(wp.exerciseGroups);
    final newIndex = index + direction;
    if (newIndex < 0 || newIndex >= groups.length) return;
    final item = groups.removeAt(index);
    groups.insert(newIndex, item);
    wp.saveGroups(groups);
  }

  void _deleteGroup(WorkoutProvider wp, int index) {
    final groups = List<ExerciseGroupData>.from(wp.exerciseGroups);
    if (index >= 0 && index < groups.length) {
      groups.removeAt(index);
      wp.saveGroups(groups);
    }
  }

  void _editGroup(BuildContext context, WorkoutProvider wp, int index, ExerciseGroupData group) {
    showEditExerciseDialog(
      context,
      group: group,
      groupIndex: index,
      onSave: (groupIndex, {required double targetWeight, bool? warmups, int? setCount}) {
        wp.rebuildGroup(groupIndex, targetWeight: targetWeight, warmups: warmups, setCount: setCount);
      },
    );
  }

  void _showAddExercise(BuildContext context, WorkoutProvider wp) {
    showAddExerciseDialog(
      context,
      onAdd: (exercise, weight, sets, reps) {
        final groups = List<ExerciseGroupData>.from(wp.exerciseGroups);
        final newSets = <ProposedSet>[];

        final warmupDefs = generateWarmupDefs(weight);
        for (final def in warmupDefs) {
          newSets.add(ProposedSet()
            ..id = _uuid.v4()
            ..exercise = exercise
            ..targetReps = def.reps
            ..targetWeight = def.weight
            ..warmup = true);
        }

        for (int i = 0; i < sets; i++) {
          newSets.add(ProposedSet()
            ..id = _uuid.v4()
            ..exercise = exercise
            ..targetReps = reps
            ..targetWeight = weight
            ..warmup = false);
        }

        groups.add(ExerciseGroupData(exercise: exercise, sets: newSets));
        wp.saveGroups(groups);
      },
    );
  }

  Future<void> _endWorkout(BuildContext context, WorkoutProvider wp) async {
    final confirmed = await showEndWorkoutConfirmDialog(context);
    if (confirmed) {
      await wp.endWorkout();
    }
  }
}
