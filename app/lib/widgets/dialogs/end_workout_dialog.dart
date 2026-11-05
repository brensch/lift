/// Ending a workout: the confirmation dialog and the flow that ends it and opens the summary.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/workout_provider.dart';
import '../../screens/completed_workout_screen.dart';
import '../../gen/copy.dart';
import 'confirm_dialog.dart';

Future<void> endWorkout(BuildContext context) async {
  final confirmed = await showEndWorkoutConfirmDialog(context);
  if (confirmed && context.mounted) {
    final wp = context.read<WorkoutProvider>();
    final navigator = Navigator.of(context, rootNavigator: true);

    final workoutId = wp.workout?.id;
    if (workoutId == null) return;

    final completedRoute = MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/workout/:id/completed'),
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
    if (!endSucceeded && navigator.canPop()) navigator.pop();
  }
}

Future<bool> showEndWorkoutConfirmDialog(BuildContext context) => confirmDialog(
  context,
  title: copy.endWorkoutDialog.title,
  body: copy.endWorkoutDialog.body,
  confirm: copy.endWorkoutDialog.confirm,
  cancel: copy.endWorkoutDialog.cancel,
  destructive: true,
);
