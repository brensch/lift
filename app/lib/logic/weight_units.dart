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

// ─────────────────────────────────────────────────────────────────────────────
// Generic plate math — a straight port of src/weight_units.rs. Everything is
// generic over a bar + plate list (in the unit's own scale), so a third unit is
// just another entry in standardBarWeight/standardPlates. Weights are stored in
// pounds; snap in the display unit so the result is actually loadable, then
// convert back. Parity with Rust is pinned by testdata/warmup_golden.json.
// ─────────────────────────────────────────────────────────────────────────────

/// Collapse f64 representation noise so this matches the Rust f32 maths at
/// `.5` rounding boundaries (see the note in warmup.dart).
double _snap6(double value) => (value * 1e6).roundToDouble() / 1e6;

/// The finest total weight you can add to the bar: two of the smallest plate.
double loadableStep(List<double> plates) => plates.last * 2;

/// Greedy heaviest-first plates for ONE side, plus any un-loadable remainder.
/// Mirrors Rust `plates_per_side`.
({List<double> plates, double remainder}) platesForSide(
    double weight, double bar, List<double> plates) {
  if (weight <= bar) return (plates: const [], remainder: 0.0);
  var remaining = (weight - bar) / 2;
  final out = <double>[];
  for (final p in plates) {
    while (remaining + 1e-4 >= p) {
      out.add(p);
      remaining -= p;
    }
  }
  return (plates: out, remainder: remaining < 0 ? 0.0 : remaining);
}

/// Plates per side for an exactly-loadable weight; `infinity` if it can't be
/// loaded (so it's never chosen as "simplest"). Mirrors Rust.
double plateCountPerSide(double weight, double bar, List<double> plates) {
  final r = platesForSide(weight, bar, plates);
  return r.remainder > 1e-3 ? double.infinity : r.plates.length.toDouble();
}

/// Nearest weight to [target] exactly loadable on [bar] from [plates].
double snapLoadable(double target, double bar, List<double> plates) {
  final step = loadableStep(plates);
  if (target < bar) {
    final grid = plates.last;
    final v = _snap6(target / grid).round() * grid;
    return v < 0 ? 0.0 : v;
  }
  return bar + _snap6((target - bar) / step).round() * step;
}

/// Lexicographic "is a strictly better warmup candidate": fewer plates, then
/// closer to target, then lighter. Mirrors Rust `candidate_is_better`.
bool _candidateIsBetter(
    (double, double, double) a, (double, double, double) b) {
  if (a.$1 != b.$1) return a.$1 < b.$1;
  if ((a.$2 - b.$2).abs() > 1e-6) return a.$2 < b.$2;
  return a.$3 < b.$3;
}

/// A loadable weight near [target] (within one loadable step) using the fewest
/// plates per side — opts for one big plate over several small. Mirrors Rust
/// `simplest_loadable_near`.
double simplestLoadableNear(
    double target, double bar, List<double> plates, double min, double max) {
  final step = loadableStep(plates);
  final base = snapLoadable(target, bar, plates).clamp(min, max).toDouble();
  var best = base;
  var bestKey = (
    plateCountPerSide(base, bar, plates),
    (base - target).abs(),
    base,
  );
  for (final delta in [-step, step]) {
    var cand = base + delta;
    if (cand < min - 1e-4 || cand > max + 1e-4) continue;
    cand = cand.clamp(min, max).toDouble();
    final key = (
      plateCountPerSide(cand, bar, plates),
      (cand - target).abs(),
      cand,
    );
    if (_candidateIsBetter(key, bestKey)) {
      best = cand;
      bestKey = key;
    }
  }
  return best;
}

/// Snap a stored pound weight to the nearest weight that's exactly loadable in
/// the display [unit], returned in pounds. `display(this)` is always clean.
double snapLoadableLb(double weightLb, WeightUnit unit) {
  final display = displayWeightFromPounds(weightLb, unit);
  final snapped =
      snapLoadable(display, standardBarWeight(unit), standardPlates(unit));
  return poundsFromDisplayWeight(snapped, unit);
}
