import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/gen/workout/v1/group.pb.dart';
import 'package:schlift/providers/multiplayer_provider.dart';
import 'package:schlift/services/account_sync.dart';
import 'package:schlift/services/grpc_client.dart';
import 'package:schlift/services/multiplayer_service.dart';

/// A stream that has brought down [requests], and no session.
class _Feed extends AccountSync {
  _Feed(this.requests) : super(GrpcClient(host: '127.0.0.1', port: 1));

  final List<JoinRequest> requests;

  @override
  GetJoinRequestsResponse get joinRequests =>
      GetJoinRequestsResponse(requests: requests);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a request goes from the banner once it can no longer be answered, '
      'with nothing more from the stream', () async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final feed = _Feed([
      // Answerable for about another second; then for a minute more.
      JoinRequest(requestId: 'old', createdAt: Int64(now - 119)),
      JoinRequest(requestId: 'new', createdAt: Int64(now - 60)),
      // Already past it.
      JoinRequest(requestId: 'gone', createdAt: Int64(now - 300)),
    ]);
    final mp = MultiplayerProvider(
      MultiplayerServiceWrapper(GrpcClient(host: '127.0.0.1', port: 1)),
      feed: feed,
    );
    var notified = 0;
    mp.addListener(() => notified++);

    mp.startSync();
    expect(mp.incomingRequests.map((r) => r.requestId), ['old', 'new']);

    await Future<void>.delayed(const Duration(milliseconds: 2500));
    expect(mp.incomingRequests.map((r) => r.requestId), ['new']);
    expect(notified, greaterThanOrEqualTo(2));

    mp.dispose();
  });
}
