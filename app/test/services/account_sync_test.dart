import 'dart:async';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:schlift/gen/workout/v1/account.pbgrpc.dart';
import 'package:schlift/gen/workout/v1/group.pb.dart';
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
}
