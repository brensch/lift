import 'package:flutter/material.dart';
import '../logic/plate_calculator.dart';

class PlateVisualization extends StatelessWidget {
  final double weight;
  final double scale;

  const PlateVisualization({
    super.key,
    required this.weight,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final result = calcPlatesPerSide(weight);
    if (result.plates.isEmpty) return const SizedBox.shrink();

    return Transform.scale(
      scale: scale,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Left Side Plates
          ...result.plates.reversed.map((plate) {
            final height = _plateHeight(plate);
            final color = _plateColor(plate);
            return Padding(
              padding: const EdgeInsets.only(left: 1),
              child: Container(
                width: 8,
                height: height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            );
          }),
          const SizedBox(width: 1),
          // Bar
          Container(
            width: 24,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 1),
          // Right Side Plates
          ...result.plates.map((plate) {
            final height = _plateHeight(plate);
            final color = _plateColor(plate);
            return Padding(
              padding: const EdgeInsets.only(right: 1),
              child: Container(
                width: 8,
                height: height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  double _plateHeight(double plate) {
    switch (plate) {
      case 45:
        return 32;
      case 25:
        return 28;
      case 10:
        return 22;
      case 5:
        return 18;
      case 2.5:
        return 12;
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
