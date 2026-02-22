import 'dart:ui';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercise_groups.dart';
import '../logic/exercises.dart';
import '../providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/multiplayer_provider.dart';
import '../widgets/exercise_group_widget.dart';
import '../widgets/participant_ticker.dart';
import '../widgets/set_log.dart';
import '../widgets/workout_modals.dart';

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

    final nextUpUserId = mp.sessionStatus?.nextUpUserId ?? '';
    final otherParticipants = mp.participants
        .where((p) => p.user.id != auth.userId)
        .toList();
    final sessionLedgerProposed = <ProposedSet>[];
    final sessionLedgerCompleted = <CompletedSet>[];
    final workoutOwnerLabels = <String, String>{};
    if (mp.isInSession && mp.sessionStatus != null) {
      for (final participant in mp.participants) {
        sessionLedgerProposed.addAll(participant.proposedSets);
        sessionLedgerCompleted.addAll(participant.completedSets);
        if (participant.activeWorkoutId.isNotEmpty) {
          final rawName = participant.user.id == auth.userId
              ? 'You'
              : (participant.user.name.isNotEmpty
                    ? participant.user.name
                    : participant.user.id);
          workoutOwnerLabels[participant.activeWorkoutId] = rawName;
        }
      }
    }
    final logProposedSets = sessionLedgerProposed.isNotEmpty
        ? sessionLedgerProposed
        : wp.proposedSets;
    final logCompletedSets = sessionLedgerCompleted.isNotEmpty
        ? sessionLedgerCompleted
        : wp.completedSets;

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
                isEnded ? 'WORKOUT COMPLETED' : 'WORKOUT IN PROGRESS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: colorScheme.tertiary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                workout.name.toUpperCase(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
            ],
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
                  'EXERCISES IN WORKOUT',

                  style: TextStyle(
                    fontSize: 11,

                    fontWeight: FontWeight.bold,

                    letterSpacing: 1.5,

                    color: colorScheme.tertiary,
                  ),
                ),
              ),

              if (groups.isNotEmpty)
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: groups.length,
                  onReorder: (oldIndex, newIndex) {
                    if (isEnded) return;

                    final completedFlags = groups
                        .map((g) => _isGroupCompleted(g, wp.completedSets))
                        .toList();

                    // Don't allow dragging completed groups
                    if (completedFlags[oldIndex]) return;

                    // Can't jump over any completed group in either direction.
                    // newIndex here is the pre-adjustment Flutter value.
                    if (oldIndex > newIndex) {
                      // Moving up: check range [newIndex, oldIndex-1]
                      for (int i = newIndex; i < oldIndex; i++) {
                        if (completedFlags[i]) return;
                      }
                    } else {
                      // Moving down: check range [oldIndex+1, newIndex-1]
                      for (int i = oldIndex + 1; i < newIndex; i++) {
                        if (completedFlags[i]) return;
                      }
                    }

                    if (oldIndex < newIndex) newIndex -= 1;

                    HapticFeedback.mediumImpact();

                    final items = List<ExerciseGroupData>.from(wp.exerciseGroups);
                    final item = items.removeAt(oldIndex);
                    items.insert(newIndex, item);

                    final groupIds = items.map((g) => g.group!.id).toList();
                    wp.reorderExerciseGroups(groupIds);
                  },
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        final animValue = Curves.easeInOut.transform(animation.value);
                        final elevation = lerpDouble(0, 4, animValue)!;
                        return Material(
                          elevation: elevation,
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: child,
                        );
                      },
                      child: child,
                    );
                  },
                  itemBuilder: (context, idx) {
                    final group = groups[idx];
                    final isCompleted = _isGroupCompleted(group, wp.completedSets);
                    final stableKey = group.sets.isNotEmpty
                        ? group.sets.first.id
                        : 'empty-$idx';

                    return Dismissible(
                      key: ValueKey(stableKey),
                      direction: isEnded
                          ? DismissDirection.none
                          : DismissDirection.endToStart,
                      confirmDismiss: (_) => showDeleteGroupDialog(
                        context,
                        exerciseNames[group.exercise] ?? '?',
                      ),
                      onDismissed: (_) => _deleteGroup(context, wp, idx),
                      background: Container(
                        alignment: Alignment.centerRight,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: colorScheme.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.delete_outline, color: colorScheme.onError, size: 20),
                      ),
                      child: ExerciseGroupWidget(
                        group: group,
                        completedSets: wp.completedSets,
                        activeSetId: activeSetId,
                        isWorkoutEnded: isEnded,
                        onEdit: () => _editGroup(context, wp, idx, group),
                        groupIndex: isCompleted ? null : idx,
                      ),
                    );
                  },
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

                    child: ParticipantCard(participant: p, isNextUp: isNextUp),
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

  void _deleteGroup(BuildContext context, WorkoutProvider wp, int index) {
    wp.deleteExerciseGroup(index);
  }

  void _editGroup(
    BuildContext context,
    WorkoutProvider wp,
    int index,
    ExerciseGroupData group,
  ) {
    showEditExerciseDialog(
      context,
      group: group,
      groupIndex: index,
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
}
