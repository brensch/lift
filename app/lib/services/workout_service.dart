import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/workout.pbgrpc.dart';
import 'grpc_client.dart';

class WorkoutServiceWrapper {
  final GrpcClient _client;

  WorkoutServiceWrapper(this._client);

  Future<String> startWorkout(String name, List<ProposedSet> proposedSets) async {
    final response = await _client.workoutService.startWorkout(
      StartWorkoutRequest()
        ..name = name
        ..proposedSets.addAll(proposedSets),
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

  Future<List<ProposedSet>> modifyProposedSets(
    String workoutId,
    List<ProposedSet> proposedSets,
  ) async {
    final response = await _client.workoutService.modifyProposedSets(
      ModifyProposedSetsRequest()
        ..workoutId = workoutId
        ..proposedSets.addAll(proposedSets),
    );
    return response.proposedSets;
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

  Future<void> deleteCompletedSet(String workoutId, String completedSetId) async {
    await _client.workoutService.deleteCompletedSet(
      DeleteCompletedSetRequest()
        ..workoutId = workoutId
        ..completedSetId = completedSetId,
    );
  }

  Future<Workout> endWorkout(String workoutId) async {
    final response = await _client.workoutService.endWorkout(
      EndWorkoutRequest()..workoutId = workoutId,
    );
    return response.workout;
  }

  Future<GetProposedWorkoutScheduleResponse> getProposedWorkoutSchedule(
    String userId,
  ) async {
    return await _client.workoutService.getProposedWorkoutSchedule(
      GetProposedWorkoutScheduleRequest()..userId = userId,
    );
  }
}
