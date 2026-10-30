import 'package:flutter/material.dart';
import '../widgets/common/flat.dart';
import 'package:provider/provider.dart';
import '../logic/weight_units.dart';
import '../providers/settings_provider.dart';
import '../widgets/plate_visualization.dart';
import '../theme/theme_spec.dart';

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

/// Plate colours: the bar loaded with one of every plate, then a row per
/// plate size with its colour swatches. A tap applies and saves.
class PlateColorsScreen extends StatelessWidget {
  const PlateColorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final settings = context.watch<SettingsProvider>();
    final unit = settings.weightUnit;
    final plates = standardPlates(unit);
    final suffix = weightUnitSuffix(unit);
    String num(double v) => v % 1 == 0 ? '${v.toInt()}' : '$v';
    String nameOf(Color c) => _colorOptions
        .firstWhere(
          (o) => o.value.toARGB32() == c.toARGB32(),
          orElse: () => MapEntry('Custom', c),
        )
        .key;

    void pick(double plate, Color color) {
      final colors = Map<double, Color>.from(settings.plateColors);
      colors[plate] = color;
      settings.updatePlateColors(colors);
    }

    return Scaffold(
      appBar: AppBar(title: const PageTitle('Plate colours')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // The bar with one of every plate on it.
          Container(
            height: 150,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: t.outline)),
            ),
            child: FittedBox(
              child: BigBarbell(
                plates: plates,
                colorOf: settings.plateColor,
                heaviest: plates.first,
              ),
            ),
          ),
          for (final plate in plates)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.hairline)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // The plate, edge on, as tall as its weight makes it.
                        Container(
                          width: 14,
                          height: 20 + 24 * (plate / plates.first),
                          decoration: BoxDecoration(
                            color: settings.plateColor(plate),
                            border: Border.all(color: t.outline),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          '${num(plate)} $suffix',
                          style: t.mono(
                            TextStyle(
                              fontSize: t.size.title,
                              fontWeight: t.weight.bold,
                              color: t.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          nameOf(settings.plateColor(plate)),
                          style: TextStyle(
                            fontSize: t.size.body,
                            color: t.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _colorOptions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final option = _colorOptions[i].value;
                        final chosen =
                            option.toARGB32() ==
                            settings.plateColor(plate).toARGB32();
                        return GestureDetector(
                          onTap: () => pick(plate, option),
                          child: Container(
                            width: 40,
                            decoration: BoxDecoration(
                              color: option,
                              border: Border.all(
                                color: chosen ? t.text : t.outline,
                                width: chosen ? 3 : 1,
                              ),
                            ),
                          ),
                        );
                      },
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
