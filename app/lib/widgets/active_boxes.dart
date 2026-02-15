import 'package:flutter/material.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
import '../theme/app_theme.dart';
import '../widgets/plate_visualization.dart';

String _formatDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

class RestingBox extends StatelessWidget {
  final int secondsRemaining;
  final VoidCallback? onSkip;

  const RestingBox({super.key, required this.secondsRemaining, this.onSkip});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.secondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        children: [
          Text(
            'RESTING',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: colorScheme.tertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDuration(secondsRemaining),
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              letterSpacing: -2,
              color: colorScheme.onSurface,
            ),
          ),
          if (onSkip != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onSkip, child: const Text('Skip Rest')),
          ],
        ],
      ),
    );
  }
}

class ActiveSetBox extends StatelessWidget {
  final ProposedSet proposedSet;
  final CompletedSet? activeCompletedSet;
  final DateTime now;
  final void Function(int reps, double weight) onComplete;

  const ActiveSetBox({
    super.key,
    required this.proposedSet,
    this.activeCompletedSet,
    required this.now,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final elapsedSecs = activeCompletedSet != null
        ? (now.millisecondsSinceEpoch ~/ 1000) - activeCompletedSet!.startedAt.toInt()
        : 0;
    final name = shortNames[proposedSet.exercise] ?? '?';
    final isWarmup = proposedSet.warmup;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWarmup ? AppTheme.warmupLight : AppTheme.activeBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isWarmup
              ? AppTheme.warmupFg.withValues(alpha: 0.3)
              : AppTheme.activeFg.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isWarmup)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.warmupFg.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'WARMUP',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.warmupFg,
                    ),
                  ),
                ),
              Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${proposedSet.targetReps} \u00D7 ${proposedSet.targetWeight.toInt()} lbs',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 8),
              PlateVisualization(weight: proposedSet.targetWeight.toDouble()),
            ],
          ),
          if (elapsedSecs > 0) ...[
            const SizedBox(height: 4),
            Text(
              _formatDuration(elapsedSecs),
              style: TextStyle(fontSize: 14, color: colorScheme.tertiary),
            ),
          ],
          const SizedBox(height: 12),
          _CompletionButtons(
            targetReps: proposedSet.targetReps,
            targetWeight: proposedSet.targetWeight.toDouble(),
            onComplete: onComplete,
          ),
        ],
      ),
    );
  }
}

class _CompletionButtons extends StatelessWidget {
  final int targetReps;
  final double targetWeight;
  final void Function(int reps, double weight) onComplete;

  const _CompletionButtons({
    required this.targetReps,
    required this.targetWeight,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        FilledButton(
          onPressed: () => onComplete(targetReps, targetWeight),
          child: Text('$targetReps reps'),
        ),
        for (int diff = 1; diff <= 2 && targetReps - diff > 0; diff++)
          OutlinedButton(
            onPressed: () => onComplete(targetReps - diff, targetWeight),
            child: Text('${targetReps - diff}'),
          ),
      ],
    );
  }
}

class NextUpBox extends StatelessWidget {
  final ProposedSet nextSet;
  final VoidCallback onStart;

  const NextUpBox({super.key, required this.nextSet, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = shortNames[nextSet.exercise] ?? '?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        children: [
          Text(
            'NEXT UP',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: colorScheme.tertiary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$name  ${nextSet.targetReps} \u00D7 ${nextSet.targetWeight.toInt()} lbs',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              if (nextSet.warmup)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.warmupLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'warmup',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.warmupFg),
                  ),
                ),
              const SizedBox(width: 8),
              PlateVisualization(weight: nextSet.targetWeight.toDouble()),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onStart,
            child: const Text('Start Set'),
          ),
        ],
      ),
    );
  }
}
