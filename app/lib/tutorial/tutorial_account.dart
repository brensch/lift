/// The tutorial's sandbox: a real account, in memory, run by the same core as
/// the user's — three templates, lifts a few months in, last week's
/// training behind it (so volume and recovery have something to say).
/// Nothing touches the network or the user's own account.
library;

import 'package:fixnum/fixnum.dart';

import '../gen/workout/v1/account.pb.dart';
import '../gen/workout/v1/settings.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../services/local_core.dart';
import '../services/workout_service.dart';

class TutorialAccount {
  final LocalCore core;

  TutorialAccount._(this.core);

  static const _day = 86400;

  static const _pull = [
    Exercise.EXERCISE_BARBELL_ROW,
    Exercise.EXERCISE_PULL_UP,
    Exercise.EXERCISE_DUMBBELL_ROW,
    Exercise.EXERCISE_BARBELL_CURL,
  ];
  static const _legs = [
    Exercise.EXERCISE_SQUAT,
    Exercise.EXERCISE_ROMANIAN_DEADLIFT,
    Exercise.EXERCISE_CALF_RAISE,
  ];
  static const _push = [
    Exercise.EXERCISE_BENCH_PRESS,
    Exercise.EXERCISE_OVERHEAD_PRESS,
    Exercise.EXERCISE_LATERAL_RAISE,
  ];

  /// Weights (lb) as someone a few months in lifts them.
  static const _weights = {
    Exercise.EXERCISE_BARBELL_ROW: 115.0,
    Exercise.EXERCISE_PULL_UP: 0.0,
    Exercise.EXERCISE_DUMBBELL_ROW: 40.0,
    Exercise.EXERCISE_BARBELL_CURL: 45.0,
    Exercise.EXERCISE_SQUAT: 185.0,
    Exercise.EXERCISE_ROMANIAN_DEADLIFT: 155.0,
    Exercise.EXERCISE_CALF_RAISE: 25.0,
    Exercise.EXERCISE_BENCH_PRESS: 135.0,
    Exercise.EXERCISE_OVERHEAD_PRESS: 75.0,
    Exercise.EXERCISE_LATERAL_RAISE: 15.0,
  };

  /// The account in the user's [unit], so its weights load on their plates.
  static Future<TutorialAccount> create(WeightUnit unit) async {
    final core = await LocalCore.memory('tutorial');
    final service = WorkoutServiceWrapper(FixedCore(core));
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await service.updateSetting(
      UserSetting(weightUnit: WeightUnitConfig(unit: unit)),
    );

    // The last fortnight's sessions, every lift done (so each has a max
    // and nothing ramps): legs and push lately, pull before this week — so
    // pull is what's behind, and suggested.
    await service.importHistory(
      ImportHistory(
        workouts: [
          _pastSession('legs', _legs, now - 2 * _day),
          _pastSession('push', _push, now - 1 * _day),
          _pastSession('pull', _pull, now - 10 * _day),
        ],
      ),
    );
    for (final (name, exercises) in [
      ('Pull', _pull),
      ('Legs', _legs),
      ('Push', _push),
    ]) {
      await service.saveTemplate(
        WorkoutTemplate(name: name, exercises: exercises, inRotation: true),
      );
    }
    return TutorialAccount._(core);
  }

  /// A finished session of [exercises] at [at]: three sets each at its
  /// weight, every rep made.
  static ImportedWorkout _pastSession(
    String id,
    List<Exercise> exercises,
    int at,
  ) {
    final workoutId = 'tutorial-$id';
    final proposed = <ProposedSet>[];
    final completed = <CompletedSet>[];
    var t = at;
    for (final exercise in exercises) {
      for (var i = 0; i < 3; i++) {
        final setId = '$workoutId-${proposed.length}';
        proposed.add(
          ProposedSet(
            id: setId,
            workoutId: workoutId,
            workoutOrder: proposed.length,
            exercise: exercise,
            targetReps: 8,
            targetWeight: _weights[exercise],
            restSeconds: 120,
          ),
        );
        t += 160;
        completed.add(
          CompletedSet(
            id: '$setId-done',
            workoutId: workoutId,
            proposedSetId: setId,
            actualReps: 8,
            actualWeight: _weights[exercise],
            endedAt: Int64(t),
            restUntil: Int64(t + 120),
          ),
        );
      }
    }
    return ImportedWorkout(
      workout: Workout(
        id: workoutId,
        name: id,
        startTime: Int64(at),
        endTime: Int64(t + 60),
      ),
      proposedSets: proposed,
      completedSets: completed,
    );
  }
}
