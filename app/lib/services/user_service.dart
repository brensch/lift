import '../gen/workout/v1/workout.pb.dart';
import '../gen/workout/v1/workout.pbgrpc.dart';
import 'grpc_client.dart';

class UserServiceWrapper {
  final GrpcClient _client;

  UserServiceWrapper(this._client);

  /// The signed-in user.
  Future<User?> getUser() async {
    final response = await retryReadAfterReconnect(
      operation: 'GetUser',
      resetChannel: _client.resetChannel,
      rpc: () => _client.userService.getUser(GetUserRequest()),
    );
    return response.hasUser() ? response.user : null;
  }

  Future<User> updateMyProfile({
    required String profileEmoji,
    required String profileColorHex,
    double? bodyWeightKg,
  }) async {
    final response = await _client.userService.updateMyProfile(
      UpdateMyProfileRequest(
        profileEmoji: profileEmoji,
        profileColorHex: profileColorHex,
        bodyWeightKg: bodyWeightKg != null && bodyWeightKg > 0
            ? bodyWeightKg.toDouble()
            : null,
      ),
    );
    return response.user;
  }

  Future<User> updateMyBodyWeight({required double bodyWeightKg}) async {
    final response = await _client.userService.updateMyProfile(
      UpdateMyProfileRequest(bodyWeightKg: bodyWeightKg),
    );
    return response.user;
  }
}
