import 'package:flutter/material.dart';

import 'theme_spec.dart';

/// The app's look: warm grey hardware, signal orange, Space Grotesk and Space
/// Mono, corners mostly squared off (after Teenage Engineering). Every
/// colour, font, size and radius the app draws with is here; change the look
/// by changing a value.
const schliftSpec = ThemeSpec(
  brightness: Brightness.light,
  background: Color(0xFFBDBDB7),
  panel: Color(0xFFD4D4CF),
  surfaceHigh: Color(0xFFABABA4),
  text: Color(0xFF111111),
  muted: Color(0xFF4A4A44),
  primary: Color(0xFFFF4F00),
  onPrimary: Colors.white,
  secondary: Color(0xFFABABA4),
  hairline: Color(0xFF9B9B94),
  outline: Color(0xFF74746E),
  switchThumbOff: Color(0xFF92928B),
  error: Color(0xFFE0301E),
  // State colours keep their hues but sit with the warm grey: less neon,
  // a touch deeper.
  ready: Color(0xFF3D8B4A),
  success: Color(0xFF3D8B4A),
  effort: Color(0xFFD99A00),
  overdue: Color(0xFFA85F00),
  warning: Color(0xFF8A5A00),
  resting: Color(0xFF3C5FB0),
  // Lifting: a set has been started. The signal orange: do it now.
  lifting: Color(0xFFFF4F00),
  // Yapping: rest has run out and the next set isn't started. Pink.
  yapping: Color(0xFFD94F8C),
  // Chart lines: deep, saturated, each distinct on the warm grey.
  series: [
    Color(0xFF1F4FD1), // blue
    Color(0xFFD03A00), // burnt orange
    Color(0xFF1E7A3C), // green
    Color(0xFFC2185B), // magenta
    Color(0xFF5B2DB8), // violet
    Color(0xFF00796B), // teal
    Color(0xFF8D5A00), // ochre
  ],
  bodyFont: 'Space Grotesk',
  headingFont: 'Space Grotesk',
  buttonFont: 'Space Mono',
  monoFont: 'Space Mono',
  // The wordmark in the buttons' face: Space Mono bold, wobbling.
  wordmarkFont: 'Space Mono',
  wordmarkWeight: FontWeight.w700,
  wordmarkScale: 1.5,
  wordmarkWobble: 1.6,
  displayWeight: FontWeight.w500,
  headingWeightBoost: -1,
  radiusSm: 2,
  radiusMd: 3,
  radiusLg: 4,
  buttonRadius: 3,
  cornerScale: 0.25,
  pills: false,
  drawerRadius: 0,
  // The small end runs large: nothing in the app is drawn under 12pt.
  size: TypeScale(
    caption: 12,
    small: 14,
    body: 16,
    bodyLg: 17,
    subtitle: 19,
    title: 21,
    titleLg: 25,
  ),
);
