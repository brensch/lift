import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/grpc_client.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final GrpcClient _grpcClient;

  String? _userId;
  String? _username;
  String? _sessionToken;
  bool _isLoading = false;
  String? _error;

  AuthProvider({
    required AuthService authService,
    required GrpcClient grpcClient,
  })  : _authService = authService,
        _grpcClient = grpcClient;

  String? get userId => _userId;
  String? get username => _username;
  String? get sessionToken => _sessionToken;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _sessionToken != null;

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionToken = prefs.getString('liftSessionToken');
    _userId = prefs.getString('liftUserId');
    _username = prefs.getString('liftUsername');
    if (_sessionToken != null) {
      _grpcClient.setToken(_sessionToken);
    }
    notifyListeners();
  }

  Future<void> register(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.register(username, password);
      await _saveSession(response);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.login(username, password);
      await _saveSession(response);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> passkeyRegister(String username) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.passkeyRegister(username);
      await _saveSession(response);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> passkeyLogin() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.passkeyLogin();
      await _saveSession(response);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
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
    _grpcClient.setToken(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('liftSessionToken');
    await prefs.remove('liftUserId');
    await prefs.remove('liftUsername');
    notifyListeners();
  }

  Future<void> _saveSession(AuthResponse response) async {
    _sessionToken = response.sessionToken;
    _userId = response.userId;
    _username = response.username;
    _grpcClient.setToken(_sessionToken);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('liftSessionToken', response.sessionToken);
    await prefs.setString('liftUserId', response.userId);
    await prefs.setString('liftUsername', response.username);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
