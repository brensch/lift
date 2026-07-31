/// Read-only view of a session participant's workout, opened from the multiplayer bar.
library;

import 'dart:async';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import '../../gen/workout/v1/group.pb.dart';
import '../../gen/workout/v1/workout.pb.dart';
import '../../logic/exercise_groups.dart';
import '../../theme/app_theme.dart';
import '../exercise_group_widget.dart';

Future<void> showParticipantWorkoutModal(
  BuildContext context,
  ParticipantStatus participant,
) async {
  final groups = _buildParticipantExerciseGroups(participant);
  final activeSetId = _participantActiveSetId(participant);
  final workoutEnded = _isParticipantWorkoutEnded(participant);
  final displayName = participant.user.name.isNotEmpty
      ? participant.user.name
      : participant.user.id;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final colorScheme = Theme.of(ctx).colorScheme;

      return Container(
        decoration: BoxDecoration(
          color: AppTheme.sheetColor(ctx),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLg),
          ),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 8,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: AppTheme.sheetHandle(ctx)),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "$displayName's Workout",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No workout data available.',
                    style: TextStyle(fontSize: 14, color: colorScheme.tertiary),
                  ),
                )
              else
                Column(
                  children: [
                    for (var i = 0; i < groups.length; i++) ...[
                      ExerciseGroupWidget(
                        group: groups[i],
                        completedSets: participant.completedSets,
                        activeSetId: activeSetId,
                        isWorkoutEnded: workoutEnded,
                      ),
                      if (i < groups.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    },
  );
}

List<ExerciseGroupData> _buildParticipantExerciseGroups(
  ParticipantStatus participant,
) {
  final proposedSets = participant.proposedSets.toList()
    ..sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
  if (proposedSets.isEmpty) return [];

  if (participant.exerciseGroups.isEmpty) {
    return groupSetsByExercise(proposedSets);
  }

  final groups = participant.exerciseGroups.toList()
    ..sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
  final usedSetIds = <String>{};
  final result = <ExerciseGroupData>[];

  for (final group in groups) {
    final groupSets = proposedSets
        .where((s) => s.exerciseGroupId == group.id)
        .toList();
    if (groupSets.isEmpty) continue;
    groupSets.sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
    usedSetIds.addAll(groupSets.map((set) => set.id));
    final exercise = group.exerciseConfigs.isNotEmpty
        ? Exercise.valueOf(group.exerciseConfigs.first.exercise.value) ??
              Exercise.EXERCISE_UNSPECIFIED
        : groupSets.isNotEmpty
        ? groupSets.first.exercise
        : Exercise.EXERCISE_UNSPECIFIED;
    final exercises = <Exercise>[];
    for (final config in group.exerciseConfigs) {
      final ex = Exercise.valueOf(config.exercise.value);
      if (ex != null && !exercises.contains(ex)) exercises.add(ex);
    }
    result.add(
      ExerciseGroupData(
        exercise: exercise,
        sets: groupSets,
        group: group,
        exercises: exercises,
      ),
    );
  }

  final leftover = proposedSets
      .where((set) => !usedSetIds.contains(set.id))
      .toList();
  if (leftover.isNotEmpty) {
    result.addAll(groupSetsByExercise(leftover));
  }

  return result;
}

String? _participantActiveSetId(ParticipantStatus participant) {
  for (final completed in participant.completedSets) {
    if (completed.endedAt == Int64.ZERO) {
      return completed.proposedSetId;
    }
  }
  return null;
}

bool _isParticipantWorkoutEnded(ParticipantStatus participant) {
  if (!participant.hasActiveWorkout()) return true;
  return participant.activeWorkout.endTime != Int64.ZERO;
}
