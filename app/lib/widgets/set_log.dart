import 'package:flutter/material.dart';
import 'package:fixnum/fixnum.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../theme/app_theme.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
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
            'COMPLETED SETS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: colorScheme.tertiary,
            ),
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

          Color bg;
          Color fg;
          String label;

          if (isWarmup) {
            bg = AppTheme.warmupLight;
            fg = AppTheme.warmupFg;
            label = 'W';
          } else if (hitTarget) {
            bg = AppTheme.successBg;
            fg = AppTheme.successFg;
            label = '\u2713';
          } else {
            bg = AppTheme.warningBg;
            fg = AppTheme.warningFg;
            label = '\u2713';
          }

          return ListTile(
            dense: true,
            leading: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
              ),
            ),
            title: Text('$name: ${completed.actualReps} \u00D7 ${completed.actualWeight.toInt()} lbs'),
            trailing: onDelete != null
                ? IconButton(
                    icon: Icon(Icons.close, size: 16, color: colorScheme.tertiary),
                    onPressed: () => onDelete!(completed.id),
                  )
                : null,
          );
        }),
      ],
    );
  }
}
