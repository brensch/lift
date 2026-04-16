import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:schlift/services/grpc_client.dart';

void main() {
  test('retries once after deadline exceeded and resets channel', () async {
    var resets = 0;
    var attempts = 0;

    final result = await retryReadAfterReconnect<String>(
      operation: 'GetCurrentSession',
      resetChannel: () => resets++,
      rpc: () async {
        attempts++;
        if (attempts == 1) {
          throw GrpcError.deadlineExceeded('Deadline exceeded');
        }
        return 'ok';
      },
    );

    expect(result, 'ok');
    expect(attempts, 2);
    expect(resets, 1);
  });

  test('retries once after unavailable and resets channel', () async {
    var resets = 0;
    var attempts = 0;

    final result = await retryReadAfterReconnect<String>(
      operation: 'GetActiveWorkout',
      resetChannel: () => resets++,
      rpc: () async {
        attempts++;
        if (attempts == 1) {
          throw GrpcError.unavailable('socket closed');
        }
        return 'ok';
      },
    );

    expect(result, 'ok');
    expect(attempts, 2);
    expect(resets, 1);
  });

  test('does not reset or retry for non-connection grpc errors', () async {
    var resets = 0;
    var attempts = 0;

    await expectLater(
      retryReadAfterReconnect<String>(
        operation: 'GetSettings',
        resetChannel: () => resets++,
        rpc: () async {
          attempts++;
          throw GrpcError.unauthenticated('bad token');
        },
      ),
      throwsA(isA<GrpcError>()),
    );

    expect(attempts, 1);
    expect(resets, 0);
  });

  test('propagates if retry on fresh channel also fails', () async {
    var resets = 0;
    var attempts = 0;

    await expectLater(
      retryReadAfterReconnect<String>(
        operation: 'GetCurrentSession',
        resetChannel: () => resets++,
        rpc: () async {
          attempts++;
          throw GrpcError.deadlineExceeded('Deadline exceeded');
        },
      ),
      throwsA(isA<GrpcError>()),
    );

    expect(attempts, 2);
    expect(resets, 1);
  });
}
