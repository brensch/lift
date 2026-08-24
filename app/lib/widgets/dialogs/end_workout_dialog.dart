/// Ending a workout: the confirmation dialog and the flow that ends it and opens the summary.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/workout_provider.dart';
import '../../providers/multiplayer_provider.dart';
import '../../screens/completed_workout_screen.dart';

Future<void> endWorkout(BuildContext context) async {
  final confirmed = await showEndWorkoutConfirmDialog(context);
  if (confirmed && context.mounted) {
    final wp = context.read<WorkoutProvider>();
    final mp = context.read<MultiplayerProvider>();
    final navigator = Navigator.of(context, rootNavigator: true);

    final workoutId = wp.workout?.id;
    if (workoutId == null) return;

    final completedRoute = MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => CompletedWorkoutScreen(workoutId: workoutId),
    );
    unawaited(navigator.push(completedRoute));

    await wp.endWorkout(fireEndedCallback: false);
    final endedWorkout = wp.workout;
    final endSucceeded =
        endedWorkout != null &&
        endedWorkout.id == workoutId &&
        wp.isWorkoutEnded;
    if (!endSucceeded) {
      if (navigator.canPop()) navigator.pop();
      return;
    }

    mp.markLocalWorkoutFinished();
  }
}

Future<bool> showEndWorkoutConfirmDialog(BuildContext context) async {
  final colorScheme = Theme.of(context).colorScheme;
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(
            'End Workout?',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: const Text('This will end your current workout.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: const Text('End Workout'),
            ),
          ],
        ),
      ) ??
      false;
}
