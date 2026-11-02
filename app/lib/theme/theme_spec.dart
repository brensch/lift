import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Every design token the app draws with: colours, type and shape.
///
/// The spec is the single source of truth for the look. [AppTheme.build]
/// turns it into a [ThemeData] (and attaches the spec itself as a theme
/// extension), so widgets read tokens from the theme with `context.tokens`.
/// The app's values are in schlift_spec.dart. Nothing else hard-codes a
/// colour, font, text size, weight or radius.
/// The text sizes the app uses. Widgets pick a step by name
/// (`context.tokens.size.body`), never a number.
@immutable
class TypeScale {
  const TypeScale({
    required this.caption,
    required this.small,
    required this.body,
    required this.bodyLg,
    required this.subtitle,
    required this.title,
    required this.titleLg,
    required this.headline,
    required this.headlineLg,
    required this.display,
    required this.displayLg,
    required this.giant,
  });

  /// Tags, axis labels, the smallest print.
  final double caption;

  /// Secondary labels and metadata.
  final double small;

  /// Running text.
  final double body;
  final double bodyLg;
  final double subtitle;

  /// Card titles, menu items.
  final double title;
  final double titleLg;

  /// Screen titles.
  final double headline;
  final double headlineLg;

  /// Big numbers: weights, timers, totals.
  final double display;
  final double displayLg;
  final double giant;
}

/// The four weights the app uses, by role.
@immutable
class FontWeights {
  const FontWeights({
    required this.regular,
    required this.medium,
    required this.bold,
    required this.heavy,
  });

  final FontWeight regular;
  final FontWeight medium;
  final FontWeight bold;

  /// Emphasis: titles, numbers, buttons.
  final FontWeight heavy;
}

@immutable
class ThemeSpec extends ThemeExtension<ThemeSpec> {
  const ThemeSpec({
    required this.background,
    required this.panel,
    required this.surfaceHigh,
    required this.text,
    required this.muted,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.hairline,
    required this.outline,
    required this.switchThumbOff,
    required this.error,
    required this.onError,
    required this.success,
    required this.ready,
    required this.overdue,
    required this.warmup,
    required this.resting,
    required this.yapping,
    required this.lifting,
    required this.short,
    required this.heart,
    required this.series,
    required this.bodyParts,
    required this.bodyFont,
    required this.headingFont,
    required this.buttonFont,
    required this.monoFont,
    required this.wordmarkFont,
    required this.wordmarkWeight,
    required this.wordmarkScale,
    required this.wordmarkWobble,
    required this.headingWeightBoost,
    required this.fontScale,
    required this.radiusSm,
    required this.radiusMd,
    required this.buttonRadius,
    required this.size,
    required this.weight,
    required this.cornerScale,
    required this.pills,
    required this.drawerRadius,
  });

  // ─── Neutrals ──────────────────────────────────────────────────────
  /// Page ground: scaffold, app bar, drawer.
  final Color background;

  /// Raised surfaces: cards, sheets, dialogs.
  final Color panel;

  /// Filled controls and wells on the ground (surfaceContainerHighest).
  final Color surfaceHigh;
  final Color text;

  /// Secondary text (the colour scheme's tertiary).
  final Color muted;

  /// Filled buttons, focus rings, switches, progress.
  final Color primary;
  final Color onPrimary;
  final Color secondary;

  /// Dividers, card borders, outlined-button borders.
  final Color hairline;

  /// Input borders and the scheme's outline.
  final Color outline;
  final Color switchThumbOff;
  final Color error;
  final Color onError;

  // ─── Status: one colour per meaning ────────────────────────────────
  final Color success;

  /// Ready / done-today green on the home screen.
  final Color ready;

  /// Overdue amber.
  final Color overdue;
  final Color warmup;

  /// The live workout states: lifting (counting up from Start), resting
  /// (blue countdown) and yapping (pink count-up).
  final Color resting;
  final Color yapping;
  final Color lifting;

  /// A set done with fewer reps than planned (amber).
  final Color short;

  /// Heart-rate icons.
  final Color heart;

  // ─── Categorical ───────────────────────────────────────────────────
  /// Chart lines, one per exercise (cycled), first one for single charts.
  final List<Color> series;

  /// One per BodyPart, in enum order (chest, back, shoulders, arms, legs,
  /// ass, core).
  final List<Color> bodyParts;

  // ─── Type (Google Fonts family names) ──────────────────────────────
  final String bodyFont;
  final String headingFont;
  final String buttonFont;

  /// Timers and other numbers that must not jiggle as they count.
  final String monoFont;

  /// The SCHLIFT wordmark.
  final String wordmarkFont;
  final FontWeight wordmarkWeight;

  /// Multiplies the size each screen draws the wordmark at.
  final double wordmarkScale;

  /// How far each wordmark letter drifts as it wobbles, in logical pixels.
  final double wordmarkWobble;

  /// Added to every heading weight (in hundreds), for looks that want
  /// heavier or lighter display type. Clamped to w100–w900.
  final int headingWeightBoost;
  final double fontScale;

  /// Every text size widgets draw at.
  final TypeScale size;

  /// Every font weight widgets draw at.
  final FontWeights weight;

  // ─── Shape ─────────────────────────────────────────────────────────
  /// Chips, inputs, segmented controls, small buttons.
  final double radiusSm;

  /// Cards and primary call-to-action panels.
  final double radiusMd;

  /// Every Material button; large values make pills.
  final double buttonRadius;

  /// Multiplies every corner a widget asks for with [corner] / [br]: 1 keeps
  /// the designed sizes, smaller squares the whole app off.
  final double cornerScale;

  /// Whether pill shapes (radius ≥ 99) stay pills. When false they become
  /// [buttonRadius] rectangles.
  final bool pills;

  /// The side menu's open edge. 0 for a hard edge.
  final double drawerRadius;

  // ─── Derived ───────────────────────────────────────────────────────
  BorderRadius get brSm => BorderRadius.circular(radiusSm);
  BorderRadius get brMd => BorderRadius.circular(radiusMd);

  /// A widget's designed corner [r], in this look. Widgets use this (or
  /// [br] / [radius]) instead of a literal, so a look can square or soften
  /// everything at once. Circles (BoxShape.circle) stay circles.
  double corner(double r) =>
      r >= 99 ? (pills ? r : buttonRadius) : r * cornerScale;
  BorderRadius br(double r) => BorderRadius.circular(corner(r));
  Radius radius(double r) => Radius.circular(corner(r));

  /// [base] in the wordmark's font, weight and size.
  TextStyle wordmark([TextStyle base = const TextStyle()]) =>
      GoogleFonts.getFont(
        wordmarkFont,
        textStyle: base.copyWith(
          fontSize: base.fontSize == null
              ? null
              : base.fontSize! * wordmarkScale,
        ),
        fontWeight: wordmarkWeight,
      );

  /// [base] in the mono font, for counting numbers.
  TextStyle mono([TextStyle base = const TextStyle()]) =>
      GoogleFonts.getFont(monoFont, textStyle: base);

  // ThemeExtension plumbing. Specs are swapped whole, never blended.
  @override
  ThemeSpec copyWith() => this;

  @override
  ThemeSpec lerp(ThemeSpec? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension ThemeSpecContext on BuildContext {
  /// The active [ThemeSpec]: every colour, font and radius to draw with.
  ThemeSpec get tokens => Theme.of(this).extension<ThemeSpec>()!;
}
