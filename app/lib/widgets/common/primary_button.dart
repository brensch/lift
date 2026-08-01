/// The single primary call-to-action for the app (home Start, onboarding,
/// login, etc.). One height/radius/weight; an optional [accent] tints it (the
/// readiness state on home, the user's profile colour in onboarding) with
/// automatic contrast for the label.
library;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PrimaryButton extends StatelessWidget {
  final String label;

  /// Small trailing note rendered after a middot, e.g. "· 52m". Optional.
  final String? trailing;
  final VoidCallback? onPressed;
  final bool loading;

  /// Tint. Defaults to the theme primary (monochrome). Contrast is derived.
  final Color? accent;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    this.trailing,
    this.onPressed,
    this.loading = false,
    this.accent,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = accent ?? cs.primary;
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
          disabledBackgroundColor:
              cs.surfaceContainerHighest.withValues(alpha: 0.4),
          disabledForegroundColor: cs.onSurfaceVariant,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AppTheme.brMd),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                      letterSpacing: -0.1,
                    ),
                  ),
                  if (trailing != null && trailing!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      trailing!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: fg.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
