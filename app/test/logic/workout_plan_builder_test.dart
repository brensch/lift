import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/settings.pb.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/logic/workout_plan_builder.dart';

ExerciseTypeConfig config(
  Exercise exercise, {
  double weight = 100,
  int reps = 5,
  required bool includeWarmup,
}) {
  return ExerciseTypeConfig()
    ..exercise = exercise
    ..startWeight = weight
    ..endWeight = weight
    ..reps = reps
    ..includeWarmup = includeWarmup;
}

void main() {
  group('warmupPlanFromConfigs', () {
    test('names the exercises that asked for warmups', () {
      final plan = warmupPlanFromConfigs([
        config(Exercise.EXERCISE_SQUAT, includeWarmup: true),
        config(Exercise.EXERCISE_LATERAL_RAISE, includeWarmup: false),
        config(Exercise.EXERCISE_BENCH_PRESS, includeWarmup: true),
      ]);

      expect(plan.exercises, [
        Exercise.EXERCISE_SQUAT,
        Exercise.EXERCISE_BENCH_PRESS,
      ]);
    });

    // "Warmups off" has to be expressible, not just absent: the server treats a
    // missing plan as "leave the warmups alone", so an empty list is the only
    // way to turn them off.
    test('is empty rather than absent when nothing wants warmups', () {
      final plan = warmupPlanFromConfigs([
        config(Exercise.EXERCISE_LATERAL_RAISE, includeWarmup: false),
      ]);
      expect(plan.exercises, isEmpty);
    });
  });

  group('buildPlannedGroupSetsFromConfigs', () {
    test('sends working sets only — the server materializes the warmups', () {
      final sets = buildPlannedGroupSetsFromConfigs(
        sets: 3,
        interleaveWarmups: false,
        exerciseConfigs: [
          config(Exercise.EXERCISE_SQUAT, weight: 200, includeWarmup: true),
        ],
        unit: WeightUnit.WEIGHT_UNIT_LB,
      );

      expect(sets, hasLength(3));
      expect(sets.every((s) => !s.warmup), isTrue);
      expect(sets.every((s) => s.targetWeight == 200), isTrue);
      // Rest values are mandatory by the time a plan leaves the client.
      expect(sets.every((s) => s.restAfterSuccess > 0), isTrue);
      expect(sets.every((s) => s.restAfterFailure > 0), isTrue);
      expect(sets.every((s) => s.clientSetId.isNotEmpty), isTrue);
    });

    test('interleaves supersets by round', () {
      final sets = buildPlannedGroupSetsFromConfigs(
        sets: 2,
        interleaveWarmups: true,
        exerciseConfigs: [
          config(Exercise.EXERCISE_SQUAT, includeWarmup: true),
          config(Exercise.EXERCISE_BENCH_PRESS, includeWarmup: true),
        ],
        unit: WeightUnit.WEIGHT_UNIT_LB,
      );

      expect(sets.map((s) => s.exercise), [
        Exercise.EXERCISE_SQUAT,
        Exercise.EXERCISE_BENCH_PRESS,
        Exercise.EXERCISE_SQUAT,
        Exercise.EXERCISE_BENCH_PRESS,
      ]);
    });
  });
}
