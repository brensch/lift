import '../gen/workout/v1/group.pb.dart';
import '../gen/workout/v1/group.pbgrpc.dart';
import 'grpc_client.dart';

class MultiplayerServiceWrapper {
  final GrpcClient _client;

  MultiplayerServiceWrapper(this._client);

  Future<String> startSession({String? workoutId}) async {
    final req = StartSessionRequest();
    if (workoutId != null) req.workoutId = workoutId;
    final response = await _client.multiplayerService.startSession(req);
    return response.sessionId;
  }

  Future<String> joinSession(String sessionId, {String? workoutId}) async {
    final req = JoinSessionRequest()..sessionId = sessionId;
    if (workoutId != null) req.workoutId = workoutId;
    final response = await _client.multiplayerService.joinSession(req);
    return response.sessionId;
  }

  Future<void> leaveSession() async {
    await _client.multiplayerService.leaveSession(LeaveSessionRequest());
  }

  Future<GetCurrentSessionResponse> getCurrentSession({String? sessionId}) async {
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
