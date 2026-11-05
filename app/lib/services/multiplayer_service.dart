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

  /// Who else was in each of [sessionIds] the caller was in, in one call.
  Future<List<SessionRoster>> getSessionRosters(
    Iterable<String> sessionIds,
  ) async {
    final response = await retryReadAfterReconnect(
      operation: 'GetSessionRosters',
      resetChannel: _client.resetChannel,
      rpc: () => _client.multiplayerService.getSessionRosters(
        GetSessionRostersRequest(sessionIds: sessionIds),
        options: _defaultCallOptions,
      ),
    );
    return response.rosters;
  }
}
