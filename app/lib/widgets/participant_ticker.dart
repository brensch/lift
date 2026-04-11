import 'package:flutter/material.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/group.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../theme/app_theme.dart';
import '../widgets/workout_status_box.dart';

String _fmt(int seconds) {
  final m = seconds.abs() ~/ 60;
  final s = seconds.abs() % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String participantDisplayName(ParticipantStatus participant) {
  final name = participant.user.name.trim();
  if (name.isNotEmpty) return name;
  final id = participant.user.id.trim();
  if (id.isNotEmpty) return id;
  return 'Unknown';
}

ParticipantVisualStatus describeParticipantStatus(
  ParticipantStatus participant, {
  DateTime? now,
}) {
  final nowUnix = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
  final nextSet = participant.hasNextUpSet() ? participant.nextUpSet : null;
  final restUntil = participant.restUntil.toInt();

  if (participant.hasActiveWorkout() &&
      participant.activeWorkout.endTime != Int64.ZERO) {
    return ParticipantVisualStatus(
      stateLabel: 'Finished',
      stateColor: AppTheme.successFg,
      sortPriority: 0,
      isComplete: true,
    );
  }

  final activeSet = participant.completedSets.cast<CompletedSet?>().firstWhere(
    (c) => c!.endedAt == Int64.ZERO,
    orElse: () => null,
  );
  if (participant.hasActiveSet || activeSet != null) {
    final proposed = participant.proposedSets.cast<ProposedSet?>().firstWhere(
      (ps) => ps!.id == activeSet?.proposedSetId,
      orElse: () => null,
    );
    final elapsed =
        activeSet != null ? nowUnix - activeSet.startedAt.toInt() : 0;
    return ParticipantVisualStatus(
      stateLabel: proposed?.warmup == true ? 'Warmup' : 'Lifting',
      stateColor: AppTheme.activeFg,
      proposedSet: proposed,
      timerText: _fmt(elapsed),
      sortPriority: 4,
    );
  }

  if (restUntil > nowUnix && nextSet != null) {
    final remaining = restUntil - nowUnix;
    return ParticipantVisualStatus(
      stateLabel: 'Resting',
      stateColor: const Color(0xFF3B82F6),
      proposedSet: nextSet,
      timerText: _fmt(remaining),
      sortPriority: 2,
    );
  }

  if (restUntil > 0 && restUntil <= nowUnix && nextSet != null) {
    final elapsed = nowUnix - restUntil;
    return ParticipantVisualStatus(
      stateLabel: 'Yapping',
      stateColor: AppTheme.destructive,
      proposedSet: nextSet,
      timerText: '+${_fmt(elapsed)}',
      timerColor: AppTheme.destructive,
      sortPriority: 3,
    );
  }

  if (nextSet != null) {
    return ParticipantVisualStatus(
      stateLabel: 'Next up',
      stateColor: AppTheme.warmupFg,
      proposedSet: nextSet,
      sortPriority: 1,
    );
  }

  return ParticipantVisualStatus(
    stateLabel: 'Done',
    stateColor: AppTheme.successFg,
    sortPriority: 0,
    isComplete: true,
  );
}

/// Card showing a participant's current workout state.
/// Shows: name, state label, exercise/weight info, timer.
class ParticipantCard extends StatelessWidget {
  final ParticipantStatus participant;
  final bool isNextUp;
  final VoidCallback? onTap;

  const ParticipantCard({
    super.key,
    required this.participant,
    this.isNextUp = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = describeParticipantStatus(participant);
    final displayName = participantDisplayName(participant);
    final box = StatusBox(
      sideLabel: displayName,
      header: displayName,
      stateLabel: status.stateLabel,
      color: status.stateColor,
      timerText: status.timerText,
      timerColor: status.timerColor,
      set: status.proposedSet,
      isComplete: status.isComplete,
      showHeader: false,
    );

    if (onTap == null) return box;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: box,
      ),
    );
  }
}

class ParticipantVisualStatus {
  final String stateLabel;
  final Color stateColor;
  final ProposedSet? proposedSet;
  final String? timerText;
  final Color? timerColor;
  final int sortPriority;
  final bool isComplete;

  const ParticipantVisualStatus({
    required this.stateLabel,
    required this.stateColor,
    this.proposedSet,
    this.timerText,
    this.timerColor,
    required this.sortPriority,
    this.isComplete = false,
  });
}
