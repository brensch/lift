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

  Session _session = Session();
  GetJoinRequestsResponse _joinRequests = GetJoinRequestsResponse();

  /// Who else is in the caller's session. Where each is up to is
  /// [partnerStatus], from their events.
  Session get session => _session;
  GetJoinRequestsResponse get joinRequests => _joinRequests;

  /// The stream is up and the server answered within [_silenceLimit].
  bool get connected => _connected;
  bool _connected = false;

  /// The server turned this app version away (`MIN_APP_VERSION`): the
  /// stream is not dialled again until the app is back in the foreground,
  /// when the server is asked once more (it may have stopped turning it
  /// away). Everything but sync works meanwhile.
  bool get updateRequired => _updateRequired;
  bool _updateRequired = false;

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

  /// The messages from the stream, handled in turn.
  Future<void> _inbox = Future.value();

  /// Whether there is a session to open the stream with. Without one the
  /// server would turn it down, so nothing is dialled; [redial] starts it
  /// once there is.
  bool Function() canDial = () => true;

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
    final LocalCore core;
    try {
      core = await LocalCore.open(
        (await _fileFor(userId)).path,
        userId,
        name: name,
      );
    } catch (_) {
      // Nothing open: a later sign-in for this user tries again.
      if (_userId == userId) _userId = null;
      rethrow;
    }
    if (_userId != userId) {
      await core.close();
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
    path = await _unzipped(path);
    final (owner, name) = await LocalCore.fileOwner(path);
    final open = _userId;
    if (open != null && open != owner) {
      throw const CoreException(
        'failed_precondition',
        'That file is a different account. Sign out to open it.',
      );
    }
    // Staged beside the account file and opened once first, so a file that
    // is damaged past its first pages is turned away before it replaces
    // anything.
    final account = await _fileFor(owner);
    final staged = File('${account.parent.path}/$owner.import.sqlite');
    if (await staged.exists()) await staged.delete();
    await File(path).copy(staged.path);
    try {
      await (await LocalCore.open(staged.path, owner, name: name)).close();
    } catch (_) {
      await staged.delete();
      rethrow;
    }
    try {
      if (open != null) await signOut();
      await staged.rename(account.path);
    } finally {
      // Whatever happened, the account that was open is open again.
      if (open != null) await signIn(owner, name);
    }
    return (owner, name);
  }

  /// The whole account as one SQLite file, gzipped, in the temp directory,
  /// named for [label] and today: the export. Years of heart rate make the
  /// file large; gzipped it's a fraction, small enough to send.
  Future<File> export(String label) async {
    final core = await ready;
    final dir = await getTemporaryDirectory();
    final day = DateTime.now().toIso8601String().substring(0, 10);
    final safe = label.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final file = File(
      '${dir.path}/schlift-${safe.isEmpty ? 'account' : safe}-$day.sqlite',
    );
    await core.export(file.path);
    final zipped = File('${file.path}.gz');
    await file.openRead().transform(gzip.encoder).pipe(zipped.openWrite());
    await file.delete();
    return zipped;
  }

  /// [path] as a plain SQLite file: a gzipped export is unzipped beside the
  /// others in the temp directory first.
  static Future<String> _unzipped(String path) async {
    final head = await File(path).openRead(0, 2).expand((b) => b).toList();
    if (head.length < 2 || head[0] != 0x1f || head[1] != 0x8b) return path;
    final dir = await getTemporaryDirectory();
    final out = File('${dir.path}/schlift-import.sqlite');
    await File(path).openRead().transform(gzip.decoder).pipe(out.openWrite());
    return out.path;
  }

  Future<void> signOut() async {
    _userId = null;
    _hangUp();
    _redial?.cancel();
    await _writesSub?.cancel();
    _writesSub = null;
    final core = _core;
    _core = null;
    if (_ready.isCompleted) _ready = Completer<LocalCore>();
    _session = Session();
    _joinRequests = GetJoinRequestsResponse();
    _unsynced = 0;
    // The next account asks the server afresh; a refusal sets it again.
    _updateRequired = false;
    notifyListeners();
    // Closed before returning: importFile writes over the file next.
    await core?.close();
  }

  void _dial() {
    final core = _core;
    if (core == null || _up != null || _updateRequired || !canDial()) return;
    _redial?.cancel();
    final up = StreamController<SyncRequest>();
    _up = up;
    _sentUpTo = null;
    _lastHeard = DateTime.now();
    final generation = _generation;
    // The stream opens with what this phone holds; the server sends the rest.
    unawaited(() async {
      final int confirmed;
      try {
        confirmed = await core.confirmed();
      } catch (e) {
        // Closed by a sign-out meanwhile: this stream is already hung up.
        // Anything else is a real failure reading this phone's file.
        if (identical(_core, core)) {
          AppLogger.instance.warn(_tag, 'opening read failed', {
            'error': e.toString(),
          });
        }
        return;
      }
      if (generation != _generation || up.isClosed) return;
      up.add(SyncRequest(afterSeq: Int64(confirmed)));
      _sentUpTo = 0;
      await _push();
    }());
    final down = _grpc.syncService.sync(up.stream);
    _down = down;
    // One at a time, in the order sent (a restore comes in chunks the store
    // takes only in order), and the end of the stream after them.
    void inTurn(Future<void> Function() handle) {
      _inbox = _inbox.then((_) async {
        if (generation != _generation) return;
        try {
          await handle();
        } catch (e) {
          AppLogger.instance.warn(_tag, 'message failed', {
            'error': e.toString(),
          });
        }
      });
    }

    down.listen(
      (message) {
        // Heard now, however long the messages ahead of it take.
        if (generation == _generation) _lastHeard = DateTime.now();
        inTurn(() => _heard(message));
      },
      onError: (Object e) => inTurn(() async => _lost(e)),
      onDone: () => inTurn(() async => _lost(null)),
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
        await _core?.keepPartners([
          for (final member in _session.members) member.user.id,
        ]);
        notifyListeners();
      case SyncResponse_Kind.partnerEvents:
        // A partner's workout as events: this phone's core folds them.
        final partner = message.partnerEvents;
        await _core?.receivePartner(
          partner.userId,
          partner.packed,
          whole: partner.whole,
        );
        notifyListeners();
      case SyncResponse_Kind.joinRequests:
        _joinRequests = message.joinRequests;
        notifyListeners();
      case SyncResponse_Kind.library:
        // What coupled templates follow; a change shows on home.
        if (await _core?.setLibrary(message.library.writeToBuffer()) ?? false) {
          _changed();
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
      if (await core.receive(events.packed, head)) _changed();
    } catch (e) {
      AppLogger.instance.warn(_tag, 'events refused', {'error': e.toString()});
      _lost(e);
      return;
    }
    await _refreshUnsynced();
    if (!_ready.isCompleted &&
        await core.confirmed() >= head &&
        !_ready.isCompleted &&
        identical(_core, core)) {
      _ready.complete(core);
      notifyListeners();
    }
    // The server may lack some of this file: offered again.
    await _push();
  }

  /// Where [member] is up to, folded on this phone from their workout's
  /// events; null once they're off show.
  Future<ParticipantStatus?> partnerStatus(SessionMember member) async =>
      await _core?.partnerStatus(member);

  /// Called after the server changed what the account shows (another
  /// device's events, or a new template library): what's on screen may
  /// have changed. Never run twice at once: changes while it runs (a
  /// restore lands in many pieces) run it once more after, not once each.
  Future<void> Function()? onCaughtUp;
  Future<void>? _catchingUp;
  bool _caughtUpAgain = false;

  /// Moves each time the server changes what the account shows: a screen
  /// that read the account reads it again when it does.
  int get revision => _revision;
  int _revision = 0;

  void _changed() {
    _revision++;
    notifyListeners();
    if (_catchingUp != null) {
      _caughtUpAgain = true;
      return;
    }
    _catchingUp = _catchUp();
  }

  Future<void> _catchUp() async {
    do {
      _caughtUpAgain = false;
      try {
        await onCaughtUp?.call();
      } catch (e) {
        AppLogger.instance.warn(_tag, 'reload failed', {'error': e.toString()});
      }
    } while (_caughtUpAgain);
    _catchingUp = null;
  }

  /// Send what this phone recorded that hasn't been sent on this stream, in
  /// pieces (the store hands out at most a few hundred events at a time).
  Future<void> _push() async {
    final core = _core;
    final up = _up;
    if (core == null) return;
    if (up == null) {
      // Not connected: a write is a good moment to try again.
      _dial();
      return;
    }
    try {
      await _refreshUnsynced();
      while (true) {
        final after = _sentUpTo;
        if (after == null) return;
        final (packed, last) = await core.outbox(after);
        // Another push may have sent them meanwhile.
        if (packed.isEmpty || up.isClosed || _sentUpTo != after) return;
        _sentUpTo = last;
        up.add(SyncRequest(events: packed));
      }
    } catch (e) {
      // Signed out meanwhile: the file is closed and nothing waits to go
      // up on this stream. Otherwise the events stay pending for the next.
      if (identical(_core, core)) {
        AppLogger.instance.warn(_tag, 'push failed', {'error': e.toString()});
      }
    }
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
    if (error is GrpcError &&
        error.code == StatusCode.failedPrecondition &&
        error.message == 'app_update_required') {
      // Too old for the server: dialling again would be turned away too.
      AppLogger.instance.warn(_tag, 'app update required');
      _hangUp();
      _updateRequired = true;
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
    // Asked again: a refusal sets it straight back.
    _updateRequired = false;
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
