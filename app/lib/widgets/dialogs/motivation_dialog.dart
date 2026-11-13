/// The workout's motivational quote, in a pop-up: the quote, and under it a
/// line saying it is this workout's.
library;

import 'package:flutter/material.dart';

import '../../gen/copy.dart';
import '../../theme/theme_spec.dart';

Future<void> showMotivationDialog(BuildContext context, String quote) {
  final t = context.tokens;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        copy.motivation.title,
        style: TextStyle(
          fontSize: t.size.headline,
          fontWeight: t.weight.regular,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quote,
            style: TextStyle(
              fontSize: t.size.titleLg,
              fontWeight: t.weight.bold,
              color: t.text,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            copy.motivation.footer,
            style: TextStyle(fontSize: t.size.body, color: t.muted),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(copy.motivation.close),
        ),
      ],
    ),
  );
}
