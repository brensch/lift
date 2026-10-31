/// The tutorial's sandbox: a real account, in memory, run by the same core as
/// the user's — three templates, trackers a few months in, last week's
/// training behind it (so volume and recovery have something to say), and
/// on cue a session two exercises in with its rest still running. Nothing
/// touches the network or the user's own account.
library;

import 'package:fixnum/fixnum.dart';

import '../gen/workout/v1/account.pb.dart';
import '../gen/workout/v1/wearable.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../services/local_core.dart';

class TutorialAccount {
  final LocalCore core;

  /// The template the home suggests, and the session runs.
  final String suggestedTemplateId;

  TutorialAccount._(this.core, this.suggestedTemplateId);

  static const _day = 86400;

  /// How far in the sample session is when the tutorial reaches it.
  static const sessionAge = Duration(minutes: 24);

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

  /// Working weights (lb), as someone a few months in would have them.
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

  static Future<TutorialAccount> create() async {
    final core = await LocalCore.memory('tutorial');
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // The trackers, as performed recently (so nothing asks to find a
    // weight), and the last fortnight's sessions: legs and push lately,
    // pull before this week — so pull is what's behind, and suggested.
    await core.call(
      'ImportHistory',
      ImportHistory(
        trackers: [
          for (final e in _weights.entries)
            TrackerRecord(
              exercise: e.key,
              workingWeight: e.value,
              lastPerformedAt: Int64(now - 2 * _day),
            ),
        ],
        workouts: [
          _pastSession('legs', _legs, now - 2 * _day),
          _pastSession('push', _push, now - 1 * _day),
          _pastSession('pull', _pull, now - 10 * _day),
        ],
      ),
      ImportHistoryResponse.fromBuffer,
    );
    final ids = <String>[];
    for (final (name, exercises) in [
      ('Pull', _pull),
      ('Legs', _legs),
      ('Push', _push),
    ]) {
      final saved = await core.call(
        'SaveTemplate',
        SaveTemplateRequest(
          template: WorkoutTemplate(name: name, exercises: exercises),
        ),
        SaveTemplateResponse.fromBuffer,
      );
      ids.add(saved.template.id);
    }
    final home = await core.call(
      'GetHome',
      GetHomeRequest(),
      GetHomeResponse.fromBuffer,
    );
    final suggested = home.suggestedTemplateId.isEmpty
        ? ids.first
        : home.suggestedTemplateId;
    return TutorialAccount._(core, suggested);
  }

  /// A finished session of [exercises] at [at]: three sets each at the
  /// tracker weight, every rep made.
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
            restAfterSuccess: 120,
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

  /// The suggested template, started [sessionAge] ago with its first two
  /// exercises done; the last set finished moments ago, so its rest is
  /// still running.
  Future<String> startSession() async {
    final now = DateTime.now();
    final started = await core.call(
      'StartWorkout',
      StartWorkoutRequest(templateId: suggestedTemplateId),
      StartWorkoutResponse.fromBuffer,
      at: now.subtract(sessionAge),
    );
    final firstTwo = <Exercise>[];
    for (final set in started.proposedSets) {
      if (!firstTwo.contains(set.exercise)) firstTwo.add(set.exercise);
    }
    firstTwo.removeRange(2, firstTwo.length);
    final done = started.proposedSets
        .where((s) => firstTwo.contains(s.exercise))
        .toList();
    // Spaced evenly back from a quarter-minute ago.
    final last = now.subtract(const Duration(seconds: 15));
    for (var i = 0; i < done.length; i++) {
      final at = last.subtract(Duration(seconds: 130 * (done.length - 1 - i)));
      await core.call(
        'AppendWorkoutMutations',
        AppendWorkoutMutationsRequest(
          mutations: [
            WorkoutMutation(
              completeSet: CompleteSetRequest(
                workoutId: started.id,
                proposedSetId: done[i].id,
                actualReps: done[i].targetReps,
                actualWeight: done[i].targetWeight,
                completedAt: Int64(at.millisecondsSinceEpoch ~/ 1000),
              ),
            ),
          ],
        ),
        AppendWorkoutMutationsResponse.fromBuffer,
        at: at,
      );
    }
    return started.id;
  }

  /// A watch's worth of heart rate for the session so far: a sample every
  /// five seconds, climbing through sets and easing during rests.
  static WearSensorBatch heartRateBatch(String workoutId) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final startMs = nowMs - sessionAge.inMilliseconds;
    final batch = WearSensorBatch()
      ..batchId = 'tutorial-hr'
      ..workoutId = workoutId
      ..sentAt = Int64(nowMs);
    for (var ms = startMs; ms <= nowMs; ms += 5000) {
      final t = (ms - startMs) / 1000;
      // Sets every ~3 minutes: up to ~150, back down to ~105 while resting.
      final phase = (t % 180) / 180;
      final bpm = phase < 0.25
          ? 105 + 45 * (phase / 0.25)
          : 150 - 45 * ((phase - 0.25) / 0.75);
      batch.heartRateSamples.add(
        HeartRateSample()
          ..sampledAt = Int64(ms)
          ..bpm = bpm + ((t * 7) % 5) - 2,
      );
    }
    return batch;
  }
}
