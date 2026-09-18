/// The tutorial's sandbox backend: an in-memory stand-in for the gRPC
/// service that answers with a believable account (three templates, a
/// suggested one, muscles at various volumes) and a session already two
/// exercises in, resting, without touching the network or the user's data.
library;

import 'package:fixnum/fixnum.dart';

import '../gen/workout/v1/wearable.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../services/grpc_client.dart';
import '../services/workout_service.dart';

class TutorialWorkoutService extends WorkoutServiceWrapper {
  TutorialWorkoutService() : super(GrpcClient(host: '127.0.0.1', port: 1));

  Workout? _active;
  List<ProposedSet> _proposed = const [];

  static const suggestedTemplateId = 't1';

  @override
  Future<GetHomeResponse> getHome() async => GetHomeResponse(
    templates: [
      _template(),
      _template(name: 'Legs', id: 't2'),
      _template(name: 'Push', id: 't3'),
    ],
    trackers: _trackers(),
    volume: _volume(),
    recovery: _recovery(),
    suggestedTemplateId: suggestedTemplateId,
    suggestionReason: 'Back and biceps are behind',
    onboarded: true,
    activeWorkoutId: _active?.id ?? '',
  );

  @override
  Future<Workout?> getActiveWorkout() async => _active;

  List<CompletedSet> _completed = const [];

  /// How far in the sample session is when the tutorial reaches it: the
  /// first two exercises done, the last set finished a moment ago, and
  /// the rest before the third exercise still running.
  static const sessionAge = Duration(minutes: 24);
  static const restLeft = Duration(seconds: 75);

  @override
  Future<StartWorkoutResponse> startWorkout(
    String name, {
    String templateId = '',
    List<Exercise> exercises = const [],
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final template = templateId == 't2'
        ? _template(name: 'Legs', id: 't2')
        : templateId == 't3'
        ? _template(name: 'Push', id: 't3')
        : _template();
    _active = Workout()
      ..id = 'tutorial-workout'
      ..name = template.name
      ..startTime = Int64(now - sessionAge.inSeconds)
      ..templateId = template.id;
    _proposed = _proposedFor(template, _active!.id);

    // Every set of the first two exercises is done, spaced out like a
    // real session, ending with a rest that is still counting down.
    final firstTwo = template.exercises.take(2).toSet();
    final done = _proposed.where((p) => firstTwo.contains(p.exercise)).toList();
    final lastEnd = now - (done.last.restAfterSuccess - restLeft.inSeconds);
    var t = lastEnd;
    final completed = <CompletedSet>[];
    for (final set in done.reversed) {
      final ended = t;
      final started = ended - 35;
      completed.insert(
        0,
        CompletedSet()
          ..id = 'cs-${set.id}'
          ..workoutId = _active!.id
          ..proposedSetId = set.id
          ..actualReps = set.targetReps
          ..actualWeight = set.targetWeight
          ..startedAt = Int64(started)
          ..endedAt = Int64(ended)
          ..restUntil = Int64(ended + set.restAfterSuccess),
      );
      t = started - set.restAfterSuccess;
    }
    _completed = completed;
    return StartWorkoutResponse(
      id: _active!.id,
      workout: _active,
      proposedSets: _proposed,
      completedSets: _completed,
      nextUpSet: _nextUp,
      stateSnapshot: _snapshot(now),
    );
  }

  ProposedSet? get _nextUp {
    final doneIds = _completed.map((c) => c.proposedSetId).toSet();
    for (final p in _proposed) {
      if (!doneIds.contains(p.id)) return p;
    }
    return null;
  }

  WorkoutStateSnapshot _snapshot(int now) {
    final next = _nextUp;
    final last = _completed.isEmpty ? null : _completed.last;
    if (next != null && last != null && last.restUntil.toInt() > now) {
      return WorkoutStateSnapshot(
        state: WorkoutState.WORKOUT_STATE_RESTING,
        displaySet: next,
        restUntil: last.restUntil,
      );
    }
    return WorkoutStateSnapshot(
      state: next == null
          ? WorkoutState.WORKOUT_STATE_ALL_DONE
          : WorkoutState.WORKOUT_STATE_READY,
      displaySet: next,
    );
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

  @override
  Future<GetWorkoutResponse> getWorkout(String workoutId) async =>
      GetWorkoutResponse(
        workout: _active,
        proposedSets: _proposed,
        completedSets: _completed,
        nextUpSet: _nextUp,
        stateSnapshot: _snapshot(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      );

  @override
  Future<EndWorkoutResponse> endWorkout(String workoutId) async {
    final ended = _active?.deepCopy();
    if (ended != null) {
      ended.endTime = Int64(DateTime.now().millisecondsSinceEpoch ~/ 1000);
    }
    _active = null;
    _proposed = const [];
    _completed = const [];
    return EndWorkoutResponse(workout: ended);
  }

  @override
  Future<AppendWorkoutMutationsResponse> appendWorkoutMutations(
    List<WorkoutMutation> mutations,
  ) async => AppendWorkoutMutationsResponse(
    appliedEventIds: mutations.map((m) => m.eventId),
  );

  @override
  Future<AppendWorkoutHeartRateResponse> appendWorkoutHeartRate(
    String workoutId,
    List<WorkoutHeartRatePoint> samples,
  ) async => AppendWorkoutHeartRateResponse(stored: samples.length);

  @override
  Future<List<WorkoutHeartRatePoint>> getWorkoutHeartRate(
    String workoutId,
  ) async => const [];

  @override
  Future<List<Workout>> listWorkouts() async => const [];

  @override
  Future<List<WorkoutWithSummary>> listWorkoutSummaries() async => const [];

  @override
  Future<GetExerciseProgressResponse> getExerciseProgress() async =>
      GetExerciseProgressResponse();

  @override
  Future<WorkoutTemplate> saveTemplate(WorkoutTemplate template) async =>
      template;

  @override
  Future<void> deleteTemplate(String templateId) async {}

  @override
  Future<void> reorderTemplates(List<String> templateIds) async {}

  @override
  Future<List<LibraryTemplate>> listTemplateLibrary() async => [
    LibraryTemplate(
      id: 'stronglifts_a',
      name: 'StrongLifts 5×5 A',
      blurb: 'Squat, bench, row. The famous one.',
      groupKey: 'programs',
      groupLabel: 'Programs',
      exercises: [
        Exercise.EXERCISE_SQUAT,
        Exercise.EXERCISE_BENCH_PRESS,
        Exercise.EXERCISE_BARBELL_ROW,
      ],
    ),
    LibraryTemplate(
      id: 'butt_stuff',
      name: 'Butt Stuff',
      blurb: 'Hip thrusts and friends.',
      groupKey: 'parts',
      groupLabel: 'Body parts',
      exercises: [
        Exercise.EXERCISE_HIP_THRUST,
        Exercise.EXERCISE_ROMANIAN_DEADLIFT,
        Exercise.EXERCISE_GLUTE_BRIDGE,
      ],
    ),
  ];

  @override
  Future<GetHomeResponse> addLibraryTemplates(List<String> libraryIds) =>
      getHome();
}

// ── Sample data ──────────────────────────────────────────────────────────────

WorkoutTemplate _template({String name = 'Pull', String id = 't1'}) {
  return WorkoutTemplate()
    ..id = id
    ..name = name
    ..exercises.addAll(
      name == 'Pull'
          ? [
              Exercise.EXERCISE_BARBELL_ROW,
              Exercise.EXERCISE_PULL_UP,
              Exercise.EXERCISE_DUMBBELL_ROW,
              Exercise.EXERCISE_BARBELL_CURL,
            ]
          : name == 'Legs'
          ? [
              Exercise.EXERCISE_SQUAT,
              Exercise.EXERCISE_ROMANIAN_DEADLIFT,
              Exercise.EXERCISE_CALF_RAISE,
            ]
          : [
              Exercise.EXERCISE_BENCH_PRESS,
              Exercise.EXERCISE_OVERHEAD_PRESS,
              Exercise.EXERCISE_LATERAL_RAISE,
            ],
    );
}

ExerciseTracker _tracker(
  Exercise exercise,
  double weight,
  int sets,
  int reps,
  int rest, {
  bool warmup = false,
  MuscleGroup muscle = MuscleGroup.MUSCLE_GROUP_UNSPECIFIED,
}) {
  return ExerciseTracker()
    ..exercise = exercise
    ..workingWeight = weight
    ..sets = sets
    ..targetReps = reps
    ..repRangeLow = reps
    ..repRangeHigh = reps + 4
    ..restSeconds = rest
    ..restSecondsFailure = rest + 60
    ..includeWarmup = warmup
    ..primaryMuscle = muscle;
}

List<ExerciseTracker> _trackers() => [
  _tracker(
    Exercise.EXERCISE_BARBELL_ROW,
    115,
    3,
    6,
    150,
    warmup: true,
    muscle: MuscleGroup.MUSCLE_GROUP_BACK,
  ),
  _tracker(
    Exercise.EXERCISE_PULL_UP,
    0,
    3,
    5,
    120,
    muscle: MuscleGroup.MUSCLE_GROUP_BACK,
  ),
  _tracker(
    Exercise.EXERCISE_DUMBBELL_ROW,
    40,
    3,
    8,
    120,
    muscle: MuscleGroup.MUSCLE_GROUP_BACK,
  ),
  _tracker(
    Exercise.EXERCISE_BARBELL_CURL,
    45,
    3,
    10,
    90,
    muscle: MuscleGroup.MUSCLE_GROUP_BICEPS,
  ),
  _tracker(
    Exercise.EXERCISE_SQUAT,
    185,
    3,
    6,
    180,
    warmup: true,
    muscle: MuscleGroup.MUSCLE_GROUP_QUADS,
  ),
  _tracker(
    Exercise.EXERCISE_ROMANIAN_DEADLIFT,
    155,
    3,
    6,
    180,
    warmup: true,
    muscle: MuscleGroup.MUSCLE_GROUP_HAMSTRINGS,
  ),
  _tracker(
    Exercise.EXERCISE_CALF_RAISE,
    25,
    3,
    10,
    90,
    muscle: MuscleGroup.MUSCLE_GROUP_CALVES,
  ),
  _tracker(
    Exercise.EXERCISE_BENCH_PRESS,
    135,
    3,
    6,
    150,
    warmup: true,
    muscle: MuscleGroup.MUSCLE_GROUP_CHEST,
  ),
  _tracker(
    Exercise.EXERCISE_OVERHEAD_PRESS,
    75,
    3,
    6,
    150,
    warmup: true,
    muscle: MuscleGroup.MUSCLE_GROUP_SHOULDERS,
  ),
  _tracker(
    Exercise.EXERCISE_LATERAL_RAISE,
    15,
    3,
    10,
    90,
    muscle: MuscleGroup.MUSCLE_GROUP_SHOULDERS,
  ),
];

/// The working sets a template prescribes, from its trackers, warmups
/// included where the tracker says so. Enough to drive a set or two.
List<ProposedSet> _proposedFor(WorkoutTemplate template, String workoutId) {
  final byExercise = {for (final t in _trackers()) t.exercise: t};
  final out = <ProposedSet>[];
  var order = 0;
  for (final ex in template.exercises) {
    final t = byExercise[ex]!;
    if (t.includeWarmup && t.workingWeight > 0) {
      for (final fraction in [0.5, 0.75]) {
        out.add(
          ProposedSet()
            ..id = 'ps-${order++}'
            ..workoutId = workoutId
            ..workoutOrder = order
            ..exercise = ex
            ..targetReps = 5
            ..targetWeight = (t.workingWeight * fraction / 5).round() * 5.0
            ..warmup = true
            ..restAfterSuccess = 60
            ..restAfterFailure = 60,
        );
      }
    }
    for (var i = 0; i < t.sets; i++) {
      out.add(
        ProposedSet()
          ..id = 'ps-${order++}'
          ..workoutId = workoutId
          ..workoutOrder = order
          ..exercise = ex
          ..targetReps = t.targetReps
          ..targetWeight = t.workingWeight
          ..restAfterSuccess = t.restSeconds
          ..restAfterFailure = t.restSecondsFailure,
      );
    }
  }
  return out;
}

MuscleVolume _v(MuscleGroup muscle, double sets) => MuscleVolume()
  ..muscle = muscle
  ..completedSets7d = sets
  ..targetLow = 10
  ..targetHigh = 20;

List<MuscleVolume> _volume() => [
  _v(MuscleGroup.MUSCLE_GROUP_CHEST, 12),
  _v(MuscleGroup.MUSCLE_GROUP_BACK, 4.5),
  _v(MuscleGroup.MUSCLE_GROUP_SHOULDERS, 6.5),
  _v(MuscleGroup.MUSCLE_GROUP_BICEPS, 2),
  _v(MuscleGroup.MUSCLE_GROUP_TRICEPS, 7.5),
  _v(MuscleGroup.MUSCLE_GROUP_QUADS, 11),
  _v(MuscleGroup.MUSCLE_GROUP_HAMSTRINGS, 5),
  _v(MuscleGroup.MUSCLE_GROUP_GLUTES, 12.5),
  _v(MuscleGroup.MUSCLE_GROUP_CALVES, 3),
  _v(MuscleGroup.MUSCLE_GROUP_CORE, 3),
];

List<MuscleRecoveryStatus> _recovery() {
  MuscleRecoveryStatus s(String key, bool recovered, int hours) =>
      MuscleRecoveryStatus()
        ..muscleKey = key
        ..recovered = recovered
        ..hoursRemaining = Int64(hours);
  return [
    s('chest', false, 14),
    s('back', true, 0),
    s('shoulders', false, 2),
    s('biceps', true, 0),
    s('triceps', false, 2),
    s('quads', true, 0),
    s('hamstrings', true, 0),
    s('glutes', true, 0),
    s('calves', true, 0),
    s('core', true, 0),
  ];
}
