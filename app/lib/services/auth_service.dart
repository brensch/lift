import 'dart:convert';
import 'dart:io' show Platform;
import 'package:credential_manager/credential_manager.dart' as cm;
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';
import '../gen/workout/v1/auth.pbgrpc.dart';
import 'app_logger.dart';
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
  final PasskeyAuthenticator _authenticator = PasskeyAuthenticator();
  final cm.CredentialManager _credentialManager = cm.CredentialManager();
  static const Duration _passkeyOpTimeout = Duration(seconds: 45);
  bool _credentialManagerInitialized = false;

  AuthService({required this.grpcClient});

  Future<void> _ensureCredentialManager() async {
    if (!Platform.isAndroid || _credentialManagerInitialized) return;
    await _credentialManager.init(preferImmediatelyAvailableCredentials: false);
    _credentialManagerInitialized = true;
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
    AppLogger.instance.info('Auth', 'passkeyRegister', {
      'phase': 'start',
      'username': username,
    });
    // Step 1: Get registration challenge from server
    final startResponse = await grpcClient.authService
        .registerStart(RegisterStartRequest(username: username))
        .timeout(
          _passkeyOpTimeout,
          onTimeout: () => throw Exception(
            'Timed out starting passkey registration. Check your connection and try again.',
          ),
        );
    AppLogger.instance.info('Auth', 'passkeyRegister', {
      'phase': 'registerStartDone',
      'userId': startResponse.userId,
    });

    // Step 2: Create passkey credential via platform API
    // Server wraps options under "publicKey" key
    final credential = await _authenticator
        .register(_registerRequestFromOptions(startResponse.optionsJson))
        .timeout(
          _passkeyOpTimeout,
          onTimeout: () => throw Exception(
            'Timed out waiting for device passkey prompt. Try again.',
          ),
        );
    AppLogger.instance.info('Auth', 'passkeyRegister', {
      'phase': 'registerPromptDone',
      'credentialId': credential.id,
    });

    // Step 3: Send credential back to server
    final finishResponse = await grpcClient.authService
        .registerFinish(
          RegisterFinishRequest(
            userId: startResponse.userId,
            credentialJson: jsonEncode(credential.toJson()),
            name: 'signup key',
          ),
        )
        .timeout(
          _passkeyOpTimeout,
          onTimeout: () => throw Exception(
            'Timed out finishing passkey registration. Try again.',
          ),
        );
    AppLogger.instance.info('Auth', 'passkeyRegister', {
      'phase': 'registerFinishDone',
      'userId': finishResponse.userId,
    });

    return AuthResponse(
      sessionToken: finishResponse.sessionToken,
      userId: finishResponse.userId,
      username: finishResponse.username,
    );
  }

  Future<AuthResponse> passkeyLogin() async {
    AppLogger.instance.info('Auth', 'passkeyLogin', {'phase': 'start'});
    try {
      // Step 1: Get authentication challenge from server (discoverable, no username)
      final startResponse = await grpcClient.authService
          .loginStart(LoginStartRequest())
          .timeout(
            _passkeyOpTimeout,
            onTimeout: () => throw Exception(
              'Timed out starting passkey login. Check your connection and try again.',
            ),
          );
      AppLogger.instance.info('Auth', 'passkeyLogin', {
        'phase': 'loginStartDone',
        'challengeId': startResponse.challengeId,
        'options': _authOptionsSummary(startResponse.optionsJson),
      });

      // Step 2: Get passkey credential via platform API
      // Server wraps options under "publicKey" key
      final credential =
          await (Platform.isAndroid
                  ? _androidAuthenticate(startResponse.optionsJson)
                  : _authenticateWithPasskeys(startResponse.optionsJson))
              .timeout(
                _passkeyOpTimeout,
                onTimeout: () => throw Exception(
                  "login timed out. if you didn't see a popup you have too many passkeys for this app, delete them all. if you did, the backend is broken.",
                ),
              );
      AppLogger.instance.info('Auth', 'passkeyLogin', {
        'phase': 'authenticateDone',
        'credentialId': credential.id,
      });

      // Step 3: Send credential back to server
      final finishResponse = await grpcClient.authService
          .loginFinish(
            LoginFinishRequest(
              challengeId: startResponse.challengeId,
              credentialJson: jsonEncode(credential.toJson()),
            ),
          )
          .timeout(
            _passkeyOpTimeout,
            onTimeout: () => throw Exception(
              'Timed out finishing passkey login. Try again.',
            ),
          );
      AppLogger.instance.info('Auth', 'passkeyLogin', {
        'phase': 'loginFinishDone',
        'userId': finishResponse.userId,
      });

      return AuthResponse(
        sessionToken: finishResponse.sessionToken,
        userId: finishResponse.userId,
        username: finishResponse.username,
      );
    } catch (error) {
      AppLogger.instance.error('Auth', 'passkeyLogin', {
        'phase': 'failed',
        'error': error.toString(),
      });
      rethrow;
    }
  }

  Future<_CredentialJsonCarrier> _androidAuthenticate(
    String optionsJson,
  ) async {
    await _ensureCredentialManager();
    final json = _publicKeyOptions(optionsJson);
    AppLogger.instance.info('Auth', 'androidAuthenticate', {
      'phase': 'start',
      'options': {
        'rpId': json['rpId'],
        'timeout': json['timeout'],
        'userVerification': json['userVerification'],
        'allowCredentialsCount':
            (json['allowCredentials'] as List?)?.length ?? 0,
      },
    });
    final credentials = await _credentialManager.getCredentials(
      passKeyOption: cm.CredentialLoginOptions.fromJson(json),
      fetchOptions: cm.FetchOptionsAndroid(passKey: true),
    );
    final credential = credentials.publicKeyCredential;
    if (credential == null) {
      AppLogger.instance.warn('Auth', 'androidAuthenticate', {
        'phase': 'noCredential',
      });
      throw Exception('No passkey credential returned by Android.');
    }
    AppLogger.instance.info('Auth', 'androidAuthenticate', {
      'phase': 'done',
      'credentialId': credential.id,
      'hasAuthenticatorData':
          credential.response?.authenticatorData?.isNotEmpty == true,
      'hasSignature': credential.response?.signature?.isNotEmpty == true,
      'hasUserHandle': credential.response?.userHandle?.isNotEmpty == true,
    });
    return _CredentialJsonCarrier(_stripNulls(credential.toJson()));
  }

  Future<_CredentialJsonCarrier> _authenticateWithPasskeys(
    String optionsJson,
  ) async {
    AppLogger.instance.info('Auth', 'iosWebAuthenticate', {
      'phase': 'start',
      'options': _authOptionsSummary(optionsJson),
    });
    final credential = await _authenticator.authenticate(
      _authenticateRequestFromOptions(optionsJson),
    );
    AppLogger.instance.info('Auth', 'iosWebAuthenticate', {
      'phase': 'done',
      'credentialId': credential.id,
    });
    return _CredentialJsonCarrier(_stripNulls(credential.toJson()));
  }

  Future<List<PasskeyInfo>> listPasskeys() async {
    final response = await grpcClient.authService.listPasskeys(
      ListPasskeysRequest(),
    );
    return response.passkeys;
  }

  Future<void> addPasskey(String name) async {
    final startResponse = await grpcClient.authService
        .addPasskeyStart(AddPasskeyStartRequest())
        .timeout(
          _passkeyOpTimeout,
          onTimeout: () => throw Exception(
            'Timed out starting add-passkey flow. Check your connection and try again.',
          ),
        );

    final credential = await _authenticator
        .register(_registerRequestFromOptions(startResponse.optionsJson))
        .timeout(
          _passkeyOpTimeout,
          onTimeout: () => throw Exception(
            'Timed out waiting for device passkey prompt. Try again.',
          ),
        );

    await grpcClient.authService
        .addPasskeyFinish(
          AddPasskeyFinishRequest(
            credentialJson: jsonEncode(credential.toJson()),
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

  Future<void> logout(String token) async {
    await grpcClient.authService.logout(LogoutRequest());
  }

  static RegisterRequestType _registerRequestFromOptions(String optionsJson) {
    final json = _publicKeyOptions(optionsJson);
    final rp = _requiredMap(json, 'rp');
    final user = _requiredMap(json, 'user');
    final authenticatorSelection = json['authenticatorSelection'];

    return RegisterRequestType(
      challenge: _requiredString(json, 'challenge'),
      relyingParty: RelyingPartyType(
        name: _requiredString(rp, 'name'),
        id: _requiredString(rp, 'id'),
      ),
      user: UserType(
        displayName: _requiredString(user, 'displayName'),
        name: _requiredString(user, 'name'),
        id: _requiredString(user, 'id'),
      ),
      excludeCredentials: _credentialList(json['excludeCredentials']),
      authSelectionType: authenticatorSelection is Map
          ? AuthenticatorSelectionType(
              authenticatorAttachment:
                  authenticatorSelection['authenticatorAttachment'] as String?,
              requireResidentKey:
                  authenticatorSelection['requireResidentKey'] == true,
              residentKey:
                  authenticatorSelection['residentKey'] as String? ??
                  (authenticatorSelection['requireResidentKey'] == true
                      ? 'required'
                      : 'preferred'),
              userVerification:
                  authenticatorSelection['userVerification'] as String? ??
                  'preferred',
            )
          : null,
      pubKeyCredParams: _pubKeyCredParams(json['pubKeyCredParams']),
      timeout: (json['timeout'] as num?)?.toInt(),
      attestation: json['attestation'] as String?,
    );
  }

  static AuthenticateRequestType _authenticateRequestFromOptions(
    String optionsJson,
  ) {
    final json = _publicKeyOptions(optionsJson);
    return AuthenticateRequestType(
      relyingPartyId: _requiredString(json, 'rpId'),
      challenge: _requiredString(json, 'challenge'),
      mediation: MediationType.Optional,
      preferImmediatelyAvailableCredentials: true,
      timeout: (json['timeout'] as num?)?.toInt(),
      userVerification: json['userVerification'] as String?,
      allowCredentials: _nullableCredentialList(json['allowCredentials']),
    );
  }

  static Map<String, dynamic> _stripNulls(Map<String, dynamic> json) {
    final result = <String, dynamic>{};
    json.forEach((key, value) {
      if (value == null) return;
      if (value is Map) {
        final stripped = _stripNulls(Map<String, dynamic>.from(value));
        if (stripped.isNotEmpty) result[key] = stripped;
        return;
      }
      result[key] = value;
    });
    return result;
  }

  static Map<String, dynamic> _authOptionsSummary(String optionsJson) {
    final json = _publicKeyOptions(optionsJson);
    return {
      'rpId': json['rpId'],
      'timeout': json['timeout'],
      'userVerification': json['userVerification'],
      'allowCredentialsCount': (json['allowCredentials'] as List?)?.length ?? 0,
    };
  }

  static Map<String, dynamic> _publicKeyOptions(String optionsJson) {
    final decoded = jsonDecode(optionsJson);
    if (decoded is! Map) {
      throw FormatException('Expected passkey options JSON object.');
    }
    final publicKey = decoded['publicKey'] ?? decoded;
    if (publicKey is! Map) {
      throw FormatException('Expected passkey publicKey options object.');
    }
    return Map<String, dynamic>.from(publicKey);
  }

  static Map<String, dynamic> _requiredMap(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value is! Map) {
      throw FormatException('Expected "$key" to be a JSON object.');
    }
    return Map<String, dynamic>.from(value);
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Expected "$key" to be a non-empty string.');
    }
    return value;
  }

  static List<CredentialType> _credentialList(Object? value) =>
      _nullableCredentialList(value) ?? [];

  static List<CredentialType>? _nullableCredentialList(Object? value) {
    if (value is! List || value.isEmpty) return null;
    return value.whereType<Map>().map((credential) {
      return CredentialType(
        type: credential['type'] as String? ?? 'public-key',
        id: credential['id'] as String? ?? '',
        transports:
            (credential['transports'] as List?)?.whereType<String>().toList() ??
            const [],
      );
    }).toList();
  }

  static List<PubKeyCredParamType>? _pubKeyCredParams(Object? value) {
    if (value is! List || value.isEmpty) return null;
    return value.whereType<Map>().map((param) {
      return PubKeyCredParamType(
        type: param['type'] as String? ?? 'public-key',
        alg: (param['alg'] as num).toInt(),
      );
    }).toList();
  }
}

class _CredentialJsonCarrier {
  final Map<String, dynamic> _json;

  _CredentialJsonCarrier(this._json);

  String? get id => _json['id'] as String?;

  Map<String, dynamic> toJson() => _json;
}
