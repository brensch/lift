import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:passkeys/exceptions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../logic/user_profile.dart';
import '../services/auth_service.dart';
import '../services/app_logger.dart';
import '../services/grpc_client.dart';
import '../services/health_service.dart';
import '../services/user_service.dart';
import '../logic/utils.dart';

class AuthProvider extends ChangeNotifier {
  static const _sessionTokenKey = 'liftSessionToken';
  static const _userIdKey = 'liftUserId';
  static const _usernameKey = 'liftUsername';

  final AuthService _authService;
  final GrpcClient _grpcClient;

  String? _userId;
  String? _username;
  String? _sessionToken;
  String _profileEmoji = defaultProfileEmoji;
  String _profileColorHex = defaultProfileColorHex;
  double _bodyWeightKg = 0;
  bool _isLoading = false;
  bool _sessionLoaded = false;
  Future<void>? _initialProfileLoad;
  bool _bodyWeightHealthSyncInFlight = false;
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
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _sessionToken != null;

  /// False until [loadSession] has read the saved session from disk. Until
  /// then "not logged in" only means "not known yet", and the router must not
  /// act on it — that is what used to flash the login screen at a signed-in
  /// user on every cold start.
  bool get sessionLoaded => _sessionLoaded;

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionToken = prefs.getString(_sessionTokenKey);
    _userId = prefs.getString(_userIdKey);
    _username = prefs.getString(_usernameKey);
    if (_sessionToken != null) {
      _grpcClient.setToken(_sessionToken);
    }
    // Publish the session as soon as it is known. The profile (emoji, colour,
    // body weight) is cosmetic, fetched over the network, and announces itself
    // when it lands; waiting for it here held every cold start on a round trip
    // — tens of seconds on a phone whose radio was asleep.
    _sessionLoaded = true;
    // Started before notifying so that listeners reacting to the login can
    // wait on it (see syncBodyWeightFromHealth).
    _initialProfileLoad = _sessionToken != null ? refreshProfile() : null;
    notifyListeners();
    await _initialProfileLoad;
  }

  Future<void> passkeyRegister(String username) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.passkeyRegister(username);
      await _saveSession(response);
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
      await _saveSession(response);
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
    _grpcClient.setToken(null);
    _isLoading = false;
    _error = message;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
    notifyListeners();
  }

  Future<void> _saveSession(AuthResponse response) async {
    _sessionToken = response.sessionToken;
    _userId = response.userId;
    _username = response.username;
    _grpcClient.setToken(_sessionToken);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionTokenKey, response.sessionToken);
    await prefs.setString(_userIdKey, response.userId);
    await prefs.setString(_usernameKey, response.username);
    await refreshProfile(notify: false);
  }

  bool _profileRefreshRetryScheduled = false;

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
      _profileRefreshRetryScheduled = false;
      if (notify) {
        notifyListeners();
      }
    } catch (e) {
      AppLogger.instance.warn('Auth', 'refreshProfile failed, will retry', {
        'error': e.toString(),
      });
      _scheduleProfileRetry();
    }
  }

  void _scheduleProfileRetry() {
    if (_profileRefreshRetryScheduled) return;
    _profileRefreshRetryScheduled = true;
    Timer(const Duration(seconds: 5), () {
      _profileRefreshRetryScheduled = false;
      refreshProfile();
    });
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

  Future<double?> syncBodyWeightFromHealth({
    bool requestPermissions = false,
  }) async {
    if (_bodyWeightHealthSyncInFlight || _sessionToken == null) return null;
    _bodyWeightHealthSyncInFlight = true;
    try {
      // Compare against the server's body weight, not the 0 we start with.
      await _initialProfileLoad;
      final importedKg = await HealthService.readLatestBodyWeightKg(
        requestPermissions: requestPermissions,
      );
      if (importedKg == null || importedKg <= 0) return null;

      final changed = (_bodyWeightKg - importedKg).abs() >= 0.05;
      if (!changed) {
        AppLogger.instance.info('Auth', 'bodyweight sync skipped', {
          'reason': 'unchanged',
          'bodyWeightKg': importedKg,
        });
        return importedKg;
      }

      final user = await UserServiceWrapper(
        _grpcClient,
      ).updateMyBodyWeight(bodyWeightKg: importedKg);
      _bodyWeightKg = user.bodyWeightKg.toDouble();
      AppLogger.instance.info('Auth', 'bodyweight sync applied', {
        'bodyWeightKg': _bodyWeightKg,
      });
      notifyListeners();
      return _bodyWeightKg;
    } catch (e) {
      AppLogger.instance.warn('Auth', 'bodyweight sync failed', {
        'error': e.toString(),
      });
      return null;
    } finally {
      _bodyWeightHealthSyncInFlight = false;
    }
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
