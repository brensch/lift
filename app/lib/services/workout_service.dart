import 'package:protobuf/protobuf.dart' show GeneratedMessage;

import '../gen/workout/v1/account.pb.dart';
import '../gen/workout/v1/settings.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import 'local_core.dart';

/// Where the account is: the signed-in user's file once it's open, or a
/// sandbox (the tutorial's in-memory account).
abstract class CoreSource {
  Future<LocalCore> get ready;
}

/// A [CoreSource] that is already open.
class FixedCore implements CoreSource {
  final LocalCore core;

  const FixedCore(this.core);

  @override
  Future<LocalCore> get ready => Future.value(core);
}

/// The app's workout calls, answered by the core on this phone (see
/// [LocalCore]): instant, and the same offline as on.
class WorkoutServiceWrapper {
  final CoreSource _source;

  WorkoutServiceWrapper(this._source);

  /// [method] answered by the core.
  Future<T> _call<T extends GeneratedMessage>(
    String method,
    GeneratedMessage request,
    T Function(List<int>) parse,
  ) async => (await _source.ready).call(method, request, parse);

  Future<StartWorkoutResponse> startWorkout(
    String name, {
    String templateId = '',
    List<Exercise> exercises = const [],
    int budgetMinutes = 0,
  }) => _call(
    'StartWorkout',
    StartWorkoutRequest()
      ..name = name
      ..exercises.addAll(exercises)
      ..templateId = templateId
      ..budgetMinutes = budgetMinutes,
    StartWorkoutResponse.fromBuffer,
  );

  Future<GetWorkoutResponse> getWorkout(String workoutId) => _call(
    'GetWorkout',
    GetWorkoutRequest()..workoutId = workoutId,
    GetWorkoutResponse.fromBuffer,
  );

  Future<Workout?> getActiveWorkout() async {
    final response = await _call(
      'GetActiveWorkout',
      GetActiveWorkoutRequest(),
      GetActiveWorkoutResponse.fromBuffer,
    );
    return response.hasWorkout() ? response.workout : null;
  }

  Future<List<WorkoutWithSummary>> listWorkoutSummaries() async => (await _call(
    'ListWorkoutSummaries',
    ListWorkoutSummariesRequest(),
    ListWorkoutSummariesResponse.fromBuffer,
  )).workouts;

  Future<GetExerciseProgressResponse> getExerciseProgress() => _call(
    'GetExerciseProgress',
    GetExerciseProgressRequest(),
    GetExerciseProgressResponse.fromBuffer,
  );

  Future<AppendWorkoutHeartRateResponse> appendWorkoutHeartRate(
    String workoutId,
    List<WorkoutHeartRatePoint> samples,
  ) => _call(
    'AppendWorkoutHeartRate',
    AppendWorkoutHeartRateRequest()
      ..workoutId = workoutId
      ..samples.addAll(samples),
    AppendWorkoutHeartRateResponse.fromBuffer,
  );

  Future<List<WorkoutHeartRatePoint>> getWorkoutHeartRate(
    String workoutId,
  ) async => (await _call(
    'GetWorkoutHeartRate',
    GetWorkoutHeartRateRequest()..workoutId = workoutId,
    GetWorkoutHeartRateResponse.fromBuffer,
  )).samples;

  /// Changes to a workout, applied in order; one that can't apply is
  /// skipped. Answers with the workout after them.
  Future<AppendWorkoutMutationsResponse> appendWorkoutMutations(
    List<WorkoutMutation> mutations,
  ) => _call(
    'AppendWorkoutMutations',
    AppendWorkoutMutationsRequest()..mutations.addAll(mutations),
    AppendWorkoutMutationsResponse.fromBuffer,
  );

  /// Ends the workout at the event's time.
  Future<EndWorkoutResponse> endWorkout(String workoutId) => _call(
    'EndWorkout',
    EndWorkoutRequest()..workoutId = workoutId,
    EndWorkoutResponse.fromBuffer,
  );

  /// Everything the home screen needs in one call, every lift planned in
  /// [budgetMinutes] (0 = the core's default).
  Future<GetHomeResponse> getHome({int budgetMinutes = 0}) => _call(
    'GetHome',
    GetHomeRequest(budgetMinutes: budgetMinutes),
    GetHomeResponse.fromBuffer,
  );

  /// Create or update [template]; [unlink] makes a library template the
  /// user's own even when saved unchanged.
  Future<WorkoutTemplate> saveTemplate(
    WorkoutTemplate template, {
    bool unlink = false,
  }) async => (await _call(
    'SaveTemplate',
    SaveTemplateRequest()
      ..template = template
      ..unlink = unlink,
    SaveTemplateResponse.fromBuffer,
  )).template;

  /// [exercises] planned as one workout in [budgetMinutes], as starting a
  /// template of them would plan it.
  Future<TemplatePlan> getTemplatePlan(
    List<Exercise> exercises, {
    int budgetMinutes = 0,
  }) async => (await _call(
    'GetTemplatePlan',
    GetTemplatePlanRequest(exercises: exercises, budgetMinutes: budgetMinutes),
    GetTemplatePlanResponse.fromBuffer,
  )).plan;

  Future<void> deleteTemplate(String templateId) => _call(
    'DeleteTemplate',
    DeleteTemplateRequest()..templateId = templateId,
    DeleteTemplateResponse.fromBuffer,
  );

  /// The user's order of [templateIds]; with [rotationCount], the first
  /// that many are in rotation and the rest reserves.
  Future<void> reorderTemplates(
    List<String> templateIds, {
    int? rotationCount,
  }) {
    final request = ReorderTemplatesRequest()..templateIds.addAll(templateIds);
    if (rotationCount != null) request.rotationCount = rotationCount;
    return _call(
      'ReorderTemplates',
      request,
      ReorderTemplatesResponse.fromBuffer,
    );
  }

  /// The user's own weight and reps (and optionally sets) for one lift:
  /// the plan carries on from it. Reps of 0 removes it.
  Future<ExercisePlan> setOverride({
    required Exercise exercise,
    required double weight,
    required int reps,
    int? sets,
  }) async {
    final request = SetOverrideRequest()
      ..exercise = exercise
      ..weight = weight
      ..reps = reps;
    if (sets != null) request.sets = sets;
    return (await _call(
      'SetOverride',
      request,
      SetOverrideResponse.fromBuffer,
    )).plan;
  }

  /// Finishes setup: saves the unit, records the starting weights
  /// [strength] picks (chick 0 .. gorilla 1; unset keeps the catalog's
  /// openers), and copies the chosen library templates (the library's
  /// defaults when none are named).
  Future<void> completeOnboarding({
    required WeightUnit unit,
    List<String> libraryIds = const [],
    double? strength,
  }) async {
    final request = CompleteOnboardingRequest()
      ..unit = unit
      ..libraryIds.addAll(libraryIds);
    if (strength != null) request.strength = strength;
    await _call(
      'CompleteOnboarding',
      request,
      CompleteOnboardingResponse.fromBuffer,
    );
  }

  /// The starting weights the setup slider shows, one step per 1% of
  /// the slider, in [unit].
  Future<List<StartingWeightsStep>> getStartingWeights(WeightUnit unit) async =>
      (await _call(
        'GetStartingWeights',
        GetStartingWeightsRequest(unit: unit),
        GetStartingWeightsResponse.fromBuffer,
      )).steps;

  /// The template library everyone picks from.
  Future<List<LibraryTemplate>> listTemplateLibrary() async =>
      (await templateLibrary()).templates;

  /// The template library and the ready-made plans made from it.
  Future<ListTemplateLibraryResponse> templateLibrary() => _call(
    'ListTemplateLibrary',
    ListTemplateLibraryRequest(),
    ListTemplateLibraryResponse.fromBuffer,
  );

  /// Makes a ready-made plan the rotation: entries the user lacks are
  /// added, the rest become reserves.
  Future<void> applyLibraryPlan(String planId) => _call(
    'ApplyLibraryPlan',
    ApplyLibraryPlanRequest(planId: planId),
    ApplyLibraryPlanResponse.fromBuffer,
  );

  /// Adds library entries to the user's templates, following the library,
  /// into the rotation or (by default) as reserves; ones the user already
  /// has are skipped.
  Future<void> addLibraryTemplates(
    List<String> libraryIds, {
    bool inRotation = false,
  }) => _call(
    'AddLibraryTemplates',
    AddLibraryTemplatesRequest(libraryIds: libraryIds, inRotation: inRotation),
    AddLibraryTemplatesResponse.fromBuffer,
  );

  /// Brings in [history] as it was (an account moving here).
  Future<void> importHistory(ImportHistory history) =>
      _call('ImportHistory', history, ImportHistoryResponse.fromBuffer);

  Future<List<UserSetting>> getSettings() async => (await _call(
    'GetSettings',
    GetSettingsRequest(),
    GetSettingsResponse.fromBuffer,
  )).settings;

  Future<void> updateSetting(UserSetting setting) => _call(
    'UpdateSetting',
    UpdateSettingRequest(setting: setting),
    UpdateSettingResponse.fromBuffer,
  );
}
