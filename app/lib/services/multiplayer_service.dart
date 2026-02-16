import '../gen/workout/v1/group.pb.dart';
import '../gen/workout/v1/group.pbgrpc.dart';
import 'grpc_client.dart';

class MultiplayerServiceWrapper {
  final GrpcClient _client;

  MultiplayerServiceWrapper(this._client);

  Future<String> joinUser(String userId) async {
    final req = JoinUserRequest()..userId = userId;
    final response = await _client.multiplayerService.joinUser(req);
    return response.sessionId;
  }

  Future<void> leaveSession() async {
    await _client.multiplayerService.leaveSession(LeaveSessionRequest());
  }

  Future<GetCurrentSessionResponse> getCurrentSession({
    String? sessionId,
  }) async {
    final req = GetCurrentSessionRequest();
    if (sessionId != null) req.sessionId = sessionId;
    return await _client.multiplayerService.getCurrentSession(req);
  }

  Future<void> updateActiveWorkout(String workoutId) async {
    await _client.multiplayerService.updateActiveWorkout(
      UpdateActiveWorkoutRequest()..workoutId = workoutId,
    );
  }

  Future<ParticipantStatus> getParticipantWorkout(
    String userId,
    String workoutId,
  ) async {
    return await _client.multiplayerService.getParticipantWorkout(
      GetParticipantWorkoutRequest()
        ..userId = userId
        ..workoutId = workoutId,
    );
  }
}
