import '../gen/workout/v1/settings.pb.dart';
import 'weight_units.dart';

class PlateResult {
  final List<double> plates;
  final double remainder;

  PlateResult(this.plates, this.remainder);
}

PlateResult calcPlatesPerSide(double totalWeight, WeightUnit unit) {
  final barWeight = standardBarWeight(unit);
  final availablePlates = standardPlates(unit);
  if (totalWeight <= barWeight) return PlateResult([], 0);

  double remaining = (totalWeight - barWeight) / 2;
  final plates = <double>[];

  for (final plate in availablePlates) {
    while (remaining >= plate) {
      plates.add(plate);
      remaining -= plate;
    }
  }

  return PlateResult(plates, remaining);
}
