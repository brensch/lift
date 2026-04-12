import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:passkeys/exceptions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../logic/user_profile.dart';
import '../services/auth_service.dart';
import '../services/grpc_client.dart';
import '../services/user_service.dart';
import '../logic/utils.dart';

class AuthProvider extends ChangeNotifier {
  static const _sessionTokenKey = 'liftSessionToken';
  static const _userIdKey = 'liftUserId';
  static const _usernameKey = 'liftUsername';
  static const _passkeyNoticePendingUserIdKey =
      'liftPasskeyNoticePendingUserId';

  final AuthService _authService;
  final GrpcClient _grpcClient;

  String? _userId;
  String? _username;
  String? _sessionToken;
  String _profileEmoji = defaultProfileEmoji;
  String _profileColorHex = defaultProfileColorHex;
  double _bodyWeightKg = 0;
  bool _needsPasskeyNotice = false;
  bool _isLoading = false;
  String? _error;

  AuthProvider({
    required AuthService authService,
    required GrpcClient grpcClient,
  }) : _authService = authService,
       _grpcClient = grpcClient;

  String? get userId => _userId;
  String? get username => _username;
  String? get sessionToken => _sessionToken;
  String get profileEmoji => _profileEmoji;
  String get profileColorHex => _profileColorHex;
  double get bodyWeightKg => _bodyWeightKg;
  bool get needsPasskeyNotice => _needsPasskeyNotice;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _sessionToken != null;

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionToken = prefs.getString(_sessionTokenKey);
    _userId = prefs.getString(_userIdKey);
    _username = prefs.getString(_usernameKey);
    _needsPasskeyNotice =
        _userId != null &&
        prefs.getString(_passkeyNoticePendingUserIdKey) == _userId;
    if (_sessionToken != null) {
      _grpcClient.setToken(_sessionToken);
      await refreshProfile(notify: false);
    }
    notifyListeners();
  }

  Future<void> passkeyRegister(String username) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.passkeyRegister(username);
      await _saveSession(response, needsPasskeyNotice: true);
    } catch (e) {
      if (e is! PasskeyAuthCancelledException) {
        _error = _formatError(e);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> testLogin(String username) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.testLogin(username);
      await _saveSession(response, needsPasskeyNotice: true);
    } catch (e) {
      _error = _formatError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> passkeyLogin() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.passkeyLogin();
      await _saveSession(response);
    } catch (e) {
      // Cancellation is user-initiated (or the OS dismissed the sheet) — clear
      // silently so the button just becomes tappable again without an error.
      if (e is! PasskeyAuthCancelledException) {
        _error = _formatError(e);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    if (_sessionToken != null) {
      try {
        await _authService.logout(_sessionToken!);
      } catch (_) {}
    }
    _sessionToken = null;
    _userId = null;
    _username = null;
    _profileEmoji = defaultProfileEmoji;
    _profileColorHex = defaultProfileColorHex;
    _needsPasskeyNotice = false;
    _grpcClient.setToken(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
    notifyListeners();
  }

  Future<void> expireSession({String? message}) async {
    _sessionToken = null;
    _userId = null;
    _username = null;
    _profileEmoji = defaultProfileEmoji;
    _profileColorHex = defaultProfileColorHex;
    _needsPasskeyNotice = false;
    _grpcClient.setToken(null);
    _isLoading = false;
    _error = message;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
    notifyListeners();
  }

  Future<void> _saveSession(
    AuthResponse response, {
    bool needsPasskeyNotice = false,
  }) async {
    _sessionToken = response.sessionToken;
    _userId = response.userId;
    _username = response.username;
    _needsPasskeyNotice = needsPasskeyNotice;
    _grpcClient.setToken(_sessionToken);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionTokenKey, response.sessionToken);
    await prefs.setString(_userIdKey, response.userId);
    await prefs.setString(_usernameKey, response.username);
    if (needsPasskeyNotice) {
      await prefs.setString(_passkeyNoticePendingUserIdKey, response.userId);
    }
    await refreshProfile(notify: false);
  }

  Future<void> refreshProfile({bool notify = true}) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty || _sessionToken == null) {
      return;
    }
    try {
      final user = await UserServiceWrapper(_grpcClient).getUser(userId);
      if (user == null) return;
      _profileEmoji = normalizedProfileEmoji(user.profileEmoji);
      _profileColorHex = normalizedProfileColorHex(user.profileColorHex);
      _bodyWeightKg = user.bodyWeightKg.toDouble();
      if (notify) {
        notifyListeners();
      }
    } catch (_) {
      // Keep cached profile if refresh fails.
    }
  }

  void setProfile({
    required String profileEmoji,
    required String profileColorHex,
    double? bodyWeightKg,
  }) {
    _profileEmoji = normalizedProfileEmoji(profileEmoji);
    _profileColorHex = normalizedProfileColorHex(profileColorHex);
    if (bodyWeightKg != null && bodyWeightKg > 0) _bodyWeightKg = bodyWeightKg;
    notifyListeners();
  }

  void setBodyWeight(double kg) {
    _bodyWeightKg = kg;
    notifyListeners();
  }

  Future<void> acknowledgePasskeyNotice() async {
    _needsPasskeyNotice = false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_passkeyNoticePendingUserIdKey) == _userId) {
      await prefs.remove(_passkeyNoticePendingUserIdKey);
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void setError(String message) {
    _error = message;
    notifyListeners();
  }

  static String _formatError(Object e) {
    if (e is AuthenticatorException) {
      return formatPasskeyError(e);
    }
    if (e is PlatformException) {
      return formatPlatformError(e);
    }
    return cleanErrorMessage(e);
  }
}
