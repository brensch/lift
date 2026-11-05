import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
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

  @override
  Stream<SyncResponse> sync(ServiceCall call, Stream<SyncRequest> request) {
    request.listen((_) {}, onError: (_) {});
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

    // Each time the stream is seen to drop: whether the message was in.
    final requestsWhenLost = <int>[];
    var wasConnected = false;
    sync.addListener(() {
      if (sync.connected) wasConnected = true;
      if (wasConnected && !sync.connected) {
        wasConnected = false;
        requestsWhenLost.add(sync.joinRequests.requests.length);
      }
    });
    service.streams.first
      ..add(_joinRequest('r1'))
      ..close();

    await _until(() => requestsWhenLost.isNotEmpty);
    expect(requestsWhenLost, [1]);
    expect(sync.joinRequests.requests.single.requestId, 'r1');
    // Lost, so dialled again after the backoff.
    await _until(() => service.streams.length == 2);
    // Let the new stream's opening read the core before it closes.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    await sync.signOut();
  });

  test('a hung-up stream changes nothing; the new one does', () async {
    final service = _Scripted();
    final sync = await serve(service);
    await sync.signIn('u1', 'Me');
    await _until(() => service.streams.length == 1);

    sync.redial();
    await _until(() => service.streams.length == 2);
    service.streams.first.add(_joinRequest('old'));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(sync.joinRequests.requests, isEmpty);

    service.streams.last.add(_joinRequest('new'));
    await _until(() => sync.joinRequests.requests.isNotEmpty);
    expect(sync.joinRequests.requests.single.requestId, 'new');

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
