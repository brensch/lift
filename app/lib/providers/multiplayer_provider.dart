import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../gen/workout/v1/group.pb.dart';
import '../logic/utils.dart';
import '../services/app_logger.dart';
import '../services/error_modal_service.dart';
import '../services/multiplayer_service.dart';

/// Tracks the caller's current multiplayer session.
///
/// Membership invariant lives on the server in `user_current_session`. This provider
/// simply reflects what `GetCurrentSession` returns — there's no client-side pending
/// state because the server knows the caller is in a group the moment they join.
class MultiplayerProvider extends ChangeNotifier {
  final MultiplayerServiceWrapper _service;

  static const Duration _pollInterval = Duration(seconds: 1);

  String? _sessionId;
  SessionStatus? _sessionStatus;
  String? _myInviteToken;
  bool _isLoading = false;
  Timer? _pollTimer;
  bool _disposed = false;
  bool _pollInFlight = false;
  bool _syncEnabled = false;

  MultiplayerProvider(this._service);

  String? get sessionId => _sessionId;
  SessionStatus? get sessionStatus => _sessionStatus;
  List<ParticipantStatus> get participants => sessionStatus?.participants ?? [];
  bool get isInSession => sessionId != null;
  bool get isLoading => _isLoading;
  String? get myInviteToken => _myInviteToken;

  List<TrainingPartner> _trainingPartners = [];
  List<TrainingPartner> get trainingPartners => _trainingPartners;

  /// Load the caller's training-partner history (people they've trained with),
  /// so the pairing UI can offer familiar faces for a one-tap re-pair.
  Future<void> loadTrainingPartners() async {
    try {
      _trainingPartners = await _service.getTrainingPartners();
      notifyListeners();
    } catch (e) {
      AppLogger.instance
          .warn('Multiplayer', 'getTrainingPartners failed', {'error': '$e'});
    }
  }

  /// One-tap re-pair: join a known partner's current session. Returns null on
  /// success, or a human-readable message if the partner isn't joinable.
  Future<String?> joinPartnerSession(String partnerUserId) async {
    try {
      final sessionId = await _service.joinPartnerSession(partnerUserId);
      _sessionId = sessionId;
      await checkForSession();
      return null;
    } catch (e) {
      AppLogger.instance
          .warn('Multiplayer', 'joinPartnerSession failed', {'error': '$e'});
      return cleanErrorMessage(e);
    }
  }

  void startSync() {
    if (_disposed) return;
    AppLogger.instance.info('Multiplayer', 'startSync');
    _syncEnabled = true;
    unawaited(_ensureInviteToken());
    _ensurePolling();
  }

  void stopSync({bool clearSession = true, bool clearInviteToken = false}) {
    AppLogger.instance.info('Multiplayer', 'stopSync', {'clearSession': clearSession});
    _syncEnabled = false;
    _cancelPolling();
    if (clearSession) {
      _clearSession(notify: true);
    }
    if (clearInviteToken) {
      _myInviteToken = null;
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

  bool _inviteTokenRetryScheduled = false;

  /// Lazily load the caller's invite token (stable across calls unless rotated).
  Future<String?> _ensureInviteToken() async {
    if (_myInviteToken != null) return _myInviteToken;
    try {
      final token = await _service.getMyInviteToken();
      _myInviteToken = token;
      _inviteTokenRetryScheduled = false;
      if (!_disposed) notifyListeners();
      return token;
    } catch (e) {
      AppLogger.instance.warn('Multiplayer', 'getMyInviteToken failed, will retry', {'error': e.toString()});
      _scheduleInviteTokenRetry();
      return null;
    }
  }

  void _scheduleInviteTokenRetry() {
    if (_inviteTokenRetryScheduled || _disposed || !_syncEnabled) return;
    _inviteTokenRetryScheduled = true;
    Timer(const Duration(seconds: 5), () {
      _inviteTokenRetryScheduled = false;
      if (!_disposed && _syncEnabled) {
        unawaited(_ensureInviteToken());
      }
    });
  }

  Future<String?> refreshInviteToken() => _ensureInviteToken();

  Future<String?> rotateInviteToken() async {
    try {
      final token = await _service.rotateInviteToken();
      _myInviteToken = token;
      if (!_disposed) notifyListeners();
      return token;
    } catch (e) {
      AppLogger.instance.warn('Multiplayer', 'rotateInviteToken failed', {'error': e.toString()});
      return null;
    }
  }

  /// Accepts either a raw invite token or a share URL containing `?join=<token>`.
  Future<String?> joinViaInvite(String tokenOrUrl) async {
    final token = _extractToken(tokenOrUrl);
    if (token.isEmpty) {
      final msg = 'INVALID INVITE CODE';
      ErrorModalService.showError(msg);
      return msg;
    }
    _isLoading = true;
    notifyListeners();
    try {
      await _service.joinViaInvite(token);
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
      AppLogger.instance.error('Multiplayer', 'joinViaInvite failed', {'error': e.toString()});
      final cleanError = cleanErrorMessage(e);
      ErrorModalService.showError(cleanError.toUpperCase());
      return cleanError;
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> leaveCurrentSession() async {
    try {
      await _service.leaveCurrentSession();
    } catch (e) {
      AppLogger.instance.warn('Multiplayer', 'leaveCurrentSession failed', {'error': e.toString()});
    }
    _clearSession(notify: true);
  }

  String _extractToken(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.queryParameters['join'] != null) {
      return uri.queryParameters['join']!.trim();
    }
    return trimmed;
  }

  void markLocalWorkoutFinished() {
    // The server clears user_current_session on EndWorkout, so our next poll
    // will come back empty and _clearSession is called. Nothing to do here
    // beyond ensuring a poll happens soon.
    if (_syncEnabled) {
      _ensurePolling();
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
    stopSync(clearSession: true, clearInviteToken: true);
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
