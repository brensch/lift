import '../gen/workout/v1/settings.pb.dart';

const double poundsPerKilogram = 2.2046226218;
const double kilogramsPerPound = 0.45359237;

double poundsToKilograms(double pounds) => pounds * kilogramsPerPound;
double kilogramsToPounds(double kilograms) => kilograms * poundsPerKilogram;

bool isMetricUnit(WeightUnit unit) => unit == WeightUnit.WEIGHT_UNIT_KG;

String weightUnitSuffix(WeightUnit unit) => isMetricUnit(unit) ? 'kg' : 'lb';

String weightUnitSuffixPlural(WeightUnit unit) =>
    isMetricUnit(unit) ? 'kg' : 'lbs';

double displayWeightFromPounds(double pounds, WeightUnit unit) =>
    isMetricUnit(unit) ? poundsToKilograms(pounds) : pounds;

double poundsFromDisplayWeight(double value, WeightUnit unit) =>
    isMetricUnit(unit) ? kilogramsToPounds(value) : value;

double snapDisplayWeight(
  double value,
  WeightUnit unit, {
  double poundStep = 5,
  double kilogramStep = 2.5,
}) {
  final step = isMetricUnit(unit) ? kilogramStep : poundStep;
  return (value / step).round() * step;
}

double snapPoundsForUnit(
  double pounds,
  WeightUnit unit, {
  double poundStep = 5,
  double kilogramStep = 2.5,
}) {
  final display = displayWeightFromPounds(pounds, unit);
  final snapped = snapDisplayWeight(
    display,
    unit,
    poundStep: poundStep,
    kilogramStep: kilogramStep,
  );
  return poundsFromDisplayWeight(snapped, unit);
}

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

double standardBarWeight(WeightUnit unit) => isMetricUnit(unit) ? 20 : 45;

List<double> standardPlates(WeightUnit unit) => isMetricUnit(unit)
    ? const [25, 20, 15, 10, 5, 2.5, 1.25]
    : const [45, 35, 25, 10, 5, 2.5];

/// The smallest increment you can actually add to a barbell: two of the
/// smallest available plate (one per side).
double barbellIncrement(WeightUnit unit) => standardPlates(unit).last * 2;
