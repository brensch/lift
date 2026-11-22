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
    'barbell_row',
    'pull_up',
    'dumbbell_row',
    'barbell_curl',
  ];
  static const _legs = ['squat', 'romanian_deadlift', 'calf_raise'];
  static const _push = ['bench_press', 'overhead_press', 'lateral_raise'];

  /// Weights (lb) as someone a few months in lifts them.
  static const _weights = {
    'barbell_row': 115.0,
    'pull_up': 0.0,
    'dumbbell_row': 40.0,
    'barbell_curl': 45.0,
    'squat': 185.0,
    'romanian_deadlift': 155.0,
    'calf_raise': 25.0,
    'bench_press': 135.0,
    'overhead_press': 75.0,
    'lateral_raise': 15.0,
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
    List<String> exercises,
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
