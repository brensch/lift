import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart' show GrpcError, StatusCode;
import '../services/toast.dart';

import '../gen/copy.dart';
import '../gen/workout/v1/group.pb.dart';
import '../logic/utils.dart' show retryDelay;
import '../services/grpc_client.dart';
import '../services/account_sync.dart';
import '../services/app_logger.dart';
import '../services/error_modal_service.dart';
import '../services/multiplayer_service.dart';
import '../theme/schlift_spec.dart';

/// The caller's multiplayer session and the requests to join them.
///
/// Membership lives on the server; the Sync stream ([AccountSync]) brings
/// who is in the session whenever that changes, and each partner's workout
/// as events, which this phone's core folds into where they're up to. This
/// provider only reflects them, and makes the online-only calls (join,
/// leave, ask).
class MultiplayerProvider extends ChangeNotifier {
  final MultiplayerServiceWrapper _service;
  final AccountSync? _feed;

  String? _sessionId;
  List<ParticipantStatus> _participants = const [];
  String? _myInviteToken;
  bool _disposed = false;
  bool _syncEnabled = false;

  /// [feed] is the signed-in account's Sync stream; null for the tutorial,
  /// which trains alone.
  MultiplayerProvider(this._service, {AccountSync? feed}) : _feed = feed {
    _feed?.addListener(_heard);
  }

  String? get sessionId => _sessionId;

  /// The partners on show, each as their workout's events fold.
  List<ParticipantStatus> get participants => _participants;
  bool get isInSession => sessionId != null;
  String? get myInviteToken => _myInviteToken;

  List<TrainingPartner> _trainingPartners = [];
  List<TrainingPartner> get trainingPartners => _trainingPartners;

  List<JoinRequest> _incomingRequests = [];
  List<JoinRequest> get incomingRequests => _incomingRequests;

  /// How long a request to join can be answered (the server's
  /// JOIN_REQUEST_TTL_SECONDS): an older one is not shown.
  static const _requestsLast = Duration(seconds: 120);

  /// Set for when the first request on show can no longer be answered.
  Timer? _expiry;

  /// The stream brought something down.
  void _heard() {
    final feed = _feed;
    if (feed == null || !_syncEnabled) return;
    unawaited(_refresh(feed));
    _showRequests(feed.joinRequests.requests);
  }

  /// Show those of [requests] that can still be answered, until the first
  /// of them can't.
  void _showRequests(List<JoinRequest> requests) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final since = (now - _requestsLast.inMilliseconds) ~/ 1000;
    requests = requests.where((r) => r.createdAt.toInt() >= since).toList();
    final changed =
        requests.map((r) => r.requestId).join(',') !=
        _incomingRequests.map((r) => r.requestId).join(',');
    _incomingRequests = requests;
    _expiry?.cancel();
    _expiry = null;
    if (requests.isNotEmpty && !_disposed) {
      final first = requests
          .map((r) => r.createdAt.toInt())
          .reduce((a, b) => a < b ? a : b);
      // The second after the last one the server still answers it in.
      final gone = (first + _requestsLast.inSeconds + 1) * 1000;
      _expiry = Timer(
        Duration(milliseconds: gone - now),
        () => _showRequests(_incomingRequests),
      );
    }
    if (changed && !_disposed) notifyListeners();
  }

  int _refreshes = 0;

  /// The session as the stream last brought it, each partner's status
  /// folded from their events (null ones are off show).
  Future<void> _refresh(AccountSync feed) async {
    final refresh = ++_refreshes;
    final session = feed.session;
    final participants = <ParticipantStatus>[];
    for (final member in session.members) {
      final status = await feed.partnerStatus(member);
      if (status != null) participants.add(status..user = member.user);
    }
    if (refresh != _refreshes || _disposed) return;
    final id = session.sessionId.isEmpty ? null : session.sessionId;
    if (id == _sessionId && listEquals(participants, _participants)) return;
    _sessionId = id;
    _participants = participants;
    notifyListeners();
  }

  void _clearSession() {
    _refreshes++;
    if (_sessionId == null && _participants.isEmpty) return;
    _sessionId = null;
    _participants = const [];
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
  /// The friends asked to train and not yet heard from: each until its
  /// request runs out on the server ([_requestLifetime], as
  /// JOIN_REQUEST_TTL_SECONDS there). A friend who accepts is in the session
  /// and no longer listed; one who declines isn't told to us, so their ask
  /// shows as pending until it runs out.
  final Map<String, DateTime> _askedUntil = {};
  final Map<String, Timer> _askExpiries = {};
  static const _requestLifetime = Duration(seconds: 120);

  /// Whether a request sent to [partnerUserId] is still waiting on them.
  bool isAskPending(String partnerUserId) =>
      _askedUntil[partnerUserId]?.isAfter(DateTime.now()) ?? false;

  void _markAsked(String partnerUserId) {
    _askedUntil[partnerUserId] = DateTime.now().add(_requestLifetime);
    _askExpiries[partnerUserId]?.cancel();
    _askExpiries[partnerUserId] = Timer(_requestLifetime, () {
      _askedUntil.remove(partnerUserId);
      _askExpiries.remove(partnerUserId);
      if (!_disposed) notifyListeners();
    });
    notifyListeners();
  }

  Future<String?> requestJoinPartner(String partnerUserId) async {
    try {
      await _service.requestJoinPartner(partnerUserId);
      _markAsked(partnerUserId);
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
  /// A failed accept is shown, as no session forms.
  Future<void> respondToJoinRequest(String requestId, bool accept) async {
    try {
      await _service.respondJoinRequest(requestId, accept);
    } catch (e) {
      AppLogger.instance.warn('Multiplayer', 'respondJoinRequest failed', {
        'error': '$e',
      });
      if (accept) {
        ErrorModalService.showError(
          e is GrpcError && e.code == StatusCode.notFound
              ? copy.joinRequest.expired
              : cleanErrorMessage(e),
        );
      }
    }
    _incomingRequests = _incomingRequests
        .where((r) => r.requestId != requestId)
        .toList();
    if (!_disposed) notifyListeners();
  }

  void startSync() {
    if (_disposed) return;
    AppLogger.instance.info('Multiplayer', 'startSync');
    _syncEnabled = true;
    unawaited(_ensureInviteToken());
    _heard();
  }

  /// The server stopped accepting this phone's session: nothing more is
  /// asked of it until [startSync] again.
  void stopSync() {
    _syncEnabled = false;
  }

  bool _inviteTokenRetryScheduled = false;
  int _inviteTokenFailures = 0;

  /// Lazily load the caller's invite token (stable across calls unless rotated).
  Future<String?> _ensureInviteToken() async {
    if (_myInviteToken != null) return _myInviteToken;
    try {
      final token = await _service.getMyInviteToken();
      _myInviteToken = token;
      _inviteTokenFailures = 0;
      if (!_disposed) notifyListeners();
      return token;
    } catch (e) {
      // A lapsed session won't get better by asking again.
      final retry = !(e is GrpcError && e.code == StatusCode.unauthenticated);
      AppLogger.instance.warn(
        'Multiplayer',
        retry
            ? 'getMyInviteToken failed, will retry'
            : 'getMyInviteToken failed',
        {'error': e.toString()},
      );
      if (retry) _scheduleInviteTokenRetry();
      return null;
    }
  }

  void _scheduleInviteTokenRetry() {
    if (_inviteTokenRetryScheduled || _disposed || !_syncEnabled) return;
    _inviteTokenRetryScheduled = true;
    Timer(retryDelay(_inviteTokenFailures++), () {
      _inviteTokenRetryScheduled = false;
      if (!_disposed && _syncEnabled) {
        unawaited(_ensureInviteToken());
      }
    });
  }

  /// Accepts either a raw invite token or a share URL containing `?join=<token>`.
  Future<String?> joinViaInvite(String tokenOrUrl) async {
    final token = _extractToken(tokenOrUrl);
    if (token.isEmpty) {
      final msg = copy.invite.invalid;
      ErrorModalService.showError(msg);
      return msg;
    }
    try {
      await _service.joinViaInvite(token);
      _syncEnabled = true;
      showToast(
        msg: copy.invite.joined,
        backgroundColor: schliftSpec.success,
        textColor: schliftSpec.onPrimary,
      );
      return null;
    } catch (e) {
      AppLogger.instance.error('Multiplayer', 'joinViaInvite failed', {
        'error': e.toString(),
      });
      final cleanError = cleanErrorMessage(e);
      ErrorModalService.showError(cleanError);
      return cleanError;
    }
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
    _syncEnabled = false;
    _clearSession();
    _myInviteToken = null;
    // The next account on this phone sees nothing of this one's.
    _trainingPartners = [];
    _incomingRequests = [];
    _expiry?.cancel();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _expiry?.cancel();
    for (final timer in _askExpiries.values) {
      timer.cancel();
    }
    _feed?.removeListener(_heard);
    super.dispose();
  }
}
