import 'package:grpc/grpc.dart';

import '../gen/workout/v1/settings.pb.dart';
import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/workout.pbgrpc.dart';
import 'package:fixnum/fixnum.dart';
import 'grpc_client.dart';

class WorkoutServiceWrapper {
  final GrpcClient _client;
  static final _defaultCallOptions = CallOptions(
    timeout: Duration(seconds: 10),
  );

  WorkoutServiceWrapper(this._client);

  Future<StartWorkoutResponse> startWorkout(
    String name, {
    String templateId = '',
    List<Exercise> exercises = const [],
  }) async {
    final req = StartWorkoutRequest()
      ..name = name
      ..exercises.addAll(exercises)
      ..templateId = templateId;
    return await _client.workoutService.startWorkout(req);
  }

  Future<GetWorkoutResponse> getWorkout(String workoutId) async {
    return await retryReadAfterReconnect(
      operation: 'GetWorkout',
      resetChannel: _client.resetChannel,
      rpc: () => _client.workoutService.getWorkout(
        GetWorkoutRequest()..workoutId = workoutId,
        options: _defaultCallOptions,
      ),
    );
  }

  Future<Workout?> getActiveWorkout() async {
    final response = await retryReadAfterReconnect(
      operation: 'GetActiveWorkout',
      resetChannel: _client.resetChannel,
      rpc: () => _client.workoutService.getActiveWorkout(
        GetActiveWorkoutRequest(),
        options: _defaultCallOptions,
      ),
    );
    return response.hasWorkout() ? response.workout : null;
  }

  Future<List<Workout>> listWorkouts() async {
    final response = await _client.workoutService.listWorkouts(
      ListWorkoutsRequest(),
    );
    return response.workouts;
  }

  Future<List<WorkoutWithSummary>> listWorkoutSummaries() async {
    final response = await _client.workoutService.listWorkoutSummaries(
      ListWorkoutSummariesRequest(),
    );
    return response.workouts;
  }

  Future<GetExerciseProgressResponse> getExerciseProgress() async {
    return await _client.workoutService.getExerciseProgress(
      GetExerciseProgressRequest(),
    );
  }

  Future<StartSetResponse> startSet(
    String workoutId,
    String proposedSetId,
  ) async {
    return await _client.workoutService.startSet(
      StartSetRequest()
        ..workoutId = workoutId
        ..proposedSetId = proposedSetId,
    );
  }

  Future<CompleteSetResponse> completeSet(
    String workoutId,
    String proposedSetId,
    int actualReps,
    double actualWeight,
    int? completedAt,
  ) async {
    return await _client.workoutService.completeSet(
      CompleteSetRequest()
        ..workoutId = workoutId
        ..proposedSetId = proposedSetId
        ..actualReps = actualReps
        ..actualWeight = actualWeight
        ..completedAt = Int64(completedAt ?? 0),
    );
  }

  Future<AppendWorkoutHeartRateResponse> appendWorkoutHeartRate(
    String workoutId,
    List<WorkoutHeartRatePoint> samples,
  ) async {
    return await _client.workoutService.appendWorkoutHeartRate(
      AppendWorkoutHeartRateRequest()
        ..workoutId = workoutId
        ..samples.addAll(samples),
    );
  }

  Future<List<WorkoutHeartRatePoint>> getWorkoutHeartRate(
    String workoutId,
  ) async {
    final response = await _client.workoutService.getWorkoutHeartRate(
      GetWorkoutHeartRateRequest()..workoutId = workoutId,
    );
    return response.samples;
  }

  Future<AppendWorkoutMutationsResponse> appendWorkoutMutations(
    List<WorkoutMutation> mutations,
  ) async {
    return await _client.workoutService.appendWorkoutMutations(
      AppendWorkoutMutationsRequest()..mutations.addAll(mutations),
    );
  }


  Future<DeleteCompletedSetResponse> deleteCompletedSet(
    String workoutId,
    String completedSetId,
  ) async {
    return await _client.workoutService.deleteCompletedSet(
      DeleteCompletedSetRequest()
        ..workoutId = workoutId
        ..completedSetId = completedSetId,
    );
  }

  Future<CancelProposedSetResponse> cancelProposedSet(
    String workoutId,
    String proposedSetId,
  ) async {
    return await _client.workoutService.cancelProposedSet(
      CancelProposedSetRequest()
        ..workoutId = workoutId
        ..proposedSetId = proposedSetId,
    );
  }

  Future<EndWorkoutResponse> endWorkout(String workoutId) async {
    return await _client.workoutService.endWorkout(
      EndWorkoutRequest()..workoutId = workoutId,
    );
  }

  Future<List<String>> dismissUserMessages(List<String> messageKeys) async {
    final response = await _client.workoutService.dismissUserMessages(
      DismissUserMessagesRequest()..messageKeys.addAll(messageKeys),
    );
    return response.dismissedMessageKeys;
  }

  /// Everything the home screen needs in one round trip.
  Future<GetHomeResponse> getHome() async {
    return await retryReadAfterReconnect(
      operation: 'GetHome',
      resetChannel: _client.resetChannel,
      rpc: () => _client.workoutService.getHome(
        GetHomeRequest(),
        options: _defaultCallOptions,
      ),
    );
  }

  Future<WorkoutTemplate> saveTemplate(WorkoutTemplate template) async {
    final response = await _client.workoutService.saveTemplate(
      SaveTemplateRequest()..template = template,
    );
    return response.template;
  }

  Future<void> deleteTemplate(String templateId) async {
    await _client.workoutService.deleteTemplate(
      DeleteTemplateRequest()..templateId = templateId,
    );
  }

  Future<void> reorderTemplates(List<String> templateIds) async {
    await _client.workoutService.reorderTemplates(
      ReorderTemplatesRequest()..templateIds.addAll(templateIds),
    );
  }

  /// Manual correction/override for one exercise. Overrides of 0 = derived.
  Future<ExerciseTracker> setExerciseTracker({
    required Exercise exercise,
    required double workingWeight,
    int overrideSets = 0,
    int overrideRepLow = 0,
    int overrideRepHigh = 0,
  }) async {
    final response = await _client.workoutService.setExerciseTracker(
      SetExerciseTrackerRequest()
        ..exercise = exercise
        ..workingWeight = workingWeight
        ..overrideSets = overrideSets
        ..overrideRepLow = overrideRepLow
        ..overrideRepHigh = overrideRepHigh,
    );
    return response.tracker;
  }

  /// Finishes setup: saves the unit, seeds trackers and default templates.
  Future<GetHomeResponse> completeOnboarding({
    required double bodyWeightKg,
    required ExperienceLevel experience,
    required WeightUnit unit,
    Gender gender = Gender.GENDER_UNSPECIFIED,
  }) async {
    final response = await _client.workoutService.completeOnboarding(
      CompleteOnboardingRequest()
        ..bodyWeightKg = bodyWeightKg
        ..experience = experience
        ..unit = unit
        ..gender = gender,
    );
    return response.home;
  }
}
