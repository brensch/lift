import 'package:grpc/grpc.dart';

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
    String name,
    List<ExerciseGroup> exerciseGroups,
  ) async {
    final req = StartWorkoutRequest()
      ..name = name
      ..exerciseGroups.addAll(exerciseGroups);
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

  Future<RehydrateWorkoutFromEventsResponse> rehydrateWorkoutFromEvents(
    String workoutId, {
    bool persist = true,
  }) async {
    return await _client.workoutService.rehydrateWorkoutFromEvents(
      RehydrateWorkoutFromEventsRequest()
        ..workoutId = workoutId
        ..persist = persist,
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

  Future<Workout> endWorkout(String workoutId) async {
    final response = await _client.workoutService.endWorkout(
      EndWorkoutRequest()..workoutId = workoutId,
    );
    return response.workout;
  }

  Future<ReplaceExerciseGroupPlanResponse> replaceExerciseGroupPlan({
    required String workoutId,
    String? exerciseGroupId,
    required String name,
    required bool interleaveWarmups,
    required List<PlannedGroupSet> sets,
    RestConfig? restConfig,
    bool deleteGroupIfEmpty = false,
    String instruction = '',
  }) async {
    final req = ReplaceExerciseGroupPlanRequest()
      ..workoutId = workoutId
      ..exerciseGroupId = exerciseGroupId ?? ''
      ..name = name
      ..interleaveWarmups = interleaveWarmups
      ..sets.addAll(sets)
      ..deleteGroupIfEmpty = deleteGroupIfEmpty
      ..instruction = instruction;
    if (restConfig != null) req.restConfig = restConfig;
    return await _client.workoutService.replaceExerciseGroupPlan(req);
  }

  Future<ReorderExerciseGroupsResponse> reorderExerciseGroups(
    String workoutId,
    List<String> exerciseGroupIds,
  ) async {
    return await _client.workoutService.reorderExerciseGroups(
      ReorderExerciseGroupsRequest()
        ..workoutId = workoutId
        ..exerciseGroupIds.addAll(exerciseGroupIds),
    );
  }

  Future<GetProposedWorkoutScheduleResponse> getProposedWorkoutSchedule(
    String userId,
  ) async {
    return await retryReadAfterReconnect(
      operation: 'GetProposedWorkoutSchedule',
      resetChannel: _client.resetChannel,
      rpc: () => _client.workoutService.getProposedWorkoutSchedule(
        GetProposedWorkoutScheduleRequest()..userId = userId,
        options: _defaultCallOptions,
      ),
    );
  }

  Future<WorkoutDraft> saveWorkoutDraft(WorkoutDraft draft) async {
    final response = await _client.workoutService.saveWorkoutDraft(
      SaveWorkoutDraftRequest()..draft = draft,
    );
    return response.draft;
  }

  Future<void> clearWorkoutDraft() async {
    await _client.workoutService.clearWorkoutDraft(ClearWorkoutDraftRequest());
  }

  Future<ExerciseGroup> saveProfileExerciseGroup(ExerciseGroup group) async {
    final response = await _client.workoutService.saveProfileExerciseGroup(
      SaveProfileExerciseGroupRequest()..group = group,
    );
    return response.group;
  }

  Future<void> deleteProfileExerciseGroup(String groupId) async {
    await _client.workoutService.deleteProfileExerciseGroup(
      DeleteProfileExerciseGroupRequest()..groupId = groupId,
    );
  }
}
