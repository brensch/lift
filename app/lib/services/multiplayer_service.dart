import 'package:grpc/grpc.dart';

import '../gen/workout/v1/group.pb.dart';
import '../gen/workout/v1/group.pbgrpc.dart';
import 'grpc_client.dart';

class MultiplayerServiceWrapper {
  final GrpcClient _client;

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

  /// People the caller has trained with before (durable history), most recent first.
  Future<List<TrainingPartner>> getTrainingPartners() async {
    final response = await retryReadAfterReconnect(
      operation: 'GetTrainingPartners',
      resetChannel: _client.resetChannel,
      rpc: () => _client.multiplayerService.getTrainingPartners(
        GetTrainingPartnersRequest(),
        options: _defaultCallOptions,
      ),
    );
    return response.partners;
  }

  /// Ask a known partner to train together (creates a request they must approve).
  Future<String> requestJoinPartner(String partnerUserId) async {
    final response = await _client.multiplayerService.requestJoinPartner(
      RequestJoinPartnerRequest()..partnerUserId = partnerUserId,
      options: _defaultCallOptions,
    );
    return response.requestId;
  }

  /// The caller's incoming (pending) join requests, to prompt approve/decline.
  Future<List<JoinRequest>> getJoinRequests() async {
    final response = await _client.multiplayerService.getJoinRequests(
      GetJoinRequestsRequest(),
      options: _defaultCallOptions,
    );
    return response.requests;
  }

  /// Approve or decline a join request. Returns the session id when accepted.
  Future<String> respondJoinRequest(String requestId, bool accept) async {
    final response = await _client.multiplayerService.respondJoinRequest(
      RespondJoinRequestRequest()
        ..requestId = requestId
        ..accept = accept,
      options: _defaultCallOptions,
    );
    return response.sessionId;
  }

  Future<GetCurrentSessionResponse> getCurrentSession() async {
    return await retryReadAfterReconnect(
      operation: 'GetCurrentSession',
      resetChannel: _client.resetChannel,
      rpc: () => _client.multiplayerService.getCurrentSession(
        GetCurrentSessionRequest(),
        options: _defaultCallOptions,
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
