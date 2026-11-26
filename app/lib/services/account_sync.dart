/// The signed-in account: its file on this phone, and the Sync stream that
/// keeps it level with the server's.
///
/// Everything works with no connection. The stream opens with the last seq
/// this phone holds and the server sends the rest; up go the events recorded
/// here, which come back down placed in the server's order with any another
/// device made (the core folds them in: `LocalCore.receive`). An event stays
/// pending until it comes back (the server stores pushes with its next
/// flush, about a minute), and is sent again after any reconnect. A
/// heartbeat every [_heartbeatEvery], answered by the server, catches a link
/// that died quietly (half-open wifi) within [_silenceLimit]; the stream is then
/// dropped and dialled again, with backoff (to 10 s) while the server stays
/// out of reach.
///
/// A connection is only ever replaced once it's known to be dead: each new
/// one costs the phone round trips and the server a handshake and an open.
/// Covered for a moment (a notification shade, a dialog, a call banner),
/// the app keeps its stream. Back from the background, or woken after being
/// frozen there, it asks the server whether the stream still reaches it (a
/// heartbeat out of turn, [probeTimeout]) and keeps it if answered.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

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

  AccountSync(
    this._grpc, {
    this.probeTimeout = const Duration(seconds: 5),
    Random? random,
  }) : _random = random ?? Random() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// How long a probe of the stream waits for its answer before the link is
  /// taken for dead: well past a slow mobile round trip, short enough that a
  /// dead link is replaced while the person is still looking.
  final Duration probeTimeout;

  /// Spreads redials, so phones that lost the server together (a restart)
  /// don't all come back in the same instant.
  final Random _random;

  static const _tag = 'Sync';
  // Every open app sends one, so at scale they're most of what the server
  // answers: a link that died is found within [_silenceLimit], well inside
  // the minute a push waits for its ack anyway.
  static const _heartbeatEvery = Duration(seconds: 30);
  static const _silenceLimit = Duration(seconds: 75);
  static const _maxBackoff = Duration(seconds: 10);

  LocalCore? _core;
  String? _userId;
  Completer<LocalCore> _ready = Completer<LocalCore>();
  StreamSubscription<void>? _writesSub;
  int _accountGen = 0;

  @override
  Future<LocalCore> get ready => _ready.future;

  @override
  int get generation => _accountGen;

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

  /// Events recorded here that the server hasn't placed for a while. The
  /// server places a workout when it ends and anything else a minute or two
  /// after it comes, so a workout under way, and events waiting less than
  /// [_unsyncedAfter], are normal and not counted.
  int get unsynced => _unsynced;
  int _unsynced = 0;
  static const _unsyncedAfter = Duration(minutes: 2);

  // ── The stream ──

  StreamController<SyncRequest>? _up;
  ResponseStream<SyncResponse>? _down;
  Timer? _heartbeat;
  Timer? _redial;
  DateTime _lastHeard = DateTime.now();

  /// When the heartbeat last ran: one running far later than due means the
  /// app was frozen in the background meanwhile.
  DateTime _lastBeat = DateTime.now();

  /// A probe waiting for its answer ([_probe]).
  Timer? _probing;

  /// When the app left the screen (hidden, then paused); null while it's on
  /// it, or only covered (inactive), when its stream carries on as it was.
  DateTime? _awaySince;

  /// The last pending event sent on this stream; null until the server's
  /// first events on it are taken, before which nothing goes up: a server
  /// restored from an older backup could place this phone's new events
  /// ahead of older ones it lost.
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

  /// Bring the account file at [path] (an export) onto this phone: what in
  /// it this phone's copy lacks is added, and goes to the server, which
  /// skips what it holds. Nothing is removed, and the same file twice adds
  /// nothing the second time. Returns whose it is (id, name). While an
  /// account is open only its own file is accepted.
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
    // A file that won't read whole adds nothing.
    final core = _core;
    if (core != null) {
      if (await core.importFile(path) > 0) _changed();
      return (owner, name);
    }
    // No account open: into this phone's copy of it, made if there's none.
    final account = await LocalCore.open(
      (await _fileFor(owner)).path,
      owner,
      name: name,
    );
    try {
      await account.importFile(path);
    } finally {
      await account.close();
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

  /// The biggest an imported account is allowed to unzip to. A real export is
  /// at most a handful of megabytes; the cap only stops a crafted file (a
  /// "zip bomb") from expanding without bound and filling the device.
  static const _maxImportBytes = 256 * 1024 * 1024;

  /// [path] as a plain SQLite file: a gzipped export is unzipped beside the
  /// others in the temp directory first, up to [_maxImportBytes].
  static Future<String> _unzipped(String path) async {
    final head = await File(path).openRead(0, 2).expand((b) => b).toList();
    if (head.length < 2 || head[0] != 0x1f || head[1] != 0x8b) return path;
    final dir = await getTemporaryDirectory();
    final out = File('${dir.path}/schlift-import.sqlite');
    final sink = out.openWrite();
    var written = 0;
    try {
      await for (final chunk in File(path).openRead().transform(gzip.decoder)) {
        written += chunk.length;
        if (written > _maxImportBytes) {
          throw const FormatException(
            'the file unzips to more than is allowed',
          );
        }
        sink.add(chunk);
      }
      await sink.close();
    } catch (_) {
      // Closing a faulted sink can itself throw; the delete is what matters.
      try {
        await sink.close();
      } catch (_) {}
      if (await out.exists()) await out.delete();
      rethrow;
    }
    return out.path;
  }

  Future<void> signOut() async {
    // Leaving the account: anything still in flight for it is now stale.
    _accountGen++;
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
    // Closed before returning: the file may be opened again at once.
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
    _lastBeat = DateTime.now();
    final generation = _generation;
    // The stream opens with what this phone holds, the rules it folds by,
    // and what it has waiting; the server sends the rest (or, far behind,
    // the account whole).
    unawaited(() async {
      final int after;
      final List<String> pendingIds;
      final String fold;
      final String lastId;
      try {
        after = await core.opensAfter();
        lastId = await core.confirmedId();
        pendingIds = await core.pendingIds();
        fold = await LocalCore.foldRules();
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
      up.add(
        SyncRequest(
          open: SyncOpen(
            afterSeq: Int64(after),
            fold: fold,
            pendingIds: pendingIds,
            lastId: lastId,
          ),
        ),
      );
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
      case SyncResponse_Kind.account:
        await _receivedAccount(message.account);
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
      case SyncResponse_Kind.notSet:
        break;
    }
  }

  /// The account whole from the server, sent on opening to a phone far
  /// behind or new: it becomes what this phone holds placed, and events
  /// from its seq follow.
  Future<void> _receivedAccount(AccountState state) async {
    final core = _core;
    if (core == null) return;
    try {
      await core.receiveAccount(
        state.snapshot,
        state.seq.toInt(),
        state.lastId,
        state.placedIds,
      );
    } catch (e) {
      AppLogger.instance.warn(_tag, 'account refused', {'error': e.toString()});
      _lost(e);
      return;
    }
    _changed();
    await _refreshUnsynced();
  }

  /// Events placed by the server: this phone's own coming back, or another
  /// device's. A file that had nothing becomes usable once it has caught up.
  Future<void> _received(Events events) async {
    final core = _core;
    final up = _up;
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
    // The server's first events taken: this stream may send.
    if (identical(_core, core) && identical(_up, up)) _sentUpTo ??= 0;
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
    final oldest = await core.oldestPendingAt();
    final waitedLong =
        oldest > 0 &&
        DateTime.now().millisecondsSinceEpoch ~/ 1000 - oldest >
            _unsyncedAfter.inSeconds;
    final unsynced = waitedLong ? await core.pendingCount() : 0;
    if (unsynced != _unsynced) {
      _unsynced = unsynced;
      notifyListeners();
    }
  }

  void _beat() {
    final up = _up;
    if (up == null || up.isClosed) return;
    final now = DateTime.now();
    final overslept = now.difference(_lastBeat) > _heartbeatEvery * 2;
    _lastBeat = now;
    if (overslept) {
      // Frozen in the background: the silence was the app's, not the
      // link's. Asked rather than judged.
      _probe();
      return;
    }
    if (now.difference(_lastHeard) > _silenceLimit) {
      // Nothing back for too long: the link is dead even if the socket
      // doesn't know it. A fresh channel, and dial again.
      AppLogger.instance.warn(_tag, 'silent, redialling');
      _lost(null, resetChannel: true);
      return;
    }
    up.add(SyncRequest(heartbeat: Heartbeat()));
  }

  /// Ask the server now whether the stream still reaches it: a heartbeat
  /// out of turn. Anything heard within [probeTimeout] keeps the stream;
  /// nothing, and the link is dead (a network that dropped it while the app
  /// was away): a fresh connection, dialled at once.
  void _probe() {
    final up = _up;
    if (up == null || up.isClosed || _probing != null) return;
    final asked = DateTime.now();
    final generation = _generation;
    up.add(SyncRequest(heartbeat: Heartbeat()));
    _probing = Timer(probeTimeout, () {
      _probing = null;
      if (generation != _generation) return;
      if (DateTime.now().difference(asked) > probeTimeout * 2) {
        // Frozen again while it waited: no verdict. Asked afresh.
        _probe();
        return;
      }
      if (!_lastHeard.isBefore(asked)) return;
      AppLogger.instance.warn(_tag, 'unanswered, redialling');
      _lost(null, resetChannel: true);
    });
  }

  void _lost(Object? error, {bool resetChannel = false}) {
    if (_up == null) return;
    // A link found dead, or one lost while it was being asked (closed while
    // the app was away): no server turned it away, so it's dialled again at
    // once rather than after a backoff.
    final atOnce = resetChannel || _probing != null;
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
    // Dead: calls stuck on it fail now (and are retried) instead of waiting
    // out a socket that will never answer.
    if (resetChannel) _grpc.resetChannel(dead: true);
    _connected = false;
    notifyListeners();
    if (_core == null) return;
    if (atOnce) {
      _dial();
      return;
    }
    _failures++;
    final seconds = 1 << (_failures - 1).clamp(0, 5);
    final step = Duration(seconds: seconds) > _maxBackoff
        ? _maxBackoff
        : Duration(seconds: seconds);
    // Half to all of the step: phones that lost the server together come
    // back spread out, not in one burst.
    _redial = Timer(step * (0.5 + _random.nextDouble() / 2), _dial);
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
    _probing?.cancel();
    _probing = null;
    unawaited(_down?.cancel());
    _down = null;
    unawaited(_up?.close());
    _up = null;
    _connected = false;
  }

  /// Only a return from the background matters: covered for a moment
  /// (inactive: a notification shade, a dialog, a call banner) the stream
  /// carried on, and is left as it is.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _awaySince ??= DateTime.now();
      case AppLifecycleState.resumed:
        final away = _awaySince;
        _awaySince = null;
        if (away != null) _back();
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  /// Back on screen from the background: the stream as it was if it still
  /// reaches the server, otherwise a new one now.
  void _back() {
    if (_core == null) return;
    if (_updateRequired) {
      // Asked again: a refusal sets it straight back.
      _updateRequired = false;
      _failures = 0;
      _dial();
      return;
    }
    if (_up == null) {
      // Waiting out a backoff (or never dialled): try now.
      _failures = 0;
      _dial();
      return;
    }
    _probe();
  }

  bool _disposed = false;

  /// Nothing is told once disposed: the sign-out [dispose] starts, and any
  /// stream message still in hand, finish after it.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(signOut());
    super.dispose();
  }
}
