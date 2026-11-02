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
    this.caption = 10,
    this.small = 12,
    this.body = 14,
    this.bodyLg = 16,
    this.subtitle = 18,
    this.title = 20,
    this.titleLg = 24,
    this.headline = 28,
    this.headlineLg = 32,
    this.display = 40,
    this.displayLg = 48,
    this.giant = 64,
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
    this.regular = FontWeight.w400,
    this.medium = FontWeight.w500,
    this.bold = FontWeight.w700,
    this.heavy = FontWeight.w900,
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
    required this.brightness,
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
    this.onError = Colors.white,
    this.success = const Color(0xFF16A34A),
    this.ready = const Color(0xFF3AD98B),
    this.warning = const Color(0xFFCA8A04),
    this.overdue = const Color(0xFFF5B544),
    this.active = const Color(0xFFEA580C),
    this.destructive = const Color(0xFFDC2626),
    this.warmup = const Color(0xFF6B7280),
    this.resting = const Color(0xFF3B82F6),
    this.yapping = const Color(0xFFEC4899),
    this.lifting = const Color(0xFF16A34A),
    this.effort = const Color(0xFFF59E0B),
    this.info = const Color(0xFF6EA8FF),
    this.heart = const Color(0xFFE11D48),
    this.series = const [
      Color(0xFF60A5FA), // blue
      Color(0xFFF59E0B), // amber
      Color(0xFF34D399), // green
      Color(0xFFF472B6), // pink
      Color(0xFFA78BFA), // violet
      Color(0xFF22D3EE), // cyan
      Color(0xFFFB7185), // rose
    ],
    this.bodyParts = const [
      Color(0xFF6BB6FF), // chest
      Color(0xFFE3C66B), // back
      Color(0xFFC79BFF), // shoulders
      Color(0xFFFFB36B), // arms
      Color(0xFF7CF2C0), // legs
      Color(0xFFFF7EB6), // ass
      Color(0xFF6BE3E3), // core
    ],
    required this.bodyFont,
    required this.headingFont,
    required this.buttonFont,
    required this.monoFont,
    this.wordmarkFont,
    this.displayWeight = FontWeight.w900,
    this.wordmarkWeight = FontWeight.w900,
    this.wordmarkScale = 1,
    this.wordmarkTracking = 0,
    this.wordmarkWobble = 0.8,
    this.wordmarkEmbolden = 0,
    this.headingWeightBoost = 0,
    this.fontScale = 1.06,
    this.radiusSm = 10,
    this.radiusMd = 16,
    this.radiusLg = 24,
    this.buttonRadius = 10,
    this.size = const TypeScale(),
    this.weight = const FontWeights(),
    this.cornerScale = 1,
    this.pills = true,
    this.drawerRadius = 16,
  });

  final Brightness brightness;

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
  final Color warning;

  /// Overdue amber.
  final Color overdue;
  final Color active;
  final Color destructive;
  final Color warmup;

  /// The live workout states: lifting (counting up from Start), resting
  /// (blue countdown), yapping (pink
  /// count-up) and the effort question (amber).
  final Color resting;
  final Color yapping;
  final Color lifting;
  final Color effort;
  final Color info;

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

  /// The big live numbers in the workout bar: the set (weight × reps) and
  /// the rest timer.
  final FontWeight displayWeight;

  /// The SCHLIFT wordmark; null uses [headingFont].
  final String? wordmarkFont;
  final FontWeight wordmarkWeight;

  /// Multiplies the size each screen draws the wordmark at.
  final double wordmarkScale;

  /// Extra space after each wordmark letter, in logical pixels.
  final double wordmarkTracking;

  /// How far each wordmark letter drifts as it wobbles, in logical pixels.
  final double wordmarkWobble;

  /// Thickens the wordmark's strokes past its weight, as a fraction of its
  /// size: a weight between the font's own when it has too few.
  final double wordmarkEmbolden;

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

  /// Sheets and dialogs.
  final double radiusLg;

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
  bool get isDark => brightness == Brightness.dark;
  BorderRadius get brSm => BorderRadius.circular(radiusSm);
  BorderRadius get brMd => BorderRadius.circular(radiusMd);
  BorderRadius get brLg => BorderRadius.circular(radiusLg);

  /// A widget's designed corner [r], in this look. Widgets use this (or
  /// [br] / [radius]) instead of a literal, so a look can square or soften
  /// everything at once. Circles (BoxShape.circle) stay circles.
  double corner(double r) =>
      r >= 99 ? (pills ? r : buttonRadius) : r * cornerScale;
  BorderRadius br(double r) => BorderRadius.circular(corner(r));
  Radius radius(double r) => Radius.circular(corner(r));

  Color get successFg => success;
  Color get successBg => success.withValues(alpha: 0.1);
  Color get warningFg => warning;
  Color get warningBg => warning.withValues(alpha: 0.1);
  Color get activeFg => active;
  Color get activeBg => active.withValues(alpha: 0.1);
  Color get warmupFg => warmup;
  Color get warmupLight => warmup.withValues(alpha: 0.1);
  Color get accentGreen => ready;
  Color get accentAmber => overdue;
  Color get accentRed => destructive;
  Color get accentBlue => info;
  Color get workoutRestingFg => resting;
  Color get workoutRestingBg => resting.withValues(alpha: 0.1);
  Color get workoutLiftingFg => lifting;
  Color get workoutLiftingBg => lifting.withValues(alpha: 0.1);
  Color get workoutYappingFg => yapping;
  Color get workoutYappingBg => yapping.withValues(alpha: 0.1);
  Color get workoutEffortFg => effort;
  Color get workoutEffortBg => effort.withValues(alpha: 0.1);

  /// [base] in the wordmark's font, weight, size and spacing.
  TextStyle wordmark([TextStyle base = const TextStyle()]) =>
      GoogleFonts.getFont(
        wordmarkFont ?? headingFont,
        textStyle: base.copyWith(
          fontSize: base.fontSize == null
              ? null
              : base.fontSize! * wordmarkScale,
        ),
        fontWeight: wordmarkWeight,
        letterSpacing: wordmarkTracking,
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
