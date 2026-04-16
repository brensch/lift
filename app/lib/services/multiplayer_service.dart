import 'package:grpc/grpc.dart';

import '../gen/workout/v1/group.pb.dart';
import '../gen/workout/v1/group.pbgrpc.dart';
import 'grpc_client.dart';

class MultiplayerServiceWrapper {
  final GrpcClient _client;

  /// Poll calls use a shorter deadline so a stale connection fails fast
  /// and the next poll can try on a fresh connection.
  static final _pollCallOptions = CallOptions(timeout: Duration(seconds: 5));
  static final _defaultCallOptions = CallOptions(
    timeout: Duration(seconds: 10),
  );

  MultiplayerServiceWrapper(this._client);

  Future<String> joinViaInvite(String inviteToken) async {
    final req = JoinViaInviteRequest()..inviteToken = inviteToken;
    final response = await _client.multiplayerService.joinViaInvite(
      req,
      options: _defaultCallOptions,
    );
    return response.sessionId;
  }

  Future<String> getMyInviteToken() async {
    final response = await retryReadAfterReconnect(
      operation: 'GetMyInviteToken',
      resetChannel: _client.resetChannel,
      rpc: () => _client.multiplayerService.getMyInviteToken(
        GetMyInviteTokenRequest(),
        options: _defaultCallOptions,
      ),
    );
    return response.inviteToken;
  }

  Future<String> rotateInviteToken() async {
    final response = await _client.multiplayerService.rotateInviteToken(
      RotateInviteTokenRequest(),
      options: _defaultCallOptions,
    );
    return response.inviteToken;
  }

  Future<GetCurrentSessionResponse> getCurrentSession() async {
    return await retryReadAfterReconnect(
      operation: 'GetCurrentSession',
      resetChannel: _client.resetChannel,
      rpc: () => _client.multiplayerService.getCurrentSession(
        GetCurrentSessionRequest(),
        options: _pollCallOptions,
      ),
    );
  }

  Future<GetSessionParticipantsResponse> getSessionParticipants(
    String sessionId,
  ) async {
    return await retryReadAfterReconnect(
      operation: 'GetSessionParticipants',
      resetChannel: _client.resetChannel,
      rpc: () => _client.multiplayerService.getSessionParticipants(
        GetSessionParticipantsRequest()..sessionId = sessionId,
        options: _defaultCallOptions,
      ),
    );
  }

  Future<void> leaveCurrentSession() async {
    await _client.multiplayerService.leaveCurrentSession(
      LeaveCurrentSessionRequest(),
      options: _defaultCallOptions,
    );
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
    return await retryReadAfterReconnect(
      operation: 'GetParticipantWorkout',
      resetChannel: _client.resetChannel,
      rpc: () => _client.multiplayerService.getParticipantWorkout(
        GetParticipantWorkoutRequest()
          ..userId = userId
          ..workoutId = workoutId,
      ),
    );
  }
}
