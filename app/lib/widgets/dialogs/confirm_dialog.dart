/// The yes/no prompt the app asks before an action that can't be taken
/// back.
library;

import 'package:flutter/material.dart';
import '../../theme/theme_spec.dart';

/// Whether the person confirmed. Dismissing the dialog counts as no.
/// [destructive] draws the confirm button in the error colours.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  required String cancel,
  bool destructive = false,
}) async {
  final colorScheme = Theme.of(context).colorScheme;
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            title,
            style: TextStyle(fontWeight: context.tokens.weight.heavy),
          ),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    )
                  : null,
              child: Text(confirm),
            ),
          ],
        ),
      ) ??
      false;
}
