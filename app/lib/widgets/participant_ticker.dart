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

  const ParticipantCard({
    super.key,
    required this.participant,
    this.isNextUp = false,
  });

  @override
  Widget build(BuildContext context) {
    final status = _getStatus(participant);

    return StatusBox(
      sideLabel: 'USER',
      header: participant.user.name,
      stateLabel: status.stateLabel,
      color: status.stateColor,
      timerText: status.timerText,
      timerColor: status.timerColor,
      set: status.proposedSet,
      isComplete: status.stateLabel == 'Done' || status.stateLabel == 'Finished',
    );
  }

  _ParticipantStatusInfo _getStatus(ParticipantStatus p) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

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
    if (activeSet != null) {
      final proposed = p.proposedSets.cast<ProposedSet?>().firstWhere(
        (ps) => ps!.id == activeSet.proposedSetId,
        orElse: () => null,
      );
      final elapsed = now - activeSet.startedAt.toInt();
      return _ParticipantStatusInfo(
        stateLabel: proposed?.warmup == true ? 'Warmup' : 'Lifting',
        stateColor: AppTheme.activeFg,
        proposedSet: proposed,
        timerText: _fmt(elapsed),
        timerColor: null,
      );
    }

    // Check if resting
    final restingSet = p.completedSets.cast<CompletedSet?>().firstWhere(
      (c) => c!.endedAt != Int64.ZERO && c.restUntil.toInt() > now,
      orElse: () => null,
    );
    if (restingSet != null) {
      final remaining = restingSet.restUntil.toInt() - now;
      // Find next pending set
      final nextSet = _findNextPending(p);
      return _ParticipantStatusInfo(
        stateLabel: 'Resting',
        stateColor: const Color(0xFF3B82F6),
        proposedSet: nextSet,
        timerText: _fmt(remaining),
        timerColor: null,
      );
    }

    // Check for yapping (rest ended, next set pending)
    final restingSets = p.completedSets
        .where((c) => c.endedAt != Int64.ZERO && c.restUntil != Int64.ZERO)
        .toList();
    restingSets.sort((a, b) => b.endedAt.compareTo(a.endedAt));
    final lastRestEnd = restingSets.isNotEmpty ? restingSets.first.restUntil.toInt() : 0;
    final nextSet = _findNextPending(p);

    if (lastRestEnd > 0 && lastRestEnd <= now && nextSet != null) {
      final elapsed = now - lastRestEnd;
      return _ParticipantStatusInfo(
        stateLabel: 'Yapping',
        stateColor: const Color(0xFFF97316),
        proposedSet: nextSet,
        timerText: '+${_fmt(elapsed)}',
        timerColor: const Color(0xFFF97316),
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

  ProposedSet? _findNextPending(ParticipantStatus p) {
    bool isDone(String setId) =>
        p.completedSets.any((c) => c.proposedSetId == setId && c.endedAt != Int64.ZERO);
    return p.proposedSets.cast<ProposedSet?>().firstWhere(
      (s) => !isDone(s!.id),
      orElse: () => null,
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
