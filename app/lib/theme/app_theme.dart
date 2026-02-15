import 'package:flutter/material.dart';

/// Monochrome, minimalist theme inspired by shadcn/ui.
/// No blue accents — neutral grays, whites, and near-black.
class AppTheme {
  AppTheme._();

  // ─── Shared constants ───────────────────────────────────────────────
  static const _fontFamily = 'Inter'; // Falls back to system sans-serif
  static const _radius = 8.0;
  static final _borderRadius = BorderRadius.circular(_radius);
  static final _buttonShape = RoundedRectangleBorder(borderRadius: _borderRadius);

  // ─── Semantic colors (same in both modes, used via extension) ──────
  static const warmupLight = Color(0x1A6B7280); // gray-500 @ 10%
  static const warmupFg = Color(0xFF6B7280);    // gray-500
  static const successBg = Color(0x1A22C55E);   // green-500 @ 10%
  static const successFg = Color(0xFF16A34A);    // green-600
  static const warningBg = Color(0x1AF59E0B);   // yellow-500 @ 10%
  static const warningFg = Color(0xFFCA8A04);    // yellow-600
  static const activeBg = Color(0x1AF97316);     // orange-500 @ 10%
  static const activeFg = Color(0xFFEA580C);     // orange-600
  static const destructive = Color(0xFFDC2626);  // red-600

  // ─── Light theme ───────────────────────────────────────────────────
  static final light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: _fontFamily,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: const ColorScheme.light(
      surface: Colors.white,
      onSurface: Color(0xFF0A0A0A),
      primary: Color(0xFF171717),       // near-black primary
      onPrimary: Color(0xFFFAFAFA),
      secondary: Color(0xFFE5E5E5),     // darker gray for better contrast
      onSecondary: Color(0xFF171717),
      tertiary: Color(0xFF737373),      // muted text
      error: Color(0xFFDC2626),
      onError: Colors.white,
      surfaceContainerHighest: Color(0xFFF5F5F5),
      outline: Color(0xFFE5E5E5),       // border
      outlineVariant: Color(0xFFE5E5E5),
    ),
    dividerColor: const Color(0xFFE5E5E5),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF0A0A0A),
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: _borderRadius,
        side: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: const Color(0xFFFAFAFA),
        shape: _buttonShape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF171717),
        side: const BorderSide(color: Color(0xFFE5E5E5)),
        shape: _buttonShape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF171717),
        textStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: _borderRadius,
        borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _borderRadius,
        borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _borderRadius,
        borderSide: const BorderSide(color: Color(0xFF171717), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      labelStyle: const TextStyle(color: Color(0xFF737373)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return const Color(0xFF171717);
        return const Color(0xFFD4D4D4);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return const Color(0xFF171717).withValues(alpha: 0.5);
        return const Color(0xFFE5E5E5);
      }),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF171717),
      contentTextStyle: TextStyle(color: Color(0xFFFAFAFA)),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Color(0xFF171717),
    ),
  );

  // ─── Dark theme ────────────────────────────────────────────────────
  static final dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: _fontFamily,
    scaffoldBackgroundColor: const Color(0xFF0A0A0A),
    colorScheme: const ColorScheme.dark(
      surface: Color(0xFF0A0A0A),
      onSurface: Color(0xFFFAFAFA),
      primary: Color(0xFFFAFAFA),       // white primary (inverted)
      onPrimary: Color(0xFF0A0A0A),
      secondary: Color(0xFF262626),     // dark gray
      onSecondary: Color(0xFFFAFAFA),
      tertiary: Color(0xFFA3A3A3),      // muted text
      error: Color(0xFFEF4444),
      onError: Colors.white,
      surfaceContainerHighest: Color(0xFF1A1A1A),
      outline: Color(0xFF262626),       // border
      outlineVariant: Color(0xFF262626),
    ),
    dividerColor: const Color(0xFF262626),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0A0A0A),
      foregroundColor: Color(0xFFFAFAFA),
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF141414),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: _borderRadius,
        side: const BorderSide(color: Color(0xFF262626)),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFFAFAFA),
        foregroundColor: const Color(0xFF0A0A0A),
        shape: _buttonShape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFFAFAFA),
        side: const BorderSide(color: Color(0xFF262626)),
        shape: _buttonShape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFFAFAFA),
        textStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF141414),
      border: OutlineInputBorder(
        borderRadius: _borderRadius,
        borderSide: const BorderSide(color: Color(0xFF262626)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _borderRadius,
        borderSide: const BorderSide(color: Color(0xFF262626)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _borderRadius,
        borderSide: const BorderSide(color: Color(0xFFFAFAFA), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      labelStyle: const TextStyle(color: Color(0xFFA3A3A3)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF141414),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Color(0xFF0A0A0A),
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF141414),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return const Color(0xFFFAFAFA);
        return const Color(0xFF525252);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return const Color(0xFFFAFAFA).withValues(alpha: 0.5);
        return const Color(0xFF262626);
      }),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFFFAFAFA),
      contentTextStyle: TextStyle(color: Color(0xFF0A0A0A)),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Color(0xFFFAFAFA),
    ),
  );
}
