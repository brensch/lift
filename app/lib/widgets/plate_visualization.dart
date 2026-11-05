import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../gen/copy.dart';
import '../gen/workout/v1/settings.pb.dart' show WeightUnit;
import '../logic/plate_calculator.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_spec.dart';
import 'common/flat.dart';

/// What to load for [weightLb] (stored pounds): a flat sheet with the total, the bar drawn
/// big with each plate sized like the real thing, and the plates for each
/// side listed in loading order.
Future<void> showPlateBreakdownDialog(
  BuildContext context, {
  required double weightLb,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _PlateSheet(weightLb: weightLb),
  );
}

class _PlateSheet extends StatelessWidget {
  final double weightLb;

  const _PlateSheet({required this.weightLb});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final settings = context.watch<SettingsProvider>();
    final unit = settings.weightUnit;
    final suffix = weightUnitSuffix(unit);
    final barWeight = standardBarWeight(unit);
    // Plates are counted in the user's unit, from the stored pounds.
    final weight = displayWeightFromPounds(weightLb, unit);
    final plates = calcPlatesPerSide(weight, unit);
    final colorOf = settings.plateColor;

    // Each plate size once, heaviest (loaded first) first, with its count.
    final counts = <double, int>{};
    for (final p in plates) {
      counts[p] = (counts[p] ?? 0) + 1;
    }
    final sizes = counts.keys.toList()..sort((a, b) => b.compareTo(a));

    final perSide = plates.fold<double>(0, (a, p) => a + p);
    final plateText = weight < barWeight
        ? '—'
        : plates.isEmpty
        ? copy.plates.none
        : '${plateLabel(perSide)} $suffix';
    final barText = weight < barWeight
        ? copy.plates.dumbbells
        : '${plateLabel(barWeight)} $suffix';

    Widget column(
      String label,
      String value,
      String? note, {
      bool last = false,
    }) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 14),
        decoration: BoxDecoration(
          border: Border(
            right: last ? BorderSide.none : BorderSide(color: t.hairline),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: t.mono(
                  TextStyle(
                    fontSize: t.size.headline,
                    fontWeight: t.weight.bold,
                    color: t.text,
                    height: 1.1,
                  ),
                ),
              ),
            ),
            if (note != null)
              Text(
                note,
                style: TextStyle(fontSize: t.size.small, color: t.muted),
              ),
          ],
        ),
      ),
    );

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTheme.sheetHandle(context, gap: 0),
          // Plates (each side), bar, total: three columns split by
          // hairlines.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                column(
                  copy.plates.plates,
                  plateText,
                  copy.plates.eachSide,
                ),
                column(copy.plates.bar, barText, null),
                column(
                  copy.plates.total,
                  formatWeight(weightLb, unit, includeUnit: true),
                  null,
                  last: true,
                ),
              ],
            ),
          ),
          // The bar, big, on the light backdrop.
          Container(
            height: 150,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: t.lightBackdrop,
              border: Border.symmetric(
                horizontal: BorderSide(color: t.outline),
              ),
            ),
            child: FittedBox(
              child: BigBarbell(
                plates: plates,
                colorOf: colorOf,
                heaviest: standardPlates(unit).first,
              ),
            ),
          ),
          if (sizes.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: FlatHeading(copy.plates.loadingOrder),
            ),
            for (final size in sizes)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: t.hairline)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: colorOf(size),
                        border: Border.all(color: t.outline),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        '${plateLabel(size)} $suffix',
                        style: t.mono(
                          TextStyle(
                            fontSize: t.size.title,
                            fontWeight: t.weight.bold,
                            color: t.text,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '× ${counts[size]}',
                      style: t.mono(
                        TextStyle(
                          fontSize: t.size.title,
                          fontWeight: t.weight.bold,
                          color: t.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 16),
        ],
      ),
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
