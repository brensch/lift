/// Throwing a workout away: the prompt that asks first.
library;

import 'package:flutter/material.dart';
import '../../gen/copy.dart';
import 'confirm_dialog.dart';

/// Whether the person confirmed throwing the workout away.
Future<bool> confirmDiscardWorkout(BuildContext context) => confirmDialog(
  context,
  title: copy.workout.discardTitle,
  body: copy.workout.discardBody,
  confirm: copy.workout.discardConfirm,
  cancel: copy.workout.discardCancel,
  destructive: true,
);
