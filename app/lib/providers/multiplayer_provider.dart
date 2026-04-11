import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../gen/workout/v1/group.pb.dart';
import '../logic/utils.dart';
import '../services/error_modal_service.dart';
import '../services/multiplayer_service.dart';

class MultiplayerProvider extends ChangeNotifier {
  final MultiplayerServiceWrapper _service;

  static const Duration _pollInterval = Duration(seconds: 1);

  String? _sessionId;
  SessionStatus? _sessionStatus;
  bool _isLoading = false;
  Timer? _pollTimer;
  bool _disposed = false;
  bool _pollInFlight = false;

  MultiplayerProvider(this._service);

  String? get sessionId => _sessionId;
  SessionStatus? get sessionStatus => _sessionStatus;
  List<ParticipantStatus> get participants => sessionStatus?.participants ?? [];
  bool get isInSession => _sessionId != null;
  bool get isLoading => _isLoading;

  Future<void> checkForSession() async {
    try {
      final response = await _service.getCurrentSession();
      if (response.sessionId.isEmpty || !response.hasSessionStatus()) {
        _clearSession(notify: true);
        return;
      }
      _applySnapshot(
        sessionId: response.sessionId,
        status: response.sessionStatus,
        notify: true,
      );
      _ensurePolling();
    } catch (_) {}
  }

  Future<String?> joinSession(String userId, {String? workoutId}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _sessionId = await _service.joinUser(userId);
      await checkForSession();
      Fluttertoast.showToast(
        msg: "JOINED GROUP",
        backgroundColor: Colors.green.shade600,
        textColor: Colors.white,
        gravity: ToastGravity.TOP,
        fontSize: 14.0,
      );
      return null;
    } catch (e) {
      debugPrint('Error joining session: $e');
      final cleanError = cleanErrorMessage(e);
      ErrorModalService.showError(cleanError.toUpperCase());
      return cleanError;
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> leaveSession() async {
    _cancelPolling();
    try {
      await _service.leaveSession();
    } catch (_) {}
    _clearSession(notify: true);
  }

  void markLocalWorkoutFinished() {
    _cancelPolling();
    _clearSession(notify: true);
  }

  Future<void> updateActiveWorkout(String workoutId) async {
    try {
      await _service.updateActiveWorkout(workoutId);
    } catch (e) {
      debugPrint('Error updating active workout: $e');
    }
  }

  void clear() {
    _cancelPolling();
    _clearSession(notify: true);
  }

  void _applySnapshot({
    required String sessionId,
    required SessionStatus status,
    required bool notify,
  }) {
    _sessionId = sessionId;
    _sessionStatus = status;
    if (notify && !_disposed) {
      notifyListeners();
    }
  }

  void _ensurePolling() {
    final sessionId = _sessionId;
    if (sessionId == null || _disposed) return;
    _pollTimer ??= Timer.periodic(_pollInterval, (_) {
      unawaited(_pollSession());
    });
    unawaited(_pollSession());
  }

  Future<void> _pollSession() async {
    if (_disposed || _pollInFlight) return;
    final sessionId = _sessionId;
    if (sessionId == null) return;
    _pollInFlight = true;
    try {
      final response = await _service.getCurrentSession(sessionId: sessionId);
      if (response.sessionId.isEmpty || !response.hasSessionStatus()) {
        _clearSession(notify: true);
        return;
      }
      _applySnapshot(
        sessionId: response.sessionId,
        status: response.sessionStatus,
        notify: true,
      );
    } catch (e) {
      debugPrint('Error polling session: $e');
    } finally {
      _pollInFlight = false;
    }
  }

  void _cancelPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _clearSession({required bool notify}) {
    _sessionId = null;
    _sessionStatus = null;
    if (notify && !_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelPolling();
    super.dispose();
  }
}
