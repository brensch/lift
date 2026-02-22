import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../gen/workout/v1/group.pb.dart';
import '../services/multiplayer_service.dart';
import '../services/error_modal_service.dart';
import '../logic/utils.dart';

class MultiplayerProvider extends ChangeNotifier {
  final MultiplayerServiceWrapper _service;

  String? _sessionId;
  SessionStatus? _sessionStatus;
  Timer? _pollTimer;
  bool _isLoading = false;
  // How many consecutive polls have returned an empty session.
  // We only clear the local session after several consecutive empties so a
  // single transient failure doesn't wipe the "who's up next" bar.
  int _consecutiveEmptyPolls = 0;
  static const int _clearSessionAfterEmpties = 3;

  MultiplayerProvider(this._service);

  String? get sessionId => _sessionId;
  SessionStatus? get sessionStatus => _sessionStatus;
  List<ParticipantStatus> get participants =>
      _sessionStatus?.participants ?? [];
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

  Future<String?> joinSession(String userId, {String? workoutId}) async {
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
      return null; // Success
    } catch (e) {
      debugPrint('Error joining session: $e');
      final cleanError = cleanErrorMessage(e);
      ErrorModalService.showError(cleanError.toUpperCase());
      return cleanError;
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
    _consecutiveEmptyPolls = 0;
    notifyListeners();
  }

  void markLocalWorkoutFinished() {
    if (_sessionId == null) return;
    _sessionId = null;
    _sessionStatus = null;
    _consecutiveEmptyPolls = 0;
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
    _consecutiveEmptyPolls = 0;
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

  /// Trigger an immediate poll right now (called after set operations so the
  /// session state updates without waiting for the next 1-second tick).
  Future<void> refreshNow() => _poll();

  Future<void> _poll() async {
    try {
      final response = await _service.getCurrentSession(sessionId: _sessionId);
      if (response.sessionId.isNotEmpty) {
        _consecutiveEmptyPolls = 0;
        _sessionId = response.sessionId;
        if (response.hasSessionStatus()) {
          _sessionStatus = response.sessionStatus;
        }
        notifyListeners();
      } else {
        _consecutiveEmptyPolls++;
        // Only clear the local session after several consecutive empty
        // responses to avoid the bar disappearing on a single blip.
        if (_sessionId != null &&
            _consecutiveEmptyPolls >= _clearSessionAfterEmpties) {
          _sessionId = null;
          _sessionStatus = null;
          _consecutiveEmptyPolls = 0;
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
