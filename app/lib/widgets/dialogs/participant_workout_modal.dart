/// A session partner's workout, opened from their box in the banner: the
/// same full-width exercise sections and circles as your own, to look at.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gen/workout/v1/group.pb.dart';
import '../../logic/exercise_blocks.dart';
import '../../providers/multiplayer_provider.dart';
import '../../providers/workout_provider.dart';
import '../../screens/workout/exercise_section.dart';
import '../../screens/workout/section_workout.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_spec.dart';
import '../common/flat.dart';
import '../participant_ticker.dart';

Future<void> showParticipantWorkoutModal(
  BuildContext context,
  ParticipantStatus participant,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) => _ParticipantWorkoutSheet(participant: participant),
  );
}

/// Live: it follows the session as it updates (their sets, their stage),
/// ticking each second so rest turning into yapping shows on time.
class _ParticipantWorkoutSheet extends StatelessWidget {
  final ParticipantStatus participant;

  const _ParticipantWorkoutSheet({required this.participant});

  @override
  Widget build(BuildContext context) {
    final mp = context.watch<MultiplayerProvider>();
    final userId = participant.user.id;
    final latest = mp.participants.firstWhere(
      (p) => p.user.id == userId,
      orElse: () => participant,
    );
    return ValueListenableBuilder<DateTime>(
      valueListenable: context.read<WorkoutProvider>().clock,
      builder: (context, _, __) => _sheet(context, latest),
    );
  }

  Widget _sheet(BuildContext context, ParticipantStatus p) {
    final t = context.tokens;
    final workout = SectionWorkout.of(p);
    final blocks = blocksFromSets(
      p.proposedSets.toList()
        ..sort((a, b) => a.workoutOrder.compareTo(b.workoutOrder)),
    );
    final status = describeParticipantStatus(p, tokens: t);
    final nextExercise = workout.nextSetId == null
        ? null
        : p.proposedSets
              .where((s) => s.id == workout.nextSetId)
              .map((s) => s.exercise)
              .firstOrNull;

    bool finished(ExerciseBlock block) {
      final working = block.sets.where((s) => !s.cancelled && !s.warmup);
      return working.isNotEmpty && working.every((s) => workout.isDone(s.id));
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTheme.sheetHandle(context, gap: 0),
            // Who: their emoji on their colour, their name, where they are.
            Container(
              height: 64,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.hairline)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 64,
                    alignment: Alignment.center,
                    color: participantProfileColor(p),
                    child: Text(
                      participantProfileEmoji(p),
                      style: TextStyle(fontSize: t.size.headline, height: 1),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PageTitle(participantDisplayName(p)),
                        Text(
                          status.stateLabel.toUpperCase(),
                          style: t.mono(
                            TextStyle(
                              fontSize: t.size.small,
                              fontWeight: t.weight.bold,
                              letterSpacing: 1,
                              color: status.stateColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(AppIcons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: blocks.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No workout yet.',
                        style: TextStyle(fontSize: t.size.body, color: t.muted),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [
                        for (final block in blocks)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: t.hairline),
                              ),
                            ),
                            child: ExerciseSection(
                              block: block,
                              workout: workout,
                              focused: block.exercise == nextExercise,
                              finished: finished(block),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
