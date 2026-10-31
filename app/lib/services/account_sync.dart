/// The signed-in account: its file on this phone, and the Sync stream that
/// keeps the server's copy level with it.
///
/// Everything works with no connection; the stream only carries the account
/// up (as events, acknowledged by seq) and the session down. It is the fast
/// path, never the record: an event leaves the outbox only when the server
/// acknowledges it, and is sent again after any reconnect. A heartbeat every
/// few seconds, answered by the server, catches a link that died quietly
/// (half-open wifi) within [_silenceLimit]; the stream is then dropped and
/// dialled again, with backoff (to 10 s) while the server stays out of reach.
library;

import 'dart:async';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/widgets.dart';
import 'package:grpc/grpc.dart';
import 'package:path_provider/path_provider.dart';

import '../gen/workout/v1/account.pb.dart';
import '../gen/workout/v1/group.pb.dart';
import 'app_logger.dart';
import 'grpc_client.dart';
import 'local_core.dart';
import 'workout_service.dart';

class AccountSync extends ChangeNotifier
    with WidgetsBindingObserver
    implements CoreSource {
  final GrpcClient _grpc;

  AccountSync(this._grpc) {
    WidgetsBinding.instance.addObserver(this);
  }

  static const _tag = 'Sync';
  static const _heartbeatEvery = Duration(seconds: 5);
  static const _silenceLimit = Duration(seconds: 15);
  static const _maxBackoff = Duration(seconds: 10);

  LocalCore? _core;
  String? _userId;
  Completer<LocalCore> _ready = Completer<LocalCore>();
  StreamSubscription<void>? _writesSub;

  @override
  Future<LocalCore> get ready => _ready.future;

  /// The open account, or null before sign-in.
  LocalCore? get core => _core;

  // ── What the stream brings down ──

  GetCurrentSessionResponse _session = GetCurrentSessionResponse();
  GetJoinRequestsResponse _joinRequests = GetJoinRequestsResponse();
  GetCurrentSessionResponse get session => _session;
  GetJoinRequestsResponse get joinRequests => _joinRequests;

  /// The stream is up and the server answered within [_silenceLimit].
  bool get connected => _connected;
  bool _connected = false;

  /// Events recorded here that the server doesn't have yet.
  int get unsynced => _unsynced;
  int _unsynced = 0;

  /// The server turned this phone's session down: sign in again to sync.
  bool get needsSignIn => _needsSignIn;
  bool _needsSignIn = false;

  /// The server holds a different history for this account (another phone
  /// recorded it). Nothing is pushed until it's resolved.
  bool get diverged => _diverged;
  bool _diverged = false;

  // ── The stream ──

  StreamController<SyncRequest>? _up;
  ResponseStream<SyncResponse>? _down;
  Timer? _heartbeat;
  Timer? _redial;
  DateTime _lastHeard = DateTime.now();
  int _sentUpTo = 0;
  int _failures = 0;

  /// Bumped on every hang-up, so a dropped stream's late callbacks are
  /// ignored rather than taken for the new one's.
  int _generation = 0;

  static Future<File> _fileFor(String userId) async {
    final dir = await getApplicationSupportDirectory();
    final accounts = Directory('${dir.path}/accounts');
    await accounts.create(recursive: true);
    return File('${accounts.path}/$userId.sqlite');
  }

  /// The account file for [userId] ([name]), restored from the server when
  /// this phone has nothing for it yet.
  Future<void> signIn(String userId, String name) async {
    if (_userId == userId) return;
    await signOut();
    _userId = userId;
    final file = await _fileFor(userId);
    final core = await LocalCore.open(file.path, userId, name: name);
    if (_userId != userId) {
      core.close();
      return;
    }
    _core = core;
    _writesSub = core.writes.listen((_) => unawaited(_push()));
    final (seq, _) = await core.syncState();
    if (seq == 0) await _restoreFromServer(core, userId);
    if (_userId != userId) return;
    _ready.complete(core);
    await _refreshUnsynced();
    _dial();
  }

  /// A fresh install (or a reinstall) of an account that already exists:
  /// the server's log first, so this phone carries on from it rather than
  /// starting a history of its own. Retried until it gets through; the
  /// account isn't usable before (see [ready]).
  Future<void> _restoreFromServer(LocalCore core, String userId) async {
    var wait = const Duration(seconds: 1);
    while (_userId == userId) {
      try {
        final pulled = await _grpc.syncService.pullEvents(
          PullEventsRequest(),
          options: CallOptions(timeout: const Duration(seconds: 30)),
        );
        final seq = await core.restore(pulled.events);
        AppLogger.instance.info(_tag, 'restored', {'seq': seq});
        return;
      } catch (e) {
        AppLogger.instance.warn(_tag, 'restore failed, retrying', {
          'error': e.toString(),
        });
        await Future<void>.delayed(wait);
        wait = wait * 2 > _maxBackoff ? _maxBackoff : wait * 2;
      }
    }
  }

  /// Put the account file at [path] (an export) on this phone, replacing
  /// this phone's copy of that account. Returns whose it is (id, name).
  /// While an account is open only its own file is accepted; it's reopened
  /// from the file.
  Future<(String, String)> importFile(String path) async {
    final (owner, name) = await LocalCore.fileOwner(path);
    final open = _userId;
    if (open != null && open != owner) {
      throw const CoreException(
        'failed_precondition',
        'That file is a different account. Sign out to open it.',
      );
    }
    if (open != null) await signOut();
    await File(path).copy((await _fileFor(owner)).path);
    if (open != null) await signIn(owner, name);
    return (owner, name);
  }

  /// The whole account as one SQLite file in the temp directory, named for
  /// [label] and today: the export.
  Future<File> export(String label) async {
    final core = await ready;
    final dir = await getTemporaryDirectory();
    final day = DateTime.now().toIso8601String().substring(0, 10);
    final safe = label.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final file = File(
      '${dir.path}/schlift-${safe.isEmpty ? 'account' : safe}-$day.sqlite',
    );
    await core.export(file.path);
    return file;
  }

  Future<void> signOut() async {
    _userId = null;
    _hangUp();
    _redial?.cancel();
    await _writesSub?.cancel();
    _writesSub = null;
    _core?.close();
    _core = null;
    if (_ready.isCompleted) _ready = Completer<LocalCore>();
    _session = GetCurrentSessionResponse();
    _joinRequests = GetJoinRequestsResponse();
    _diverged = false;
    _unsynced = 0;
    notifyListeners();
  }

  void _dial() {
    if (_core == null || _diverged || _up != null) return;
    _redial?.cancel();
    final up = StreamController<SyncRequest>();
    _up = up;
    _sentUpTo = 0;
    _lastHeard = DateTime.now();
    final down = _grpc.syncService.sync(up.stream);
    _down = down;
    final generation = _generation;
    down.listen(
      (message) {
        if (generation == _generation) unawaited(_heard(message));
      },
      onError: (Object e) {
        if (generation == _generation) _lost(e);
      },
      onDone: () {
        if (generation == _generation) _lost(null);
      },
      cancelOnError: true,
    );
    _heartbeat = Timer.periodic(_heartbeatEvery, (_) => _beat());
    unawaited(_push());
  }

  Future<void> _heard(SyncResponse message) async {
    _lastHeard = DateTime.now();
    if (!_connected) {
      _connected = true;
      _failures = 0;
      notifyListeners();
    }
    switch (message.whichKind()) {
      case SyncResponse_Kind.head:
        await _catchUp(message.head.toInt());
        await _core?.acked(message.head.toInt());
        await _refreshUnsynced();
        // More may have been written while the last batch was in flight.
        await _push();
      case SyncResponse_Kind.session:
        _session = message.session;
        notifyListeners();
      case SyncResponse_Kind.joinRequests:
        _joinRequests = message.joinRequests;
        notifyListeners();
      case SyncResponse_Kind.notSet:
        break;
    }
  }

  /// The server holds events this file doesn't (it was restored from an
  /// older export): pull them in after this file's own.
  Future<void> _catchUp(int head) async {
    final core = _core;
    if (core == null) return;
    final (seq, _) = await core.syncState();
    if (head <= seq) return;
    try {
      final pulled = await _grpc.syncService.pullEvents(
        PullEventsRequest(afterSeq: Int64(seq)),
      );
      await core.restore(pulled.events);
      onCaughtUp?.call();
    } catch (e) {
      AppLogger.instance.warn(_tag, 'catch-up failed', {'error': e.toString()});
    }
  }

  /// Called after events from the server were folded in: what's on screen
  /// may have changed.
  VoidCallback? onCaughtUp;

  /// Send what the server hasn't acknowledged and hasn't been sent on this
  /// stream yet.
  Future<void> _push() async {
    final core = _core;
    final up = _up;
    if (core == null) return;
    if (up == null) {
      // Not connected: a write is a good moment to try again.
      _dial();
      return;
    }
    final (packed, last) = await core.outbox();
    await _refreshUnsynced();
    if (last <= _sentUpTo || up.isClosed) return;
    _sentUpTo = last;
    up.add(SyncRequest(events: packed));
  }

  Future<void> _refreshUnsynced() async {
    final core = _core;
    if (core == null) return;
    final (seq, acked) = await core.syncState();
    final unsynced = seq - acked;
    if (unsynced != _unsynced) {
      _unsynced = unsynced;
      notifyListeners();
    }
  }

  void _beat() {
    final up = _up;
    if (up == null || up.isClosed) return;
    if (DateTime.now().difference(_lastHeard) > _silenceLimit) {
      // Nothing back for too long: the link is dead even if the socket
      // doesn't know it. A fresh channel, and dial again.
      AppLogger.instance.warn(_tag, 'silent, redialling');
      _lost(null, resetChannel: true);
      return;
    }
    up.add(SyncRequest(heartbeat: Heartbeat()));
  }

  void _lost(Object? error, {bool resetChannel = false}) {
    if (_up == null) return;
    if (error is GrpcError &&
        error.code == StatusCode.failedPrecondition &&
        (error.message ?? '').contains('account_diverged')) {
      _diverged = true;
      AppLogger.instance.error(_tag, 'diverged from the server');
    } else if (error is GrpcError && error.code == StatusCode.unauthenticated) {
      // The session lapsed: nothing to dial until the user signs in again.
      _hangUp();
      _needsSignIn = true;
      onSessionRejected?.call();
      notifyListeners();
      return;
    }
    _hangUp();
    if (resetChannel) _grpc.resetChannel();
    _connected = false;
    notifyListeners();
    if (_diverged || _core == null) return;
    _failures++;
    final seconds = 1 << (_failures - 1).clamp(0, 5);
    final wait = Duration(seconds: seconds) > _maxBackoff
        ? _maxBackoff
        : Duration(seconds: seconds);
    _redial = Timer(wait, _dial);
  }

  /// Called when the server turns the session down.
  VoidCallback? onSessionRejected;

  /// Signed in again (or for the first time): dial now.
  void redial() {
    _needsSignIn = false;
    _hangUp();
    _failures = 0;
    _dial();
    notifyListeners();
  }

  void _hangUp() {
    _generation++;
    _heartbeat?.cancel();
    _heartbeat = null;
    unawaited(_down?.cancel());
    _down = null;
    unawaited(_up?.close());
    _up = null;
    _connected = false;
  }

  /// Back in the foreground: whatever the stream was doing in the
  /// background, start it afresh now.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _core == null) return;
    _hangUp();
    _failures = 0;
    _dial();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(signOut());
    super.dispose();
  }
}
