import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/plate_visualization.dart';

const List<double> _plateWeights = [45, 35, 25, 10, 5, 2.5];

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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Plate colours saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PLATE COLOURS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        actions: [
          if (_dirty)
            TextButton(
              onPressed: _save,
              child: Text(
                'SAVE',
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
          // Preview
          Padding(
            padding: const EdgeInsets.all(16),
            child: PlateVisualization(
              weight: 290, // one of each plate per side: 45+35+25+10+5+2.5
              scale: 2.0,
              showText: false,
              isInteractive: false,
              colorOverrides: _colors,
            ),
          ),
          Divider(color: colorScheme.outline),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _plateWeights.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final weight = _plateWeights[index];
                final currentColor = _colors[weight] ?? Colors.purple;
                final label = weight % 1 == 0
                    ? '${weight.toInt()} lb'
                    : '${weight} lb';

                return Material(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: currentColor,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: colorScheme.outline,
                                  width: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              label.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _colorOptions.map((entry) {
                            final isSelected =
                                currentColor == entry.value;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _colors[weight] = entry.value;
                                  _dirty = true;
                                });
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: entry.value,
                                  borderRadius: BorderRadius.circular(6),
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
                      ],
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
}
