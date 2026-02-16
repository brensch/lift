import 'dart:convert';
import 'package:credential_manager/credential_manager.dart';
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
  final CredentialManager _credentialManager = CredentialManager();
  bool _credentialManagerInitialized = false;

  AuthService({required this.grpcClient});

  Future<void> _ensureCredentialManager() async {
    if (!_credentialManagerInitialized) {
      await _credentialManager.init(preferImmediatelyAvailableCredentials: false);
      _credentialManagerInitialized = true;
    }
  }

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

  Future<AuthResponse> passkeyRegister(String username) async {
    await _ensureCredentialManager();

    // Step 1: Get registration challenge from server
    final startResponse = await grpcClient.authService.registerStart(
      RegisterStartRequest(username: username),
    );

    // Step 2: Create passkey credential via platform API
    // Server wraps options under "publicKey" key
    final optionsJson = jsonDecode(startResponse.optionsJson);
    final credential = await _credentialManager.savePasskeyCredentials(
      request: CredentialCreationOptions.fromJson(
        optionsJson['publicKey'],
      ),
    );

    // Step 3: Send credential back to server
    final finishResponse = await grpcClient.authService.registerFinish(
      RegisterFinishRequest(
        userId: startResponse.userId,
        credentialJson: jsonEncode(_stripNulls(credential.toJson())),
        name: 'android',
      ),
    );

    return AuthResponse(
      sessionToken: finishResponse.sessionToken,
      userId: finishResponse.userId,
      username: finishResponse.username,
    );
  }

  Future<AuthResponse> passkeyLogin() async {
    await _ensureCredentialManager();

    // Step 1: Get authentication challenge from server (discoverable, no username)
    final startResponse = await grpcClient.authService.loginStart(
      LoginStartRequest(),
    );

    // Step 2: Get passkey credential via platform API
    // Server wraps options under "publicKey" key
    final optionsJson = jsonDecode(startResponse.optionsJson);
    final credentials = await _credentialManager.getCredentials(
      passKeyOption: CredentialLoginOptions.fromJson(
        optionsJson['publicKey'],
      ),
    );

    // Step 3: Send credential back to server
    final finishResponse = await grpcClient.authService.loginFinish(
      LoginFinishRequest(
        challengeId: startResponse.challengeId,
        credentialJson: jsonEncode(_stripNulls(credentials.publicKeyCredential!.toJson())),
      ),
    );

    return AuthResponse(
      sessionToken: finishResponse.sessionToken,
      userId: finishResponse.userId,
      username: finishResponse.username,
    );
  }

  // TODO: iOS passkey support — add Associated Domains entitlement
  // (webcredentials:lift.snek2.ddns.net) and serve apple-app-site-association

  Future<void> logout(String token) async {
    await grpcClient.authService.logout(LogoutRequest());
  }

  /// Recursively strip null values from a JSON map for clean serialization.
  static Map<String, dynamic> _stripNulls(Map<String, dynamic> json) {
    final result = <String, dynamic>{};
    json.forEach((key, value) {
      if (value == null) return;
      if (value is Map<String, dynamic>) {
        final stripped = _stripNulls(value);
        if (stripped.isNotEmpty) result[key] = stripped;
      } else {
        result[key] = value;
      }
    });
    return result;
  }
}
