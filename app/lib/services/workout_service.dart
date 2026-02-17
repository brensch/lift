import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/workout.pbgrpc.dart';
import 'grpc_client.dart';

class WorkoutServiceWrapper {
  final GrpcClient _client;

  WorkoutServiceWrapper(this._client);

  Future<String> startWorkout(
    String name,
    List<ExerciseGroup> exerciseGroups,
  ) async {
    final response = await _client.workoutService.startWorkout(
      StartWorkoutRequest()
        ..name = name
        ..exerciseGroups.addAll(exerciseGroups),
    );
    return response.id;
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

  Future<CompletedSet> startSet(String workoutId, String proposedSetId) async {
    final response = await _client.workoutService.startSet(
      StartSetRequest()
        ..workoutId = workoutId
        ..proposedSetId = proposedSetId,
    );
    return response.completedSet;
  }

  Future<CompletedSet> completeSet(
    String workoutId,
    String proposedSetId,
    int actualReps,
    double actualWeight,
  ) async {
    final response = await _client.workoutService.completeSet(
      CompleteSetRequest()
        ..workoutId = workoutId
        ..proposedSetId = proposedSetId
        ..actualReps = actualReps
        ..actualWeight = actualWeight,
    );
    return response.completedSet;
  }

  Future<void> deleteCompletedSet(
    String workoutId,
    String completedSetId,
  ) async {
    await _client.workoutService.deleteCompletedSet(
      DeleteCompletedSetRequest()
        ..workoutId = workoutId
        ..completedSetId = completedSetId,
    );
  }

  Future<void> cancelProposedSet(String workoutId, String proposedSetId) async {
    await _client.workoutService.cancelProposedSet(
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

  Future<CreateExerciseGroupResponse> createExerciseGroup({
    required String workoutId,
    required String name,
    required int sets,
    required bool interleaveWarmups,
    required List<ExerciseTypeConfig> exerciseConfigs,
    RestConfig? restConfig,
  }) async {
    final req = CreateExerciseGroupRequest()
      ..workoutId = workoutId
      ..name = name
      ..sets = sets
      ..interleaveWarmups = interleaveWarmups
      ..exerciseConfigs.addAll(exerciseConfigs);
    if (restConfig != null) req.restConfig = restConfig;
    return await _client.workoutService.createExerciseGroup(req);
  }

  Future<UpdateExerciseGroupResponse> updateExerciseGroup({
    required String workoutId,
    required String exerciseGroupId,
    required String name,
    required int sets,
    required bool interleaveWarmups,
    required List<ExerciseTypeConfig> exerciseConfigs,
    RestConfig? restConfig,
  }) async {
    final req = UpdateExerciseGroupRequest()
      ..workoutId = workoutId
      ..exerciseGroupId = exerciseGroupId
      ..name = name
      ..sets = sets
      ..interleaveWarmups = interleaveWarmups
      ..exerciseConfigs.addAll(exerciseConfigs);
    if (restConfig != null) req.restConfig = restConfig;
    return await _client.workoutService.updateExerciseGroup(req);
  }

  Future<void> deleteExerciseGroup(
    String workoutId,
    String exerciseGroupId,
  ) async {
    await _client.workoutService.deleteExerciseGroup(
      DeleteExerciseGroupRequest()
        ..workoutId = workoutId
        ..exerciseGroupId = exerciseGroupId,
    );
  }

  Future<void> reorderExerciseGroups(
    String workoutId,
    List<String> exerciseGroupIds,
  ) async {
    await _client.workoutService.reorderExerciseGroups(
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
