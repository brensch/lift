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
    required this.headingBand,
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
    required this.resting,
    required this.yapping,
    required this.lifting,
    required this.short,
    required this.heart,
    required this.heartZones,
    required this.lightBackdrop,
    required this.barSteel,
    required this.sleeveSteel,
    required this.collarSteel,
    required this.plateEdge,
    required this.dumbbellPlate,
    required this.dumbbellHandle,
    required this.machine,
    required this.scrim,
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
    required this.fontScale,
    required this.radiusXs,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.size,
    required this.weight,
    required this.drawerRadius,
  });

  // ─── Neutrals ──────────────────────────────────────────────────────
  /// Page ground: scaffold, app bar, drawer.
  final Color background;

  /// Raised surfaces: cards, sheets, dialogs.
  final Color panel;

  /// Filled controls and wells on the ground (surfaceContainerHighest).
  final Color surfaceHigh;

  /// The band behind a section heading over full-width rows: darker than
  /// the ground the rows sit on, so a heading reads as one at a glance.
  final Color headingBand;
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

  /// The live workout states: lifting (counting up from Start), resting
  /// (blue countdown) and yapping (pink count-up).
  final Color resting;
  final Color yapping;
  final Color lifting;

  /// A set done with fewer reps than planned (amber).
  final Color short;

  /// Heart-rate icons.
  final Color heart;

  /// The heart-rate zones, Z1 (recovery) to Z5 (max).
  final List<Color> heartZones;

  // ─── Hardware: the drawn bars and dumbbells ────────────────────────
  /// The light ground the drawn bars and plates (and the invite QR code)
  /// sit on, so plate colours read the same whatever the page colour.
  final Color lightBackdrop;

  /// The bar between the plates in the inline drawing.
  final Color barSteel;

  /// The loading sleeves outside the plates.
  final Color sleeveSteel;

  /// The collars inside the plates.
  final Color collarSteel;

  /// The outline round each plate.
  final Color plateEdge;

  final Color dumbbellPlate;
  final Color dumbbellHandle;

  /// The equipment in a machine exercise's drawing.
  final Color machine;

  /// The shade over the screen around the tutorial's spotlight.
  final Color scrim;

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

  /// Multiplies the Material text theme's sizes (the text Material
  /// widgets draw for themselves, not [size]).
  final double fontScale;

  /// Every text size widgets draw at.
  final TypeScale size;

  /// Every font weight widgets draw at.
  final FontWeights weight;

  // ─── Shape ─────────────────────────────────────────────────────────
  /// The smallest corners: tags, swatches, chart labels.
  final double radiusXs;

  /// Chips, inputs, segmented controls, small buttons.
  final double radiusSm;

  /// Cards, primary call-to-action panels and every Material button.
  final double radiusMd;

  /// Large cards and selection panels.
  final double radiusLg;

  /// The largest panels.
  final double radiusXl;

  /// The side menu's open edge. 0 for a hard edge.
  final double drawerRadius;

  // ─── Derived ───────────────────────────────────────────────────────
  BorderRadius get brXs => BorderRadius.circular(radiusXs);
  BorderRadius get brSm => BorderRadius.circular(radiusSm);
  BorderRadius get brMd => BorderRadius.circular(radiusMd);
  BorderRadius get brLg => BorderRadius.circular(radiusLg);
  BorderRadius get brXl => BorderRadius.circular(radiusXl);

  /// Text that reads on [fill]: white on a dark fill, [text] on a light one.
  Color inkOn(Color fill) =>
      ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
      ? Colors.white
      : text;

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

  /// [base] in the mono font. For figures only: a weight, a count, a clock,
  /// a code. Words are always in the body font, whatever they label.
  TextStyle mono([TextStyle base = const TextStyle()]) =>
      GoogleFonts.getFont(monoFont, textStyle: base);

  /// A section's heading or a figure's label: small, bold, quiet words.
  /// Every heading band, metric label and row label is this, so they match.
  TextStyle label({Color? color}) => TextStyle(
    fontSize: size.body,
    fontWeight: weight.bold,
    color: color ?? muted,
  );

  // ThemeExtension plumbing. There is one spec, so nothing blends.
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
