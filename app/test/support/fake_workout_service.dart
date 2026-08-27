/// An in-memory stand-in for the gRPC service wrapper, for driving the
/// real WorkoutProvider in tests. Canned responses go in, every mutation
/// batch the provider flushes is captured, and the failure switch lets a
/// test hold mutations in the offline queue.
library;

import 'package:grpc/grpc.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/services/grpc_client.dart';
import 'package:schlift/services/workout_service.dart';

class FakeWorkoutService extends WorkoutServiceWrapper {
  FakeWorkoutService() : super(GrpcClient(host: '127.0.0.1', port: 1));

  /// The next StartWorkout response.
  StartWorkoutResponse startResponse = StartWorkoutResponse();

  /// The next GetWorkout response (loadWorkoutFromServer reads this).
  GetWorkoutResponse workoutResponse = GetWorkoutResponse();

  /// The next GetHome response (refreshHome reads this).
  GetHomeResponse homeResponse = GetHomeResponse();

  /// When true, appendWorkoutMutations throws UNAVAILABLE — the provider
  /// treats that as transient and keeps the batch queued.
  bool failMutations = false;

  /// Every mutation the provider has flushed, in order.
  final List<WorkoutMutation> flushedMutations = [];

  @override
  Future<StartWorkoutResponse> startWorkout(
    String name, {
    String templateId = '',
    List<Exercise> exercises = const [],
  }) async => startResponse;

  @override
  Future<GetWorkoutResponse> getWorkout(String workoutId) async =>
      workoutResponse;

  @override
  Future<Workout?> getActiveWorkout() async => null;

  @override
  Future<GetHomeResponse> getHome() async => homeResponse;

  @override
  Future<AppendWorkoutMutationsResponse> appendWorkoutMutations(
    List<WorkoutMutation> mutations,
  ) async {
    if (failMutations) {
      throw GrpcError.unavailable('offline (test)');
    }
    flushedMutations.addAll(mutations);
    return AppendWorkoutMutationsResponse(
      appliedEventIds: mutations.map((m) => m.eventId),
    );
  }

  @override
  Future<AppendWorkoutHeartRateResponse> appendWorkoutHeartRate(
    String workoutId,
    List<WorkoutHeartRatePoint> samples,
  ) async => AppendWorkoutHeartRateResponse(stored: samples.length);

  @override
  Future<List<WorkoutHeartRatePoint>> getWorkoutHeartRate(
    String workoutId,
  ) async => const [];
}
