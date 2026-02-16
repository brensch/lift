import 'package:flutter/material.dart';
import 'package:fixnum/fixnum.dart';
import 'package:provider/provider.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercise_groups.dart';
import '../logic/exercises.dart';
import '../logic/group_next_up.dart';
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

    // Group next up for highlighting
    final nowUnix = wp.now.millisecondsSinceEpoch ~/ 1000;
    final groupNextUp = computeGroupNextUp(
      mp.sessionStatus,
      auth.userId,
      nowUnix,
    );
    final otherParticipants = mp.participants
        .where((p) => p.user.id != auth.userId)
        .toList();

    final workout = wp.workout!;
    final startTime = DateTime.fromMillisecondsSinceEpoch(
      workout.startTime.toInt() * 1000,
    );
    final endTime = workout.endTime != Int64.ZERO
        ? DateTime.fromMillisecondsSinceEpoch(workout.endTime.toInt() * 1000)
        : wp.now;
    final duration = endTime.difference(startTime);

    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            crossAxisAlignment: CrossAxisAlignment.end,

            children: [
              Expanded(
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

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,

                children: [
                  Text(
                    'TOTAL TIME',

                    style: TextStyle(
                      fontSize: 10,

                      fontWeight: FontWeight.bold,

                      letterSpacing: 1.0,

                      color: colorScheme.tertiary,
                    ),
                  ),

                  Text(
                    _formatDuration(duration),

                    style: const TextStyle(
                      fontSize: 20,

                      fontWeight: FontWeight.w900,

                      letterSpacing: -0.5,
                    ),
                  ),
                ],
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
                ReorderableListView(
                  shrinkWrap: true,

                  physics: const NeverScrollableScrollPhysics(),

                  onReorder: (oldIndex, newIndex) {
                    if (isEnded) return;

                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }

                    final items = List<ExerciseGroupData>.from(
                      wp.exerciseGroups,
                    );

                    final item = items.removeAt(oldIndex);

                    items.insert(newIndex, item);

                    final groupIds = items.map((g) => g.group!.id).toList();

                    wp.reorderExerciseGroups(groupIds);
                  },

                  children: groups.asMap().entries.map((entry) {
                    final idx = entry.key;

                    final group = entry.value;

                    final stableKey = group.sets.isNotEmpty
                        ? group.sets.first.id
                        : 'empty-$idx';

                    return Padding(
                      key: ValueKey(stableKey),

                      padding: const EdgeInsets.only(bottom: 12),

                      child: Dismissible(
                        key: ValueKey('dismiss-$stableKey'),

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

                          padding: const EdgeInsets.only(right: 16),

                          decoration: BoxDecoration(
                            color: colorScheme.error,

                            borderRadius: BorderRadius.circular(12),
                          ),

                          child: Icon(Icons.delete, color: colorScheme.onError),
                        ),

                        child: ExerciseGroupWidget(
                          group: group,

                          completedSets: wp.completedSets,

                          activeSetId: activeSetId,

                          isWorkoutEnded: isEnded,

                          onEdit: () => _editGroup(context, wp, idx, group),
                        ),
                      ),
                    );
                  }).toList(),
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
                      groupNextUp?.participant.user.id == p.user.id;

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
            proposedSets: wp.proposedSets,

            completedSets: wp.completedSets,

            onDelete: isEnded ? null : (id) => wp.deleteCompletedSet(id),
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
      onSave: (
        groupIndex, {
        required int sets,
        required bool interleaveWarmups,
        required List<ExerciseTypeConfig> exerciseConfigs,
      }) {
        wp.updateGroup(
          groupIndex,
          sets: sets,
          interleaveWarmups: interleaveWarmups,
          exerciseConfigs: exerciseConfigs,
        );
      },
    );
  }

  void _showAddExercise(BuildContext context, WorkoutProvider wp) {
    showAddExerciseDialog(
      context,
      exerciseStatuses: wp.exerciseStatuses,
      onAdd: (name, sets, interleaveWarmups, exerciseConfigs) {
        final finalName = name.isNotEmpty
            ? name
            : exerciseConfigs
                .map((c) => exerciseNames[Exercise.valueOf(c.exercise.value)] ?? '?')
                .join(' / ');

        wp.addExerciseGroup(
          name: finalName,
          sets: sets,
          interleaveWarmups: interleaveWarmups,
          exerciseConfigs: exerciseConfigs,
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}
