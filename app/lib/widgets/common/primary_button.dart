/// The login screen's passkey button: the theme primary, full width, with
/// a fingerprint before the label.
library;

import 'package:flutter/material.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme_spec.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.primary;
    final fg = cs.onPrimary;
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
                  Icon(AppIcons.fingerprint, size: 19, color: fg),
                  const SizedBox(width: 9),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: context.tokens.weight.bold,
                      fontSize: context.tokens.size.bodyLg,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
