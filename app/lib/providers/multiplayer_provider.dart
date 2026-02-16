import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
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
    _startPolling();
    try {
      final response = await _service.getCurrentSession();
      if (response.sessionId.isNotEmpty) {
        _sessionId = response.sessionId;
        _sessionStatus = response.sessionStatus;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> joinSession(String userId, {String? workoutId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _sessionId = await _service.joinUser(userId);
      Fluttertoast.showToast(
        msg: "JOINED GROUP",
        backgroundColor: Colors.green.shade600,
        textColor: Colors.white,
        gravity: ToastGravity.TOP,
        fontSize: 14.0,
      );
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
    notifyListeners();
  }

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _poll() async {
    try {
      final response = await _service.getCurrentSession(sessionId: _sessionId ?? "");
      if (response.sessionId.isNotEmpty) {
        _sessionId = response.sessionId;
        if (response.hasSessionStatus()) {
          _sessionStatus = response.sessionStatus;
        }
        notifyListeners();
      } else {
        if (_sessionId != null) {
          _sessionId = null;
          _sessionStatus = null;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
