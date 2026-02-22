class PlateResult {
  final List<double> plates;
  final double remainder;

  PlateResult(this.plates, this.remainder);
}

const double barWeight = 45;
const List<double> availablePlates = [45, 35, 25, 10, 5, 2.5];

PlateResult calcPlatesPerSide(double totalWeight) {
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
