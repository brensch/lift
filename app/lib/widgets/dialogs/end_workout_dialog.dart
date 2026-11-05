/// Ending a workout: the confirmation dialog and the flow that ends it and opens the summary.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/workout_provider.dart';
import '../../gen/copy.dart';
import 'confirm_dialog.dart';

/// Ends through the same path as the watch: once the end is recorded,
/// [WorkoutProvider.onWorkoutEnded] opens the summary and any template offer.
Future<void> endWorkout(BuildContext context) async {
  final confirmed = await showEndWorkoutConfirmDialog(context);
  if (confirmed && context.mounted) {
    await context.read<WorkoutProvider>().endWorkout();
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
