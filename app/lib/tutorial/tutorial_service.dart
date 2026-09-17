/// The tutorial's sandbox backend: an in-memory stand-in for the gRPC
/// service that answers with a believable account (three templates, a
/// suggested one, muscles at various volumes) and lets a workout be
/// started and driven without touching the network or the user's data.
library;

import 'package:fixnum/fixnum.dart';

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

  @override
  Future<StartWorkoutResponse> startWorkout(
    String name, {
    String templateId = '',
    List<Exercise> exercises = const [],
  }) async {
    final now = Int64(DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final template = templateId == 't2'
        ? _template(name: 'Legs', id: 't2')
        : templateId == 't3'
        ? _template(name: 'Push', id: 't3')
        : _template();
    _active = Workout()
      ..id = 'tutorial-workout'
      ..name = template.name
      ..startTime = now
      ..templateId = template.id;
    _proposed = _proposedFor(template, _active!.id);
    return StartWorkoutResponse(
      id: _active!.id,
      workout: _active,
      proposedSets: _proposed,
      nextUpSet: _proposed.first,
      stateSnapshot: WorkoutStateSnapshot(
        state: WorkoutState.WORKOUT_STATE_READY,
        displaySet: _proposed.first,
      ),
    );
  }

  @override
  Future<GetWorkoutResponse> getWorkout(String workoutId) async =>
      GetWorkoutResponse(
        workout: _active,
        proposedSets: _proposed,
        nextUpSet: _proposed.isEmpty ? null : _proposed.first,
      );

  @override
  Future<EndWorkoutResponse> endWorkout(String workoutId) async {
    final ended = _active?.deepCopy();
    if (ended != null) {
      ended.endTime = Int64(DateTime.now().millisecondsSinceEpoch ~/ 1000);
    }
    _active = null;
    _proposed = const [];
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
