import '../gen/workout/v1/settings.pb.dart';

const double poundsPerKilogram = 2.2046226218;
const double kilogramsPerPound = 0.45359237;

double poundsToKilograms(double pounds) => pounds * kilogramsPerPound;
double kilogramsToPounds(double kilograms) => kilograms * poundsPerKilogram;

bool isMetricUnit(WeightUnit unit) => unit == WeightUnit.WEIGHT_UNIT_KG;

String weightUnitSuffix(WeightUnit unit) => isMetricUnit(unit) ? 'kg' : 'lb';

double displayWeightFromPounds(double pounds, WeightUnit unit) =>
    isMetricUnit(unit) ? poundsToKilograms(pounds) : pounds;

double poundsFromDisplayWeight(double value, WeightUnit unit) =>
    isMetricUnit(unit) ? kilogramsToPounds(value) : value;

String formatWeight(
  double pounds,
  WeightUnit unit, {
  bool includeUnit = false,
}) {
  final display = displayWeightFromPounds(pounds, unit);
  final rounded = display.toStringAsFixed(display % 1 == 0 ? 0 : 1);
  if (!includeUnit) return rounded;
  return '$rounded ${weightUnitSuffix(unit)}';
}

/// A plate or bar as its weight is printed on it: "20", "2.5".
String plateLabel(double weight) =>
    weight % 1 == 0 ? '${weight.toInt()}' : '$weight';

double standardBarWeight(WeightUnit unit) => isMetricUnit(unit) ? 20 : 45;

List<double> standardPlates(WeightUnit unit) => isMetricUnit(unit)
    ? const [25, 20, 15, 10, 5, 2.5, 1.25]
    : const [45, 35, 25, 10, 5, 2.5];

/// Exactly the bar, no plates — in [unit], from a stored pound weight.
bool isEmptyBar(double pounds, WeightUnit unit) =>
    (displayWeightFromPounds(pounds, unit) - standardBarWeight(unit)).abs() <
    0.05;

/// A total lifted, short: "940", "1.5k", "12k", "1.2M" — in the user's
/// unit, from stored pounds.
String compactVolume(double pounds, WeightUnit unit) {
  final v = displayWeightFromPounds(pounds, unit);
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k';
  return v.round().toString();
}

/// A weight as typed: "62.5", or "62,5" from a decimal-comma keypad. Null
/// when blank or not a number.
double? parseDisplayWeight(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));
