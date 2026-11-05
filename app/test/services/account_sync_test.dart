import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:schlift/gen/workout/v1/account.pbgrpc.dart';
import 'package:schlift/gen/workout/v1/group.pb.dart';
import 'package:schlift/gen/workout/v1/workout.pb.dart';
import 'package:schlift/services/account_sync.dart';
import 'package:schlift/services/grpc_client.dart';

import '../support/provider_harness.dart';

/// A server that turns every Sync away as too old an app.
class _TooOld extends SyncServiceBase {
  int calls = 0;

  @override
  Stream<SyncResponse> sync(ServiceCall call, Stream<SyncRequest> request) {
    calls++;
    return Stream.error(GrpcError.failedPrecondition('app_update_required'));
  }
}

/// A server whose Sync streams the test writes to and closes, one per call.
class _Scripted extends SyncServiceBase {
  final streams = <StreamController<SyncResponse>>[];

  /// Called with each request the phone sends up.
  void Function(SyncRequest)? onRequest;

  @override
  Stream<SyncResponse> sync(ServiceCall call, Stream<SyncRequest> request) {
    request.listen((r) => onRequest?.call(r), onError: (_) {});
    final down = StreamController<SyncResponse>();
    streams.add(down);
    return down.stream;
  }
}

SyncResponse _joinRequest(String id) => SyncResponse(
  joinRequests: GetJoinRequestsResponse(requests: [JoinRequest(requestId: id)]),
);

/// [events] as the server packs them: a JSON array in a zstd frame, here
/// with its blocks stored uncompressed (which any zstd decoder reads).
List<int> _packed(List<Map<String, Object>> events) {
  final json = utf8.encode(jsonEncode(events));
  const block = 1 << 17;
  // Magic number; no content size, checksum or dictionary; a 128 KiB window.
  final out = <int>[0x28, 0xB5, 0x2F, 0xFD, 0x00, 0x38];
  for (var at = 0; at < json.length; at += block) {
    final end = at + block < json.length ? at + block : json.length;
    final header = (end - at) << 3 | (end == json.length ? 1 : 0);
    out
      ..addAll([header & 0xFF, header >> 8 & 0xFF, header >> 16 & 0xFF])
      ..addAll(json.sublist(at, end));
  }
  return out;
}

/// The server's history in pieces of [per], as a restore sends it. The
/// facts are of a kind this app doesn't know, which fold as nothing.
List<SyncResponse> _restore(int pieces, {int per = 3}) {
  final head = pieces * per;
  return [
    for (var piece = 0; piece < pieces; piece++)
      SyncResponse(
        events: Events(
          head: Int64(head),
          packed: _packed([
            for (var i = 1; i <= per; i++)
              {
                'seq': piece * per + i,
                'id': 'e${piece * per + i}',
                'at': 0,
                'later_fact': <String, Object>{},
              },
          ]),
        ),
      ),
  ];
}

Future<void> _until(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  Server? server;

  Future<AccountSync> serve(SyncServiceBase service) async {
    final s = Server.create(services: [service]);
    await s.serve(address: 'localhost', port: 0);
    server = s;
    return AccountSync(GrpcClient(host: 'localhost', port: s.port!));
  }

  setUp(() async {
    await loadCore();
    dir = await Directory.systemTemp.createTemp('account_sync_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => dir.path,
        );
  });

  tearDown(() async {
    await server?.shutdown();
    server = null;
    await dir.delete(recursive: true);
  });

  test('an app the server says is too old stops dialling', () async {
    final service = _TooOld();
    final sync = await serve(service);
    await sync.signIn('u1', 'Me');

    await _until(() => sync.updateRequired);
    expect(service.calls, 1);

    // Past the first backoff (1 s), and asked to dial again: still once.
    sync.redial();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    expect(service.calls, 1);
    expect(sync.connected, isFalse);

    // Back in the foreground the server is asked again, once.
    sync.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await _until(() => service.calls == 2 && sync.updateRequired);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    expect(service.calls, 2);

    // Signing out forgets it: the next sign-in asks the server again.
    await sync.signOut();
    expect(sync.updateRequired, isFalse);
    await sync.signIn('u1', 'Me');
    await _until(() => service.calls == 3 && sync.updateRequired);

    await sync.signOut();
  });

  test('with nothing to dial with, nothing is dialled until redial', () async {
    final service = _Scripted();
    final sync = await serve(service);
    var canDial = false;
    sync.canDial = () => canDial;
    await sync.signIn('u1', 'Me');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(service.streams, isEmpty);

    canDial = true;
    sync.redial();
    await _until(() => service.streams.length == 1);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(service.streams, hasLength(1));

    await sync.signOut();
  });

  test('a message is handled before the end of the stream after it', () async {
    final service = _Scripted();
    final sync = await serve(service);
    await sync.signIn('u1', 'Me');
    await _until(() => service.streams.length == 1);
    // A fresh file: usable once the server's history is in.
    expect(sync.isReady, isFalse);

    // Each time the stream is seen to drop: whether the history was in. Its
    // handler awaits the core before it takes effect, so the end of the
    // stream right behind it must wait its turn.
    final readyWhenLost = <bool>[];
    var wasConnected = false;
    sync.addListener(() {
      if (sync.connected) wasConnected = true;
      if (wasConnected && !sync.connected) {
        wasConnected = false;
        readyWhenLost.add(sync.isReady);
      }
    });
    service.streams.first
      ..add(SyncResponse(events: Events(head: Int64(0))))
      ..close();

    await _until(() => readyWhenLost.isNotEmpty);
    expect(readyWhenLost, [true]);
    // Lost, so dialled again after the backoff.
    await _until(() => service.streams.length == 2);

    await sync.signOut();
  });

  test('signing out as the stream opens leaves nothing running', () async {
    final service = _Scripted();
    final sync = await serve(service);
    // The stream opens with what the core holds, then pushes what it has
    // to send, reading the core again: signed out the moment the opening
    // arrives, the file closes under those reads.
    Future<void>? signedOut;
    service.onRequest = (r) {
      if (r.hasAfterSeq()) signedOut ??= sync.signOut();
    };
    for (var i = 1; i <= 5; i++) {
      signedOut = null;
      await sync.signIn('u1', 'Me');
      await _until(() => signedOut != null);
      await signedOut;
    }
    // Any read that failed on the closed file would have failed the test.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });

  test('a hung-up stream changes nothing; the new one does', () async {
    final service = _Scripted();
    final sync = await serve(service);
    await sync.signIn('u1', 'Me');
    await _until(() => service.streams.length == 1);

    sync.redial();
    await _until(() => service.streams.length == 2);
    service.streams.last.add(_joinRequest('new'));
    await _until(() => sync.joinRequests.requests.isNotEmpty);
    expect(sync.joinRequests.requests.single.requestId, 'new');
    expect(sync.connected, isTrue);

    // The old call's cancellation comes in late: not taken for the new one.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(sync.connected, isTrue);
    expect(service.streams, hasLength(2));

    await sync.signOut();
  });

  test('an account that would not open opens on the next sign-in', () async {
    final sync = await serve(_Scripted());
    sync.canDial = () => false;
    // A directory where the file goes: it can't be opened.
    final blocked = Directory('${dir.path}/accounts/u1.sqlite');
    await blocked.create(recursive: true);
    await expectLater(sync.signIn('u1', 'Me'), throwsA(anything));
    expect(sync.core, isNull);

    await blocked.delete();
    await sync.signIn('u1', 'Me');
    expect(sync.core, isNotNull);

    await sync.signOut();
  });
  test(
    'a restore in many pieces reads the account again at most twice',
    () async {
      final service = _Scripted();
      final sync = await serve(service);
      // As the app does: each notice reads the account, which waits until
      // the account is usable and then takes a while (GetHome).
      var reloads = 0;
      sync.onCaughtUp = () async {
        await sync.ready;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        reloads++;
      };
      await sync.signIn('u1', 'Me');
      await _until(() => service.streams.length == 1);
      for (final piece in _restore(20)) {
        service.streams.first.add(piece);
      }
      await _until(() => sync.isReady);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(await sync.core!.confirmed(), 60);
      // The last read is of the whole history.
      expect(reloads, inInclusiveRange(1, 2));

      await sync.signOut();
    },
  );

  test('a server that holds less is sent the rest from its head', () async {
    final service = _Scripted();
    final opened = <int>[];
    service.onRequest = (r) {
      if (r.hasAfterSeq()) opened.add(r.afterSeq.toInt());
    };
    final sync = await serve(service);
    await sync.signIn('u1', 'Me');
    await _until(() => service.streams.length == 1);
    _restore(1).forEach(service.streams.first.add);
    await _until(() => sync.isReady);
    await sync.core!.call(
      'StartWorkout',
      StartWorkoutRequest(name: 'Test', exercises: [Exercise.EXERCISE_SQUAT]),
      StartWorkoutResponse.fromBuffer,
    );
    await service.streams.first.close();

    // Restored from an older backup, the server holds one event: it says
    // so and ends the stream, unread.
    await _until(() => service.streams.length == 2);
    service.streams[1]
      ..add(SyncResponse(events: Events(head: Int64(1))))
      ..close();

    // The phone dials again from there, everything after it queued.
    await _until(() => service.streams.length == 3);
    await _until(() => opened.length == 3);
    expect(opened, [0, 3, 1]);
    expect(await sync.core!.confirmed(), 1);
    expect(await sync.core!.pendingCount(), 3);

    await sync.signOut();
  });

  test('a damaged import is turned away and the account stays open', () async {
    final service = _Scripted();
    final sync = await serve(service);
    // An id the server made: it names the account's file.
    const me = '0b7d5c3e-6f1a-4c2b-9d8e-2a4f6b1c3d5e';
    await sync.signIn(me, 'Me');
    await _until(() => service.streams.length == 1);
    _restore(1).forEach(service.streams.first.add);
    await _until(() => sync.isReady);
    await sync.core!.call(
      'StartWorkout',
      StartWorkoutRequest(name: 'Test', exercises: [Exercise.EXERCISE_SQUAT]),
      StartWorkoutResponse.fromBuffer,
    );
    final pending = await sync.core!.pendingCount();

    // The export, unzipped, with its events' page (the fourth, after the
    // schema and meta) written over: whose it is still reads, but the
    // account in it doesn't.
    final whole = gzip.decode(await (await sync.export('Me')).readAsBytes());
    final damaged = File('${dir.path}/damaged.sqlite')
      ..writeAsBytesSync([...whole]..fillRange(3 * 4096, 4 * 4096, 7));
    final garbage = File('${dir.path}/garbage.sqlite')
      ..writeAsBytesSync(List.filled(4096, 7));

    for (final file in [damaged, garbage]) {
      await expectLater(sync.importFile(file.path), throwsA(anything));
      expect(sync.core, isNotNull);
      expect(await sync.core!.confirmed(), 3);
      expect(await sync.core!.pendingCount(), pending);
    }
    expect(File('${dir.path}/accounts/$me.import.sqlite').existsSync(), false);

    // A whole export still goes in, and the account reopens from it.
    final good = File('${dir.path}/good.sqlite')..writeAsBytesSync(whole);
    expect(await sync.importFile(good.path), (me, 'Me'));
    expect(await sync.core!.confirmed(), 3);
    expect(await sync.core!.pendingCount(), pending);

    await sync.signOut();
  });
}
