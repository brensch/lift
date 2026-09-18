import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/logic/starting_weights.dart';
import 'package:schlift/logic/weight_units.dart';

void main() {
  double lift(List<(Exercise, double)> w, Exercise ex) =>
      w.firstWhere((e) => e.$1 == ex).$2;

  test('slider preview matches the server seeds (src/onboarding.rs)', () {
    final w = startingWeightsLb(strength: 0.5, unit: WeightUnit.WEIGHT_UNIT_LB);
    expect(lift(w, Exercise.EXERCISE_SQUAT), 180);
    expect(lift(w, Exercise.EXERCISE_BENCH_PRESS), 130);
    expect(lift(w, Exercise.EXERCISE_DEADLIFT), 215);
    expect(lift(w, Exercise.EXERCISE_OVERHEAD_PRESS), 105);
    expect(lift(w, Exercise.EXERCISE_BARBELL_ROW), 145);
  });

  test('chick is the bar, gorilla is huge, kg snaps to the 2.5 kg grid', () {
    final chick = startingWeightsLb(
      strength: 0,
      unit: WeightUnit.WEIGHT_UNIT_LB,
    );
    expect(lift(chick, Exercise.EXERCISE_SQUAT), 45);
    expect(lift(chick, Exercise.EXERCISE_BENCH_PRESS), 35);
    final gorilla = startingWeightsLb(
      strength: 1,
      unit: WeightUnit.WEIGHT_UNIT_LB,
    );
    expect(lift(gorilla, Exercise.EXERCISE_SQUAT), 315);
    expect(lift(gorilla, Exercise.EXERCISE_BENCH_PRESS), 225);
    final kg = startingWeightsLb(
      strength: 0.5,
      unit: WeightUnit.WEIGHT_UNIT_KG,
    );
    expect(
      displayWeightFromPounds(
        lift(kg, Exercise.EXERCISE_SQUAT),
        WeightUnit.WEIGHT_UNIT_KG,
      ),
      closeTo(82.5, 0.01),
    );
  });
}
