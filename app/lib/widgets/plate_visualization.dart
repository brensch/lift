import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../gen/copy.dart';
import '../gen/workout/v1/settings.pb.dart' show WeightUnit;
import '../logic/plate_calculator.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import '../theme/theme_spec.dart';

/// The plates for each side of the bar at [weightLb] (stored pounds), in
/// loading order: "45 · 10 each side", or that the bar is empty.
String platesEachSide(double weightLb, WeightUnit unit) {
  final plates = calcPlatesPerSide(
    displayWeightFromPounds(weightLb, unit),
    unit,
  );
  if (plates.isEmpty) return copy.workout.emptyBar;
  return '${_platesCounted(plates).join(' · ')}  ${copy.plates.eachSide}';
}

/// Each plate size once, heaviest first; one loaded more than once says how
/// many: "45×2", "35", "5".
List<String> _platesCounted(List<double> plates) {
  final parts = <String>[];
  for (var i = 0; i < plates.length;) {
    var n = 1;
    while (i + n < plates.length && plates[i + n] == plates[i]) {
      n++;
    }
    parts.add(n > 1 ? '${plateLabel(plates[i])}×$n' : plateLabel(plates[i]));
    i += n;
  }
  return parts;
}

/// The load at [weightLb] (stored pounds) beside its weight: the end of the
/// bar with its plates, then the plates for each side as a list, one size
/// to a line, hard against the right. Its size never changes with the load
/// (room for the bar's fullest end and [lines] lines of the list), so
/// nothing around it moves as a slider runs through the weights.
class PlateSummary extends StatelessWidget {
  final double weightLb;

  /// The lines the list has room for. A load with more sizes than that
  /// puts the lightest ones together on the last line.
  static const lines = 4;
  static const double _lineHeight = 20;
  static const double height = lines * _lineHeight;

  const PlateSummary({super.key, required this.weightLb});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final plates = calcPlatesPerSide(
      displayWeightFromPounds(weightLb, unit),
      unit,
    );
    var sizes = plates.isEmpty
        ? [copy.workout.emptyBar]
        : _platesCounted(plates);
    if (sizes.length > lines) {
      sizes = [...sizes.take(lines - 1), sizes.skip(lines - 1).join(' · ')];
    }
    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The bar's end, in a slot as wide as its fullest: it grows
          // towards the list, not into the weight.
          SizedBox(
            width: 120,
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerRight,
                child: HalfBarbell(weightLb: weightLb, height: 58),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 52,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final size in sizes)
                  SizedBox(
                    height: _lineHeight,
                    child: Text(
                      size,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: t.mono(
                        TextStyle(
                          fontSize: t.size.body,
                          fontWeight: t.weight.bold,
                          color: t.text,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The plate calculator for [weightLb] (stored pounds): the whole bar as it
/// is loaded, on the light backdrop from edge to edge, and under it the
/// plates for each side in loading order.
class PlateBand extends StatelessWidget {
  final double weightLb;

  const PlateBand({super.key, required this.weightLb});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final settings = context.watch<SettingsProvider>();
    final unit = settings.weightUnit;
    final plates = calcPlatesPerSide(
      displayWeightFromPounds(weightLb, unit),
      unit,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 96,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: t.lightBackdrop,
            border: Border.symmetric(horizontal: BorderSide(color: t.outline)),
          ),
          child: FittedBox(
            child: BigBarbell(
              plates: plates,
              colorOf: settings.plateColor,
              heaviest: standardPlates(unit).first,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          // One line always, shrunk to fit.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              plates.isEmpty
                  ? copy.workout.emptyBar
                  : '${plates.map(plateLabel).join(' · ')}  '
                        '${copy.plates.eachSide}',
              maxLines: 1,
              softWrap: false,
              style: t.mono(
                TextStyle(
                  fontSize: t.size.body,
                  fontWeight: t.weight.bold,
                  color: t.muted,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A barbell drawn the way it looks loaded: the sleeve through the middle,
/// plates out from the collars, each as tall and thick as its weight makes
/// it relative to the heaviest plate.
class BigBarbell extends StatelessWidget {
  final List<double> plates;
  final Color Function(double plate) colorOf;
  final double heaviest;

  const BigBarbell({
    super.key,
    required this.plates,
    required this.colorOf,
    required this.heaviest,
  });

  static const double _fullHeight = 120;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget plate(double p) {
      final f = (p / heaviest).clamp(0.0, 1.0);
      return Container(
        width: 8 + 12 * f,
        height: _fullHeight * (0.32 + 0.68 * f),
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: colorOf(p),
          border: Border.all(color: t.plateEdge),
        ),
      );
    }

    final sleeve = Container(width: 24, height: 8, color: t.sleeveSteel);
    return SizedBox(
      height: _fullHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          sleeve,
          for (final p in plates.reversed) plate(p),
          // Collar, then the bar between the hands.
          Container(width: 10, height: 22, color: t.collarSteel),
          Container(width: 70, height: 6, color: t.muted),
          Container(width: 10, height: 22, color: t.collarSteel),
          for (final p in plates) plate(p),
          sleeve,
        ],
      ),
    );
  }
}

/// One end of the bar loaded for [weightLb] (stored pounds), as the app's
/// icon draws it: the plates stepping up from the lightest at the sleeve's
/// end to the heaviest against the collar, then the bar running on. Half a
/// barbell is all there is to load: the other end is the same. It sits
/// straight on whatever is behind it, with no box of its own.
class HalfBarbell extends StatelessWidget {
  final double weightLb;

  /// How tall the heaviest plate there is stands.
  final double height;

  /// Drawn the other way round: the bar running off to the left, the
  /// plates stepping down to the right.
  final bool mirrored;

  /// Past four plates, draw each thinner (down to half), so a heavy bar
  /// leaves room for what is beside it. The height never changes.
  final bool squeeze;

  const HalfBarbell({
    super.key,
    required this.weightLb,
    this.height = 40,
    this.mirrored = false,
    this.squeeze = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Rebuilds when the unit or the plate colours change.
    final settings = context.watch<SettingsProvider>();
    final unit = settings.weightUnit;
    final plates = calcPlatesPerSide(
      displayWeightFromPounds(weightLb, unit),
      unit,
    );
    final heaviest = standardPlates(unit).first;
    final steel = height * 0.07;
    final parts = <Widget>[
      // The sleeve's end, past the last plate.
      Container(width: height * 0.22, height: steel, color: t.barSteel),
      // Lightest outermost, as they go on: each as tall and as thick as
      // its weight makes it beside the heaviest plate.
      for (final plate in plates.reversed) ...[
        Builder(
          builder: (_) {
            final f = (plate / heaviest).clamp(0.0, 1.0);
            return Container(
              width:
                  height *
                  (0.07 + 0.09 * f) *
                  (squeeze && plates.length > 4
                      ? (4 / plates.length).clamp(0.5, 1.0)
                      : 1.0),
              height: height * (0.45 + 0.55 * f),
              color: settings.plateColor(plate),
            );
          },
        ),
        // A hair between plates, so two the same read as two.
        const SizedBox(width: 1),
      ],
      // The bar on its way to the other end.
      Container(width: height * 0.3, height: steel, color: t.barSteel),
    ];
    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: mirrored ? parts.reversed.toList() : parts,
      ),
    );
  }
}

/// The bar loaded for [weightLb] (stored pounds), small: inline wherever a
/// set's load is shown.
class PlateVisualization extends StatelessWidget {
  final double weightLb;

  const PlateVisualization({super.key, required this.weightLb});

  Color _plateColor(BuildContext context, double plate) =>
      context.read<SettingsProvider>().plateColor(plate);

  @override
  Widget build(BuildContext context) {
    // Rebuild when the plate colours change.
    context.watch<SettingsProvider>();
    final unit = context.read<SettingsProvider>().weightUnit;
    final weight = displayWeightFromPounds(weightLb, unit);
    final plates = calcPlatesPerSide(weight, unit);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: weight < standardBarWeight(unit)
          ? _buildDumbbell(context.tokens)
          : _buildBarbell(context, plates, unit),
    );
  }

  Widget _buildBarbell(
    BuildContext context,
    List<double> plates,
    WeightUnit unit,
  ) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Left side plates.
        ...plates.reversed.map((plate) {
          final width = inlinePlateWidth(plate, unit);
          final color = _plateColor(context, plate);
          return Padding(
            padding: const EdgeInsets.only(left: 1),
            child: Container(
              width: width,
              height: 32,
              decoration: BoxDecoration(color: color, borderRadius: t.brXs),
            ),
          );
        }),
        const SizedBox(width: 1),
        // Bar.
        Container(
          width: 24,
          height: 32,
          alignment: Alignment.center,
          child: Container(
            width: 24,
            height: 4,
            decoration: BoxDecoration(color: t.barSteel),
          ),
        ),
        const SizedBox(width: 1),
        // Right side plates.
        ...plates.map((plate) {
          final width = inlinePlateWidth(plate, unit);
          final color = _plateColor(context, plate);
          return Padding(
            padding: const EdgeInsets.only(right: 1),
            child: Container(
              width: width,
              height: 32,
              decoration: BoxDecoration(color: color, borderRadius: t.brXs),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDumbbell(ThemeSpec t) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 22,
          decoration: BoxDecoration(
            color: t.dumbbellPlate,
            borderRadius: t.brSm,
          ),
        ),
        Container(
          width: 18,
          height: 4,
          decoration: BoxDecoration(
            color: t.dumbbellHandle,
            borderRadius: t.brSm,
          ),
        ),
        Container(
          width: 7,
          height: 22,
          decoration: BoxDecoration(
            color: t.dumbbellPlate,
            borderRadius: t.brSm,
          ),
        ),
      ],
    );
  }
}

/// How thick [plate] (in [unit]) is drawn in [PlateVisualization]: by its
/// place among the unit's plates, heaviest thickest, so a 20 kg plate is
/// drawn like a 35 lb one.
double inlinePlateWidth(double plate, WeightUnit unit) {
  const widths = <double>[10, 9, 8, 6, 4, 2];
  final rank = standardPlates(unit).indexOf(plate);
  if (rank < 0) return 3;
  return widths[min(rank, widths.length - 1)];
}
