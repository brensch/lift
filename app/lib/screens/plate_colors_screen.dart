import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import '../widgets/plate_visualization.dart';

const List<MapEntry<String, Color>> _colorOptions = [
  MapEntry('Red', Colors.red),
  MapEntry('Blue', Colors.blue),
  MapEntry('Green', Colors.green),
  MapEntry('Yellow', Color(0xFFFFEB3B)),
  MapEntry('Amber', Colors.amber),
  MapEntry('Orange', Colors.orange),
  MapEntry('Purple', Colors.purple),
  MapEntry('Pink', Colors.pink),
  MapEntry('Teal', Colors.teal),
  MapEntry('White', Color(0xFFE0E0E0)),
  MapEntry('Light Grey', Color(0xFFBDBDBD)),
  MapEntry('Grey', Colors.grey),
  MapEntry('Dark Grey', Color(0xFF616161)),
  MapEntry('Black', Color(0xFF212121)),
  MapEntry('Brown', Colors.brown),
];

class PlateColorsScreen extends StatefulWidget {
  const PlateColorsScreen({super.key});

  @override
  State<PlateColorsScreen> createState() => _PlateColorsScreenState();
}

class _PlateColorsScreenState extends State<PlateColorsScreen> {
  late Map<double, Color> _colors;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SettingsProvider>();
    _colors = Map.from(provider.plateColors);
  }

  void _save() {
    context.read<SettingsProvider>().updatePlateColors(_colors);
    setState(() => _dirty = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Plate colours saved')));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final plateWeights = standardPlates(unit);

    final previewPlatesPerSide = plateWeights;
    final contrivedWeight =
        standardBarWeight(unit) +
        previewPlatesPerSide.fold<double>(0, (sum, plate) => sum + plate * 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Plate colours',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        actions: [
          if (_dirty)
            TextButton(
              onPressed: _save,
              child: Text(
                'Save',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Center(
              child: PlateVisualization(
                weight: contrivedWeight,
                scale: 2.0,
                showText: false,
                isInteractive: false,
                colorOverrides: _colors,
                displayPlatesPerSide: previewPlatesPerSide,
              ),
            ),
          ),
          Divider(color: colorScheme.outline),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: plateWeights.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.0,
              ),
              itemBuilder: (context, index) {
                final weight = plateWeights[index];
                final currentColor = _colors[weight] ?? Colors.purple;
                final plateTextColor = currentColor.computeLuminance() > 0.55
                    ? Colors.black87
                    : Colors.white;
                return Material(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _showColorPicker(context, weight),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 94,
                              height: 94,
                              child: CustomPaint(
                                painter: _PlateRingPainter(
                                  color: currentColor,
                                  borderColor: colorScheme.outline,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 9,
                              child: Text(
                                weight % 1 == 0
                                    ? '${weight.toInt()}'
                                    : '$weight',
                                style: TextStyle(
                                  color: plateTextColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: weight >= 10 ? 12 : 11,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showColorPicker(BuildContext context, double weight) {
    final label = _plateLabel(weight);
    final colorScheme = Theme.of(context).colorScheme;

    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select a color for $label'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _colorOptions.map((option) {
            final isSelected = _colors[weight] == option.value;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _colors[weight] = option.value;
                  _dirty = true;
                });
                Navigator.pop(context);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: option.value,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.outline,
                    width: isSelected ? 3 : 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _plateLabel(double weight) =>
      '${weight % 1 == 0 ? weight.toInt() : weight} ${weightUnitSuffix(context.read<SettingsProvider>().weightUnit)}';
}

class _PlateRingPainter extends CustomPainter {
  const _PlateRingPainter({required this.color, required this.borderColor});

  final Color color;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerRadius = size.shortestSide / 2 - 2;
    final innerRadius = outerRadius * 0.32;

    final ringPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: center, radius: outerRadius))
      ..addOval(Rect.fromCircle(center: center, radius: innerRadius));

    canvas.drawShadow(ringPath, Colors.black.withValues(alpha: 0.2), 4, false);
    canvas.drawPath(ringPath, Paint()..color = color);

    canvas.drawCircle(
      center,
      outerRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = borderColor,
    );
    canvas.drawCircle(
      center,
      innerRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = borderColor.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _PlateRingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.borderColor != borderColor;
}
