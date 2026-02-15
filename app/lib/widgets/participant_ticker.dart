import 'package:flutter/material.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/group.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../theme/app_theme.dart';
import '../widgets/plate_visualization.dart';

String _fmt(int seconds) {
  final m = seconds.abs() ~/ 60;
  final s = seconds.abs() % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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

  static const _purple = Color(0xFF9333EA);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = participant.user.name;
    final status = _getStatus(participant);

    final borderColor = isNextUp
        ? _purple.withValues(alpha: 0.5)
        : colorScheme.outline;
    final bgColor = isNextUp
        ? _purple.withValues(alpha: 0.05)
        : colorScheme.surface;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: isNextUp ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: name + state dot + timer
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: status.stateColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                status.stateLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: status.stateColor,
                ),
              ),
              if (status.timerText != null) ...[
                const SizedBox(width: 6),
                Text(
                  status.timerText!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: status.timerColor ?? colorScheme.onSurface,
                  ),
                ),
              ],
            ],
          ),
          // Row 2: exercise + weight info
          if (status.exerciseName != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  status.exerciseName!,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                if (status.isWarmup) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    decoration: BoxDecoration(
                      color: AppTheme.warmupFg.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'W',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warmupFg,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Text(
                  '${status.weight} lb',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 6),
                PlateVisualization(weight: status.weightDouble),
              ],
            ),
          ],
        ],
      ),
    );
  }

  _ParticipantState _getStatus(ParticipantStatus p) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

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
      return _ParticipantState(
        stateLabel: proposed?.warmup == true ? 'WARMUP' : 'LIFTING',
        stateColor: AppTheme.activeFg,
        exerciseName: proposed != null ? (exerciseNames[proposed.exercise] ?? '?') : null,
        isWarmup: proposed?.warmup ?? false,
        weight: proposed != null ? '${proposed.targetWeight.toInt()}' : null,
        weightDouble: proposed?.targetWeight.toDouble() ?? 0,
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
      return _ParticipantState(
        stateLabel: 'RESTING',
        stateColor: const Color(0xFF3B82F6),
        exerciseName: nextSet != null ? (exerciseNames[nextSet.exercise] ?? '?') : null,
        isWarmup: nextSet?.warmup ?? false,
        weight: nextSet != null ? '${nextSet.targetWeight.toInt()}' : null,
        weightDouble: nextSet?.targetWeight.toDouble() ?? 0,
        timerText: _fmt(remaining),
        timerColor: null,
      );
    }

    // Check for chatting (rest ended, next set pending)
    final restingSets = p.completedSets
        .where((c) => c.endedAt != Int64.ZERO && c.restUntil != Int64.ZERO)
        .toList();
    restingSets.sort((a, b) => b.endedAt.compareTo(a.endedAt));
    final lastRestEnd = restingSets.isNotEmpty ? restingSets.first.restUntil.toInt() : 0;
    final nextSet = _findNextPending(p);

    if (lastRestEnd > 0 && lastRestEnd <= now && nextSet != null) {
      final elapsed = now - lastRestEnd;
      return _ParticipantState(
        stateLabel: 'CHATTING',
        stateColor: const Color(0xFFF97316),
        exerciseName: exerciseNames[nextSet.exercise] ?? '?',
        isWarmup: nextSet.warmup,
        weight: '${nextSet.targetWeight.toInt()}',
        weightDouble: nextSet.targetWeight.toDouble(),
        timerText: '+${_fmt(elapsed)}',
        timerColor: const Color(0xFFF97316),
      );
    }

    // Idle / next up
    if (nextSet != null) {
      return _ParticipantState(
        stateLabel: 'NEXT UP',
        stateColor: AppTheme.warmupFg,
        exerciseName: exerciseNames[nextSet.exercise] ?? '?',
        isWarmup: nextSet.warmup,
        weight: '${nextSet.targetWeight.toInt()}',
        weightDouble: nextSet.targetWeight.toDouble(),
      );
    }

    // All done
    return _ParticipantState(
      stateLabel: 'DONE',
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

class _ParticipantState {
  final String stateLabel;
  final Color stateColor;
  final String? exerciseName;
  final bool isWarmup;
  final String? weight;
  final double weightDouble;
  final String? timerText;
  final Color? timerColor;

  _ParticipantState({
    required this.stateLabel,
    required this.stateColor,
    this.exerciseName,
    this.isWarmup = false,
    this.weight,
    this.weightDouble = 0,
    this.timerText,
    this.timerColor,
  });
}
