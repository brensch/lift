import 'package:flutter/material.dart';

import '../theme/theme_spec.dart';
import 'wobbly_text.dart';

/// The SCHLIFT wordmark, in the spec's wordmark font, weight and spacing,
/// each letter wobbling by the spec's amount.
class Wordmark extends StatelessWidget {
  /// Letter size; the app bar's size by default.
  final double? size;

  const Wordmark({super.key, this.size});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return WobblyText(
      text: 'SCHLIFT',
      fontSize: size ?? t.size.titleLg,
      maxOffset: t.wordmarkWobble * (size ?? t.size.titleLg) / t.size.titleLg,
    );
  }
}
