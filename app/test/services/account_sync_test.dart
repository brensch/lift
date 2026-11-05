import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:schlift/gen/workout/v1/account.pbgrpc.dart';
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
  late Server server;
  late _TooOld service;

  setUp(() async {
    await loadCore();
    dir = await Directory.systemTemp.createTemp('account_sync_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => dir.path,
        );
    service = _TooOld();
    server = Server.create(services: [service]);
    await server.serve(address: 'localhost', port: 0);
  });

  tearDown(() async {
    await server.shutdown();
    await dir.delete(recursive: true);
  });

  test('an app the server says is too old stops dialling', () async {
    final sync = AccountSync(GrpcClient(host: 'localhost', port: server.port!));
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
}
