import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/workout.pbgrpc.dart';
import 'package:fixnum/fixnum.dart';
import 'grpc_client.dart';

class WorkoutServiceWrapper {
  final GrpcClient _client;

  WorkoutServiceWrapper(this._client);

  Future<StartWorkoutResponse> startWorkout(
    String name,
    List<ExerciseGroup> exerciseGroups,
  ) async {
    return await _client.workoutService.startWorkout(
      StartWorkoutRequest()
        ..name = name
        ..exerciseGroups.addAll(exerciseGroups),
    );
  }

  Future<GetWorkoutResponse> getWorkout(String workoutId) async {
    return await _client.workoutService.getWorkout(
      GetWorkoutRequest()..workoutId = workoutId,
    );
  }

  Future<Workout?> getActiveWorkout() async {
    final response = await _client.workoutService.getActiveWorkout(
      GetActiveWorkoutRequest(),
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
    return await _client.workoutService.getProposedWorkoutSchedule(
      GetProposedWorkoutScheduleRequest()..userId = userId,
    );
  }
}
