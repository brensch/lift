import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/logic/starting_weights.dart';
import 'package:schlift/logic/weight_units.dart';

void main() {
  double lift(List<(Exercise, double)> w, Exercise ex) =>
      w.firstWhere((e) => e.$1 == ex).$2;

  test('slider preview matches the server seeds (src/onboarding.rs)', () {
    final w = startingWeightsLb(
      bodyweightKg: 0,
      strength: 0.5,
      unit: WeightUnit.WEIGHT_UNIT_LB,
    );
    expect(lift(w, Exercise.EXERCISE_SQUAT), 130);
    expect(lift(w, Exercise.EXERCISE_BENCH_PRESS), 85);
    expect(lift(w, Exercise.EXERCISE_DEADLIFT), 155);
    expect(lift(w, Exercise.EXERCISE_OVERHEAD_PRESS), 60);
    expect(lift(w, Exercise.EXERCISE_BARBELL_ROW), 90);
  });

  test(
    'chick never goes below the bar, gorilla is heavier, kg snaps to 2.5',
    () {
      final chick = startingWeightsLb(
        bodyweightKg: 50,
        strength: 0,
        unit: WeightUnit.WEIGHT_UNIT_KG,
      );
      for (final (_, lb) in chick) {
        expect(lb, greaterThanOrEqualTo(kilogramsToPounds(20) - 0.01));
        final kg = displayWeightFromPounds(lb, WeightUnit.WEIGHT_UNIT_KG);
        expect((kg * 10).round() % 25, 0, reason: 'loadable in kg: $kg');
      }
      final gorilla = startingWeightsLb(
        bodyweightKg: 100,
        strength: 1,
        unit: WeightUnit.WEIGHT_UNIT_LB,
      );
      expect(
        lift(gorilla, Exercise.EXERCISE_SQUAT),
        greaterThan(lift(chick, Exercise.EXERCISE_SQUAT)),
      );
      expect(strengthMultiplier(1 / 3), closeTo(0.85, 1e-6));
    },
  );
}
