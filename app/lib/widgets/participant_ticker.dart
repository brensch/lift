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
    final status = _getStatus(participant);
    final box = StatusBox(
      sideLabel: participant.user.name,
      header: participant.user.name,
      stateLabel: status.stateLabel,
      color: status.stateColor,
      timerText: status.timerText,
      timerColor: status.timerColor,
      set: status.proposedSet,
      isComplete:
          status.stateLabel == 'Done' || status.stateLabel == 'Finished',
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

  _ParticipantStatusInfo _getStatus(ParticipantStatus p) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final nextSet = p.hasNextUpSet() ? p.nextUpSet : null;
    final restUntil = p.restUntil.toInt();

    // Check if workout is ended
    if (p.hasActiveWorkout() && p.activeWorkout.endTime != Int64.ZERO) {
      return _ParticipantStatusInfo(
        stateLabel: 'Finished',
        stateColor: AppTheme.successFg,
      );
    }

    // Check if actively lifting
    final activeSet = p.completedSets.cast<CompletedSet?>().firstWhere(
      (c) => c!.endedAt == Int64.ZERO,
      orElse: () => null,
    );
    if (p.hasActiveSet || activeSet != null) {
      final proposed = p.proposedSets.cast<ProposedSet?>().firstWhere(
        (ps) => ps!.id == activeSet?.proposedSetId,
        orElse: () => null,
      );
      final elapsed = activeSet != null ? now - activeSet.startedAt.toInt() : 0;
      return _ParticipantStatusInfo(
        stateLabel: proposed?.warmup == true ? 'Warmup' : 'Lifting',
        stateColor: AppTheme.activeFg,
        proposedSet: proposed,
        timerText: _fmt(elapsed),
        timerColor: null,
      );
    }

    // Check if resting
    if (restUntil > now && nextSet != null) {
      final remaining = restUntil - now;
      return _ParticipantStatusInfo(
        stateLabel: 'Resting',
        stateColor: const Color(0xFF3B82F6),
        proposedSet: nextSet,
        timerText: _fmt(remaining),
        timerColor: null,
      );
    }

    // Check for yapping (rest ended, next set pending)
    if (restUntil > 0 && restUntil <= now && nextSet != null) {
      final elapsed = now - restUntil;
      return _ParticipantStatusInfo(
        stateLabel: 'Yapping',
        stateColor: AppTheme.destructive,
        proposedSet: nextSet,
        timerText: '+${_fmt(elapsed)}',
        timerColor: AppTheme.destructive,
      );
    }

    // Idle / next up
    if (nextSet != null) {
      return _ParticipantStatusInfo(
        stateLabel: 'Next up',
        stateColor: AppTheme.warmupFg,
        proposedSet: nextSet,
      );
    }

    // All done
    return _ParticipantStatusInfo(
      stateLabel: 'Done',
      stateColor: AppTheme.successFg,
    );
  }
}

class _ParticipantStatusInfo {
  final String stateLabel;
  final Color stateColor;
  final ProposedSet? proposedSet;
  final String? timerText;
  final Color? timerColor;

  _ParticipantStatusInfo({
    required this.stateLabel,
    required this.stateColor,
    this.proposedSet,
    this.timerText,
    this.timerColor,
  });
}
