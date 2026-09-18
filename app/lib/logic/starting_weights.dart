/// The first working weights for the main lifts, from the setup slider
/// (chick 0 .. gorilla 1) and bodyweight. A mirror of src/onboarding.rs:
/// the slider shows these numbers and the server seeds the same ones, and
/// test/logic/starting_weights_test.dart pins both to the same values.
library;

import '../gen/workout/v1/settings.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import 'weight_units.dart';

/// What a blank bodyweight seeds from.
const double averageBodyweightKg = 75;

/// (exercise, fraction of bodyweight) for a sane first working weight.
const List<(Exercise, double)> startingRatios = [
  (Exercise.EXERCISE_SQUAT, 0.95),
  (Exercise.EXERCISE_BENCH_PRESS, 0.70),
  (Exercise.EXERCISE_BARBELL_ROW, 0.75),
  (Exercise.EXERCISE_OVERHEAD_PRESS, 0.50),
  (Exercise.EXERCISE_DEADLIFT, 1.15),
];

/// Chick to gorilla through the old four levels' multipliers.
double strengthMultiplier(double strength) {
  const stops = [0.40, 0.85, 1.0, 1.15];
  final s = strength.clamp(0.0, 1.0) * 3.0;
  final i = s.floor().clamp(0, 2);
  final t = s - i;
  return stops[i] + (stops[i + 1] - stops[i]) * t;
}

/// No gender question any more: the "unspecified" multipliers, which sit
/// between the population averages so nobody gets a bar they can't lift.
double _bodyPartMultiplier(Exercise ex) {
  const upper = {
    Exercise.EXERCISE_BENCH_PRESS,
    Exercise.EXERCISE_OVERHEAD_PRESS,
    Exercise.EXERCISE_BARBELL_ROW,
  };
  return upper.contains(ex) ? 0.80 : 0.88;
}

/// Snapped to what fits on a bar in [unit], never below the bar.
double _snapBarbellLb(double lb, WeightUnit unit) {
  final bar = standardBarWeight(unit);
  final step = barbellIncrement(unit);
  final display = displayWeightFromPounds(lb, unit);
  final snapped = display < bar
      ? bar
      : bar + ((display - bar) / step).round() * step;
  return poundsFromDisplayWeight(snapped, unit);
}

/// Seeds in pounds, in [startingRatios] order.
List<(Exercise, double)> startingWeightsLb({
  required double bodyweightKg,
  required double strength,
  required WeightUnit unit,
}) {
  final bodyweight = bodyweightKg > 0 ? bodyweightKg : averageBodyweightKg;
  final multiplier = strengthMultiplier(strength);
  return [
    for (final (exercise, ratio) in startingRatios)
      (
        exercise,
        _snapBarbellLb(
          kilogramsToPounds(bodyweight) *
              ratio *
              multiplier *
              _bodyPartMultiplier(exercise),
          unit,
        ),
      ),
  ];
}
