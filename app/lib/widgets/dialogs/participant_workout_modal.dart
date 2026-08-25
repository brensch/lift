/// Read-only view of a session participant's workout, opened from the multiplayer bar.
library;

import 'dart:async';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import '../../gen/workout/v1/group.pb.dart';
import '../../logic/exercise_blocks.dart';
import '../../theme/app_theme.dart';
import '../exercise_block_widget.dart';

Future<void> showParticipantWorkoutModal(
  BuildContext context,
  ParticipantStatus participant,
) async {
  final blocks = _participantBlocks(participant);
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

              if (blocks.isEmpty)
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
                    for (var i = 0; i < blocks.length; i++) ...[
                      ExerciseBlockWidget(
                        block: blocks[i],
                        completedSets: participant.completedSets,
                        activeSetId: activeSetId,
                        isWorkoutEnded: workoutEnded,
                      ),
                      if (i < blocks.length - 1) const SizedBox(height: 8),
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

List<ExerciseBlock> _participantBlocks(ParticipantStatus participant) {
  final proposedSets = participant.proposedSets.toList()
    ..sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder));
  return blocksFromSets(proposedSets);
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
