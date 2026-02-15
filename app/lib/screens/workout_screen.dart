import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercise_groups.dart';
import '../logic/exercises.dart';
import '../logic/group_next_up.dart';
import '../logic/warmup.dart';
import '../providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/multiplayer_provider.dart';
import '../widgets/exercise_group_widget.dart';
import '../widgets/participant_ticker.dart';
import '../widgets/set_log.dart';
import '../widgets/workout_modals.dart';

const _uuid = Uuid();

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkoutProvider>();
    final mp = context.watch<MultiplayerProvider>();
    final auth = context.read<AuthProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    if (wp.workout == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final groups = wp.exerciseGroups;
    final activeSetId = wp.activeSetId;
    final isEnded = wp.isWorkoutEnded;

    // Group next up for highlighting
    final nowUnix = wp.now.millisecondsSinceEpoch ~/ 1000;
    final groupNextUp = computeGroupNextUp(mp.sessionStatus, auth.userId, nowUnix);
    final otherParticipants = mp.participants
        .where((p) => p.user.id != auth.userId)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Participant cards (multiplayer)
        if (mp.isInSession && otherParticipants.isNotEmpty) ...[
          ...otherParticipants.map((p) {
            final isNextUp = groupNextUp?.participant.user.id == p.user.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ParticipantCard(
                participant: p,
                isNextUp: isNextUp,
              ),
            );
          }),
          const SizedBox(height: 8),
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
              onDismissed: (_) => _deleteGroup(context, wp, idx),
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

        if (!isEnded) ...[
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => _showAddExercise(context, wp),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Add Exercise',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        SetLog(
          proposedSets: wp.proposedSets,
          completedSets: wp.completedSets,
          onDelete: isEnded ? null : (id) => wp.deleteCompletedSet(id),
        ),

        if (!isEnded) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () => _endWorkout(context, wp),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
              ),
              child: const Text(
                'End Workout',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ],
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

  void _deleteGroup(BuildContext context, WorkoutProvider wp, int index) {
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
      final workoutId = wp.workout!.id;
      await wp.endWorkout();
      if (context.mounted) {
        context.go('/workout/$workoutId/completed');
      }
    }
  }
}
