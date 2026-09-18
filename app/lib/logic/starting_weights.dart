/// The first working weights for the main lifts, from the setup slider
/// (chick 0 .. gorilla 1). A mirror of src/onboarding.rs: the slider shows
/// these numbers and the server seeds the same ones, and
/// test/logic/starting_weights_test.dart pins both to the same values.
library;

import '../gen/workout/v1/settings.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import 'weight_units.dart';

/// (exercise, chick lb, gorilla lb): the bar (a little under for bench)
/// up to truly huge. Linear between.
const List<(Exercise, double, double)> strengthRangeLb = [
  (Exercise.EXERCISE_SQUAT, 45, 315),
  (Exercise.EXERCISE_BENCH_PRESS, 35, 225),
  (Exercise.EXERCISE_BARBELL_ROW, 45, 245),
  (Exercise.EXERCISE_OVERHEAD_PRESS, 45, 165),
  (Exercise.EXERCISE_DEADLIFT, 45, 385),
];

/// Snapped to what fits on a bar in [unit]: the bar plus whole pairs of
/// the smallest plate; under the bar, the smallest plate's grid.
double _snapBarbellLb(double lb, WeightUnit unit) {
  final bar = standardBarWeight(unit);
  final step = barbellIncrement(unit);
  final display = displayWeightFromPounds(lb, unit);
  final double snapped;
  if (display < bar) {
    final grid = step / 2;
    snapped = ((display / grid).round() * grid).clamp(0, double.infinity);
  } else {
    snapped = bar + ((display - bar) / step).round() * step;
  }
  return poundsFromDisplayWeight(snapped, unit);
}

/// Seeds in pounds, in [strengthRangeLb] order.
List<(Exercise, double)> startingWeightsLb({
  required double strength,
  required WeightUnit unit,
}) {
  final s = strength.clamp(0.0, 1.0);
  return [
    for (final (exercise, lo, hi) in strengthRangeLb)
      (exercise, _snapBarbellLb(lo + (hi - lo) * s, unit)),
  ];
}
