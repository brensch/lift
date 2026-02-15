import 'dart:async';
import 'package:flutter/foundation.dart';
import '../gen/workout/v1/group.pb.dart';
import '../services/multiplayer_service.dart';

class MultiplayerProvider extends ChangeNotifier {
  final MultiplayerServiceWrapper _service;

  String? _sessionId;
  SessionStatus? _sessionStatus;
  Timer? _pollTimer;
  bool _isLoading = false;

  MultiplayerProvider(this._service);

  String? get sessionId => _sessionId;
  SessionStatus? get sessionStatus => _sessionStatus;
  List<ParticipantStatus> get participants => _sessionStatus?.participants ?? [];
  bool get isInSession => _sessionId != null;
  bool get isLoading => _isLoading;

  Future<void> checkForSession() async {
    try {
      final response = await _service.getCurrentSession();
      if (response.sessionId.isNotEmpty) {
        _sessionId = response.sessionId;
        _sessionStatus = response.sessionStatus;
        _startPolling();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<String?> startSession({String? workoutId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _sessionId = await _service.startSession(workoutId: workoutId);
      _startPolling();
      return _sessionId;
    } catch (e) {
      debugPrint('Error starting session: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> joinSession(String sessionId, {String? workoutId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _sessionId = await _service.joinSession(sessionId, workoutId: workoutId);
      _startPolling();
      return true;
    } catch (e) {
      debugPrint('Error joining session: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> leaveSession() async {
    try {
      await _service.leaveSession();
    } catch (_) {}
    _sessionId = null;
    _sessionStatus = null;
    _stopPolling();
    notifyListeners();
  }

  Future<void> updateActiveWorkout(String workoutId) async {
    try {
      await _service.updateActiveWorkout(workoutId);
    } catch (e) {
      debugPrint('Error updating active workout: $e');
    }
  }

  void clear() {
    _sessionId = null;
    _sessionStatus = null;
    _stopPolling();
    notifyListeners();
  }

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _poll() async {
    if (_sessionId == null) return;
    try {
      final response = await _service.getCurrentSession(sessionId: _sessionId);
      if (response.hasSessionStatus()) {
        _sessionStatus = response.sessionStatus;
        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
