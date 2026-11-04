/// Throwing a workout away: the prompt that asks first.
library;

import 'package:flutter/material.dart';
import '../../gen/copy.dart';
import '../../theme/theme_spec.dart';

/// Whether the person confirmed throwing the workout away.
Future<bool> confirmDiscardWorkout(BuildContext context) async {
  final colorScheme = Theme.of(context).colorScheme;
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            copy.workout.discardTitle,
            style: TextStyle(fontWeight: context.tokens.weight.heavy),
          ),
          content: Text(copy.workout.discardBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(copy.workout.discardCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child: Text(copy.workout.discardConfirm),
            ),
          ],
        ),
      ) ??
      false;
}
