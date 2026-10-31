import 'package:fixnum/fixnum.dart';
import 'package:protobuf/protobuf.dart' show GeneratedMessage;

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

  Future<T> _call<T extends GeneratedMessage>(
    String method,
    GeneratedMessage request,
    T Function(List<int>) parse,
  ) async => (await _source.ready).call(method, request, parse);

  Future<StartWorkoutResponse> startWorkout(
    String name, {
    String templateId = '',
    List<Exercise> exercises = const [],
  }) => _call(
    'StartWorkout',
    StartWorkoutRequest()
      ..name = name
      ..exercises.addAll(exercises)
      ..templateId = templateId,
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

  Future<List<Workout>> listWorkouts() async => (await _call(
    'ListWorkouts',
    ListWorkoutsRequest(),
    ListWorkoutsResponse.fromBuffer,
  )).workouts;

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

  Future<EndWorkoutResponse> endWorkout(String workoutId, {int? endedAt}) =>
      _call(
        'EndWorkout',
        EndWorkoutRequest()
          ..workoutId = workoutId
          ..endedAt = Int64(endedAt ?? 0),
        EndWorkoutResponse.fromBuffer,
      );

  /// Everything the home screen needs in one call.
  Future<GetHomeResponse> getHome() =>
      _call('GetHome', GetHomeRequest(), GetHomeResponse.fromBuffer);

  Future<WorkoutTemplate> saveTemplate(WorkoutTemplate template) async =>
      (await _call(
        'SaveTemplate',
        SaveTemplateRequest()..template = template,
        SaveTemplateResponse.fromBuffer,
      )).template;

  Future<void> deleteTemplate(String templateId) => _call(
    'DeleteTemplate',
    DeleteTemplateRequest()..templateId = templateId,
    DeleteTemplateResponse.fromBuffer,
  );

  Future<void> reorderTemplates(List<String> templateIds) => _call(
    'ReorderTemplates',
    ReorderTemplatesRequest()..templateIds.addAll(templateIds),
    ReorderTemplatesResponse.fromBuffer,
  );

  /// Manual correction/override for one exercise. Overrides of 0 = derived.
  Future<ExerciseTracker> setExerciseTracker({
    required Exercise exercise,
    required double workingWeight,
    int overrideSets = 0,
    int overrideRepLow = 0,
    int overrideRepHigh = 0,
    int targetReps = 0,
  }) async => (await _call(
    'SetExerciseTracker',
    SetExerciseTrackerRequest()
      ..exercise = exercise
      ..workingWeight = workingWeight
      ..overrideSets = overrideSets
      ..overrideRepLow = overrideRepLow
      ..overrideRepHigh = overrideRepHigh
      ..targetReps = targetReps,
    SetExerciseTrackerResponse.fromBuffer,
  )).tracker;

  /// Finishes setup: saves the unit, seeds trackers, and copies the chosen
  /// library templates (the library's defaults when none are named).
  Future<GetHomeResponse> completeOnboarding({
    required double bodyWeightKg,
    required ExperienceLevel experience,
    required WeightUnit unit,
    Gender gender = Gender.GENDER_UNSPECIFIED,
    List<String> libraryIds = const [],
    double? strength, // chick 0 .. gorilla 1; replaces experience/gender
  }) async {
    final request = CompleteOnboardingRequest()
      ..bodyWeightKg = bodyWeightKg
      ..experience = experience
      ..unit = unit
      ..gender = gender
      ..libraryIds.addAll(libraryIds);
    if (strength != null) request.strength = strength;
    return (await _call(
      'CompleteOnboarding',
      request,
      CompleteOnboardingResponse.fromBuffer,
    )).home;
  }

  /// The template library everyone picks from.
  Future<List<LibraryTemplate>> listTemplateLibrary() async => (await _call(
    'ListTemplateLibrary',
    ListTemplateLibraryRequest(),
    ListTemplateLibraryResponse.fromBuffer,
  )).templates;

  /// Copies library entries into the user's templates; ones already there
  /// are skipped. Returns the refreshed home.
  Future<GetHomeResponse> addLibraryTemplates(List<String> libraryIds) async =>
      (await _call(
        'AddLibraryTemplates',
        AddLibraryTemplatesRequest()..libraryIds.addAll(libraryIds),
        AddLibraryTemplatesResponse.fromBuffer,
      )).home;

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

  Future<List<String>> dismissUserMessages(List<String> keys) async =>
      (await _call(
        'DismissUserMessages',
        DismissUserMessagesRequest()..messageKeys.addAll(keys),
        DismissUserMessagesResponse.fromBuffer,
      )).dismissedMessageKeys;
}
