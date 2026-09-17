import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/logic/session_estimate.dart';

ExerciseTracker tracker(
  Exercise exercise, {
  int sets = 3,
  int rest = 180,
  bool warmup = false,
}) {
  return ExerciseTracker()
    ..exercise = exercise
    ..sets = sets
    ..restSeconds = rest
    ..includeWarmup = warmup;
}

void main() {
  test('one exercise: setup + sets + rests between them', () {
    // 75 setup + 3×45 lifting + 2×180 rest = 570 s.
    final t = tracker(Exercise.EXERCISE_LATERAL_RAISE, rest: 180);
    expect(estimatedExerciseSeconds(t), 75 + 3 * 45 + 2 * 180);
  });

  test('a warmup ladder adds four short sets with short rests', () {
    final bare = tracker(Exercise.EXERCISE_SQUAT);
    final warmed = tracker(Exercise.EXERCISE_SQUAT, warmup: true);
    expect(
      estimatedExerciseSeconds(warmed) - estimatedExerciseSeconds(bare),
      4 * (30 + 30),
    );
  });

  test('a template sums its exercises; unknown ones count zero', () {
    final template = WorkoutTemplate()
      ..exercises.addAll([
        Exercise.EXERCISE_SQUAT,
        Exercise.EXERCISE_CRUNCH,
        Exercise.EXERCISE_PEC_DECK, // no tracker below
      ]);
    final trackers = [
      tracker(Exercise.EXERCISE_SQUAT, rest: 180, warmup: true),
      tracker(Exercise.EXERCISE_CRUNCH, rest: 60),
    ];
    final squat = 75 + 3 * 45 + 2 * 180 + 4 * 60;
    final crunch = 75 + 3 * 45 + 2 * 60;
    expect(estimatedSessionSeconds(template, trackers), squat + crunch);
    expect(estimatedSessionLabel(template, trackers), isNotEmpty);
  });

  test('shorter upper-body rest shows up as real minutes saved', () {
    final template = WorkoutTemplate()
      ..exercises.add(Exercise.EXERCISE_BENCH_PRESS);
    final threeMin = [tracker(Exercise.EXERCISE_BENCH_PRESS, rest: 180)];
    final twoThirty = [tracker(Exercise.EXERCISE_BENCH_PRESS, rest: 150)];
    expect(
      estimatedSessionSeconds(template, threeMin) -
          estimatedSessionSeconds(template, twoThirty),
      60,
    );
  });
}
