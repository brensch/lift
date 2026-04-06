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
  static const Duration _passkeyOpTimeout = Duration(seconds: 30);

  AuthService({required this.grpcClient});

  Future<void> _ensureCredentialManager() async {
    if (!_credentialManagerInitialized) {
      await _credentialManager.init(
        preferImmediatelyAvailableCredentials: false,
      );
      _credentialManagerInitialized = true;
    }
  }

  Future<AuthResponse> testLogin(String username) async {
    final response = await grpcClient.authService.testLogin(
      TestLoginRequest(username: username),
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
    final startResponse = await grpcClient.authService
        .registerStart(RegisterStartRequest(username: username))
        .timeout(
          _passkeyOpTimeout,
          onTimeout: () => throw Exception(
            'Timed out starting passkey registration. Check your connection and try again.',
          ),
        );

    // Step 2: Create passkey credential via platform API
    // Server wraps options under "publicKey" key
    final optionsJson = jsonDecode(startResponse.optionsJson);
    final credential = await _credentialManager
        .savePasskeyCredentials(
          request: CredentialCreationOptions.fromJson(optionsJson['publicKey']),
        )
        .timeout(
          _passkeyOpTimeout,
          onTimeout: () => throw Exception(
            'Timed out waiting for device passkey prompt. Try again.',
          ),
        );

    // Step 3: Send credential back to server
    final finishResponse = await grpcClient.authService
        .registerFinish(
          RegisterFinishRequest(
            userId: startResponse.userId,
            credentialJson: jsonEncode(_stripNulls(credential.toJson())),
            name: 'signup key',
          ),
        )
        .timeout(
          _passkeyOpTimeout,
          onTimeout: () => throw Exception(
            'Timed out finishing passkey registration. Try again.',
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
    final startResponse = await grpcClient.authService
        .loginStart(LoginStartRequest())
        .timeout(
          _passkeyOpTimeout,
          onTimeout: () => throw Exception(
            'Timed out starting passkey login. Check your connection and try again.',
          ),
        );

    // Step 2: Get passkey credential via platform API
    // Server wraps options under "publicKey" key
    final optionsJson = jsonDecode(startResponse.optionsJson);
    final credentials = await _credentialManager
        .getCredentials(
          passKeyOption: CredentialLoginOptions.fromJson(
            optionsJson['publicKey'],
          ),
          fetchOptions: FetchOptionsAndroid(passKey: true),
        )
        .timeout(
          _passkeyOpTimeout,
          onTimeout: () => throw Exception(
            'Timed out waiting for passkey selection. this happens if you have too many passkeys saved for this domain, or took too long picking. Delete some passkeys, or be quicker.',
          ),
        );
    final publicKeyCredential = credentials.publicKeyCredential;
    if (publicKeyCredential == null) {
      throw Exception('No passkey credential was returned by the device.');
    }

    // Step 3: Send credential back to server
    final finishResponse = await grpcClient.authService
        .loginFinish(
          LoginFinishRequest(
            challengeId: startResponse.challengeId,
            credentialJson: jsonEncode(
              _stripNulls(publicKeyCredential.toJson()),
            ),
          ),
        )
        .timeout(
          _passkeyOpTimeout,
          onTimeout: () =>
              throw Exception('Timed out finishing passkey login. Try again.'),
        );

    return AuthResponse(
      sessionToken: finishResponse.sessionToken,
      userId: finishResponse.userId,
      username: finishResponse.username,
    );
  }

  Future<List<PasskeyInfo>> listPasskeys() async {
    final response = await grpcClient.authService.listPasskeys(
      ListPasskeysRequest(),
    );
    return response.passkeys;
  }

  Future<void> addPasskey(String name) async {
    await _ensureCredentialManager();

    final startResponse = await grpcClient.authService
        .addPasskeyStart(AddPasskeyStartRequest())
        .timeout(
          _passkeyOpTimeout,
          onTimeout: () => throw Exception(
            'Timed out starting add-passkey flow. Check your connection and try again.',
          ),
        );

    final optionsJson = jsonDecode(startResponse.optionsJson);
    final credential = await _credentialManager
        .savePasskeyCredentials(
          request: CredentialCreationOptions.fromJson(optionsJson['publicKey']),
        )
        .timeout(
          _passkeyOpTimeout,
          onTimeout: () => throw Exception(
            'Timed out waiting for device passkey prompt. Try again.',
          ),
        );

    await grpcClient.authService
        .addPasskeyFinish(
          AddPasskeyFinishRequest(
            credentialJson: jsonEncode(_stripNulls(credential.toJson())),
            name: name,
          ),
        )
        .timeout(
          _passkeyOpTimeout,
          onTimeout: () => throw Exception(
            'Timed out finishing add-passkey flow. Try again.',
          ),
        );
  }

  Future<void> deletePasskey(String credentialId) async {
    await grpcClient.authService.deletePasskey(
      DeletePasskeyRequest(credentialId: credentialId),
    );
  }

  // TODO: iOS passkey support — add Associated Domains entitlement
  // (webcredentials:schlift.com) and serve apple-app-site-association

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
