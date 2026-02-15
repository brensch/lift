import '../gen/workout/v1/auth.pbgrpc.dart';
import 'grpc_client.dart';

class AuthResponse {
  final String sessionToken;
  final String userId;
  final String username;

  AuthResponse({
    required this.sessionToken,
    required this.userId,
    required this.username,
  });
}

class AuthService {
  final GrpcClient grpcClient;

  AuthService({required this.grpcClient});

  Future<AuthResponse> register(String username, String password) async {
    final response = await grpcClient.authService.passwordRegister(
      PasswordRegisterRequest(username: username, password: password),
    );

    return AuthResponse(
      sessionToken: response.sessionToken,
      userId: response.userId,
      username: response.username,
    );
  }

  Future<AuthResponse> login(String username, String password) async {
    final response = await grpcClient.authService.passwordLogin(
      PasswordLoginRequest(username: username, password: password),
    );

    return AuthResponse(
      sessionToken: response.sessionToken,
      userId: response.userId,
      username: response.username,
    );
  }

  Future<void> logout(String token) async {
    // Note: The token is already set in the GrpcClient interceptor if logged in.
    // But we pass it to LogoutRequest if needed, or just rely on interceptor.
    await grpcClient.authService.logout(LogoutRequest());
  }
}
