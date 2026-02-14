import 'package:flutter/material.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/group.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';

class ParticipantTicker extends StatelessWidget {
  final ParticipantStatus participant;

  const ParticipantTicker({super.key, required this.participant});

  @override
  Widget build(BuildContext context) {
    final name = participant.user.name;
    final statusInfo = _getStatus(participant);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusInfo.color.withValues(alpha: 0.1),
        border: Border.all(color: statusInfo.color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusInfo.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          Text(
            statusInfo.text,
            style: TextStyle(fontSize: 11, color: statusInfo.color),
          ),
        ],
      ),
    );
  }

  _StatusInfo _getStatus(ParticipantStatus p) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Check for active (in-progress) set
    final activeSet = p.completedSets.cast<CompletedSet?>().firstWhere(
      (c) => c!.endedAt == Int64.ZERO,
      orElse: () => null,
    );
    if (activeSet != null) {
      final proposed = p.proposedSets.cast<ProposedSet?>().firstWhere(
        (ps) => ps!.id == activeSet.proposedSetId,
        orElse: () => null,
      );
      final name = proposed != null ? (shortNames[proposed.exercise] ?? '?') : '?';
      return _StatusInfo('lifting $name', Colors.orange);
    }

    // Check for resting
    final restingSet = p.completedSets.cast<CompletedSet?>().firstWhere(
      (c) => c!.endedAt != Int64.ZERO && c.restUntil.toInt() > now,
      orElse: () => null,
    );
    if (restingSet != null) {
      final remaining = restingSet.restUntil.toInt() - now;
      return _StatusInfo('rest ${remaining}s', Colors.blue);
    }

    // Idle
    return _StatusInfo('idle', Colors.grey);
  }
}

class _StatusInfo {
  final String text;
  final Color color;
  _StatusInfo(this.text, this.color);
}
