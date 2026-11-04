import 'package:flutter/material.dart';
import '../../theme/theme_spec.dart';

/// A rare, one-way action (ending or throwing away a workout): a quiet,
/// centred text link rather than a full-width button.
class QuietLink extends StatelessWidget {
  const QuietLink({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.onSurface.withValues(alpha: 0.5),
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: context.tokens.weight.bold,
            fontSize: context.tokens.size.body,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
