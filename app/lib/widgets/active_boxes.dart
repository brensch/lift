import 'package:flutter/material.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../logic/exercises.dart';
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
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Resting', style: TextStyle(fontSize: 14, color: Colors.blue)),
            const SizedBox(height: 8),
            Text(
              _formatDuration(secondsRemaining),
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            if (onSkip != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(onPressed: onSkip, child: const Text('Skip Rest')),
            ],
          ],
        ),
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
    final elapsedSecs = activeCompletedSet != null
        ? (now.millisecondsSinceEpoch ~/ 1000) - activeCompletedSet!.startedAt.toInt()
        : 0;
    final name = shortNames[proposedSet.exercise] ?? '?';

    return Card(
      color: proposedSet.warmup ? Colors.blue.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (proposedSet.warmup)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('WARMUP', style: TextStyle(fontSize: 10, color: Colors.blue)),
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
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                PlateVisualization(weight: proposedSet.targetWeight.toDouble()),
              ],
            ),
            if (elapsedSecs > 0) ...[
              const SizedBox(height: 4),
              Text(
                _formatDuration(elapsedSecs),
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
        // Quick complete with target reps
        FilledButton(
          onPressed: () => onComplete(targetReps, targetWeight),
          child: Text('$targetReps reps'),
        ),
        // Minus reps buttons
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
    final name = shortNames[nextSet.exercise] ?? '?';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Next Up: $name',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${nextSet.targetReps} \u00D7 ${nextSet.targetWeight.toInt()} lbs',
                  style: const TextStyle(fontSize: 18),
                ),
                if (nextSet.warmup)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('warmup', style: TextStyle(fontSize: 10, color: Colors.blue)),
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
      ),
    );
  }
}
