/// The login screen's passkey button: the theme primary, full width, with
/// the label in whichever of black or white reads on it.
library;

import 'package:flutter/material.dart';
import '../../theme/theme_spec.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.primary;
    final fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: cs.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          disabledForegroundColor: cs.onSurfaceVariant,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: context.tokens.brMd),
        ),
        child: loading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 19, color: fg),
                    const SizedBox(width: 9),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: context.tokens.weight.bold,
                      fontSize: context.tokens.size.bodyLg,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
