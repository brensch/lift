import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../gen/workout/v1/group.pb.dart';
import '../logic/utils.dart';
import '../services/account_sync.dart';
import '../services/app_logger.dart';
import '../services/error_modal_service.dart';
import '../services/multiplayer_service.dart';
import '../theme/schlift_spec.dart';

/// The caller's multiplayer session and the requests to join them.
///
/// Membership lives on the server (`user_current_session`); the Sync stream
/// ([AccountSync]) pushes the session, whole, whenever anyone in it does
/// anything, and the requests whenever they change. This provider only
/// reflects them, and makes the online-only calls (join, leave, ask).
class MultiplayerProvider extends ChangeNotifier {
  final MultiplayerServiceWrapper _service;
  final AccountSync? _feed;

  String? _sessionId;
  SessionStatus? _sessionStatus;
  String? _myInviteToken;
  bool _isLoading = false;
  bool _disposed = false;
  bool _syncEnabled = false;

  /// [feed] is the signed-in account's Sync stream; null for the tutorial,
  /// which trains alone.
  MultiplayerProvider(this._service, {AccountSync? feed}) : _feed = feed {
    _feed?.addListener(_heard);
  }

  String? get sessionId => _sessionId;
  SessionStatus? get sessionStatus => _sessionStatus;
  List<ParticipantStatus> get participants => sessionStatus?.participants ?? [];
  bool get isInSession => sessionId != null;
  bool get isLoading => _isLoading;
  String? get myInviteToken => _myInviteToken;

  List<TrainingPartner> _trainingPartners = [];
  List<TrainingPartner> get trainingPartners => _trainingPartners;

  List<JoinRequest> _incomingRequests = [];
  List<JoinRequest> get incomingRequests => _incomingRequests;

  /// The stream brought something down.
  void _heard() {
    final feed = _feed;
    if (feed == null || !_syncEnabled) return;
    _apply(feed.session);
    final requests = feed.joinRequests.requests;
    final changed =
        requests.map((r) => r.requestId).join(',') !=
        _incomingRequests.map((r) => r.requestId).join(',');
    _incomingRequests = requests;
    if (changed && !_disposed) notifyListeners();
  }

  void _apply(GetCurrentSessionResponse response) {
    final id = response.sessionId.isEmpty || !response.hasSessionStatus()
        ? null
        : response.sessionId;
    final status = id == null ? null : response.sessionStatus;
    if (id == _sessionId && status == _sessionStatus) return;
    _sessionId = id;
    _sessionStatus = status;
    if (!_disposed) notifyListeners();
  }

  /// Load the caller's training-partner history (people they've trained with),
  /// so the pairing UI can offer familiar faces for a one-tap re-pair.
  Future<void> loadTrainingPartners() async {
    try {
      _trainingPartners = await _service.getTrainingPartners();
      notifyListeners();
    } catch (e) {
      AppLogger.instance.warn('Multiplayer', 'getTrainingPartners failed', {
        'error': '$e',
      });
    }
  }

  /// Ask a known partner to train together. Returns null on success, or a
  /// human-readable message on failure. They must approve before you're paired.
  Future<String?> requestJoinPartner(String partnerUserId) async {
    try {
      await _service.requestJoinPartner(partnerUserId);
      return null;
    } catch (e) {
      AppLogger.instance.warn('Multiplayer', 'requestJoinPartner failed', {
        'error': '$e',
      });
      return cleanErrorMessage(e);
    }
  }

  /// Approve or decline an incoming request. On approve the stream brings
  /// the shared session down as soon as it exists.
  Future<void> respondToJoinRequest(String requestId, bool accept) async {
    try {
      await _service.respondJoinRequest(requestId, accept);
    } catch (e) {
      AppLogger.instance.warn('Multiplayer', 'respondJoinRequest failed', {
        'error': '$e',
      });
    }
    _incomingRequests = _incomingRequests
        .where((r) => r.requestId != requestId)
        .toList();
    if (!_disposed) notifyListeners();
    if (accept) await checkForSession();
  }

  void startSync() {
    if (_disposed) return;
    AppLogger.instance.info('Multiplayer', 'startSync');
    _syncEnabled = true;
    unawaited(_ensureInviteToken());
    _heard();
  }

  void stopSync({bool clearSession = true, bool clearInviteToken = false}) {
    _syncEnabled = false;
    if (clearSession) _apply(GetCurrentSessionResponse());
    if (clearInviteToken) _myInviteToken = null;
  }

  /// Ask for the session now, rather than waiting for the stream (straight
  /// after joining).
  Future<void> checkForSession() async {
    if (_disposed) return;
    try {
      _apply(await _service.getCurrentSession());
    } catch (_) {
      // The stream brings it anyway.
    }
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
      AppLogger.instance.warn(
        'Multiplayer',
        'getMyInviteToken failed, will retry',
        {'error': e.toString()},
      );
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
        backgroundColor: schliftSpec.success,
        textColor: schliftSpec.onPrimary,
        gravity: ToastGravity.TOP,
        fontSize: schliftSpec.size.body,
      );
      return null;
    } catch (e) {
      AppLogger.instance.error('Multiplayer', 'joinViaInvite failed', {
        'error': e.toString(),
      });
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
      AppLogger.instance.warn('Multiplayer', 'leaveCurrentSession failed', {
        'error': e.toString(),
      });
    }
    _apply(GetCurrentSessionResponse());
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

  void clear() {
    stopSync(clearSession: true, clearInviteToken: true);
  }

  @override
  void dispose() {
    _disposed = true;
    _feed?.removeListener(_heard);
    super.dispose();
  }
}
