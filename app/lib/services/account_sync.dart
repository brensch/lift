/// The signed-in account: its file on this phone, and the Sync stream that
/// keeps it level with the server's.
///
/// Everything works with no connection. The stream opens with the last seq
/// this phone holds and the server sends the rest; up go the events recorded
/// here, which come back down placed in the server's order with any another
/// device made (the core folds them in: `LocalCore.receive`). An event stays
/// pending until it comes back, and is sent again after any reconnect. A
/// heartbeat every few seconds, answered by the server, catches a link that
/// died quietly (half-open wifi) within [_silenceLimit]; the stream is then
/// dropped and dialled again, with backoff (to 10 s) while the server stays
/// out of reach.
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

  /// The open account is usable: on this phone already, or caught up from
  /// the server.
  bool get isReady => _ready.isCompleted;

  // ── What the stream brings down ──

  GetCurrentSessionResponse _session = GetCurrentSessionResponse();
  GetJoinRequestsResponse _joinRequests = GetJoinRequestsResponse();
  GetCurrentSessionResponse get session => _session;
  GetJoinRequestsResponse get joinRequests => _joinRequests;

  /// The stream is up and the server answered within [_silenceLimit].
  bool get connected => _connected;
  bool _connected = false;

  /// Events recorded here that the server hasn't placed yet.
  int get unsynced => _unsynced;
  int _unsynced = 0;

  // ── The stream ──

  StreamController<SyncRequest>? _up;
  ResponseStream<SyncResponse>? _down;
  Timer? _heartbeat;
  Timer? _redial;
  DateTime _lastHeard = DateTime.now();

  /// The last pending event sent on this stream; null until the stream has
  /// opened (said what this phone holds), before which nothing goes up.
  int? _sentUpTo;
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

  /// The account file for [userId] ([name]). One with nothing in it yet (a
  /// fresh install, or a reinstall of an account that exists) isn't usable
  /// until the stream has brought the server's history (see [ready]), so
  /// this phone carries on from it rather than starting one of its own.
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
    final fresh = await core.confirmed() == 0 && await core.pendingCount() == 0;
    if (_userId != userId) return;
    if (!fresh) _ready.complete(core);
    await _refreshUnsynced();
    _dial();
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
    _unsynced = 0;
    notifyListeners();
  }

  void _dial() {
    final core = _core;
    if (core == null || _up != null) return;
    _redial?.cancel();
    final up = StreamController<SyncRequest>();
    _up = up;
    _sentUpTo = null;
    _lastHeard = DateTime.now();
    final generation = _generation;
    // The stream opens with what this phone holds; the server sends the rest.
    unawaited(
      core.confirmed().then((confirmed) {
        if (generation != _generation || up.isClosed) return;
        up.add(SyncRequest(afterSeq: Int64(confirmed)));
        _sentUpTo = 0;
        unawaited(_push());
      }),
    );
    final down = _grpc.syncService.sync(up.stream);
    _down = down;
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
  }

  Future<void> _heard(SyncResponse message) async {
    _lastHeard = DateTime.now();
    if (!_connected) {
      _connected = true;
      _failures = 0;
      notifyListeners();
    }
    switch (message.whichKind()) {
      case SyncResponse_Kind.events:
        await _received(message.events);
      case SyncResponse_Kind.head:
        // The answer to a heartbeat: the link is alive.
        break;
      case SyncResponse_Kind.session:
        _session = message.session;
        notifyListeners();
      case SyncResponse_Kind.joinRequests:
        _joinRequests = message.joinRequests;
        notifyListeners();
      case SyncResponse_Kind.library:
        // What coupled templates follow; a change shows on home.
        if (await _core?.setLibrary(message.library.writeToBuffer()) ?? false) {
          onCaughtUp?.call();
        }
      case SyncResponse_Kind.notSet:
        break;
    }
  }

  /// Events placed by the server: this phone's own coming back, or another
  /// device's. A file that had nothing becomes usable once it has caught up.
  Future<void> _received(Events events) async {
    final core = _core;
    if (core == null) return;
    final head = events.head.toInt();
    try {
      if (await core.receive(events.packed, head)) onCaughtUp?.call();
    } catch (e) {
      AppLogger.instance.warn(_tag, 'events refused', {'error': e.toString()});
      _lost(e);
      return;
    }
    await _refreshUnsynced();
    if (!_ready.isCompleted && await core.confirmed() >= head) {
      _ready.complete(core);
      notifyListeners();
    }
    // The server may lack some of this file: offered again.
    await _push();
  }

  /// Called after the server changed what the account shows (another
  /// device's events, or a new template library): what's on screen may
  /// have changed.
  VoidCallback? onCaughtUp;

  /// Send what this phone recorded that hasn't been sent on this stream.
  Future<void> _push() async {
    final core = _core;
    final up = _up;
    if (core == null) return;
    if (up == null) {
      // Not connected: a write is a good moment to try again.
      _dial();
      return;
    }
    await _refreshUnsynced();
    final after = _sentUpTo;
    if (after == null) return;
    final (packed, last) = await core.outbox(after);
    // Another push may have sent them meanwhile.
    if (packed.isEmpty || up.isClosed || _sentUpTo != after) return;
    _sentUpTo = last;
    up.add(SyncRequest(events: packed));
  }

  Future<void> _refreshUnsynced() async {
    final core = _core;
    if (core == null) return;
    final unsynced = await core.pendingCount();
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
    if (error is GrpcError && error.code == StatusCode.unauthenticated) {
      // The session lapsed: nothing to dial until the user signs in again.
      _hangUp();
      onSessionRejected?.call();
      notifyListeners();
      return;
    }
    _hangUp();
    if (resetChannel) _grpc.resetChannel();
    _connected = false;
    notifyListeners();
    if (_core == null) return;
    _failures++;
    final seconds = 1 << (_failures - 1).clamp(0, 5);
    final wait = Duration(seconds: seconds) > _maxBackoff
        ? _maxBackoff
        : Duration(seconds: seconds);
    _redial = Timer(wait, _dial);
  }

  /// Called when the server turns the session down, before the account is
  /// restored ([isReady] false) or after.
  VoidCallback? onSessionRejected;

  /// Signed in again (or for the first time): dial now.
  void redial() {
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
