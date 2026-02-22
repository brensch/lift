import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/plate_calculator.dart';
import '../providers/settings_provider.dart';

class PlateVisualization extends StatelessWidget {
  final double weight;
  final double scale;
  final bool showText;
  final bool isInteractive;
  final Map<double, Color>? colorOverrides;

  const PlateVisualization({
    super.key,
    required this.weight,
    this.scale = 1.0,
    this.showText = false,
    this.isInteractive = true,
    this.colorOverrides,
  });

  void _showDetailModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${weight.toInt()} LB BREAKDOWN',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            PlateVisualization(
              weight: weight,
              scale: 2.0,
              showText: true,
              isInteractive: false,
            ),
            const SizedBox(height: 20),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

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

    final result = calcPlatesPerSide(weight);
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
                : _buildBarbell(context, result.plates),
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
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
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
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey.shade600,
                      height: 1.8,
                      letterSpacing: 0.5,
                    ),
                  ),
                );
              }
              final Map<double, int> plateCounts = {};
              for (var p in result.plates) {
                plateCounts[p] = (plateCounts[p] ?? 0) + 1;
              }
              final plateDescription = plateCounts.entries
                  .map(
                    (e) =>
                        '${e.key % 1 == 0 ? e.key.toInt() : e.key} x ${e.value}',
                  )
                  .join('\n');
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Each side:\n$plateDescription',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
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
            onTap: () => _showDetailModal(context),
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
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
            ),
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
