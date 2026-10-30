/// Pins the Dart catalog mirror to src/exercise_catalog.rs and the
/// calibration maths to src/workout/planning.rs. The numbers here are the
/// ones the Rust tests assert; a change on either side must land on both.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/logic/exercise_prescription.dart';
import 'package:schlift/logic/exercises.dart';

void main() {
  const lb = WeightUnit.WEIGHT_UNIT_LB;
  const kg = WeightUnit.WEIGHT_UNIT_KG;

  test('every catalogue exercise is classified exactly once', () {
    final catalogue = exerciseCatalog.map((e) => e.exercise).toSet();
    expect(
      classifiedExercises,
      catalogue,
      reason:
          'the five load classes partition the catalogue, as the '
          'exhaustive Rust match does',
    );
  });

  test('prescriptions follow the class', () {
    final squat = prescriptionFor(Exercise.EXERCISE_SQUAT);
    expect((squat.sets, squat.repLow, squat.repHigh), (3, 6, 10));
    expect((squat.restSeconds, squat.restSecondsFailure), (180, 240));
    expect(squat.includeWarmup, isTrue);

    final bench = prescriptionFor(Exercise.EXERCISE_BENCH_PRESS);
    expect((bench.restSeconds, bench.restSecondsFailure), (150, 210));

    final pushUp = prescriptionFor(Exercise.EXERCISE_PUSH_UP);
    expect((pushUp.sets, pushUp.repLow, pushUp.repHigh), (3, 5, 15));
    expect((pushUp.restSeconds, pushUp.restSecondsFailure), (120, 180));

    final dbRow = prescriptionFor(Exercise.EXERCISE_DUMBBELL_ROW);
    expect((dbRow.sets, dbRow.repLow, dbRow.repHigh), (3, 8, 12));

    final curl = prescriptionFor(Exercise.EXERCISE_DUMBBELL_CURL);
    expect((curl.sets, curl.repLow, curl.repHigh), (3, 10, 15));
    expect((curl.restSeconds, curl.restSecondsFailure), (90, 120));

    final plank = prescriptionFor(Exercise.EXERCISE_PLANK);
    expect((plank.sets, plank.repLow, plank.repHigh), (3, 10, 20));
    expect((plank.restSeconds, plank.restSecondsFailure), (60, 90));
  });

  test('the next rung is the larger of a step and ten percent, snapped', () {
    expect(nextCalibrationWeight(Exercise.EXERCISE_SQUAT, 45, lb), 50);
    expect(nextCalibrationWeight(Exercise.EXERCISE_SQUAT, 200, lb), 220);
    // 20 kg bar in kilograms: 22.5 kg is the next loadable rung.
    final barKg = startingWeightLb(Exercise.EXERCISE_SQUAT, kg);
    final next = nextCalibrationWeight(Exercise.EXERCISE_SQUAT, barKg, kg);
    expect((next * 0.45359237).toStringAsFixed(2), '22.50');
    // A dumbbell climbs by its own step.
    expect(nextCalibrationWeight(Exercise.EXERCISE_DUMBBELL_CURL, 20, lb), 25);
    // Bodyweight has no step and never calibrates.
    expect(progressionIncrementLb(Exercise.EXERCISE_PUSH_UP, lb), 0);
  });

  test('the ramp starts at 60% of the seed, never under the opener', () {
    expect(
      calibrationStartWeight(
        Exercise.EXERCISE_BENCH_PRESS,
        seedWeightLb: 135,
        performedBefore: false,
        unit: lb,
      ),
      80,
    );
    expect(
      calibrationStartWeight(
        Exercise.EXERCISE_SQUAT,
        seedWeightLb: 45,
        performedBefore: false,
        unit: lb,
      ),
      45,
      reason: 'the resolved opener seeds back to the opener',
    );
    expect(
      calibrationStartWeight(
        Exercise.EXERCISE_SQUAT,
        seedWeightLb: 185,
        performedBefore: true,
        unit: lb,
      ),
      isNull,
      reason: 'performed before: no ramp',
    );
    expect(
      calibrationStartWeight(
        Exercise.EXERCISE_PUSH_UP,
        seedWeightLb: 0,
        performedBefore: false,
        unit: lb,
      ),
      isNull,
      reason: 'bodyweight never calibrates',
    );
  });

  test('appended set ids are v5 over the OID namespace of "{id}:{n}"', () {
    // Pinned to python3: uuid.uuid5(uuid.NAMESPACE_OID, 'abc:0') and ':1'.
    // The Rust reducer mints the same ids, so both sides must agree here.
    expect(appendedSetId('abc', 0), '7b50f659-f399-59e9-b2fb-3d074b70a57d');
    expect(appendedSetId('abc', 1), 'daed2c28-a845-56a0-aff5-fb7f9e5f92f3');
    // The typed-weight path keys on the pending rung: uuid5(OID, 'r1:0').
    expect(appendedSetId('r1', 0), '0c571b2f-6816-54fa-a80e-f20800527fa9');
  });

  test('working sets after calibration follow the prescription', () {
    var n = 0;
    final sets = workingSetsAfterCalibration(
      workoutId: 'w1',
      exercise: Exercise.EXERCISE_SQUAT,
      weightLb: 95,
      newId: () => 'id-${n++}',
    );
    expect(sets, hasLength(2), reason: 'three prescribed, the rung counts');
    for (final set in sets) {
      expect(set.targetWeight, 95);
      expect(set.targetReps, 6);
      expect((set.restAfterSuccess, set.restAfterFailure), (180, 240));
      expect(set.warmup, isFalse);
      expect(set.calibration, isFalse);
    }
    expect(sets.map((s) => s.id), ['id-0', 'id-1']);
  });
}
