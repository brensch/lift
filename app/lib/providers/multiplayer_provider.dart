import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../gen/workout/v1/group.pb.dart';
import '../logic/utils.dart';
import '../services/app_logger.dart';
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
  bool _syncEnabled = false;

  MultiplayerProvider(this._service);

  String? get sessionId => _sessionId;
  SessionStatus? get sessionStatus => _sessionStatus;
  List<ParticipantStatus> get participants => sessionStatus?.participants ?? [];
  bool get isInSession => _sessionId != null;
  bool get isLoading => _isLoading;

  void startSync() {
    if (_disposed) return;
    AppLogger.instance.info('Multiplayer', 'startSync');
    _syncEnabled = true;
    _ensurePolling();
  }

  void stopSync({bool clearSession = true}) {
    AppLogger.instance.info('Multiplayer', 'stopSync', {'clearSession': clearSession});
    _syncEnabled = false;
    _cancelPolling();
    if (clearSession) {
      _clearSession(notify: true);
    }
  }

  Future<void> checkForSession() async {
    if (_disposed) return;
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
      _syncEnabled = true;
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
      AppLogger.instance.error('Multiplayer', 'joinSession failed', {'error': e.toString()});
      final cleanError = cleanErrorMessage(e);
      ErrorModalService.showError(cleanError.toUpperCase());
      return cleanError;
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> leaveSession() async {
    try {
      await _service.leaveSession();
    } catch (_) {}
    _clearSession(notify: true);
    if (_syncEnabled) {
      _ensurePolling();
    } else {
      _cancelPolling();
    }
  }

  void markLocalWorkoutFinished() {
    _clearSession(notify: true);
    if (_syncEnabled) {
      _ensurePolling();
    } else {
      _cancelPolling();
    }
  }

  Future<void> updateActiveWorkout(String workoutId) async {
    try {
      await _service.updateActiveWorkout(workoutId);
    } catch (e) {
      AppLogger.instance.warn('Multiplayer', 'updateActiveWorkout failed', {'error': e.toString()});
    }
  }

  void clear() {
    stopSync(clearSession: true);
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
    if (_disposed || !_syncEnabled) return;
    _pollTimer ??= Timer.periodic(_pollInterval, (_) {
      unawaited(_pollSession());
    });
    unawaited(_pollSession());
  }

  Future<void> _pollSession() async {
    if (_disposed || _pollInFlight) return;
    _pollInFlight = true;
    try {
      final sessionId = _sessionId;
      final response = sessionId == null
          ? await _service.getCurrentSession()
          : await _service.getCurrentSession(sessionId: sessionId);
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
      AppLogger.instance.warn('Multiplayer', 'poll error', {
        'error': e.toString(),
      });
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
