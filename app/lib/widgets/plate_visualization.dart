import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/plate_calculator.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_spec.dart';
import 'common/flat.dart';

/// What to load for [weight]: a flat sheet with the total, the bar drawn
/// big with each plate sized like the real thing, and the plates for each
/// side listed in loading order.
Future<void> showPlateBreakdownDialog(
  BuildContext context, {
  required double weight,
  Map<double, Color>? colorOverrides,
  List<double>? displayPlatesPerSide,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _PlateSheet(
      weight: weight,
      colorOverrides: colorOverrides,
      displayPlatesPerSide: displayPlatesPerSide,
    ),
  );
}

class _PlateSheet extends StatelessWidget {
  final double weight;
  final Map<double, Color>? colorOverrides;
  final List<double>? displayPlatesPerSide;

  const _PlateSheet({
    required this.weight,
    this.colorOverrides,
    this.displayPlatesPerSide,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final settings = context.watch<SettingsProvider>();
    final unit = settings.weightUnit;
    final suffix = weightUnitSuffix(unit);
    final barWeight = standardBarWeight(unit);
    final plates =
        displayPlatesPerSide ?? calcPlatesPerSide(weight, unit).plates;
    Color colorOf(double plate) => colorOverrides != null
        ? (colorOverrides![plate] ?? Colors.purple)
        : settings.plateColor(plate);
    String num(double v) => v % 1 == 0 ? v.toInt().toString() : '$v';

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
        ? 'None'
        : '${num(perSide)} $suffix';
    final barText = weight < barWeight
        ? 'Dumbbells'
        : '${num(barWeight)} $suffix';

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
                column('Plates', plateText, 'each side'),
                column('Bar', barText, null),
                column(
                  'Total',
                  '${formatWeight(weight, unit)} $suffix',
                  null,
                  last: true,
                ),
              ],
            ),
          ),
          // The bar, big, on white.
          Container(
            height: 150,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.symmetric(
                horizontal: BorderSide(color: t.outline),
              ),
            ),
            child: FittedBox(
              child: _BigBarbell(
                plates: plates,
                colorOf: colorOf,
                heaviest: standardPlates(unit).first,
              ),
            ),
          ),
          if (sizes.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: const SectionLabel('Each side, in loading order'),
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
                        '${num(size)} $suffix',
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
class _BigBarbell extends StatelessWidget {
  final List<double> plates;
  final Color Function(double plate) colorOf;
  final double heaviest;

  const _BigBarbell({
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
          border: Border.all(color: Colors.black.withValues(alpha: 0.35)),
        ),
      );
    }

    final sleeve = Container(width: 24, height: 8, color: Colors.grey.shade500);
    return SizedBox(
      height: _fullHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          sleeve,
          for (final p in plates.reversed) plate(p),
          // Collar, then the bar between the hands.
          Container(width: 10, height: 22, color: Colors.grey.shade700),
          Container(width: 70, height: 6, color: t.muted),
          Container(width: 10, height: 22, color: Colors.grey.shade700),
          for (final p in plates) plate(p),
          sleeve,
        ],
      ),
    );
  }
}

class PlateVisualization extends StatelessWidget {
  final double weight;
  final double scale;
  final bool showText;
  final bool isInteractive;
  final Map<double, Color>? colorOverrides;
  final List<double>? displayPlatesPerSide;

  const PlateVisualization({
    super.key,
    required this.weight,
    this.scale = 1.0,
    this.showText = false,
    this.isInteractive = true,
    this.colorOverrides,
    this.displayPlatesPerSide,
  });

  Color _plateColor(BuildContext context, double plate) {
    if (colorOverrides != null) {
      return colorOverrides![plate] ?? Colors.purple;
    }
    return context.read<SettingsProvider>().plateColor(plate);
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider so we rebuild when colors change (unless overrides given)
    if (colorOverrides == null) {
      context.watch<SettingsProvider>();
    }

    final unit = context.read<SettingsProvider>().weightUnit;
    final result = calcPlatesPerSide(weight, unit);
    final platesForDisplay = displayPlatesPerSide ?? result.plates;
    final barWeight = standardBarWeight(unit);
    final isDumbbellWeight = weight < barWeight;
    final isBarOnly = weight == barWeight;

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Transform.scale(
            scale: scale,
            child: isDumbbellWeight
                ? _buildDumbbell()
                : _buildBarbell(context, platesForDisplay),
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              if (isDumbbellWeight) {
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Dumbbell setup',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: context.tokens.size.subtitle,
                      fontWeight: context.tokens.weight.heavy,
                      color: Colors.grey.shade600,
                      height: 1.8,
                      letterSpacing: 0.5,
                    ),
                  ),
                );
              }
              if (isBarOnly) {
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Bar only',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: context.tokens.size.subtitle,
                      fontWeight: context.tokens.weight.heavy,
                      color: Colors.grey.shade600,
                      height: 1.8,
                      letterSpacing: 0.5,
                    ),
                  ),
                );
              }
              final Map<double, int> plateCounts = {};
              for (var p in platesForDisplay) {
                plateCounts[p] = (plateCounts[p] ?? 0) + 1;
              }
              final plateDescription = plateCounts.entries
                  .map(
                    (e) =>
                        '${e.key % 1 == 0 ? e.key.toInt() : e.key} × ${e.value}',
                  )
                  .join('\n');
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Each side:\n$plateDescription',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: context.tokens.size.subtitle,
                    fontWeight: context.tokens.weight.heavy,
                    color: Colors.grey.shade600,
                    height: 1.8,
                    letterSpacing: 0.5,
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );

    if (isInteractive) {
      final colorScheme = Theme.of(context).colorScheme;
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Material(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => showPlateBreakdownDialog(
              context,
              weight: weight,
              colorOverrides: colorOverrides,
              displayPlatesPerSide: displayPlatesPerSide,
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: content,
            ),
          ),
        ),
      );
    }

    return content;
  }

  Widget _buildBarbell(BuildContext context, List<double> plates) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Left side plates.
        ...plates.reversed.map((plate) {
          final width = _plateWidth(plate);
          final color = _plateColor(context, plate);
          return Padding(
            padding: const EdgeInsets.only(left: 1),
            child: Container(
              width: width,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1),
              ),
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
            decoration: BoxDecoration(color: Colors.grey.shade400),
          ),
        ),
        const SizedBox(width: 1),
        // Right side plates.
        ...plates.map((plate) {
          final width = _plateWidth(plate);
          final color = _plateColor(context, plate);
          return Padding(
            padding: const EdgeInsets.only(right: 1),
            child: Container(
              width: width,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDumbbell() {
    const plateColor = Color(0xFF6B7280);
    const handleColor = Color(0xFF111827);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 22,
          decoration: BoxDecoration(
            color: plateColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Container(
          width: 18,
          height: 4,
          decoration: BoxDecoration(
            color: handleColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Container(
          width: 7,
          height: 22,
          decoration: BoxDecoration(
            color: plateColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  double _plateWidth(double plate) {
    switch (plate) {
      case 45:
        return 10;
      case 35:
        return 9;
      case 25:
        return 8;
      case 10:
        return 6;
      case 5:
        return 4;
      case 2.5:
        return 2;
      default:
        return 3;
    }
  }
}
