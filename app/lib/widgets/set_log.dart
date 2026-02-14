import 'package:flutter/material.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';

class SetLog extends StatelessWidget {
  final List<ProposedSet> proposedSets;
  final List<CompletedSet> completedSets;
  final void Function(String completedSetId)? onDelete;

  const SetLog({
    super.key,
    required this.proposedSets,
    required this.completedSets,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final done = completedSets
        .where((c) => c.endedAt != Int64.ZERO)
        .toList()
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));

    if (done.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Completed Sets',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        ...done.map((completed) {
          final proposed = proposedSets.cast<ProposedSet?>().firstWhere(
            (p) => p!.id == completed.proposedSetId,
            orElse: () => null,
          );
          final name = proposed != null ? (shortNames[proposed.exercise] ?? '?') : '?';
          final isWarmup = proposed?.warmup ?? false;
          final hitTarget = proposed != null ? completed.actualReps >= proposed.targetReps : true;

          return ListTile(
            dense: true,
            leading: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isWarmup
                    ? Colors.blue.withValues(alpha: 0.2)
                    : hitTarget
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                isWarmup ? 'W' : '\u2713',
                style: TextStyle(
                  fontSize: 12,
                  color: isWarmup ? Colors.blue : hitTarget ? Colors.green : Colors.amber.shade700,
                ),
              ),
            ),
            title: Text('$name: ${completed.actualReps} \u00D7 ${completed.actualWeight.toInt()} lbs'),
            trailing: onDelete != null
                ? IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => onDelete!(completed.id),
                  )
                : null,
          );
        }),
      ],
    );
  }
}
