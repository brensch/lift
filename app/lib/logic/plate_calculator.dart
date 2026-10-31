import '../gen/workout/v1/settings.pb.dart';
import 'weight_units.dart';

class PlateResult {
  final List<double> plates;
  final double remainder;

  PlateResult(this.plates, this.remainder);
}

// Weights stored in pounds come back to kg a hair under the real weight;
// a plate counts if it fits within this.
const _plateSlack = 1e-3;

PlateResult calcPlatesPerSide(double totalWeight, WeightUnit unit) {
  final barWeight = standardBarWeight(unit);
  final availablePlates = standardPlates(unit);
  if (totalWeight <= barWeight + _plateSlack) return PlateResult([], 0);

  double remaining = (totalWeight - barWeight) / 2;
  final plates = <double>[];

  for (final plate in availablePlates) {
    while (remaining >= plate - _plateSlack) {
      plates.add(plate);
      remaining -= plate;
    }
  }

  return PlateResult(plates, remaining < 0 ? 0 : remaining);
}
