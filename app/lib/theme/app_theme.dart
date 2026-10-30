import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'schlift_spec.dart';
import 'theme_spec.dart';

/// Builds Flutter themes from a [ThemeSpec]. The spec holds every value;
/// this file only maps tokens onto Material's components, and attaches the
/// spec as a theme extension so widgets can read it (`context.tokens`).
class AppTheme {
  AppTheme._();

  /// The app's theme, built from [schliftSpec].
  static final theme = build(schliftSpec);

  /// Standard grab handle for bottom sheets: a flat 36×4 bar.
  static Widget sheetHandle(BuildContext context) => Container(
    width: 36,
    height: 4,
    margin: const EdgeInsets.only(top: 8, bottom: 12),
    color: Theme.of(context).colorScheme.outlineVariant,
  );

  /// Translucent card fill used on the ground (text colour @ ~4%).
  static Color cardFill(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04);

  /// Canonical elevated surface for a bottom sheet / dialog body (panel).
  static Color sheetColor(BuildContext context) =>
      Theme.of(context).bottomSheetTheme.backgroundColor ??
      Theme.of(context).colorScheme.surface;

  static ThemeData build(ThemeSpec s) {
    final controlShape = RoundedRectangleBorder(borderRadius: s.brSm);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(s.buttonRadius),
    );
    TextStyle buttonText(double size, FontWeight weight) => GoogleFonts.getFont(
      s.buttonFont,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: 0,
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: s.brSm,
      borderSide: BorderSide(color: s.outline),
    );
    // Surfaces that sit over the page are flat: square, no shadow, set
    // apart by a line rather than a lift.
    final sheetShape = Border(top: BorderSide(color: s.outline));
    final flatPanel = RoundedRectangleBorder(
      side: BorderSide(color: s.outline),
    );
    final typography = s.isDark
        ? Typography.material2021().white
        : Typography.material2021().black;

    return ThemeData(
      useMaterial3: true,
      brightness: s.brightness,
      extensions: [s],
      scaffoldBackgroundColor: s.background,
      textTheme: _textTheme(typography, s),
      colorScheme: ColorScheme(
        brightness: s.brightness,
        surface: s.background,
        onSurface: s.text,
        primary: s.primary,
        onPrimary: s.onPrimary,
        secondary: s.secondary,
        onSecondary: s.text,
        tertiary: s.muted,
        onTertiary: s.background,
        error: s.error,
        onError: s.onError,
        surfaceContainerHighest: s.surfaceHigh,
        outline: s.outline,
        outlineVariant: s.outline,
      ),
      dividerColor: s.hairline,
      dividerTheme: DividerThemeData(color: s.hairline, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: s.background,
        foregroundColor: s.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        // Page titles in the buttons' face, regular weight.
        titleTextStyle: GoogleFonts.getFont(
          s.buttonFont,
          fontSize: s.size.title,
          fontWeight: s.weight.regular,
          color: s.text,
        ),
      ),
      cardTheme: CardThemeData(
        color: s.panel,
        elevation: 0,
        shape: RoundedRectangleBorder(side: BorderSide(color: s.hairline)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: s.primary,
          foregroundColor: s.onPrimary,
          shape: buttonShape,
          textStyle: buttonText(s.size.subtitle, s.weight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: s.text,
          side: BorderSide(color: s.hairline),
          shape: buttonShape,
          textStyle: buttonText(s.size.subtitle, s.weight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: s.text,
          textStyle: buttonText(s.size.bodyLg, s.weight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.transparent,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: s.brSm,
          borderSide: BorderSide(color: s.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        labelStyle: TextStyle(color: s.muted),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: s.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: flatPanel,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: s.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            right: Radius.circular(s.drawerRadius),
          ),
        ),
        endShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(s.drawerRadius),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: s.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: flatPanel,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: s.brSm),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: s.primary, borderRadius: s.brSm),
        textStyle: TextStyle(color: s.onPrimary),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(shape: controlShape),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: s.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shadowColor: Colors.transparent,
        shape: sheetShape,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? s.primary
              : s.switchThumbOff,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? s.primary.withValues(alpha: 0.5)
              : s.hairline,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: s.primary,
        contentTextStyle: TextStyle(color: s.onPrimary),
        behavior: SnackBarBehavior.fixed,
        elevation: 0,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: s.primary),
    );
  }

  static TextTheme _textTheme(TextTheme base, ThemeSpec s) {
    final bodyText = GoogleFonts.getTextTheme(s.bodyFont, base);

    TextStyle? scaled(TextStyle? style) {
      if (style == null || style.fontSize == null) return style;
      return style.copyWith(fontSize: style.fontSize! * s.fontScale);
    }

    TextStyle? heading(
      TextStyle? style, {
      required int weight,
      double? letterSpacing,
    }) {
      if (style == null) return null;
      final w = (weight + s.headingWeightBoost).clamp(1, 9);
      return GoogleFonts.getFont(
        s.headingFont,
        textStyle: style,
        fontWeight: FontWeight.values[w - 1],
        letterSpacing: letterSpacing ?? style.letterSpacing,
      );
    }

    return bodyText.copyWith(
      displayLarge: heading(
        scaled(bodyText.displayLarge),
        weight: 9,
        letterSpacing: -0.8,
      ),
      displayMedium: heading(
        scaled(bodyText.displayMedium),
        weight: 9,
        letterSpacing: -0.6,
      ),
      displaySmall: heading(
        scaled(bodyText.displaySmall),
        weight: 9,
        letterSpacing: -0.4,
      ),
      headlineLarge: heading(
        scaled(bodyText.headlineLarge),
        weight: 8,
        letterSpacing: -0.4,
      ),
      headlineMedium: heading(
        scaled(bodyText.headlineMedium),
        weight: 8,
        letterSpacing: -0.3,
      ),
      headlineSmall: heading(
        scaled(bodyText.headlineSmall),
        weight: 8,
        letterSpacing: -0.2,
      ),
      titleLarge: heading(
        scaled(bodyText.titleLarge),
        weight: 8,
        letterSpacing: -0.2,
      ),
      titleMedium: heading(
        scaled(bodyText.titleMedium),
        weight: 6,
        letterSpacing: -0.1,
      ),
      titleSmall: heading(
        scaled(bodyText.titleSmall),
        weight: 6,
        letterSpacing: -0.05,
      ),
      bodyLarge: scaled(bodyText.bodyLarge),
      bodyMedium: scaled(bodyText.bodyMedium),
      bodySmall: scaled(bodyText.bodySmall),
      labelLarge: scaled(
        bodyText.labelLarge,
      )?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: scaled(
        bodyText.labelMedium,
      )?.copyWith(fontWeight: FontWeight.w600),
      labelSmall: scaled(bodyText.labelSmall),
    );
  }
}
