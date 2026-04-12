import 'package:grpc/grpc.dart';

import '../gen/workout/v1/group.pb.dart';
import '../gen/workout/v1/group.pbgrpc.dart';
import 'grpc_client.dart';

class MultiplayerServiceWrapper {
  final GrpcClient _client;
  /// Poll calls use a shorter deadline so a stale connection fails fast
  /// and the next poll can try on a fresh connection.
  static final _pollCallOptions = CallOptions(timeout: Duration(seconds: 5));
  static final _defaultCallOptions = CallOptions(timeout: Duration(seconds: 10));

  MultiplayerServiceWrapper(this._client);

  Future<String> joinUser(String userId) async {
    final req = JoinUserRequest()..userId = userId;
    final response = await _client.multiplayerService.joinUser(
      req,
      options: _defaultCallOptions,
    );
    return response.sessionId;
  }

  Future<void> leaveSession() async {
    await _client.multiplayerService.leaveSession(
      LeaveSessionRequest(),
      options: _defaultCallOptions,
    );
  }

  Future<GetCurrentSessionResponse> getCurrentSession({
    String? sessionId,
  }) async {
    final req = GetCurrentSessionRequest();
    if (sessionId != null) req.sessionId = sessionId;
    return await _client.multiplayerService.getCurrentSession(
      req,
      options: _pollCallOptions,
    );
  }

  Stream<SessionSubscriptionEvent> subscribeSession({String? sessionId}) {
    final req = SubscribeSessionRequest();
    if (sessionId != null) req.sessionId = sessionId;
    return _client.multiplayerService.subscribeSession(req);
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
