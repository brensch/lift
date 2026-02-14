import 'package:flutter/material.dart';
import '../logic/plate_calculator.dart';

class PlateVisualization extends StatelessWidget {
  final double weight;

  const PlateVisualization({super.key, required this.weight});

  @override
  Widget build(BuildContext context) {
    final result = calcPlatesPerSide(weight);
    if (result.plates.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bar
        Container(
          width: 4,
          height: 16,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: 1),
        // Plates
        ...result.plates.map((plate) {
          final height = _plateHeight(plate);
          final color = _plateColor(plate);
          return Padding(
            padding: const EdgeInsets.only(right: 1),
            child: Container(
              width: 6,
              height: height,
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

  double _plateHeight(double plate) {
    switch (plate) {
      case 45:
        return 24;
      case 25:
        return 20;
      case 10:
        return 16;
      case 5:
        return 12;
      case 2.5:
        return 8;
      default:
        return 14;
    }
  }

  Color _plateColor(double plate) {
    switch (plate) {
      case 45:
        return Colors.blue;
      case 25:
        return Colors.green;
      case 10:
        return Colors.amber;
      case 5:
        return Colors.red;
      case 2.5:
        return Colors.grey;
      default:
        return Colors.purple;
    }
  }
}
